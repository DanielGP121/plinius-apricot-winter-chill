#!/usr/bin/env python3
"""
Derive the metrics the methodological deck quotes but no existing table exposes in metric/value form.

Why it exists: the deck builder reads metrics as (metric, value) pairs, and three of the things the
v3 deck has to say live in tables shaped differently. The interpolation error is one row per
situation in idw_crossval_summary.csv; the spread between models is one row per model in
per_model_cropland_km2.csv; and the effect of the aggregation order is a comparison between two
tables that nothing had computed. Typing any of them into the content file would put a number on a
slide that no table could contradict, which is the failure this project has already had once.

The aggregation-order comparison is the only genuinely new calculation here, and it answers a real
objection: the pipeline takes the median across models at the station and then classifies, so every
published area is a statistic of a surface no single model produced. Classifying each model first
and taking the median of the resulting areas is the alternative, and the difference between the two
is what this reports.

Requires: Python 3, standard library only.
Reads:  02_outputs/talk_numbers_cropland.csv, per_model_cropland_km2.csv,
        idw_crossval_summary.csv, idw_threshold_band.csv
Writes: 02_outputs/v3_numbers.csv

Usage:
    python 45_v3_numbers.py
"""

import csv
import io
import os
import statistics
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUTPUTS = os.path.join(os.path.dirname(HERE), "02_outputs")

HEADLINE_SIT = "ssp370_far"      # the situation every headline in the deck is drawn from
BASE_SIT = "presente_present"


def read(name):
    path = os.path.join(OUTPUTS, name)
    if not os.path.exists(path):
        sys.exit("missing %s\n  run scripts 19, 36 and 41 before this one" % path)
    with io.open(path, encoding="utf-8-sig", newline="") as fh:
        return list(csv.DictReader(fh))


def main():
    crop = {r["situation"]: r for r in read("talk_numbers_cropland.csv")}
    per = read("per_model_cropland_km2.csv")
    xval = {r["situation"]: r for r in read("idw_crossval_summary.csv")}
    band = {r["situation"]: r for r in read("idw_threshold_band.csv")}

    out = []

    def add(metric, value):
        out.append((metric, value))

    # --- how wrong the interpolation is, and how much land that puts in doubt --------------------
    for tag, sit in (("base", BASE_SIT), ("far", HEADLINE_SIT)):
        x = xval[sit]
        add("idw_rmse_%s_CP" % tag, round(float(x["rmse_CP"]), 2))
        add("idw_mae_%s_CP" % tag, round(float(x["mae_CP"]), 2))
        add("idw_r_%s" % tag, round(float(x["r"]), 3))
        add("idw_pct_of_gap_%s" % tag, round(float(x["pct_of_gap"]), 1))
        add("idw_n_stations_%s" % tag, int(x["n_stations"]))
        b = band[sit]
        add("idw_band_pct_%s" % tag, round(float(b["pct_near_any"]), 1))
        add("idw_band_km2_%s" % tag, round(float(b["km2_near_any"])))

    # --- the spread the ensemble median hides, on the unit every headline uses -------------------
    far_rows = [r for r in per if r["situation"] == HEADLINE_SIT]
    if len(far_rows) < 2:
        sys.exit("per_model_cropland_km2.csv has no per-model rows for %s" % HEADLINE_SIT)
    none_v = sorted(float(r["km2_none"]) for r in far_rows)
    only_v = sorted(float(r["km2_only_precoz"]) for r in far_rows)
    both_v = sorted(float(r["km2_both"]) for r in far_rows)
    add("spread_none_min_km2", round(none_v[0]))
    add("spread_none_max_km2", round(none_v[-1]))
    add("spread_none_ratio", round(none_v[-1] / none_v[0], 1))
    add("spread_only_min_km2", round(only_v[0]))
    add("spread_only_max_km2", round(only_v[-1]))
    add("spread_both_min_km2", round(both_v[0]))
    add("spread_both_max_km2", round(both_v[-1]))
    add("spread_n_models", len(far_rows))

    # --- does the order of aggregation change the answer? ----------------------------------------
    # Mapping the ensemble median (what the pipeline does) against classifying each model first and
    # taking the median of the eleven resulting areas. Reported per class and on the headline.
    e = crop[HEADLINE_SIT]
    pairs = (("both", "km2_both", "crop_km2_both"),
             ("only", "km2_only_precoz", "crop_km2_only_precoz"),
             ("none", "km2_none", "crop_km2_none"))
    worst = 0.0
    for tag, pcol, ecol in pairs:
        med = statistics.median(float(r[pcol]) for r in far_rows)
        ens = float(e[ecol])
        shift = 100.0 * (med - ens) / ens
        add("agg_%s_median_first_km2" % tag, round(ens))
        add("agg_%s_classify_first_km2" % tag, round(med))
        add("agg_%s_shift_pct" % tag, round(shift, 1))
        worst = max(worst, abs(shift))
    add("agg_max_abs_shift_pct", round(worst, 1))

    ens_head = 100.0 * float(e["crop_km2_only_precoz"]) / (
        float(e["crop_km2_only_precoz"]) + float(e["crop_km2_none"]))
    med_head = statistics.median(float(r["pct_rescued_of_lost"]) for r in far_rows)
    add("agg_headline_median_first_pct", round(ens_head, 1))
    add("agg_headline_classify_first_pct", round(med_head, 1))
    add("agg_headline_shift_points", round(med_head - ens_head, 1))

    # --- the surface itself, per class, for the headline situation --------------------------------
    for tag, col in (("both", "pct_both"), ("only", "pct_only_precoz"), ("none", "pct_none")):
        add("far_pct_%s" % tag, round(float(e[col]), 1))
    add("far_swc_median_CP", round(float(e["swc_median"]), 1))
    add("base_swc_median_CP", round(float(crop[BASE_SIT]["swc_median"]), 1))
    add("obs_swc_median_CP", round(float(crop["observaciones_present"]["swc_median"]), 1))

    dest = os.path.join(OUTPUTS, "v3_numbers.csv")
    with io.open(dest, "w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["metric", "value"])
        w.writerows(out)
    print("%s\n%d metrics" % (dest, len(out)))


if __name__ == "__main__":
    main()
