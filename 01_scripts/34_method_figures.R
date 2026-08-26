#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------------------
# The three didactic figures the method section of the talk needs.
#
# These explain HOW the number is built rather than what it says. They exist because an audience
# that has not met the Dynamic Model will otherwise spend the results section wondering what a
# chill portion is, and because two of the choices in this work (an optimum away from freezing, and
# a percentile instead of a mean) are counter-intuitive enough that stating them is not enough.
#
#   fig34  the temperature response of the Dynamic Model, computed from the model itself
#   fig35  what Safe Winter Chill is, drawn on the 50 observed seasons of one real station
#   fig36  the chain from station points to classified cropland, in three panels
#
# Usage: Rscript 34_method_figures.R [--res 1000]
# Requires: terra, sf, mapSpain, ggplot2, data.table, patchwork, and DM_JOSE.R for fig34.
# ---------------------------------------------------------------------------------------

suppressWarnings(suppressMessages({
  library(terra); library(sf); library(mapSpain); library(ggplot2); library(data.table)
  library(patchwork)
}))

args   <- commandArgs(trailingOnly = TRUE)
getarg <- function(f, d) { i <- which(args == f); if (length(i)) args[i + 1] else d }
RES_M  <- as.numeric(getarg("--res", 1000))

.f <- grep("^--file=", commandArgs(FALSE), value = TRUE)
.dir <- if (length(.f)) dirname(normalizePath(sub("^--file=", "", .f[1]))) else getwd()
source(file.path(.dir, "00_paths.R"))
source(file.path(.dir, "00_map_layout.R"))
source(file.path(.dir, "00_corine.R"))   # cell_area_km2()

EPSG <- 3035; CR_B <- 47.5; CR_P <- 33.7
CACHE <- out_path("surface_cache")
# A figure that goes on a slide carries no title of its own: the slide states the assertion, and
# two titles stacked read as a mistake, the more so because ggplot's renders smaller than the
# slide's. The subtitles stay, because they carry the quantities. Export self-contained figures,
# for sending on their own, with PLINIUS_FIG_TITLE=TRUE.
FIG_TITLE <- toupper(Sys.getenv("PLINIUS_FIG_TITLE", "FALSE")) %in% c("TRUE", "1", "YES")
ttl <- function(x) if (FIG_TITLE) x else NULL

# English number format for anything the audience reads: comma for thousands, full stop for the
# decimal. R's sprintf formats through the C locale and emits no thousands separator at all, so
# "45089 km2" would reach a slide. Every user-visible number goes through here as %s, not as %f.
n_en <- function(x, d = 1) formatC(x, format = "f", digits = d, big.mark = ",", decimal.mark = ".")

talk_theme <- theme_minimal(base_size = 14) +
  theme(plot.title = element_text(face = "bold", size = 17),
        plot.subtitle = element_text(size = 12.5, colour = "grey30"),
        panel.grid.minor = element_blank(), legend.position = "bottom")

# § 1 — fig34, the temperature response of the model.
# Measured, not asserted: the model is run on constant-temperature series and the chill it
# accumulates per day is read off.
#
# The series length is not arbitrary. The Dynamic Model carries an intermediate state, so the rate
# per day rises as the series lengthens and only settles asymptotically (0.779 CP/day over 30 days,
# 0.791 over 120, 0.799 over 2000). 120 days is the length of the dormancy season this project
# integrates over (JDay 305 to 59), which is the only length whose rate means anything here, and it
# reproduces the 0.791 CP/day already documented for the project.
cat("1. dynamic model response curve\n")
source_dm_jose()
temps <- seq(-12, 26, by = 0.5)
DAYS  <- 120
resp  <- vapply(temps, function(tt) {
  cp <- DM_JOSE(rep(tt, DAYS * 24), summ = TRUE)
  as.numeric(cp[length(cp)]) / DAYS
}, numeric(1))
rc <- data.table(temp = temps, cp_day = resp)
opt <- rc[which.max(cp_day)]
cat(sprintf("   optimum %.3f CP/day at %.1f C\n", opt$cp_day, opt$temp))

pct <- function(t) 100 * rc[which.min(abs(temp - t))]$cp_day / opt$cp_day
g34 <- ggplot(rc, aes(temp, cp_day)) +
  geom_area(fill = "#2c7bb6", alpha = 0.18) +
  geom_line(colour = "#2c7bb6", linewidth = 1.2) +
  geom_vline(xintercept = opt$temp, linetype = "22", colour = "grey40") +
  annotate("point", x = opt$temp, y = opt$cp_day, size = 3.4, colour = "#2c7bb6") +
  annotate("text", x = opt$temp + 0.7, y = opt$cp_day, hjust = 0, vjust = 0.2, size = 4.6,
           fontface = "bold", colour = "#2c7bb6",
           label = sprintf("optimum: %s CP/day at %s °C", n_en(opt$cp_day, 3), n_en(opt$temp, 0))) +
  annotate("text", x = -11, y = opt$cp_day * 0.86, hjust = 0, size = 4.2, colour = "grey30",
           label = sprintf("at 0 °C only %s%% of the\noptimum accumulates", n_en(pct(0), 0))) +
  annotate("text", x = 17.5, y = opt$cp_day * 0.55, hjust = 0, size = 4.2, colour = "grey30",
           label = "above 14 °C\nnothing accumulates") +
  scale_x_continuous(breaks = seq(-10, 25, 5)) +
  # The only axis in the deck whose ticks carry decimals, so the only one that needs saying.
  scale_y_continuous(labels = function(x) n_en(x, 1)) +
  labs(title = ttl("The chill that counts has an optimum, and it is not at freezing point"),
       subtitle = "Response of the Dynamic Model (Fishman et al. 1987) measured on constant-temperature series",
       x = "Temperature (°C)", y = "Chill portions accumulated per day") +
  talk_theme
ggsave(fig_path("fig34_dynamic_model_response.png"), g34, width = 11.5, height = 6, dpi = 190,
       bg = "white")

# § 2 — fig35, what a percentile buys over a mean.
# Drawn on the longest observed record available, so the audience sees real seasons rather than a
# schematic. The point is that a grower is not ruined by the average winter but by the poor one,
# which is why the statistic that matters is a low percentile.
cat("2. Safe Winter Chill concept\n")
os <- fread(out_path("chill_obs_seasons_1975.csv"))
cand <- os[perc_complete >= 85, .(n = .N, sdv = sd(CP), mu = mean(CP)), by = station_id]
# A station with a full record and enough spread for the gap between mean and P10 to be visible.
pick <- cand[n >= 44][which.max(sdv)]$station_id[1]
ss   <- os[station_id == pick & perc_complete >= 85][order(season_end_year)]
p10  <- quantile(ss$CP, 0.10); mn <- mean(ss$CP)

g35 <- ggplot(ss, aes(season_end_year, CP)) +
  geom_col(aes(fill = CP <= p10), width = 0.78) +
  geom_hline(yintercept = mn, colour = "grey35", linewidth = 0.9, linetype = "22") +
  geom_hline(yintercept = p10, colour = "#d7191c", linewidth = 1.1) +
  scale_fill_manual(values = c(`FALSE` = "#9ecae1", `TRUE` = "#d7191c"), guide = "none") +
  annotate("label", x = min(ss$season_end_year), y = mn, hjust = 0, size = 4.3, colour = "grey25",
           fill = "white", label = sprintf("mean: %s CP", n_en(mn))) +
  annotate("label", x = min(ss$season_end_year), y = p10, hjust = 0, size = 4.3, colour = "#d7191c",
           fill = "white", fontface = "bold",
           label = sprintf("Safe Winter Chill (P10): %s CP", n_en(p10))) +
  labs(title = ttl("What ruins a grower is not the average winter, it is the poor one"),
       subtitle = sprintf("Station %s · %d observed seasons · the P10 is the chill exceeded in nine winters out of ten",
                          pick, nrow(ss)),
       x = NULL, y = "Chill portions of the season") +
  talk_theme
ggsave(fig_path("fig35_swc_concept.png"), g35, width = 12.5, height = 5.8, dpi = 190, bg = "white")

# § 3 — fig36, the chain from points to territory in three panels.
# The step that needs showing is the middle one: a network of stations is not a map, and the jump
# from one to the other is where a reader is entitled to be sceptical. Panel 3 also makes visible
# that most of the surface is discarded, because only cropland is ever counted.
cat("3. chain stations -> surface -> cropland\n")
ccaa  <- esp_get_ccaa(epsg = 4326)
ccaa  <- st_transform(ccaa[!grepl("Canaria", ccaa$ine.ccaa.name), ], EPSG)
disp  <- ccaa[!ccaa$ine.ccaa.name %in% c("Ceuta", "Melilla"), ]
DE    <- ext(vect(st_union(disp))); PAD <- 0.02 * (DE$xmax - DE$xmin)
XLIM  <- c(DE$xmin - PAD, DE$xmax + PAD); YLIM <- c(DE$ymin - PAD, DE$ymax + PAD)
MAP_AR <- diff(YLIM) / diff(XLIM)

surf_f <- file.path(CACHE, sprintf("swc_presente_present_%d.tif", RES_M))
crop_f <- file.path(CACHE, sprintf("cropfrac_%d.tif", RES_M))
if (!file.exists(surf_f) || !file.exists(crop_f))
  stop("surfaces missing from cache; run first: Rscript 33_talk_figures.R")
surf <- rast(surf_f); cropfrac <- rast(crop_f)

d   <- fread(out_path("chill_all_windows.csv"))
pts <- d[situation == "presente_present",
         .(SWC = median(safe_winter_chill_P10)), by = .(station_id, lon, lat)]
pts_p <- as.data.frame(project(vect(as.data.frame(pts), geom = c("lon", "lat"), crs = "EPSG:4326"),
                               paste0("EPSG:", EPSG)), geom = "XY")

base_map <- function(title, sub) list(
  geom_sf(data = disp, fill = NA, colour = "grey60", linewidth = 0.14),
  coord_sf(crs = EPSG, datum = NA, expand = FALSE, xlim = XLIM, ylim = YLIM),
  labs(title = title, subtitle = sub),
  talk_theme,
  theme(panel.grid = element_blank(), axis.text = element_blank(), axis.title = element_blank(),
        legend.position = "none", plot.title = element_text(size = 14),
        plot.subtitle = element_text(size = 11)))

p1 <- ggplot() + geom_point(data = pts_p, aes(x, y, colour = SWC), size = 0.32) +
  scale_colour_viridis_c() + base_map("1. What there is: stations",
                                      sprintf("%s points with chill computed", n_en(nrow(pts), 0)))
sdf <- as.data.frame(surf, xy = TRUE, na.rm = TRUE); names(sdf)[3] <- "SWC"
p2 <- ggplot() + geom_raster(data = sdf, aes(x, y, fill = SWC)) +
  scale_fill_viridis_c() + base_map("2. IDW interpolation, 50 km radius",
                                    "cells with no station within 50 km are left empty")
cls <- mask(ifel(surf >= CR_B, 1L, ifel(surf >= CR_P, 2L, 3L)), cropfrac > 0, maskvalues = c(0, NA))
cdf <- as.data.frame(cls, xy = TRUE, na.rm = TRUE); names(cdf)[3] <- "k"
LAB <- c("Both cultivars", "Only 'Búlida Precoz'", "Neither")
cdf$clase <- factor(LAB[cdf$k], levels = LAB)

# Panel 3 shows the MASK, not the answer. An earlier version put the classified viability map here,
# which meant a figure whose job is to explain the method was already giving away the result three
# slides before the results section. What belongs in a chain diagram is the last input, not the
# output.
# Drawn as the cropland FRACTION of each cell, not as a yes/no. The mask keeps any cell with some
# cropland in it, so a binary version paints almost the whole country green and suggests that all
# of Spain is farmland. What actually enters the area statistics is the fraction, and every cell
# contributes in proportion to it, so that is what the panel shows.
cropdf <- as.data.frame(ifel(cropfrac > 0, cropfrac, NA), xy = TRUE, na.rm = TRUE)
names(cropdf)[3] <- "frac"
p3 <- ggplot() +
  geom_sf(data = disp, fill = "grey93", colour = NA) +
  geom_raster(data = cropdf, aes(x, y, alpha = frac), fill = "#2e8b57") +
  scale_alpha_continuous(range = c(0.12, 1), guide = "none") +
  base_map("3. Only cropland, and in what proportion",
           sprintf("%s km² of CORINE 211-244, pastures excluded",
                   formatC(round(global(cropfrac, "sum", na.rm = TRUE)[1, 1] * cell_area_km2(cropfrac)),
                           format = "d", big.mark = ",")))

g36 <- (p1 | p2 | p3) +
  plot_annotation(
    title = ttl("A network of stations is not a map, and a count of stations is not an area"),
    subtitle = "Interpolation and mask replicating Egea et al. 2022 (Front. Plant Sci. 13:842628), with 3,460 stations against the 270 of that reference",
    theme = theme(plot.title = element_text(face = "bold", size = 17),
                  plot.subtitle = element_text(size = 12, colour = "grey30")))
ggsave(fig_path("fig36_method_chain.png"), g36, width = 15, height = slot_height(15), dpi = 190,
       bg = "white")

# § 4 — fig37, the anchor map the results section opens on.
# The same classified baseline as panel 3 above, alone and at full size. The talk needs a "this is
# today" frame that carries no scenario label, because the baseline is shared by all three and
# labelling it with one of them would suggest a divergence that has not happened yet.
km2_base <- sapply(1:3, function(k)
  global(mask(cropfrac, cls == k, maskvalues = c(0, NA)), "sum", na.rm = TRUE)[1, 1] * cell_area_km2(cropfrac))
km2_base[is.na(km2_base)] <- 0
g37 <- ggplot() + geom_raster(data = cdf, aes(x, y, fill = clase)) +
  geom_sf(data = disp, fill = NA, colour = "grey55", linewidth = 0.15) +
  coord_sf(crs = EPSG, datum = NA, expand = FALSE, xlim = XLIM, ylim = YLIM) +
  scale_fill_manual(values = setNames(c("#2c7bb6", "#fdae61", "#d7191c"), LAB), drop = FALSE,
                    name = NULL) +
  labs(title = ttl("Today 'Búlida' meets its chill requirement on almost all Spanish cropland"),
       subtitle = sprintf("Baseline 1995-2020 · only the mutant would be viable on %s km² (%s%%), neither cultivar on %s km²",
                          formatC(round(km2_base[2]), format = "d", big.mark = ","),
                          n_en(100 * km2_base[2] / sum(km2_base)),
                          formatC(round(km2_base[3]), format = "d", big.mark = ","))) +
  talk_theme +
  theme(panel.grid = element_blank(), axis.text = element_blank(), axis.title = element_blank())
ggsave(fig_path("fig37_baseline_today.png"), g37, width = 9.5, height = 9.5 / 1.28,
       dpi = 190, bg = "white")

fwrite(data.table(metric = c("dm_optimum_cp_day", "dm_optimum_temp_C", "dm_pct_at_0C",
                             "swc_example_station", "swc_example_mean", "swc_example_p10"),
                  value = c(opt$cp_day, opt$temp, pct(0), pick, mn, p10)),
       out_path("method_figure_numbers.csv"))
cat(sprintf("\nwrote 3 figures in %s\n", FIG_DIR))
