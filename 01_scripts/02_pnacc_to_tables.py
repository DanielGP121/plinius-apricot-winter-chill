"""
Convert the station-based PNACC AR6 (ESD-RegBA) NetCDF files of one domain into tidy
per-station daily Tmin/Tmax tables, and print an inspection summary so the data can be
checked before the winter-chill computation.

Why it matters: chillR needs, for each station, a daily series of Tmin/Tmax (Year, Month,
Day) to reconstruct hourly temperatures and accumulate chill portions. This script is the
bridge from the raw NetCDF (one file per climate model and variable) to that input, and it
confirms the time spans (historical reference vs future) and the station set before scaling
the pipeline to the whole country.

Input layout for one domain (e.g. Murcia), as produced by unzipping the archive requests:
    <root>/observaciones/{tasmax,tasmin}_obs.nc                       (observed reference)
    <root>/historical/{tasmax,tasmin}_<MODEL>_<run>_historical_ESD-RegBA.nc
    <root>/{ssp126,ssp245,ssp370}/{tasmax,tasmin}_<MODEL>_<run>_<ssp>_ESD-RegBA.nc

Each NetCDF follows CF conventions, with a time dimension ('hours since 1900-01-01') and a
station dimension carrying the station id, longitude and latitude.

Usage:
    # 1) inspect first (prints structure, station count, time span, units) — run this first
    python 02_pnacc_to_tables.py --root "$PLINIUS_DATA/02_escenarios_pnacc/murcia" --inspect-only

    # 2) full extraction to tidy tables (one file per scenario)
    python 02_pnacc_to_tables.py --root "$PLINIUS_DATA/02_escenarios_pnacc/murcia" \
                                 --out  "$PLINIUS_DATA/tables/murcia" --format csv

Requires: python >=3.10 with xarray, netCDF4, pandas, numpy (and pyarrow if --format parquet).
"""
from pathlib import Path
import argparse
import re
import sys

import numpy as np
import pandas as pd
import xarray as xr

SCENARIOS = ["observaciones", "historical", "ssp126", "ssp245", "ssp370"]

# tasmax_ACCESS-CM2_r1i1p1f1_historical_ESD-RegBA.nc   |   tasmax_obs.nc
_MODEL_RE = re.compile(r"^(?P<var>tasmax|tasmin)_(?P<model>.+?)_r\d+i\d+p\d+f\d+_(?P<scen>\w+)_ESD-RegBA\.nc$")
_OBS_RE = re.compile(r"^(?P<var>tasmax|tasmin)_obs\.nc$")

# candidate CF names; the station dimension is whatever is not time
_ID_NAMES = ["station_id", "station", "station_name", "station_code", "id"]
_LON_NAMES = ["lon", "longitude", "x"]
_LAT_NAMES = ["lat", "latitude", "y"]


# --- helpers to stay agnostic to the exact CF variable/dimension names ------------------
def _pick(ds, names):
    """First name in `names` that exists as a variable or coordinate of ds, else None."""
    for n in names:
        if n in ds.variables:
            return n
    return None


def _decode(series):
    """Decode CF byte-string station ids (|S5) to clean text; leave plain values untouched."""
    return series.map(lambda b: b.decode("utf-8").strip() if isinstance(b, (bytes, bytearray)) else str(b).strip())


def _var_name(ds):
    """Return 'tasmax' or 'tasmin' depending on which is present."""
    for v in ("tasmax", "tasmin"):
        if v in ds:
            return v
    raise ValueError(f"no tasmax/tasmin data variable found; variables were {list(ds.data_vars)}")


def _station_dim(ds, var):
    """The station dimension is the non-time dimension of the temperature variable."""
    dims = [d for d in ds[var].dims if d.lower() not in ("time", "t")]
    if not dims:
        raise ValueError(f"could not find a station dimension in dims {ds[var].dims}")
    return dims[0]


def _to_celsius(values, units):
    """Convert to degrees Celsius when the file is stored in Kelvin; leave as-is otherwise.
    Chill models operate in Celsius, so a silent Kelvin series would poison every chill value."""
    u = (units or "").strip().lower()
    if u in ("k", "kelvin"):
        return values - 273.15, True
    if u in ("degc", "c", "celsius", "degrees_celsius", "°c"):
        return values, False
    # fall back on magnitude: winter temperatures near 270-290 are almost certainly Kelvin
    finite = values[np.isfinite(values)]
    if finite.size and np.nanmedian(finite) > 100:
        return values - 273.15, True
    return values, False


# --- inspection -------------------------------------------------------------------------
def describe_file(path):
    """Open one NetCDF and return a one-line-per-file structural summary."""
    with xr.open_dataset(path) as ds:
        var = _var_name(ds)
        sdim = _station_dim(ds, var)
        t = pd.to_datetime(ds["time"].values)
        return {
            "file": path.name,
            "station_dim": sdim,
            "n_stations": int(ds.sizes[sdim]),
            "id_var": _pick(ds, _ID_NAMES),
            "lon_var": _pick(ds, _LON_NAMES),
            "lat_var": _pick(ds, _LAT_NAMES),
            "n_days": len(t),
            "time_start": str(pd.Timestamp(t.min()).date()),
            "time_end": str(pd.Timestamp(t.max()).date()),
            "units": ds[var].attrs.get("units", "?"),
        }


def inspect(root):
    """Print, for each scenario found, the full structure of one file plus a parsed summary."""
    for scen in SCENARIOS:
        d = root / scen
        files = sorted(d.glob("*.nc")) if d.is_dir() else []
        print(f"\n=== {scen} : {len(files)} files in {d} ===")
        if not files:
            continue
        # raw xarray view of the first file so the exact dims/coords/attrs are visible
        with xr.open_dataset(files[0]) as ds:
            print(ds)
        print("-- summary per file --")
        for f in files:
            info = describe_file(f)
            print(f"  {info['file']:<55} n_est={info['n_stations']:>4}  "
                  f"{info['time_start']}..{info['time_end']} ({info['n_days']}d)  units={info['units']}")


# --- extraction -------------------------------------------------------------------------
def read_variable(path, out_name):
    """Read one NetCDF into a long DataFrame: station_id, lon, lat, year, month, day, <out_name>.
    Kelvin is converted to Celsius here so the downstream chill computation is well posed."""
    with xr.open_dataset(path) as ds:
        var = _var_name(ds)
        sdim = _station_dim(ds, var)
        id_v, lon_v, lat_v = _pick(ds, _ID_NAMES), _pick(ds, _LON_NAMES), _pick(ds, _LAT_NAMES)

        vals, converted = _to_celsius(ds[var].values.astype("float64"), ds[var].attrs.get("units"))
        df = xr.DataArray(vals, dims=ds[var].dims, coords=ds[var].coords).to_dataframe(name=out_name).reset_index()

        # attach station metadata (id/lon/lat live along the station dimension)
        for role, name in (("station_id", id_v), ("lon", lon_v), ("lat", lat_v)):
            if name is None:
                continue
            if name in df.columns:
                df = df.rename(columns={name: role})
            else:
                meta = ds[name].to_dataframe().reset_index()[[sdim, name]].rename(columns={name: role})
                df = df.merge(meta, on=sdim, how="left")

    df["time"] = pd.to_datetime(df["time"])
    df["year"], df["month"], df["day"] = df["time"].dt.year, df["time"].dt.month, df["time"].dt.day
    if "station_id" in df.columns:
        df["station_id"] = _decode(df["station_id"])
    cols = [c for c in ["station_id", "lon", "lat", "year", "month", "day", out_name] if c in df.columns]
    return df[cols], converted


def write_stations(root, out_dir):
    """Export the station list (id, lon, lat) once, from the first NetCDF found.
    This tiny table is what the cropland (CORINE) filter needs to keep only the stations on
    cultivable land, without touching the heavy temperature series."""
    for scen in SCENARIOS:
        files = sorted((root / scen).glob("*.nc")) if (root / scen).is_dir() else []
        if not files:
            continue
        with xr.open_dataset(files[0]) as ds:
            sdim = _station_dim(ds, _var_name(ds))
            id_v, lon_v, lat_v = _pick(ds, _ID_NAMES), _pick(ds, _LON_NAMES), _pick(ds, _LAT_NAMES)
            st = pd.DataFrame({
                "station_id": _decode(ds[id_v].to_dataframe().reset_index()[id_v]) if id_v else np.arange(ds.sizes[sdim]),
                "lon": np.asarray(ds[lon_v].values) if lon_v else np.nan,
                "lat": np.asarray(ds[lat_v].values) if lat_v else np.nan,
            })
        out_dir.mkdir(parents=True, exist_ok=True)
        dst = out_dir / "stations.csv"
        st.to_csv(dst, index=False)
        print(f"[stations] {len(st)} stations (from {files[0].name}) -> {dst}")
        return
    print("found no .nc from which to extract the station list")


def _keep_model(model, wanted):
    """Whether a model survives the requested subset. Observations ('obs') carry no model and
    are always kept; a requested model matches by case-insensitive substring so short tags like
    'UKESM1' select 'UKESM1-0-LL' without spelling out the full run id."""
    if wanted is None or model == "obs":
        return True
    ml = model.lower()
    return any(w.lower() in ml for w in wanted)


def build_scenario_table(root, scen, models=None, year_min=None, year_max=None):
    """Merge Tmax and Tmin per model into one tidy table for a scenario.
    Columns: scenario, model, station_id, lon, lat, year, month, day, Tmin, Tmax.
    The optional model subset and year clip let a light validation slice be extracted without
    materialising the full multi-GB daily series (e.g. 2-3 models over one 30-year window)."""
    d = root / scen
    files = sorted(d.glob("*.nc"))
    # group the two variables under each model (obs has a single, model-less pair)
    groups = {}
    for f in files:
        m = _MODEL_RE.match(f.name) or _OBS_RE.match(f.name)
        if not m:
            print(f"  warning: name not recognised, skipping: {f.name}")
            continue
        model = m.groupdict().get("model", "obs")
        if not _keep_model(model, models):
            continue
        groups.setdefault(model, {})[m.group("var")] = f

    frames, any_converted = [], False
    for model, vp in groups.items():
        if "tasmax" not in vp or "tasmin" not in vp:
            print(f"  warning: {scen}/{model} has no Tmax+Tmin pair, skipping")
            continue
        tmax, c1 = read_variable(vp["tasmax"], "Tmax")
        tmin, c2 = read_variable(vp["tasmin"], "Tmin")
        any_converted = any_converted or c1 or c2
        keys = [c for c in ["station_id", "lon", "lat", "year", "month", "day"] if c in tmax.columns]
        merged = tmax.merge(tmin, on=keys, how="inner")
        if year_min is not None:
            merged = merged[merged["year"] >= year_min]
        if year_max is not None:
            merged = merged[merged["year"] <= year_max]
        if merged.empty:
            continue
        merged.insert(0, "model", model)
        merged.insert(0, "scenario", scen)
        frames.append(merged)

    if not frames:
        return None, any_converted
    return pd.concat(frames, ignore_index=True), any_converted


def main():
    ap = argparse.ArgumentParser(description="PNACC station NetCDF -> tidy Tmin/Tmax tables")
    ap.add_argument("--root", required=True, help="carpeta del dominio, p.ej. .../02_escenarios_pnacc/murcia")
    ap.add_argument("--out", help="carpeta de salida para las tablas (requerida salvo --inspect-only)")
    ap.add_argument("--inspect-only", action="store_true", help="solo imprime estructura, no escribe tablas")
    ap.add_argument("--format", choices=["csv", "parquet"], default="csv")
    ap.add_argument("--stations-only", action="store_true",
                    help="solo exporta la lista de estaciones (id, lon, lat) a stations.csv, para el filtro CORINE")
    ap.add_argument("--scenarios", help="subconjunto de escenarios separados por coma (por defecto, todos)")
    ap.add_argument("--models", help="subconjunto de modelos, coma-separado y por substring (no afecta a observaciones)")
    ap.add_argument("--year-min", type=int, help="recorta la serie a year >= year-min")
    ap.add_argument("--year-max", type=int, help="recorta la serie a year <= year-max")
    ap.add_argument("--chill-format", action="store_true",
                    help="renombra year/month/day a Year/Month/Day (formato de entrada de chillR)")
    args = ap.parse_args()

    root = Path(args.root)
    if not root.is_dir():
        sys.exit(f"root no existe: {root}")

    if args.stations_only:
        if not args.out:
            sys.exit("--stations-only necesita --out")
        write_stations(root, Path(args.out))
        return

    inspect(root)
    if args.inspect_only:
        return
    if not args.out:
        sys.exit("--out es obligatorio salvo que uses --inspect-only")

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    scenarios = [s.strip() for s in args.scenarios.split(",")] if args.scenarios else SCENARIOS
    models = [m.strip() for m in args.models.split(",")] if args.models else None
    for scen in scenarios:
        if not (root / scen).is_dir():
            continue
        table, converted = build_scenario_table(root, scen, models=models,
                                                 year_min=args.year_min, year_max=args.year_max)
        if table is None:
            print(f"[{scen}] no usable data")
            continue
        if args.chill_format:
            table = table.rename(columns={"year": "Year", "month": "Month", "day": "Day"})
        dst = out / f"{scen}.{args.format}"
        if args.format == "parquet":
            table.to_parquet(dst, index=False)
        else:
            table.to_csv(dst, index=False)
        note = " (convertido K->C)" if converted else ""
        print(f"[{scen}] {len(table):>9} rows, {table['station_id'].nunique() if 'station_id' in table else '?'} stations, "
              f"{table['model'].nunique()} models -> {dst}{note}")


if __name__ == "__main__":
    main()
