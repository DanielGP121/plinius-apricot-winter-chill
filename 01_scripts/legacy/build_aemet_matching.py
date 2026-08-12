"""
Match each of the 270 regional agroclimatic stations (Egea et al. 2022, Frontiers)
to the nearest AEMET station, so the EGU/Plinius work can reuse AEMET observed
series and PNACC future climate projections in place of the regional networks.

Pipeline (each stage caches its output; delete the cache file to force a rebuild):
  1. AEMET inventory  -> download + parse the public station master list
  2. Regional elevation -> query a public DEM (neither input Excel carries altitude)
  3. Matching -> nearest AEMET by three criteria, written to CSV + XLSX
  4. Map -> control figure over a Spain provinces outline

Inputs (00_data/):
  coordenadas_long_lat_UTM.xlsx        CODEST, x(lon), y(lat), XUTM, YUTM
  COORDS INICIO UF DEF definitiva.xlsx CCAA, Provincia, CODEST, MUNICIPIO, chill-start dates

All coordinates are WGS84 decimal degrees; distances are haversine (km).
"""
from pathlib import Path
import io
import os
import re
import sys
import time
import json

import numpy as np
import pandas as pd
import requests

sys.stdout.reconfigure(encoding="utf-8")

# --- paths (resolved relative to this script for portability) ---
BASE = Path(__file__).resolve().parents[1]
DATA = BASE / "00_data"
OUT = BASE / "02_outputs"
ASSETS = OUT / "_assets"
OUT.mkdir(exist_ok=True)
ASSETS.mkdir(exist_ok=True)

# --- tunable matching parameters (to be revisited with J.A. Egea) ---
ALT_WEIGHT_KM_PER_M = 0.10   # criterion B: 100 m of altitude gap counts as ~10 km horizontal
RADIUS_KM = 25.0             # criterion C: neighbourhood radius for the closest-in-altitude station

AEMET_API_INVENTORY = ("https://opendata.aemet.es/opendata/api/valores/climatologicos/"
                       "inventarioestaciones/todasestaciones")
AEMET_MASTER_URL = "https://raw.githubusercontent.com/boricles/aemet/master/tools/stationsGenerator/maestro.csv"
DEM_URL = "https://api.opentopodata.org/v1/eudem25m"
SPAIN_GEOJSON_URL = ("https://raw.githubusercontent.com/codeforgermany/click_that_hood/"
                     "main/public/data/spain-provinces.geojson")


def haversine_km(lat1, lon1, lat2, lon2):
    """Great-circle distance (km); scalar origin against numpy target arrays."""
    R = 6371.0088
    p1, p2 = np.radians(lat1), np.radians(lat2)
    dphi = np.radians(lat2 - lat1)
    dlmb = np.radians(lon2 - lon1)
    a = np.sin(dphi / 2) ** 2 + np.cos(p1) * np.cos(p2) * np.sin(dlmb / 2) ** 2
    return 2 * R * np.arcsin(np.sqrt(a))


def sexagesimal_to_decimal(s):
    """Signed decimal degrees from AEMET DMS. Handles both the public mirror
    ('43 47 14 N', spaced) and the official API ('394924N', packed DDMMSSH)."""
    if s is None:
        return np.nan
    m = re.match(r"\s*(\d{2})\s*(\d{2})\s*(\d{2})\s*([NSEWnsew])", str(s).strip())
    if not m:
        return np.nan
    deg, mn, sec, hemi = int(m.group(1)), int(m.group(2)), int(m.group(3)), m.group(4).upper()
    val = deg + mn / 60 + sec / 3600
    return -val if hemi in ("S", "W") else val


# --- 1. AEMET inventory -----------------------------------------------------
# Two interchangeable sources, both normalised to the same INDCLIM/lat/lon/alt
# schema so the rest of the pipeline is source-agnostic: the official AEMET
# OpenData API (preferred, set AEMET_API_KEY in the environment) and a public
# mirror as fallback. Each source caches to its own file so both stay comparable.
def fetch_aemet_inventory_public():
    """Public mirror (boricles/aemet): comma header + semicolon data, ISO-8859-1."""
    txt = requests.get(AEMET_MASTER_URL, timeout=60).content.decode("latin-1")
    cols = ["INDCLIM", "INDSINOP", "NOMBRE", "PROVINCIA", "LATITUD", "LONGITUD", "ALTITUD"]
    df = pd.read_csv(io.StringIO(txt), sep=";", header=0, names=cols, dtype=str)
    df["lat"] = df["LATITUD"].apply(sexagesimal_to_decimal)
    df["lon"] = df["LONGITUD"].apply(sexagesimal_to_decimal)
    df["alt"] = pd.to_numeric(df["ALTITUD"], errors="coerce")
    df["INDCLIM"] = df["INDCLIM"].str.strip()
    df["NOMBRE"] = df["NOMBRE"].str.strip()
    return df


def fetch_aemet_inventory_api(api_key):
    """Official inventory via the AEMET two-step pattern: the first call returns a
    small JSON carrying a 'datos' URL, the second fetches the station array (served
    as ISO-8859-15). Retries on the 429 rate limit that AEMET applies aggressively."""
    data_url = None
    for _ in range(6):
        r = requests.get(AEMET_API_INVENTORY, params={"api_key": api_key}, timeout=30)
        if r.status_code == 429:
            time.sleep(20); continue
        r.raise_for_status()
        meta = r.json()
        if meta.get("estado") == 200:
            data_url = meta["datos"]; break
        if meta.get("estado") == 429:
            time.sleep(20); continue
        raise RuntimeError(f"AEMET estado {meta.get('estado')}: {meta.get('descripcion')}")
    if data_url is None:
        raise RuntimeError("AEMET inventory: still rate-limited after retries")
    d = requests.get(data_url, timeout=60)
    d.encoding = "ISO-8859-15"
    df = pd.DataFrame(d.json())
    df["lat"] = df["latitud"].apply(sexagesimal_to_decimal)
    df["lon"] = df["longitud"].apply(sexagesimal_to_decimal)
    df["alt"] = pd.to_numeric(df["altitud"], errors="coerce")
    return df.rename(columns={"indicativo": "INDCLIM", "indsinop": "INDSINOP",
                              "nombre": "NOMBRE", "provincia": "PROVINCIA"})


def load_aemet_inventory():
    api_key = os.environ.get("AEMET_API_KEY")
    if api_key:
        cache, source, fetch = (OUT / "aemet_station_inventory_api.csv",
                                "AEMET OpenData API (official)", lambda: fetch_aemet_inventory_api(api_key))
    else:
        cache, source, fetch = (OUT / "aemet_station_inventory_public.csv",
                                "public mirror (no API key set)", fetch_aemet_inventory_public)
    if cache.exists():
        return pd.read_csv(cache)
    df = fetch()[["INDCLIM", "INDSINOP", "NOMBRE", "PROVINCIA", "lat", "lon", "alt"]].dropna(subset=["lat", "lon", "alt"])
    df.to_csv(cache, index=False, encoding="utf-8")
    print(f"[1] AEMET inventory: {len(df)} stations from {source} -> {cache.name}")
    return df


# --- 2. Regional elevation --------------------------------------------------
# Neither input carries altitude, so sample a public 25 m DEM at each of the 270
# points (batched to respect the endpoint's 100-locations / ~1 req-s limits).
def load_regional_with_elevation():
    cache = OUT / "regional_stations_elevation.csv"
    if cache.exists():
        return pd.read_csv(cache)
    reg = pd.read_excel(DATA / "coordenadas_long_lat_UTM.xlsx").rename(columns={"x": "lon", "y": "lat"})
    elevs = []
    for i in range(0, len(reg), 100):
        sub = reg.iloc[i:i + 100]
        locs = "|".join(f"{r.lat},{r.lon}" for r in sub.itertuples())
        js = requests.get(DEM_URL, params={"locations": locs}, timeout=60).json()
        elevs.extend(x["elevation"] for x in js["results"])
        time.sleep(1.2)
    reg["elev_dem_m"] = elevs
    reg.to_csv(cache, index=False, encoding="utf-8")
    print(f"[2] Regional elevation: {len(reg)} stations, {reg.elev_dem_m.isna().sum()} nulls -> {cache.name}")
    return reg


# --- 3. Matching ------------------------------------------------------------
# For every regional station rank the AEMET network three ways: pure distance
# (A, reference), distance penalised by altitude gap (B, the chosen criterion),
# and smallest altitude gap within a radius (C, interpretable alternative).
def build_matching(reg, aem):
    meta = pd.read_excel(DATA / "COORDS INICIO UF DEF definitiva.xlsx")
    meta = meta[["CCAA", "Provincia", "CODEST", "MUNICIPIO", "PROMEDIO"]].rename(
        columns={"PROMEDIO": "inicio_UF_promedio"})
    alat, alon, aalt = aem["lat"].to_numpy(), aem["lon"].to_numpy(), aem["alt"].to_numpy()
    rows = []
    for r in reg.itertuples():
        d = haversine_km(r.lat, r.lon, alat, alon)
        dalt = aalt - r.elev_dem_m
        iA = int(np.argmin(d))
        iB = int(np.argmin(np.sqrt(d ** 2 + (ALT_WEIGHT_KM_PER_M * dalt) ** 2)))
        within = np.where(d <= RADIUS_KM)[0]
        iC = int(within[np.argmin(np.abs(dalt[within]))]) if within.size else iA
        rows.append({
            "CODEST": r.CODEST, "reg_lat": round(r.lat, 5), "reg_lon": round(r.lon, 5),
            "reg_elev_m": round(r.elev_dem_m),
            "A_indclim": aem.INDCLIM.iloc[iA], "A_name": aem.NOMBRE.iloc[iA], "A_prov": aem.PROVINCIA.iloc[iA],
            "A_alt_m": int(aalt[iA]), "A_dist_km": round(d[iA], 2), "A_dalt_m": round(dalt[iA]),
            "B_indclim": aem.INDCLIM.iloc[iB], "B_name": aem.NOMBRE.iloc[iB],
            "B_alt_m": int(aalt[iB]), "B_dist_km": round(d[iB], 2), "B_dalt_m": round(dalt[iB]),
            "C_indclim": aem.INDCLIM.iloc[iC], "C_name": aem.NOMBRE.iloc[iC],
            "C_alt_m": int(aalt[iC]), "C_dist_km": round(d[iC], 2), "C_dalt_m": round(dalt[iC]),
            "AB_differ": iA != iB, "AC_differ": iA != iC,
        })
    out = pd.DataFrame(rows).merge(meta, on="CODEST", how="left")
    lead = ["CODEST", "CCAA", "Provincia", "MUNICIPIO", "reg_lat", "reg_lon", "reg_elev_m", "inicio_UF_promedio"]
    out = out[lead + [c for c in out.columns if c not in lead]]
    out.to_csv(OUT / "matching_regional_to_aemet.csv", index=False, encoding="utf-8")
    try:  # xlsx write fails if the file is open in Excel / locked by OneDrive; the CSV still updates
        with pd.ExcelWriter(OUT / "matching_regional_to_aemet.xlsx") as xw:
            out.to_excel(xw, index=False, sheet_name="matching")
        fmt = "csv/.xlsx"
    except PermissionError:
        fmt = "csv (xlsx locked; close it in Excel and re-run to refresh)"
    print(f"[3] Matching -> matching_regional_to_aemet.{fmt}  "
          f"(B differs from A in {out.AB_differ.sum()}, C in {out.AC_differ.sum()} of {len(out)})")
    return out


# --- 4. Control map ---------------------------------------------------------
# Draw the chosen criterion (B) as regional->AEMET links over a provinces outline,
# regional points coloured by altitude, so mismatches are visually auditable.
def draw_map(match, aem):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    geo_cache = ASSETS / "spain_provinces.geojson"
    if not geo_cache.exists():
        geo_cache.write_bytes(requests.get(SPAIN_GEOJSON_URL, timeout=30).content)
    gj = json.loads(geo_cache.read_text(encoding="utf-8"))

    fig, ax = plt.subplots(figsize=(11, 9))
    for feat in gj["features"]:
        geom = feat["geometry"]
        polys = geom["coordinates"] if geom["type"] == "MultiPolygon" else [geom["coordinates"]]
        for poly in polys:
            ring = np.array(poly[0])
            ax.plot(ring[:, 0], ring[:, 1], color="0.75", lw=0.5, zorder=1)

    ax.scatter(aem.lon, aem.lat, s=4, c="0.8", zorder=2, label="AEMET network (784)")
    idx = aem.set_index("INDCLIM")
    used = idx.loc[match.B_indclim.unique()]
    ax.scatter(used.lon, used.lat, s=26, marker="^", facecolor="none",
               edgecolor="crimson", lw=0.8, zorder=4, label="AEMET matched (B)")
    for m in match.itertuples():
        a = idx.loc[m.B_indclim]
        ax.plot([m.reg_lon, a.lon], [m.reg_lat, a.lat], color="crimson", lw=0.3, alpha=0.5, zorder=3)
    sc = ax.scatter(match.reg_lon, match.reg_lat, c=match.reg_elev_m, s=18,
                    cmap="viridis", zorder=5, label="Regional stations (270)")
    fig.colorbar(sc, ax=ax, shrink=0.6, label="Regional station elevation (m)")

    ax.set_xlim(-10, 5); ax.set_ylim(35, 44.5)
    ax.set_xlabel("Longitude"); ax.set_ylabel("Latitude")
    ax.set_title("Regional agroclimatic stations matched to nearest AEMET station\n"
                 f"criterion B (distance + altitude, {ALT_WEIGHT_KM_PER_M:g} km/m)")
    ax.legend(loc="lower left", fontsize=8, framealpha=0.9)
    ax.set_aspect(1.35)
    fig.tight_layout()
    fig.savefig(OUT / "matching_map.png", dpi=150)
    print(f"[4] Map -> matching_map.png")


def main():
    aem = load_aemet_inventory()
    reg = load_regional_with_elevation()
    match = build_matching(reg, aem)
    draw_map(match, aem)
    print("done.")


if __name__ == "__main__":
    main()
