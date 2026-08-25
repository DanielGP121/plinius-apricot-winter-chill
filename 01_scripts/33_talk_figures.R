#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------------------
# Figures built for the talk rather than for the analysis.
#
# The 59 figures the pipeline already produces are working figures: dense subtitles, several
# messages each, sized for a screen someone is leaning into. A projected slide has one message and
# about forty seconds, so these four are drawn to be read from the back of a room.
#
#   fig30  time of emergence: the window in which each cultivar stops meeting its requirement
#   fig31  the ensemble against the two requirements, over the region where 'Búlida' is grown
#   fig32  the observed record 1976-2025 as one band per winter
#   fig33  the headline as a flow: what is lost, and what the mutant buys back
#
# fig30 follows the time-of-emergence convention of Schuhen et al. (2026, NHESS 26:753): periods
# as ordered categories, white where the threshold is never crossed. Collapsing the century onto a
# single map is what makes the comparison between the two cultivars possible in one glance, which
# four side-by-side windows never quite achieve.
#
# The interpolated surfaces are cached as GeoTIFFs, because the same four IDW passes feed three of
# these figures and each one costs minutes at 1 km. The cropland criterion is NOT reimplemented
# here: it comes from 00_corine.R, shared with 19 and 31, because a divergence there would change
# every km2 without changing anything visible.
#
# Usage: Rscript 33_talk_figures.R [--res 1000] [--scenario ssp370] [--refresh]
# Requires: terra, sf, mapSpain, ggplot2, data.table, patchwork. CORINE under PLINIUS_DATA.
# ---------------------------------------------------------------------------------------

suppressWarnings(suppressMessages({
  library(terra); library(sf); library(mapSpain); library(ggplot2); library(data.table)
  library(patchwork)
}))

args   <- commandArgs(trailingOnly = TRUE)
getarg <- function(f, d) { i <- which(args == f); if (length(i)) args[i + 1] else d }
RES_M  <- as.numeric(getarg("--res", 1000))
SCEN   <- getarg("--scenario", "ssp370")
REFRESH <- "--refresh" %in% args

.f <- grep("^--file=", commandArgs(FALSE), value = TRUE)
.dir <- if (length(.f)) dirname(normalizePath(sub("^--file=", "", .f[1]))) else getwd()
source(file.path(.dir, "00_paths.R"))
source(file.path(.dir, "00_map_layout.R"))
source(file.path(.dir, "00_corine.R"))

EPSG <- 3035
CR_B <- 47.5    # 'Búlida'        (Ruiz et al. 2019, Sci. Hortic. 254:187-192, Table 2)
CR_P <- 33.7    # 'Búlida Precoz' (idem)
IDW_RADIUS <- 50000; IDW_POWER <- 2; IDW_NMAX <- 12    # Egea et al. 2022, as in scripts 19 and 31

SSP_LAB <- c(ssp126 = "SSP1-2.6", ssp245 = "SSP2-4.5", ssp370 = "SSP3-7.0")
WINDOWS <- data.table(window = c("present", "nearterm", "near", "far"),
                      period = c("1995-2020", "2021-2040", "2041-2070", "2071-2100"))

FIGS  <- FIG_DIR; dir.create(FIGS, showWarnings = FALSE, recursive = TRUE)
CACHE <- out_path("surface_cache"); dir.create(CACHE, showWarnings = FALSE, recursive = TRUE)

# A figure that goes on a slide carries no title of its own: the slide states the assertion, and
# two titles stacked read as a mistake, the more so because ggplot's renders smaller than the
# slide's. The subtitles stay, because they carry the quantities. Export self-contained figures,
# for sending on their own, with PLINIUS_FIG_TITLE=TRUE.
FIG_TITLE <- toupper(Sys.getenv("PLINIUS_FIG_TITLE", "FALSE")) %in% c("TRUE", "1", "YES")
ttl <- function(x) if (FIG_TITLE) x else NULL

# English separators for anything the audience reads: comma for thousands, full stop for decimals.
# Replaces the n_es() helper this script carried while the deck was in Spanish, which swapped the
# two and would now print "3,65 CP" inside an English slide. R's sprintf formats through the C
# locale and cannot group thousands at all, so every user-visible number goes through here as %s
# rather than through %f.
n_en <- function(x, d = 1) formatC(x, format = "f", digits = d, big.mark = ",", decimal.mark = ".")

talk_theme <- theme_minimal(base_size = 14) +
  theme(plot.title = element_text(face = "bold", size = 17),
        plot.subtitle = element_text(size = 13, colour = "grey30"),
        panel.grid.minor = element_blank(),
        legend.position = "bottom")

# § 1 — Station chill and the geography every map is drawn on.
cat("1. datos y geografia\n")
d   <- fread(out_path("chill_all_windows.csv"))
ens <- d[, .(SWC = median(safe_winter_chill_P10)),
         by = .(situation, scenario, window, station_id, lon, lat)]

ccaa  <- esp_get_ccaa(epsg = 4326)
ccaa  <- st_transform(ccaa[!grepl("Canaria", ccaa$ine.ccaa.name), ], EPSG)
spain <- st_union(ccaa)
tmpl  <- rast(ext(vect(spain)), resolution = RES_M, crs = paste0("EPSG:", EPSG))

# Display extent excludes Ceuta and Melilla, which hold no cropland at all and would otherwise
# stretch every frame 300 km south over open sea. Analysis extent is untouched (see 31).
disp   <- ccaa[!ccaa$ine.ccaa.name %in% c("Ceuta", "Melilla"), ]
DE     <- ext(vect(st_union(disp)))
PAD    <- 0.02 * (DE$xmax - DE$xmin)
XLIM   <- c(DE$xmin - PAD, DE$xmax + PAD); YLIM <- c(DE$ymin - PAD, DE$ymax + PAD)
MAP_AR <- diff(YLIM) / diff(XLIM)

cropfrac_file <- file.path(CACHE, sprintf("cropfrac_%d.tif", RES_M))
if (!REFRESH && file.exists(cropfrac_file)) {
  cropfrac <- rast(cropfrac_file)
  cat("   suelo cultivable leido de cache\n")
} else {
  clc_c <- crop(rast(plinius_clc()), ext(project(vect(spain), crs(rast(plinius_clc())))))
  cropfrac <- mask(resample(corine_crop_mask(clc_c), tmpl, method = "average"), vect(spain))
  writeRaster(cropfrac, cropfrac_file, overwrite = TRUE)
}
cell_km2 <- cell_area_km2(cropfrac)   # not (RES_M/1000)^2; see 00_corine.R
total_crop_km2 <- global(cropfrac, "sum", na.rm = TRUE)[1, 1] * cell_km2
cat(sprintf("   superficie cultivable: %.0f km2\n", total_crop_km2))

# IDW surface with a disk cache. Interpolating is the slow step and three figures below want the
# same four surfaces, so paying for them once is the difference between one minute and ten.
chill_surface <- function(sit) {
  f <- file.path(CACHE, sprintf("swc_%s_%d.tif", sit, RES_M))
  if (!REFRESH && file.exists(f)) return(rast(f))
  p  <- ens[situation == sit]
  if (!nrow(p)) stop("situacion ausente en chill_all_windows.csv: ", sit)
  pv <- project(vect(as.data.frame(p[, .(lon, lat, SWC)]), geom = c("lon", "lat"),
                     crs = "EPSG:4326"), paste0("EPSG:", EPSG))
  s <- mask(interpIDW(tmpl, pv, field = "SWC", radius = IDW_RADIUS, power = IDW_POWER,
                      maxPoints = IDW_NMAX, near = TRUE), vect(spain))
  writeRaster(s, f, overwrite = TRUE)
  s
}

# § 2 — fig30, time of emergence.
# For each cell, the first window whose interpolated chill falls below the cultivar's requirement.
# Classification happens AFTER interpolation, never before: interpolating an ordinal "first window"
# index would average categories that are not numbers and invent intermediate decades.
cat(sprintf("2. tiempo de emergencia (%s)\n", SSP_LAB[[SCEN]]))
sits <- c("presente_present", paste0(SCEN, "_", c("nearterm", "near", "far")))
surf <- lapply(sits, chill_surface)

TOE_LAB <- c("Already below\n(1995-2020)", "2021-2040", "2041-2070", "2071-2100",
             "Does not happen\nthis century")
TOE_COL <- c("#67000d", "#cb181d", "#fb6a4a", "#fcbba1", "#f0f0f0")

toe_raster <- function(cr) {
  # 5 = never; overwritten from the last window backwards so the FIRST crossing survives.
  out <- ifel(!is.na(surf[[1]]), 5L, NA)
  for (i in 4:1) out <- ifel(surf[[i]] < cr, i, out)
  mask(out, cropfrac > 0, maskvalues = c(0, NA))
}

toe_panel <- function(cr, cultivar) {
  r  <- toe_raster(cr)
  df <- as.data.frame(r, xy = TRUE, na.rm = TRUE); names(df)[3] <- "k"
  df$cat <- factor(TOE_LAB[df$k], levels = TOE_LAB)
  km2 <- sapply(1:5, function(k)
    global(mask(cropfrac, r == k, maskvalues = c(0, NA)), "sum", na.rm = TRUE)[1, 1] * cell_km2)
  km2[is.na(km2)] <- 0
  ok <- 100 * km2[5] / sum(km2)
  g <- ggplot() +
    geom_raster(data = df, aes(x, y, fill = cat)) +
    geom_sf(data = disp, fill = NA, colour = "grey55", linewidth = 0.15) +
    coord_sf(crs = EPSG, datum = NA, expand = FALSE, xlim = XLIM, ylim = YLIM) +
    scale_fill_manual(values = setNames(TOE_COL, TOE_LAB), drop = FALSE, name = NULL) +
    labs(title = sprintf("'%s' · %s CP", cultivar, n_en(cr)),
         # "never" and "at the end of the century" are not the same statement: a cell classified
         # grey never drops below the requirement in ANY window, which is the stronger claim.
         # Two lines, because on one the text runs past the panel and ggplot clips it silently.
         subtitle = sprintf("never below the requirement: %s%%\nloses it at some point: %s%%",
                            n_en(ok), n_en(100 - ok))) +
    talk_theme +
    theme(panel.grid = element_blank(), axis.text = element_blank(), axis.title = element_blank(),
          legend.position = "none")
  list(g = g, ok = ok)
}

pa <- toe_panel(CR_B, "Búlida"); pb <- toe_panel(CR_P, "Búlida Precoz")
leg <- legend_column(lapply(seq_along(TOE_LAB),
                             function(i) list(lab = gsub("
", " ", TOE_LAB[i]),
                                              fill = TOE_COL[i])),
                     size = 3.9, title = "First window below the requirement")

# The assertion in the title is computed, not written. An earlier draft claimed the mutant pushed
# the problem out of the century "in almost all of Spain", which the numbers did not support.
g30 <- map_row_with_legend(list(pa$g, pb$g), leg, LEG_IN[["hatch"]]) +
  plot_annotation(
    title = ttl(sprintf("The mutant cuts the cropland losing its chill requirement before 2100 from %s%% to %s%%",
                    n_en(100 - pa$ok, 0), n_en(100 - pb$ok, 0))),
    subtitle = sprintf("First window in which winter chill drops below the requirement · %s · median of 11 CMIP6 models",
                       SSP_LAB[[SCEN]]),
    theme = theme(plot.title = element_text(face = "bold", size = 19),
                  plot.subtitle = element_text(size = 13, colour = "grey30")))
ggsave(fig_path(sprintf("fig30_time_of_emergence_%s.png", SCEN)), g30,
       width = 13, height = slot_height(13), dpi = 190, bg = "white")
cat("   fig30 escrita\n")

# § 3 — fig31, the ensemble against the two requirements where the cultivar is actually grown.
# Nationally the median station holds ~74 CP and both requirements sit far below it, so a national
# boxplot says nothing. 'Búlida' is a Murcian cultivar, and in Murcia the lower tail is exactly
# what crosses the two lines. This is the figure that shows the mutant buying a whole window.
cat("3. ensemble frente a los requerimientos (Región de Murcia)\n")
murcia <- ccaa[ccaa$ine.ccaa.name == "Murcia, Región de", ]
# Coordinates are taken from ONE situation, not pooled across the table. chill_all_windows.csv
# merges a modelled half (3460 stations, float32 coordinates) with an observed half (3044 stations,
# full precision), so the same station carries two spellings of the same point: 3460 station_id but
# 6504 distinct (station_id, lon, lat) triples. Deduplicating on the triple therefore counts rows
# rather than stations, and reported 278 stations in Murcia where there are 154. The boxplots were
# unaffected, since membership is tested with %in%, but the number printed on the figure was not.
st_all <- unique(d[situation == "presente_present", .(station_id, lon, lat)])
stopifnot(nrow(st_all) == uniqueN(d$station_id))
pts    <- project(vect(as.data.frame(st_all), geom = c("lon", "lat"), crs = "EPSG:4326"),
                  paste0("EPSG:", EPSG))
inside <- !is.na(extract(rasterize(vect(murcia), rast(ext(vect(murcia)), resolution = 500,
                                                     crs = paste0("EPSG:", EPSG))), pts)[, 2])
mu_ids <- st_all$station_id[inside]
cat(sprintf("   %d estaciones dentro de la Región de Murcia\n", length(mu_ids)))

BOX_SITS <- c("presente_present", paste0(rep(c("ssp126", "ssp245", "ssp370"), each = 3), "_",
                                         c("nearterm", "near", "far")))
bx <- d[station_id %in% mu_ids & situation %in% BOX_SITS]
bx <- bx[, .(SWC = median(safe_winter_chill_P10)), by = .(situation, scenario, window, station_id)]
bx[, period := WINDOWS$period[match(window, WINDOWS$window)]]
bx[, grp := ifelse(situation == "presente_present", "Baseline\n1995-2020",
                   sprintf("%s\n%s", SSP_LAB[scenario], period))]
bx[, grp := factor(grp, levels = c("Baseline\n1995-2020",
                                   unlist(lapply(c("ssp126", "ssp245", "ssp370"), function(s)
                                     sprintf("%s\n%s", SSP_LAB[[s]], WINDOWS$period[2:4])))))]
bx[, fillcol := ifelse(situation == "presente_present", "grey60",
                       c(ssp126 = "#173C66", ssp245 = "#F79420", ssp370 = "#E71D25")[scenario])]

# The x axis is built numerically rather than as a factor. The two requirement lines need labels
# placed to the left of the first box, and a numeric annotation on a discrete axis makes ggplot
# treat the scale as continuous and reject the factor levels outright.
bx[, xpos := as.integer(grp)]
xlab <- levels(bx$grp)

# The two requirements are labelled on a right-hand axis rather than annotated inside the panel.
# An in-panel label has to be placed somewhere, and every position that is free in one scenario is
# covered by a box in another.
# How far the mutant actually gets in Murcia at the end of the century. Quoted on the slide, because
# "the mutant is the difference between carrying on and not" is only true for the band between the
# two requirements, and by 2071-2100 a large minority of the region is below even the lower one.
mu_far <- bx[situation == paste0(SCEN, "_far")]
MU_BELOW_P <- 100 * mean(mu_far$SWC < CR_P)
MU_BELOW_B <- 100 * mean(mu_far$SWC < CR_B)
MU_MED_FAR <- median(mu_far$SWC)
cat(sprintf("   %s a fin de siglo: mediana %.1f CP · bajo 33.7: %.0f%% · bajo 47.5: %.0f%%\n",
            SSP_LAB[[SCEN]], MU_MED_FAR, MU_BELOW_P, MU_BELOW_B))

g31 <- ggplot(bx, aes(xpos, SWC, group = xpos, fill = fillcol)) +
  geom_hline(yintercept = CR_B, colour = "#b2182b", linewidth = 0.9) +
  geom_hline(yintercept = CR_P, colour = "#2166ac", linewidth = 0.9) +
  geom_boxplot(width = 0.62, outlier.size = 0.5, outlier.alpha = 0.35) +
  scale_fill_identity() +
  scale_x_continuous(breaks = seq_along(xlab), labels = xlab,
                     expand = expansion(add = c(0.6, 0.6))) +
  scale_y_continuous(sec.axis = sec_axis(~ ., breaks = c(CR_P, CR_B),
                                         labels = c(sprintf("'Búlida Precoz'\nneeds %s CP", n_en(CR_P)),
                                                    sprintf("'Búlida'\nneeds %s CP", n_en(CR_B))))) +
  labs(title = ttl("In Murcia, where it is grown, the mutant is the difference between carrying on and not"),
       subtitle = sprintf("Safe Winter Chill at the %d stations in the Region · each box summarises the per-station median of the 11 models",
                          length(mu_ids)),
       x = NULL, y = "Chill portions (P10)") +
  talk_theme +
  theme(legend.position = "none", axis.text.x = element_text(size = 10.5),
        axis.text.y.right = element_text(size = 11, face = "bold", lineheight = 0.95,
                                         colour = c("#2166ac", "#b2182b")),
        axis.title.y.right = element_blank())
ggsave(fig_path("fig31_murcia_ensemble_requirements.png"), g31, width = 14, height = 7,
       dpi = 190, bg = "white")
cat("   fig31 escrita\n")

# § 4 — fig32, the observed record as one band per winter.
# Fifty winters of national mean chill, drawn as bands rather than as a line because the message is
# not a trend (there is none) but a block: the last five winters are the coldest-deficient of the
# record. A line invites the eye to look for a slope that the data do not support.
cat("4. registro observado 1976-2025\n")
obs <- fread(out_path("observed_annual_series.csv"))

# The anomaly and its size in standard deviations are NOT recomputed here. They are read from the
# summary written by 26_observed_long_record.R, which measures both against the 1976-2020 baseline
# and uses the per-station anomaly composition. Recomputing them over the whole record instead
# folds the recent block into its own reference and shrinks the anomaly from -3.65 to -3.29 CP, a
# discrepancy that would then sit on a slide next to the correct figure in the wiki.
lr    <- fread(out_path("observed_long_record_summary.csv"))
lrval <- function(b, m) lr[block == b & metric == m]$value
mu    <- lrval("baseline", "mean_CP")        # 1976-2020
sdv   <- lrval("baseline", "sd_CP")
anom  <- lrval("recent", "anomaly_CP")
anom_sd <- lrval("recent", "anomaly_sd")
n_mild  <- lrval("ranking", "n_recent_in_10_mildest")
p_exch  <- lrval("ranking", "p_exchangeable")
obs[, anom := mean_CP - mu]
g32 <- ggplot(obs, aes(season_end_year, 1, fill = anom)) +
  geom_tile(width = 1, height = 1) +
  scale_fill_gradient2(low = "#b2182b", mid = "#f7f7f7", high = "#2166ac", midpoint = 0,
                       name = "Chill anomaly (CP)") +
  annotate("segment", x = 2020.5, xend = 2020.5, y = 0.5, yend = 1.72, linewidth = 0.6) +
  annotate("text", x = 2020.3, y = 1.62, label = "2021-2025", hjust = 1, size = 4.6,
           fontface = "bold") +
  scale_x_continuous(breaks = seq(1980, 2025, 10), expand = c(0, 0)) +
  coord_cartesian(ylim = c(0.5, 1.8), expand = FALSE) +
  # 45 winters, not fifty: the trendless stretch is 1976-2020 (p = 0.90). Over the full 1976-2025
  # record the trend IS significant (p = 0.047), precisely because of the recent block.
  labs(title = ttl("Forty-five winters with no trend, and then an unprecedented five-year block"),
       subtitle = sprintf("Mean of %d AEMET stations · anomaly against the 1976-2020 baseline\nThe 2021-2025 five-year block loses %s CP (%s σ) and supplies %d of the 10 mildest winters on record (p = %s)",
                          max(obs$n_stations), n_en(abs(anom), 2), n_en(abs(anom_sd), 2),
                          round(n_mild), n_en(p_exch, 4)),
       x = NULL, y = NULL) +
  talk_theme +
  theme(axis.text.y = element_blank(), panel.grid = element_blank(),
        legend.key.width = unit(2.4, "cm"))
ggsave(fig_path("fig32_observed_stripes.png"), g32, width = 13.5, height = 4.6, dpi = 190,
       bg = "white")
cat("   fig32 escrita\n")

# § 5 — fig33, the headline as a flow.
# Three quantities and the relation between them: what Spain has, what 'Búlida' loses by the end of
# the century, and how much of that loss the mutant takes back. A bar chart of percentages hides
# the fact that the second number is a subset of the first.
cat("5. titular\n")
tn  <- fread(out_path("talk_numbers_cropland.csv"))
far <- tn[situation == paste0(SCEN, "_far")]
tot <- far$crop_km2_both + far$crop_km2_only_precoz + far$crop_km2_none
lost     <- far$crop_km2_only_precoz + far$crop_km2_none
rescued  <- far$crop_km2_only_precoz
gone     <- far$crop_km2_none

# The same three quantities net of the baseline. `lost` is an END STATE, not a change: part of it is
# land where 'Búlida' already fell short in 1995-2020, so calling all 45.089 km2 "what warming takes
# away" overstates it. The warming-driven figures are the differences against the model baseline,
# and they are what any sentence containing the word "quita" has to use.
base <- tn[situation == "presente_present"]
base_lost    <- base$crop_km2_only_precoz + base$crop_km2_none
warm_lost    <- lost - base_lost
warm_rescued <- rescued - base$crop_km2_only_precoz
cat(sprintf("   pérdida total %.0f km2, de los cuales %.0f ya lo eran en la línea base\n",
            lost, base_lost))
cat(sprintf("   atribuible al calentamiento: %.0f km2, rescatados %.0f (%.1f%%)\n",
            warm_lost, warm_rescued, 100 * warm_rescued / warm_lost))

# Drawn as a bar with a zoom rather than as four columns side by side. The affected land is a fifth
# of the total, so on a shared axis the three quantities that carry the message become three short
# stubs next to one tall bar, and the comparison the talk is about becomes the hardest thing on the
# slide to read. The lower bar rescales the affected fraction to full width, and the connector says
# that is what is happening.
km <- function(x) formatC(round(x), format = "d", big.mark = ",")
kept <- far$crop_km2_both

top <- data.table(xmin = c(0, kept), xmax = c(kept, tot), ymin = 2.45, ymax = 3.25,
                  col = c("#bdbdbd", "#d7191c"))
bot <- data.table(xmin = c(0, tot * rescued / lost), xmax = c(tot * rescued / lost, tot),
                  ymin = 0.55, ymax = 1.35, col = c("#fdae61", "#7f0000"))
link <- data.table(x = c(kept, tot, tot, 0), y = c(2.45, 2.45, 1.35, 1.35))

g33 <- ggplot() +
  geom_rect(data = top, aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax, fill = col)) +
  geom_polygon(data = link, aes(x, y), fill = "#d7191c", alpha = 0.16) +
  geom_rect(data = bot, aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax, fill = col)) +
  scale_fill_identity() +
  annotate("text", x = kept / 2, y = 2.85, label = sprintf("'Búlida' still viable\n%s km²", km(kept)),
           size = 5, colour = "grey15", fontface = "bold", lineheight = 0.95) +
  annotate("text", x = (kept + tot) / 2, y = 3.52, size = 5, colour = "#d7191c", fontface = "bold",
           label = sprintf("no longer viable\n%s km²  (%s%%)", km(lost), n_en(100 * lost / tot)),
           lineheight = 0.95) +
  annotate("text", x = tot * rescued / lost / 2, y = 0.95, size = 5.4, colour = "grey15",
           fontface = "bold", lineheight = 0.95,
           label = sprintf("the mutant rescues it\n%s km²  (%s%%)", km(rescued),
                           n_en(100 * rescued / lost))) +
  annotate("text", x = tot * (1 + rescued / lost) / 2, y = 0.95, size = 5.4, colour = "white",
           fontface = "bold", lineheight = 0.95,
           label = sprintf("lost outright\n%s km²  (%s%%)", km(gone), n_en(100 * gone / lost))) +
  annotate("text", x = 0, y = 3.95, hjust = 0, size = 4.6, colour = "grey35",
           label = sprintf("Spain's cropland: %s km² (CORINE 211-244, pastures excluded)", km(tot))) +
  annotate("text", x = 0, y = 1.72, hjust = 0, size = 4.3, colour = "grey35",
           label = "The red band, magnified") +
  coord_cartesian(xlim = c(0, tot), ylim = c(0.3, 4.2), expand = FALSE) +
  labs(title = ttl("The mutant buys back half of what warming takes away from 'Búlida'"),
       subtitle = sprintf("%s at the end of the century (2071-2100) · median of 11 CMIP6 models", SSP_LAB[[SCEN]]),
       x = NULL, y = NULL) +
  talk_theme +
  theme(legend.position = "none", panel.grid = element_blank(),
        axis.text = element_blank(), axis.ticks = element_blank())
ggsave(fig_path("fig33_headline_flow.png"), g33, width = 13, height = 6.2, dpi = 190, bg = "white")
cat("   fig33 escrita\n")

# § 6 — Why the three scenarios are not comparable at 2021-2040.
# The side-by-side frame shows SSP3-7.0 losing LESS cropland than SSP2-4.5, which reads as a result
# and is not one. Quantified here so the answer is traceable rather than asserted:
#
#   - nationally the paired difference between scenarios is nil, but the disagreement is
#     concentrated in the stations sitting near the 47.5 CP threshold, which is where a small shift
#     converts into a large area;
#   - across the 11 models the sign of that difference is a coin flip;
#   - and the sign of the ensemble result depends on the ORDER of aggregation, which is the
#     signature of no signal at all. Taking the median across models first (what the pipeline does,
#     and what any ensemble-median map does) gives one sign; taking it across stations first gives
#     the other. A quantity whose sign is decided by the order of two medians is not measuring
#     anything.
cat("6. dispersion escenario frente a modelo en 2021-2040\n")
nt  <- d[window == "nearterm"]
ens_nt <- dcast(nt[, .(SWC = median(safe_winter_chill_P10)), by = .(scenario, station_id)],
                station_id ~ scenario, value.var = "SWC")
# "Marginal" means the station could fall either side of the 'Búlida' requirement: those are the
# only ones whose scenario differences can move any area at all.
marg <- ens_nt[pmin(ssp126, ssp245, ssp370) < CR_B + 7.5 &
               pmax(ssp126, ssp245, ssp370) > CR_B - 7.5, station_id]
sub  <- nt[station_id %in% marg]

A <- dcast(sub[, .(SWC = median(safe_winter_chill_P10)), by = .(scenario, station_id)],
           station_id ~ scenario, value.var = "SWC")               # models first, then stations
B <- dcast(sub[, .(SWC = median(safe_winter_chill_P10)), by = .(scenario, model)],
           model ~ scenario, value.var = "SWC")                    # stations first, then models
ord_A <- median(A$ssp370 - A$ssp245)
ord_B <- median(B$ssp370 - B$ssp245)
n_pos <- sum(B$ssp370 > B$ssp245)
sign_p <- binom.test(n_pos, nrow(B), 0.5)$p.value
spread_mod <- median(sub[, .(r = diff(range(safe_winter_chill_P10))), by = .(station_id, scenario)]$r)
spread_scen <- median(A[, pmax(ssp126, ssp245, ssp370) - pmin(ssp126, ssp245, ssp370)])

cat(sprintf("   %d estaciones marginales · escenarios %.1f CP frente a modelos %.1f CP\n",
            length(marg), spread_scen, spread_mod))
cat(sprintf("   modelos con mas frio en SSP3-7.0: %d de %d (prueba de signo p = %.2f)\n",
            n_pos, nrow(B), sign_p))
cat(sprintf("   orden de agregacion: modelos primero %+.2f CP, estaciones primero %+.2f CP%s\n",
            ord_A, ord_B, if (sign(ord_A) != sign(ord_B)) "  <- SIGNOS OPUESTOS" else ""))

# fig38 — the same thing as a picture, because the argument is much easier to see than to say.
# One row per model, three points per row (the three scenarios), over the stations whose chill sits
# near the requirement.
#
# What the picture shows turned out to be stronger than the summary statistics suggested. It is not
# that the three scenarios sit on top of one another inside each model: they are 2 to 6 CP apart.
# It is that their ORDER changes from model to model. Whichever scenario comes out coldest is
# essentially a property of the model, not of the emissions. That is why the ensemble median can
# rank them in a way no individual model supports, and it is the cleanest possible demonstration
# that there is no scenario signal to read at this horizon.
coldest <- B[, .(coldest = c("ssp126", "ssp245", "ssp370")[which.min(c(ssp126, ssp245, ssp370))]),
             by = model][, .N, by = coldest][order(-N)]
cat("   escenario mas pobre en frio, modelo a modelo: ",
    paste(sprintf("%s en %d", SSP_LAB[coldest$coldest], coldest$N), collapse = " · "), "\n", sep = "")
within_model <- median(B[, pmax(ssp126, ssp245, ssp370) - pmin(ssp126, ssp245, ssp370)])
cat(sprintf("   rango entre escenarios DENTRO de un mismo modelo: %.1f CP (mediana)\n", within_model))

ord_models <- B[order(ssp245)]$model
Bl <- melt(B, id.vars = "model", variable.name = "scenario", value.name = "SWC")
Bl[, model := factor(model, levels = ord_models)]
SSP_COL <- c(ssp126 = "#173C66", ssp245 = "#F79420", ssp370 = "#E71D25")

g38 <- ggplot(Bl, aes(SWC, model)) +
  geom_vline(xintercept = CR_B, colour = "#b2182b", linewidth = 0.9) +
  geom_line(aes(group = model), colour = "grey78", linewidth = 0.9) +
  geom_point(aes(colour = scenario), size = 3.6) +
  scale_colour_manual(values = SSP_COL, labels = SSP_LAB, name = NULL) +
  scale_x_continuous(breaks = seq(42, 58, 2),
                     sec.axis = dup_axis(breaks = CR_B, labels = "requirement\nof 'Búlida'")) +
  labs(title = ttl("Which scenario comes out poorest in chill depends on the model, not on the emissions"),
       subtitle = sprintf(paste0("Median of the %d stations near the threshold, 2021-2040 · ",
                                 "each grey line joins the three scenarios within one model\n",
                                 "The poorest scenario is SSP1-2.6 in %d models, SSP2-4.5 in %d ",
                                 "and SSP3-7.0 in %d: there is no stable ordering"),
                          length(marg),
                          coldest[coldest == "ssp126", N][1], coldest[coldest == "ssp245", N][1],
                          coldest[coldest == "ssp370", N][1]),
       x = "Chill portions (P10)", y = NULL) +
  talk_theme +
  theme(legend.position = "top",
        axis.text.x.top = element_text(size = 10.5, face = "bold", colour = "#b2182b",
                                       lineheight = 0.9),
        axis.title.x.top = element_blank())
ggsave(fig_path("fig38_model_vs_scenario_spread.png"), g38, width = 12.5, height = 6.6, dpi = 190,
       bg = "white")
cat("   fig38 escrita\n")

# Numbers quoted on the slides, written out so the deck builder never retypes one.
fwrite(data.table(
  metric = c("total_cropland_km2", "lost_km2", "rescued_km2", "gone_km2", "rescued_pct_of_lost",
             "murcia_stations", "toe_pct_lost_bulida", "toe_pct_lost_precoz",
             "obs_baseline_mean_CP", "obs_baseline_sd_CP", "obs_recent_anom_CP", "obs_recent_sd",
             "obs_recent_in_10_mildest", "obs_p_exchangeable",
             "murcia_median_far", "murcia_below_precoz_pct", "murcia_below_bulida_pct",
             "baseline_already_lost_km2", "warming_lost_km2", "warming_rescued_pct",
             "warming_rescued_km2",
             "obs_baseline_first_year", "obs_baseline_n_seasons", "obs_blocks_as_mild",
             "obs_n_baseline_blocks", "obs_record_n_seasons", "obs_record_last_year",
             "nearterm_marginal_stations", "nearterm_spread_scenarios_CP",
             "nearterm_spread_models_CP", "nearterm_models_favouring_ssp370",
             "nearterm_sign_test_p", "nearterm_order_models_first_CP",
             "nearterm_order_stations_first_CP", "nearterm_within_model_range_CP",
             "nearterm_coldest_is_ssp126", "nearterm_coldest_is_ssp245",
             "nearterm_coldest_is_ssp370"),
  value  = c(tot, lost, rescued, gone, 100 * rescued / lost, length(mu_ids),
             100 - pa$ok, 100 - pb$ok, mu, sdv, anom, anom_sd, n_mild, p_exch,
             MU_MED_FAR, MU_BELOW_P, MU_BELOW_B,
             base_lost, warm_lost, 100 * warm_rescued / warm_lost,
             # The numerator of that percentage. Without it a reader divides the headline rescue by
             # the warming-attributable loss and gets a different number, because the rescue also
             # has to be discounted for what was already rescued at baseline.
             warm_rescued,
             lrval("baseline", "first_year"), lrval("baseline", "n_seasons"),
             lrval("blocks", "n_as_mild"), lrval("blocks", "n_baseline_blocks"),
             # Length of the WHOLE record, which is not the length of the baseline: the baseline
             # stops in 2020 and the record runs to 2025.
             nrow(obs), max(obs$season_end_year),
             length(marg), spread_scen, spread_mod, n_pos, sign_p, ord_A, ord_B, within_model,
             coldest[coldest == "ssp126", N][1], coldest[coldest == "ssp245", N][1],
             coldest[coldest == "ssp370", N][1]),
  scenario = SCEN), out_path("talk_key_numbers.csv"))

cat(sprintf("\nescritas 4 figuras en %s\ny talk_key_numbers.csv\n", FIGS))
