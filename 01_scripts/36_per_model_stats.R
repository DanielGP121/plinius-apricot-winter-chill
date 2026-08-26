#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------------------
# The analysis repeated model by model, instead of only on the ensemble median.
#
# Everything else in this project collapses the eleven CMIP6 models to their median before
# interpolating, so every published km2 is a statistic of a surface that no model produced. That is
# a defensible way to draw one map, but it hides two things the talk needs: how far apart the
# models are, and where they actually agree.
#
# This script runs the same chain (IDW at 50 km, CORINE cropland, three viability classes) once per
# model and per situation, and writes:
#
#   per_model_cropland_km2.csv     area by class for each model, the table that was missing behind
#                                  the "32.6 % to 66.1 %" range quoted in the canonical document
#   model_agreement/<sit>.tif      three counters per cell: how many models put it below each
#                                  cultivar requirement, and how many say chill DECREASES from the
#                                  baseline
#   model_agreement_summary.csv    the same, summarised per situation
#
# Two kinds of agreement, kept apart on purpose. They are not the same question and the project has
# been conflating them:
#
#   CLASSIFICATION agreement  do the models agree this cell is below 47.5 CP? Good, and it is what
#                             the viability maps actually draw.
#   SIGN-OF-CHANGE agreement  do the models agree chill goes down from the baseline? Poor at
#                             2021-2040, which is exactly why the near-term scenario comparison
#                             cannot be read, and better by 2071-2100.
#
# Runtime is a few minutes: one IDW surface is under a second, and there are about 150 of them.
#
# Usage: Rscript 36_per_model_stats.R [--res 1000]
# Requires: terra, sf, mapSpain, data.table. CORINE under PLINIUS_DATA.
# ---------------------------------------------------------------------------------------

suppressWarnings(suppressMessages({
  library(terra); library(sf); library(mapSpain); library(data.table)
}))

args   <- commandArgs(trailingOnly = TRUE)
getarg <- function(f, d) { i <- which(args == f); if (length(i)) args[i + 1] else d }
RES_M  <- as.numeric(getarg("--res", 1000))

.f <- grep("^--file=", commandArgs(FALSE), value = TRUE)
.dir <- if (length(.f)) dirname(normalizePath(sub("^--file=", "", .f[1]))) else getwd()
source(file.path(.dir, "00_paths.R"))
source(file.path(.dir, "00_corine.R"))

EPSG <- 3035
CR_B <- 47.5; CR_P <- 33.7
IDW_RADIUS <- 50000; IDW_POWER <- 2; IDW_NMAX <- 12
BASE_SIT <- "presente_present"          # the modelled baseline every change is measured against
AGREE_FRAC <- 0.8                       # AR6 threshold: colour when >= 80 % of models agree

AGREE_DIR <- out_path("model_agreement"); dir.create(AGREE_DIR, showWarnings = FALSE, recursive = TRUE)
CACHE <- out_path("surface_cache")

# § 1 — Geography, cropland and the station table.
cat("1. geography and cropland\n")
d <- fread(out_path("chill_all_windows.csv"))
d <- d[model != "obs"]                  # observational situations carry no ensemble
models <- sort(unique(d$model))
sits <- intersect(c(BASE_SIT, "historical_ref",
                    paste0(rep(c("ssp126", "ssp245", "ssp370"), each = 3), "_",
                           c("nearterm", "near", "far"))),
                  unique(d$situation))
cat(sprintf("   %d models x %d situations = %d surfaces\n",
            length(models), length(sits), length(models) * length(sits)))

ccaa  <- esp_get_ccaa(epsg = 4326)
ccaa  <- st_transform(ccaa[!grepl("Canaria", ccaa$ine.ccaa.name), ], EPSG)
spain <- st_union(ccaa)
tmpl  <- rast(ext(vect(spain)), resolution = RES_M, crs = paste0("EPSG:", EPSG))

cropfrac_file <- file.path(CACHE, sprintf("cropfrac_%d.tif", RES_M))
if (file.exists(cropfrac_file)) {
  cropfrac <- rast(cropfrac_file)
} else {
  clc_c <- crop(rast(plinius_clc()), ext(project(vect(spain), crs(rast(plinius_clc())))))
  cropfrac <- mask(resample(corine_crop_mask(clc_c), tmpl, method = "average"), vect(spain))
  dir.create(CACHE, showWarnings = FALSE, recursive = TRUE)
  writeRaster(cropfrac, cropfrac_file, overwrite = TRUE)
}
cell_km2 <- cell_area_km2(cropfrac)   # not (RES_M/1000)^2; see 00_corine.R
total_crop_km2 <- global(cropfrac, "sum", na.rm = TRUE)[1, 1] * cell_km2
cat(sprintf("   cropland area: %.0f km2\n", total_crop_km2))

surface_of <- function(sit, mdl) {
  p <- d[situation == sit & model == mdl, .(lon, lat, SWC = safe_winter_chill_P10)]
  if (!nrow(p)) return(NULL)
  pv <- project(vect(as.data.frame(p), geom = c("lon", "lat"), crs = "EPSG:4326"),
                paste0("EPSG:", EPSG))
  mask(interpIDW(tmpl, pv, field = "SWC", radius = IDW_RADIUS, power = IDW_POWER,
                 maxPoints = IDW_NMAX, near = TRUE), vect(spain))
}

# § 2 — The eleven baseline surfaces, held once.
# Every sign-of-change counter compares a model against ITSELF in the baseline, never against the
# ensemble. Comparing a model's future to the ensemble's present would count the model's own bias
# as if it were climate change.
cat("2. baselines per model\n")
base_stack <- rast(lapply(models, function(m) surface_of(BASE_SIT, m)))
names(base_stack) <- models

# § 3 — One pass per situation, accumulating areas and agreement counters.
cat("3. surfaces per model\n")
rows <- list(); agg <- list()
for (s in sits) {
  n_below_B <- n_below_P <- n_decr <- rast(tmpl, vals = 0)
  n_have <- 0L
  for (i in seq_along(models)) {
    surf <- surface_of(s, models[i])
    if (is.null(surf)) next
    n_have <- n_have + 1L
    cls <- mask(ifel(surf >= CR_B, 1L, ifel(surf >= CR_P, 2L, 3L)), cropfrac > 0,
                maskvalues = c(0, NA))
    km2 <- sapply(1:3, function(k)
      global(mask(cropfrac, cls == k, maskvalues = c(0, NA)), "sum", na.rm = TRUE)[1, 1] * cell_km2)
    km2[is.na(km2)] <- 0
    rows[[length(rows) + 1]] <- data.table(
      situation = s, model = models[i],
      km2_both = km2[1], km2_only_precoz = km2[2], km2_none = km2[3],
      pct_lost = 100 * (km2[2] + km2[3]) / sum(km2),
      pct_rescued_of_lost = if (km2[2] + km2[3] > 0) 100 * km2[2] / (km2[2] + km2[3]) else NA_real_)

    n_below_B <- n_below_B + ifel(surf < CR_B, 1L, 0L)
    n_below_P <- n_below_P + ifel(surf < CR_P, 1L, 0L)
    n_decr    <- n_decr    + ifel(surf < base_stack[[models[i]]], 1L, 0L)
  }
  ag <- c(n_below_B, n_below_P, n_decr)
  names(ag) <- c("n_below_bulida", "n_below_precoz", "n_decreasing")
  ag <- mask(ag, vect(spain))
  writeRaster(ag, file.path(AGREE_DIR, sprintf("%s_%d.tif", s, RES_M)), overwrite = TRUE)

  # Summaries are taken over CROPLAND only: agreement over bare rock is not a result.
  cm <- mask(ag, cropfrac > 0, maskvalues = c(0, NA))
  v <- as.data.frame(cm, na.rm = TRUE)
  need <- ceiling(AGREE_FRAC * n_have)
  agg[[s]] <- data.table(
    situation = s, n_models = n_have,
    pct_class_agree = 100 * mean(pmax(v$n_below_bulida, n_have - v$n_below_bulida) >= need),
    pct_class_unanimous = 100 * mean(v$n_below_bulida == 0 | v$n_below_bulida == n_have),
    pct_sign_agree = 100 * mean(pmax(v$n_decreasing, n_have - v$n_decreasing) >= need),
    pct_sign_unanimous = 100 * mean(v$n_decreasing == 0 | v$n_decreasing == n_have))
  cat(sprintf("   %-18s %2d models · class agreement %5.1f %% · sign agreement %5.1f %%\n",
              s, n_have, agg[[s]]$pct_class_agree, agg[[s]]$pct_sign_agree))
}

PM <- rbindlist(rows)
AG <- rbindlist(agg)
fwrite(PM, out_path("per_model_cropland_km2.csv"))
fwrite(AG, out_path("model_agreement_summary.csv"))

# § 4 — The range the canonical document quotes, now with a table behind it.
cat("\n4. between-model range of the rescued fraction\n")
for (s in grep("_far$", sits, value = TRUE)) {
  r <- PM[situation == s]
  cat(sprintf("   %-14s %.1f %% to %.1f %%  (ensemble median in talk_numbers: see that table)\n",
              s, min(r$pct_rescued_of_lost), max(r$pct_rescued_of_lost)))
  cat(sprintf("                  lowest: %-14s  highest: %s\n",
              r[which.min(pct_rescued_of_lost)]$model, r[which.max(pct_rescued_of_lost)]$model))
}
cat(sprintf("\nwrote %d rows to per_model_cropland_km2.csv and %d rasters in %s\n",
            nrow(PM), length(sits), AGREE_DIR))
