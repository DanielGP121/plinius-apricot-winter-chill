# Figures

Ninety-seven PNGs came out of the chill pipeline. Eighty-three of them are here, filed by the job
they do rather than by the script that drew them, and fourteen sit in `_superseded/` and stay out
of the repository. Nothing in this folder is edited by hand. Every file is a render, and the script
named beside it will overwrite it on the next run.

If you want the result, it is `04_results/fig20_15_viability_ssp370_far.png` for the map and
`04_results/fig33_headline_flow.png` for the arithmetic behind it. Everything else either builds up
to those two or tests them.

In the tables below, **talk** is `01_scripts/talk_content.py`, which builds the English talk;
**deck** is `01_scripts/deck_content.R`, the Spanish deck, which keeps a much fuller appendix
gallery; **book** is the method book in `04_metodo/`. Line numbers appear where a figure is pinned
to one slide rather than dropped into a gallery.

---

## Folders

| | What belongs in it | Figures |
|---|---|---:|
| `01_inputs` | The cropland mask, and where the weather stations fall inside it | 5 |
| `02_method` | What a chill portion is, and what each stage of the chain does to the numbers | 9 |
| `03_chill_surfaces` | Interpolated Safe Winter Chill, one map per scenario and window | 15 |
| `04_results` | Viability classes on the ground, plus the summary figures the talk leads with | 21 |
| `05_model_spread` | The eleven models seen one at a time, and how far apart they are | 20 |
| `06_checks` | Figures that test a methodological choice instead of reporting a result | 10 |
| `07_observed_record` | The measured record, 1976 to 2025 | 3 |
| `_superseded` | Retired renders, kept for reference and not part of the repository | 14 |

---

## 01_inputs

| Figure | What it shows | Produced by |
|---|---|---|
| `fig8_spain_cropland_density_stations.png` | Cropland density per 500 m cell across Spain, with the 3,044 AEMET stations in red | `67_cropland_density_stations.R` |
| `fig16_spain_cropland_binary_100m.png` | The national cropland mask at native 100 m, cropland against non-cropland | `68_cropland_binary_100m.R` |
| `fig17_spain_cropland_binary_100m_stations.png` | The same mask with the station network laid over it | `68_cropland_binary_100m.R` |
| `fig18_murcia_cropland_binary_100m.png` | Murcia at 100 m, the one scale in this family where the native resolution resolves on screen | `68_cropland_binary_100m.R` |
| `fig19_murcia_cropland_binary_100m_stations.png` | Murcia with its stations, the coverage argument at test-run scale | `68_cropland_binary_100m.R` |

`fig8` was retired by the triage as a Spanish-labelled render and then rescued.
`67_cropland_density_stations.R` was translated and re-run on 27 August, which produced an English
figure (titled `Cropland and AEMET stations in Spain (CORINE 2018)`) and brought it back into this
folder, where it is published rather than held out. It was worth rescuing because it is the only
member of the cropland family the English talk actually shows. It overlaps `fig17`: both put
stations over the national mask, but only `fig8` carries the percentage of cropland in each cell.

---

## 02_method

| Figure | What it shows | Produced by |
|---|---|---|
| `fig34_dynamic_model_response.png` | How the Dynamic Model responds to temperature, for an audience that has not met chill portions | `53_didactic_figures.R` |
| `fig35_swc_concept.png` | Safe Winter Chill defined on fifty observed seasons of one real station, which is the argument for a percentile rather than a mean | `53_didactic_figures.R` |
| `fig36_method_chain.png` | Three map panels carrying the chain from station values to a classified surface | `53_didactic_figures.R` |
| `fig44_aggregation_chain.png` | How many numbers enter and how many leave each of the five aggregation steps | `55_validation_figures.R` |
| `fig46_station_walkthrough.png` | One real station followed from its raw seasons to the class its neighbourhood ends up with | `55_validation_figures.R` |
| `fig49_pipeline_overview.png` | The pipeline as seven conceptual stages | `56_pipeline_diagram.R` |
| `fig50_pipeline_files.png` | The same chain at file level, the second level of detail after `fig49` | `56_pipeline_diagram.R` |
| `fig51_attrition_funnel.png` | Where stations and seasons are lost between the raw archive and the analysis | `57_attrition_funnel.R` |
| `fig53_data_coverage_timeline.png` | What each data source covers in time, and where they overlap | `58_data_timeline.R` |

`fig50` is absent from the talk on purpose. The book embeds it immediately after `fig49`, under the
line offering one more level of detail.

---

## 03_chill_surfaces

One interpolated Safe Winter Chill surface per situation, the layer underneath the `fig20` viability
maps. All fifteen come from `30_cropland_viability_national.R` and all fifteen sit in the deck's
gallery; the book names the family in prose without embedding it. What the set is worth lies in the
grid being complete, so several panels are unremarkable read on their own.

| Figure | What it shows | Produced by |
|---|---|---|
| `fig21_01_swc_surface_observaciones_present.png` | Observed 1995-2020, the observational anchor that opens the gallery | `30_cropland_viability_national.R` |
| `fig21_02_swc_surface_presente_present.png` | Model baseline over the same 1995-2020 window, and the figure used to explain how stations become a surface | `30_cropland_viability_national.R` |
| `fig21_03_swc_surface_presente_current.png` | Model on current climate 1995-2025 (median 73.81 CP), a window of its own | `30_cropland_viability_national.R` |
| `fig21_04_swc_surface_observaciones_obsref.png` | Observed 1991-2020, the second observational baseline, so the window choice can be checked against another period | `30_cropland_viability_national.R` |
| `fig21_05_swc_surface_historical_ref.png` | Simulated historical 1985-2014, the model-side counterpart for judging bias | `30_cropland_viability_national.R` |
| `fig21_06_swc_surface_pooled_nearterm.png` | 2021-2040 with the three scenarios pooled, the oddity of the series | `30_cropland_viability_national.R` |
| `fig21_07_swc_surface_ssp126_nearterm.png` | SSP1-2.6, 2021-2040 | `30_cropland_viability_national.R` |
| `fig21_08_swc_surface_ssp245_nearterm.png` | SSP2-4.5, 2021-2040 | `30_cropland_viability_national.R` |
| `fig21_09_swc_surface_ssp370_nearterm.png` | SSP3-7.0, 2021-2040, completing the near-term row | `30_cropland_viability_national.R` |
| `fig21_10_swc_surface_ssp126_near.png` | SSP1-2.6, 2041-2070 (median 72.33 CP), where the scenarios begin to separate | `30_cropland_viability_national.R` |
| `fig21_11_swc_surface_ssp245_near.png` | SSP2-4.5, 2041-2070 (median 72.19 CP) | `30_cropland_viability_national.R` |
| `fig21_12_swc_surface_ssp370_near.png` | SSP3-7.0, 2041-2070, completing the mid-century row | `30_cropland_viability_national.R` |
| `fig21_13_swc_surface_ssp126_far.png` | SSP1-2.6, 2071-2100, the low-emissions contrast to the headline | `30_cropland_viability_national.R` |
| `fig21_14_swc_surface_ssp245_far.png` | SSP2-4.5, 2071-2100 (median 70.13 CP) | `30_cropland_viability_national.R` |
| `fig21_15_swc_surface_ssp370_far.png` | SSP3-7.0, 2071-2100, the lowest median of the set at 65.14 CP and the surface behind the headline map | `30_cropland_viability_national.R` |

---

## 04_results

The `fig20` series classifies every cropland cell as viable for both cultivars, for 'Búlida Precoz'
only, or for neither. Its fifteen panels cover the same situations as `fig21`, one layer further on.
All of them are in the talk's annex contact sheet and in the deck gallery; four are shown full-size
on talk slides, and those are marked.

| Figure | What it shows | Produced by |
|---|---|---|
| `fig20_01_viability_observaciones_present.png` | Observed 1995-2020 (0.96% only-Precoz), the observation half of the only model-against-observation comparison in the study | `30_cropland_viability_national.R` |
| `fig20_02_viability_presente_present.png` | Model baseline over the same window (1.89% only-Precoz), the "today" panel of the talk | `30_cropland_viability_national.R` |
| `fig20_03_viability_presente_current.png` | Model on current climate 1995-2025, kept outside the four-window tessellation because it overlaps 2021-2040 by five years | `30_cropland_viability_national.R` |
| `fig20_04_viability_observaciones_obsref.png` | Observed 1991-2020, near-identical to `fig20_01` outside the Andalusian fringe, which is the check it exists for | `30_cropland_viability_national.R` |
| `fig20_05_viability_historical_ref.png` | Simulated historical 1985-2014, the window where the CMIP6 historical experiment ends | `30_cropland_viability_national.R` |
| `fig20_06_viability_pooled_nearterm.png` | 2021-2040 pooled across scenarios, which the script argues is the only near-term presentation the data support (0.26 CP between scenarios against 7.13 CP between models) | `30_cropland_viability_national.R` |
| `fig20_07_viability_ssp126_nearterm.png` | SSP1-2.6, 2021-2040, 96.2% both | `30_cropland_viability_national.R` |
| `fig20_08_viability_ssp245_nearterm.png` | SSP2-4.5, 2021-2040, 95.4% both, the middle term of a non-monotonic row | `30_cropland_viability_national.R` |
| `fig20_09_viability_ssp370_nearterm.png` | SSP3-7.0, 2021-2040, 97.2% both, higher than SSP1-2.6 and the reason the row is pooled into `fig20_06` | `30_cropland_viability_national.R` |
| `fig20_10_viability_ssp126_near.png` | SSP1-2.6, 2041-2070, 92.5% both | `30_cropland_viability_national.R` |
| `fig20_11_viability_ssp245_near.png` | SSP2-4.5, 2041-2070, the only panel covering that cell of the matrix | `30_cropland_viability_national.R` |
| `fig20_12_viability_ssp370_near.png` | SSP3-7.0, 2041-2070, 90.6% both | `30_cropland_viability_national.R` |
| `fig20_13_viability_ssp126_far.png` | SSP1-2.6, 2071-2100, the optimistic end of the end-of-century row | `30_cropland_viability_national.R` |
| `fig20_14_viability_ssp245_far.png` | SSP2-4.5, 2071-2100, 87.9% both, the bridge across which the "neither" class jumps to 9.5% | `30_cropland_viability_national.R` |
| `fig20_15_viability_ssp370_far.png` | SSP3-7.0, 2071-2100. The headline: 80.4% both, 10.1% only-Precoz, 9.5% neither, the point where the mutant stops compensating | `30_cropland_viability_national.R` |
| `fig22_viability_bars.png` | The same three classes as bars, so the windows can be read against each other without counting pixels | `30_cropland_viability_national.R` |
| `fig30_time_of_emergence_ssp370.png` | The first window in which each cell drops below the requirement, against "already below" and "does not happen this century" | `52_talk_figures.R` |
| `fig31_murcia_ensemble_requirements.png` | Murcia stations against both cultivar thresholds as a distribution rather than a map | `52_talk_figures.R` |
| `fig33_headline_flow.png` | The whole answer as one bar: 229,676 km² of cropland, 45,103 km² lost to 'Búlida', and that band magnified into 23,310 km² rescued against 21,794 km² lost outright | `52_talk_figures.R` |
| `fig37_baseline_today.png` | The modelled 1995-2020 baseline on its own, the map that says where we start | `53_didactic_figures.R` |
| `fig47_observed_viability.png` | The measured IDW surface classified, the map that opens the results before any model appears | `54_model_figures.R` |

`fig37` and `fig47` share a page geometry and are easy to confuse. `fig37` is the modelled baseline,
`fig47` the observed surface, so the two are complements.

---

## 05_model_spread

| Figure | What it shows | Produced by |
|---|---|---|
| `fig38_model_vs_scenario_spread.png` | Model spread set against scenario spread, the two sources of uncertainty separated | `52_talk_figures.R` |
| `fig39_model_agreement_far.png` | Ensemble-median viability with the cells below the AR6 80% agreement threshold hatched over it | `54_model_figures.R` |
| `fig40_small_multiples_presente_present.png` | The baseline in eleven panels, one per model, ordered by each model's own rescue fraction | `54_model_figures.R` |
| `fig40_small_multiples_ssp126_far.png` | The same eleven panels for SSP1-2.6 at 2071-2100 | `54_model_figures.R` |
| `fig40_small_multiples_ssp245_far.png` | The same eleven panels for SSP2-4.5 at 2071-2100 | `54_model_figures.R` |
| `fig40_small_multiples_ssp370_far.png` | SSP3-7.0 at 2071-2100, the most reused sheet in the family, annotated with callouts on IITM-ESM and UKESM1-0-LL | `54_model_figures.R` |
| `fig40_small_multiples_presente_present_ssp126.png` | The baseline redrawn in the SSP1-2.6 end-of-century panel order, so the animation opens without the panels shuffling | `54_model_figures.R` |
| `fig40_small_multiples_presente_present_ssp245.png` | The baseline in SSP2-4.5 panel order | `54_model_figures.R` |
| `fig40_small_multiples_presente_present_ssp370.png` | The baseline in SSP3-7.0 panel order, with the subtitle spelling out why it is drawn twice | `54_model_figures.R` |
| `fig40_small_multiples_ssp126_nearterm.png` | SSP1-2.6 at 2021-2040 | `54_model_figures.R` |
| `fig40_small_multiples_ssp245_nearterm.png` | SSP2-4.5 at 2021-2040 | `54_model_figures.R` |
| `fig40_small_multiples_ssp370_nearterm.png` | SSP3-7.0 at 2021-2040, the starting point for the turn to red the talk points at | `54_model_figures.R` |
| `fig40_small_multiples_ssp126_near.png` | SSP1-2.6 at 2041-2070 | `54_model_figures.R` |
| `fig40_small_multiples_ssp245_near.png` | SSP2-4.5 at 2041-2070, with the orange band already spreading inland | `54_model_figures.R` |
| `fig40_small_multiples_ssp370_near.png` | SSP3-7.0 at 2041-2070, the frame just before the sheet the talk annotates | `54_model_figures.R` |
| `fig41_per_model_range.png` | The rescue range measured over area against the same range measured over stations, which are not the same number | `54_model_figures.R` |
| `fig42_sign_agreement_ssp370.png` | Viability fill plus hatching, against a six-level agreement scale | `54_model_figures.R` |
| `fig48_agreement_scale_ssp370.png` | Agreement alone, with no viability fill competing for the colour channel, so all six levels show | `54_model_figures.R` |
| `fig54_model_ranking_ssp370.png` | The eleven models ranked by how much land each one loses | `59_model_ranking.R` |
| `fig55_model_sensitivity.png` | Whether that ranking follows published model sensitivity, to which the script header records the answer as only half yes | `75_model_sensitivity.R` |

`fig39` and `fig48` look like the same map and are not. `fig39` keeps the viability fill and hatches
the cells below 80% agreement; `fig48` drops the fill to free the colour channel for the full
agreement scale. Both sit on their own slides.

---

## 06_checks

| Figure | What it shows | Produced by |
|---|---|---|
| `fig6_soil_criteria_compare.png` | How far the answer moves when the cropland criterion changes, over 123 Murcia stations, in three classes | `64_soil_criterion_compare.R` |
| `fig23_01_api_vs_archive_seasons.png` | Archive against API season by season, the paired-values panel | `41_observed_api_vs_archive.R` |
| `fig23_02_api_vs_archive_swc.png` | The same comparison carried through to Safe Winter Chill, which is what the argument rests on | `41_observed_api_vs_archive.R` |
| `fig23_03_bias_vs_completeness.png` | That the archive-against-API disagreement is not concentrated in barely-complete seasons, which is the evidence for the 85% threshold | `41_observed_api_vs_archive.R` |
| `fig24_01_swc_shift_1995_2025.png` | What extending the observed record from 2020 to 2025 does to the numbers | `42_splice_observed_1995_2025.R` |
| `fig26_01_independent_records.png` | The recent drop confirmed on a Cieza series from outside the AEMET network | `44_cieza_independent_check.R` |
| `fig26_02_parametrisation_gap.png` | The gap between the two Dynamic Model parametrisations, a number quoted in a slide title | `44_cieza_independent_check.R` |
| `fig43_model_bias.png` | Model bias against the observed baselines, the figure that justifies applying no bias correction | `55_validation_figures.R` |
| `fig45_delta_vs_absolute.png` | That the conclusion survives comparing each model to its own past rather than to absolute values | `55_validation_figures.R` |
| `fig52_idw_crossval.png` | Leave-one-out interpolation error, RMSE 5.50 CP, set against half of the 13.8 CP gap between the cultivars | `40_idw_crossval.R` |

---

## 07_observed_record

| Figure | What it shows | Produced by |
|---|---|---|
| `fig25_01_observed_chill_series_1976_2025.png` | Fifty winters of observed chill, with the trend | `43_observed_long_record.R` |
| `fig25_02_running5_blocks.png` | The same record in overlapping five-winter blocks, which puts the recent winters in context | `43_observed_long_record.R` |
| `fig32_observed_stripes.png` | The observed record as warming stripes, one band per winter | `52_talk_figures.R` |

---

## _superseded

Fourteen renders are held here and are not part of the repository. They were retired on four
grounds:

- **outdated**, where the file on disk no longer matches what its script now produces;
- **duplicate**, where two scripts draw the same map and the files differ only cosmetically;
- **redundant**, where the figure is correct and current but another one carries its argument
  better;
- **no_value**, where there is nothing to read. None of the fourteen fell into this last one.

All fourteen carry Spanish titles and legends. That is a translation that did not reach the rendered
output, not a scientific defect. The scripts were translated in late August; these files were
written before that pass, in July or from a working tree that had not caught up. Where the values
were checked they hold. `fig4_distribucion_swc.png`, for one, has an observed median near 62 CP,
which matches the DM_JOSE 1987 re-run.

| Figure | Ground | Replaced by |
|---|---|---|
| `fig1_contexto_suelo.png` | outdated | Nothing exactly. `fig19` covers cropland and stations, but only `fig1` colours each station by the strict, broad or neither cultivable criterion |
| `fig2_swc_ensemble.png` | outdated | none |
| `fig3_case_study.png` | outdated | `fig31_murcia_ensemble_requirements.png`, which makes the same point as a distribution rather than a map |
| `fig4_distribucion_swc.png` | outdated | none |
| `fig5_spain_cropland_binary.png` | outdated | `fig16_spain_cropland_binary_100m.png`, at native resolution and in English |
| `fig5_spain_cropland_density.png` | outdated | `fig10` at 500 m, itself retired, so the national density view now survives only in `fig8` |
| `fig7_murcia_cropland_density.png` | duplicate | `fig11`, itself retired; the clean Murcia map is `fig18_murcia_cropland_binary_100m.png` |
| `fig9_murcia_cropland_density_stations.png` | redundant | `fig19_murcia_cropland_binary_100m_stations.png` |
| `fig10_spain_cropland_density_500m.png` | redundant | `fig16` on the deck slide, `fig8` for the density itself |
| `fig11_murcia_cropland_density_500m.png` | redundant | `fig18_murcia_cropland_binary_100m.png` |
| `fig12_spain_cropland_binary_500m.png` | outdated | `fig16_spain_cropland_binary_100m.png` |
| `fig13_spain_cropland_binary_500m_stations.png` | outdated | `fig17_spain_cropland_binary_100m_stations.png` |
| `fig14_murcia_cropland_binary_500m.png` | outdated | `fig18_murcia_cropland_binary_100m.png` |
| `fig15_murcia_cropland_binary_500m_stations.png` | outdated | `fig19_murcia_cropland_binary_100m_stations.png` |

Re-running the scripts would not repair all of them. `61_chill_maps_murcia.Rmd`, which draws `fig1`
to `fig4`, now sets English titles, but Spanish literals survive in its code: the scenario facet
labels at line 64 (`Observado 1991-2020`, `Histórico 1985-2014`) and the cropland legend at line 91
(`cultivo (211-223)`, `heterogéneo (241-244)`), so a re-knit would leave `fig2` half translated.
`67_cropland_density_stations.R`, which draws `fig12` to `fig15`, is no longer in that position: it
was translated and re-run on 27 August, and its binary legend now reads `non-cropland` / `cropland`.

`fig8_spain_cropland_density_stations.png` was on this list too, on the same ground, and is the one
that came back. That script was translated on 27 August and re-run the same day, which was enough.
It now lives in `01_inputs/` and is published with the rest of that folder.

Nine of the fourteen are still named in the deck's appendix gallery (`deck_content.R:278-282`), and
two more sit on body slides instead: `fig3_case_study` at `deck_content.R:44` and
`fig1_contexto_suelo` at `:83`. All eleven references need editing before this folder can be treated
as gone.

---

## New figures

`fig_path()` in `01_scripts/00_paths.R` reads the number out of a file name, looks it up in
`FIG_GROUPS`, and writes the PNG into the folder it finds there, under `figures_chill/`.
`fig_in(dir, name)` does the same against any base, which is what the scripts that reach the figure
directory through an alias or a `--figdir` override call, so a redirected run files its output the
same way. Both consult `FIG_GROUPS`, and that map lives in one place rather than in each script, so
a script keeps calling `fig_path("fig33_headline_flow.png")` and its output lands where it belongs
on the next render. A number with no entry falls back to the root of `figures_chill/`, which is
where a figure added later sits until someone gives it an entry. Readers resolve either way, since
the book and the deck builder both search recursively.

Two things follow. Filing a new figure means adding its number to a group in `FIG_GROUPS`, not
moving the file: move the file alone and the next render puts it back. And the numbers 1 to 5, 7,
and 9 to 15 are listed under `_superseded`, so re-running the scripts that draw them sends the
renders straight back there. Rescuing one means taking its number out of that entry first, which is
what was done for 8.
