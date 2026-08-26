"""Narrative of the talk deck, read by 35_build_talk_pptx.py.

Kept apart from the builder so the wording can be reworked without touching layout code, the same
split the project already uses for deck_content.R and 29_build_deck.R.

In the conference talk and its backup every slide title is an assertion, not a label. That is the
convention the IPCC WGI Visual Style Guide calls the intent rule and applied to every visual in the
AR6 Summary for Policymakers: write the message as a sentence, then use the sentence as the title.
A title that reads "Results" makes the audience find the message; a title that states it lets them
spend their attention on the evidence underneath.

The review deck v4() does not follow it. Fifty assertion titles read one after another stop being
titles and become a voice, so there they are the name of the thing the slide is about instead.
The requirement that survives is precision, which is what the supervision meeting of 24 August 2026
actually asked for: "Interpolation error" and "The shared atmosphere" name a variable, "Results"
does not.

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
             title="How much the answer depends on where cropland is drawn",
             image=f"{FIG}/fig6_soil_criteria_compare.png",
             points=[f"Adopted for the national maps: CORINE classes 211 to 244, excluding 231 "
                     f"(pastures). That is {en(N['total_cropland_km2'])} km² of cropland.",
                     "The map is the earlier Murcia test of the same question, over its 123 "
                     "stations: two ways of deciding whether a station sits on cropland.",
                     "Egea's criterion (≤1 km to a crop, ≤100 m of elevation difference) keeps "
                     "113 of them, the broad buffer criterion 73 and the strict one 44. No "
                     "station passes the buffer criterion without passing Egea's, so the map "
                     "has three classes and not four.",
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

        dict(kind="figure_max",
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

        dict(kind="figure_max",
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

        dict(kind="figure_max",
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

        dict(kind="figure_max",
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
             # The fifteen-minute cut drops slides 15, 16 and 31, which are where the bias
             # argument and the per-model range are shown. Everything below is anchored in a slide
             # that subset keeps: the headline flow, the Murcia panel, the animation and the
             # observed stripes.
             points_short=[f"Of the {en(N['total_cropland_km2'])} km² of cropland in Spain, "
                           f"'Búlida' stops meeting its chill requirement over "
                           f"{en(N['lost_km2'])} by the end of the century under SSP3-7.0. "
                           f"Warming accounts for {en(N['warming_lost_km2'])} of them.",
                           f"Its somatic mutant covers {en(N['rescued_km2'])} km², half of it.",
                           f"In Murcia, where the crop is, "
                           f"{N['murcia_below_bulida_pct']:.0f}% of the stations fall below "
                           f"the 'Búlida' requirement by then.",
                           "Before 2040 the three panels of the animation are hard to tell "
                           "apart: at that horizon the cultivar decides more than the policy.",
                           "And the observed record has already moved: the 2021-2025 five-year "
                           f"block is the poorest in chill of the "
                           f"{en(N['obs_n_baseline_blocks'])} before it."],
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


# =================================================================================================
# v3: the deck a co-author reads
# =================================================================================================
# The talk deck argues a result in fifteen minutes. This one has a different job: a co-author who
# has not seen any of the code needs to follow the chain from the raw files to the maps, judge each
# choice, and be able to disagree with a specific step rather than with the conclusion. So it says
# what was done, with what parameter, in what order, and what was checked afterwards.
#
# It is written to be read alone. Nothing on a slide depends on the reader having the talk, the
# method book or the repository open, and where a number would otherwise be asserted the slide
# carries the file and line it is set at.
#
# Register: describe, do not sell. The talk asserts its titles because an audience needs the message
# up front. Here the titles name the variable and say what the slide establishes, which is what the
# supervision meeting of 24 August 2026 asked for and which suits a document that will be argued
# with rather than watched.


def v3(N):
    """The methodological deck, built with `--v3`.

    Ten parts: the question, the data, chill from temperature, the time windows, points to surface,
    what was checked, what came out, what the ensemble median hides, the observed record, and what
    is still open. Built from the same metric tables as the talk, so the two cannot disagree.
    """
    return (_v3_intro(N) + _v3_data(N) + _v3_chill(N) + _v3_windows(N) + _v3_surface(N)
            + _v3_checks(N) + _v3_results(N) + _v3_spread(N) + _v3_observed(N) + _v3_open(N))


def _v3_intro(N):
    return [
        dict(kind="cover",
             title="Where a low-chill apricot mutant still works, and how that was calculated.",
             subtitle="Method and results in full, for review: the data, every parameter, the "
                      "checks that were run, and the questions still open",
             authors="Daniel González-Palazón¹ · José A. Egea² · José Antonio Campoy Corbalán¹",
             affil="¹ Estación Experimental de Aula Dei (EEAD-CSIC), Zaragoza    "
                   "² Centro de Edafología y Biología Aplicada del Segura (CEBAS-CSIC), Murcia",
             venue="Working document for the co-authors · August 2026",
             notes="This deck is meant to be read rather than delivered. It carries the whole "
                   "chain so that any single step can be argued with on its own."),

        dict(kind="bignum",
             title="The question, and the answer the pipeline gives",
             lead="'Búlida' is an apricot cultivar grown across southeastern Spain. 'Búlida "
                  "Precoz' is a natural bud sport of it that flowers earlier because it needs "
                  "less winter chill. Both were quantified in the same study and with the same "
                  "chill model, which is what makes them comparable.",
             items=[
                 dict(value="47.5 CP", label="chill required by 'Búlida', in chill portions"),
                 dict(value="33.7 CP", label="chill required by 'Búlida Precoz'"),
                 dict(value=f"{N['rank_cultivar_gap_CP']:.1f} CP",
                      label="the gap between them, and the signal this work measures"),
                 dict(value="±3.3 CP",
                      label="standard error on each threshold, from three seasons"),
             ],
             body=["Both values come from Ruiz et al. (2019), Scientia Horticulturae 254:187-192, "
                   "where the two cultivars were phenotyped side by side.",
                   "The absolute thresholds are poorly determined and the gap between them is "
                   "well determined, because the gap is a paired difference within each season. "
                   "Every claim in this deck that rests on the gap is firmer than one that rests "
                   "on a threshold."],
             source="Ruiz et al. 2019, Table 2",
             notes="Worth stating at the outset because it governs how much weight each later "
                   "number can carry."),

        dict(kind="bignum",
             title=f"Under SSP3-7.0 at 2071-2100, 'Búlida' loses "
                   f"{en(N['lost_km2'])} km² and the mutant recovers half of it",
             items=[
                 dict(value=f"{en(N['total_cropland_km2'])} km²",
                      label="Spanish cropland, the denominator for every area below"),
                 dict(value=f"{en(N['lost_km2'])} km²",
                      label=f"where 'Búlida' no longer meets its requirement "
                            f"({N['toe_pct_lost_bulida']:.1f}% of cropland)"),
                 dict(value=f"{en(N['rescued_km2'])} km²",
                      label=f"of that loss, still viable for the mutant "
                            f"({N['rescued_pct_of_lost']:.1f}%)"),
                 dict(value=f"{en(N['gone_km2'])} km²",
                      label=f"below both requirements ({N['far_pct_none']:.1f}% of cropland)"),
             ],
             body=["Under milder scenarios the mutant recovers almost all of a smaller loss. "
                   "Under the severe one it recovers half, because chill falls below even its own "
                   "requirement across a growing area. The mutant buys time rather than immunity.",
                   "The rest of this deck is how those four numbers were produced and what would "
                   "have to be wrong for them to change."],
             source="§ 19_cropland_viability_national.R · talk_numbers_cropland.csv",
             notes="These are areas of cropland, not counts of weather stations. The distinction "
                   "matters and is dealt with in the section on going from points to a surface."),

        dict(kind="stepper",
             title="The chain, in seven steps",
             steps=[
                 dict(head="Acquire",
                      body=["Daily maximum and minimum temperature, from four sources."],
                      param="88 NetCDF · ~15 GB"),
                 dict(head="Reconstruct",
                      body=["Daily values become an hourly curve from the station's latitude."],
                      param="inside chillR"),
                 dict(head="Accumulate",
                      body=["The Dynamic Model turns hourly temperature into chill portions."],
                      param="Fishman et al. 1987"),
                 dict(head="Aggregate",
                      body=["One winter gives one value; a window of winters gives its 10th "
                            "percentile."],
                      param="P10 across seasons"),
                 dict(head="Summarise",
                      body=["The eleven models are collapsed to their median at each station."],
                      param="median, not mean"),
                 dict(head="Interpolate",
                      body=["Station values become a continuous surface on a 1 km grid."],
                      param="IDW, 50 km"),
                 dict(head="Classify",
                      body=["Each cell of cropland is placed in one of three classes."],
                      param="47.5 and 33.7 CP"),
             ],
             foot=f"{en(N['chain_stations'])} stations and {en(N['chain_models'])} models give "
                  f"{en(N['chain_swc_values'])} Safe Winter Chill values in each of the 15 "
                  f"situations. Interpolating one of them fills {en(N['chain_cells'])} cells over "
                  f"Spain, of which the cropland mask keeps "
                  f"{en(N['total_cropland_km2'])} km².",
             source="§ 39_pipeline_diagram.R",
             notes="Each of these seven steps gets its own slides later. The order matters: three "
                   "of the choices in this deck are about where in this chain an operation "
                   "happens rather than about which operation it is."),

        dict(kind="table",
             title="Which steps run on the cluster, and which on a workstation",
             head=["Step", "Script", "Runs on", "Why there"],
             rows=[
                 ["Download the projections", "14_ladon_download_thredds.sh", "HPC",
                  "88 files and about 15 GB; downloading to a laptop and uploading again is the "
                  "slowest possible route"],
                 ["Compute chill nationally", "15_chill_national_parallel.R", "HPC",
                  "reads the NetCDF directly, parallel by station, about 23 h for the full run"],
                 ["Download recent observations", "21_aemet_observed_download.py", "HPC",
                  "standard library only, so it runs under any Python there; resumable"],
                 ["Merge into one table", "22_merge_chill_tables.R", "local",
                  "what comes back from the cluster is a few megabytes of chill, not gigabytes"],
                 ["Interpolate and classify", "19_cropland_viability_national.R", "local",
                  "needs the CORINE raster, which lives on the workstation"],
                 ["Repeat per model", "36_per_model_stats.R", "local",
                  "121 surfaces, about three minutes"],
                 ["Validate the interpolation", "41_idw_crossval.R", "local",
                  "leave-one-out over the same parameters"],
                 ["Figures and decks", "31 to 46", "local",
                  "every number read from a table at build time"],
             ],
             widths=[0.22, 0.24, 0.09, 0.45],
             numeric=False,
             foot="Scripts 14 and 15 are uploaded to the cluster as loose files rather than as part "
                  "of a checkout, which is why 15 deliberately does not depend on the shared path "
                  "resolver the other scripts use.",
             source="§ 39_pipeline_diagram.R · README of the repository",
             notes="Worth knowing before reading the rest: nothing in this pipeline needs a "
                   "queueing system or a cluster allocation. The heavy step is one long "
                   "single-node run, and it checkpoints so a broken connection costs one "
                   "model-scenario combination at most."),
    ]


def _v3_data(N):
    return [
        dict(kind="section", n="1", title="The data",
             lead="Four sources, none of them produced here. What each one is, how it was "
                  "obtained, and what it cannot do."),

        dict(kind="datacard",
             title="Four inputs, with the dimensions they actually have",
             items=[
                 dict(head="Climate projections",
                      sub="PNACC AR6, ESD-RegBA statistical downscaling, from the AdapteCCa "
                          "THREDDS server",
                      rows=[("models", "11 CMIP6"),
                            ("experiments", "hist + 3 SSP"),
                            ("variables", "tasmax, tasmin"),
                            ("files", "88, ~15 GB"),
                            ("stations", f"{en(N['timeline_n_stations_proj'])}"),
                            ("span", "1950-2100")],
                      note="The portal's web form serves the same product over 3,044 stations. "
                           "The route has to be declared or the areas cannot be reproduced."),
                 dict(head="Observed archive",
                      sub="PNACC observational product, requested through a web form and "
                          "delivered by email",
                      rows=[("stations", f"{en(N['timeline_n_stations_obs'])}"),
                            ("span", f"{N['timeline_archive_first_year']:.0f}-"
                                     f"{N['timeline_archive_last_year']:.0f}"),
                            ("days", "16,802"),
                            ("gaps", "none"),
                            ("layout", "station × time"),
                            ("ends", "2020")],
                      note="This product stops in 2020 and cannot be extended by this route. It "
                           "is the year of the dataset, not an access limitation."),
                 dict(head="Observed, recent",
                      sub="AEMET OpenData, daily climatological values, REST API in two steps",
                      rows=[("stations", "666"),
                            ("of archive", f"{en(N['timeline_n_stations_obs'])}"),
                            ("span", f"{N['timeline_api_first_year']:.0f}-"
                                     f"{N['timeline_api_last_year']:.0f}"),
                            ("per request", "6 months"),
                            ("throttled to", "40/min"),
                            ("role", "extension")],
                      note="Covers 22% of the network and only 131 stations reach back to 1995, "
                           "so it extends the record rather than defining it."),
                 dict(head="Cropland",
                      sub="CORINE Land Cover 2018, Copernicus, 100 m raster in EPSG:3035",
                      rows=[("classes", "211-244"),
                            ("excluded", "231 pasture"),
                            ("area", f"{en(N['total_cropland_km2'])} km²"),
                            ("of Spain", "46%"),
                            ("resolution", "100 m"),
                            ("use", "denominator")],
                      note=None),
             ],
             foot="The first three are temperature; the fourth decides which parts of the map are "
                  "counted at all.",
             source="§ 2 of the canonical project document",
             notes="The two warnings on this slide are the ones that would cost someone else time "
                   "if they tried to rebuild this."),

        dict(kind="figure",
             title="What each source covers, and which stretch of each one is used",
             image=f"{FIG}/fig53_data_coverage_timeline.png",
             caption="Upper lanes: the period each source spans, with the stretch actually used "
                     "shaded. Lower lanes: the four analysis windows, which tile 1995-2100 "
                     "without gaps or overlaps.",
             source="§ 42_data_timeline.R",
             notes="The seam at 2015 is where the CMIP6 historical experiment ends and the "
                   "scenarios begin. Any window crossing it has to be assembled from two files, "
                   "which is the subject of a later slide."),

        dict(kind="table",
             title="The portal serves the projections over two different station sets",
             head=["", "THREDDS, the route used here", "The portal's web form"],
             rows=[
                 ["Stations", "3,460", "3,044"],
                 ["Models", "the same 11", "the same 11"],
                 ["Downscaling method", "ESD-RegBA", "ESD-RegBA"],
                 ["Scenarios offered", "5, including SSP5-8.5", "one per request"],
                 ["Values", "rounded to 0.1 °C", "full decimals"],
                 ["Array layout", "time × station", "station × time"],
                 ["Time origin", "days since 1850", "hours since 1900"],
             ],
             widths=[0.28, 0.36, 0.36],
             numeric=False,
             emphasis=0,
             foot="Established by arithmetic on the delivered file, then confirmed value by "
                  "value on the 123 stations of Murcia for UKESM1-0-LL, the model most at risk "
                  "because it uses a different realisation: correlation 0.9999916, maximum "
                  "difference 0.05 °C, which disappears on rounding. It is one product in two "
                  "packagings, and the 3,044 are an ordered subset of the 3,460.",
             source="§ 2.1.1 of the canonical project document",
             notes="Two consequences. Methods has to name the route, and the validation of the "
                   "model against observations could only be measured on the 3,044 common "
                   "stations, so 416 stations enter the interpolation without ever having been "
                   "compared against an observed counterpart."),

        dict(kind="twocol",
             title="The observed record needs two products, and they had to be shown to agree",
             image=f"{FIG}/fig23_02_api_vs_archive_swc.png",
             image_frac=0.5,
             blocks=[
                 dict(head="Why two",
                      body=["The archive is dense and complete but stops in 2020. The API reaches "
                            "2025 but covers 666 stations and is thin before 2008. Neither one "
                            "spans the period on its own."]),
                 dict(head="How they were compared",
                      body=["Season by season over the 8,979 winters both report, with the same "
                            "completeness filter applied to each. Comparing the aggregate instead "
                            "would have measured sample size rather than agreement."]),
                 dict(head="What came out",
                      body=["Over the 196 stations with at least fifteen seasons in common, Safe "
                            "Winter Chill agrees to 0.13 CP with a spatial correlation of 0.9865. "
                            "Season by season the agreement is looser, MAE 1.35 CP over all "
                            "8,979 winters, but the statistic in use is a percentile."]),
                 dict(head="The rule adopted",
                      body=["The archive supplies every season to 2020 and the API only the "
                            "2021-2025 extension. The thinner source never overwrites the denser "
                            "one."]),
             ],
             source="§ 24_observed_api_vs_archive.R · § 25_splice_observed_1995_2025.R",
             notes="The residual worry is that both halves come from the same national network, "
                   "so a change in AEMET processing around 2021 would look like a climate signal. "
                   "That is what the Cieza check later in the deck is for."),
    ]


def _v3_chill(N):
    return [
        dict(kind="section", n="2", title="From temperature to chill",
             lead="How a pair of daily temperatures becomes one number per winter per station, and "
                  "which decisions inside that conversion carry the most weight."),

        dict(kind="stepper",
             title="Four operations turn daily temperature into Safe Winter Chill",
             steps=[
                 dict(head="Daily to hourly",
                      body=["chillR builds an idealised daily curve from the station's latitude "
                            "and the day of the year.",
                            "No hourly observations are used anywhere in this work."],
                      param="fix_weather(end_at_present = FALSE)"),
                 dict(head="Hourly to chill portions",
                      body=["The Dynamic Model accumulates chill hour by hour, with an "
                            "intermediate state that can be reversed by warm spells."],
                      param="DM_JOSE, Fishman 1987"),
                 dict(head="Portions to a season",
                      body=["Accumulation runs from 1 November to 28 February and the total is "
                            "that winter's chill."],
                      param="Julian day 305 to 59"),
                 dict(head="Seasons to one number",
                      body=["Safe Winter Chill is the 10th percentile across the winters of a "
                            "window, so it describes a bad year rather than an average one."],
                      param="P10 across seasons"),
             ],
             foot="The argument for a percentile rather than a mean is agronomic: an orchard is "
                  "not helped by knowing that a typical winter delivers enough chill, because the "
                  "one winter in ten that does not is the one that costs the crop.",
             source="§ 15_chill_national_parallel.R:116, :318-319, :346",
             notes="The first step is worth flagging to anyone who works with chill: the hourly "
                   "reconstruction is chillR's, not something this project implemented, and it is "
                   "the largest un-inspected component of the chain."),

        dict(kind="twocol",
             title="The Dynamic Model is not a temperature index, and that changes how it reads",
             image=f"{FIG}/fig34_dynamic_model_response.png",
             image_frac=0.5,
             blocks=[
                 dict(head="Where it accumulates",
                      body=[f"The response peaks near {N['dm_optimum_temp_C']:.0f} °C, at "
                            f"{N['dm_optimum_cp_day']:.2f} chill portions per day, and falls away "
                            f"on both sides."]),
                 dict(head="Where it does not",
                      body=[f"At 0 °C it delivers {N['dm_pct_at_0C']:.0f}% of its optimum. Above "
                            "14 °C it accumulates nothing at all; below −4 °C it is down to two "
                            "hundredths of a percent of the optimum and reaches exactly zero near "
                            "−8 °C."]),
                 dict(head="Why that matters here",
                      body=["A severe cold snap contributes no chill. Storm Filomena in January "
                            "2021 is the clearest case: a memorable freeze in a winter this work "
                            "records as chill-poor, with no contradiction between the two."]),
                 dict(head="And why it matters for a mild winter",
                      body=["The same shape means a warm Mediterranean winter loses chill faster "
                            "than a linear index would suggest, because it spends its hours on "
                            "the falling side of the curve."]),
             ],
             source="§ 34_method_figures.R · DM_JOSE.R",
             notes="This slide exists because the single most common misreading of these maps is "
                   "to treat chill portions as a proxy for how cold a winter was."),

        dict(kind="params",
             title="The chill model, its constants, and how it enters the chain",
             rows=[
                 ["Implementation", "DM_JOSE.R, the Dynamic Model under the Fishman et al. (1987) "
                                    "parametrisation, used unmodified", "DM_JOSE.R:4-5"],
                 ["Constants", "E0 4457.8 · E1 10161.9 · A0 419700 · A1 1.797e14 · slope 1.6 · "
                               "Tf 277", "DM_JOSE.R:4-5"],
                 ["How it is called", "passed to chillR as models = list(Chill_Portions = "
                                      "DM_JOSE), unwrapped", "15_chill_national_parallel.R:318"],
                 ["Computed alongside", "Utah_Model, kept as a secondary metric and not used in "
                                        "any map", "15_...:319"],
                 ["Season", "Julian day 305 to 59, 1 November to 28 February", "15_...:116"],
                 ["Safe Winter Chill", "10th percentile of seasonal chill portions within a "
                                       "station and window", "15_...:346"],
                 ["Season discarded if", "fewer than 85% of days present", "15_...:116, :339"],
                 ["Station discarded if", "more than 40% missing in Tmax or Tmin, or fewer than 3 "
                                          "valid seasons", "15_...:117, :344"],
                 ["Fill-value guard", "values outside −90 to 70 °C masked; four models ship −999 "
                                      "while declaring NaN", "15_...:118, :271"],
             ],
             key_frac=0.20, src_frac=0.22, size=12,
             foot="Every value above is read from the file named beside it. The provenance column "
                  "is there so none of this has to be taken on trust.",
             source="§ 15_chill_national_parallel.R · DM_JOSE.R",
             notes="The fill-value guard was not defensive programming. Four of the eleven models "
                   "ship −999 as a fill value while declaring NaN in the metadata, so ncdf4 reads "
                   "them as real temperatures of −999 °C."),

        dict(kind="twocol",
             title=f"The 1987 and 1988 parametrisations differ by "
                   f"{abs(N['param_gap_mean_CP']):.2f} chill portions on the same data",
             image=f"{FIG}/fig26_02_parametrisation_gap.png",
             image_frac=0.5,
             blocks=[
                 dict(head="What was compared",
                      body=[f"Both parametrisations run over the same "
                            f"{N['param_gap_n_seasons']:.0f} seasons of the CEBAS orchard record "
                            f"at Cieza, with everything else held identical."]),
                 dict(head="The size of it",
                      body=[f"The 1988 version, which is chillR's default Dynamic_Model, returns "
                            f"{abs(N['param_gap_mean_CP']):.2f} CP less on average, ranging from "
                            f"{abs(N['param_gap_max_CP']):.2f} to "
                            f"{abs(N['param_gap_min_CP']):.2f} CP."]),
                 dict(head="Why a constant will not fix it",
                      body=["The offset is not stable. It widens in the mildest winters, which "
                            "are precisely the ones that decide whether a threshold is crossed."]),
                 dict(head="What is at stake",
                      body=[f"The two cultivars are separated by {N['rank_cultivar_gap_CP']:.1f} "
                            f"CP. An offset of {abs(N['param_gap_mean_CP']):.2f} CP is half the "
                            f"signal being measured, so supply and demand have to be on the same "
                            f"scale or the comparison is empty."]),
             ],
             source="§ 27_cieza_independent_check.R · cieza_numbers.csv",
             notes="This is why the project uses DM_JOSE rather than chillR's default. The "
                   "methods section of Ruiz et al. 2019 states that the requirements were "
                   "quantified with Fishman 1987, which is what makes the choice consistent. "
                   "Confirming that reading is the first open question at the end of this deck."),

        dict(kind="twocol",
             title="Safe Winter Chill describes the tenth-percentile winter, not the average one",
             image=f"{FIG}/fig35_swc_concept.png",
             image_frac=0.5,
             blocks=[
                 dict(head="The construction",
                      body=["Each winter in the window gives one chill total. Safe Winter Chill "
                            "is the value that nine winters in ten exceed."]),
                 dict(head="On a real station",
                      body=[f"Station {N['swc_example_station']} averages "
                            f"{N['swc_example_mean']:.1f} CP across its seasons but has a Safe "
                            f"Winter Chill of {N['swc_example_p10']:.1f} CP. Planting to the mean "
                            f"would over-state what the site can support by "
                            f"{N['swc_example_mean'] - N['swc_example_p10']:.1f} CP."]),
                 dict(head="What it costs",
                      body=["A percentile needs enough seasons to be a percentile rather than a "
                            "minimum. That is why records of different length are compared season "
                            "by season and never as aggregates."]),
                 dict(head="Where it comes from",
                      body=["The definition, the season limits and the percentile are all taken "
                            "from the method used in Egea et al. (2022), so the numbers here are "
                            "comparable with that work."]),
             ],
             source="§ 34_method_figures.R · § 15_chill_national_parallel.R:346",
             notes="The window-length point is the reason the archive and the API were never "
                   "compared on their aggregates: a P10 over 12 seasons is close to a minimum, "
                   "while a P10 over 26 is a genuine decile."),

        dict(kind="figure",
             title="What the quality filters discard, and at which step",
             image=f"{FIG}/fig51_attrition_funnel.png",
             caption="One panel per unit, because stations, seasons and square kilometres cannot "
                     "share an axis: on a common scale the discarded seasons would draw a bar four "
                     "times the width of the discarded stations and say nothing.",
             source="§ 40_attrition_funnel.R",
             notes="The figure carries a guard that refuses to draw if its denominator disagrees "
                   "with talk_numbers_cropland.csv, so it cannot quietly show a different total "
                   "from the rest of the deck."),
    ]


def _v3_windows(N):
    return [
        dict(kind="section", n="3", title="The time windows",
             lead="Which periods are compared against which, why the baseline stops where it "
                  "does, and what had to be assembled because no single file contains it."),

        dict(kind="table",
             title="Four windows tile 1995 to 2100 without gaps or overlaps",
             head=["Window", "Years", "Seasons", "Source", "Role"],
             rows=[
                 ["Baseline", "1995-2020", f"{N['timeline_seasons_base']:.0f}",
                  "historical + SSP, spliced", "reference for every difference"],
                 ["Near term", "2021-2040", f"{N['timeline_seasons_nearterm']:.0f}",
                  "SSP only", "the horizon of a planting decision"],
                 ["Mid century", "2041-2070", f"{N['timeline_seasons_near']:.0f}",
                  "SSP only", "tiles the middle of the century"],
                 ["End century", "2071-2100", f"{N['timeline_seasons_far']:.0f}",
                  "SSP only", "where the headline figures come from"],
                 ["Observed", "1995-2020", f"{N['timeline_seasons_base']:.0f}",
                  "PNACC archive", "validates the baseline, not a window"],
                 ["Current climate", "1995-2025", "31",
                  "historical + SSP, spliced", "most recent picture; never a reference"],
             ],
             widths=[0.17, 0.13, 0.11, 0.28, 0.31],
             numeric=False,
             foot="An apricot orchard produces for 25 to 30 years, which is why 2021-2040 exists "
                  "at all: it is the horizon that matters to anyone planting now, and the original "
                  "plan jumped straight from the historical period to 2041-2070.",
             source="§ 15_chill_national_parallel.R:126-132 · § 22_merge_chill_tables.R:49-59",
             notes="The last row is the one to watch. The current-climate panel overlaps the near "
                   "term by five years, so it can be shown but must never be the reference a "
                   "future is differenced against."),

        dict(kind="compare",
             title="The baseline does not exist in any single file and had to be assembled",
             left=dict(head="CMIP6 historical", big="≤ 2014",
                       lines=["The historical experiment ends on 31 December 2014, by design of "
                              "the CMIP6 protocol",
                              "It is not a data limitation and no amount of downloading extends "
                              "it",
                              "Supplies the first twenty years of the baseline window"]),
             right=dict(head="SSP scenarios", big="≥ 2015",
                        lines=["The scenario runs begin on 1 January 2015",
                               "SSP2-4.5 supplies the 2015-2020 stretch, once per model rather "
                               "than three times",
                               "Before 2020 the three scenarios have barely separated, so the "
                               "choice costs almost nothing and saves two thirds of the compute"]),
             foot="The join was checked on the real series: no duplicated days, no missing days, "
                  "and a physically continuous transition across 31 December 2014 to 1 January "
                  "2015. The assembled situation is labelled 'presente' throughout the outputs.",
             source="§ 15_chill_national_parallel.R:159, :295-302",
             notes="This is the step most likely to be questioned, and it is worth being explicit "
                   "that the splice scenario is a parameter (--splice-scenario) rather than "
                   "something hard-wired."),

        dict(kind="twocol",
             title="A baseline of 1995-2025 would have cancelled a quarter of the near-term change",
             image=f"{FIG}/fig37_baseline_today.png",
             image_frac=0.48,
             blocks=[
                 dict(head="The temptation",
                      body=["Using the most recent possible baseline, 1995-2025, looks like the "
                            "honest choice: it is the climate growers actually experience."]),
                 dict(head="Why it fails",
                      body=["It would share 2021 to 2025 with the near-term window. Five of those "
                            "twenty years would sit inside the reference as well as inside the "
                            "future, so a quarter of the change would cancel by construction and "
                            "2021-2040 would look artificially flat."]),
                 dict(head="What was done instead",
                      body=["The baseline stops at 2020 and the current-climate panel exists "
                            "separately, shown but never differenced against."]),
                 dict(head="What it costs",
                      body=["The baseline is five years older than it could be. Measured on the "
                            "observed record, moving the window from 1995-2020 to 1995-2025 "
                            "shifts chill by about half a chill portion, so the cost is small and "
                            "known."]),
             ],
             source="§ 34_method_figures.R · § 25_splice_observed_1995_2025.R",
             notes="If a reviewer only argues with one window choice, it will be this one, and "
                   "the answer is that the alternative is not neutral."),
    ]


def _v3_surface(N):
    return [
        dict(kind="section", n="4", title="From points to a surface",
             lead="The chill is computed at weather stations and the question is about territory. "
                  "This is the step that bridges them, and the one that carries the most "
                  "assumptions."),

        dict(kind="twocol",
             title="Counting stations does not estimate territory, so the unit is cropland area",
             image=f"{FIG}/fig36_method_chain.png",
             image_frac=0.5,
             blocks=[
                 dict(head="The problem with stations",
                      body=["Weather stations cluster in valleys, airports and towns: 306 of "
                            "them sit on just 151 coordinates. A percentage of stations is a "
                            "statistic about the network, not about Spain."]),
                 dict(head="What is reported instead",
                      body=["Every headline in this work is square kilometres of cropland. Each "
                            "1 km cell contributes its own fraction of CORINE cropland rather "
                            "than counting as a whole cell."]),
                 dict(head="It changes the answer",
                      body=[f"The fraction the mutant recovers spans "
                            f"{N['station_rescued_min_pct']:.1f}% to "
                            f"{N['station_rescued_max_pct']:.1f}% across models when measured on "
                            f"stations, and {N['km2_rescued_min_pct']:.1f}% to "
                            f"{N['km2_rescued_max_pct']:.1f}% when measured on area. Only the "
                            f"second is the unit the conclusions use."]),
                 dict(head="The cost",
                      body=["It introduces an interpolation, which introduces an error. That "
                            "error is measured later in this deck rather than assumed away."]),
             ],
             source="§ 19_cropland_viability_national.R · § 36_per_model_stats.R",
             notes="An earlier version of the project documentation quoted the station range "
                   "beside a claim that only holds on the area range. Keeping the two units "
                   "clearly apart is deliberate."),

        dict(kind="params",
             title="Every parameter of the spatial step, and where each one is set",
             rows=[
                 ["Ensemble statistic", "median across the 11 models, taken at the station, "
                                        "before anything spatial happens",
                  "19_cropland_viability_national.R:66"],
                 ["Interpolation", "inverse distance weighting, terra::interpIDW", "19_...:151"],
                 ["Power", "2", "19_...:44"],
                 ["Search radius", "50 km, which also acts as the mask: a cell with no station "
                                   "within 50 km stays empty", "19_...:43, :151"],
                 ["Neighbours", "at most 12 per cell", "19_...:45"],
                 ["Grid", "1 km, EPSG:3035, an equal-area projection", "19_...:37-40"],
                 ["Cell area", "computed from the realised resolution, not the nominal one",
                  "00_corine.R:43-46"],
                 ["Cropland mask", "CORINE 2018 classes 211-244, excluding 231 pasture, verified "
                                   "against class labels rather than a column name",
                  "00_corine.R:24-28"],
                 ["Area weighting", "each cell contributes its cropland fraction, from a 100 m "
                                    "raster averaged onto the 1 km grid", "19_...:124, :157"],
                 ["Classification", "≥ 47.5 CP both cultivars · ≥ 33.7 CP mutant only · below "
                                    "that neither", "19_...:139-141"],
             ],
             key_frac=0.19, src_frac=0.24, size=11.5,
             foot="The interpolation replicates the method of Egea et al. (2022), which "
                  "interpolated by IDW and masked to 50 km from the nearest station. That work "
                  "had 270 stations after quality control; this one has "
                  f"{en(N['chain_stations'])}.",
             source="§ 19_cropland_viability_national.R · § 00_corine.R",
             notes="The cell-area row looks like pedantry and is not. terra honours the extent it "
                   "is given and adjusts the resolution to fit whole cells, so a nominal 1 km "
                   "grid over Spain has cells of 1000.32 by 999.99 m. Using the nominal value put "
                   "every area in this project 0.031% low until it was found."),

        dict(kind="twocol",
             title="Where the median is taken decides what the maps are a statistic of",
             image=f"{FIG}/fig44_aggregation_chain.png",
             image_frac=0.52,
             blocks=[
                 dict(head="What the pipeline does",
                      body=["Eleven chill values per station are collapsed to their median, and "
                            "the median surface is then interpolated and classified. Every "
                            "published square kilometre is therefore a statistic of a surface "
                            "that no individual model produced."]),
                 dict(head="Why the median and not the mean",
                      body=["The distribution across models is skewed by its harshest members, so "
                            "a mean is pulled by them. Egea et al. (2022) used an ensemble mean; "
                            "this work uses the median for that reason."]),
                 dict(head="The alternative",
                      body=["Classify each model on its own and aggregate the eleven resulting "
                            "areas at the end. That is what 36_per_model_stats.R computes, and "
                            "the comparison between the two orders appears later in this deck."]),
                 dict(head="Where it does not apply",
                      body=["The agreement counter compares each model against itself in the "
                            "baseline, never against the ensemble, so a model's own bias is not "
                            "counted as climate change."]),
             ],
             source="§ 38_method_figures.R · § 36_per_model_stats.R",
             notes="This is one of the two places where a reviewer could reasonably say the "
                   "pipeline does the wrong thing, so the deck measures it rather than defending "
                   "it."),

        dict(kind="figure",
             title=f"The whole chain on one station: {N['walk_station']}, from daily temperature "
                   f"to classified cropland",
             image=f"{FIG}/fig46_station_walkthrough.png",
             caption=f"Observed Safe Winter Chill {N['walk_p10_obs']:.1f} CP, modelled baseline "
                     f"{N['walk_med_base']:.1f} CP, and {N['walk_med_far']:.1f} CP at 2071-2100 "
                     f"under SSP3-7.0, ending in the classified land within 50 km of the station.",
             source="§ 38_method_figures.R",
             notes="A single worked example is the fastest way to check that the chain does what "
                   "the previous slides claim. Every number on it can be traced back to the "
                   "canonical table."),
    ]


def _v3_checks(N):
    return [
        dict(kind="section", n="5", title="What was checked",
             lead="Four things could have made the maps wrong without anything failing: the models "
                  "could disagree with observations, the interpolation could invent detail, the "
                  "observed record could be an artefact, and the choice of absolute values over "
                  "differences could carry a bias. Each was measured."),

        dict(kind="twocol",
             title=f"Model minus observed is {N['bias_ensemble_CP']:.2f} CP over the same period "
                   f"and the same stations",
             image=f"{FIG}/fig43_model_bias.png",
             image_frac=0.5,
             blocks=[
                 dict(head="How it was measured",
                      body=[f"Identical window, 1995-2020, and the "
                            f"{en(N['n_bias_stations'])} stations both products share. Comparing "
                            f"different periods or different networks would have measured "
                            f"something else."]),
                 dict(head="The result",
                      body=[f"Ensemble bias {N['bias_ensemble_CP']:.2f} CP. Per model it runs "
                            f"from {N['bias_min_CP']:.2f} CP ({N['bias_min_model']}) to "
                            f"+{N['bias_max_CP']:.2f} CP ({N['bias_max_model']}), a span of "
                            f"{N['bias_range_CP']:.1f} CP, and the worst single model is "
                            f"{N['bias_worst_abs_CP']:.2f} CP out."]),
                 dict(head="What follows",
                      body=["No bias correction is applied and absolute values are used rather "
                            "than differences from a baseline."]),
                 dict(head="The caveat that has to travel with it",
                      body=["ESD-RegBA was calibrated against these same stations, so this is not "
                            "an independent validation. It shows the downscaling did what it was "
                            "fitted to do."]),
             ],
             source="§ 38_method_figures.R · method_chain_numbers.csv",
             notes="The caveat is not a formality. It is the reason the deck also carries a check "
                   "against a record from outside the AEMET network."),

        dict(kind="twocol",
             title=f"Leaving each station out gives an interpolation RMSE of "
                   f"{N['idw_rmse_base_CP']:.2f} CP at the baseline",
             image=f"{FIG}/fig52_idw_crossval.png",
             image_frac=0.52,
             blocks=[
                 dict(head="The test",
                      body=[f"Each of {en(N['idw_n_stations_far'])} stations is removed in turn "
                            f"and predicted from the others with the production parameters. "
                            f"Predictions are made at the station's own coordinate rather than at "
                            f"a cell centre, so grid offset does not inflate the error."]),
                 dict(head="The size of the error",
                      body=[f"RMSE {N['idw_rmse_base_CP']:.2f} CP at the baseline and "
                            f"{N['idw_rmse_far_CP']:.2f} CP at 2071-2100 under SSP3-7.0, which is "
                            f"{N['idw_pct_of_gap_base']:.0f}% and "
                            f"{N['idw_pct_of_gap_far']:.0f}% of the gap between the two "
                            f"cultivars."]),
                 dict(head="Three limits on reading it",
                      body=["It is measured at stations, and the network is dense enough that "
                            "none is more than 27 km from a neighbour, so it says nothing about "
                            "genuinely isolated ground.",
                            "There is a floor: where two station codes share a coordinate their "
                            "own observations differ by 1.02 CP.",
                            "The residual has a slope with altitude, −2.94 CP per 1,000 m, and "
                            "that is not corrected."]),
                 dict(head="What it is not",
                      body=["It is not a confidence interval and is not presented as one."]),
             ],
             source="§ 41_idw_crossval.R · idw_crossval_summary.csv",
             notes="Until this was run the interpolation was justified by citing Egea et al. "
                   "(2022) and its error had never been measured. The altitude slope is the way "
                   "an IDW fails in a mountainous country and is worth raising with a reviewer."),

        dict(kind="bignum",
             title="One RMSE from a threshold: how much land the interpolation could reclassify",
             lead="The error above matters only where it could move a cell across 47.5 or 33.7 "
                  "chill portions. Measuring that turns an abstract RMSE into an area.",
             items=[
                 dict(value=f"{N['idw_band_pct_base']:.1f}%",
                      label="of cropland sits within one RMSE of a threshold at the baseline"),
                 dict(value=f"{N['idw_band_pct_far']:.1f}%",
                      label="the same at 2071-2100 under SSP3-7.0"),
                 dict(value=f"{en(N['idw_band_km2_far'])} km²",
                      label="that second figure as area, against a national cropland of "
                            f"{en(N['total_cropland_km2'])} km²"),
             ],
             body=["The band widens through the century because the surface flattens as it warms: "
                   "more of the country ends up near a threshold rather than far from one.",
                   "This is the number to quote when asked how firm the boundary between the "
                   "classes is. It is a statement about where the map is fragile, not a claim "
                   "that those cells are misclassified."],
             source="§ 41_idw_crossval.R · idw_threshold_band.csv",
             notes="Reported alongside the maps rather than buried, because a reader who sees a "
                   "crisp three-colour map will otherwise assume the boundaries are crisp too."),

        dict(kind="twocol",
             title="An orchard record from outside the AEMET network shows the same recent drop",
             image=f"{FIG}/fig26_01_independent_records.png",
             image_frac=0.52,
             blocks=[
                 dict(head="Why it was needed",
                      body=["Both halves of the observed record come from the same national "
                            "network, so a change in AEMET's processing around 2021 would look "
                            "exactly like a climate signal."]),
                 dict(head="The independent series",
                      body=[f"The CEBAS experimental orchard at Cieza, {N['cieza_first_day']} to "
                            f"{N['cieza_last_day']}, {en(float(N['cieza_days']))} days with "
                            f"{float(N['cieza_missing_days']):.0f} missing, measured with CEBAS "
                            f"instruments and published with Muñoz-Morales et al. (2025)."]),
                 dict(head="What it shows",
                      body=["A recent anomaly of −1.66 standard deviations against −1.95 "
                            "nationally. In absolute chill portions the local drop is much "
                            "larger, because Murcia is a low-chill area where the model is more "
                            "sensitive, but in standard deviations the two agree."]),
                 dict(head="What it does not show",
                      body=["It corroborates that the winters were warm. No published series of "
                            "accumulated chill exists to check the magnitude of the drop in chill "
                            "portions against."]),
             ],
             source="§ 27_cieza_independent_check.R",
             notes="A first attempt averaged the five AEMET stations nearest Cieza and was "
                   "discarded: only one of them has recent data, so the average changed "
                   "composition in 2021 and would have mixed a change of network with a change of "
                   "climate."),

        dict(kind="twocol",
             title="Absolute chill and change-from-baseline give the same direction, not the same "
                   "map",
             image=f"{FIG}/fig45_delta_vs_absolute.png",
             image_frac=0.52,
             blocks=[
                 dict(head="Two ways to report",
                      body=["Absolute Safe Winter Chill, which can be compared against a cultivar "
                            "requirement, or the change from the model's own baseline, which "
                            "cancels the model's bias."]),
                 dict(head="Why absolute is used here",
                      body=["The question is whether a threshold is crossed, and a threshold is "
                            "an absolute quantity. A change of −13 CP says nothing about whether "
                            "47.5 is still met."]),
                 dict(head="What the change says",
                      body=[f"Median loss of {abs(N['delta_median_CP']):.1f} CP by 2071-2100 "
                            f"under SSP3-7.0, ranging from {abs(N['delta_max_CP']):.1f} to "
                            f"{abs(N['delta_min_CP']):.1f} CP across models."]),
                 dict(head="The limit of the argument",
                      body=["Differencing cancels a model's bias only for the change. The "
                            "classification is an absolute comparison against 47.5 and 33.7 CP, "
                            "so it never benefits from that cancellation. This is the strongest "
                            "reason the bias check above had to be run."]),
             ],
             source="§ 38_method_figures.R",
             notes="Raised by a cold-read audit of the method book, which pointed out that the "
                   "bias-cancels argument was being applied to a step it does not cover."),
    ]


def _v3_results(N):
    return [
        dict(kind="section", n="6", title="What came out",
             lead="The maps, the areas, and how the answer moves between scenarios and across the "
                  "century."),

        dict(kind="figure",
             title="Baseline 1995-2020: almost all Spanish cropland still meets both requirements",
             image=f"{FIG}/fig20_02_viability_presente_present.png",
             caption=f"Blue: both cultivars viable. Orange: only 'Búlida Precoz'. Red: neither. "
                     f"Model agreement is reported separately, not on this map. National median "
                     f"Safe Winter Chill {N['base_swc_median_CP']:.1f} CP.",
             source="§ 19_cropland_viability_national.R",
             notes="This is the reference every later map is read against. The orange band already "
                   f"exists at the baseline, covering {en(N['baseline_already_lost_km2'])} km², "
                   "which matters when attributing the future band to warming."),

        dict(kind="figure",
             title="SSP3-7.0 at 2071-2100: the orange band spreads and a red core appears",
             image=f"{FIG}/fig20_15_viability_ssp370_far.png",
             caption=f"{N['far_pct_both']:.1f}% of cropland still supports both cultivars, "
                     f"{N['far_pct_only']:.1f}% only the mutant, and {N['far_pct_none']:.1f}% "
                     f"neither. National median Safe Winter Chill "
                     f"{N['far_swc_median_CP']:.1f} CP.",
             source="§ 19_cropland_viability_national.R",
             notes="The red is the part that matters agronomically: it is where the mutant stops "
                   "being an answer at all. It concentrates on the Mediterranean coast and the "
                   "southern valleys, which is where the crop actually is."),

        dict(kind="figure",
             title="The three scenarios side by side, 1995 to 2100",
             image=f"{GIF}/sidebyside.gif",
             gif=True,
             caption="One frame per window, the same colour scale and extent throughout, so what "
                     "moves is the land and not the legend.",
             source="§ 31_scenario_frames.R · § 32_make_gifs.py",
             notes="Before 2040 the three panels are hard to tell apart, and that is the finding "
                   "rather than a defect of the animation. The next section quantifies it."),

        dict(kind="figure",
             title="Every scenario and window as shares of cropland",
             image=f"{FIG}/fig22_viability_bars.png",
             caption="Fifteen situations on one axis, from the observed baseline at the top to "
                     "SSP3-7.0 at end of century at the bottom.",
             source="§ 19_cropland_viability_national.R",
             notes="The shape to notice is that the orange band grows steadily while the red one "
                   "stays near zero until the severe scenario at end of century, and then jumps. "
                   "The mutant absorbs the loss until it cannot."),

        dict(kind="bignum",
             title="How much of the loss is warming, and how much was already there",
             lead="Attributing the mutant's usefulness to climate change requires subtracting the "
                  "band that exists in the baseline, on both sides of the fraction.",
             items=[
                 dict(value=f"{en(N['baseline_already_lost_km2'])} km²",
                      label="already beyond 'Búlida' in the 1995-2020 baseline"),
                 dict(value=f"{en(N['warming_lost_km2'])} km²",
                      label="lost to warming by 2071-2100 under SSP3-7.0, net of that"),
                 dict(value=f"{en(N['warming_rescued_km2'])} km²",
                      label=f"of that warming-driven loss recovered by the mutant "
                            f"({N['warming_rescued_pct']:.1f}%)"),
             ],
             body=[f"Reporting {N['rescued_pct_of_lost']:.1f}% without this subtraction would "
                   f"credit the mutant with land it already covered before any warming. The "
                   f"attributed figure is {N['warming_rescued_pct']:.1f}%.",
                   "Both numbers are correct answers to different questions, and the deck states "
                   "which is which rather than choosing the larger one."],
             source="§ 19_cropland_viability_national.R · talk_key_numbers.csv",
             notes="A cold-read audit found this exact figure unreconstructable in an earlier "
                   "draft, because the numerator was never published. It is on the slide now."),

        dict(kind="twocol",
             title="When the boundary moves, not just where it ends up",
             image=f"{FIG}/fig30_time_of_emergence_ssp370.png",
             image_frac=0.54,
             blocks=[
                 dict(head="What it shows",
                      body=["The window in which each parcel of cropland first stops meeting "
                            "the 'Búlida' requirement, under SSP3-7.0."]),
                 dict(head="Why it is worth separating",
                      body=[f"An end-of-century map says {N['toe_pct_lost_bulida']:.1f}% of "
                            f"cropland is lost. It does not say whether that happens in 2035 or "
                            f"in 2095, and a grower planting a 25-year orchard needs the second "
                            f"answer."]),
                 dict(head="How to read the classes",
                      body=["Land that fails in the near term is already committed. Land that "
                            "fails only at end of century is where mitigation and cultivar choice "
                            "still change the outcome."]),
             ],
             source="§ 33_talk_figures.R",
             notes="This is the figure that turns the work from a map into advice, and it is "
                   "where the conversation with growers would start."),

        dict(kind="twocol",
             title=f"Murcia, where the crop actually is: median "
                   f"{N['murcia_median_far']:.1f} CP by 2071-2100",
             image=f"{FIG}/fig31_murcia_ensemble_requirements.png",
             image_frac=0.54,
             blocks=[
                 dict(head="Why zoom",
                      body=[f"Región de Murcia holds the production this work is about. Its "
                            f"{N['murcia_stations']:.0f} stations are shown against both cultivar "
                            f"requirements rather than as a map."]),
                 dict(head="What happens there",
                      body=[f"By 2071-2100 under SSP3-7.0, "
                            f"{N['murcia_below_bulida_pct']:.1f}% of those stations fall below "
                            f"the 'Búlida' requirement and {N['murcia_below_precoz_pct']:.1f}% fall "
                            f"below the mutant's."]),
                 dict(head="The reading",
                      body=["In the region that matters most commercially, the mutant is not a "
                            "solution for half the sites: it is a delay. The national figures are "
                            "kinder than the regional ones because the north of Spain carries "
                            "them."]),
             ],
             source="§ 33_talk_figures.R",
             notes="Requested in supervision on 24 August: the national map is the headline, but "
                   "the regional zoom is what a Murcian audience will ask about."),
    ]


def _v3_spread(N):
    return [
        dict(kind="section", n="7", title="What the ensemble median hides",
             lead="Every map so far is the median of eleven models. This section is what that "
                  "median costs, measured four ways, because it is where the work is most open to "
                  "challenge."),

        dict(kind="figure",
             title="The eleven models ranked by the chill they leave at 2071-2100",
             image=f"{FIG}/fig54_model_ranking_ssp370.png",
             caption=f"National mean Safe Winter Chill per model under SSP3-7.0. "
                     f"{N['rank_worst_model']} leaves {N['rank_worst_swc']:.1f} CP and "
                     f"{N['rank_best_model']} leaves {N['rank_best_swc']:.1f} CP, a spread of "
                     f"{N['rank_spread_far_CP']:.1f} CP against "
                     f"{N['rank_spread_base_CP']:.1f} CP at the baseline.",
             source="§ 43_model_ranking.R",
             notes=f"Two cautions carried on the figure itself. The ordering is not stable: "
                   f"{N['rank_order_swaps_mean_vs_median']:.0f} of eleven positions move between "
                   f"a mean and a median. And {N['rank_short_window_models']} computes its "
                   f"percentile over {N['rank_short_window_seasons']:.0f} seasons rather than "
                   f"{N['rank_modal_seasons']:.0f}, while leading the next model by only "
                   f"{N['rank_best_margin_CP']:.2f} CP, so its first place is not secure."),

        dict(kind="annotated",
             title="The eleven models, unsummarised, ordered by how much of the loss the "
                   "mutant still covers",
             image=f"{FIG}/fig40_small_multiples_ssp370_far.png",
             notes_frac=0.26,
             callouts=[
                 dict(at=(0.078, 0.34),
                      text="IITM-ESM, the optimistic bound. The band where only the mutant works "
                           "barely leaves the coast, and almost nothing is lost outright."),
                 dict(at=(0.805, 0.66),
                      text="UKESM1-0-LL, the pessimistic bound. Red covers the whole southern "
                           "half and the orange band has moved inland behind it."),
                 dict(at=(0.605, 0.68),
                      text="ACCESS-CM2, and beside it KACE-1-0-G. These two and UKESM1-0-LL "
                           "share an atmospheric component, so a third of the panels on this "
                           "sheet are not independent draws."),
                 dict(at=(0.545, 0.23),
                      text="The northern half stays blue in all eleven. Where the models disagree "
                           "is the southern and coastal ground, which is where the crop is."),
             ],
             source="§ 37_model_figures.R",
             notes="This is the sheet to look at before accepting any single map in this deck. "
                   "The ensemble median is one summary of these eleven, and the eleven do not "
                   "agree about the part of Spain the question is about."),

        dict(kind="twocol",
             title="Model sensitivity explains the harsh end of the ranking but not the mild end",
             image=f"{FIG}/fig55_model_sensitivity.png",
             image_frac=0.56,
             blocks=[
                 dict(head="What is plotted",
                      body=["Each model's transient climate response against the chill it leaves "
                            "at 2071-2100. Sensitivity values are from IPCC AR6 WG1 Chapter 7 "
                            "Supplementary Material, Table 7.SM.5."]),
                 dict(head="The harsh end",
                      body=["UKESM1-0-LL has the highest sensitivity of the eleven, above the AR6 "
                            "assessed likely range on both metrics, and it leaves the least "
                            "chill. ACCESS-CM2 leaves the second least, though on sensitivity it "
                            "ranks third by transient response and fourth by equilibrium."]),
                 dict(head="The mild end is not explained",
                      body=["IITM-ESM leaves the most chill, yet its transient "
                            "response sits mid-table, above four models that leave less chill "
                            "than it does. Low sensitivity is not why it is the optimistic "
                            "outlier."]),
                 dict(head="Why that matters",
                      body=["If the optimistic bound of this work rests on a regional feature of "
                            "one model rather than on its global sensitivity, screening the "
                            "ensemble by sensitivity would not address it."]),
             ],
             source="§ 46_model_sensitivity.R · IPCC AR6 WG1 Ch.7 SM Table 7.SM.5",
             notes="This is the first of two slides written to be argued with. The AR6 table "
                   "leaves IITM-ESM's equilibrium sensitivity blank; the value shown for it comes "
                   "from the Zelinka et al. 2020 dataset and is marked as such on the figure."),

        dict(kind="table",
             title="Three of the eleven share one atmosphere, and the selection filter could not "
                   "see it",
             head=["Model", "Chill left, CP", "TCR °C", "ECS °C", "Atmospheric component"],
             rows=[
                 ["UKESM1-0-LL", "41.1", "2.79", "5.34", "MetUM-HadGEM3-GA7.1"],
                 ["ACCESS-CM2", "46.0", "2.10", "4.72", "MetUM-HadGEM3-GA7.1"],
                 ["EC-Earth3-Veg", "51.5", "2.62", "4.31", "other"],
                 ["CMCC-CM2-SR5", "53.7", "2.09", "3.52", "other"],
                 ["KACE-1-0-G", "56.3", "2.04", "4.75", "MetUM-HadGEM3-GA7.1"],
                 ["CNRM-ESM2-1", "57.1", "1.86", "4.76", "other"],
                 ["MRI-ESM2-0", "58.2", "1.64", "3.15", "other"],
                 ["NorESM2-MM", "59.6", "1.33", "2.50", "other"],
                 ["MIROC6", "60.8", "1.55", "2.61", "other"],
                 ["MPI-ESM1-2-HR", "60.9", "1.66", "2.98", "other"],
                 ["IITM-ESM", "62.3", "1.71", "2.37 *", "other"],
             ],
             widths=[0.24, 0.16, 0.13, 0.13, 0.34],
             numeric=True,
             foot="The three models naming MetUM-HadGEM3-GA7.1 declare a byte-identical atmosphere but come from "
                  "different institutions, and they hold ranks 1, 2 and 5 for harshness. "
                  "* IITM-ESM's ECS is absent from AR6 and comes from Zelinka et al. 2020.",
             source="AEMET Nota Técnica 41 · WCRP CMIP6 controlled vocabulary · AR6 Table 7.SM.5",
             notes="The eleven were selected by AEMET on skill, on data availability, and on one "
                   "model per institutional family, with a final check that the subset still "
                   "spanned the spread of the full ensemble. That filter operates on the "
                   "institution, so three models sharing MetUM-HadGEM3-GA7.1 pass through it as "
                   "independent draws.\n\n"
                   "This is a question for a reviewer, not a claim that the ensemble is wrong. "
                   "The measured effect on the national median is small; whether the shared "
                   "atmosphere biases the spatial pattern over Iberia has not been tested."),

        dict(kind="table",
             title="Aggregating before or after classification changes the areas by at most "
                   f"{N['agg_max_abs_shift_pct']:.1f}%",
             head=["Class", "Median first, km²", "Classify first, km²", "Difference"],
             rows=[
                 ["Both cultivars", f"{en(N['agg_both_median_first_km2'])}",
                  f"{en(N['agg_both_classify_first_km2'])}",
                  f"{N['agg_both_shift_pct']:+.1f}%"],
                 ["Only 'Búlida Precoz'", f"{en(N['agg_only_median_first_km2'])}",
                  f"{en(N['agg_only_classify_first_km2'])}",
                  f"{N['agg_only_shift_pct']:+.1f}%"],
                 ["Neither", f"{en(N['agg_none_median_first_km2'])}",
                  f"{en(N['agg_none_classify_first_km2'])}",
                  f"{N['agg_none_shift_pct']:+.1f}%"],
                 ["Headline: share of the loss recovered",
                  f"{N['agg_headline_median_first_pct']:.1f}%",
                  f"{N['agg_headline_classify_first_pct']:.1f}%",
                  f"{N['agg_headline_shift_points']:+.1f} points"],
             ],
             widths=[0.34, 0.22, 0.22, 0.22],
             emphasis=3,
             foot="The objection is real and general: averaging a climate before running an "
                  "impact model can destroy the signal, and plant thresholds are the textbook "
                  "case. Measured here on SSP3-7.0 at 2071-2100 it is a second-order effect, which "
                  "converts a methodological complaint into a robustness result. The middle column "
                  "does not sum to the national cropland, and cannot: each class median comes from "
                  "a different model.",
             source="§ 45_v3_numbers.py · per_model_cropland_km2.csv",
             notes="Worth being clear about what this does and does not settle. It compares the "
                   "median of eleven areas against the area of the median surface. It does not "
                   "test reporting the fraction of models that place each cell in each class, "
                   "which is a different and arguably better presentation."),

        dict(kind="twocol",
             title=f"The models agree on the class over {N['agree_class_far']:.0f}% of cropland at "
                   f"end of century",
             image=f"{FIG}/fig39_model_agreement_far.png",
             image_frac=0.54,
             blocks=[
                 dict(head="Which question is being answered",
                      body=["Agreement is three different questions with three different answers, "
                            "and the maps answer the first: is this cell above or below a "
                            "threshold?"]),
                 dict(head="On the classification",
                      body=[f"{N['agree_class_far']:.1f}% of cropland has at least 9 of 11 models "
                            f"on the same side at 2071-2100 under SSP3-7.0, and between 92.6% "
                            f"and 99.1% in the other situations. This is the map that gets "
                            f"projected, "
                            f"and it is well supported."]),
                 dict(head="On the direction of change",
                      body=[f"{N['agree_sign_nearterm']:.1f}% at 2021-2040 against "
                            f"{N['agree_sign_far']:.1f}% at 2071-2100. The collapse in the near "
                            f"term is why the scenarios cannot be told apart at that horizon."]),
                 dict(head="On the narrow band",
                      body=[f"Agreement that a cell falls between 33.7 and 47.5 CP is rare: "
                            f"{N['band_agree_min_pct']:.2f}% to {N['band_agree_max_pct']:.2f}% of "
                            f"cropland across the "
                            f"{float(N['band_agree_n_situations']):.0f} situations, and "
                            f"{N['band_agree_far_pct']:.2f}% at 2071-2100 under SSP3-7.0. Hitting "
                            f"a 13.8 CP band is a far harder target than picking a side, so this "
                            f"figure alone would understate what the models do support."]),
             ],
             source="§ 37_model_figures.R · § 00_hatch.R",
             notes="With eleven models, agreement counted as the larger side can only take six "
                   "values: 6, 7, 8, 9, 10 or 11 out of 11. A legend promising a 50% band would "
                   "describe something the data cannot produce, which is why the hatching is "
                   "binary at the AR6 80% criterion."),

        dict(kind="bignum",
             title="On area, the eleven models disagree by more than a factor of ten",
             lead="The same spread, expressed in the unit the conclusions use rather than in chill "
                  "portions. All figures are SSP3-7.0 at 2071-2100.",
             items=[
                 dict(value=f"{en(N['spread_none_min_km2'])} – {en(N['spread_none_max_km2'])}",
                      label=f"km² where neither cultivar works, across the "
                            f"{N['spread_n_models']:.0f} models: a factor of "
                            f"{N['spread_none_ratio']:.1f}"),
                 dict(value=f"{en(N['spread_only_min_km2'])} – {en(N['spread_only_max_km2'])}",
                      label="km² recovered by the mutant"),
                 dict(value=f"{N['km2_rescued_min_pct']:.1f} – {N['km2_rescued_max_pct']:.1f}%",
                      label="the share of the loss it recovers, median "
                            f"{N['km2_rescued_median_pct']:.1f}%"),
             ],
             body=["The right-hand figure is the most robust statement in this work, because it rests on "
                   "the gap between the cultivars rather than on either threshold. No model puts "
                   "it below a third.",
                   "The left-hand one is the least robust, and a single-number headline for it would "
                   "be misleading. The data provider's own guidance discourages reducing an "
                   "ensemble to one value, and whether the area figures should carry a band is an "
                   "open question at the end of this deck."],
             source="§ 36_per_model_stats.R · per_model_cropland_km2.csv",
             notes="Putting the factor of fifteen on a slide is deliberate. It is the number a "
                   "reviewer would find on their own, and finding it unannounced would undermine "
                   "everything else."),
    ]


def _v3_observed(N):
    return [
        dict(kind="section", n="8", title="The observed record",
             lead="A result that is not a projection: what the last fifty winters actually did, "
                  "and why it reframes the near-term message."),

        dict(kind="figure",
             title=f"No trend from {N['obs_baseline_first_year']:.0f} to 2020, then five winters "
                   f"{abs(N['obs_recent_anom_CP']):.1f} CP below it",
             image=f"{FIG}/fig25_01_observed_chill_series_1976_2025.png",
             caption=f"Observed Safe Winter Chill as anomalies, {N['obs_record_n_seasons']:.0f} "
                     f"seasons. The 1976-2020 baseline has no trend (p = 0.90); 2021-2025 sits "
                     f"{abs(N['obs_recent_anom_CP']):.2f} CP below it, "
                     f"{abs(N['obs_recent_sd']):.2f} standard deviations.",
             source="§ 26_observed_long_record.R",
             notes=f"Four of the five recent winters are among the ten mildest of the fifty "
                   f"(p = {N['obs_p_exchangeable']:.3f} under exchangeability), and of the "
                   f"{N['obs_n_baseline_blocks']:.0f} five-season blocks in the baseline, "
                   f"{N['obs_blocks_as_mild']:.0f} reach as low. One caveat travels with it: the "
                   f"five-year running mean has been falling since 2005, so the recent block "
                   f"sharpens a decline that had already begun rather than appearing from "
                   f"nowhere."),

        dict(kind="twocol",
             title="Before 2040 the scenarios cannot be told apart, and that is a result",
             image=f"{FIG}/fig38_model_vs_scenario_spread.png",
             image_frac=0.54,
             blocks=[
                 dict(head="Measured where it matters",
                      body=[f"On the {N['nearterm_marginal_stations']:.0f} stations whose chill "
                            f"sits near the 'Búlida' threshold at 2021-2040, which is where the "
                            f"distinction actually decides something."]),
                 dict(head="The comparison",
                      body=[f"The three scenarios differ by "
                            f"{N['nearterm_spread_scenarios_CP']:.1f} CP and the eleven models by "
                            f"{N['nearterm_spread_models_CP']:.1f} CP, five times as much."]),
                 dict(head="It is not even ordered",
                      body=[f"{N['nearterm_models_favouring_ssp370']:.0f} of eleven models give "
                            f"more chill under SSP3-7.0 than under SSP2-4.5 (sign test "
                            f"p = {N['nearterm_sign_test_p']:.2f}), and the chill-poorest scenario "
                            f"is SSP1-2.6 in {N['nearterm_coldest_is_ssp126']:.0f} models, "
                            f"SSP2-4.5 in {N['nearterm_coldest_is_ssp245']:.0f} and SSP3-7.0 in "
                            f"{N['nearterm_coldest_is_ssp370']:.0f}."]),
                 dict(head="What it changes",
                      body=["The near term is shown as one pooled panel rather than three. Three "
                            "panels would invite the reader to conclude that the pessimistic "
                            "scenario is better, which the data do not support."]),
             ],
             source="§ 33_talk_figures.R · talk_key_numbers.csv",
             notes=f"The sign even depends on the order of averaging: taking the median across "
                   f"models first gives SSP3-7.0 {N['nearterm_order_models_first_CP']:+.1f} CP "
                   f"against SSP2-4.5, and across stations first gives "
                   f"{N['nearterm_order_stations_first_CP']:+.1f}. A quantity whose sign is "
                   f"decided by the order of two medians is not measuring anything."),
    ]


def _v3_open(N):
    return [
        dict(kind="section", n="9", title="What is still open",
             lead="Five questions whose answers would change either the numbers or how they have "
                  "to be reported. They are listed in the order of how much they would move."),

        dict(kind="params",
             title="Five open questions, and what each one would change",
             rows=[
                 ["1. Parametrisation",
                  "Were the 47.5 and 33.7 CP requirements quantified with Fishman 1987 or with "
                  "chillR's 1988 default? Supply is computed with 1987.",
                  "would move every area"],
                 ["", "If 1988, the equivalent thresholds on the 1987 scale are near 54 and 41 "
                      "CP and every area figure is recomputed. The threshold sweep already "
                      "exists, so this is a re-run rather than new work.", "28_threshold_sweep"],
                 ["2. Interpolation",
                  "Gómez-Ramos et al. (2024) found Safe Winter Chill interpolates less accurately "
                  "than mean chill, and chill consistently overestimated in warm coastal areas.",
                  "would change every map"],
                 ["", "That bias would fall exactly on the warm, low-chill ground where the "
                      "distinction between the two cultivars is decided. If it is material at "
                      "3,460 stations, the honest presentation is station-level classification "
                      "with an uncertainty mask rather than a continuous surface.", "41_idw_crossval"],
                 ["3. Reporting the spread",
                  "Should the area figures carry a band rather than a single median, given that "
                  "the classes span a factor of fifteen across models?",
                  "would change the framing"],
                 ["", "The provider's own guidance discourages reducing an ensemble to one value. "
                      "The per-model areas are already computed, so this is a decision about "
                      "presentation rather than about analysis.", "36_per_model_stats"],
                 ["4. Model subset",
                  "Does the atmosphere shared by UKESM1-0-LL, KACE-1-0-G and ACCESS-CM2 warrant "
                  "down-weighting, and why is IITM-ESM the mild outlier?",
                  "would move the median"],
                 ["", "The measured effect on the national median is small. Whether the shared "
                      "atmosphere biases the pattern over Iberia rather than the national mean "
                      "has not been tested.", "46_model_sensitivity"],
                 ["5. Excluding SSP5-8.5",
                  "The accepted abstract names RCP8.5 and the analysis uses SSP1-2.6, SSP2-4.5 "
                  "and SSP3-7.0. The reference justifying the exclusion is not recorded.",
                  "needed for the caption"],
             ],
             key_frac=0.17, src_frac=0.19, size=10.5,
             foot="None of these is a defect found after the fact. Each was raised while the "
                  "pipeline was being built and left open because answering it needs a decision "
                  "that is not the analyst's to make alone.",
             source="§ 10.4 of the canonical project document",
             notes="The first question is the one that has been open longest and the one with the "
                   "largest consequence: the offset between the two parametrisations is half the "
                   "gap between the two cultivars."),

        dict(kind="close",
             title="Where this stands",
             points=[
                 f"The computation is finished: {en(N['chain_stations'])} stations and "
                 f"{N['chain_models']:.0f} models over four analysis windows, giving "
                 f"{en(N['chain_swc_values'])} Safe Winter Chill values per situation.",

                 f"Under SSP3-7.0 at 2071-2100, 'Búlida' stops meeting its requirement on "
                 f"{en(N['lost_km2'])} km² of cropland and 'Búlida Precoz' recovers "
                 f"{N['rescued_pct_of_lost']:.1f}% of that, "
                 f"{N['warming_rescued_pct']:.1f}% once the baseline band is subtracted.",

                 "The firmest number is the share of the loss the mutant recovers, because it "
                 "rests on the gap between the cultivars. The weakest are the absolute areas, "
                 "because they rest on thresholds carrying a standard error of 3.3 CP.",

                 "Everything here is reproducible from the repository, and every figure quoted "
                 "is read from a table at build time rather than typed onto a slide.",
             ],
             foot="Code and documentation: https://github.com/DanielGP121/plinius-apricot-winter-chill",
             notes="The purpose of this deck is to make each step arguable on its own. Comments "
                   "on any single slide are more useful than a verdict on the whole."),
    ]

# --- v4: the review deck ------------------------------------------------------------------------
#
# Same material as v3 and a different contract with the reader. v3 put the whole argument on the
# slides, 33,860 characters of it, and left its figures at a fifth of the page. Here each slide
# carries one claim and its evidence, the argument that used to sit beside a picture moves to the
# method book that travels with this deck, and anything that was a list of relations is drawn as
# one: a chain as a chain, four windows on an axis, three thresholds as three bands of a scale.
#
# The two national maps are the case that motivated the rework. They arrive from R with a printed
# title, a subtitle and a legend row, all of which the slide already carried, plus a quarter of the
# canvas in white. Cropped and given a side rail, the same picture goes from a fifth of the page to
# nearly half of it, which is what the supervision meeting of 24 August 2026 asked for.
#
# MAP_CROP is tied to the layout of 19_cropland_viability_national.R: the fractions remove the
# title band above the map and the legend row below it. Measured on the row ink profile of
# fig20_15, not guessed. If that script's layout changes, this is the constant to re-measure.

MAP_CROP = (0.114, 0.056)

# The scripts the parameter tables point at, named once so a rename is one edit and the tables
# cannot disagree about how a file is spelled. A row gives (file, [lines]), where a line is an int
# or an inclusive (from, to) pair; the builder checks every one of them against the file on disk
# and prints only the file name on the slide.
CHILL = "15_chill_national_parallel.R"
VIABILITY = "19_cropland_viability_national.R"
CORINE = "00_corine.R"
DM_JOSE = "DM_JOSE.R"


def v4(N):
    """The review deck, built with `--v4`.

    Ten parts in the order a reader needs them: the question, the data, chill from temperature, the
    time windows, points to a surface, what was checked, what came out, what the ensemble median
    hides, the observed record, and what is still open. Built from the same metric tables as the
    talk and as v3, so none of the three can disagree with the others.
    """
    return (_v4_open(N) + _v4_data(N) + _v4_chill(N) + _v4_windows(N) + _v4_surface(N)
            + _v4_checks(N) + _v4_results(N) + _v4_spread(N) + _v4_observed(N)
            + _v4_questions(N))


def _v4_open(N):
    return [
        dict(kind="cover",
             title="Where a low-chill apricot mutant still works, and how that was calculated.",
             subtitle="Method and results for review: the data, the parameters, the checks, and "
                      "the questions still open",
             authors="Daniel González-Palazón¹ · José A. Egea² · José Antonio Campoy Corbalán¹",
             affil="¹ Estación Experimental de Aula Dei (EEAD-CSIC), Zaragoza    "
                   "² Centro de Edafología y Biología Aplicada del Segura (CEBAS-CSIC), Murcia",
             venue="Working document for the co-authors · August 2026",
             notes="This deck is meant to be read rather than delivered. Each slide carries one "
                   "claim so that it can be argued with on its own. The full reasoning behind "
                   "every step is in the method book that travels with it."),

        dict(kind="scale",
             title="The two chill requirements",
             span=(0, 80), thresholds=(33.7, 47.5),
             marks=[dict(at=N["base_swc_median_CP"],
                         label=f"cropland median today, "
                               f"{N['base_swc_median_CP']:.1f} CP")],
             foot="'Búlida' needs 47.5 chill portions, its bud sport 'Búlida Precoz' 33.7. Both "
                  "were phenotyped side by side in Ruiz et al. (2019), which is what makes them "
                  "comparable.",
             source="Ruiz et al. 2019, Table 2 · § 19_cropland_viability_national.R",
             notes="Each threshold carries a standard error of 3.3 CP from three seasons, so the "
                   "absolute positions of the two lines are poorly determined. The distance "
                   "between them is not, because it is a paired difference within each season. "
                   "Every claim in this deck that rests on the gap is firmer than one that rests "
                   "on a threshold, and the deck says which is which."),

        dict(kind="bignum", slim=True,
             title="Cropland lost and recovered, SSP3-7.0 at 2071-2100",
             items=[
                 dict(value=f"{en(N['total_cropland_km2'])} km²", label="Spanish cropland"),
                 dict(value=f"{en(N['lost_km2'])} km²",
                      label=f"below the 'Búlida' requirement ({N['toe_pct_lost_bulida']:.1f}%)"),
                 dict(value=f"{en(N['rescued_km2'])} km²",
                      label=f"of that, still viable for the mutant "
                            f"({N['rescued_pct_of_lost']:.1f}%)"),
                 dict(value=f"{en(N['gone_km2'])} km²",
                      label=f"below both ({N['far_pct_none']:.1f}% of cropland)"),
             ],
             source="§ 19_cropland_viability_national.R · talk_numbers_cropland.csv",
             notes="The mutant buys time rather than immunity. Under milder scenarios it recovers "
                   "almost all of a smaller loss; under the severe one it recovers half, because "
                   "chill falls below even its own requirement across a growing area.\n\n"
                   "These are areas of cropland, not counts of weather stations, and the two units "
                   "give different answers. The section on going from points to a surface deals "
                   "with why area is the one reported. Under milder scenarios the mutant recovers "
                   "almost all of a smaller loss; under the severe one it recovers half, because "
                   "chill falls below even its own requirement across a growing area."),

        dict(kind="flow",
             title="The chain, end to end",
             steps=[
                 dict(head="Acquire", body="Daily maximum and minimum temperature.",
                      param="88 NetCDF · 15 GB"),
                 dict(head="Reconstruct", body="Daily values become an hourly curve.",
                      param="latitude, inside chillR"),
                 dict(head="Accumulate", body="Hourly temperature becomes chill portions.",
                      param="Fishman et al. 1987"),
                 dict(head="Aggregate", body="A window of winters gives one value.",
                      param="10th percentile"),
                 dict(head="Summarise", body="Eleven models become one number per station.",
                      param="median, not mean"),
                 dict(head="Interpolate", body="Stations become a continuous surface.",
                      param="IDW, 50 km"),
                 dict(head="Classify", body="Each cell of cropland gets one of three classes.",
                      param="47.5 and 33.7 CP"),
             ],
             foot=f"{en(N['chain_stations'])} stations × {en(N['chain_models'])} models = "
                  f"{en(N['chain_swc_values'])} values per situation, over 15 situations. "
                  f"Interpolating one fills {en(N['chain_cells'])} cells.",
             source="§ 39_pipeline_diagram.R",
             notes="Steps 1 to 3 run on the cluster as one 23 h single-node run that checkpoints, "
                   "and everything after them on a workstation, because what comes back is "
                   "megabytes of chill rather than gigabytes of temperature. No queueing system "
                   "is involved anywhere.\n\n"
                   "Each step gets its own slides later. The order matters more than it looks: "
                   "three of the choices argued about in this deck are about where in this chain "
                   "an operation happens rather than about which operation it is."),

    ]


def _v4_data(N):
    return [
        dict(kind="section", n="1", title="The data",
             lead="Four sources, none of them produced here."),

        dict(kind="cards",
             title="The four inputs",
             items=[
                 dict(head="Climate projections", stat="11 models",
                      body="PNACC AR6, ESD-RegBA downscaling, from THREDDS. 88 files, 15 GB, "
                           "1950-2100.",
                      chip=f"{en(N['timeline_n_stations_proj'])} stations"),
                 dict(head="Observed archive", stat=f"{N['timeline_archive_last_year']:.0f}",
                      body="PNACC observational product, by web form. Daily, no gaps. The year it "
                           "stops, not an access limit.",
                      chip=f"{en(N['timeline_n_stations_obs'])} stations"),
                 dict(head="Observed, recent", stat="22%",
                      body=f"AEMET OpenData REST API. Extends the record to "
                           f"{N['timeline_api_last_year']:.0f}, and covers 22% of the network.",
                      chip="666 stations"),
                 dict(head="Cropland", stat=f"{en(N['total_cropland_km2'])} km²",
                      body="CORINE 2018, 100 m raster, classes 211-244. Decides what is counted "
                           "at all.",
                      chip="46% of Spain"),
             ],
             source="§ 2 of the canonical project document",
             notes="The two warnings here are the ones that would cost someone else time. The "
                   "archive cannot be extended past 2020 by any route, and the API covers 22% of "
                   "the network with only 131 stations reaching back to 1995, so it extends the "
                   "record rather than defining it.\n\n"
                   "The projections are also served over a second station set by the portal's web "
                   "form, which is the subject of a later slide: the route has to be declared or "
                   "the areas cannot be reproduced."),

        dict(kind="figure_max",
             title="Coverage of each source",
             image=f"{FIG}/fig53_data_coverage_timeline.png",
             source="§ 42_data_timeline.R",
             notes="Upper lanes: the period each source spans, with the stretch actually used "
                   "shaded. Lower lanes: the four analysis windows, which tile 1995-2100 without "
                   "gaps or overlaps. The seam at 2015 is where the CMIP6 historical experiment "
                   "ends and the scenarios begin, so any window crossing it is assembled from two "
                   "files."),

        dict(kind="figure_note",
             title="Archive against API",
             image=f"{FIG}/fig23_02_api_vs_archive_swc.png",
             note_frac=0.30,
             notes_side=[
                 dict(head="How", body="Season by season over the 8,979 winters both report, with "
                                       "the same completeness filter on each."),
                 dict(head="Result", body="0.13 CP over the 196 stations with fifteen seasons in "
                                          "common, spatial correlation 0.9865."),
                 dict(head="Caveat", body="Season by season the agreement is looser, MAE 1.35 CP. "
                                          "The statistic in use is a percentile."),
             ],
             source="§ 24_observed_api_vs_archive.R",
             notes="The rule adopted: the archive supplies every season to 2020 and the API only "
                   "the 2021-2025 extension, so the thinner source never overwrites the denser "
                   "one. Neither product spans the period alone.\n\n"
                   "Comparing the aggregates instead would have measured sample size rather than "
                   "agreement. The residual worry is that both halves come from the same national "
                   "network, so a change in AEMET processing around 2021 would look like a "
                   "climate signal. That is what the Cieza check later in the deck is for."),

        dict(kind="table", slim=True,
             title="Two download routes, two station sets",
             head=["", "THREDDS, used here", "The portal's web form"],
             rows=[
                 ["Stations", "3,460", "3,044"],
                 ["Models", "the same 11", "the same 11"],
                 ["Downscaling", "ESD-RegBA", "ESD-RegBA"],
                 ["Scenarios", "5, incl. SSP5-8.5", "one per request"],
                 ["Values", "rounded to 0.1 °C", "full decimals"],
             ],
             widths=[0.28, 0.36, 0.36],
             numeric=False, emphasis=0,
             foot="One product in two packagings: the 3,044 are an ordered subset of the 3,460.",
             source="§ 2.1.1 of the canonical project document",
             notes="Established by arithmetic on the delivered file, then confirmed value by value "
                   "on the 123 stations of Murcia for UKESM1-0-LL, the model most at risk because "
                   "it uses a different realisation: correlation 0.9999916, maximum difference "
                   "0.05 °C, which disappears on rounding.\n\n"
                   "Two consequences. Methods has to name the route, and the model-observation "
                   "comparison could only be measured on the 3,044 common stations, so 416 "
                   "stations enter the interpolation without an observed counterpart."),
    ]


def _v4_chill(N):
    return [
        dict(kind="section", n="2", title="From temperature to chill",
             lead="How two daily temperatures become one number per winter per station."),

        dict(kind="flow",
             title="From daily temperature to Safe Winter Chill",
             steps=[
                 dict(head="Daily to hourly",
                      body="An idealised curve from latitude and day of year.",
                      param="fix_weather()"),
                 dict(head="Hourly to portions",
                      body="Accumulated hour by hour, through a state warm spells can reverse.",
                      param="DM_JOSE, Fishman 1987"),
                 dict(head="Portions to a season",
                      body="1 November to 28 February. The total is that winter's chill.",
                      param="Julian day 305 to 59"),
                 dict(head="Seasons to one number",
                      body="The 10th percentile across a window: a bad year, not a typical one.",
                      param="P10 across seasons"),
             ],
             foot="The winter in ten that falls short is the one that costs the crop.",
             source="§ 15_chill_national_parallel.R:116, :318-319, :346",
             notes="No hourly observations are used anywhere in this work: the reconstruction is "
                   "chillR's own, from latitude and day of year. Worth flagging to anyone who "
                   "works with chill, because it is the largest un-inspected component of the "
                   "chain.\n\n"
                   "The argument for a percentile rather than a mean is agronomic. An orchard is "
                   "not helped by knowing that a typical winter delivers enough chill."),

        dict(kind="figure_note",
             title="Response of the Dynamic Model",
             image=f"{FIG}/fig34_dynamic_model_response.png",
             note_frac=0.27,
             notes_side=[
                 dict(head="Where it accumulates",
                      body=f"Peak near {N['dm_optimum_temp_C']:.0f} °C, at "
                           f"{N['dm_optimum_cp_day']:.2f} CP per day."),
                 dict(head="Where it does not",
                      body=f"{N['dm_pct_at_0C']:.0f}% of the optimum at 0 °C. Nothing above 14 °C, "
                           f"and effectively nothing below −4 °C."),
                 dict(head="Why it matters",
                      body="Storm Filomena was a memorable freeze in a winter this work records "
                           "as chill-poor. No contradiction."),
             ],
             source="§ 34_method_figures.R · DM_JOSE.R",
             notes="This slide exists because the commonest misreading of these maps is to treat "
                   "chill portions as a proxy for how cold a winter was. The same curve shape "
                   "means a warm Mediterranean winter loses chill faster than a linear index "
                   "would suggest, because it spends its hours on the falling side."),

        dict(kind="table", slim=True,
             title="Chill model parameters",
             head=["Setting", "Value", "Set in · 01_scripts/"],
             rows=[
                 ["Implementation", "Dynamic Model, Fishman et al. (1987), unmodified",
                  (DM_JOSE, [(4, 5)])],
                 ["Constants", "E0 4457.8 · E1 10161.9 · A0 419700 · A1 1.797e14 · slope 1.6 · "
                               "Tf 277", (DM_JOSE, [(4, 5)])],
                 ["Called as", "models = list(Chill_Portions = DM_JOSE)", (CHILL, [318])],
                 ["Season", "Julian day 305 to 59", (CHILL, [116])],
                 ["Safe Winter Chill", "10th percentile within station and window", (CHILL, [346])],
                 ["Season dropped if", "fewer than 85% of days present", (CHILL, [116, 339])],
                 ["Station dropped if", "over 40% missing, or fewer than 3 seasons",
                  (CHILL, [117, 344])],
                 ["Fill-value guard", "values outside −90 to 70 °C masked", (CHILL, [118, 271])],
             ],
             widths=[0.19, 0.55, 0.26],
             numeric=False,
             foot="Every value is read from the file named in the last column.",
             source="§ 15_chill_national_parallel.R · DM_JOSE.R",
             notes="The fill-value guard was not defensive programming. Four of the eleven models "
                   "ship −999 as a fill value while declaring NaN in the metadata, so ncdf4 reads "
                   "them as real temperatures of −999 °C."),

        dict(kind="figure_note",
             title="The 1987 and 1988 parametrisations",
             image=f"{FIG}/fig26_02_parametrisation_gap.png",
             note_frac=0.29,
             notes_side=[
                 dict(head="Compared how",
                      body=f"Both run over the same {N['param_gap_n_seasons']:.0f} seasons at "
                           f"Cieza, everything else identical."),
                 dict(head="The size",
                      body=f"chillR's 1988 default returns "
                           f"{abs(N['param_gap_mean_CP']):.2f} CP less on average, ranging "
                           f"{abs(N['param_gap_max_CP']):.2f} to "
                           f"{abs(N['param_gap_min_CP']):.2f}."),
                 dict(head="What is at stake",
                      body=f"Half the {N['rank_cultivar_gap_CP']:.1f} CP signal being measured. "
                           f"Supply and demand have to share a scale."),
             ],
             source="§ 27_cieza_independent_check.R · cieza_numbers.csv",
             notes="A constant offset would not fix it: the gap widens in the mildest winters, "
                   "which are precisely the ones that decide whether a threshold is crossed.\n\n"
                   "This is why the project uses DM_JOSE rather than chillR's default. The "
                   "methods section of Ruiz et al. 2019 states that the requirements were "
                   "quantified with Fishman 1987, which is what makes the choice consistent. "
                   "Confirming that reading is the first open question at the end of this deck."),

        dict(kind="figure_note",
             title="Safe Winter Chill on one station",
             image=f"{FIG}/fig35_swc_concept.png",
             note_frac=0.27,
             notes_side=[
                 dict(head="The construction",
                      body="Each winter gives one total. Safe Winter Chill is the value nine "
                           "winters in ten exceed."),
                 dict(head="On a real station",
                      body=f"Station {N['swc_example_station']} averages "
                           f"{N['swc_example_mean']:.1f} CP but its Safe Winter Chill is "
                           f"{N['swc_example_p10']:.1f} CP."),
             ],
             source="§ 34_method_figures.R · § 15_chill_national_parallel.R:346",
             notes="Planting to the mean at that station would over-state what the site supports "
                   "by "
                   + f"{N['swc_example_mean'] - N['swc_example_p10']:.1f} CP. "
                   "The definition, the season limits and the percentile are all taken from Egea "
                   "et al. (2022), so the numbers here are comparable with that work. The "
                   "window-length point is why the archive and the API were never compared on "
                   "their aggregates: a P10 over 12 seasons is close to a minimum, while a P10 "
                   "over 26 is a genuine decile."),

        dict(kind="figure_max",
             title="The quality filters",
             image=f"{FIG}/fig51_attrition_funnel.png",
             source="§ 40_attrition_funnel.R",
             notes="One panel per unit, because stations, seasons and square kilometres cannot "
                   "share an axis: on a common scale the discarded seasons would draw a bar four "
                   "times the width of the discarded stations and say nothing. The figure carries "
                   "a guard that refuses to draw if its denominator disagrees with "
                   "talk_numbers_cropland.csv."),
    ]


def _v4_windows(N):
    return [
        dict(kind="section", n="3", title="The time windows",
             lead="Which periods are compared against which, and why the baseline stops in 2020."),

        dict(kind="timeline",
             title="The four analysis windows",
             span=(1990, 2100), ticks=[2000, 2020, 2040, 2060, 2080, 2100],
             bands=[
                 dict(head="Baseline", sub="the reference for every difference",
                      **{"from": 1995, "to": 2020},
                      label=f"{N['timeline_seasons_base']:.0f} seasons · spliced"),
                 dict(head="Near term", sub="the horizon of a planting decision",
                      **{"from": 2021, "to": 2040},
                      label=f"{N['timeline_seasons_nearterm']:.0f} seasons"),
                 dict(head="Mid century", sub="tiles the middle",
                      **{"from": 2041, "to": 2070},
                      label=f"{N['timeline_seasons_near']:.0f} seasons"),
                 dict(head="End century", sub="where the headlines come from",
                      **{"from": 2071, "to": 2100},
                      label=f"{N['timeline_seasons_far']:.0f} seasons"),
                 dict(head="Observed", sub="validates the baseline",
                      **{"from": 1995, "to": 2020}, label="PNACC archive"),
                 dict(head="Current climate", sub="shown, never a reference",
                      **{"from": 1995, "to": 2025}, label="31 seasons · overlaps the near term"),
             ],
             source="§ 15_chill_national_parallel.R:126-132 · § 22_merge_chill_tables.R:49-59",
             notes="An apricot orchard produces for 25 to 30 years, which is why 2021-2040 exists "
                   "at all: the original plan jumped straight from the historical period to "
                   "2041-2070.\n\n"
                   "The last row is the one to watch. The current-climate panel overlaps the near "
                   "term by five years, so it can be shown but must never be the reference a "
                   "future is differenced against."),

        dict(kind="cards",
             title="The baseline splice",
             items=[
                 dict(head="CMIP6 historical", stat="≤ 2014",
                      body="The experiment ends on 31 December 2014 by protocol. No amount of "
                           "downloading extends it.",
                      chip="first 20 years of the baseline"),
                 dict(head="SSP scenarios", stat="≥ 2015",
                      body="SSP2-4.5 supplies 2015-2020, once per model. By 2020 the scenarios "
                           "have barely separated.",
                      chip="saves two thirds of the compute"),
             ],
             foot="Checked on the real series: no duplicated or missing days, and a physically "
                  "continuous transition across the join.",
             source="§ 15_chill_national_parallel.R:159, :295-302",
             notes="This is the step most likely to be questioned, and it is worth being explicit "
                   "that the splice scenario is a parameter (--splice-scenario) rather than "
                   "something hard-wired. The assembled situation is labelled 'presente' "
                   "throughout the outputs."),

        dict(kind="figure_note",
             title="Why the baseline stops in 2020",
             image=f"{FIG}/fig37_baseline_today.png",
             note_frac=0.31,
             notes_side=[
                 dict(head="The temptation",
                      body="The most recent baseline looks honest: it is the climate growers "
                           "actually experience."),
                 dict(head="Why it fails",
                      body="It would share 2021-2025 with the near-term window, so a quarter of "
                           "the change would cancel by construction."),
                 dict(head="What it costs",
                      body="A baseline five years older than it could be, worth about half a "
                           "chill portion on the observed record."),
             ],
             source="§ 34_method_figures.R · § 25_splice_observed_1995_2025.R",
             notes="If a reviewer only argues with one window choice, it will be this one, and "
                   "the answer is that the alternative is not neutral. The baseline stops at 2020 "
                   "and the current-climate panel exists separately, shown but never differenced "
                   "against."),
    ]


def _v4_surface(N):
    return [
        dict(kind="section", n="4", title="From points to a surface",
             lead="Chill is computed at stations and the question is about territory. This is the "
                  "step that bridges them."),

        dict(kind="cards",
             title="Stations against cropland area",
             items=[
                 dict(head="Stations", stat=f"{N['station_rescued_min_pct']:.1f}-"
                                            f"{N['station_rescued_max_pct']:.1f}%",
                      body="Stations cluster in valleys, airports and towns: 306 of them sit on "
                           "151 coordinates.",
                      chip="not the unit used"),
                 dict(head="Cropland area", stat=f"{N['km2_rescued_min_pct']:.1f}-"
                                                 f"{N['km2_rescued_max_pct']:.1f}%",
                      body="Each 1 km cell contributes its own fraction of CORINE cropland, not a "
                           "whole cell.",
                      chip="every headline in this work"),
             ],
             foot="The same quantity, the share of the loss the mutant recovers, measured two "
                  "ways. Choosing area buys an interpolation, and therefore an error.",
             source="§ 19_cropland_viability_national.R · § 36_per_model_stats.R",
             notes="That interpolation error is measured two sections later rather than assumed "
                   "away. An earlier version of the project documentation quoted the station "
                   "range beside a claim that only holds on the area range, so keeping the two "
                   "units clearly apart is deliberate."),

        dict(kind="table", slim=True,
             title="Interpolation parameters",
             head=["Setting", "Value", "Set in · 01_scripts/"],
             rows=[
                 ["Ensemble statistic", "median across 11 models, at the station, before anything "
                                        "spatial", (VIABILITY, [66])],
                 ["Interpolation", "inverse distance weighting, terra::interpIDW",
                  (VIABILITY, [151])],
                 ["Power", "2", (VIABILITY, [44])],
                 ["Search radius", "50 km, which is also the mask", (VIABILITY, [43, 151])],
                 ["Neighbours", "at most 12 per cell", (VIABILITY, [45])],
                 ["Grid", "1 km, EPSG:3035, equal-area", (VIABILITY, [37, 40])],
                 ["Cell area", "from the realised resolution, not the nominal one",
                  (CORINE, [(43, 46)])],
                 ["Cropland mask", "CORINE 2018 classes 211-244, pasture excluded",
                  (CORINE, [(24, 28)])],
                 ["Area weighting", "each cell contributes its cropland fraction",
                  (VIABILITY, [124])],
                 ["Classification", "≥ 47.5 both · ≥ 33.7 mutant only · below, neither",
                  (VIABILITY, [(139, 141)])],
             ],
             widths=[0.19, 0.55, 0.26],
             numeric=False,
             foot=f"The method replicates Egea et al. (2022), which interpolated by IDW and masked "
                  f"to 50 km. That work had 270 stations after quality control; this one has "
                  f"{en(N['chain_stations'])}.",
             source="§ 19_cropland_viability_national.R · § 00_corine.R",
             notes="The cell-area row looks like pedantry and is not. terra honours the extent it "
                   "is given and adjusts the resolution to fit whole cells, so a nominal 1 km grid "
                   "over Spain has cells of 1000.32 by 999.99 m. Using the nominal value put every "
                   "area in this project 0.031% low until it was found."),

        dict(kind="figure_note",
             title="Where the median is taken",
             image=f"{FIG}/fig44_aggregation_chain.png",
             note_frac=0.28,
             notes_side=[
                 dict(head="What the pipeline does",
                      body="Median first, then interpolate and classify. Every published km² is a "
                           "statistic of a surface no single model produced."),
                 dict(head="Median, not mean",
                      body="The distribution across models is skewed by its harshest members. "
                           "Egea et al. (2022) used a mean."),
                 dict(head="The alternative",
                      body="Classify each model, aggregate the eleven areas at the end. Measured "
                           "later in this deck."),
             ],
             source="§ 38_method_figures.R · § 36_per_model_stats.R",
             notes="This is one of the two places where a reviewer could reasonably say the "
                   "pipeline does the wrong thing, so the deck measures it rather than defending "
                   "it. It does not apply to the agreement counter, which compares each model "
                   "against itself in the baseline, never against the ensemble."),

        dict(kind="figure_max",
             title=f"One station end to end: {N['walk_station']}",
             image=f"{FIG}/fig46_station_walkthrough.png",
             source="§ 38_method_figures.R",
             notes=f"Observed Safe Winter Chill {N['walk_p10_obs']:.1f} CP, modelled baseline "
                   f"{N['walk_med_base']:.1f} CP, and {N['walk_med_far']:.1f} CP at 2071-2100 "
                   f"under SSP3-7.0, ending in the classified land within 50 km of the station. A "
                   f"single worked example is the fastest way to check that the chain does what "
                   f"the previous slides claim."),
    ]


def _v4_checks(N):
    return [
        dict(kind="section", n="5", title="What was checked",
             lead="Four things could have made the maps wrong without anything failing. Each was "
                  "measured."),

        dict(kind="figure_note",
             title="Model against observations",
             image=f"{FIG}/fig43_model_bias.png",
             note_frac=0.29,
             notes_side=[
                 dict(head="How",
                      body=f"Identical window, 1995-2020, and the {en(N['n_bias_stations'])} "
                           f"stations both products share. Ensemble bias "
                           f"{N['bias_ensemble_CP']:.2f} CP."),
                 dict(head="Per model",
                      body=f"{N['bias_min_CP']:.2f} ({N['bias_min_model']}) to "
                           f"+{N['bias_max_CP']:.2f} CP ({N['bias_max_model']}), a span of "
                           f"{N['bias_range_CP']:.1f} CP."),
                 dict(head="The caveat",
                      body="ESD-RegBA was calibrated against these same stations, so this is not "
                           "an independent test."),
             ],
             source="§ 38_method_figures.R · method_chain_numbers.csv",
             notes="No bias correction is applied and absolute values are used rather than "
                   "differences from a baseline. The caveat is not a formality: it is the reason "
                   "the deck also carries a check against a record from outside the AEMET "
                   "network."),

        dict(kind="figure_note",
             title="Interpolation error",
             image=f"{FIG}/fig52_idw_crossval.png",
             note_frac=0.30,
             notes_side=[
                 dict(head="The test",
                      body=f"Each of {en(N['idw_n_stations_far'])} stations removed in turn and "
                           f"predicted from the others, at its own coordinate."),
                 dict(head="The size",
                      body=f"{N['idw_rmse_base_CP']:.2f} CP at the baseline, "
                           f"{N['idw_rmse_far_CP']:.2f} at 2071-2100: "
                           f"{N['idw_pct_of_gap_base']:.0f}% and "
                           f"{N['idw_pct_of_gap_far']:.0f}% of the cultivar gap."),
                 dict(head="Not a confidence interval",
                      body="Measured at stations, with a floor of 1.02 CP and an uncorrected "
                           "altitude slope of −2.94 CP per 1,000 m."),
             ],
             source="§ 41_idw_crossval.R · idw_crossval_summary.csv",
             notes="Until this was run the interpolation was justified by citing Egea et al. "
                   "(2022) and its error had never been measured. Three limits on reading it: the "
                   "network is dense enough that no station is more than 27 km from a neighbour, "
                   "so it says nothing about genuinely isolated ground; where two station codes "
                   "share a coordinate their own observations differ by 1.02 CP; and the altitude "
                   "slope is the way an IDW fails in a mountainous country."),

        dict(kind="bignum", slim=True,
             title="Land within one RMSE of a threshold",
             items=[
                 dict(value=f"{N['idw_band_pct_base']:.1f}%",
                      label="of cropland within one RMSE of a threshold at the baseline"),
                 dict(value=f"{N['idw_band_pct_far']:.1f}%",
                      label="the same at 2071-2100 under SSP3-7.0"),
                 dict(value=f"{en(N['idw_band_km2_far'])} km²",
                      label=f"that figure as area, of {en(N['total_cropland_km2'])} km²"),
             ],
             body=["The band widens through the century because the surface flattens as it warms."],
             source="§ 41_idw_crossval.R · idw_threshold_band.csv",
             notes="This is the number to quote when asked how firm the boundary between classes "
                   "is. It is a statement about where the map is fragile, not a claim that those "
                   "cells are misclassified. Reported alongside the maps rather than buried, "
                   "because a reader who sees a crisp three-colour map will otherwise assume the "
                   "boundaries are crisp too."),

        dict(kind="figure_note",
             title="An independent record: the Cieza orchard",
             image=f"{FIG}/fig26_01_independent_records.png",
             note_frac=0.30,
             notes_side=[
                 dict(head="Why it was needed",
                      body="Both halves of the observed record come from the same network."),
                 dict(head="The series",
                      body=f"CEBAS orchard at Cieza, {N['cieza_first_day']} to "
                           f"{N['cieza_last_day']}, {en(float(N['cieza_days']))} days, "
                           f"{float(N['cieza_missing_days']):.0f} missing."),
                 dict(head="What it shows",
                      body="A recent anomaly of −1.66 standard deviations against −1.95 "
                           "nationally."),
             ],
             source="§ 27_cieza_independent_check.R",
             notes="In absolute chill portions the local drop is much larger, because Murcia is a "
                   "low-chill area where the model is more sensitive, but in standard deviations "
                   "the two agree. It corroborates that the winters were warm; no published "
                   "series of accumulated chill exists to check the magnitude against.\n\n"
                   "A first attempt averaged the five AEMET stations nearest Cieza and was "
                   "discarded: only one of them has recent data, so the average changed "
                   "composition in 2021."),

        dict(kind="figure_note",
             title="Absolute chill against change from baseline",
             image=f"{FIG}/fig45_delta_vs_absolute.png",
             note_frac=0.28,
             notes_side=[
                 dict(head="Why absolute",
                      body="The question is whether a threshold is crossed, and a threshold is an "
                           "absolute quantity."),
                 dict(head="What the change says",
                      body=f"Median loss of {abs(N['delta_median_CP']):.1f} CP by 2071-2100, "
                           f"{abs(N['delta_max_CP']):.1f} to {abs(N['delta_min_CP']):.1f} across "
                           f"models."),
                 dict(head="The limit",
                      body="Differencing cancels a model's bias only for the change. The "
                           "classification never benefits from it."),
             ],
             source="§ 38_method_figures.R",
             notes="Raised by a cold-read audit of the method book, which pointed out that the "
                   "bias-cancels argument was being applied to a step it does not cover. This is "
                   "the strongest reason the bias check had to be run."),
    ]


def _v4_results(N):
    return [
        dict(kind="section", n="6", title="What came out",
             lead="The maps, the areas, and how the answer moves across the century."),

        dict(kind="map",
             title="Baseline, 1995-2020",
             image=f"{FIG}/fig20_02_viability_presente_present.png",
             crop=MAP_CROP,
             legend=[
                 dict(key="both", label="Both cultivars"),
                 dict(key="only", label="Only 'Búlida Precoz'",
                      value=f"{en(N['baseline_already_lost_km2'])} km²"),
                 dict(key="neither", label="Neither"),
             ],
             rail=[f"National median Safe Winter Chill {N['base_swc_median_CP']:.1f} CP.",
                   "Model agreement is reported separately, not on this map."],
             source="§ 19_cropland_viability_national.R",
             notes="This is the reference every later map is read against. The orange band already "
                   f"exists at the baseline, covering {en(N['baseline_already_lost_km2'])} km², "
                   "which matters when attributing the future band to warming."),

        dict(kind="map",
             title="SSP3-7.0, 2071-2100",
             image=f"{FIG}/fig20_15_viability_ssp370_far.png",
             crop=MAP_CROP,
             legend=[
                 dict(key="both", label="Both cultivars", value=f"{N['far_pct_both']:.1f}%"),
                 dict(key="only", label="Only 'Búlida Precoz'",
                      value=f"{N['far_pct_only']:.1f}%"),
                 dict(key="neither", label="Neither", value=f"{N['far_pct_none']:.1f}%"),
             ],
             rail=[f"National median Safe Winter Chill {N['far_swc_median_CP']:.1f} CP."],
             source="§ 19_cropland_viability_national.R",
             notes="The red is the part that matters agronomically: it is where the mutant stops "
                   "being an answer at all. It concentrates on the Mediterranean coast and the "
                   "southern valleys, which is where the crop actually is."),

        dict(kind="figure_max",
             title="Three scenarios, 1995 to 2100",
             image=f"{GIF}/sidebyside.gif",
             gif=True,
             source="§ 31_scenario_frames.R · § 32_make_gifs.py",
             notes="One frame per window, the same colour scale and extent throughout, so what "
                   "moves is the land and not the legend. Before 2040 the three panels are hard "
                   "to tell apart, and that is the finding rather than a defect of the animation. "
                   "The observed section quantifies it."),

        dict(kind="figure_max",
             title="Shares of cropland, fifteen situations",
             image=f"{FIG}/fig22_viability_bars.png",
             source="§ 19_cropland_viability_national.R",
             notes="Fifteen situations on one axis, from the observed baseline at the top to "
                   "SSP3-7.0 at end of century at the bottom. The shape to notice is that the "
                   "orange band grows steadily while the red one stays near zero until the severe "
                   "scenario at end of century, and then jumps. The mutant absorbs the loss until "
                   "it cannot."),

        dict(kind="bignum", slim=True,
             title="Loss already there, loss from warming",
             items=[
                 dict(value=f"{en(N['baseline_already_lost_km2'])} km²",
                      label="already beyond 'Búlida' in the 1995-2020 baseline"),
                 dict(value=f"{en(N['warming_lost_km2'])} km²",
                      label="lost to warming by 2071-2100, net of that"),
                 dict(value=f"{N['warming_rescued_pct']:.1f}%",
                      label=f"of that warming-driven loss recovered by the mutant "
                            f"({en(N['warming_rescued_km2'])} km²)"),
             ],
             body=[f"Both {N['rescued_pct_of_lost']:.1f}% and "
                   f"{N['warming_rescued_pct']:.1f}% are correct answers to different questions."],
             source="§ 19_cropland_viability_national.R · talk_key_numbers.csv",
             notes="Reporting the larger figure without this subtraction would credit the mutant "
                   "with land it already covered before any warming. A cold-read audit found this "
                   "exact figure unreconstructable in an earlier draft, because the numerator was "
                   "never published."),

        dict(kind="figure_note",
             title="When each parcel first falls below",
             image=f"{FIG}/fig30_time_of_emergence_ssp370.png",
             note_frac=0.26,
             notes_side=[
                 dict(head="What it shows",
                      body="The window in which each parcel first stops meeting the 'Búlida' "
                           "requirement, under SSP3-7.0."),
                 dict(head="Why separate it",
                      body=f"An end-of-century map says {N['toe_pct_lost_bulida']:.1f}% is lost. "
                           f"It does not say whether in 2035 or in 2095."),
                 dict(head="How to read it",
                      body="Land failing in the near term is already committed. Land failing only "
                           "at end of century is still open to cultivar choice."),
             ],
             source="§ 33_talk_figures.R",
             notes="This is the figure that turns the work from a map into advice, and it is where "
                   "a conversation with growers would start."),

        dict(kind="figure_note",
             title="Murcia",
             image=f"{FIG}/fig31_murcia_ensemble_requirements.png",
             note_frac=0.26,
             notes_side=[
                 dict(head="Why zoom",
                      body=f"Región de Murcia holds the production this work is about. Its "
                           f"{N['murcia_stations']:.0f} stations, against both requirements."),
                 dict(head="What happens",
                      body=f"By 2071-2100 the regional median is "
                           f"{N['murcia_median_far']:.1f} CP. "
                           f"{N['murcia_below_bulida_pct']:.1f}% of the stations fall below the "
                           f"'Búlida' requirement and {N['murcia_below_precoz_pct']:.1f}% below "
                           f"the mutant's."),
                 dict(head="The reading",
                      body="In the region that matters commercially, the mutant is a delay for "
                           "half the sites rather than a solution."),
             ],
             source="§ 33_talk_figures.R",
             notes="Requested in supervision on 24 August. The national figures are kinder than "
                   "the regional ones because the north of Spain carries them."),
    ]


def _v4_spread(N):
    return [
        dict(kind="section", n="7", title="What the ensemble median hides",
             lead="Every map so far is the median of eleven models. This is what that median "
                  "costs, measured four ways."),

        dict(kind="figure_max",
             title="The eleven models, ranked",
             image=f"{FIG}/fig54_model_ranking_ssp370.png",
             source="§ 43_model_ranking.R",
             notes=f"National mean Safe Winter Chill per model under SSP3-7.0. "
                   f"{N['rank_worst_model']} leaves {N['rank_worst_swc']:.1f} CP and "
                   f"{N['rank_best_model']} leaves {N['rank_best_swc']:.1f} CP, a spread of "
                   f"{N['rank_spread_far_CP']:.1f} CP against {N['rank_spread_base_CP']:.1f} CP at "
                   f"the baseline.\n\n"
                   f"Two cautions carried on the figure itself. The ordering is not stable: "
                   f"{N['rank_order_swaps_mean_vs_median']:.0f} of eleven positions move between a "
                   f"mean and a median. And {N['rank_short_window_models']} computes its "
                   f"percentile over {N['rank_short_window_seasons']:.0f} seasons rather than "
                   f"{N['rank_modal_seasons']:.0f}, while leading the next model by only "
                   f"{N['rank_best_margin_CP']:.2f} CP, so its first place is not secure."),

        dict(kind="figure_max",
             title="The eleven maps, unsummarised",
             image=f"{FIG}/fig40_small_multiples_ssp370_far.png",
             source="§ 37_model_figures.R",
             notes="Four things to look for on this sheet.\n\n"
                   "IITM-ESM, top left, is the optimistic bound: the band where only the mutant "
                   "works barely leaves the coast and almost nothing is lost outright. "
                   "UKESM1-0-LL, bottom right, is the pessimistic one: red covers the whole "
                   "southern half and the orange band has moved inland behind it. ACCESS-CM2 and "
                   "KACE-1-0-G sit beside it, and those three share an atmospheric component, so "
                   "a third of the panels are not independent draws. And the northern half stays "
                   "blue in all eleven: where the models disagree is the southern and coastal "
                   "ground, which is where the crop is.\n\n"
                   "This is the sheet to look at before accepting any single map in this deck."),

        dict(kind="figure_note",
             title="Climate sensitivity against chill left",
             image=f"{FIG}/fig55_model_sensitivity.png",
             note_frac=0.30,
             notes_side=[
                 dict(head="What is plotted",
                      body="Each model's transient climate response against the chill it leaves, "
                           "from IPCC AR6 WG1 Table 7.SM.5."),
                 dict(head="The harsh end",
                      body="UKESM1-0-LL has the highest sensitivity of the eleven and leaves the "
                           "least chill."),
                 dict(head="The mild end is not explained",
                      body="IITM-ESM leaves the most chill with a mid-table response, above four "
                           "models that leave less."),
             ],
             source="§ 46_model_sensitivity.R · IPCC AR6 WG1 Ch.7 SM Table 7.SM.5",
             notes="If the optimistic bound of this work rests on a regional feature of one model "
                   "rather than on its global sensitivity, screening the ensemble by sensitivity "
                   "would not address it. ACCESS-CM2 leaves the second least chill, though on "
                   "sensitivity it ranks third by transient response and fourth by equilibrium. "
                   "The AR6 table leaves IITM-ESM's equilibrium sensitivity blank; the value "
                   "shown comes from Zelinka et al. 2020 and is marked as such on the figure."),

        dict(kind="table", slim=True,
             title="The shared atmosphere",
             head=["Model", "Chill left, CP", "TCR °C", "ECS °C", "Atmosphere"],
             rows=[
                 ["UKESM1-0-LL", "41.1", "2.79", "5.34", "MetUM-HadGEM3-GA7.1"],
                 ["ACCESS-CM2", "46.0", "2.10", "4.72", "MetUM-HadGEM3-GA7.1"],
                 ["EC-Earth3-Veg", "51.5", "2.62", "4.31", "other"],
                 ["CMCC-CM2-SR5", "53.7", "2.09", "3.52", "other"],
                 ["KACE-1-0-G", "56.3", "2.04", "4.75", "MetUM-HadGEM3-GA7.1"],
                 ["CNRM-ESM2-1", "57.1", "1.86", "4.76", "other"],
                 ["MRI-ESM2-0", "58.2", "1.64", "3.15", "other"],
                 ["NorESM2-MM", "59.6", "1.33", "2.50", "other"],
                 ["MIROC6", "60.8", "1.55", "2.61", "other"],
                 ["MPI-ESM1-2-HR", "60.9", "1.66", "2.98", "other"],
                 ["IITM-ESM", "62.3", "1.71", "2.37 *", "other"],
             ],
             widths=[0.24, 0.16, 0.13, 0.13, 0.34],
             numeric=True,
             foot="The three declare a byte-identical atmosphere but come from different "
                  "institutions, and they hold ranks 1, 2 and 5 for harshness. "
                  "* from Zelinka et al. 2020.",
             source="AEMET Nota Técnica 41 · WCRP CMIP6 controlled vocabulary · AR6 Table 7.SM.5",
             notes="The eleven were selected by AEMET on skill, on data availability, and on one "
                   "model per institutional family, with a final check that the subset still "
                   "spanned the spread of the full ensemble. That filter operates on the "
                   "institution, so three models sharing MetUM-HadGEM3-GA7.1 pass through it as "
                   "independent draws.\n\n"
                   "This is a question for a reviewer, not a claim that the ensemble is wrong. The "
                   "measured effect on the national median is small; whether the shared atmosphere "
                   "biases the spatial pattern over Iberia has not been tested."),

        dict(kind="table", slim=True,
             title="Order of aggregation",
             head=["Class", "Median first, km²", "Classify first, km²", "Difference"],
             rows=[
                 ["Both cultivars", f"{en(N['agg_both_median_first_km2'])}",
                  f"{en(N['agg_both_classify_first_km2'])}",
                  f"{N['agg_both_shift_pct']:+.1f}%"],
                 ["Only 'Búlida Precoz'", f"{en(N['agg_only_median_first_km2'])}",
                  f"{en(N['agg_only_classify_first_km2'])}",
                  f"{N['agg_only_shift_pct']:+.1f}%"],
                 ["Neither", f"{en(N['agg_none_median_first_km2'])}",
                  f"{en(N['agg_none_classify_first_km2'])}",
                  f"{N['agg_none_shift_pct']:+.1f}%"],
                 ["Share of the loss recovered",
                  f"{N['agg_headline_median_first_pct']:.1f}%",
                  f"{N['agg_headline_classify_first_pct']:.1f}%",
                  f"{N['agg_headline_shift_points']:+.1f} points"],
             ],
             widths=[0.34, 0.22, 0.22, 0.22],
             emphasis=3,
             source="§ 45_v3_numbers.py · per_model_cropland_km2.csv",
             notes="The objection is real and general: averaging a climate before running an "
                   "impact model can destroy the signal, and plant thresholds are the textbook "
                   "case. Measured here on SSP3-7.0 at 2071-2100 it is a second-order effect. The "
                   "middle column does not sum to the national cropland, and cannot: each class "
                   "median comes from a different model.\n\n"
                   "It compares the median of eleven areas against the area of the median "
                   "surface. It does not test reporting the fraction of models placing each cell "
                   "in each class, which is a different and arguably better presentation."),

        dict(kind="cards",
             title="Three kinds of agreement",
             items=[
                 dict(head="On the class", stat=f"{N['agree_class_far']:.1f}%",
                      bar=N["agree_class_far"] / 100.0,
                      body="At least 9 of 11 models on the same side of a threshold, at 2071-2100.",
                      chip="this is what the maps show"),
                 dict(head="On the direction", stat=f"{N['agree_sign_nearterm']:.1f}%",
                      bar=N["agree_sign_nearterm"] / 100.0,
                      body=f"On the sign of the change at 2021-2040, against "
                           f"{N['agree_sign_far']:.1f}% at end of century.",
                      chip="why the near term is pooled"),
                 dict(head="On the narrow band", stat=f"{N['band_agree_far_pct']:.2f}%",
                      bar=max(0.02, N["band_agree_far_pct"] / 100.0),
                      body="That a cell falls between 33.7 and 47.5 CP, a 13.8 CP target rather "
                           "than a side.",
                      chip="a far harder target"),
             ],
             foot=f"Across all situations the band figure runs "
                  f"{N['band_agree_min_pct']:.2f}% to {N['band_agree_max_pct']:.2f}%, so it alone "
                  f"would understate what the models do support.",
             source="§ 37_model_figures.R · § 00_hatch.R",
             notes="With eleven models, agreement counted as the larger side can only take six "
                   "values: 6, 7, 8, 9, 10 or 11 out of 11. A legend promising a 50% band would "
                   "describe something the data cannot produce, which is why the hatching is "
                   "binary at the AR6 80% criterion."),

        dict(kind="figure_max",
             title="Where the models disagree on the class",
             image=f"{FIG}/fig39_model_agreement_far.png",
             source="§ 37_model_figures.R · § 00_hatch.R",
             notes="Hatched cropland is where fewer than 9 of 11 models place the cell in the same "
                   "class. It falls on the boundaries between classes, which is where it should "
                   "fall, and in the other situations agreement runs between 92.6% and 99.1%."),

        dict(kind="bignum", slim=True,
             title="The spread in area",
             items=[
                 dict(value=f"{en(N['spread_none_min_km2'])} – {en(N['spread_none_max_km2'])}",
                      label=f"km² where neither cultivar works: a factor of "
                            f"{N['spread_none_ratio']:.1f}"),
                 dict(value=f"{en(N['spread_only_min_km2'])} – {en(N['spread_only_max_km2'])}",
                      label="km² recovered by the mutant"),
                 dict(value=f"{N['km2_rescued_min_pct']:.1f} – {N['km2_rescued_max_pct']:.1f}%",
                      label=f"the share of the loss it recovers, median "
                            f"{N['km2_rescued_median_pct']:.1f}%"),
             ],
             body=["The right-hand figure is the most robust statement in this work; the "
                   "left-hand one is the least, and no single-number headline for it is honest."],
             source="§ 36_per_model_stats.R · per_model_cropland_km2.csv",
             notes="The right-hand figure rests on the gap between the cultivars rather than on "
                   "either threshold, and no model puts it below a third. The data provider's own "
                   "guidance discourages reducing an ensemble to one value, and whether the area "
                   "figures should carry a band is an open question at the end of this deck.\n\n"
                   "Putting the factor on a slide is deliberate: it is the number a reviewer "
                   "would find on their own, and finding it unannounced would undermine "
                   "everything else."),
    ]


def _v4_observed(N):
    return [
        dict(kind="section", n="8", title="The observed record",
             lead="A result that is not a projection: what the last fifty winters actually did."),

        dict(kind="figure_max",
             title="Fifty observed winters",
             image=f"{FIG}/fig25_01_observed_chill_series_1976_2025.png",
             source="§ 26_observed_long_record.R",
             notes=f"Observed Safe Winter Chill as anomalies over "
                   f"{N['obs_record_n_seasons']:.0f} seasons. The 1976-2020 baseline has no trend "
                   f"(p = 0.90); 2021-2025 sits {abs(N['obs_recent_anom_CP']):.2f} CP below it, "
                   f"{abs(N['obs_recent_sd']):.2f} standard deviations.\n\n"
                   f"Four of the five recent winters are among the ten mildest of the fifty "
                   f"(p = {N['obs_p_exchangeable']:.3f} under exchangeability), and of the "
                   f"{N['obs_n_baseline_blocks']:.0f} five-season blocks in the baseline, "
                   f"{N['obs_blocks_as_mild']:.0f} reach as low. One caveat travels with it: the "
                   f"five-year running mean has been falling since 2005, so the recent block "
                   f"sharpens a decline that had already begun."),

        dict(kind="figure_note",
             title="Model spread against scenario spread",
             image=f"{FIG}/fig38_model_vs_scenario_spread.png",
             note_frac=0.29,
             notes_side=[
                 dict(head="Measured where it matters",
                      body=f"On the {N['nearterm_marginal_stations']:.0f} stations sitting near "
                           f"the 'Búlida' threshold at 2021-2040."),
                 dict(head="The comparison",
                      body=f"Scenarios differ by {N['nearterm_spread_scenarios_CP']:.1f} CP, "
                           f"models by {N['nearterm_spread_models_CP']:.1f} CP: five times as "
                           f"much."),
                 dict(head="Not even ordered",
                      body=f"{N['nearterm_models_favouring_ssp370']:.0f} of eleven models give "
                           f"more chill under SSP3-7.0 than under SSP2-4.5."),
             ],
             source="§ 33_talk_figures.R · talk_key_numbers.csv",
             notes=f"The near term is shown as one pooled panel rather than three, because three "
                   f"panels would invite the reader to conclude that the pessimistic scenario is "
                   f"better, which the data do not support. Sign test p = "
                   f"{N['nearterm_sign_test_p']:.2f}; the chill-poorest scenario is SSP1-2.6 in "
                   f"{N['nearterm_coldest_is_ssp126']:.0f} models, SSP2-4.5 in "
                   f"{N['nearterm_coldest_is_ssp245']:.0f} and SSP3-7.0 in "
                   f"{N['nearterm_coldest_is_ssp370']:.0f}.\n\n"
                   f"The sign even depends on the order of averaging: median across models first "
                   f"gives SSP3-7.0 {N['nearterm_order_models_first_CP']:+.1f} CP against "
                   f"SSP2-4.5, and across stations first gives "
                   f"{N['nearterm_order_stations_first_CP']:+.1f}."),
    ]


def _v4_questions(N):
    return [
        dict(kind="section", n="9", title="What is still open",
             lead="Five questions whose answers would change either the numbers or how they have "
                  "to be reported, in the order of how much they would move."),

        dict(kind="cards", rows=True,
             title="Five open questions",
             items=[
                 dict(head="1. Parametrisation",
                      body="Were the two requirements quantified with Fishman 1987, or with "
                           "chillR's 1988 default? Supply uses 1987.",
                      stat="would move every area"),
                 dict(head="2. Interpolation",
                      body="Gómez-Ramos et al. (2024) found chill overestimated in warm coastal "
                           "areas, where the cultivars separate.",
                      stat="would change every map"),
                 dict(head="3. Reporting the spread",
                      body="Should the areas carry a band rather than a median, given a factor of "
                           "fifteen across models?",
                      stat="would change the framing"),
                 dict(head="4. Model subset",
                      body="Does the shared atmosphere warrant down-weighting, and why is "
                           "IITM-ESM the mild outlier?",
                      stat="would move the median"),
                 dict(head="5. Excluding SSP5-8.5",
                      body="The accepted abstract names RCP8.5. The reference justifying the "
                           "exclusion is not recorded.",
                      stat="needed for the caption"),
             ],
             source="§ 10.4 of the canonical project document",
             notes="None is a defect found after the fact. Each was raised while the pipeline was being built and left open because answering it is not the analyst's decision alone.\n\n"
                   "Question 1 has been open longest and has the largest consequence: the offset "
                   "between the two parametrisations is half the gap between the two cultivars. "
                   "If the answer is 1988, the equivalent thresholds on the 1987 scale are near "
                   "54 and 41 CP and every area figure is recomputed, which the threshold sweep "
                   "already supports.\n\n"
                   "Questions 2 and 3 change presentation rather than analysis: station-level "
                   "classification with an uncertainty mask instead of a continuous surface, and "
                   "a band instead of a median. The per-model areas are already computed."),

        dict(kind="close",
             title="Where this stands",
             points=[
                 f"'Búlida' loses {en(N['lost_km2'])} km² by 2071-2100 under SSP3-7.0, and the "
                 f"mutant recovers {N['rescued_pct_of_lost']:.1f}% of it.",

                 "That share is the firmest number here; the absolute areas are the weakest.",

                 "Comments on a single slide are more useful than a verdict on the whole.",
             ],
             foot="Code and documentation: https://github.com/DanielGP121/plinius-apricot-winter-chill",
             notes="Everything here is reproducible from the repository, and every figure quoted "
                   "is read from a table at build time rather than typed onto a slide. The method "
                   "book carries the reasoning that this deck deliberately leaves off the "
                   "slides."),
    ]
