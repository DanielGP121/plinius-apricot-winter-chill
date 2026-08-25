#!/usr/bin/env Rscript
# Two figures the deck quotes and no table produced.
#
# A verification pass over the methodological deck found both of these asserted in prose with no
# output backing them, which is the failure this project keeps guarding against. Rather than drop
# them, this derives each one from the artefact it should always have come from.
#
# 1. AGREEMENT ON THE NARROW BAND. The maps report agreement on which side of a threshold a cell
#    falls. A harder question is how often the models agree that a cell sits BETWEEN the two
#    requirements, which is the band where the mutant is the answer and the parent is not. That is a
#    13.8 CP target rather than a half-line, so agreement on it is far rarer, and quoting the number
#    without that context is what an earlier version of the project documentation did.
#
#    36_per_model_stats.R already writes, per cell, how many of the eleven models put it below each
#    requirement. A model places a cell in the band exactly when it is below 'Búlida' and not below
#    the mutant, so the count in the band is the difference of the two counters. Agreement uses the
#    same rule as the hatching: at least ceiling(0.8 * n) of the eleven.
#
# 2. THE LENGTH OF THE CIEZA RECORD. The independent orchard series is quoted as continuous over
#    2011-2025. This counts its days and, more to the point, checks that the calendar really has no
#    gap rather than repeating a number from a note.
#
# Usage: Rscript 47_band_and_record_numbers.R
# Writes: 02_outputs/band_agreement_by_situation.csv
#         02_outputs/v3_gap_numbers.csv
# Needs:  02_outputs/model_agreement/*_1000.tif and surface_cache/cropfrac_1000.tif, from
#         36_per_model_stats.R; and the Cieza workbook for the second block, which is skipped with
#         a warning when it is absent.

suppressPackageStartupMessages({
  library(data.table)
  library(terra)
})

.f <- grep("^--file=", commandArgs(FALSE), value = TRUE)
.dir <- if (length(.f)) dirname(normalizePath(sub("^--file=", "", .f[1]))) else getwd()
source(file.path(.dir, "00_paths.R"))
source(file.path(.dir, "00_corine.R"))

RES_M <- 1000
AGREE_FRAC <- 0.8        # the AR6 criterion, same constant as 00_hatch.R and 36_per_model_stats.R

out <- list()

# § 1 — how often the models agree that a cell sits in the mutant's band ---------------------------
agr_dir <- file.path(OUT_DIR, "model_agreement")
crop_path <- file.path(OUT_DIR, "surface_cache", sprintf("cropfrac_%d.tif", RES_M))

if (!dir.exists(agr_dir) || !file.exists(crop_path)) {
  stop("missing ", agr_dir, " or ", crop_path, "\n  run: Rscript 36_per_model_stats.R")
}

cropfrac <- rast(crop_path)
cell_km2 <- cell_area_km2(cropfrac)
total_km2 <- as.numeric(global(cropfrac, "sum", na.rm = TRUE)) * cell_km2

tifs <- sort(list.files(agr_dir, pattern = sprintf("_%d\\.tif$", RES_M), full.names = TRUE))
rows <- rbindlist(lapply(tifs, function(p) {
  sit <- sub(sprintf("_%d\\.tif$", RES_M), "", basename(p))
  r <- rast(p)
  # Layer order is set by 36_per_model_stats.R: below 'Búlida', below the mutant, chill decreasing.
  n_models <- max(as.numeric(global(r[[1]], "max", na.rm = TRUE)),
                  as.numeric(global(r[[2]], "max", na.rm = TRUE)))
  need <- ceiling(AGREE_FRAC * n_models)
  in_band <- r[[1]] - r[[2]]                     # models placing the cell between the two requirements
  agree <- in_band >= need
  km2 <- as.numeric(global(agree * cropfrac, "sum", na.rm = TRUE)) * cell_km2
  data.table(situation = sit, n_models = n_models, need = need,
             km2_band_agreed = km2, pct_band_agreed = 100 * km2 / total_km2)
}))

fwrite(rows, file.path(OUT_DIR, "band_agreement_by_situation.csv"))
cat("band agreement over cropland, at least", unique(rows$need), "of", unique(rows$n_models),
    "models\n")
print(rows[order(pct_band_agreed), .(situation, pct_band_agreed = round(pct_band_agreed, 2))])

out <- c(out, list(
  data.table(metric = "band_agree_min_pct", value = sprintf("%.2f", min(rows$pct_band_agreed))),
  data.table(metric = "band_agree_max_pct", value = sprintf("%.2f", max(rows$pct_band_agreed))),
  data.table(metric = "band_agree_far_pct",
             value = sprintf("%.2f", rows[situation == "ssp370_far", pct_band_agreed])),
  data.table(metric = "band_agree_need", value = as.character(unique(rows$need))),
  data.table(metric = "band_agree_n_situations", value = as.character(nrow(rows)))))

# § 2 — the length of the independent orchard record ----------------------------------------------
# Skipped rather than fatal: the workbook is third-party and is not in the repository, so a clone
# without it should still get the block above.
CIEZA <- plinius_data("cieza_cebas", "Cieza11-25.xlsx")
if (!file.exists(CIEZA)) {
  warning("no Cieza workbook at ", CIEZA, "; the record-length metrics are not written")
} else {
  suppressPackageStartupMessages(library(readxl))
  # Same sheet selection as 27_cieza_independent_check.R: the workbook carries several sheets and
  # only some hold the daily series, so take the largest that has all five columns. The date is
  # built from Year/Month/Day because the workbook has no date column.
  need <- c("Year", "Month", "Day")
  best <- NULL
  for (s in excel_sheets(CIEZA)) {
    x <- suppressMessages(as.data.frame(read_excel(CIEZA, sheet = s)))
    if (!all(c(need, "Tmax", "Tmin") %in% names(x))) next
    x <- x[!is.na(x$Year), ]
    if (is.null(best) || nrow(x) > nrow(best)) best <- x
  }
  if (is.null(best)) stop("no sheet carries Year/Month/Day/Tmax/Tmin")
  d <- best
  dates <- sort(unique(as.Date(sprintf("%d-%02d-%02d", d$Year, d$Month, d$Day))))
  span <- as.integer(diff(range(dates))) + 1L
  cat(sprintf("\nCieza: %d rows, %d distinct days, %s to %s, calendar span %d days, missing %d\n",
              nrow(d), length(dates), min(dates), max(dates), span, span - length(dates)))
  out <- c(out, list(
    data.table(metric = "cieza_days", value = as.character(length(dates))),
    data.table(metric = "cieza_first_day", value = as.character(min(dates))),
    data.table(metric = "cieza_last_day", value = as.character(max(dates))),
    data.table(metric = "cieza_missing_days", value = as.character(span - length(dates)))))
}

fwrite(rbindlist(out), file.path(OUT_DIR, "v3_gap_numbers.csv"))
cat("\nwrote", file.path(OUT_DIR, "v3_gap_numbers.csv"), "and band_agreement_by_situation.csv\n")
