# Winter chill for apricot in Spain, and what a low-chill mutant buys

Where does the apricot cultivar **'Búlida'** stop meeting its winter chill requirement while its
somatic mutant **'Búlida Precoz'** still meets its own, and how does that band of land move through
the century?

This repository holds the code behind a talk at the **19th Plinius Conference on Mediterranean
Risks** (session PL6, Murcia, 8 October 2026). It computes winter chill from Spanish station data,
observed from 1976 to 2025 and projected to 2100 under three CMIP6 scenarios, and expresses the
answer as **area of cultivable land** rather than as a count of weather stations.

> **Status.** Work in progress towards the talk. The numbers below are current as of August 2026
> and reconcile with the tables in `02_outputs/`.

**In a hurry?** [`03_presentacion/plinius_workflow.pdf`](03_presentacion/plinius_workflow.pdf) is
the whole pipeline on one page: the four data sources with their real dimensions, which step runs
on the cluster and which locally, every operative parameter with the line of code that sets it,
and a thumbnail of what each stage produces.

---

## Cropland viable for each cultivar, 2071-2100 under SSP3-7.0

Of Spain's **229,676 km²** of cropland:

| | km² | |
|---|---:|---|
| 'Búlida' stops being viable on | **45,103** | 19.6% of cropland |
| of which 'Búlida Precoz' still works on | **23,310** | **51.7% of the loss** |
| neither cultivar viable | 21,794 | 9.5% of cropland |

Across the eleven climate models the rescued fraction runs from **39.1% to 82.1%**, and none falls
below a third. That is the most robust number here, because it rests on the *gap* between the two
cultivars rather than on either absolute threshold. Under SSP1-2.6 the mutant rescues 89.3% of a
smaller loss. **It buys time, not immunity.**

Two secondary findings:

- **Model spread exceeds scenario spread in the near term.** On the 446 stations whose chill sits
  near the 'Búlida' threshold at 2021-2040, the three scenarios differ by 2.7 chill portions and
  the eleven models by 13.4, five times as much.
- **The last five winters are the mildest five-year stretch of the observed fifty.** 1976-2020
  shows no trend (p = 0.90); 2021-2025 sits 3.65 chill portions below it, 1.95 standard deviations,
  and none of the 41 five-year blocks in the baseline reaches as low.

---

## Quick start

```bash
git clone <this repo> && cd <this repo>
Rscript install_deps.R                       # 18 R packages; see the file for the chillR recipe
conda env create -f environment.yml          # Python side, only needed for scripts 02, 05, 07, 21, 30
cp .env.example .env                         # then fill in PLINIUS_DATA
```

Read [`00_data/README.md`](00_data/README.md) next: the input data is not here and cannot be, and
that file says how to obtain each source. Every script fails on its first line with instructions
rather than halfway through with something cryptic.

```bash
export PLINIUS_DATA=/path/to/plinius_data
Rscript 01_scripts/19_cropland_viability_national.R   # interpolate, cross with CORINE, classify
```

That one runs from `02_outputs/chill_all_windows.csv`, which **is** in this repository, so the maps
and the areas above can be reproduced without the cluster.

---

## From station temperature to classified cropland

```mermaid
flowchart TD
    subgraph SRC["Sources, none of them in this repository"]
        A1["PNACC AR6 projections<br/>11 models x 3 SSP + historical<br/>3460 stations, 88 NetCDF, 15 GB"]
        A2["PNACC observed archive<br/>3044 stations, 1975-2020"]
        A3["AEMET OpenData<br/>666 stations, reaches 2025"]
        A4["CORINE Land Cover 2018<br/>100 m raster"]
    end

    subgraph HPC["On the HPC: heavy compute"]
        B1["14 download_thredds"]
        B2["15 chill_national_parallel<br/>reads NetCDF, windows it,<br/>parallel by station, checkpoints"]
        B3["21 aemet_observed_download<br/>two-step API, 6-month chunks"]
    end

    subgraph LOC["Local: everything else"]
        C1["22 merge_chill_tables"]
        C2["19 cropland_viability<br/>IDW + CORINE + classify"]
        C3["28 threshold_sweep"]
        D1["23 chill_from_api"]
        D2["24 api_vs_archive<br/>are the two sources the same?"]
        D3["25 splice 1995-2025"]
        D4["26 long record 1976-2025"]
        D5["27 cieza independent check"]
        C4["36 per_model_stats<br/>the same chain, once per model"]
        C5["41 idw_crossval<br/>leave-one-out over the interpolation"]
        E1["29 / 30 working document<br/>35 the talk, 44 the one-page sheet"]
    end

    A1 --> B1 --> B2 --> C1 --> C2 --> C3
    A2 --> B2
    A3 --> B3 --> D1 --> D2 --> D3 --> D4
    A4 --> C2
    B2 -->|per-season mode| D2
    D4 --> D5
    C1 --> C4
    C2 --> C5
    C4 --> E1
    C5 --> E1
    C2 --> E1
    D4 --> E1
```

Reading 15 GB of NetCDF and computing chill for 3460 stations across 45 model-scenario combinations
takes about a day, so it happens where the data lives; what comes back are chill tables of a few
megabytes.

```mermaid
flowchart LR
    T["Daily Tmax / Tmin<br/>per station"] --> F["fix_weather<br/>end_at_present = FALSE"]
    F --> R["tempResponse_daily_list<br/>JDay 305-59, 1 Nov to 28 Feb"]
    R --> M["Dynamic Model<br/>Fishman et al. 1987<br/>+ Utah units"]
    M --> S["Chill portions<br/>one value per winter"]
    S --> Q["Safe Winter Chill<br/>P10 across seasons"]
    Q --> I["IDW interpolation<br/>power 2, 50 km mask, 1 km grid"]
    I --> X["Cross with CORINE cropland"]
    X --> V["Classify each cell:<br/>both / mutant only / neither"]
```

Why each step is the way it is, and what was checked, is in the method book sources under
[`04_metodo/`](04_metodo/): the chill model in `07-modelo-dinamico.Rmd`, the percentile in
`08-agregacion.Rmd`, the interpolation and its error in `09-superficie.Rmd`, and the window choices
in `05-descarga.Rmd`.

### Parameters, and the line that sets each

| | Value | Set at |
|---|---|---|
| Chill model | Dynamic Model, Fishman et al. (1987) parametrisation | `DM_JOSE.R:4-5` |
| Model constants | E0 4457.8, E1 10161.9, A0 419700, A1 1.797e14, slope 1.6, Tf 277 | `DM_JOSE.R:4-5` |
| Chill season | Julian day 305 to 59, 1 November to 28 February | `15_chill_national_parallel.R:116` |
| Safe Winter Chill | 10th percentile of seasonal chill portions, across seasons within a station | `15_...:346` |
| Season kept if | at least 85% of days present | `15_...:116, :339` |
| Station kept if | no more than 40% missing in either variable, and 3 or more valid seasons | `15_...:117, :344` |
| Fill-value guard | values outside -90 to 70 C masked; four models ship -999 undeclared | `15_...:118, :271` |
| Baseline splice | historical to 2014, then SSP2-4.5 from 2015 | `15_...:159, :295-302` |
| Analysis windows | 1995-2020, then 2021-2040, 2041-2070, 2071-2100 | `15_...:126-132` |
| Ensemble statistic | median across the 11 models, at the station, before interpolation | `19_cropland_viability_national.R:66` |
| Interpolation | IDW, power 2, 50 km radius, at most 12 neighbours; the radius *is* the mask | `19_...:43-45, :151` |
| Grid | 1 km, EPSG:3035; cell area from the realised resolution, not the nominal one | `19_...:37-40`, `00_corine.R:43` |
| Cropland | CORINE 2018 classes 211-244 excluding 231; each cell weighted by its cropland fraction | `00_corine.R:24-28` |
| Cultivar thresholds | 47.5 and 33.7 chill portions, both with a standard error of 3.3 | `19_...:41-42` |
| Model agreement | hatched where fewer than 9 of 11 models agree on the class, the AR6 80% convention | `00_hatch.R:28, :107-113` |

---

## What `02_outputs/` contains, and what it does not

**Versioned, and enough to recompute every number quoted above:**

| | What it is |
|---|---|
| `chill_all_windows.csv` | Safe Winter Chill per station, model and situation. Every map and every area comes from this |
| `chill_obs_seasons.csv`, `_1975.csv`, `chill_api_seasons.csv` | The observed record, season by season |
| `idw_crossval.csv` | Leave-one-out error of the interpolation, station by station |
| 38 metric tables | One or two kilobytes each, `(metric, value)` pairs. Every figure on every slide is read from one of these at build time rather than typed |

**Not versioned:** the per-window chill runs, which `22_merge_chill_tables.R` merges into
`chill_all_windows.csv`; the raw AEMET API download, superseded by the seasonal tables; the figures
and the GIFs, rebuilt by scripts 19 and 31-43; and the station coordinates compiled by the regional
agrometeorological services, which came through a third party with no terms of transfer.

---

## The scripts

All in [`01_scripts/`](01_scripts/). Numbering is chronological, so it has gaps and does not match
execution order: 22 runs before 19, and 01, 03, 04, 16, 17, 18 and 20 never existed. Every file
carries a header stating what it does, what it needs and what it writes.

| | Script | Runs on | What it does |
|---|---|---|---|
| | `00_paths.R` | — | Resolves every path; sourced by the rest |
| | `DM_JOSE.R` | — | The chill model. **Not in this repository**, see below |
| **Murcia test-run** | `02_pnacc_to_tables.py` | local | NetCDF to tidy per-station tables |
| | `05_cropland_filter.py`, `07_soil_decision_map.py` | local | Soil criterion by CORINE buffer |
| | `06_chill_murcia.R`, `08_chill_maps_murcia.Rmd` | local | Regional chill and its report |
| | `09`-`13_*cropland*` | local | Cropland maps at 500 m and 100 m |
| **National** | `14_ladon_download_thredds.sh` | HPC | 88 NetCDF from THREDDS |
| | `15_chill_national_parallel.R` | HPC | **The chill engine.** Windows, splicing, checkpoints |
| | `22_merge_chill_tables.R` | local | Merges the runs into the canonical table |
| | `19_cropland_viability_national.R` | local | IDW, CORINE, classification, maps |
| | `28_threshold_sweep_cropland.R` | local | Viable km² for any chill requirement |
| **Observed** | `21_aemet_observed_download.py` | HPC | AEMET OpenData, resumable |
| | `23_chill_from_api.R` | local | Chill per season from those CSVs |
| | `24_observed_api_vs_archive.R` | local | Paired comparison of the two sources |
| | `25_splice_observed_1995_2025.R` | local | The splice and its effect |
| | `26_observed_long_record.R` | local | 1976-2025: trend, ranking, blocks |
| | `27_cieza_independent_check.R` | local | Check outside the AEMET network |
| **Ensemble** | `36_per_model_stats.R` | local | The whole chain repeated once per model, and the agreement rasters |
| | `41_idw_crossval.R` | local | Leave-one-out error of the interpolation |
| **Shared** | `00_corine.R`, `00_hatch.R`, `00_map_layout.R` | local | Cropland mask and cell area, AR6 agreement hatching, figure geometry |
| **Figures** | `31_scenario_frames.R`, `32_make_gifs.py` | local | Animation frames and the GIFs built from them |
| | `33`, `34`, `37`, `38`, `39`, `40`, `42`, `43` | local | Talk and method figures, the pipeline diagram, the attrition funnel, the data timeline, the model ranking |
| **Reporting** | `29_build_deck.R`, `30_build_pptx.py` | local | Working document, HTML and PowerPoint |
| | `talk_content.py`, `35_build_talk_pptx.py` | local | The talk's content, and the builder that lays it out |
| | `45_v3_numbers.py`, `46_model_sensitivity.R`, `47_band_and_record_numbers.R` | local | Metrics the review decks quote |
| | `44_workflow_sheet.py` | local | The whole pipeline on one A3 page |

`35_build_talk_pptx.py` builds every deck from the one narrative file, so none of them can quote a
different number from another, and every figure on every slide is read from a table at build time.

Script 15 carries several protections that exist because of failures that actually happened: a
checkpoint per model-scenario combination written atomically, a sentinel that refuses to save a
combination where a parallel worker died, a reader that detects the NetCDF layout instead of
assuming it, and a mask for undeclared `-999` fill values.

---

## What this repository does not contain

**The data.** Gigabytes, third-party licences. [`00_data/README.md`](00_data/README.md) says how to
obtain each source and [`THIRD_PARTY.md`](THIRD_PARTY.md) records who owns it.

**The chill model.** `DM_JOSE.R` is not mine, so it is not uploaded here. Request it from
J. A. Egea, jaegea@cebas.csic.es.

**The figures and the decks.** Rebuilt from the tables that are here.

---

## Limitations

- **The cultivar thresholds are the dominant uncertainty.** 47.5 and 33.7 chill portions each carry
  a standard error of 3.3. `28_threshold_sweep_cropland.R` sweeps the whole range so the
  sensitivity is visible rather than asserted. The gap between them, being a paired difference, is
  far better determined than either threshold.
- **Which parametrisation the requirements were measured under needs confirming.** The methods of
  the source paper cite Fishman 1987, but code published by the same group in 2025 calls chillR's
  1988 default. On the 1988 scale the requirements would need raising by about 7 chill portions to
  be comparable with the supply computed here.
- **The model validation is not independent.** Bias against observations is −0.45 chill portions
  with r = 0.984, which is why no bias correction is applied, but the downscaling was calibrated
  against these same stations.
- **The ensemble median hides real disagreement.** The land where neither cultivar works ranges
  from 4,983 to 75,951 km² depending on which of the eleven models is believed, a factor of
  fifteen. What is *not* a problem is the order of aggregation: mapping the ensemble median and
  classifying each model separately before aggregating give a headline within four tenths of a
  point of each other.
- **The record extended to 2025 rests on 666 stations, not 3044**, and the offset between the two
  observed sources could only be measured where they overlap.
- **The portal serves the projections over two station sets.** This analysis uses the THREDDS route
  with 3460 stations; the interactive form returns 3044, and figures from the two do not reconcile.
