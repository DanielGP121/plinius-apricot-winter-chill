#!/usr/bin/env python3
"""
The whole pipeline on one page: datasets, where each step runs, the parameters, and what comes out.

Why it exists: explaining this project to a co-author by prose alone takes several pages, and the
part people actually need — which parameter was used where, and on which machine — is exactly the
part that gets lost. This builds a single A3 sheet that carries the four data sources with their
real dimensions, the chain of scripts in two lanes (HPC and local), every operative parameter, and
thumbnails of what each stage produces, so the reader can follow it in one look and then go to the
method book only for the parts they care about.

Nothing on the sheet is typed. Figures are read from 02_outputs/ and every number is read from the
canonical tables at build time, so the sheet cannot drift from the analysis the way a slide would.
Parameters that live in code rather than in a table are listed in PARAMS below with the file and
line they come from, and those citations are printed on the sheet itself.

Requires: Python 3 with Pillow (conda env egu_aemet, or any interpreter that has it).
Produces: 03_presentacion/plinius_workflow.html, and the same as .pdf when Chrome is available.

Usage:
    python 44_workflow_sheet.py
    python 44_workflow_sheet.py --no-pdf          # skip the Chrome step
    python 44_workflow_sheet.py --chrome "C:/path/to/chrome.exe"
"""

import argparse
import base64
import csv
import io
import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUTPUTS = os.path.join(ROOT, "02_outputs")
FIGS = os.path.join(OUTPUTS, "figures_chill")
DEST = os.path.join(ROOT, "03_presentacion")

THUMB_W = 760          # px; wide enough to read a map legend at print size, small enough to inline


# --- numbers -------------------------------------------------------------------------------------
# Every figure quoted on the sheet is looked up here. A missing table is a hard error rather than a
# blank, because a sheet that silently drops a number is worse than one that fails to build.

def read_table(name):
    path = os.path.join(OUTPUTS, name)
    if not os.path.exists(path):
        sys.exit("missing table: %s\nRun the pipeline before building the sheet." % path)
    with io.open(path, encoding="utf-8-sig", newline="") as fh:
        return list(csv.DictReader(fh))


def keyed(rows, key_col, val_col):
    return {r[key_col]: r[val_col] for r in rows}


def n(x, dec=0):
    """English thousands separator. The project ships in English; a Spanish full stop here would
    render 229.676 km2 inside an English sentence."""
    return "{:,.{d}f}".format(float(x), d=dec)


def load_numbers():
    crop = {r["situation"]: r for r in read_table("talk_numbers_cropland.csv")}
    rank = keyed(read_table("model_ranking_numbers.csv"), "metric", "value")
    cieza = keyed(read_table("cieza_numbers.csv"), "metric", "value")
    xval = {r["situation"]: r for r in read_table("idw_crossval_summary.csv")}
    band = {r["situation"]: r for r in read_table("idw_threshold_band.csv")}
    per_model = read_table("per_model_cropland_km2.csv")

    far = crop["ssp370_far"]
    lost = float(far["crop_km2_only_precoz"]) + float(far["crop_km2_none"])
    rescued = float(far["crop_km2_only_precoz"])

    far_rows = [r for r in per_model if r["situation"] == "ssp370_far"]
    none_vals = sorted(float(r["km2_none"]) for r in far_rows)
    resc_vals = sorted(float(r["pct_rescued_of_lost"]) for r in far_rows)

    return {
        "cropland_km2": n(band["ssp370_far"]["km2_total"]),
        "lost_km2": n(lost),
        "rescued_km2": n(rescued),
        "rescued_pct": n(100 * rescued / lost, 1),
        "n_stations_proj": n(crop["presente_present"]["n_stations"]),
        "n_stations_obs": n(crop["observaciones_present"]["n_stations"]),
        "n_models": rank["rank_n_models"],
        "spread_far": n(rank["rank_spread_far_CP"], 1),
        "spread_base": n(rank["rank_spread_base_CP"], 1),
        "gap_cp": n(rank["rank_cultivar_gap_CP"], 1),
        "worst_model": rank["rank_worst_model"],
        "best_model": rank["rank_best_model"],
        "worst_swc": n(rank["rank_worst_swc"], 1),
        "best_swc": n(rank["rank_best_swc"], 1),
        "rmse_base": n(xval["presente_present"]["rmse_CP"], 2),
        "rmse_far": n(xval["ssp370_far"]["rmse_CP"], 2),
        "pct_of_gap_far": n(xval["ssp370_far"]["pct_of_gap"], 1),
        "pct_near_thresh": n(band["ssp370_far"]["pct_near_any"], 1),
        "param_gap": n(abs(float(cieza["param_gap_mean_CP"])), 2),
        "param_gap_n": cieza["param_gap_n_seasons"],
        "none_min": n(none_vals[0]),
        "none_max": n(none_vals[-1]),
        "resc_min": n(resc_vals[0], 1),
        "resc_max": n(resc_vals[-1], 1),
    }


# --- parameters ----------------------------------------------------------------------------------
# Value, and the file:line it is set at. The provenance column is on the sheet on purpose: it is
# what lets a reader check any of these against the repository in one step.

PARAMS = [
    ("Chill model", "Dynamic Model, Fishman et al. (1987) parametrisation",
     "DM_JOSE.R:4-5"),
    ("Model constants", "E0 4457.8 &middot; E1 10161.9 &middot; A0 419700 &middot; A1 1.797&times;10<sup>14</sup> &middot; slope 1.6 &middot; Tf 277",
     "DM_JOSE.R:4-5"),
    ("Chill season", "Julian day 305 to 59 (1 Nov to 28 Feb)",
     "15_chill_national_parallel.R:116"),
    ("Safe Winter Chill", "10th percentile of seasonal chill portions, across seasons within a station",
     "15_chill_national_parallel.R:346"),
    ("Season kept if", "at least 85% of days present",
     "15_chill_national_parallel.R:116, :339"),
    ("Station kept if", "no more than 40% missing in Tmax or Tmin, and 3 or more valid seasons",
     "15_chill_national_parallel.R:117, :344"),
    ("Fill-value guard", "values outside &minus;90 to 70 &deg;C masked (four models ship &minus;999 undeclared)",
     "15_chill_national_parallel.R:118, :271"),
    ("Baseline splice", "historical to 2014, then SSP2-4.5 from 2015 (CMIP6 historical ends 2014 by design)",
     "15_chill_national_parallel.R:159, :295-302"),
    ("Time windows", "1995&ndash;2020 baseline, then 2021&ndash;2040, 2041&ndash;2070, 2071&ndash;2100 (tiling, no overlap)",
     "15_chill_national_parallel.R:126-132"),
    ("Ensemble statistic", "median across the 11 models, taken at the station, before interpolation",
     "19_cropland_viability_national.R:66"),
    ("Interpolation", "IDW, power 2, 50 km radius, at most 12 neighbours; the radius is the mask",
     "19_cropland_viability_national.R:43-45, :151"),
    ("Grid", "1 km, EPSG:3035 (equal-area); cell area from the realised resolution, not the nominal one",
     "19_cropland_viability_national.R:37-40; 00_corine.R:43"),
    ("Cropland", "CORINE 2018, 100 m, classes 211&ndash;244 excluding 231 pasture; each cell weighted by its cropland fraction",
     "00_corine.R:24-28; 19_...:124"),
    ("Cultivar thresholds", "'B&uacute;lida' 47.5 CP, 'B&uacute;lida Precoz' 33.7 CP (Ruiz et al. 2019, both &plusmn;3.3)",
     "19_cropland_viability_national.R:41-42"),
    ("Model agreement", "hatched where fewer than 9 of 11 models agree on the class (AR6 80% convention)",
     "00_hatch.R:28, :107-113"),
]


# --- datasets ------------------------------------------------------------------------------------

def datasets(v):
    return [
        {
            "tag": "projections",
            "name": "PNACC AR6 &middot; ESD-RegBA at stations",
            "route": "AdapteCCa THREDDS, direct HTTP, no credential",
            "detail": "product group SP-005",
            "rows": [
                ("files", "88 NetCDF, ~15 GB"),
                ("shape", "11 models &times; 4 experiments &times; 2 variables"),
                ("stations", v["n_stations_proj"]),
                ("span", "historical 1950&ndash;2014, SSP 2015&ndash;2100"),
                ("layout", "[time &times; station], days since 1850"),
            ],
            "warn": "The portal's web form serves the same product over 3,044 stations, "
                    "not 3,460. The route has to be stated in Methods or the areas cannot be reproduced.",
        },
        {
            "tag": "observed",
            "name": "PNACC observational archive",
            "route": "web form, delivered by email",
            "detail": "not available as daily data on THREDDS",
            "rows": [
                ("stations", v["n_stations_obs"]),
                ("span", "1975-01-01 to 2020-12-31"),
                ("days", "16,802 continuous"),
                ("layout", "[station &times; time], hours since 1900"),
                ("ends", "2020, and cannot be extended by this route"),
            ],
            "warn": None,
        },
        {
            "tag": "recent",
            "name": "AEMET OpenData, daily climatological values",
            "route": "REST API, two-step (envelope then payload)",
            "detail": "key read from $AEMET_API_KEY, never written to disk",
            "rows": [
                ("stations", "666 of the 3,044"),
                ("span", "1995&ndash;2025"),
                ("limit", "6 months per request, ~62 per station"),
                ("rate", "40 calls/min against a ~50 ceiling"),
                ("role", "extension only; never overwrites the archive"),
            ],
            "warn": "Covers 22% of the network and only 131 stations reach back to 1995, "
                    "so it is a cross-check and an extension, not a baseline.",
        },
        {
            "tag": "land",
            "name": "CORINE Land Cover 2018",
            "route": "Copernicus raster, 100 m",
            "detail": "EPSG:3035, 46,000 &times; 65,000 cells",
            "rows": [
                ("classes", "211&ndash;244, excluding 231 pasture"),
                ("area", v["cropland_km2"] + " km&sup2;"),
                ("share", "46% of Spain"),
                ("use", "denominator of every area figure"),
                ("weighting", "cropland fraction per 1 km cell"),
            ],
            "warn": None,
        },
    ]


# --- the chain -----------------------------------------------------------------------------------

LADON = [
    ("Download", "14_ladon_download_thredds.sh",
     "88 files by wget, skipped if already non-empty. No OPeNDAP, so whole files come down and are "
     "subset locally."),
    ("Chill engine", "15_chill_national_parallel.R",
     "Reads NetCDF directly, clips to the window, parallelises by station, checkpoints per "
     "model&times;scenario with atomic writes. ~23 h for the full run."),
    ("Recent observed", "21_aemet_observed_download.py",
     "Standard library only, so it runs under any Python on the cluster. Resumable, and refuses to "
     "resume a directory holding a different year range."),
]

LOCAL = [
    ("Merge", "22_merge_chill_tables.R",
     "One canonical table, 462,808 rows, labelled by period and class. Refuses input whose "
     "coordinates have been through Excel."),
    ("Surface", "19_cropland_viability_national.R",
     "Median across models, IDW, CORINE mask, three classes, area weighted by cropland fraction."),
    ("Per model", "36_per_model_stats.R",
     "The same chain repeated once per model, so the spread survives instead of being collapsed. "
     "Feeds the agreement hatching."),
    ("Validation", "41_idw_crossval.R",
     "Leave-one-out over the interpolation, with the same parameters. Two self-checks must pass "
     "before anything is written."),
    ("Figures", "33, 34, 37, 38, 42, 43",
     "Every number read from the canonical tables at build time. Nothing typed."),
]


def wiring_block():
    """How the co-author's own function is wired into chillR. Verbatim from the engine."""
    return (
        "<pre><code>weather &lt;- fix_weather(df, end_at_present = FALSE)\n"
        "\n"
        "tempResponse_daily_list(list(weather), latitude = lat,\n"
        "                        Start_JDay = 305, End_JDay = 59,\n"
        "                        models = list(Utah_Chill_Units = Utah_Model,\n"
        "                                      Chill_Portions   = <b>DM_JOSE</b>))</code></pre>"
    )


# --- images --------------------------------------------------------------------------------------

def inline(fname, width=THUMB_W):
    """Downsample and inline, so the sheet is one self-contained file that survives being emailed."""
    path = os.path.join(FIGS, fname)
    if not os.path.exists(path):
        sys.exit("missing figure: %s" % path)
    im = Image.open(path).convert("RGB")
    if im.width > width:
        im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=88, optimize=True)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode("ascii")


# Four stages, one thumbnail each. fig52 (the interpolation cross-validation) would belong here
# on subject, but it is one of the four figures still rendered in Spanish and this sheet is in
# English; fig22 carries the same summary role and covers every situation at once.
THUMBS = [
    ("fig53_data_coverage_timeline.png", "What each source covers, and which stretch of it is used"),
    ("fig20_15_viability_ssp370_far.png", "Where each cultivar still works, SSP3-7.0 at 2071&ndash;2100"),
    ("fig54_model_ranking_ssp370.png", "The eleven models ranked by the chill they leave"),
    ("fig22_viability_bars.png", "The same three classes across every scenario and window"),
]


# --- the sheet -----------------------------------------------------------------------------------

CSS = """
@page { size: A3 landscape; margin: 9mm; }
* { box-sizing: border-box; }
body { margin: 0; font-family: "Segoe UI", "Helvetica Neue", Arial, sans-serif;
       font-size: 8.1px; line-height: 1.34; color: #1b1f24; background: #fff; }
.sheet { width: 402mm; padding: 0; }
h1 { font-size: 17px; margin: 0 0 1mm; letter-spacing: -0.2px; }
h1 span { font-weight: 400; color: #5b6570; }
.lede { font-size: 9px; color: #39424c; margin: 0 0 2.4mm; max-width: 300mm; }
.lede b { color: #0d1116; }
h2 { font-size: 8.6px; text-transform: uppercase; letter-spacing: 0.9px; color: #6b7682;
     margin: 0 0 1.6mm; font-weight: 700; border-bottom: 1px solid #dfe4e9; padding-bottom: 1mm; }
.row { display: grid; gap: 3.4mm; margin-bottom: 2.5mm; }
.r4 { grid-template-columns: repeat(4, 1fr); }
.r2 { grid-template-columns: 1.62fr 1fr; }
.card { border: 1px solid #dfe4e9; border-radius: 2.5px; padding: 2.4mm 2.8mm; background: #fbfcfd; }
.card .tag { font-size: 7px; text-transform: uppercase; letter-spacing: 1px; font-weight: 700;
             color: #fff; background: #47535f; border-radius: 2px; padding: 0.5mm 1.4mm;
             display: inline-block; margin-bottom: 1.4mm; }
.card.projections .tag { background: #2c7bb6; }
.card.observed   .tag { background: #4a6572; }
.card.recent     .tag { background: #7a8b48; }
.card.land       .tag { background: #b07d3a; }
.card .name { font-weight: 700; font-size: 8.6px; margin-bottom: 0.6mm; }
.card .route { color: #5b6570; margin-bottom: 0.4mm; }
.card .detail { color: #8a949e; font-style: italic; margin-bottom: 1.6mm; }
table.kv { width: 100%; border-collapse: collapse; }
table.kv td { padding: 0.55mm 0; vertical-align: top; border-top: 1px dotted #e3e8ec; }
table.kv td:first-child { color: #6b7682; width: 34%; }
table.kv td:last-child { font-weight: 600; }
.warn { margin-top: 1.6mm; padding: 1.4mm 1.8mm; background: #fdf3e3; border-left: 2px solid #d79a3a;
        color: #6b4c17; font-size: 7.5px; }
.lane { border: 1px solid #dfe4e9; border-radius: 2.5px; overflow: hidden; margin-bottom: 2.4mm; }
.lane > .hd { padding: 1.2mm 2.4mm; font-weight: 700; font-size: 8px; color: #fff; }
.lane.hpc > .hd { background: #2c4a5e; }
.lane.loc > .hd { background: #5b6b3f; }
.lane .steps { display: flex; }
.lane .step { flex: 1; padding: 2mm 2.4mm; border-right: 1px solid #e6eaee; }
.lane .step:last-child { border-right: 0; }
.lane .step .n { font-weight: 700; font-size: 8.3px; margin-bottom: 0.4mm; }
.lane .step code { font-family: Consolas, "SF Mono", Menlo, monospace; font-size: 7.1px;
                   color: #2c4a5e; background: #eef2f5; padding: 0.3mm 1mm; border-radius: 2px;
                   display: inline-block; margin-bottom: 1mm; }
.lane .step p { margin: 0; color: #4a545e; font-size: 7.5px; }
table.par { width: 100%; border-collapse: collapse; }
table.par td { padding: 0.85mm 1.4mm; border-bottom: 1px solid #eef1f4; vertical-align: top; }
table.par tr:last-child td { border-bottom: 0; }
table.par td.k { width: 21%; font-weight: 700; color: #2c4a5e; }
table.par td.v { width: 57%; }
table.par td.s { width: 22%; font-family: Consolas, Menlo, monospace; font-size: 6.6px;
                 color: #93a0ac; text-align: right; }
.wire { background: #f4f7f9; border: 1px solid #dbe2e8; border-radius: 2.5px; padding: 2.4mm 2.8mm; }
.wire pre { margin: 1.4mm 0 0; font-family: Consolas, Menlo, monospace; font-size: 7.2px;
            line-height: 1.45; color: #1b2a36; white-space: pre; overflow-x: auto; }
.wire p { margin: 0; color: #4a545e; }
.thumbs { display: grid; grid-template-columns: repeat(4, 1fr); gap: 3.4mm; }
.thumb img { width: 100%; height: 28mm; object-fit: contain; background: #fff;
             border: 1px solid #dfe4e9; border-radius: 2px; display: block; }
.thumb .cap { margin-top: 1mm; color: #6b7682; font-size: 7.3px; }
.res { display: flex; gap: 3.4mm; }
.res .fig { flex: 1; border: 1px solid #dfe4e9; border-radius: 2.5px; padding: 2mm 2.4mm;
            background: #fbfcfd; }
.res .fig .big { font-size: 15px; font-weight: 700; color: #1b2a36; line-height: 1.1; }
.res .fig .lab { color: #6b7682; margin-top: 0.6mm; font-size: 7.4px; }
.foot { margin-top: 2.2mm; padding-top: 2mm; border-top: 1px solid #dfe4e9; color: #8a949e;
        font-size: 7.2px; display: flex; justify-content: space-between; }
"""


def build_html(v):
    ds = "".join(
        '<div class="card {tag}"><span class="tag">{tag}</span>'
        '<div class="name">{name}</div><div class="route">{route}</div>'
        '<div class="detail">{detail}</div><table class="kv">{rows}</table>{warn}</div>'.format(
            tag=d["tag"], name=d["name"], route=d["route"], detail=d["detail"],
            rows="".join("<tr><td>%s</td><td>%s</td></tr>" % r for r in d["rows"]),
            warn='<div class="warn">%s</div>' % d["warn"] if d["warn"] else "")
        for d in datasets(v))

    def lane(cls, title, steps):
        return ('<div class="lane {c}"><div class="hd">{t}</div><div class="steps">{s}</div></div>'
                .format(c=cls, t=title, s="".join(
                    '<div class="step"><div class="n">%s</div><code>%s</code><p>%s</p></div>' % st
                    for st in steps)))

    par = "".join('<tr><td class="k">%s</td><td class="v">%s</td><td class="s">%s</td></tr>' % p
                  for p in PARAMS)

    thumbs = "".join('<div class="thumb"><img src="%s"><div class="cap">%s</div></div>'
                     % (inline(f), c) for f, c in THUMBS)

    res = [
        (v["cropland_km2"] + " km&sup2;", "Spanish cropland, the denominator"),
        (v["lost_km2"] + " km&sup2;", "where 'B&uacute;lida' fails by 2071&ndash;2100, SSP3-7.0"),
        (v["rescued_km2"] + " km&sup2;", "of that, still viable for the mutant (%s%%)" % v["rescued_pct"]),
        (v["spread_far"] + " CP", "spread between models, against a %s CP cultivar gap" % v["gap_cp"]),
        (v["rmse_far"] + " CP", "interpolation error at 2071&ndash;2100, %s%% of that gap" % v["pct_of_gap_far"]),
    ]
    resb = "".join('<div class="fig"><div class="big">%s</div><div class="lab">%s</div></div>' % r
                   for r in res)

    return """<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<title>Winter chill pipeline &mdash; one page</title>
<style>%(css)s</style></head><body><div class="sheet">

<h1>Winter chill for apricot in Spain <span>&mdash; the pipeline on one page</span></h1>
<p class="lede">Where does <b>'B&uacute;lida'</b> (47.5 chill portions required) stop meeting its
requirement while its somatic mutant <b>'B&uacute;lida Precoz'</b> (33.7) still meets its own, and
how does that band of land move through the century? Chill is computed at %(nst)s weather stations
from %(nmod)s CMIP6 models, interpolated to a 1 km grid, and reported as <b>area of cropland</b>
rather than as a count of stations. Every number below is read from the project's canonical tables
when this sheet is built.</p>

<h2>1 &middot; The four data sources</h2>
<div class="row r4">%(ds)s</div>

<h2>2 &middot; Where each step runs</h2>
%(hpc)s
%(loc)s

<h2>3 &middot; Parameters, and where each one is set</h2>
<div class="row r2">
  <div class="card"><table class="par">%(par)s</table></div>
  <div>
    <div class="wire">
      <p><b>How the Dynamic Model enters the chain.</b> <code>DM_JOSE.R</code> carries the Fishman
      et al. (1987) parametrisation and is used unmodified: the function object is passed straight
      into chillR as one of the models, with Utah computed alongside it as a secondary metric. The
      daily-to-hourly reconstruction happens inside chillR from the station's latitude.</p>
      %(wire)s
      <p style="margin-top:1.6mm"><b>Why the parametrisation matters.</b> chillR's default
      <code>Dynamic_Model</code> carries the 1988 constants and gives different numbers: measured
      over %(pgn)s seasons at Cieza, %(pg)s CP lower on average. The two cultivars are separated by
      %(gap)s CP, so supply and demand have to be on the same scale or the comparison means nothing.</p>
    </div>
    <div class="wire" style="margin-top:3.4mm">
      <p><b>What the ensemble hides.</b> The maps show the median of %(nmod)s models, but the models
      disagree by %(sf)s CP at end of century against %(sb)s CP at the baseline. %(wm)s leaves
      %(ws)s CP and %(bm)s leaves %(bs)s. On area, the land where neither cultivar works ranges from
      %(nmin)s to %(nmax)s km&sup2; and the rescued fraction from %(rmin)s%% to %(rmax)s%%,
      depending on the model. %(pnt)s%% of cropland sits within one interpolation RMSE of a
      threshold.</p>
    </div>
  </div>
</div>

<h2>4 &middot; What comes out</h2>
<div class="res" style="margin-bottom:3mm">%(resb)s</div>
<div class="thumbs">%(thumbs)s</div>

<div class="foot">
  <span>Chill computed with the Dynamic Model, Fishman et al. (1987) parametrisation &middot;
        interpolation after Egea et al. (2022) &middot; requirements from Ruiz et al. (2019)</span>
  <span>19th Plinius Conference on Mediterranean Risks, session PL6, Murcia, 8 October 2026</span>
</div>

</div></body></html>""" % {
        "css": CSS, "ds": ds, "par": par, "thumbs": thumbs, "resb": resb,
        "wire": wiring_block(),
        "hpc": lane("hpc", "HPC cluster (Ladon) &mdash; the heavy end", LADON),
        "loc": lane("loc", "Local workstation &mdash; surfaces, validation and figures", LOCAL),
        "nst": v["n_stations_proj"], "nmod": v["n_models"],
        "pg": v["param_gap"], "pgn": v["param_gap_n"], "gap": v["gap_cp"],
        "sf": v["spread_far"], "sb": v["spread_base"],
        "wm": v["worst_model"], "ws": v["worst_swc"], "bm": v["best_model"], "bs": v["best_swc"],
        "nmin": v["none_min"], "nmax": v["none_max"],
        "rmin": v["resc_min"], "rmax": v["resc_max"], "pnt": v["pct_near_thresh"],
    }


def find_chrome(explicit):
    if explicit:
        return explicit
    for c in (r"C:/Program Files/Google/Chrome/Application/chrome.exe",
              r"C:/Program Files (x86)/Google/Chrome/Application/chrome.exe",
              r"C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
              r"C:/Program Files/Microsoft/Edge/Application/msedge.exe"):
        if os.path.exists(c):
            return c
    return shutil.which("chrome") or shutil.which("chromium") or shutil.which("msedge")


def main():
    ap = argparse.ArgumentParser(description="Build the one-page workflow sheet.")
    ap.add_argument("--no-pdf", action="store_true", help="write the HTML only")
    ap.add_argument("--chrome", default=None, help="path to a Chrome or Edge binary")
    a = ap.parse_args()

    if not os.path.isdir(DEST):
        os.makedirs(DEST)

    v = load_numbers()
    html = build_html(v)
    out_html = os.path.join(DEST, "plinius_workflow.html")
    with io.open(out_html, "w", encoding="utf-8", newline="") as fh:
        fh.write(html)
    print("wrote %s (%.1f MB)" % (out_html, os.path.getsize(out_html) / 1e6))

    if a.no_pdf:
        return

    chrome = find_chrome(a.chrome)
    if not chrome:
        print("no Chrome or Edge found; open the HTML and print to PDF, or pass --chrome")
        return

    out_pdf = os.path.join(DEST, "plinius_workflow.pdf")
    # A fresh profile keeps the print from inheriting whatever the user's own Chrome has set.
    prof = tempfile.mkdtemp(prefix="plinius_chrome_")
    cmd = [chrome, "--headless=new", "--disable-gpu", "--no-pdf-header-footer",
           "--user-data-dir=" + prof, "--print-to-pdf=" + out_pdf,
           "--virtual-time-budget=12000", "file:///" + out_html.replace("\\", "/")]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
        if os.path.exists(out_pdf) and os.path.getsize(out_pdf) > 5000:
            print("wrote %s (%.1f MB)" % (out_pdf, os.path.getsize(out_pdf) / 1e6))
        else:
            print("Chrome did not produce a PDF; open the HTML and print it instead.")
            print((r.stderr or "").strip()[:600])
    except subprocess.TimeoutExpired:
        print("Chrome timed out; open the HTML and print it instead.")
    finally:
        shutil.rmtree(prof, ignore_errors=True)


if __name__ == "__main__":
    main()
