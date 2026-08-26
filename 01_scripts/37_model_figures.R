#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------------------
# The model spread, drawn four ways.
#
# The rest of the project shows the ensemble median and mentions the spread in a caveat. These
# figures make the spread the subject, because it is the honest answer to "how much of this do you
# believe" and because two of the project's own claims turned out to depend on which spread was
# being talked about.
#
#   fig39  viability with AR6 diagonal hatching where fewer than 80 % of models agree
#   fig40  the eleven models as small multiples, unsummarised
#   fig41  the rescued fraction model by model, which is the table behind the quoted range
#   fig42  agreement on the SIGN of change, near term against end of century
#
# fig42 carries the finding that reorganised the argument. Agreement on the CLASSIFICATION (is this
# cell below 47.5 CP) is high everywhere, 83 to 99 %. Agreement on the SIGN OF CHANGE is 30 to 41 %
# at 2021-2040 and 83 to 88 % by 2071-2100. Those are different questions, and the project had been
# quoting one as if it settled the other.
#
# Usage: Rscript 37_model_figures.R [--res 1000] [--scenario ssp370]
# Requires: terra, sf, mapSpain, ggplot2, data.table, patchwork. Run 36_per_model_stats.R first.
# ---------------------------------------------------------------------------------------

suppressWarnings(suppressMessages({
  library(terra); library(sf); library(mapSpain); library(ggplot2); library(data.table)
  library(patchwork)
}))

args   <- commandArgs(trailingOnly = TRUE)
getarg <- function(f, d) { i <- which(args == f); if (length(i)) args[i + 1] else d }
RES_M  <- as.numeric(getarg("--res", 1000))
SCEN   <- getarg("--scenario", "ssp370")

.f <- grep("^--file=", commandArgs(FALSE), value = TRUE)
.dir <- if (length(.f)) dirname(normalizePath(sub("^--file=", "", .f[1]))) else getwd()
source(file.path(.dir, "00_paths.R"))
source(file.path(.dir, "00_corine.R"))   # cell_area_km2()
source(file.path(.dir, "00_hatch.R"))
source(file.path(.dir, "00_map_layout.R"))

EPSG <- 3035; CR_B <- 47.5; CR_P <- 33.7
IDW_RADIUS <- 50000; IDW_POWER <- 2; IDW_NMAX <- 12
AGREE_FRAC <- 0.8
LAB <- c("Both cultivars", "Only 'Búlida Precoz'", "Neither")
COL <- c("#2c7bb6", "#fdae61", "#d7191c")
SSP_LAB <- c(ssp126 = "SSP1-2.6", ssp245 = "SSP2-4.5", ssp370 = "SSP3-7.0")
SSP_COL <- c(ssp126 = "#173C66", ssp245 = "#F79420", ssp370 = "#E71D25")
AGREE_DIR <- out_path("model_agreement")
CACHE <- out_path("surface_cache")

FIG_TITLE <- toupper(Sys.getenv("PLINIUS_FIG_TITLE", "FALSE")) %in% c("TRUE", "1", "YES")
ttl <- function(x) if (FIG_TITLE) x else NULL
n_en <- function(x, d = 1) formatC(x, format = "f", digits = d, big.mark = ",", decimal.mark = ".")

talk_theme <- theme_minimal(base_size = 14) +
  theme(plot.title = element_text(face = "bold", size = 17),
        plot.subtitle = element_text(size = 12.5, colour = "grey30"),
        panel.grid.minor = element_blank(), legend.position = "bottom")
map_theme <- function(base = 13) theme_minimal(base_size = base) +
  theme(panel.grid = element_blank(), axis.text = element_blank(), axis.title = element_blank(),
        axis.ticks = element_blank(), plot.title = element_text(face = "bold"),
        plot.subtitle = element_text(colour = "grey35"))

# § 1 — Geography, shared with every other map in the project.
cat("1. geography\n")
ccaa  <- esp_get_ccaa(epsg = 4326)
ccaa  <- st_transform(ccaa[!grepl("Canaria", ccaa$ine.ccaa.name), ], EPSG)
spain <- st_union(ccaa)
disp  <- ccaa[!ccaa$ine.ccaa.name %in% c("Ceuta", "Melilla"), ]
DE    <- ext(vect(st_union(disp))); PAD <- 0.02 * (DE$xmax - DE$xmin)
XLIM  <- c(DE$xmin - PAD, DE$xmax + PAD); YLIM <- c(DE$ymin - PAD, DE$ymax + PAD)
MAP_AR <- diff(YLIM) / diff(XLIM)
tmpl  <- rast(ext(vect(spain)), resolution = RES_M, crs = paste0("EPSG:", EPSG))
cropfrac <- rast(file.path(CACHE, sprintf("cropfrac_%d.tif", RES_M)))

d <- fread(out_path("chill_all_windows.csv"))[model != "obs"]
models <- sort(unique(d$model))
PM <- fread(out_path("per_model_cropland_km2.csv"))
AG <- fread(out_path("model_agreement_summary.csv"))

ens_surface <- function(sit) {
  f <- file.path(CACHE, sprintf("swc_%s_%d.tif", sit, RES_M))
  if (file.exists(f)) return(rast(f))
  p <- d[situation == sit, .(SWC = median(safe_winter_chill_P10)), by = .(station_id, lon, lat)]
  pv <- project(vect(as.data.frame(p[, .(lon, lat, SWC)]), geom = c("lon", "lat"),
                     crs = "EPSG:4326"), paste0("EPSG:", EPSG))
  s <- mask(interpIDW(tmpl, pv, field = "SWC", radius = IDW_RADIUS, power = IDW_POWER,
                      maxPoints = IDW_NMAX, near = TRUE), vect(spain))
  writeRaster(s, f, overwrite = TRUE); s
}
classify <- function(s) mask(ifel(s >= CR_B, 1L, ifel(s >= CR_P, 2L, 3L)),
                             cropfrac > 0, maskvalues = c(0, NA))
as_df <- function(r, nm = "cls") { z <- as.data.frame(r, xy = TRUE, na.rm = TRUE); names(z)[3] <- nm; z }

# Draws a short sample of the real hatch texture, so the legend is matched by eye against the map
# instead of reconstructed from a description.
HATCH_GAP_LEG <- c(robust = 0.075, weak = 0.038)
hatch_swatch <- function(x0, gap, col, cross) {
  xs <- seq(x0, x0 + 0.25, by = gap)
  a <- data.table(x = xs, xend = xs + 0.09, y = 0.955, yend = 1.045)
  out <- list(geom_segment(data = a, aes(x, y, xend = xend, yend = yend), colour = col,
                           linewidth = 0.5))
  if (cross) out <- c(out, list(geom_segment(data = a, aes(x = xend, y = y, xend = x, yend = yend),
                                             colour = col, linewidth = 0.5)))
  out
}

base_map <- function() list(
  geom_sf(data = disp, fill = NA, colour = "grey55", linewidth = 0.14),
  coord_sf(crs = EPSG, datum = NA, expand = FALSE, xlim = XLIM, ylim = YLIM))

# § 2 — fig39, the result with its own uncertainty drawn on top.
# Colour is the ensemble median, exactly as in the headline maps. Diagonal lines mark the cropland
# where fewer than 80 % of the models place the cell on the same side of the requirement, so the
# viewer can see at once which parts of the pattern the ensemble actually supports.
cat("2. fig39 AR6 agreement map\n")
agree_panel <- function(sit, title) {
  ag  <- rast(file.path(AGREE_DIR, sprintf("%s_%d.tif", sit, RES_M)))
  cls <- classify(ens_surface(sit))
  df  <- as_df(cls); df$clase <- factor(LAB[df$cls], levels = LAB)
  pct <- AG[situation == sit]$pct_class_agree
  g <- ggplot() +
    geom_raster(data = df, aes(x, y, fill = clase)) +
    geom_agreement(agreement_bands(ag[["n_below_bulida"]], length(models), restrict = cropfrac)) +
    base_map() +
    scale_fill_manual(values = setNames(COL, LAB), drop = FALSE, name = NULL) +
    labs(title = title,
         subtitle = sprintf("the models agree over %s%% of the cropland", n_en(pct))) +
    map_theme() + theme(legend.position = "none")
  g
}
p39 <- lapply(c("ssp126_far", "ssp245_far", "ssp370_far"),
              function(s) agree_panel(s, sprintf("%s · 2071-2100", SSP_LAB[[sub("_far", "", s)]])))
# The same key as before, stacked into a column so it can sit beside the maps instead of under
# them. Built from LAB/COL and hatch_legend_items(), so it cannot drift from what the maps draw.
leg_side <- local({
  items <- lapply(seq_along(LAB), function(i) list(lab = LAB[i], fill = COL[i]))
  for (it in hatch_legend_items())
    items <- c(items, list(list(lab = it$lab, hatch = list(gap = it$gap, col = it$col,
                                                          cross = it$cross))))
  legend_column(items, size = 4.1)
})

g39 <- map_row_with_legend(p39, leg_side, LEG_IN[["hatch"]]) +
  plot_annotation(title = ttl("Where the ensemble supports the map, and where it does not"),
                  theme = theme(plot.title = element_text(face = "bold", size = 18)))
ggsave(fig_path("fig39_model_agreement_far.png"), g39, width = 15,
       height = slot_height(15), dpi = 190, bg = "white")

# § 3 — fig40, the eleven models without any summarising at all, one sheet per situation.
# The point of a small-multiple panel is that it cannot lie by aggregation: whatever the ensemble
# median does to these eleven maps, here they are. Built for the baseline as well as for the three
# scenarios, because the baseline sheet is what lets an audience check that the models reproduce
# the observed map before being asked to believe their futures.
cat("3. fig40 small multiples\n")
per_model_sheet <- function(sit, label) {
  mm <- rbindlist(lapply(models, function(m) {
    p  <- d[situation == sit & model == m, .(lon, lat, SWC = safe_winter_chill_P10)]
    pv <- project(vect(as.data.frame(p), geom = c("lon", "lat"), crs = "EPSG:4326"),
                  paste0("EPSG:", EPSG))
    s  <- mask(interpIDW(tmpl, pv, field = "SWC", radius = IDW_RADIUS, power = IDW_POWER,
                         maxPoints = IDW_NMAX, near = TRUE), vect(spain))
    z <- as_df(classify(s)); z$model <- m; z
  }))
  mm[, clase := factor(LAB[cls], levels = LAB)]
  # Ordered by how much the mutant rescues, so the sheet reads from the mildest model to the
  # harshest instead of alphabetically, which would be an arbitrary order over a real gradient.
  ordm <- PM[situation == sit][order(-pct_rescued_of_lost)]$model
  if (!length(ordm)) ordm <- models
  mm[, model := factor(model, levels = ordm)]
  g <- ggplot(mm) +
    geom_raster(aes(x, y, fill = clase)) +
    geom_sf(data = disp, fill = NA, colour = "grey65", linewidth = 0.1) +
    coord_sf(crs = EPSG, datum = NA, expand = FALSE, xlim = XLIM, ylim = YLIM) +
    # Six columns rather than four. Eleven maps in four columns make a nearly square sheet, and a
    # square sheet dropped into a 16:9 slide is scaled down until each map is smaller than the same
    # eleven laid out wide. Two rows of six fill the slide and each panel ends up larger.
    facet_wrap(~ model, ncol = 6) +
    scale_fill_manual(values = setNames(COL, LAB), drop = FALSE, name = NULL) +
    labs(title = ttl("The eleven models, unsummarised"), subtitle = label) +
    map_theme(11) +
    # The legend stays under this one. A side column only pays off when the figure is taller than
    # the slide slot; this sheet is already 2.3 wide per unit tall against the slot's 2.6, so
    # moving the key sideways would take width away from eleven maps to save height there is no
    # shortage of.
    theme(legend.position = "bottom", legend.text = element_text(size = 11),
          strip.text = element_text(face = "bold", size = 9.5))
  ggsave(fig_path(sprintf("fig40_small_multiples_%s.png", sit)), g, width = 15,
         height = slot_height(15), dpi = 190, bg = "white")
  cat(sprintf("   %s\n", sit))
}
SHEETS <- c(presente_present = "Baseline 1995-2020 · the starting point every future comes from",
            ssp126_far = "SSP1-2.6 · 2071-2100 · ordered from the largest to the smallest fraction of cropland the mutant still covers",
            ssp245_far = "SSP2-4.5 · 2071-2100 · ordered from the largest to the smallest fraction of cropland the mutant still covers",
            ssp370_far = "SSP3-7.0 · 2071-2100 · ordered from the largest to the smallest fraction of cropland the mutant still covers")
for (s in names(SHEETS)) per_model_sheet(s, SHEETS[[s]])

# § 3b — the observed map, which is the only one of these that is measured rather than simulated.
# It opens the results section: before any model is shown, this is what the instruments say.
cat("4. observed map\n")
# `d` is filtered to the model runs, so the observed situation has to be read separately: its only
# "model" is the label obs, which that filter removes.
obs_pts <- fread(out_path("chill_all_windows.csv"))[situation == "observaciones_present",
                                                    .(station_id, lon, lat, SWC = safe_winter_chill_P10)]
n_obs_st <- uniqueN(obs_pts$station_id)
obs_surf <- mask(interpIDW(tmpl, project(vect(as.data.frame(obs_pts[, .(lon, lat, SWC)]),
                                              geom = c("lon", "lat"), crs = "EPSG:4326"),
                                         paste0("EPSG:", EPSG)),
                           field = "SWC", radius = IDW_RADIUS, power = IDW_POWER,
                           maxPoints = IDW_NMAX, near = TRUE), vect(spain))
odf <- as_df(classify(obs_surf)); odf$clase <- factor(LAB[odf$cls], levels = LAB)
okm <- sapply(1:3, function(k)
  global(mask(cropfrac, classify(obs_surf) == k, maskvalues = c(0, NA)), "sum", na.rm = TRUE)[1, 1] *
    cell_area_km2(cropfrac))
okm[is.na(okm)] <- 0
g_obs <- ggplot() +
  geom_raster(data = odf, aes(x, y, fill = clase)) +
  geom_sf(data = disp, fill = NA, colour = "grey55", linewidth = 0.15) +
  coord_sf(crs = EPSG, datum = NA, expand = FALSE, xlim = XLIM, ylim = YLIM) +
  scale_fill_manual(values = setNames(COL, LAB), drop = FALSE, name = NULL) +
  labs(title = ttl("What the thermometers say, before any model"),
       subtitle = sprintf("Observed 1995-2020, %s AEMET stations · only the mutant viable over %s km² (%s%%), neither over %s km²",
                          formatC(n_obs_st, format = "d", big.mark = ","),
                          formatC(round(okm[2]), format = "d", big.mark = ","),
                          n_en(100 * okm[2] / sum(okm)),
                          formatC(round(okm[3]), format = "d", big.mark = ","))) +
  map_theme() + theme(legend.position = "bottom")
ggsave(fig_path("fig47_observed_viability.png"), g_obs, width = 9.5, height = 9.5 / 1.28,
       dpi = 190, bg = "white")

# § 4 — fig41, the range behind the quoted number.
# The canonical document quotes 32.6 % to 66.1 %. That range is real but it is measured over
# STATIONS, while every headline in the project is measured over AREA. On area the same eleven
# models give a different range, and the difference decides whether the sentence "none falls below
# a third" is true. Both are drawn.
cat("4. fig41 per-model range\n")
far <- PM[grepl("_far$", situation)]
far[, scen := sub("_far", "", situation)]
st_rng <- d[grepl("_far$", situation), .(
  pct = 100 * sum(safe_winter_chill_P10 < CR_B & safe_winter_chill_P10 >= CR_P) /
        sum(safe_winter_chill_P10 < CR_B)), by = .(situation, model)]
st_rng[, scen := sub("_far", "", situation)]
far[, base := "over area (km²)"]; st_rng[, base := "over stations"]
both <- rbind(far[, .(scen, model, pct = pct_rescued_of_lost, base)], st_rng[, .(scen, model, pct, base)])
both[, scen := factor(SSP_LAB[scen], levels = SSP_LAB)]
both[, base := factor(base, levels = c("over area (km²)", "over stations"))]

g41 <- ggplot(both, aes(pct, scen, colour = scen)) +
  geom_hline(yintercept = c(1, 2, 3), colour = "grey92", linewidth = 6) +
  geom_vline(xintercept = 100 / 3, linetype = "22", colour = "grey35") +
  geom_point(size = 3, alpha = 0.85) +
  stat_summary(fun = median, geom = "point", shape = 124, size = 9, colour = "grey15") +
  facet_wrap(~ base) +
  scale_colour_manual(values = setNames(SSP_COL, SSP_LAB), guide = "none") +
  scale_x_continuous(labels = function(x) paste0(n_en(x, 0), "%")) +
  labs(title = ttl("How much the mutant rescues, model by model"),
       subtitle = paste("2071-2100 · each point is a model, the vertical bar is the median ·",
                        "the dashed line marks a third\nOver area no model drops below a third;",
                        "over stations the lowest does. The same sentence is true or false depending on the base."),
       x = "fraction of what 'Búlida' loses that the mutant still covers", y = NULL) +
  talk_theme + theme(strip.text = element_text(face = "bold", size = 12))
ggsave(fig_path("fig41_per_model_range.png"), g41, width = 13.5, height = 4.6, dpi = 190,
       bg = "white")

# § 5 — fig42, the two horizons compared on agreement about the direction of change.
# This is the figure that justifies pooling the near term and separating the far one, and it does
# it without a single number: the near-term map is almost entirely hatched, the far-term one almost
# entirely clean.
cat("5. fig42 near-term against far-term agreement\n")
sign_panel <- function(sit, title) {
  ag <- rast(file.path(AGREE_DIR, sprintf("%s_%d.tif", sit, RES_M)))
  cls <- classify(ens_surface(sit))
  df  <- as_df(cls); df$clase <- factor(LAB[df$cls], levels = LAB)
  pct <- AG[situation == sit]$pct_sign_agree
  ggplot() +
    geom_raster(data = df, aes(x, y, fill = clase)) +
    geom_agreement(agreement_bands(ag[["n_decreasing"]], length(models), restrict = cropfrac)) +
    base_map() +
    scale_fill_manual(values = setNames(COL, LAB), drop = FALSE, name = NULL) +
    labs(title = title,
         subtitle = sprintf("sign-of-change agreement: %s%% of the cropland", n_en(pct))) +
    map_theme() + theme(legend.position = "none")
}
g42 <- map_row_with_legend(
  list(sign_panel(paste0(SCEN, "_nearterm"), sprintf("%s · 2021-2040", SSP_LAB[[SCEN]])),
       sign_panel(paste0(SCEN, "_far"),      sprintf("%s · 2071-2100", SSP_LAB[[SCEN]]))),
  leg_side, LEG_IN[["hatch"]]) +
  plot_annotation(
    title = ttl("In the near term the models do not even agree on the direction of change"),
    subtitle = "Diagonal lines where fewer than 80% of the models agree on whether chill rises or falls against the baseline",
    theme = theme(plot.title = element_text(face = "bold", size = 18),
                  plot.subtitle = element_text(size = 12.5, colour = "grey30")))
ggsave(fig_path(sprintf("fig42_sign_agreement_%s.png", SCEN)), g42, width = 13,
       height = slot_height(13), dpi = 190, bg = "white")

# § 5b — fig48, agreement on its own, with its own colour scale.
# The hatching has to share the map with the viability fill, so it can only ever carry three bands.
# Here nothing competes for the colour channel, so all six possible levels are shown: with eleven
# models the majority side can only be 6, 7, 8, 9, 10 or 11, and there is no such thing as an
# agreement below 6 of 11. Kept for the annex, where the extra resolution is worth the extra map.
cat("6. fig48 agreement with its own scale\n")
AG_LAB <- c("6 of 11 (55%)", "7 of 11 (64%)", "8 of 11 (73%)",
            "9 of 11 (82%)", "10 of 11 (91%)", "11 of 11 (100%)")
AG_COL <- c("#67000d", "#cb181d", "#fb6a4a", "#c7e9c0", "#74c476", "#238b45")

agree_only <- function(sit, layer, title, sub) {
  ag <- rast(file.path(AGREE_DIR, sprintf("%s_%d.tif", sit, RES_M)))
  k  <- ag[[layer]]
  agree <- max(k, length(models) - k)
  df <- as_df(mask(agree, cropfrac > 0, maskvalues = c(0, NA)), "n")
  df$lev <- factor(AG_LAB[df$n - 5], levels = AG_LAB)
  ggplot() +
    geom_raster(data = df, aes(x, y, fill = lev)) +
    base_map() +
    scale_fill_manual(values = setNames(AG_COL, AG_LAB), drop = FALSE, name = NULL) +
    labs(title = title, subtitle = sub) +
    map_theme() + theme(legend.position = "none")
}
leg48 <- legend_column(lapply(seq_along(AG_LAB),
                                function(i) list(lab = AG_LAB[i], fill = AG_COL[i])),
                        size = 3.9)

g48 <- map_row_with_legend(
  list(agree_only(paste0(SCEN, "_far"), "n_below_bulida",
                  "On the classification", "is the cell above or below 47.5 CP?"),
       agree_only(paste0(SCEN, "_nearterm"), "n_decreasing",
                  "On the sign of the change", "does chill rise or fall against the baseline?")),
  leg48, LEG_IN[["plain"]]) +
  plot_annotation(
    title = ttl("How many models agree, with nothing competing for the colour"),
    subtitle = sprintf("%s · left 2071-2100, right 2021-2040 · the AR6 criterion (≥80%%) falls between 8 and 9 models
With 11 models the majority side never drops below 6, so agreement below 55%% does not exist",
                       SSP_LAB[[SCEN]]),
    theme = theme(plot.title = element_text(face = "bold", size = 18),
                  plot.subtitle = element_text(size = 12, colour = "grey30")))
ggsave(fig_path(sprintf("fig48_agreement_scale_%s.png", SCEN)), g48, width = 13,
       height = slot_height(13), dpi = 190, bg = "white")

# § 6 — Numbers for the deck.
fwrite(data.table(
  metric = c("n_models", "agree_class_far", "agree_sign_nearterm", "agree_sign_far",
             "km2_rescued_min_pct", "km2_rescued_max_pct", "km2_rescued_median_pct",
             "km2_rescued_min_model", "km2_rescued_max_model",
             "station_rescued_min_pct", "station_rescued_max_pct"),
  value = c(length(models),
            AG[situation == paste0(SCEN, "_far")]$pct_class_agree,
            AG[situation == paste0(SCEN, "_nearterm")]$pct_sign_agree,
            AG[situation == paste0(SCEN, "_far")]$pct_sign_agree,
            min(far[scen == SCEN]$pct_rescued_of_lost), max(far[scen == SCEN]$pct_rescued_of_lost),
            median(far[scen == SCEN]$pct_rescued_of_lost),
            far[scen == SCEN][which.min(pct_rescued_of_lost)]$model,
            far[scen == SCEN][which.max(pct_rescued_of_lost)]$model,
            min(st_rng[scen == SCEN]$pct), max(st_rng[scen == SCEN]$pct)),
  scenario = SCEN), out_path("model_spread_numbers.csv"))

cat(sprintf("\nwrote 4 figures in %s and model_spread_numbers.csv\n", FIG_DIR))
