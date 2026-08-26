"""
Flag which AEMET stations sit on (or near) cultivable land, using CORINE Land Cover.

Why it matters: the agroclimatic characterization only makes sense on stations that
represent cultivated areas, where the apricot cultivars could actually grow. This filter
implements the criterion agreed with J.A. Egea: a station counts as cultivable if at least a
given fraction of a small radius around it falls on CORINE cropland classes. The output
station subset is what later feeds the winter-chill maps, so the class list and the buffer
size decide which territory the case study speaks about.

Inputs:
  --stations  stations.csv with columns station_id, lon, lat (WGS84), from 02_pnacc_to_tables.py
  --clc       local CORINE Land Cover raster (GeoTIFF), e.g. CLC2018 100 m (ideally EPSG:3035)

Output:
  <out>/stations_cultivable.csv  (point class, % cropland in the buffer, and the cultivable flag)

Also prints the distribution of raster class codes found in the buffers, so the cropland code
list can be calibrated against the raster legend before trusting the flag.

Usage:
  python 05_cropland_filter.py --stations "$PLINIUS_DATA/tables/murcia/stations.csv" \
      --clc "$PLINIUS_DATA/corine/clc2018.tif" --out "$PLINIUS_DATA/tables/murcia" \
      --radius-km 2 --threshold 0.5

Requires: geopandas, rasterio, shapely, pyproj, pandas, numpy.
"""
from pathlib import Path
import argparse
import sys

import numpy as np
import pandas as pd
import geopandas as gpd
import rasterio
from rasterio.mask import mask
from shapely.geometry import Point

# CORINE 100 m raster grid codes (1..44 legend). Cropland = arable + permanent crops:
#   12=211 non-irrigated arable, 13=212 permanently irrigated, 14=213 rice fields,
#   15=221 vineyards, 16=222 fruit trees & berries, 17=223 olive groves.
# Excluded by default: 18=231 pastures. Optional heterogeneous agriculture: 19..22 = 241..244.
# If the raster instead stores 3-digit codes (211, 212, ...), pass --crop-codes accordingly.
DEFAULT_CROP_CODES = [12, 13, 14, 15, 16, 17]
HETERO_CODES = [19, 20, 21, 22]


def main():
    ap = argparse.ArgumentParser(description="Flag stations on CORINE cropland (buffer % criterion)")
    ap.add_argument("--stations", required=True)
    ap.add_argument("--clc", required=True, help="ruta al raster CORINE local (GeoTIFF)")
    ap.add_argument("--out", required=True)
    ap.add_argument("--radius-km", type=float, default=2.0, help="radio del buffer alrededor de la estación")
    ap.add_argument("--threshold", type=float, default=0.5, help="fracción mínima de cultivo en el buffer (0-1)")
    ap.add_argument("--crop-codes", default=",".join(map(str, DEFAULT_CROP_CODES)),
                    help="códigos del raster considerados cultivo (según la leyenda del raster)")
    ap.add_argument("--include-hetero", action="store_true",
                    help="añade las clases agrícolas heterogéneas (241-244)")
    ap.add_argument("--tag", default="", help="sufijo para el fichero de salida (p.ej. strict, broad)")
    args = ap.parse_args()

    crop_codes = {int(c) for c in args.crop_codes.split(",") if c.strip()}
    if args.include_hetero:
        crop_codes |= set(HETERO_CODES)

    stations = pd.read_csv(args.stations)
    gdf = gpd.GeoDataFrame(stations,
                           geometry=[Point(xy) for xy in zip(stations.lon, stations.lat)],
                           crs="EPSG:4326")

    seen = {}
    rows = []
    with rasterio.open(args.clc) as src:
        if src.crs is None:
            sys.exit("the raster has no CRS defined")
        if src.crs.is_geographic:
            print("WARNING: the raster is in geographic degrees, so a buffer in km will not be "
                  "metric. Use a projected CORINE (EPSG:3035) for a reliable radius in metres.")
        gdf_p = gdf.to_crs(src.crs)
        radius_m = args.radius_km * 1000.0
        nodata = src.nodata

        for st, geom in zip(stations.itertuples(index=False), gdf_p.geometry):
            point_class = int(list(src.sample([(geom.x, geom.y)]))[0][0])
            arr, _ = mask(src, [geom.buffer(radius_m)], crop=True, filled=True)
            a = arr[0]
            valid = (a != nodata) if nodata is not None else np.ones_like(a, dtype=bool)
            valid &= a > 0  # CORINE class codes are strictly positive; drops fill/nodata pixels
            n_valid = int(valid.sum())
            pct = float(np.isin(a, list(crop_codes))[valid].mean()) if n_valid else np.nan
            for v in np.unique(a[valid]):
                seen[int(v)] = seen.get(int(v), 0) + 1
            rows.append({
                "station_id": st.station_id, "lon": st.lon, "lat": st.lat,
                "point_class": point_class,
                "point_is_crop": point_class in crop_codes,
                "pct_crop_buffer": round(pct, 4) if pct == pct else np.nan,
                "cultivable": bool(pct == pct and pct >= args.threshold),
            })

    out = pd.DataFrame(rows)
    Path(args.out).mkdir(parents=True, exist_ok=True)
    fname = "stations_cultivable" + (f"_{args.tag}" if args.tag else "") + ".csv"
    dst = Path(args.out) / fname
    out.to_csv(dst, index=False)

    print(f"\nCriterion: >= {args.threshold:.0%} cropland within a radius of {args.radius_km} km; "
          f"crop codes = {sorted(crop_codes)}")
    print(f"Cultivable stations: {int(out.cultivable.sum())} / {len(out)}  "
          f"(with the point directly on cropland: {int(out.point_is_crop.sum())})")
    print(f"-> {dst}")
    print("\nRaster classes found inside the buffers (code: number of stations):")
    for code in sorted(seen):
        print(f"  {code:>4}: {seen[code]}{'  <- cropland' if code in crop_codes else ''}")
    print("\nIf these codes do not match the CORINE legend (the 100 m raster uses 1-44; other "
          "products use 111-523), rerun with --crop-codes set to what you see above.")


if __name__ == "__main__":
    main()
