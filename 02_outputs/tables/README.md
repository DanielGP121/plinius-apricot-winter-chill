# Tables

Every km² and every chill portion quoted on a slide, in the one-page workflow sheet or in the method
book is read from one of these files when that document is built, rather than typed in. The
repository README is the exception: it is written by hand and its result table typed out, though the
numbers in it come from these same files. Any figure asserted anywhere in the project can therefore
be traced back to a row here, and checked from a clone without access to the cluster. Fifty tables
and nine run logs, moved out of `02_outputs/` in August 2026 so that opening that folder shows the
shape of the output instead of sixty loose files.

Read a file's header before using it. Several tables share a column layout and differ only in which
window they cover, and the `situation` column, not `scenario`, is what identifies a period.

## Where to start

**`chill_all_windows.csv`** is the table everything else comes from. One row per station, model and
situation, carrying mean chill portions, Safe Winter Chill (the 10th percentile across seasons) and
both again in Utah units. Fourteen situations: twelve model ones at 3,460 stations x 11 models,
38,060 rows each, plus two observed ones at 3,044 stations. Fourteen scripts read it, and every map,
every area and every per-model figure descends from it. Script 21 assembles it from the five
per-window runs, and the arithmetic is checkable: 269,464 + 114,180 + 38,060 + 38,060 + 3,044 =
462,808 rows.

The **metric tables**, the `*_numbers.csv` family, are the other place to look. Each is under a
kilobyte or two of `(metric, value)` pairs, and between them they hold every number the README, the
one-page workflow sheet and the method book quote. The headline result in the repository README is
`talk_key_numbers.csv`: 229,676 km² of cropland, 45,103 km² lost, 23,310 km² rescued, 51.7% of the
loss. The 39.1% to 82.1% range beside it is `model_spread_numbers.csv`. If a claim in this project
looks like it needs checking, one of these twelve files holds the number behind it.

Two more worth knowing about. `talk_numbers_cropland.csv` is where every projected km² figure comes
from, fifteen rows of area by class and situation. `idw_crossval_summary.csv` reports the
interpolation error as a percentage of the 13.8 chill portions separating the two cultivars, which
is the number that decides whether the method is good enough for the question being asked.

## What is published

45 of the 59 files are versioned. `.gitignore` names each one on its own line rather than opening
the folder wholesale, so a new output has to be added deliberately instead of being swept in.

Out on purpose: the five per-window chill runs (`chill_national`, `chill_present`, `chill_near`,
`chill_current`, `chill_obs1995`). Script 21 merges them into `chill_all_windows.csv`, so shipping
both would ship the same numbers twice. Out by omission: the nine logs, which were never listed.

Worth knowing when reading the last column below. The reporting layer that consumes many of these
tables (scripts 70 to 76, `talk_content.py`, `deck_content.R`) and the method book in `04_metodo/`
are themselves kept out of the published repository. In a clone, several metric tables have no
consumer at all. They are there so a reader can check a quoted figure, which is the difference
between publishing a result and publishing a claim.

## Contents

Scripts are given by their number prefix; full names are in `01_scripts/`. A dash in the last column
means nothing in the pipeline reads that file: it is terminal, and exists to back a claim.

### The chill tables

The master table and the five cluster runs it is assembled from. All six share the same columns,
apart from the four situation keys the merge adds.

| | What it is | Written by | Read by |
|---|---|---|---|
| `chill_all_windows.csv` | 462,808 rows, 49 MB. The canonical chill table: situation, scenario, window, period, its class (observed, historical, model baseline, current, future), whether the window tiles the century, model, station, coordinates, seasons kept, mean CP, Safe Winter Chill, and the two Utah equivalents | 21 | 30, 31, 32, 40, 50, 52 to 59, 70 |
| `chill_national.csv` | 269,464 rows. The default window set as it came off the cluster: historical 1985-2014, the three SSPs at 2041-2070 and at 2071-2100, and the observed 1991-2020 reference | 20 `--windows default` | 21 |
| `chill_near.csv` | 114,180 rows. The three SSPs at 2021-2040, the AR6 near term, which the default set leaves unanalysed | 20 `--windows near` | 21 |
| `chill_present.csv` | 38,060 rows. Model baseline 1995-2020, historical spliced to an SSP across 2014/2015, so model bias reads against the observed period without a mismatch of years | 20 `--windows present` | 21 |
| `chill_current.csv` | 38,060 rows. 1995-2025, the most recent model climate. It overlaps 2021-2040, so it opens the talk but is never a reference a future is differenced against | 20 `--windows current` | 21 |
| `chill_obs1995.csv` | 3,044 rows. The observed record aggregated over 1995-2020, the situation the model baseline is compared against | 20 `--windows obs` | 21 |

### The observed record

What was measured, as opposed to simulated. The three season-by-season tables carry one row per
station and winter with its completeness rather than an aggregate, because the 10th percentile of a
station with 12 seasons sits close to its coldest winter while the same statistic over 26 seasons is
a genuine decile. Comparing aggregates across records of unequal length measures sample size as much
as climate.

| | What it is | Written by | Read by |
|---|---|---|---|
| `chill_obs_seasons.csv` | 79,144 rows. The PNACC observed archive season by season, 1995-2020 | 20 `--per-season` | 22, 41, 42 |
| `chill_obs_seasons_1975.csv` | 136,980 rows. The long version, 1976-2020, behind the fifty-winter series | 20 `--per-season --years 1975,2020` | 43, 44, 53, 55, 58 |
| `chill_api_seasons.csv` | 13,613 rows. The same shape, from the AEMET OpenData download that carries the record to 2025 | 22 | 41, 42, 43, 44, 57, 58 |
| `observed_annual_series.csv` | 50 rows. One winter per row, 1976-2025: stations contributing, mean chill, and where that winter ranks among the mild ones | 43 | 44, 52 |
| `observed_long_record_summary.csv` | 31 rows, `block/metric/value`. The 1976-2020 baseline, the 2021-2025 anomaly and its ranking, autocorrelation at three lags, how well the 665-station panel stands in for the 3,044, and three trend fits with their p-values | 43 | 52 |
| `observed_spliced_swc.csv` | 665 rows. Per station, Safe Winter Chill over 1995-2020 against 1995-2025, so the effect of splicing five more winters on is visible station by station | 42 | 43 |
| `observed_spliced_summary.csv` | 3 rows. The same for three subsets of the network | 42 | — |
| `observed_swc_by_window.csv` | 4 rows. Median Safe Winter Chill under four definitions of the observed period. This is how the choice of window is defended | 43 | — |
| `observed_panel_sensitivity.csv` | 3 rows. The recent anomaly recomputed three ways (simple mean, balanced panel, per-station anomaly) to show the answer does not turn on which | 43 | — |
| `aemet_station_inventory_public.csv` | 784 rows. AEMET's public station list: name, province, coordinates, altitude. The only source of elevation in the project, and joined on the station identifier it matches 708 of the 3,460 stations, 76 of its entries not being network stations at all, which is why script 40's elevation panel states its subset on the figure rather than in a footnote | `legacy/build_aemet_matching.py` | 40 |

### The check tables

Error, agreement between sources, and one independent series. Nothing here feeds a headline number.
These are what a reviewer goes to when the headline looks too clean.

| | What it is | Written by | Read by |
|---|---|---|---|
| `idw_crossval.csv` | 47,608 rows. Leave-one-out residual for every station in every situation, with distance to the nearest neighbour and whether the station has a co-located twin. Versioned so the RMSE printed beside each map can be recomputed rather than taken on trust | 40 | — |
| `idw_crossval_summary.csv` | 14 rows, one per situation. MAE, RMSE, bias, r, p90, and the error as a percentage of the cultivar gap | 40 | 56, 57, 73, 74 |
| `idw_threshold_band.csv` | 6 rows. Cropland lying within one RMSE of either threshold, the land the map cannot confidently assign either way. 5.5% at the baseline, 22.7% at SSP3-7.0 far | 40 | 73, 74 |
| `idw_colocated.csv` | 151 rows. Coordinates served by more than one station and how far apart their Safe Winter Chill values are. An estimate of irreducible error | 40 | 57 |
| `api_vs_archive_by_station.csv` | 666 rows. Per-station bias, MAE and correlation between the two observed sources, over the seasons they share | 41 | 42 |
| `api_vs_archive_summary.csv` | 24 rows. The same pooled, then per station, then at the Safe Winter Chill level | 41 | — |
| `api_vs_archive_threshold_sweep.csv` | 4 rows. The comparison repeated at four completeness thresholds, so the agreement can be seen not to be an artefact of the 85% rule | 41 | — |
| `cieza_seasons.csv` | 14 rows. Chill at the Cieza orchard, 2012-2025, under both model parametrisations | 44 | — |
| `cieza_parametrisation_gap.csv` | 14 rows. The 1987 against the 1988 parametrisation, season by season. Script 31 offsets its threshold sweep by this, falling back to a default when the file is absent | 44 | 31 |
| `cieza_check_summary.csv` | 6 rows. Baseline and recent means for the orchard, for two AEMET stations within 17 km, and for the national panel. The check on the observed trend from a series outside the AEMET network | 44 | — |

### The area tables

What the classified surface produces once chill has been interpolated and crossed with CORINE. Areas
are km² of cropland, each cell weighted by its cropland fraction.

| | What it is | Written by | Read by |
|---|---|---|---|
| `talk_numbers_cropland.csv` | 15 rows. Area and percentage in each of the three classes, per situation, with the median Safe Winter Chill. Every projected km² comes from here | 30 | 31, 52, 55, 56, 57, 70, 73, 74 |
| `per_model_cropland_km2.csv` | 121 rows. The same broken out model by model, including the rescued fraction that runs from 39.1% (UKESM1-0-LL) to 82.1% (IITM-ESM) at SSP3-7.0 far | 32 | 54, 73, 74 |
| `model_agreement_summary.csv` | 11 rows. Per situation, the percentage of cells the models agree on by class and by sign of change, and how often they are unanimous | 32 | 54 |
| `band_agreement_by_situation.csv` | 11 rows. Cropland where at least 9 of 11 models place the cell in the mutant's band, the AR6 80% convention, as km² and as a percentage of cropland | 76 | — |
| `model_ranking_ssp370.csv` | 11 rows. The models ordered by how much chill they lose, by mean and by median, with baseline and far-window values | 59 | 75 |
| `cropland_threshold_sweep.csv` | 1,404 rows. Viable km² at any chill requirement from 20 CP upwards, per situation. Answers the question for a cultivar other than these two | 31 | 70 |
| `cropland_threshold_check.csv` | 12 rows. The sweep reconciled against the published areas. Largest discrepancy 0.01 km² | 31 | — |
| `cropland_threshold_meta.csv` | 4 rows. Total cropland, realised cell area, IDW radius, thresholds swept | 31 | 70 |
| `gif_frame_stats.csv` | 10 rows. Area by class for each animation frame, so an animation cannot contradict the slide next to it | 50 | — |
| `station_walkthrough_km2.csv` | 2 rows. One station (7121A, Calasparra) and its 50 km neighbourhood, baseline against SSP3-7.0 far. The worked example the method book follows through the whole chain | 55 | — |

### The metric tables

`(metric, value)` pairs, under a kilobyte or two each. These are what the talk, the workflow sheet
and the method book quote at build time, so no document can drift from the table that produced its
numbers; the repository README quotes them too, but by hand. Four of them (`v3_numbers`,
`model_sensitivity_numbers`, `v3_gap_numbers`, and `band_agreement_by_situation` above) come from
scripts that do not ship, so a clone can read them but cannot regenerate them.

| | What it is | Written by | Read by |
|---|---|---|---|
| `talk_key_numbers.csv` | 38 rows. The headline result, the Murcia figures, the observed anomaly with its exchangeability p-value, and the near-term spread. The repository README's result table is this file | 52 | 72 |
| `v3_numbers.csv` | 41 rows. Interpolation error at two windows, the between-model spread, and what changes if models are aggregated after classification instead of before (at most 4.4 percentage points) | 74 | 72 |
| `method_chain_numbers.csv` | 20 rows. Model bias against the observed at either end, correlation, and the chill deltas the chain produces | 55 | 72 |
| `model_ranking_numbers.csv` | 18 rows. Best and worst model, the spread between them at baseline and far, and how many models fall below the 'Búlida' requirement | 59 | 72, 73 |
| `timeline_numbers.csv` | 16 rows. First and last year of each source, the splice year, and seasons per window. Everything the data timeline figure draws | 58 | 72 |
| `model_spread_numbers.csv` | 11 rows. Agreement by class and by sign, and the rescued fraction across models, minimum, median and maximum with the model producing each | 54 | 72 |
| `model_sensitivity_numbers.csv` | 10 rows. Rank correlation between a model's chill loss and its TCR and ECS, both near -0.8, with the count of models sharing an atmosphere | 75 | — |
| `pipeline_diagram_numbers.csv` | 10 rows. Stations, models, scenarios, windows, canonical row count, grid cells, cropland km², runs, table size. The counts the method book leans on hardest | 56 | — |
| `method_figure_numbers.csv` | 6 rows. The Dynamic Model's optimum and its accumulation at 0 °C, and one worked station's mean against its P10 | 53 | 72 |
| `cieza_numbers.csv` | 4 rows. The parametrisation gap at Cieza: mean, range, seasons | 44 | 72, 73 |
| `v3_gap_numbers.csv` | 9 rows. Model agreement inside the hatched band, and the Cieza series' span with its zero missing days | 76 | 72 |
| `attrition_funnel_numbers.csv` | 9 rows, `side/step/value`. Stations and area surviving each stage, from the 3,460 served by THREDDS down to what is classified | 57 | 72 |

### Counts of the run

Not results. What was computed, and what was discarded on the way.

| | What it is | Written by | Read by |
|---|---|---|---|
| `pipeline_runs.csv` | 132 rows. Every model x experiment x window combination actually run, with its stations and seasons. The combinatorics of the whole compute | 56 | — |
| `season_attrition_by_window.csv` | 7 rows. Seasons possible, kept and lost per window under the 85% completeness rule. Only the 2071-2100 window loses any, and it loses 0.4% | 57 | 72 |

### The logs

| | What it is |
|---|---|
| `chill_obs_seasons.log` | The observed per-season run: 3,044 stations, 79,144 seasons, 11.7 minutes |
| `frames_quick.log`, `frames_full.log`, `frames_en.log` | Three animation-frame runs. A reduced pass at 2 km, the full pass at 1 km, and the rebuild after the talk moved to English |
| `rerun19_2026-08-14.log`, `refix_2026-08-14.log`, `refix_B_2026-08-14.log` | The 14 August rebuild, in two chains: the viability script and the per-model stats, then the frames and the GIFs |
| `regen_figs.log` | An earlier figure regeneration from the same chain |
| `talk_figs.log` | A talk-figure run that ended in an R error instead of an output. Kept as it fell |

These are console output captured from a run, not data. Nothing reads them and nothing should. They
were kept because they record which run produced the files sitting beside them, and what it cost in
wall-clock time. Most are in Spanish and name script numbers from before the August 2026
renumbering, so `19_`, `31_` and `32_` in a log are today's 30, 50 and 51. They are not versioned.

## Re-running

The move into `tables/` is not finished on the writing side. `tab_path()` in `00_paths.R` resolves
here, and scripts 22, 32, 40, 50 and 52 to 59 go through it, but several still address `02_outputs/`
directly and will drop their output one level up: 21 (`OUT <- OUT_DIR`), 30 (line 227), 31, 41 to 44,
59 for `model_ranking_ssp370.csv`, 74, 75 and 76. Their readers match, so each chain is
self-consistent on its own; it is the mixture that will catch you out. After re-running any of
those, move the file down into `tables/`, or the scripts that do use `tab_path()` will not find it.
