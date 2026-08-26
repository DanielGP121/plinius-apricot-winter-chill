#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------------------
# Animation frames: how cultivar viability over Spanish cropland evolves through the century
# under each emission scenario.
#
# Same chain as 19_cropland_viability_national.R (IDW at 50 km, CORINE cropland mask, three
# viability classes), but rendered for animation rather than for a static page. Three things
# change, and each of them exists because an animation can lie in ways a static map cannot:
#
#   - the colour scale, the map extent and the panel geometry are computed once and held fixed
#     across every frame, so movement on screen is movement in the data and nothing else;
#   - every frame carries a timeline strip marking which window is showing, because a viewer who
#     joins mid-loop has no other way of knowing;
#   - the baseline frame comes from the MODEL baseline (1995-2020), not from the observations.
#     Opening on the observed surface and continuing with modelled futures would put a change of
#     data source in the first transition, and it would read as climate.
#
# No frames are interpolated between windows. A crossfade between 2040 and 2070 would draw states
# the data never produced, and at this size it is indistinguishable from a measurement.
#
# Outputs (02_outputs/gif_frames/): PNG frames plus frames_manifest.csv, which tells
# 32_make_gifs.py which frames make up which animation and how long each one is held.
#
# Usage: Rscript 31_scenario_frames.R [--res 1000] [--quick]
#   --quick  2 km cells and only SSP3-7.0, to check the chain end to end in a couple of minutes
# Requires: terra, sf, mapSpain, ggplot2, viridis, data.table, patchwork. CORINE under PLINIUS_DATA.
# ---------------------------------------------------------------------------------------

suppressWarnings(suppressMessages({
  library(terra); library(sf); library(mapSpain); library(ggplot2); library(viridis)
  library(data.table); library(patchwork)
}))

args   <- commandArgs(trailingOnly = TRUE)
getarg <- function(f, d) { i <- which(args == f); if (length(i)) args[i + 1] else d }
QUICK  <- "--quick" %in% args
RES_M  <- as.numeric(getarg("--res", if (QUICK) 2000 else 1000))

.f <- grep("^--file=", commandArgs(FALSE), value = TRUE)
.dir <- if (length(.f)) dirname(normalizePath(sub("^--file=", "", .f[1]))) else getwd()
source(file.path(.dir, "00_paths.R"))
source(file.path(.dir, "00_corine.R"))
source(file.path(.dir, "00_hatch.R"))

# Model agreement is drawn on top of every map, following the AR6 convention: colour where at least
# 80 % of the models place a cell on the same side of the requirement, diagonal lines where they do
# not. Without it the ensemble median produces a map far crisper than the models support, and the
# 2021-2040 frame in particular invites a reading of the three panels that the data cannot carry.
# Set PLINIUS_NO_HATCH=TRUE for the older, cleaner maps.
HATCH <- !toupper(Sys.getenv("PLINIUS_NO_HATCH", "FALSE")) %in% c("TRUE", "1", "YES")
AGREE_FRAC <- 0.8
AGREE_DIR <- out_path("model_agreement")

EPSG       <- 3035
CR_B       <- 47.5                      # 'Búlida'        chill requirement (Ruiz et al. 2019)
CR_P       <- 33.7                      # 'Búlida Precoz' chill requirement (Ruiz et al. 2019)
IDW_RADIUS <- 50000                     # 50 km mask, Egea et al. 2022
IDW_POWER  <- 2
IDW_NMAX   <- 12

LAB <- c("Both cultivars", "Only 'Búlida Precoz'", "Neither")
COL <- c("#2c7bb6", "#fdae61", "#d7191c")

# IPCC AR6 scenario colours, so the three panels are recognisable to anyone who has seen an AR6
# figure. Held in one place because they are used by the map titles, the timeline and the deck.
SSP_COL <- c(ssp126 = "#173C66", ssp245 = "#F79420", ssp370 = "#E71D25")
SSP_LAB <- c(ssp126 = "SSP1-2.6", ssp245 = "SSP2-4.5", ssp370 = "SSP3-7.0")

# The four steps of the animation. The baseline is shared by the three scenarios: CMIP6 runs do not
# diverge until after it, so showing three different starting maps would invent a difference.
STEPS <- data.table(
  step   = 1:4,
  window = c("present", "nearterm", "near", "far"),
  period = c("1995-2020", "2021-2040", "2041-2070", "2071-2100"),
  kind   = c("base", "futuro", "futuro", "futuro"))

FRAME_DIR <- out_path("gif_frames")
dir.create(FRAME_DIR, showWarnings = FALSE, recursive = TRUE)

# § 1 — Station chill, collapsed to the ensemble median per station and situation.
cat("1. reading chill per station\n")
d <- fread(out_path("chill_all_windows.csv"))
stopifnot(!anyNA(d$safe_winter_chill_P10), is.numeric(d$lon))
ens <- d[, .(SWC = median(safe_winter_chill_P10)),
         by = .(situation, scenario, window, station_id, lon, lat)]

scen_list <- if (QUICK) "ssp370" else c("ssp126", "ssp245", "ssp370")
sits <- c(base = "presente_present",
          setNames(paste0(rep(scen_list, each = 3), "_", c("nearterm", "near", "far")),
                   paste0(rep(scen_list, each = 3), "_", c("nearterm", "near", "far"))))
missing <- setdiff(sits, unique(ens$situation))
if (length(missing)) stop("missing situations in chill_all_windows.csv: ", paste(missing, collapse = ", "))
cat(sprintf("   %d surfaces to interpolate, %.0f m cell\n", length(sits), RES_M))

# § 2 — Country outline, 1 km template and the cropland fraction of every cell.
# Identical to 19_cropland_viability_national.R; the area statistics printed on the frames have to
# match talk_numbers_cropland.csv exactly or the animation contradicts the slide next to it.
cat("2. template, outline and cropland\n")
ccaa  <- esp_get_ccaa(epsg = 4326)
ccaa  <- st_transform(ccaa[!grepl("Canaria", ccaa$ine.ccaa.name), ], EPSG)
spain <- st_union(ccaa)
tmpl  <- rast(ext(vect(spain)), resolution = RES_M, crs = paste0("EPSG:", EPSG))

# Display extent, deliberately not the analysis extent. Ceuta and Melilla are Spanish and stay in
# every statistic, but they sit 300 km south of the peninsula, and a frame stretched to reach them
# spends a third of its height on empty sea. They hold no CORINE cropland whatsoever (measured:
# 0.00 km2), so restricting what is DRAWN to the peninsula and the Balearics hides nothing. The
# template, and therefore every km2 reported, is untouched.
disp   <- ccaa[!ccaa$ine.ccaa.name %in% c("Ceuta", "Melilla"), ]
DISP_E <- ext(vect(st_union(disp)))
PAD    <- 0.02 * (DISP_E$xmax - DISP_E$xmin)
XLIM   <- c(DISP_E$xmin - PAD, DISP_E$xmax + PAD)
YLIM   <- c(DISP_E$ymin - PAD, DISP_E$ymax + PAD)
MAP_AR <- diff(YLIM) / diff(XLIM)

clc   <- rast(plinius_clc())
clc_c <- crop(clc, ext(project(vect(spain), crs(clc))))
isc   <- corine_crop_mask(clc_c)
cropfrac <- mask(resample(isc, tmpl, method = "average"), vect(spain))
cell_km2 <- cell_area_km2(cropfrac)   # not (RES_M/1000)^2; see 00_corine.R
total_crop_km2 <- global(cropfrac, "sum", na.rm = TRUE)[1, 1] * cell_km2
if (!is.finite(total_crop_km2) || total_crop_km2 < 1e4)
  stop(sprintf("cropland mask selected %.0f km2, which cannot be right", total_crop_km2))
cat(sprintf("   national cropland area: %.0f km2\n", total_crop_km2))

# § 3 — One IDW surface per situation, classified into the three viability classes.
# The classified rasters are turned into data frames here, once, because ggplot needs them in that
# form and re-converting inside the frame loop would dominate the runtime.
classify_cell <- function(swc) ifel(swc >= CR_B, 1L, ifel(swc >= CR_P, 2L, 3L))

panels <- list(); stats <- list(); surfaces <- list()
for (s in unique(sits)) {
  cat(sprintf("3. interpolating %s\n", s))
  p  <- ens[situation == s]
  pv <- project(vect(as.data.frame(p[, .(lon, lat, SWC)]), geom = c("lon", "lat"), crs = "EPSG:4326"),
                paste0("EPSG:", EPSG))
  surf <- mask(interpIDW(tmpl, pv, field = "SWC", radius = IDW_RADIUS, power = IDW_POWER,
                         maxPoints = IDW_NMAX, near = TRUE), vect(spain))
  cls  <- mask(classify_cell(surf), cropfrac > 0, maskvalues = c(0, NA))

  km2 <- sapply(1:3, function(k)
    global(mask(cropfrac, cls == k, maskvalues = c(0, NA)), "sum", na.rm = TRUE)[1, 1] * cell_km2)
  km2[is.na(km2)] <- 0

  df <- as.data.frame(cls, xy = TRUE, na.rm = TRUE); names(df)[3] <- "cls"
  df$clase <- factor(LAB[df$cls], levels = LAB)
  panels[[s]] <- df
  surfaces[[s]] <- as.data.frame(surf, xy = TRUE, na.rm = TRUE) |> setNames(c("x", "y", "SWC"))
  stats[[s]] <- data.table(situation = s, km2_both = km2[1], km2_only = km2[2], km2_none = km2[3])
  cat(sprintf("   both %.0f km2 | only Precoz %.0f km2 | neither %.0f km2\n", km2[1], km2[2], km2[3]))
}
ST <- rbindlist(stats)

# The colour scale of the SWC surfaces has to span every frame, not each frame's own range, or the
# same colour would mean a different amount of chill depending on the year showing.
SWC_LIM <- range(unlist(lapply(surfaces, function(z) range(z$SWC, na.rm = TRUE))), na.rm = TRUE)

# § 4 — Frame composition.
# A frame is a map, a timeline strip and a statistics line. The timeline is drawn rather than
# written because a viewer reads a filled bar faster than a date, and the loop gives them under two
# seconds to place themselves in the century.
map_theme <- theme_minimal(base_size = 13) +
  theme(panel.grid = element_blank(), axis.text = element_blank(), axis.title = element_blank(),
        axis.ticks = element_blank(), legend.position = "none",
        plot.title = element_text(face = "bold", size = 15),
        plot.subtitle = element_text(size = 12, colour = "grey30"),
        plot.margin = margin(4, 4, 2, 4))

# Hatching is built once per situation and reused by every frame that draws it, because clipping
# the diagonals to the disagreement polygon is the slowest step in the whole script.
hatch_cache <- new.env(parent = emptyenv())
hatch_for <- function(sit) {
  if (!HATCH) return(list())
  if (!is.null(hatch_cache[[sit]])) return(hatch_cache[[sit]]$v)
  # The agreement layers are written at the resolution 36_per_model_stats.R ran at, normally 1 km.
  # A --quick run at 2 km would otherwise find nothing and silently drop the hatching, so any
  # available resolution is accepted and resampled. Hatching is coarsened to 4 km before it is
  # drawn anyway, so the source resolution makes no visible difference.
  f <- file.path(AGREE_DIR, sprintf("%s_%d.tif", sit, RES_M))
  if (!file.exists(f)) {
    alt <- list.files(AGREE_DIR, pattern = sprintf("^%s_[0-9]+\\.tif$", sit), full.names = TRUE)
    f <- if (length(alt)) alt[1] else f
  }
  v <- if (!file.exists(f)) {
    message("no agreement layer for ", sit, "; run 36_per_model_stats.R")
    list()
  } else {
    ag <- rast(f)
    if (!compareGeom(ag, tmpl, stopOnError = FALSE)) ag <- resample(ag, tmpl, method = "near")
    nm <- length(unique(d[situation == sit & model != "obs"]$model))
    agreement_bands(ag[["n_below_bulida"]], nm, restrict = cropfrac)
  }
  hatch_cache[[sit]] <- list(v = v)
  v
}

map_panel <- function(sit, title, subtitle) {
  ggplot() +
    geom_raster(data = panels[[sit]], aes(x, y, fill = clase)) +
    geom_agreement(hatch_for(sit)) +
    geom_sf(data = disp, fill = NA, colour = "grey55", linewidth = 0.15) +
    coord_sf(crs = EPSG, datum = NA, expand = FALSE, xlim = XLIM, ylim = YLIM) +
    scale_fill_manual(values = setNames(COL, LAB), drop = FALSE, name = NULL) +
    labs(title = title, subtitle = subtitle) + map_theme
}

timeline <- function(active, accent = "grey20") {
  dt <- copy(STEPS)[, `:=`(xmin = step - 1, xmax = step - 0.08,
                           on = step == active)]
  ggplot(dt) +
    geom_rect(aes(xmin = xmin, xmax = xmax, ymin = 0, ymax = 1, fill = on), colour = NA) +
    geom_text(aes(x = (xmin + xmax) / 2, y = 0.5, label = period,
                  colour = on, fontface = ifelse(dt$on, "bold", "plain")), size = 3.9) +
    scale_fill_manual(values = c(`FALSE` = "grey92", `TRUE` = accent), guide = "none") +
    scale_colour_manual(values = c(`FALSE` = "grey45", `TRUE` = "white"), guide = "none") +
    coord_cartesian(xlim = c(0, 4), ylim = c(0, 1), expand = FALSE) +
    theme_void() + theme(plot.margin = margin(2, 4, 4, 4))
}

# The legend is built by hand so it can sit in a fixed place in every frame. ggplot's own legend
# would be positioned relative to the panel and would shift by a few pixels between frames, which
# on a loop looks like a flicker.
legend_strip <- function() {
  # Positions are spaced by hand. The strip is reused by frames of different widths, so the same
  # data coordinates land at different physical sizes; the gaps below are set for the narrowest
  # frame, where the labels are closest to touching.
  CX <- c(0.9, 3.9, 6.9)
  dt <- data.table(x = CX, lab = factor(LAB, levels = LAB))
  g <- ggplot(dt) +
    geom_point(aes(x, 1, colour = lab), size = 4.6, shape = 15) +
    geom_text(aes(x + 0.10, 1, label = lab), hjust = 0, size = 3.6, colour = "grey20") +
    scale_colour_manual(values = setNames(COL, LAB), guide = "none")
  # The hatching legend is drawn as samples of the real texture rather than described in words,
  # because a viewer matches a texture against the map far faster than they reconstruct it from a
  # sentence. The items come from hatch_legend_items(), so the strip follows the hatching mode
  # without this file knowing which mode is active.
  items <- if (HATCH) hatch_legend_items() else list()
  if (length(items)) {
    sw <- function(x0, gap, col, cross) {
      xs <- seq(x0, x0 + 0.25, by = gap)
      a <- data.table(x = xs, xend = xs + 0.09, y = 0.955, yend = 1.045)
      out <- list(geom_segment(data = a, aes(x, y, xend = xend, yend = yend),
                               colour = col, linewidth = 0.5))
      if (cross) out <- c(out, list(geom_segment(data = a, aes(x = xend, y = y, xend = x, yend = yend),
                                                 colour = col, linewidth = 0.5)))
      out
    }
    x0 <- 9.5
    for (it in items) {
      g <- g + sw(x0, it$gap, it$col, it$cross) +
        annotate("text", x = x0 + 0.36, y = 1, hjust = 0, size = 3.4, colour = "grey35",
                 label = it$lab)
      x0 <- x0 + 3.5
    }
    LEG_XMAX <- x0 + 0.7   # slack for the longest label, which is the plain-mode one
  } else LEG_XMAX <- 9.0
  g + coord_cartesian(xlim = c(0.8, LEG_XMAX), ylim = c(0.9, 1.1), expand = FALSE) +
    theme_void() + theme(plot.margin = margin(2, 4, 2, 4))
}

stat_line <- function(sit) {
  r <- ST[situation == sit]
  ggplot() +
    annotate("text", x = 0, y = 1, hjust = 0, size = 4.1, colour = "grey20",
             label = sprintf("Only 'Búlida Precoz': %s km²      Neither: %s km²",
                             km2_fmt(r$km2_only), km2_fmt(r$km2_none))) +
    coord_cartesian(xlim = c(0, 10), ylim = c(0.9, 1.1), expand = FALSE) +
    theme_void() + theme(plot.margin = margin(2, 4, 2, 4))
}

sit_of <- function(scen, step) if (step == 1) "presente_present" else
  paste0(scen, "_", STEPS$window[step])

# Strips are pinned to absolute heights; the map takes whatever is left. With purely relative
# heights the strips would grow with the canvas and the layout would drift between animations.
STRIP_IN  <- c(legend = 0.30, stat = 0.26, timeline = 0.42)
FRAME_W   <- 8.2    # inches, one scenario
PANEL_W   <- 5.2    # inches, one panel of the side-by-side
TITLE_IN  <- 0.72   # room the title and subtitle take above the map
strip_layout <- function(...) plot_layout(heights = unit(c(1, ...), c("null", rep("in", length(c(...))))))

# English thousands separator. formatC rather than format, which warns when the big mark and the
# decimal mark are both a full stop even though these are integers and no decimal is ever printed.
km2_fmt <- function(x) formatC(round(x), format = "d", big.mark = ",")

# § 5 — One animation per scenario.
# The caption on step 2 is not decoration. At 2021-2040 the three scenarios differ by 0.26 CP at the
# median station while the eleven models span 7.13, so a viewer watching three panels move apart
# there would be reading model noise as policy. Saying it on the frame costs nothing.
manifest <- list()
frame_file <- function(tag, i) file.path(FRAME_DIR, sprintf("%s_%02d.png", tag, i))

for (scen in scen_list) {
  for (i in 1:4) {
    sit <- sit_of(scen, i)
    sub <- if (i == 1) "Model baseline, shared by the three scenarios"
           else if (i == 2) "At this horizon the three scenarios are not yet distinguishable"
           else sprintf("Median of the 11 CMIP6 models")
    g <- map_panel(sit, sprintf("%s · %s", SSP_LAB[[scen]], STEPS$period[i]), sub) /
         legend_strip() / stat_line(sit) / timeline(i, SSP_COL[[scen]]) +
         strip_layout(STRIP_IN[["legend"]], STRIP_IN[["stat"]], STRIP_IN[["timeline"]])
    ggsave(frame_file(scen, i), g, width = FRAME_W,
           height = FRAME_W * MAP_AR + sum(STRIP_IN) + TITLE_IN, dpi = 132, bg = "white")
    manifest[[length(manifest) + 1]] <- data.table(
      anim = scen, step = i, file = basename(frame_file(scen, i)),
      duration_ms = c(1800, 1400, 1400, 2500)[i])
  }
  cat(sprintf("5. frames for %s written\n", SSP_LAB[[scen]]))
}

# § 6 — The three scenarios side by side, advancing together.
# This is the frame that answers the question the talk asks, because the difference between panels
# at 2071-2100 is the whole result: the same land, three futures.
for (i in 1:4) {
  maps <- lapply(scen_list, function(scen)
    map_panel(sit_of(scen, i), SSP_LAB[[scen]],
              sprintf("only 'Búlida Precoz': %s km²",
                      km2_fmt(ST[situation == sit_of(scen, i)]$km2_only))))
  # At 2021-2040 the panels differ, and one of the differences runs the wrong way: SSP3-7.0 loses
  # LESS land than SSP2-4.5. That is not a scenario effect and it is not a mistake either, it is
  # the ensemble median of eleven models that disagree far more with each other than the scenarios
  # do. The frame says so, because a viewer comparing three panels will otherwise read the ranking
  # as a result, and the question arrives before the speaker gets to it.
  note <- if (i == 2)
    paste("Differences between panels at this horizon are not a scenario effect:",
          "the models disagree with each other far more than the scenarios do") else ""
  head <- ggplot() +
    annotate("text", x = 0, y = 1.06, hjust = 0, size = 6.2, fontface = "bold", colour = "grey15",
             label = sprintf("Viable cropland · %s", STEPS$period[i])) +
    annotate("text", x = 0, y = 0.94, hjust = 0, size = 3.9, colour = "#b2182b", label = note) +
    coord_cartesian(xlim = c(0, 10), ylim = c(0.88, 1.12), expand = FALSE) +
    theme_void() + theme(plot.margin = margin(6, 4, 0, 4))
  # Canvas width follows the number of scenarios drawn, so --quick does not leave one map floating
  # in a frame sized for three.
  HEAD_IN <- 0.62      # room for the title plus the caveat line under it
  g <- head / wrap_plots(maps, nrow = 1) / legend_strip() / timeline(i) +
       plot_layout(heights = unit(c(HEAD_IN, 1, STRIP_IN[["legend"]], STRIP_IN[["timeline"]]),
                                  c("in", "null", "in", "in")))
  ggsave(frame_file("sidebyside", i), g, width = PANEL_W * length(scen_list) + 0.3,
         height = PANEL_W * MAP_AR + HEAD_IN + STRIP_IN[["legend"]] + STRIP_IN[["timeline"]] + TITLE_IN,
         dpi = 132, bg = "white")
  manifest[[length(manifest) + 1]] <- data.table(
    anim = "sidebyside", step = i, file = basename(frame_file("sidebyside", i)),
    duration_ms = c(2000, 1500, 1500, 2800)[i])
}
cat("6. side-by-side frames written\n")

# § 7 — The continuous chill surface, same four steps, pooled scenarios aside.
# Kept for the annex: the classified map answers the question, but the surface behind it is what
# shows that the classes are the product of a gradient and not of a threshold drawn on a whim.
for (scen in scen_list) {
  for (i in 1:4) {
    sit <- sit_of(scen, i)
    g <- ggplot() +
      geom_raster(data = surfaces[[sit]], aes(x, y, fill = SWC)) +
      geom_sf(data = disp, fill = NA, colour = "grey55", linewidth = 0.15) +
      coord_sf(crs = EPSG, datum = NA, expand = FALSE, xlim = XLIM, ylim = YLIM) +
      scale_fill_viridis_c(name = "Chill portions (P10)", limits = SWC_LIM, option = "viridis") +
      labs(title = sprintf("Safe Winter Chill · %s · %s", SSP_LAB[[scen]], STEPS$period[i])) +
      map_theme + theme(legend.position = "bottom", legend.key.width = unit(2.2, "cm"))
    g <- g / timeline(i, SSP_COL[[scen]]) + strip_layout(STRIP_IN[["timeline"]])
    ggsave(frame_file(paste0("swc_", scen), i), g, width = FRAME_W,
           height = FRAME_W * MAP_AR + STRIP_IN[["timeline"]] + TITLE_IN + 0.75,  # 0.75: bottom colourbar
           dpi = 132, bg = "white")
    manifest[[length(manifest) + 1]] <- data.table(
      anim = paste0("swc_", scen), step = i, file = basename(frame_file(paste0("swc_", scen), i)),
      duration_ms = c(1800, 1400, 1400, 2500)[i])
  }
}
cat("7. SWC surface frames written\n")

MAN <- rbindlist(manifest)[order(anim, step)]
fwrite(MAN, file.path(FRAME_DIR, "frames_manifest.csv"))
fwrite(ST,  out_path("gif_frame_stats.csv"))

cat(sprintf("\nwrote %d frames in %s\n", nrow(MAN), FRAME_DIR))
cat(sprintf("%d animations: %s\n", uniqueN(MAN$anim), paste(unique(MAN$anim), collapse = ", ")))
cat("next: python 32_make_gifs.py\n")
