"""
Decision support for the cultivable-soil criterion (Murcia test-run).

Why it exists: the strict vs broad cropland definition changes how many stations enter the
chill maps (44 vs 73 in Murcia), so the definition has to be chosen deliberately. This script
lays out the two things that decision needs: a map of which stations fall in or out under each
definition, and a sensitivity table over buffer radius and threshold showing how fragile the
count is.

It samples CORINE once and computes, per station, the cropland fraction at several radii for
both the strict class set (arable + permanent crops, 211-223) and the broad set (also the
heterogeneous agriculture 241-244). Nothing here decides science; it just lays the numbers out.

Inputs:
  --stations  stations.csv (station_id, lon, lat, WGS84) from 02_pnacc_to_tables.py
  --clc       CORINE Land Cover GeoTIFF (ideally EPSG:3035 so a km radius is metric)

Outputs (in --out):
  soil_criterion_sensitivity.csv   cultivable counts for every radius x threshold x class set
  soil_criterion_map.png           station map under the canonical criterion
  soil_criterion_stations.csv      per-station cropland fraction at each radius (strict & broad)

Usage:
  python 07_soil_decision_map.py --stations "$PLINIUS_DATA/tables/murcia/stations.csv" \
      --clc ".../U2018_CLC2018_V2020_20u1.tif" --out "$PLINIUS_DATA/tables/murcia" \
      --radii 1,2,5 --thresholds 0.3,0.5,0.7 --map-radius 2 --map-threshold 0.5

Requires: geopandas, rasterio, shapely, pyproj, pandas, numpy, matplotlib.
"""
from pathlib import Path
import argparse

import numpy as np
import pandas as pd
import geopandas as gpd
import rasterio
from rasterio.mask import mask
from shapely.geometry import Point
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

# CORINE 100 m grid codes (1..44 legend), same convention as 05_cropland_filter.py.
STRICT_CODES = [12, 13, 14, 15, 16, 17]          # 211-223 arable + permanent crops
HETERO_CODES = [19, 20, 21, 22]                  # 241-244 heterogeneous agriculture
BROAD_CODES = STRICT_CODES + HETERO_CODES


def sample_fractions(stations, clc_path, radii_km):
    """For every station, the cropland fraction (strict and broad) within each radius.
    One raster pass; for each station the largest buffer is masked and the smaller radii are
    taken from the same window by pixel distance, so the raster is read once per station."""
    gdf = gpd.GeoDataFrame(stations,
                           geometry=[Point(xy) for xy in zip(stations.lon, stations.lat)],
                           crs="EPSG:4326")
    rows = []
    rmax = max(radii_km)
    with rasterio.open(clc_path) as src:
        if src.crs is not None and src.crs.is_geographic:
            print("WARNING: raster in degrees; the radius in km will not be metric. Use EPSG:3035.")
        gdf_p = gdf.to_crs(src.crs)
        px = abs(src.transform.a)  # pixel size in CRS units (metres for EPSG:3035)
        nodata = src.nodata
        for st, geom in zip(stations.itertuples(index=False), gdf_p.geometry):
            point_class = int(list(src.sample([(geom.x, geom.y)]))[0][0])
            arr, tr = mask(src, [geom.buffer(rmax * 1000.0)], crop=True, filled=True)
            a = arr[0]
            # pixel-centre distance to the station, to carve smaller radii out of the window
            ny, nx = a.shape
            cols = np.arange(nx); rowsi = np.arange(ny)
            xs = tr.c + (cols + 0.5) * tr.a
            ys = tr.f + (rowsi + 0.5) * tr.e
            dx = xs[None, :] - geom.x
            dy = ys[:, None] - geom.y
            dist = np.sqrt(dx * dx + dy * dy)
            base_valid = (a > 0)
            if nodata is not None:
                base_valid &= (a != nodata)
            rec = {"station_id": st.station_id, "lon": st.lon, "lat": st.lat,
                   "point_class": point_class}
            for r in radii_km:
                within = base_valid & (dist <= r * 1000.0)
                n = int(within.sum())
                if n:
                    rec[f"pct_strict_r{r}"] = float(np.isin(a, STRICT_CODES)[within].mean())
                    rec[f"pct_broad_r{r}"] = float(np.isin(a, BROAD_CODES)[within].mean())
                else:
                    rec[f"pct_strict_r{r}"] = np.nan
                    rec[f"pct_broad_r{r}"] = np.nan
            rows.append(rec)
    return pd.DataFrame(rows)


def sensitivity_table(frac, radii_km, thresholds):
    """Cultivable-station count for every radius x threshold x class-set combination."""
    out = []
    n_tot = len(frac)
    for r in radii_km:
        for t in thresholds:
            for label, col in (("strict", f"pct_strict_r{r}"), ("broad", f"pct_broad_r{r}")):
                n_ok = int((frac[col] >= t).sum())
                out.append({"class_set": label, "radius_km": r, "threshold": t,
                            "n_cultivable": n_ok, "n_total": n_tot,
                            "pct": round(100 * n_ok / n_tot, 1)})
    return pd.DataFrame(out)


def draw_map(frac, radius, threshold, dst_png):
    """Station map under the canonical criterion: strict-cultivable, broad-only, or out."""
    strict_ok = frac[f"pct_strict_r{radius}"] >= threshold
    broad_ok = frac[f"pct_broad_r{radius}"] >= threshold
    cat = np.where(strict_ok, "cultivable (estricto)",
                   np.where(broad_ok, "solo amplio (heterogéneo)", "no cultivable"))
    colours = {"cultivable (estricto)": "#1a9850",
               "solo amplio (heterogéneo)": "#fdae61",
               "no cultivable": "#b0b0b0"}
    fig, ax = plt.subplots(figsize=(8, 7))
    for label, c in colours.items():
        m = cat == label
        ax.scatter(frac.lon[m], frac.lat[m], s=42, c=c, edgecolor="k",
                   linewidth=0.3, label=f"{label} (n={int(m.sum())})")
    ax.set_xlabel("Longitud"); ax.set_ylabel("Latitud")
    ax.set_title(f"Estaciones AEMET en suelo cultivable — Región de Murcia\n"
                 f"criterio: ≥{threshold:.0%} de cultivo en radio de {radius} km (CORINE 2018)")
    ax.set_aspect("equal", adjustable="datalim")
    ax.grid(True, alpha=0.3)
    ax.legend(loc="best", fontsize=9, framealpha=0.9)
    fig.tight_layout()
    fig.savefig(dst_png, dpi=150)
    plt.close(fig)


def main():
    ap = argparse.ArgumentParser(description="Mapa + sensibilidad del criterio de suelo cultivable")
    ap.add_argument("--stations", required=True)
    ap.add_argument("--clc", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--radii", default="1,2,5", help="radios en km, coma-separados")
    ap.add_argument("--thresholds", default="0.3,0.5,0.7", help="umbrales (fracción), coma-separados")
    ap.add_argument("--map-radius", type=float, default=2.0)
    ap.add_argument("--map-threshold", type=float, default=0.5)
    args = ap.parse_args()

    radii = [float(x) for x in args.radii.split(",")]
    thresholds = [float(x) for x in args.thresholds.split(",")]
    out = Path(args.out); out.mkdir(parents=True, exist_ok=True)

    stations = pd.read_csv(args.stations)
    frac = sample_fractions(stations, args.clc, radii)
    frac.to_csv(out / "soil_criterion_stations.csv", index=False)

    sens = sensitivity_table(frac, radii, thresholds)
    sens.to_csv(out / "soil_criterion_sensitivity.csv", index=False)

    draw_map(frac, args.map_radius, args.map_threshold, out / "soil_criterion_map.png")

    print(f"stations: {len(frac)}")
    print("\n=== sensitivity (number of cultivable stations) ===")
    piv = sens.pivot_table(index=["class_set", "radius_km"], columns="threshold",
                           values="n_cultivable")
    print(piv.to_string())
    print(f"\nmapa -> {out / 'soil_criterion_map.png'}")
    print(f"table -> {out / 'soil_criterion_sensitivity.csv'}")


if __name__ == "__main__":
    main()
