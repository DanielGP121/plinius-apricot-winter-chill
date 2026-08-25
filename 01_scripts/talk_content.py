"""Narrative of the talk deck, read by 35_build_talk_pptx.py.

Kept apart from the builder so the wording can be reworked without touching layout code, the same
split the project already uses for deck_content.R and 29_build_deck.R.

Every slide title is an assertion, not a label. That is the convention the IPCC WGI Visual Style
Guide calls the intent rule and applied to every visual in the AR6 Summary for Policymakers: write
the message as a sentence, then use the sentence as the title. A title that reads "Results" makes
the audience find the message; a title that states it lets them spend their attention on the
evidence underneath.

Every number that comes out of the analysis arrives through `N`, loaded from talk_key_numbers.csv
and method_figure_numbers.csv, so those cannot drift from the tables that produced them. Numbers
that are NOT analysis outputs are typed here: the two chill requirements, which are literature
values from Ruiz et al. 2019, the dataset descriptions, and the figures quoted from the canonical
project document. Those are the ones to re-check by hand, and an earlier version of this docstring
claimed no number was ever typed here, which was false and hid exactly that.

Slide kinds:
    cover       title page
    section     part divider
    figure      assertion + one image, optionally with a caption under it
    figure_side assertion + image on the left, short points on the right
    compare     assertion + two labelled columns of native shapes (no image)
    ingredients assertion + the three data layers as native shapes
    close       take-home page

Prose is British English throughout, following the supervision meeting of 24 August 2026: the
conference is international, and the deck reaches the coauthors in the language it will be
delivered in. What gets projected on 8 October is the subset carrying spoken=True, built with
`--short`; the full deck is what the coauthors review.
"""

FIG = "02_outputs/figures_chill"
GIF = "02_outputs/gifs"
FRAME = "02_outputs/gif_frames"

# Situations drawn by 19_cropland_viability_national.R, in the order its SIT_ORDER fixes. Used to
# build the contact sheet in the annex without hard-coding fifteen file names.
GALLERY_MAPS = [
    ("fig20_01_viability_observaciones_present.png", "Observed 1995-2020"),
    ("fig20_02_viability_presente_present.png", "Model, baseline 1995-2020"),
    ("fig20_03_viability_presente_current.png", "Model, current climate 1995-2025"),
    ("fig20_04_viability_observaciones_obsref.png", "Observed 1991-2020"),
    ("fig20_05_viability_historical_ref.png", "Simulated historical 1985-2014"),
    ("fig20_06_viability_pooled_nearterm.png", "2021-2040, three scenarios pooled"),
    ("fig20_07_viability_ssp126_nearterm.png", "SSP1-2.6 · 2021-2040"),
    ("fig20_08_viability_ssp245_nearterm.png", "SSP2-4.5 · 2021-2040"),
    ("fig20_09_viability_ssp370_nearterm.png", "SSP3-7.0 · 2021-2040"),
    ("fig20_10_viability_ssp126_near.png", "SSP1-2.6 · 2041-2070"),
    ("fig20_11_viability_ssp245_near.png", "SSP2-4.5 · 2041-2070"),
    ("fig20_12_viability_ssp370_near.png", "SSP3-7.0 · 2041-2070"),
    ("fig20_13_viability_ssp126_far.png", "SSP1-2.6 · 2071-2100"),
    ("fig20_14_viability_ssp245_far.png", "SSP2-4.5 · 2071-2100"),
    ("fig20_15_viability_ssp370_far.png", "SSP3-7.0 · 2071-2100"),
]


def en(x, dec=0):
    """Format a number the English way: comma for thousands, full stop for decimals.

    Replaces the es() helper this file carried while the deck was in Spanish, which swapped the two
    separators. Keeping it after the translation would have printed "229.676 km²" and "33,5 %"
    inside English sentences, in all 84 interpolated figures, and nothing would have flagged it.
    """
    return f"{x:,.{dec}f}"


def slides(N):
    """Build the slide list. `N` maps metric name to value, straight from the output tables.

    Six sections, in the order an audience needs them: what data went in, what was done to it,
    what was and was not adjusted, what came out, what it means, and what it does not mean.

    Titles change register between sections on purpose. In data, logic and adjustments they
    describe what the slide shows, because forcing an assertion onto a slide that introduces a
    dataset reads as sales. In results and discussion they assert, following the IPCC intent
    rule. Every title also names the variable it is about, which is what the 24 August 2026
    supervision meeting asked for: a heading that says "the result" makes the audience work out
    which result.
    """
    pct_resc = N["rescued_pct_of_lost"]
    return [
        dict(kind="cover",
             spoken=True,
             title="Harnessing low-chill apricot bud sports to sustain Mediterranean "
                   "stone fruit production through increasingly warm winters.",
             subtitle="Calculating where the winter chill requirement of the apricot cultivar "
                      "'Búlida' stops being met, and how much of it its somatic mutant "
                      "'Búlida Precoz' rescues",
             authors="Daniel González-Palazón¹ · José A. Egea² · José Antonio Campoy Corbalán¹",
             affil="¹ Estación Experimental de Aula Dei (EEAD-CSIC), Zaragoza    "
                   "² Centro de Edafología y Biología Aplicada del Segura (CEBAS-CSIC), Murcia",
             venue="19th Plinius Conference on Mediterranean Risks · Murcia · 8 October 2026",
             notes="Working version, aimed at explaining the method. Six sections: data, logic, "
                   "adjustments, results, discussion and close. What gets projected in October "
                   "will be a subset of this material."),

        # ---------------------------------------------------------------- 1. DATA
        # Deliberately without a lead: the divider goes straight into the four sources on the next
        # slide. The other four sections keep theirs.
        dict(kind="section", n="1", title="The data"),

        dict(kind="ingredients",
             spoken=True,
             title="Four inputs: projections, observations, cropland, requirements",
             items=[
                 dict(head="Projections", body="PNACC AR6, ESD-RegBA method\n"
                                               "11 CMIP6 models × 3 scenarios\n"
                                               "3,460 stations, daily\n"
                                               "88 files, ~15 GB"),
                 dict(head="Observations", body="AEMET, two products\n"
                                                "Archive 1975-2020 (3,044 stations)\n"
                                                "API 1996-2025\n"
                                                "Spliced record of 665"),
                 dict(head="Cropland", body="CORINE Land Cover 2018\n"
                                            "100 m raster\n"
                                            "classes 211-244 without pastures\n"
                                            f"{en(N['total_cropland_km2'])} km² of cropland"),
                 dict(head="Requirements", body="Ruiz et al. 2019\n"
                                                "'Búlida' 47.5 CP\n"
                                                "'Búlida Precoz' 33.7 CP\n"
                                                "measured with the same model"),
             ],
             foot="The first three are data layers. The fourth is what turns a temperature map "
                  "into a map of agronomic decisions.",
             source="§ 2 of canonical document v2",
             notes="Worth pausing on the fourth one. Without the cultivar requirements this would "
                   "be one more chill map; with them it is a map of where you can plant what. It "
                   "is also the largest uncertainty in the work, because it depends on which "
                   "parametrisation they were measured with. It comes up again in the discussion "
                   "section."),

        dict(kind="compare",
             title="Projections arrive downscaled to stations, not on a grid",
             left=dict(head="What ESD-RegBA is", big="11 × 3",
                       lines=["Statistical downscaling of PNACC AR6, published by AEMET",
                              "Delivers daily maximum and minimum temperature at each station",
                              "Historical 1950-2014, scenarios 2015-2100",
                              "It is the only published method for temperature in this product"]),
             right=dict(head="The download trap", big="3,460 ≠ 3,044",
                        lines=["THREDDS serves 3,460 stations; the download form, 3,044",
                               "It is the same scientific product in two packagings",
                               "Checked by arithmetic on the received file itself",
                               "Methods has to declare the download route used, or nobody "
                               "reproduces the km²"]),
             foot="Working with stations rather than a grid is what allows a direct comparison "
                  "with the observations at the same point, without interpolating before "
                  "validating.",
             source="§ 2.1 and § 2.1.1 of canonical document v2",
             notes="If anyone asks why stations and not a grid: because the check against "
                   "observations is done at the same point, without an interpolation in between. "
                   "The interpolation comes later, and only to go from points to surface.\n\n"
                   "The two-route business turned up while checking whether the download script "
                   "pulled the same thing as the web interface. It did not. Practical "
                   "consequence: 416 stations enter the interpolation without having been "
                   "contrasted against the observed record, because the observations only cover "
                   "the 3,044."),

        dict(kind="figure_side",
             title="Observed chill reaches 2025 by splicing two AEMET products",
             image=f"{FIG}/fig25_01_observed_chill_series_1976_2025.png",
             points=["The historical archive covers 1975-2020 with 3,044 stations.",
                     "The open API supplies 2021-2025 of the record, and it is a different "
                     "quality-control chain.",
                     "Splicing them means showing first that they measure the same thing. That "
                     "was done, and it is shown in the adjustments section.",
                     "The resulting record has 665 stations with a continuous series of 50 "
                     "winters."],
             source="§ 2.2 and § 6.7 of canonical document v2 · scripts 21 to 26",
             notes="This splice was not in the original plan. It came out of a minor question "
                   "(are the two products interchangeable?) and ended up producing a result of "
                   "its own, which turns up in section 4."),

        dict(kind="figure",
             spoken=True,
             title="Period covered by each source, and the four analysis windows",
             image=f"{FIG}/fig53_data_coverage_timeline.png",
             caption=f"The four windows tile 1995-2100 with no gaps and no overlaps. Each source "
                     f"bar spans the period the analysis reads from it, not the product's full "
                     f"extent.",
             source="§ 3 of canonical document v3 · 42_data_timeline.R",
             notes="This is the slide that defines the four windows the results talk about. It "
                   "deserves thirty seconds.\n\n"
                   "Three things to point at. The first, the dashed line at 2014/2015: it is a "
                   "seam, and it is structural, because the CMIP6 historical experiment ends on "
                   "31 December 2014 by design and the scenarios start the next day, so the "
                   "baseline window has to be assembled from two files. There is a second join "
                   "in this work, the one between the AEMET archive and the open API, but that "
                   "one gets a figure of its own later and is deliberately not drawn here.\n\n"
                   "The second, why the baseline stops in 2020 when there is data up to 2025: if "
                   "it ran to 2025 it would share five years with the 2021-2040 window, and "
                   "differencing one against the other would cancel a quarter of the first "
                   "change by construction. The current climate panel for 1995-2025 exists, but "
                   "it is never used as a reference.\n\n"
                   "And the third, the overlap between observations and model over 1995-2020, "
                   "which is what makes the validation shown later possible."),

        dict(kind="figure_side",
             title="Cropland is defined by CORINE classes; the choice was tested",
             image=f"{FIG}/fig6_soil_criteria_compare.png",
             points=[f"Criterion adopted: CORINE classes 211 to 244, excluding 231 (pastures). "
                     f"That is {en(N['total_cropland_km2'])} km² of cropland.",
                     "The map compares it, over the 123 Murcia stations, against a criterion "
                     "based on the percentage of cropland inside a buffer.",
                     "Egea's criterion (≤1 km to a crop, ≤100 m of elevation difference) keeps "
                     "113 stations; the wide buffer criterion 73 and the strict one 44.",
                     "Measured on the final percentages, the choice moves the result by two and "
                     "a half points at most."],
             source="§ 2.3 of canonical document v2 · 05_cropland_filter.py",
             notes="The reasonable question is whether the result depends on where the boundary "
                   "of 'cropland' is drawn. Narrower and wider criteria were tried and the "
                   "difference in the final percentages is two and a half points at most. The "
                   "wide criterion was chosen because apricot grows alongside other woody crops "
                   "in mosaic, which is exactly what classes 241-244 capture."),

        # ---------------------------------------------------------------- 2. LOGIC
        dict(kind="section", n="2", title="The calculation chain",
             lead="Getting from a daily temperature to a classified square kilometre takes five "
                  "steps, and each one cuts down the number of values."),

        dict(kind="figure",
             title="Chill accumulation rate peaks at 8 °C in the Dynamic Model",
             image=f"{FIG}/fig34_dynamic_model_response.png",
             caption="The fruit tree has to accumulate chill in winter to break dormancy. It is "
                     "measured in chill portions, and the temperature that contributes most is "
                     f"not the lowest one: at 0 °C only {en(N['dm_pct_at_0C'])}% of the "
                     "optimum accumulates.",
             source="Fishman et al. 1987 · curve measured on the model itself in 34_method_figures.R",
             notes="Obligatory starting point. Three ideas for the people in the room who do not "
                   "come from fruit growing: the tree needs to go through cold in winter to flower "
                   "properly; that chill is counted in portions, not in hours below a "
                   "threshold; and a freezing winter can accumulate LESS than a mild one, because "
                   "below −4 °C nothing accumulates at all. Which is why warming does not reduce "
                   "chill in a straight line."),

        dict(kind="figure",
             title="Safe Winter Chill is the 10th percentile across winters",
             image=f"{FIG}/fig35_swc_concept.png",
             caption="What ruins a grower is not the average winter, it is the poor one. Safe "
                     "Winter Chill is the chill that is exceeded in nine winters out of ten.",
             source="§ 4 of canonical document v2 · seasons JDay 305-59, completeness ≥ 85%",
             notes="If a site gives 47.5 CP on average and the crop needs 47.5, it fails one year "
                   "in two. The P10 shifts the question from 'how much chill is there' to 'how "
                   "much can I count on', which is the one you answer before planting a tree that "
                   "will stand for twenty years. The example station has a mean of "
                   f"{en(N['swc_example_mean'], 1)} CP and a P10 of "
                   f"{en(N['swc_example_p10'], 1)}."),

        dict(kind="figure",
             spoken=True,
             title="From stations and models to 1 km cells in five reductions",
             image=f"{FIG}/fig44_aggregation_chain.png",
             source="§ 6.10 of canonical document v2",
             notes="This is the slide that answers 'where does the map come from'. The numbers "
                   f"matter: you start from {en(N['chain_stations'])} stations times "
                   f"{en(N['chain_models'])} models, that gives {en(N['chain_swc_values'])} Safe "
                   f"Winter Chill values, they collapse to {en(N['chain_stations'])} by taking "
                   f"the median across models, and from there it is interpolated onto "
                   f"{en(N['chain_cells'])} cells of 1 km.\n\n"
                   "The point to say out loud is where the spread between models is lost: in the "
                   "fourth step. That is why the discussion section brings it back on its own, "
                   "instead of writing it off."),

        dict(kind="figure",
             title="From stations to surface: IDW interpolation and cropland mask",
             image=f"{FIG}/fig36_method_chain.png",
             caption="What there is, what gets interpolated and where it is clipped. The stations "
                     "cluster in valleys, airports and cities, and 151 points carry two at once, "
                     "so counting them does not estimate territory.",
             source="§ 34_method_figures.R · method of Egea et al. 2022 "
                    "(Front. Plant Sci. 13:842628)",
             notes="The interpolation is IDW with a 50 km radius and power 2, replicating the "
                   "method of Egea et al. 2022 over this same region. Cells with no station "
                   "within 50 km are left empty, which is the mask used in that work.\n\n"
                   "If they ask why IDW and not kriging with covariates, which is what the recent "
                   "literature prefers: because this replicates a published method for this "
                   "region and these cultivars, and it is done with 3,460 stations against the "
                   "270 of that reference, so the surface is far better constrained."),

        dict(kind="figure",
             title="Safe Winter Chill at Calasparra: the chain at one station",
             image=f"{FIG}/fig46_station_walkthrough.png",
             caption=f"Calasparra (Murcia, 394 m). Observed P10 "
                     f"{en(N['walk_p10_obs'], 1)} CP; ensemble median "
                     f"{en(N['walk_med_base'], 1)} today and {en(N['walk_med_far'], 1)} at the "
                     f"end of the century.",
             source="§ 38_method_figures.R · station 7121A of the AEMET inventory",
             notes="Here you can check the arithmetic of the method on a concrete case. "
                   "Calasparra is in the Segura valley, in apricot country.\n\n"
                   f"The observed and the simulated almost agree today ({en(N['walk_p10_obs'], 1)} "
                   f"against {en(N['walk_med_base'], 1)} CP), which is the check of the next "
                   f"section at a single point. And by the end of the century the median falls to "
                   f"{en(N['walk_med_far'], 1)} CP: below the 47.5 that 'Búlida' needs and well "
                   "above the 33.7 of its mutant. This station is, literally, the argument of the "
                   "talk at one point on the map."),

        # ---------------------------------------------------------------- 3. ADJUSTMENTS
        dict(kind="section", n="3", title="The adjustments",
             lead="What was corrected, what was deliberately left uncorrected, and the evidence "
                  "behind each of the two decisions."),

        dict(kind="figure",
             title="Model bias in Safe Winter Chill, and why none was corrected",
             image=f"{FIG}/fig43_model_bias.png",
             caption=f"The eleven models span {en(N['bias_range_CP'], 1)} CP, on a variable whose "
                     f"national median is around 74. The worst one is off by "
                     f"{en(N['bias_worst_abs_CP'], 2)} CP.",
             source="§ 6.1 of canonical document v2 · § 38_method_figures.R",
             notes="This answers head-on the question of whether the data were adjusted. The "
                   "answer is that they arrive already adjusted at source (ESD-RegBA is a "
                   "statistical downscaling with correction built in, produced by AEMET) and that "
                   "NO further correction was applied.\n\n"
                   f"The decision was not assumed, it was measured: over the same "
                   f"{en(N['n_bias_stations'])} stations and the same window, the bias of the "
                   f"ensemble median is {en(N['bias_ensemble_CP'], 2)} CP and the spatial "
                   f"correlation 0.984. Model by model it runs from {en(N['bias_min_CP'], 2)} "
                   f"({N['bias_min_model']}) to +{en(N['bias_max_CP'], 2)} "
                   f"({N['bias_max_model']}), and no correlation drops below "
                   f"{en(N['r_min'], 3)}.\n\n"
                   "Compulsory caveat, say it before anyone asks: ESD-RegBA was calibrated "
                   "against these same stations, so this is not independent validation. It is a "
                   "consistency check. And there are 416 stations that go into the interpolation "
                   "without having been through it, because they have no observations."),

        dict(kind="figure",
             title="Deltas against each model's own baseline cancel constant bias",
             image=f"{FIG}/fig45_delta_vs_absolute.png",
             caption="Comparing each model with its own baseline, any constant bias it carries "
                     "cancels out in the subtraction.",
             source="§ 6.6 of canonical document v2 · § 38_method_figures.R",
             notes="This is the argument that shields the previous decision. If the conclusion "
                   "only held with absolute values, it would depend on not having corrected. "
                   f"Working in differences, the median loss under SSP3-7.0 at the end of the "
                   f"century is {en(abs(N['delta_median_CP']), 1)} CP, with a range across models "
                   f"from {en(abs(N['delta_max_CP']), 1)} to {en(abs(N['delta_min_CP']), 1)} CP "
                   f"taken as the median across stations, "
                   "and 88% of the stations lose chill.\n\n"
                   "A nice detail for anyone who asks about the order of aggregation: here the "
                   "three ways of averaging give −12.8, −11.8 and −12.2 CP, so they agree. In the "
                   "2021-2040 window those same three ways can flip the sign. When there is a "
                   "signal, the order stops mattering."),

        dict(kind="figure_side",
             title="Safe Winter Chill from archive versus API: splice verified",
             image=f"{FIG}/fig23_02_api_vs_archive_swc.png",
             points=["Safe Winter Chill computed over the same seasons from each product, one "
                     "point per station.",
                     "Bias +0.13 CP, spatial correlation 0.9865.",
                     "Season by season the two disagree more (MAE 1.35 CP), but the statistic "
                     "that feeds the maps is the P10 over many seasons.",
                     "The bias was not corrected: it pushes upwards, against the finding that "
                     "the last five winters are poor in chill."],
             source="§ 6.7 of canonical document v2 · 24_observed_api_vs_archive.R",
             notes="Here something really did have to be demonstrated before it could be used. "
                   "Season by season the two products disagree (MAE 1.35 CP), but the statistic "
                   "that feeds the maps is the P10 over many seasons, and there they agree.\n\n"
                   "The +0.13 CP was not corrected either. And it is worth saying why that is "
                   "safe: that bias pushes upwards, that is, AGAINST the finding that the last "
                   "five winters are poor in chill. If we corrected it, the result would come "
                   "out even stronger."),

        # ---------------------------------------------------------------- 4. RESULTS
        dict(kind="section", n="4", title="The results",
             lead="One starting point, three futures, and cropland that changes hands."),

        dict(kind="figure_side",
             spoken=True,
             title="Measured winter chill still meets 'Búlida' almost everywhere",
             image=f"{FIG}/fig47_observed_viability.png",
             points=["Blue: both cultivars meet their chill requirement.",
                     "Orange: only the mutant meets it. Today it is a thin band in the south and "
                     "along the Mediterranean coast.",
                     "Red: neither cultivar meets it. Today it barely exists.",
                     "This is measured, not simulated: the 3,044 stations with observations "
                     "between 1995 and 2020."],
             source="§ 37_model_figures.R · observed 1995-2020",
             notes="Visual anchor and an honest starting point: before asking the audience to "
                   "believe in any future, this is what has actually been measured. Give it a few "
                   "seconds of silence so the colour key sinks in, because everything that comes "
                   "afterwards is this same image changing."),

        dict(kind="figure",
             title="Each model's baseline chill reproduces the observed pattern",
             image=f"{FIG}/fig40_small_multiples_presente_present.png",
             caption="Baseline 1995-2020. Each map is a different climate model, with nothing "
                     "averaged. Compare them with the observed map on the previous slide.",
             source="§ 37_model_figures.R · 11 CMIP6 models, ESD-RegBA",
             notes="This is where you can see that the models start from a reasonable place. None "
                   "of them is identical to the observations, but all of them reproduce the same "
                   "pattern: the orange band in the south and along the coast, and blue "
                   "everywhere else.\n\n"
                   "It is the visual version of the bias measured in section 3: the eleven all "
                   f"fit within {en(N['bias_range_CP'], 1)} CP."),

        dict(kind="figure_side",
             spoken=True,
             title="Ensemble-median chill, station by station, is the baseline map",
             image=f"{FIG}/fig37_baseline_today.png",
             points=["At each station separately, the middle value of the eleven models is "
                     "taken.",
                     "It is no single model's map: which one sits in the middle changes from one "
                     "station to the next.",
                     "It looks a lot like the observations, which is what had to be checked "
                     "before applying the same recipe to the futures.",
                     "This operation is the fourth of the five reductions in the chain, and it is "
                     "where the model spread is lost."],
             source="§ 34_method_figures.R · ensemble median, baseline 1995-2020",
             notes="The hinge slide. We have just seen what was measured and the eleven "
                   "simulations; this one explains the operation that turns them into a single "
                   "map, and checks it in the window where there are observations to compare "
                   "against. The same recipe is then applied to the three scenarios, and there no "
                   "observed record is left to act as a control."),

        dict(kind="figure",
             title="SSP3-7.0 end-century chill: models differ more than scenarios",
             image=f"{FIG}/fig40_small_multiples_ssp370_far.png",
             caption="Here the full model spread shows: there is more difference between the "
                     "mildest and the harshest model than between this scenario and SSP1-2.6. The "
                     "sheets for the other two scenarios are in the annex.",
             source="§ 37_model_figures.R · 2071-2100",
             notes="The sheet that most deserves room to breathe. Two readings: every model agrees "
                   "that there is a loss and where it is (the south and the Mediterranean coast), "
                   "but they disagree a great deal on how much.\n\n"
                   f"Quantified: the fraction the mutant rescues runs from "
                   f"{en(N['km2_rescued_min_pct'], 1)}% ({N['km2_rescued_min_model']}) to "
                   f"{en(N['km2_rescued_max_pct'], 1)}% ({N['km2_rescued_max_model']}). It is the "
                   "figure behind the per-model range slide in section 5."),

        dict(kind="figure",
             spoken=True,
             title="Models agree on baseline chill but not on how much it falls",
             image=f"{FIG}/fig54_model_ranking_ssp370.png",
             caption=f"The {en(N['rank_spread_far_CP'], 1)} CP between the harshest model and the "
                     f"mildest one are more than the {en(N['rank_cultivar_gap_CP'], 1)} CP that "
                     f"separate the two cultivars.",
             source="§ 43_model_ranking.R · SSP3-7.0, 2071-2100 · each model against its own baseline",
             notes=f"The previous sheet shows the eleven models as maps and this one gives them a "
                   f"name and a number. It is the slide that answers 'which one is the optimist "
                   f"and which the pessimist?', which somebody always asks.\n\n"
                   f"The harsh extreme is {N['rank_worst_model']}, which drops to "
                   f"{en(N['rank_worst_swc'], 1)} CP averaged over the "
                   f"{en(N['rank_n_stations'])} stations, and the mild one is "
                   f"{N['rank_best_model']} with {en(N['rank_best_swc'], 1)}. The change against "
                   f"its own baseline is {en(abs(N['rank_delta_worst_CP']), 1)} CP in the first "
                   f"and {en(abs(N['rank_delta_best_CP']), 1)} in the second: almost a factor of "
                   f"four in the magnitude of the simulated warming. These two are means across "
                   f"stations; the adjustments section quotes the same spread as a median across "
                   f"stations, which is why the numbers there are slightly wider.\n\n"
                   f"The reading that matters is not the order but the shape. The eleven national "
                   f"baseline means fit within {en(N['rank_spread_base_CP'], 1)} CP, so the models "
                   f"disagree far less about the starting point than about the sensitivity. If "
                   f"they ask about the disagreement inside one particular station, which is a "
                   f"different thing, the median range across models there is "
                   f"{en(N['rank_station_range_base_CP'], 1)} CP. That is what the bias slide in "
                   f"section 3 says from the other side, and it is what justifies working in "
                   f"differences.\n\n"
                   f"If they ask about the exact order, two warnings worth giving before anyone "
                   f"asks. The first: the top four and the last one do not move if you take "
                   f"the median across stations instead of the mean, but "
                   f"{en(N['rank_order_swaps_mean_vs_median'])} of the eleven positions do change, "
                   f"all of them in the middle of the table. The extremes hold, the order in the "
                   f"middle does not.\n\n"
                   f"The second one is what the asterisk in the figure is for: "
                   f"{N['rank_short_window_models']} has its percentile computed over "
                   f"{en(N['rank_short_window_seasons'])} seasons and not "
                   f"{en(N['rank_modal_seasons'])}, and it is only "
                   f"{en(N['rank_best_margin_CP'], 2)} CP ahead of the next one. Two missing "
                   f"winters can move a 10th percentile by more than that, so its first place is "
                   f"not secure. The numbers for the other ten do not depend on this. Full table, "
                   f"with both orderings, in model_ranking_ssp370.csv.\n\n"
                   f"Watch out for an easy and wrong reading: "
                   f"{en(N['rank_n_below_bulida'])} models sitting below the 47.5 line does not "
                   f"mean that the whole of Spain stops working under those two, because what is "
                   f"plotted is the mean across stations and it is the map that decides. The lines "
                   f"are there as a reference of scale, not as a threshold applied to the mean."),
        dict(kind="figure",
             spoken=True,
             title="Ensemble-median chill collapses 33 model maps into three",
             image=f"{GIF}/sidebyside.gif",
             caption="The median across models, station by station, applied to each scenario and "
                     "to each window. The diagonal hatching marks where fewer than 80% of the "
                     "models agree, so the model spread just seen does not go away: it stays "
                     "drawn on top.",
             source="§ 31_scenario_frames.R · median of 11 CMIP6 models",
             gif=True,
             notes="HEADS UP: this is a GIF, it only animates in presentation mode. Let it run a "
                   "full loop in silence before saying anything.\n\n"
                   "Three things to point at: the orange grows from the south-west and from the "
                   "Mediterranean coast, the red turns up first in the Guadalquivir valley, and "
                   "at 2021-2040 the three panels are almost identical.\n\n"
                   "NEAR-CERTAIN QUESTION: at 2021-2040 SSP3-7.0 loses LESS cropland than "
                   "SSP2-4.5, which looks the wrong way round. It is not a mistake: the km² in "
                   "the frame match the table to the km². It is that at this horizon the models "
                   f"disagree by {en(N['nearterm_spread_models_CP'], 1)} CP among themselves where "
                   f"the scenarios disagree by {en(N['nearterm_spread_scenarios_CP'], 1)}. It is "
                   "worked out in section 5 and there is a backup slide in the annex."),

        dict(kind="figure",
             spoken=True,
             title="By 2100 the mutant covers half the cropland 'Búlida' loses",
             image=f"{FIG}/fig33_headline_flow.png",
             source="§ talk_numbers_cropland.csv · SSP3-7.0, 2071-2100",
             notes=f"The headline. Of the {en(N['total_cropland_km2'])} km² of cropland in Spain, "
                   f"'Búlida' stops meeting its chill requirement over {en(N['lost_km2'])} by the "
                   f"end of the century. The mutant covers {en(N['rescued_km2'])} of them, "
                   f"{en(pct_resc, 1)}%.\n\n"
                   "CAREFUL with the attribution if anyone asks: that figure is an end state, not "
                   f"a change. {en(N['baseline_already_lost_km2'])} km² were already outside "
                   f"'Búlida' in the baseline. What warming takes away is "
                   f"{en(N['warming_lost_km2'])} km², and of that the mutant rescues "
                   f"{en(N['warming_rescued_pct'], 1)}%."),

        dict(kind="figure",
             title="The mutant halves the cropland losing its chill requirement",
             image=f"{FIG}/fig30_time_of_emergence_ssp370.png",
             caption="First window in which chill drops below the requirement. In grey, the "
                     "cropland where that does not happen before 2100.",
             source="§ 33_talk_figures.R · time-of-emergence convention of Schuhen et al. "
                    "2026 (NHESS 26:753)",
             notes=f"The cropland 'Búlida' loses at some point in the century is "
                   f"{en(N['toe_pct_lost_bulida'], 1)}%; for the mutant, "
                   f"{en(N['toe_pct_lost_precoz'], 1)}%.\n\n"
                   "Two clarifications. The grey does not mean nothing happens there, it means "
                   "that cultivar's threshold is not crossed before 2100. And the mutant does not "
                   "take the problem out of the century: over that 9.5% it is crossed all the "
                   "same, only later."),

        dict(kind="figure",
             spoken=True,
             title="By 2100 half of Murcia falls in the mutant-only chill band",
             image=f"{FIG}/fig31_murcia_ensemble_requirements.png",
             source="§ 33_talk_figures.R · stations within the Region of Murcia",
             notes=f"The {en(N['murcia_stations'])} stations in the Region. The median starts at "
                   f"about 58 CP and ends at {en(N['murcia_median_far'], 1)} under SSP3-7.0.\n\n"
                   f"By the end of the century {en(N['murcia_below_bulida_pct'])}% of the stations "
                   f"sit below 47.5 CP and {en(N['murcia_below_precoz_pct'])}% sit below even "
                   "33.7. The mutant decides in the intermediate band, which is roughly half the "
                   "region; in the other half it saves nobody."),

        dict(kind="figure",
             spoken=True,
             title="Observed chill anomaly: 45 flat winters, then five mild ones",
             image=f"{FIG}/fig32_observed_stripes.png",
             source="§ 26_observed_long_record.R · per-station anomaly against the 1976-2020 "
                    "baseline",
             notes=f"Own result, not a projection. The 2021-2025 five-year block loses "
                   f"{en(abs(N['obs_recent_anom_CP']), 2)} CP against the "
                   f"{int(N['obs_baseline_first_year'])}-2020 baseline, or "
                   f"{en(abs(N['obs_recent_sd']), 2)} standard deviations, and it supplies "
                   f"{en(N['obs_recent_in_10_mildest'])} of the 10 mildest winters out of the 50. "
                   f"Of the {en(N['obs_n_baseline_blocks'])} earlier five-year blocks, "
                   f"{en(N['obs_blocks_as_mild'])} get as mild (p = "
                   f"{en(N['obs_p_exchangeable'], 4)}).\n\n"
                   "The claim is about the BLOCK, not about each winter: 2022 is middling, "
                   f"21st of 50. And careful with the word trend: the "
                   f"{en(N['obs_baseline_n_seasons'])} winters from 1976 to 2020 do not have one "
                   "(p = 0.90), but the full 50-winter record does come out significant "
                   "(p = 0.047), precisely because of this block."),

        # ---------------------------------------------------------------- 5. DISCUSSION
        dict(kind="section", n="5", title="Discussion",
             lead="Which parts of this hold up, which parts depend on the model you look at, and "
                  "what could be wrong."),

        dict(kind="figure",
             title="Sign-of-change agreement across models collapses before 2040",
             image=f"{FIG}/fig42_sign_agreement_ssp370.png",
             caption=f"Sign agreement rises from {en(N['agree_sign_nearterm'], 1)}% to "
                     f"{en(N['agree_sign_far'], 1)}% of cropland between the two windows. On the "
                     f"classification, by contrast, the models already agree over "
                     f"{en(N['agree_class_far'], 1)}% by the end of the century.",
             source="§ 36_per_model_stats.R · § 37_model_figures.R",
             notes="These are two different questions and it pays not to mix them, because this "
                   "project did mix them for a while. If the models agree on CLASSIFYING a cell "
                   "above or below 47.5 CP, agreement is high everywhere. If they agree on the "
                   "SIGN of the change in the near term, it collapses.\n\n"
                   "So: the map of where you can grow the crop holds up well; what does not hold "
                   "up is reading differences between scenarios before 2040. At 62% of the "
                   "stations the pessimistic scenario returns more chill than the optimistic one "
                   "at that horizon."),

        dict(kind="figure",
             title="Rescued cropland fraction: over area no model drops below a third",
             image=f"{FIG}/fig41_per_model_range.png",
             caption="Each point is one of the 11 models. The vertical bar is the median.",
             source="§ 36_per_model_stats.R · per_model_cropland_km2.csv",
             notes=f"Under SSP3-7.0 at the end of the century the rescued fraction runs from "
                   f"{en(N['km2_rescued_min_pct'], 1)}% ({N['km2_rescued_min_model']}) to "
                   f"{en(N['km2_rescued_max_pct'], 1)}% ({N['km2_rescued_max_model']}), with a "
                   f"median of {en(N['km2_rescued_median_pct'], 1)}%. None drops below a third, "
                   "so the qualitative conclusion does not depend on which model you believe.\n\n"
                   "The right-hand panel is there because the range the project document quotes "
                   f"({en(N['station_rescued_min_pct'], 1)}-"
                   f"{en(N['station_rescued_max_pct'], 1)}%) is measured over stations, while the "
                   "headlines are measured over area. Over area the phrase 'none drops below a "
                   "third' is true; over stations it is false. Both numbers are real; pairing "
                   "them was the mistake."),

        dict(kind="figure_side",
             title="An independent orchard series reproduces the chill anomaly",
             image=f"{FIG}/fig26_01_independent_records.png",
             points=["The Cieza series (CEBAS-CSIC) is an experimental orchard, with a different "
                     "instrument and a different operator.",
                     "Against its own 2012-2020 baseline it gives −6.84 CP, or −1.66 σ. It only "
                     "has nine years, so it takes no other baseline.",
                     "The two nearby AEMET stations, against the long 1976-2020 baseline, give "
                     "−1.45 and −1.94 σ.",
                     "The national set, against that same long baseline, gives −1.95 σ."],
             source="§ 27_cieza_independent_check.R · cieza_check_summary.csv",
             notes="Closes off the objection that 'this is a homogeneity problem in the AEMET "
                   "network'. A thermometer outside that network reproduces the drop.\n\n"
                   "Do not mix the sigmas from the two baselines when speaking: against the short "
                   "baseline the anomaly comes out larger, and presenting them together would "
                   "exaggerate the convergence."),

        dict(kind="figure_side",
             spoken=True,
             title=f"Parametrisation is the largest uncertainty: a "
                   f"{en(abs(N['param_gap_mean_CP']), 2)} CP gap",
             image=f"{FIG}/fig26_02_parametrisation_gap.png",
             points=[f"The parametrisation, and it is the largest one. The 1987 model and the "
                     f"1988 one sit {en(abs(N['param_gap_mean_CP']), 2)} CP apart over "
                     f"{en(N['param_gap_n_seasons'])} seasons at Cieza, half the gap between the "
                     f"two cultivars. If the requirements in Ruiz et al. 2019 were on the other "
                     f"scale, every area changes.",
                     "The validation is circular: ESD-RegBA was calibrated against these same "
                     "stations.",
                     "The station census: the two routes through the portal give 3,460 and 3,044, "
                     "and the validation only covers the ones they share.",
                     "The interpolation: IDW replicates Egea et al. 2022, but the recent "
                     "literature prefers kriging with covariates."],
             source="§ 27_cieza_independent_check.R · § 4.1.1 of canonical document v2",
             notes="Put it before the close and do not hide it. The first one is an open question "
                   "about the source, not a weakness of the analysis: the methods section of Ruiz "
                   "et al. 2019 cites Fishman 1987, so it is confirmation rather than an unknown, "
                   "but it is worth having in writing before publishing area figures."),

        # ---------------------------------------------------------------- 6. CLOSE
        dict(kind="close",
             spoken=True,
             title="The low-chill mutant buys time, not immunity",
             points=[f"Of the {en(N['total_cropland_km2'])} km² of cropland in Spain, 'Búlida' "
                     f"stops meeting its chill requirement over {en(N['lost_km2'])} by the end of "
                     f"the century under SSP3-7.0. Warming accounts for "
                     f"{en(N['warming_lost_km2'])} of them.",
                     f"Its somatic mutant covers {en(N['rescued_km2'])} km², half of it, and the "
                     f"range across the 11 models runs from {en(N['km2_rescued_min_pct'], 1)}% to "
                     f"{en(N['km2_rescued_max_pct'], 1)}%: none drops below a third.",
                     "No bias correction was applied, and working in differences gives the same "
                     "result, so nothing hangs on that decision.",
                     "Before 2040 the scenarios are indistinguishable: what decides those two "
                     "decades is the cultivar, not the policy.",
                     "And the observed record has already moved: the 2021-2025 five-year block is "
                     f"the poorest in chill of the {en(N['obs_n_baseline_blocks'])} before it."],
             foot="Code and figures: https://github.com/DanielGP121/plinius-apricot-winter-chill",
             notes="Close by restating the problem and the answer, not with a 'thank you'. The "
                   "line that sums it up: the mutation does not solve the warming, it shifts the "
                   "moment when another decision has to be taken."),
    ]


def annex(N):
    """Backup material, kept in its own file so the talk deck stays short enough to deliver.

    These are the slides the speaker jumps to when asked, not the ones they present. Everything
    here answers a question that has actually been asked about this work at some point: what does
    each scenario look like on its own, is the interpolated surface hiding the thresholds, are the
    two observational sources really interchangeable, and what do all fifteen situations look like
    side by side.
    """
    return [
        dict(kind="cover",
             title="Backup material",
             subtitle="The figures that answer the most likely questions from the discussion "
                      "session. They are not part of the route the talk follows.",
             authors="Daniel González-Palazón · José A. Egea",
             affil="EEAD-CSIC Zaragoza · CEBAS-CSIC Murcia",
             venue="Annex to charla_plinius.pptx · 19th Plinius Conference, Murcia, 2026",
             notes="Separate file: these are the figures to jump to when they ask, not the ones "
                   "that get presented."),

        dict(kind="figure", title="SSP1-2.6 (low emissions): cropland viability by window",
             image=f"{GIF}/ssp126.gif", gif=True,
             source="§ 31_scenario_frames.R",
             notes="Under SSP1-2.6 the mutant covers almost everything 'Búlida' loses: 89.3%."),

        dict(kind="figure", title="SSP2-4.5 (intermediate): cropland viability by window",
             image=f"{GIF}/ssp245.gif", gif=True,
             source="§ 31_scenario_frames.R",
             notes="Intermediate in the result too."),

        dict(kind="figure", title="SSP3-7.0 (severe): cropland viability by window",
             image=f"{GIF}/ssp370.gif", gif=True,
             source="§ 31_scenario_frames.R",
             notes="This is the one used in the talk because it is the one that separates the two "
                   "cultivars."),

        dict(kind="figure",
             title="SSP1-2.6 at 2071-2100: viability in each of 11 models",
             image=f"{FIG}/fig40_small_multiples_ssp126_far.png",
             caption="Ordered from the largest to the smallest fraction of cropland the mutant "
                     "still covers.",
             source="§ 37_model_figures.R · 2071-2100",
             notes="Low emissions scenario. The orange band grows with respect to the baseline, "
                   "but red barely appears. It was in the talk and moved here so as not to spend "
                   "two slides on a message the SSP3-7.0 sheet in the talk already gives."),

        dict(kind="figure",
             title="SSP2-4.5 at 2071-2100: viability in each of 11 models",
             image=f"{FIG}/fig40_small_multiples_ssp245_far.png",
             caption="The same order and the same colour scale as the previous sheet.",
             source="§ 37_model_figures.R · 2071-2100",
             notes="Intermediate scenario. Red starts to appear in the Guadalquivir and in the "
                   "south-east, and in some models quite a lot of it."),

        dict(kind="figure",
             title="Safe Winter Chill surface underlying the viability classes",
             image=f"{GIF}/swc_ssp370.gif", gif=True,
             caption="The 47.5 and 33.7 CP thresholds are applied on this surface. The classes "
                     "are not an artefact of the cut: they are a gradient that has been cut.",
             source="§ 31_scenario_frames.R · colour scale fixed across every frame",
             notes="Answers 'your map depends on the threshold'. It does, of course, but the "
                   "underlying gradient is continuous and smooth, and the threshold sweep is "
                   "quantified in 28_threshold_sweep_cropland.R."),

        dict(kind="figure",
             title="Model agreement: classification (left) vs sign of change",
             image=f"{FIG}/fig48_agreement_scale_ssp370.png",
             caption="Nothing competes for the colour here, so all six possible levels show up "
                     "instead of the single hatched band the other maps carry.",
             source="§ 37_model_figures.R · § 36_per_model_stats.R",
             notes="The map on the left is almost all green and the one on the right almost all "
                   "red, and they are the same region and the same eleven models: only the "
                   "question changes. On which side of the threshold a cell falls, the models "
                   "agree; on whether chill goes up or down twenty years from now, they do not."
                   "\n\n"
                   "Detail worth having clear in case they ask: with 11 models the majority side "
                   "cannot be smaller than 6, so agreement can only take six values (55, 64, 73, "
                   "82, 91 and 100%) and nothing below 55% exists. The AR6 criterion, 80%, falls "
                   "between 8 and 9 models."),

        dict(kind="figure",
             title="Classification agreement at 2071-2100, three scenarios",
             image=f"{FIG}/fig39_model_agreement_far.png",
             caption="The three scenarios at the end of the century, with diagonal hatching where "
                     "fewer than 80% of the models agree on the classification.",
             source="§ 36_per_model_stats.R · § 37_model_figures.R",
             notes="Complements the slide on sign-of-change agreement. Here the agreement is "
                   "about the "
                   "CLASSIFICATION, not about the sign of the change, and it is high: between 83% "
                   "and 95% of the cropland depending on the scenario. It is the argument that "
                   "the map being projected is well supported even if the near-term comparison "
                   "between scenarios is not."),

        dict(kind="figure",
             title="Why SSP3-7.0 loses less cropland than SSP2-4.5 by 2040",
             image=f"{FIG}/fig38_model_vs_scenario_spread.png",
             caption="Each row is a model; the three points are the three scenarios within that "
                     "model. The order of the colours changes from one row to the next.",
             source="§ 33_talk_figures.R · marginal stations, 2021-2040 window",
             notes="The backup slide for the most likely question of the whole session. "
                   "It is not a mistake in the assembly or in the analysis: the km² in the frame "
                   "match talk_numbers_cropland.csv to the km².\n\n"
                   "The scenario poorest in chill is SSP1-2.6 in "
                   f"{en(N['nearterm_coldest_is_ssp126'])} models, SSP2-4.5 in "
                   f"{en(N['nearterm_coldest_is_ssp245'])} and SSP3-7.0 in "
                   f"{en(N['nearterm_coldest_is_ssp370'])}. There is no stable ordering, so no "
                   "scenario is systematically the warmest at this horizon. Within a single "
                   f"model the scenarios separate by {en(N['nearterm_within_model_range_CP'], 1)} CP, "
                   f"but between models the range is {en(N['nearterm_spread_models_CP'], 1)} CP, "
                   f"almost as much as the {en(N['rank_cultivar_gap_CP'], 1)} CP that separate the "
                   "two cultivars.\n\n"
                   "If it needs finishing off: over those same stations, taking the median across "
                   f"models first gives {en(N['nearterm_order_models_first_CP'], 2)} CP and taking "
                   f"it across stations first gives {en(N['nearterm_order_stations_first_CP'], 2)} CP. "
                   "Opposite signs. When the order in which you average decides the sign, there "
                   "is no signal to measure.\n\n"
                   "What can NOT be claimed is the physical cause. Three models giving "
                   "substantially more chill under SSP3-7.0 is compatible with the aerosol effect "
                   "(that scenario assumes little air quality policy, and more aerosols cool in "
                   "the near term), but with one run per model and a 20-year window there is no "
                   "way to separate it from internal variability."),

        dict(kind="figure",
             title="Cropland area per viability class in all 15 situations",
             image=f"{FIG}/fig22_viability_bars.png",
             source="§ 19_cropland_viability_national.R · talk_numbers_cropland.csv",
             notes="Includes the observed and the simulated baselines, which let you see how "
                   "close the model is to the observations over the same period."),

        dict(kind="gallery",
             title="Contact sheet of the 15 viability maps",
             items=GALLERY_MAPS,
             source="§ 19_cropland_viability_national.R",
             notes="Contact sheet. It is there to locate at a glance the map somebody asks for "
                   "and then open the corresponding file if it needs to be seen large."),

        dict(kind="figure",
             title="Archive and API give the same Safe Winter Chill: r = 0.9865",
             image=f"{FIG}/fig23_02_api_vs_archive_swc.png",
             caption="Safe Winter Chill computed over the same seasons from the archive and from "
                     "the API: bias +0.13 CP and r = 0.9865.",
             source="§ 24_observed_api_vs_archive.R",
             notes="This is what justifies splicing the archive up to 2020 with the API from "
                   "2021. Season by season the agreement is worse (MAE 1.35 CP), but the "
                   "statistic in use is the P10 over many seasons, and there the two sources "
                   "agree."),

        dict(kind="figure",
             title="Running five-year blocks: 2021-2025 has the least chill",
             image=f"{FIG}/fig25_02_running5_blocks.png",
             source="§ 26_observed_long_record.R",
             notes="None of the 41 earlier five-year blocks drops as far as "
                   "2021-2025."),

        dict(kind="figure",
             title="Observed Safe Winter Chill shift from 1995-2020 to 1995-2025",
             image=f"{FIG}/fig24_01_swc_shift_1995_2025.png",
             source="§ 25_splice_observed_1995_2025.R",
             notes="Adding five recent years to the reference window moves chill by 0.53 CP over "
                   "the 573 stations the figure plots, and by 0.45 CP over all 665, against the "
                   "0.1 CP the model predicts for the same change of window."),
    ]
