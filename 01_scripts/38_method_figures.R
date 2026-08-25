#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------------------
# Figures for the methods half of the talk: what was done to the data, and what was not.
#
#   fig43  bias of each model against the observations, over the same window and stations
#   fig44  the aggregation chain, with how many numbers enter and leave each stage
#   fig45  absolute values against the delta (future minus that model's own past)
#   fig46  one real station followed from its seasons to the class its neighbourhood gets
#
# fig43 answers a question that has an uncomfortable-looking answer: no bias correction was
# applied. The answer is defensible, and this figure is why. ESD-RegBA arrives already downscaled
# and adjusted by AEMET, and the residual bias of the eleven models spans 2.8 CP on a variable
# whose national median is about 74. Correcting that would move the result less than the choice of
# parametrisation does, and it would spend the observations twice, since the product was calibrated
# against these very stations.
#
# fig45 is the companion argument. If the conclusion held only because the absolute values happen
# to be right, it would be fragile. Comparing each model to ITS OWN past removes any constant bias
# it carries, and the loss signal survives.
#
# Usage: Rscript 38_method_figures.R [--res 1000] [--station 7121A]
# Requires: terra, sf, mapSpain, ggplot2, data.table, patchwork.
# ---------------------------------------------------------------------------------------

suppressWarnings(suppressMessages({
  library(terra); library(sf); library(mapSpain); library(ggplot2); library(data.table)
  library(patchwork)
}))

args   <- commandArgs(trailingOnly = TRUE)
getarg <- function(f, d) { i <- which(args == f); if (length(i)) args[i + 1] else d }
RES_M  <- as.numeric(getarg("--res", 1000))
STN    <- getarg("--station", "7121A")

.f <- grep("^--file=", commandArgs(FALSE), value = TRUE)
.dir <- if (length(.f)) dirname(normalizePath(sub("^--file=", "", .f[1]))) else getwd()
source(file.path(.dir, "00_paths.R"))
source(file.path(.dir, "00_map_layout.R"))
source(file.path(.dir, "00_corine.R"))   # cell_area_km2()

CR_B <- 47.5; CR_P <- 33.7
SSP_COL <- c(ssp126 = "#173C66", ssp245 = "#F79420", ssp370 = "#E71D25")
SSP_LAB <- c(ssp126 = "SSP1-2.6", ssp245 = "SSP2-4.5", ssp370 = "SSP3-7.0")
CACHE <- out_path("surface_cache")

FIG_TITLE <- toupper(Sys.getenv("PLINIUS_FIG_TITLE", "FALSE")) %in% c("TRUE", "1", "YES")
ttl <- function(x) if (FIG_TITLE) x else NULL
n_en <- function(x, d = 1) formatC(x, format = "f", digits = d, big.mark = ",", decimal.mark = ".")
i_en <- function(x) formatC(round(x), format = "d", big.mark = ",", decimal.mark = ".")

talk_theme <- theme_minimal(base_size = 14) +
  theme(plot.title = element_text(face = "bold", size = 17),
        plot.subtitle = element_text(size = 12.5, colour = "grey30"),
        panel.grid.minor = element_blank(), legend.position = "bottom")

cat("1. datos\n")
d  <- fread(out_path("chill_all_windows.csv"))
dm <- d[model != "obs"]
models <- sort(unique(dm$model))
# The cropland denominator is read, never typed. It used to be a literal here and went stale the
# moment the cell area was corrected on 2026-08-14: the figure kept claiming 229,604 km2 while every
# table said 229,676.
CROP_KM2 <- fread(out_path("talk_numbers_cropland.csv"))[1,
              crop_km2_both + crop_km2_only_precoz + crop_km2_none]

# § 1 — fig43, how far each model sits from the observations.
# Same window and the same 3044 stations for both sides, because comparing a model over one period
# with observations over another measures the periods, not the model.
cat("2. fig43 sesgo por modelo\n")
obs <- d[situation == "observaciones_present", .(station_id, obs = safe_winter_chill_P10)]
mod <- dm[situation == "presente_present", .(station_id, model, mod = safe_winter_chill_P10)]
mm  <- merge(mod, obs, by = "station_id")
bias <- mm[, .(sesgo = median(mod - obs), mae = median(abs(mod - obs)), r = cor(mod, obs),
               q25 = quantile(mod - obs, .25), q75 = quantile(mod - obs, .75)), by = model]
ens_bias <- {
  e <- mm[, .(mod = median(mod)), by = station_id]
  e <- merge(e, obs, by = "station_id"); median(e$mod - e$obs)
}
bias <- bias[order(sesgo)][, model := factor(model, levels = model)]

g43 <- ggplot(bias, aes(sesgo, model)) +
  annotate("rect", xmin = -1, xmax = 1, ymin = 0.4, ymax = nrow(bias) + 0.6,
           fill = "#2c7bb6", alpha = 0.10) +
  geom_vline(xintercept = 0, colour = "grey35") +
  geom_vline(xintercept = ens_bias, linetype = "22", colour = "#d7191c", linewidth = 0.9) +
  geom_segment(aes(x = q25, xend = q75, yend = model), colour = "grey70", linewidth = 1.1) +
  geom_point(size = 3.6, colour = "#2c7bb6") +
  geom_text(aes(label = sprintf("r = %s", n_en(r, 3))), x = max(bias$q75) + 0.55, hjust = 0,
            size = 3.6, colour = "grey40") +
  annotate("text", x = ens_bias - 0.12, y = nrow(bias) + 0.5, hjust = 1, size = 3.9,
           colour = "#d7191c", fontface = "bold",
           label = sprintf("ensemble median: %s CP", n_en(ens_bias, 2))) +
  scale_x_continuous(limits = c(min(bias$q25) - 0.4, max(bias$q75) + 2.2),
                     breaks = seq(-4, 2, 1), labels = function(x) paste0(n_en(x, 0), " CP")) +
  scale_y_discrete(expand = expansion(add = c(0.6, 0.6))) +
  labs(title = ttl("No model departs far enough to justify correcting it"),
       subtitle = sprintf(paste0("Safe Winter Chill bias against the observations, same 1995-2020 window and the same %s stations\n",
                                 "The blue band is ±1 CP. The point is the median across stations, the grey bar the interquartile range."),
                          i_en(uniqueN(mm$station_id))),
       x = "model minus observed", y = NULL) +
  talk_theme
ggsave(fig_path("fig43_model_bias.png"), g43, width = 12.5, height = 6, dpi = 190, bg = "white")

# § 2 — fig44, the aggregation chain.
# Drawn because "the median of eleven models" hides four other reductions that happen before it,
# and the audience cannot judge the result without knowing that the map is the last of five
# collapses, not the first.
cat("3. fig44 cadena de agregacion\n")
n_st <- uniqueN(dm$station_id); n_md <- length(models)
n_seasons_far <- max(dm[window == "far"]$n_seasons)
surf <- rast(file.path(CACHE, sprintf("swc_presente_present_%d.tif", RES_M)))
n_cells <- global(!is.na(surf), "sum")[1, 1]

steps <- data.table(
  i = 1:6,
  etapa = c("Daily temperature",
            "Chill per season",
            "Safe Winter Chill",
            "Median across models",
            "Interpolated surface",
            "Classified cropland"),
  detalle = c(sprintf("%s stations × %d models × 2 variables × ~30 years", i_en(n_st), n_md),
              sprintf("Dynamic Model on each season\n%s × %d × %d seasons",
                      i_en(n_st), n_md, n_seasons_far),
              sprintf("10th percentile of the seasons\n%s × %d = %s values",
                      i_en(n_st), n_md, i_en(n_st * n_md)),
              sprintf("one value per station\n%s values", i_en(n_st)),
              sprintf("IDW, 50 km radius\n%s cells of 1 km", i_en(n_cells)),
              sprintf("CORINE mask and two thresholds\n%s km² in 3 classes", i_en(CROP_KM2))),
  n = c(NA, NA, n_st * n_md, n_st, n_cells, NA))
steps[, y := rev(seq_len(.N))]

g44 <- ggplot(steps) +
  geom_rect(aes(xmin = 0, xmax = 3.4, ymin = y - 0.36, ymax = y + 0.36),
            fill = c(rep("#eef3f8", 3), "#dbe7f2", "#eef3f8", "#fdf0e3"), colour = NA) +
  geom_text(aes(0.16, y + 0.14, label = etapa), hjust = 0, size = 4.6, fontface = "bold",
            colour = "grey12") +
  geom_text(aes(0.16, y - 0.15, label = detalle), hjust = 0, size = 3.5, colour = "grey35",
            lineheight = 0.95) +
  geom_segment(data = steps[i < 6], aes(x = 1.7, xend = 1.7, y = y - 0.38, yend = y - 0.62),
               arrow = arrow(length = unit(0.16, "cm"), type = "closed"), colour = "grey45") +
  annotate("text", x = 3.55, y = steps[i == 4]$y, hjust = 0, size = 3.9, colour = "#d7191c",
           lineheight = 0.95,
           label = "this is where the\nmodel spread is\nlost: it is brought\nback separately") +
  coord_cartesian(xlim = c(0, 4.6), ylim = c(0.3, 6.8), expand = FALSE) +
  labs(title = ttl("The map is the last of five collapses, not the first"),
       subtitle = "Each stage cuts down the number of values. Knowing where each reduction happens is what lets you judge the result.") +
  theme_void(base_size = 14) +
  theme(plot.title = element_text(face = "bold", size = 17, hjust = 0),
        plot.subtitle = element_text(size = 12.5, colour = "grey30", hjust = 0),
        plot.margin = margin(10, 10, 10, 10))
ggsave(fig_path("fig44_aggregation_chain.png"), g44, width = 13.5, height = 6.4, dpi = 190,
       bg = "white")

# § 3 — fig45, absolute against delta.
# Each model is compared to its own baseline, so any constant offset it carries cancels. If the
# conclusion only survived on absolute values it would depend on the bias correction not applied.
cat("4. fig45 delta frente a absoluto\n")
base_m <- dm[situation == "presente_present", .(station_id, model, base = safe_winter_chill_P10)]
delt <- rbindlist(lapply(c("ssp126_far", "ssp245_far", "ssp370_far"), function(s) {
  fut <- dm[situation == s, .(station_id, model, fut = safe_winter_chill_P10)]
  z <- merge(fut, base_m, by = c("station_id", "model"))
  z[, .(scen = sub("_far", "", s), model, station_id, delta = fut - base)]
}))
ds <- delt[, .(med = median(delta)), by = .(scen, model)]
ds[, scen := factor(SSP_LAB[scen], levels = SSP_LAB)]

g45 <- ggplot(ds, aes(med, scen, colour = scen)) +
  geom_vline(xintercept = 0, colour = "grey40") +
  geom_point(size = 3.4, alpha = 0.9) +
  stat_summary(fun = median, geom = "point", shape = 124, size = 9, colour = "grey15") +
  scale_colour_manual(values = setNames(SSP_COL, SSP_LAB), guide = "none") +
  scale_x_continuous(labels = function(x) paste0(n_en(x, 0), " CP")) +
  labs(title = ttl("Comparing each model with itself, the loss is still there"),
       subtitle = paste("Change in Safe Winter Chill between 1995-2020 and 2071-2100, each model against its own baseline.",
                        "\nAny constant model bias cancels out in this subtraction, so the result does not depend on correcting it or not."),
       x = "change in chill, end century minus baseline", y = NULL) +
  talk_theme
ggsave(fig_path("fig45_delta_vs_absolute.png"), g45, width = 12.5, height = 4.6, dpi = 190,
       bg = "white")

# § 4 — fig46, one real station from its record to its class.
# Abstract chains are hard to trust. This is the same chain applied to a single named station, with
# every number visible, so the audience can check the arithmetic of the method on one case.
cat(sprintf("5. fig46 recorrido de la estacion %s\n", STN))
os <- fread(out_path("chill_obs_seasons_1975.csv"))[station_id == STN & perc_complete >= 85]
setorder(os, season_end_year)
if (!nrow(os)) stop("la estacion ", STN, " no tiene temporadas observadas suficientes")
p10_obs <- quantile(os$CP, 0.10)

pa <- ggplot(os, aes(season_end_year, CP)) +
  geom_col(aes(fill = CP <= p10_obs), width = 0.8) +
  geom_hline(yintercept = p10_obs, colour = "#d7191c", linewidth = 1) +
  scale_fill_manual(values = c(`FALSE` = "#9ecae1", `TRUE` = "#d7191c"), guide = "none") +
  annotate("label", x = min(os$season_end_year), y = p10_obs, hjust = 0, size = 3.8,
           colour = "#d7191c", fill = "white", fontface = "bold",
           label = sprintf("observed P10 = %s CP", n_en(p10_obs))) +
  labs(title = sprintf("1. Measured: %d seasons", nrow(os)),
       x = NULL, y = "Chill portions of the season") +
  talk_theme + theme(plot.title = element_text(size = 13.5))

stm <- rbind(
  dm[station_id == STN & situation == "presente_present", .(model, SWC = safe_winter_chill_P10, w = "1995-2020")],
  dm[station_id == STN & situation == "ssp370_far", .(model, SWC = safe_winter_chill_P10, w = "2071-2100")])
med <- stm[, .(m = median(SWC)), by = w]
pb <- ggplot(stm, aes(SWC, w)) +
  geom_vline(xintercept = CR_B, colour = "#b2182b", linewidth = 0.9) +
  geom_vline(xintercept = CR_P, colour = "#2166ac", linewidth = 0.9) +
  geom_point(size = 3, colour = "grey45", alpha = 0.85) +
  geom_point(data = med, aes(m, w), size = 5, shape = 124, colour = "grey10") +
  geom_text(data = med, aes(m, w, label = n_en(m)), vjust = -1.4, size = 4, fontface = "bold") +
  scale_x_continuous(labels = function(x) paste0(n_en(x, 0), " CP")) +
  labs(title = "2. Simulated: 11 models",
       subtitle = sprintf("lines: 'Búlida' (%s), mutant (%s)",
                          n_en(CR_B), n_en(CR_P)),
       x = NULL, y = NULL) +
  talk_theme + theme(plot.title = element_text(size = 13.5), plot.subtitle = element_text(size = 11))

# Panel 3 closes the chain. Panels 1 and 2 end with a number at a point, which is where this figure
# used to stop, and a number at a point is not the result: the result is territory. This shows the
# station's own 50 km neighbourhood, the radius within which it actually weighs on the
# interpolation, with the cropland classified before and after. It is the step where the audience
# sees a chill portion become a hectare.
cat("6. fig46 panel 3, del punto al terreno\n")
crop_f <- file.path(CACHE, sprintf("cropfrac_%d.tif", RES_M))
if (!file.exists(crop_f)) stop("falta ", basename(crop_f), "; ejecuta antes 36_per_model_stats.R",
                               call. = FALSE)
cropfrac <- rast(crop_f)
CELL <- cell_area_km2(cropfrac)

xy <- crds(project(vect(as.data.frame(unique(dm[station_id == STN, .(lon, lat)])),
                        geom = c("lon", "lat"), crs = "EPSG:4326"), crs(cropfrac)))[1, ]
HALF <- 62000                                   # a little past the 50 km radius, for context
win  <- ext(xy[1] - HALF, xy[1] + HALF, xy[2] - HALF, xy[2] + HALF)

classify_local <- function(s) ifel(s >= CR_B, 1L, ifel(s >= CR_P, 2L, 3L))
SIT3 <- c(presente_present = "1995-2020", ssp370_far = "2071-2100 · SSP3-7.0")
LAB3 <- c("Both cultivars", "Only 'Búlida Precoz'", "Neither")
COL3 <- c("#2c7bb6", "#fdae61", "#d7191c")

cfw <- crop(cropfrac, win)
# The km2 of each class go into the panel heading, not on top of the map. Written over the raster
# they sat on the colour they were describing and could not be read at all.
built <- lapply(names(SIT3), function(s) {
  f <- file.path(CACHE, sprintf("swc_%s_%d.tif", s, RES_M))
  if (!file.exists(f)) return(NULL)
  cls <- mask(classify_local(crop(rast(f), win)), cfw > 0, maskvalues = c(0, NA))
  km  <- sapply(1:3, function(k)
    global(mask(cfw, cls == k, maskvalues = c(0, NA)), "sum", na.rm = TRUE)[1, 1] * CELL)
  km[is.na(km)] <- 0
  df <- as.data.frame(cls, xy = TRUE, na.rm = TRUE)
  names(df)[3] <- "k"
  list(df = as.data.table(df), sit = s, km = km,
       lab = sprintf("%s\n%s both · %s mutant\n%s neither  (km²)",
                     SIT3[[s]], i_en(km[1]), i_en(km[2]), i_en(km[3])))
})
built <- Filter(Negate(is.null), built)
if (!length(built)) stop("no hay superficies cacheadas para el panel 3 de fig46")
labs3 <- vapply(built, `[[`, character(1), "lab")
loc <- rbindlist(Map(function(b, l) b$df[, sit := l], built, labs3))
loc[, sit := factor(sit, levels = labs3)]

circle <- st_as_sf(st_sfc(st_buffer(st_point(xy), 50000), crs = crs(cropfrac)))
pc <- ggplot() +
  geom_raster(data = loc, aes(x, y, fill = factor(LAB3[k], levels = LAB3))) +
  geom_sf(data = circle, fill = NA, colour = "grey20", linewidth = 0.4, linetype = "22") +
  annotate("point", x = xy[1], y = xy[2], size = 2.6, shape = 21, fill = "white", colour = "grey10",
           stroke = 1) +
  facet_wrap(~ sit) +
  scale_fill_manual(values = setNames(COL3, LAB3), name = NULL, drop = FALSE) +
  coord_sf(expand = FALSE) +
  labs(title = sprintf("3. On the ground: 50 km around %s", STN),
       subtitle = "Circle: the radius this station weighs over. Cropland only.") +
  theme_void(base_size = 14) +
  theme(plot.title = element_text(face = "bold", size = 13.5),
        plot.subtitle = element_text(size = 11, colour = "grey30"),
        strip.text = element_text(size = 11, colour = "grey20", lineheight = 1.25,
                                  margin = margin(b = 5)),
        legend.position = "bottom")

# In a row rather than a column. Stacked, the sheet came out 1.1 wide per unit tall against the
# slide's 2.6, so PowerPoint scaled it to fit the height and left 58% of the width empty. The three
# panels read left to right in the same order they read top to bottom.
g46 <- (pa | pb | pc) +
  plot_layout(widths = c(1, 0.85, 1.25)) +
  plot_annotation(
    title = ttl(sprintf("The same calculation, followed at one real station: %s", STN)),
    subtitle = paste("Calasparra (Murcia), 394 m. Today the ensemble median leaves it above the",
                     "chill requirement of 'Búlida';\nby the end of the century, below it, but well",
                     "above that of its mutant."),
    theme = theme(plot.title = element_text(face = "bold", size = 17),
                  plot.subtitle = element_text(size = 12, colour = "grey30")))
ggsave(fig_path("fig46_station_walkthrough.png"), g46, width = 15, height = slot_height(15),
       dpi = 190, bg = "white")

fwrite(data.table(
  metric = c("bias_min_CP", "bias_max_CP", "bias_range_CP", "bias_ensemble_CP", "bias_min_model",
             "bias_max_model", "bias_worst_abs_CP", "r_min", "n_bias_stations",
             "chain_stations", "chain_models", "chain_swc_values", "chain_cells",
             "delta_median_CP", "delta_min_CP", "delta_max_CP",
             "walk_station", "walk_p10_obs", "walk_med_base", "walk_med_far"),
  value = c(min(bias$sesgo), max(bias$sesgo), diff(range(bias$sesgo)), ens_bias,
            as.character(bias[which.min(sesgo)]$model), as.character(bias[which.max(sesgo)]$model),
            max(abs(bias$sesgo)), min(bias$r), uniqueN(mm$station_id),
            n_st, n_md, n_st * n_md, n_cells,
            median(ds[scen == SSP_LAB[["ssp370"]]]$med), min(ds[scen == SSP_LAB[["ssp370"]]]$med),
            max(ds[scen == SSP_LAB[["ssp370"]]]$med),
            STN, p10_obs, med[w == "1995-2020"]$m, med[w == "2071-2100"]$m)),
  out_path("method_chain_numbers.csv"))

# The neighbourhood areas of panel 3 are projected on a slide, so they go in a table like every
# other figure that gets shown. One row per situation and class.
fwrite(rbindlist(lapply(built, function(b) data.table(
  station = STN, radius_km = 50, situation = b$sit,
  km2_both = b$km[1], km2_only_precoz = b$km[2], km2_none = b$km[3]))),
  out_path("station_walkthrough_km2.csv"))

cat(sprintf("\nescritas 4 figuras en %s y method_chain_numbers.csv\n", FIG_DIR))
