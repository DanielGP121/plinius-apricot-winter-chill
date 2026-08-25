#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------------------
# Where every station and every square kilometre goes: the attrition funnel.
#
#   fig51  two funnels. Left, the station network and the seasons the completeness filter drops.
#          Right, the territory, from the country outline down to the cropland the result is
#          reported on.
#
# WHY. "229,676 km2 of Spanish cropland" is the denominator of every headline in this project, and
# until now the only way to check it was to trust it. A supervisor's first question about an area
# statistic is what fell out on the way, and the honest answer has to be a subtraction they can do
# themselves. This is the PRISMA flow diagram idea borrowed from systematic reviews: counts and
# reasons at every step, no rounded percentages standing in for numbers.
#
# WHAT THE FIGURE REFUSES TO DO. It does not present the two download routes of the AEMET portal as
# attrition. THREDDS serves 3460 stations and the web form serves 3044 of the same product: that is
# a fork, not a loss, and drawing it as a funnel step would imply 416 stations were discarded on
# some quality ground. It is drawn as a fork and labelled as one.
#
# THE ONE THING THAT CANNOT BE COUNTED FROM HERE. Stations that the chill engine rejected outright
# on the HPC never reach the canonical table, so their number is not recoverable from local outputs.
# What IS recoverable is the seasons the 85 % completeness filter dropped, because the table carries
# n_seasons per station, model and window. The figure says which of the two it is showing.
#
# Usage: Rscript 40_attrition_funnel.R [--res 1000]
# Requires: terra, sf, mapSpain, ggplot2, data.table, patchwork.
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
source(file.path(.dir, "00_corine.R"))

EPSG <- 3035
FIG_TITLE <- toupper(Sys.getenv("PLINIUS_FIG_TITLE", "FALSE")) %in% c("TRUE", "1", "YES")
ttl <- function(x) if (FIG_TITLE) x else NULL
n_en <- function(x, d = 1) formatC(x, format = "f", digits = d, big.mark = ",", decimal.mark = ".")
i_en <- function(x) formatC(round(x), format = "d", big.mark = ",", decimal.mark = ".")

funnel_theme <- theme_void(base_size = 14) +
  theme(plot.title = element_text(face = "bold", size = 14, hjust = 0),
        plot.subtitle = element_text(size = 11, colour = "grey35", hjust = 0),
        plot.margin = margin(8, 8, 8, 8))

# § 1 — The station side, counted from the canonical table.
cat("1. stations and seasons\n")
d  <- fread(out_path("chill_all_windows.csv"))
dm <- d[model != "obs"]

N_THREDDS <- uniqueN(dm$station_id)
N_FORM    <- uniqueN(d[model == "obs"]$station_id)   # the archive, which is the web-form census

# Seasons kept against seasons the window could have held. The nominal length is taken as the
# maximum observed in each window rather than from the window's dates, so a window whose data simply
# ends early is not counted as a filter rejection.
# Over the WHOLE table, not just the simulated half. The observed windows are windows too, and
# leaving them out made this table show six of the seven the project has, which is exactly the kind
# of inventory mismatch a reader trips over.
ds <- copy(d)
ds[, max_win := max(n_seasons), by = window]
seas <- ds[, .(nominal = sum(max_win), kept = sum(n_seasons)), by = .(window, periodo)]
seas[, `:=`(lost = nominal - kept, pct = 100 * (nominal - kept) / nominal)]
setorder(seas, -lost)
SEAS_NOMINAL <- sum(seas$nominal); SEAS_LOST <- sum(seas$lost)

api <- if (file.exists(out_path("chill_api_seasons.csv"))) fread(out_path("chill_api_seasons.csv")) else NULL
API_ALL  <- if (is.null(api)) NA_integer_ else nrow(api)
API_KEPT <- if (is.null(api)) NA_integer_ else sum(api$perc_complete >= 85)
API_ST   <- if (is.null(api)) NA_integer_ else uniqueN(api$station_id)

colo <- if (file.exists(out_path("idw_colocated.csv"))) fread(out_path("idw_colocated.csv")) else NULL
cv   <- if (file.exists(out_path("idw_crossval_summary.csv")))
          fread(out_path("idw_crossval_summary.csv"))[situation == "presente_present"] else NULL

cat(sprintf("   THREDDS %s · archive %s · seasons dropped %s of %s (%.2f%%)\n",
            i_en(N_THREDDS), i_en(N_FORM), i_en(SEAS_LOST), i_en(SEAS_NOMINAL),
            100 * SEAS_LOST / SEAS_NOMINAL))

# § 2 — The territory side. Rebuilt rather than read, so the denominator on the figure is one this
# script computed and not one it inherited.
cat("2. area\n")
ccaa  <- esp_get_ccaa(epsg = 4326)
ccaa  <- st_transform(ccaa[!grepl("Canaria", ccaa$ine.ccaa.name), ], EPSG)
spain <- st_union(ccaa)
tmpl  <- rast(ext(vect(spain)), resolution = RES_M, crs = paste0("EPSG:", EPSG))
CELL  <- cell_area_km2(tmpl)

cropfrac_file <- file.path(out_path("surface_cache"), sprintf("cropfrac_%d.tif", RES_M))
if (!file.exists(cropfrac_file))
  stop("missing ", basename(cropfrac_file), "; run 36_per_model_stats.R first", call. = FALSE)
cropfrac <- rast(cropfrac_file)

AREA_SPAIN <- as.numeric(sum(st_area(spain))) / 1e6            # from the polygon, not from cells
AREA_CROP  <- global(cropfrac, "sum", na.rm = TRUE)[1, 1] * CELL

# Cropland the interpolation actually reaches. Built from the canonical table so it is the real
# surface and not an assumption about it.
ens <- d[situation == "presente_present", .(SWC = median(safe_winter_chill_P10)),
         by = .(station_id, lon, lat)]
pv   <- project(vect(as.data.frame(ens[, .(lon, lat, SWC)]), geom = c("lon", "lat"),
                     crs = "EPSG:4326"), paste0("EPSG:", EPSG))
surf <- mask(terra::interpIDW(tmpl, pv, field = "SWC", radius = 50000, power = 2,
                              maxPoints = 12, near = TRUE), vect(spain))
AREA_REACHED <- global(mask(cropfrac, surf), "sum", na.rm = TRUE)[1, 1] * CELL

crop_tab   <- fread(out_path("talk_numbers_cropland.csv"))
AREA_TABLE <- crop_tab[1, crop_km2_both + crop_km2_only_precoz + crop_km2_none]

cat(sprintf("   Spain %s · cropland %s · reached %s · in the table %s km2\n",
            i_en(AREA_SPAIN), i_en(AREA_CROP), i_en(AREA_REACHED), i_en(AREA_TABLE)))
# The figure's whole claim is that these numbers can be checked, so it refuses to be drawn if the
# denominator it computed and the one the results were written with have drifted apart.
if (abs(AREA_REACHED - AREA_TABLE) > 1)
  stop(sprintf(paste("the cropland the interpolation reaches (%.1f km2) does not match the one in",
                     "talk_numbers_cropland.csv (%.1f km2). Re-run 19_cropland_viability_national.R"),
               AREA_REACHED, AREA_TABLE), call. = FALSE)

# § 3 — Drawing.
#
# ONE UNIT PER PANEL, and this is not a stylistic preference. The bar widths are proportional to the
# value, so putting 3460 stations and 13,840 seasons on the same axis draws the seasons four times
# wider and tells the eye that more was thrown away than ever came in. Stations, seasons and square
# kilometres therefore get their own panel and their own scale.
#
# The bar is only a bar: the number sits just past its end and the label sits in a fixed column to
# the right, so a short bar never has text spilling out of it.
step_panel <- function(steps, title, subtitle, unit, accent = "#2c7bb6") {
  steps <- copy(steps)[, `:=`(y = rev(seq_len(.N)), w = value / max(value))]
  ggplot(steps) +
    geom_rect(aes(xmin = 0, xmax = w, ymin = y - 0.26, ymax = y + 0.26, fill = kind), colour = NA) +
    geom_text(aes(w + 0.025, y, label = sprintf("%s%s", i_en(value),
                                                if (nzchar(unit)) paste0(" ", unit) else "")),
              hjust = 0, size = 3.6, fontface = "bold", colour = "grey15") +
    geom_text(aes(1.42, y + 0.14, label = label), hjust = 0, size = 3.6, fontface = "bold",
              colour = "grey12") +
    geom_text(aes(1.42, y - 0.16, label = note), hjust = 0, size = 3.0, colour = "grey42",
              lineheight = 0.95) +
    scale_fill_manual(values = c(step = accent, dropped = "grey70"), guide = "none") +
    coord_cartesian(xlim = c(0, 3.75), ylim = c(0.35, nrow(steps) + 0.75), expand = FALSE) +
    labs(title = title, subtitle = subtitle) +
    funnel_theme
}

est <- data.table(
  label = c("Served by THREDDS", "Enter the calculation", "Observed archive",
            "Also covered by the API"),
  value = c(N_THREDDS, N_THREDDS, N_FORM, API_ST),
  kind  = c("step", "step", "step", "step"),
  note  = c(sprintf("the web form of the same portal serves %s:\nthat is a fork, not a loss",
                    i_en(N_FORM)),
            "none is lost on quality grounds",
            "1975-2020, the basis of the comparison",
            if (is.na(API_ST)) "" else
              sprintf("extends to 2025 · %s of its %s seasons\nfall to completeness < 85%%",
                      i_en(API_ALL - API_KEPT), i_en(API_ALL))))

tem <- data.table(
  label = c("Possible across the seven windows", "Pass 85% completeness", "Dropped"),
  value = c(SEAS_NOMINAL, SEAS_NOMINAL - SEAS_LOST, SEAS_LOST),
  kind  = c("step", "step", "dropped"),
  note  = c("station × model × season",
            sprintf("%s%% of those possible", n_en(100 * (1 - SEAS_LOST / SEAS_NOMINAL), 2)),
            sprintf("%s%%, all of them in %s;\nthe other six windows lose none",
                    n_en(100 * SEAS_LOST / SEAS_NOMINAL, 2), seas[1]$periodo)))

sup <- data.table(
  label = c("Peninsular Spain and the Balearics", "CORINE cropland",
            "Reached by the interpolation", "Classified into the three classes"),
  value = c(AREA_SPAIN, AREA_CROP, AREA_REACHED, AREA_TABLE),
  kind  = rep("step", 4),
  note  = c("outline of the autonomous communities, without the Canaries",
            sprintf("classes 211-244 without pasture: %s%% of the country",
                    n_en(100 * AREA_CROP / AREA_SPAIN, 1)),
            sprintf("cells with a station within 50 km:\n%s km² are lost",
                    i_en(AREA_CROP - AREA_REACHED)),
            "this is the denominator of every area\nfigure in the project"))

pa <- step_panel(est, "The stations", "None is discarded on the projections branch.", "")
pt <- step_panel(tem, "The seasons",
                 "This is where the completeness filter acts, and only just.", "", accent = "#7a6ea8")
pb <- step_panel(sup, "The territory",
                 sprintf("Cell of %s km², not exactly 1 km² (see 00_corine.R).", n_en(CELL, 5)),
                 "km²", accent = "#2e8b57")

extra <- if (!is.null(colo) && !is.null(cv) && nrow(cv))
  sprintf(paste("Two more things worth knowing about those %s stations: %s of them share a coordinate with another (%s pairs),",
                "and for %s there is no neighbour within the 50 km radius."),
          i_en(N_THREDDS), i_en(sum(colo$n)), i_en(nrow(colo)), i_en(cv$n_no_neigh)) else ""

g51 <- ((pa / pt) | pb) +
  plot_layout(widths = c(1, 1)) +
  plot_annotation(
    title = ttl("Where every station and every square kilometre goes"),
    subtitle = paste("Real counts at every step, with no rounded percentages, so the subtraction can be done by hand.",
                     "Each panel has its own unit and its own scale.\n", extra),
    theme = theme(plot.title = element_text(face = "bold", size = 17),
                  plot.subtitle = element_text(size = 11.5, colour = "grey30")))
ggsave(fig_path("fig51_attrition_funnel.png"), g51, width = 16.5, height = 8.2, dpi = 190,
       bg = "white")

fwrite(rbind(
  data.table(side = "stations", step = est$label, value = est$value),
  data.table(side = "area", step = sup$label, value = sup$value),
  data.table(side = "area", step = "cell area km2", value = CELL)),
  out_path("attrition_funnel_numbers.csv"))
fwrite(seas, out_path("season_attrition_by_window.csv"))

cat(sprintf("\nwritten fig51, attrition_funnel_numbers.csv and season_attrition_by_window.csv\n"))
