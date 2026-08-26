#!/usr/bin/env bash
# ---------------------------------------------------------------------------------------
# Download the national (Peninsula + Baleares) PNACC AR6 station projections from the AdapteCCa
# THREDDS server, directly on Ladon, avoiding a 22 GB upload from the laptop. Verified route:
# HTTPServer serves one NetCDF per model and scenario, each holding ALL stations (station x time).
#
# Product: Proyecciones_CMIP6_en_estaciones, daily temperature, ESD-RegBA. 11 models x
# {historical, ssp126, ssp245, ssp370} x {tasmax, tasmin} = 88 files (~15 GB). ssp585 is skipped
# (project uses ssp370 as the pessimistic scenario). The observed reference is a separate catalog
# (Observaciones_en_estaciones) and is handled apart.
#
# Run on Ladon (has internet + the compute). OPeNDAP is not available for these datasets, so the
# whole file is downloaded and subset locally.
#
# Usage (Ladon):
#   nohup bash 14_ladon_download_thredds.sh > download_thredds.log 2>&1 &
# ---------------------------------------------------------------------------------------
set -u

BASE="https://escenarios.adaptecca.es/thredds/fileServer/peninsula/Proyecciones_CMIP6_en_estaciones/Dato_diario/Temperatura"
DEST="${1:-./proyecciones_peninsula}"   # first argument overrides it; on Ladon we pass an absolute path
GROUP="SP-005"   # product identifier (a single group, holding every station)

MODELS=(ACCESS-CM2 CMCC-CM2-SR5 CNRM-ESM2-1 EC-Earth3-Veg IITM-ESM KACE-1-0-G MIROC6 MPI-ESM1-2-HR MRI-ESM2-0 NorESM2-MM UKESM1-0-LL)
SCENARIOS=(historical ssp126 ssp245 ssp370)
VARS=(tasmax tasmin)

mkdir -p "$DEST"
n_ok=0; n_fail=0; n_total=$(( ${#MODELS[@]} * ${#SCENARIOS[@]} * ${#VARS[@]} ))
echo "downloading $n_total files to $DEST"

for var in "${VARS[@]}"; do
  for model in "${MODELS[@]}"; do
    for scen in "${SCENARIOS[@]}"; do
      f="${var}_${GROUP}_${model}_${scen}_ESD-RegBA_day.nc"
      url="${BASE}/${var}/${f}"
      out="${DEST}/${f}"
      if [[ -s "$out" ]]; then echo "already there, skipping: $f"; n_ok=$((n_ok+1)); continue; fi
      echo "-> $f"
      # --continue resumes a cut download; the retries cover a one-off failure on a single file.
      # Note this only skips a file that already exists and is non-empty, so a truncated download
      # passes for good: 48_ladon_checksums.sh is what catches that.
      if wget --continue --tries=5 --waitretry=10 --timeout=120 -q -O "$out" "$url"; then
        n_ok=$((n_ok+1))
      else
        echo "   FAILED: $url"; rm -f "$out"; n_fail=$((n_fail+1))
      fi
    done
  done
done

echo "done: $n_ok ok, $n_fail failed of $n_total"
echo "total size:"; du -sh "$DEST"
