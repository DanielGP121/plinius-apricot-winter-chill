#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------------------
# Observed winter chill 1995-2025, by splicing the PNACC archive to the AEMET API record.
#
# The archive stops in 2020 and the API record starts thin but reaches 2025, so neither covers the
# period on its own. Script 41 established that on the seasons they share the two agree to +0.13 CP
# in Safe Winter Chill with a spatial correlation of 0.987, which is what licenses joining them.
#
# The join is deliberately asymmetric: the archive supplies every season up to 2020 and the API only
# the 2021-2025 extension. The archive is complete (26 of 26 seasons for all 3044 stations) and
# quality controlled, so there is no reason to let the thinner source overwrite any of it. The API
# is used strictly for the years the archive cannot reach.
#
# What this answers: whether the last five winters move the observed baseline, and by how much. The
# model's own answer was about -0.1 CP (73.0 CP over 1995-2020 against 72.9 over 1995-2025), so an
# observed record that says something markedly different would be worth knowing before the talk.
#
# Everything is reported twice, over all stations and over the subset that passed the agreement
# check of script 41 (mean absolute error <= 3 CP), so the conclusion can be seen not to depend on
# where that line was drawn.
#
# Outputs: observed_spliced_swc.csv, observed_spliced_summary.csv and fig24_01.
#
# Usage:
#   Rscript 58_splice_observed_1995_2025.R
#   Rscript 58_splice_observed_1995_2025.R --min-recent 4 --max-mae 3
#
# Requires: data.table, ggplot2.
# ---------------------------------------------------------------------------------------

suppressWarnings(suppressMessages({
  library(data.table); library(ggplot2)
}))
setDTthreads(1)

args <- commandArgs(trailingOnly = TRUE)
# A flag given as the last argument used to yield NA instead of its value, which for --maxst
# turned an intended smoke test into the full run writing to production paths.
getarg <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (!length(i)) return(default)
  if (i[1] >= length(args)) stop(sprintf("%s needs a value after it", flag), call. = FALSE)
  args[i[1] + 1]
}

# Paths come from 00_paths.R: it derives the repository root from its own location, so these
# defaults no longer depend on the script being launched from inside 01_scripts/.
.f <- grep("^--file=", commandArgs(FALSE), value = TRUE)
source(file.path(if (length(.f)) dirname(normalizePath(sub("^--file=", "", .f[1]))) else getwd(), "00_paths.R"))

ARCH   <- getarg("--archive",  out_path("chill_obs_seasons.csv"))
APIF   <- getarg("--api",      out_path("chill_api_seasons.csv"))
AGREE  <- getarg("--agreement",out_path("api_vs_archive_by_station.csv"))
OUTDIR <- getarg("--outdir",   OUT_DIR)
FIGDIR <- getarg("--figdir",   FIG_DIR)

MIN_PERC   <- as.numeric(getarg("--min-perc", 85))
MAX_MAE    <- as.numeric(getarg("--max-mae", 3))     # station agreement threshold from script 41
MIN_RECENT <- as.integer(getarg("--min-recent", 3))  # recent seasons a station must add to count
SPLIT_YEAR <- 2020L                                  # last season the archive provides
LAST_YEAR  <- 2025L                                  # last season the API can complete
MODEL_SHIFT <- -0.1   # what the model said the same extension does, as a yardstick

# --- § 1 - the two season tables ---------------------------------------------------------------
load_seasons <- function(path, tag) {
  if (!file.exists(path)) stop(sprintf("missing %s table at %s", tag, path))
  d <- fread(path, colClasses = list(character = "station_id"))
  d[perc_complete >= MIN_PERC, .(station_id, lon, lat, season_end_year, CP)]
}

arch <- load_seasons(ARCH, "archive")
api  <- load_seasons(APIF, "API")

# The 2026 season an API run produces is only November and December of 2025 and never clears the
# completeness filter, but the bound is stated rather than assumed: a later download would silently
# extend the window otherwise.
recent <- api[season_end_year > SPLIT_YEAR & season_end_year <= LAST_YEAR]
past   <- arch[season_end_year <= SPLIT_YEAR]

cat(sprintf("archive to %d : %d seasons, %d stations\n", SPLIT_YEAR, nrow(past), uniqueN(past$station_id)))
cat(sprintf("API %d-%d   : %d seasons, %d stations\n", SPLIT_YEAR + 1L, LAST_YEAR,
            nrow(recent), uniqueN(recent$station_id)))

# --- § 2 - splice --------------------------------------------------------------------------------
# Only stations the API can actually extend are spliced; the rest keep the archive record and are
# reported separately, because a "1995-2025" value built from a series that stops in 2020 would be
# a mislabelled 1995-2020 value.
ids <- intersect(unique(past$station_id), unique(recent$station_id))
cat(sprintf("spliceable stations: %d\n", length(ids)))

spliced <- rbindlist(list(past[station_id %in% ids][, src := "archive"],
                          recent[station_id %in% ids][, src := "api"]))
setorder(spliced, station_id, season_end_year)

n_recent <- recent[station_id %in% ids, .(n_recent = .N), by = station_id]
cat("\nrecent seasons contributed per station:\n")
print(n_recent[, .(estaciones = .N), by = n_recent][order(n_recent)])

# --- § 3 - does the extension move the baseline? -------------------------------------------------
# Safe Winter Chill is the P10 across seasons, so the two windows are computed over the same station
# set and differ only in the five seasons added. This is the number the talk would quote if it
# claimed the observed record now reaches 2025.
swc <- merge(
  spliced[, .(n_all = .N, swc_1995_2025 = as.numeric(quantile(CP, .10, names = FALSE)),
              lon = lon[1], lat = lat[1]), by = station_id],
  past[station_id %in% ids, .(n_past = .N,
       swc_1995_2020 = as.numeric(quantile(CP, .10, names = FALSE))), by = station_id],
  by = "station_id")
swc <- merge(swc, n_recent, by = "station_id")
swc[, d_swc := swc_1995_2025 - swc_1995_2020]

# Mean chill of the recent seasons against the earlier ones. With only five winters a P10 would sit
# on the coldest of them, so the mean is the honest statistic for the recent block itself.
mean_cp <- merge(
  past[station_id %in% ids, .(mean_past = mean(CP)), by = station_id],
  recent[station_id %in% ids, .(mean_recent = mean(CP)), by = station_id], by = "station_id")
mean_cp[, d_mean := mean_recent - mean_past]
swc <- merge(swc, mean_cp, by = "station_id")

# --- § 4 - with and without the stations flagged in script 41 ------------------------------------
if (file.exists(AGREE)) {
  ag <- fread(AGREE, colClasses = list(character = "station_id"))
  if (!"mae" %in% names(ag)) stop("the agreement table has no mae column; re-run script 41")
  swc <- merge(swc, ag[, .(station_id, mae)], by = "station_id", all.x = TRUE)
} else {
  cat(sprintf("\nWARNING: no agreement table at %s, the flagged subset cannot be reported\n", AGREE))
  swc[, mae := NA_real_]
}

report <- function(d, label) {
  if (!nrow(d)) { cat(sprintf("\n%s: no stations\n", label)); return(NULL) }
  cat(sprintf("\n--- %s (n = %d) ---\n", label, nrow(d)))
  cat(sprintf("  SWC 1995-2020 median : %.2f CP\n", median(d$swc_1995_2020)))
  cat(sprintf("  SWC 1995-2025 median : %.2f CP\n", median(d$swc_1995_2025)))
  cat(sprintf("  change               : median %+.2f CP, mean %+.2f (p10 %+.2f, p90 %+.2f)\n",
              median(d$d_swc), mean(d$d_swc), quantile(d$d_swc, .10), quantile(d$d_swc, .90)))
  cat(sprintf("  stations losing chill when 2021-2025 is added: %.1f%%\n", 100 * mean(d$d_swc < 0)))
  cat(sprintf("  mean CP 1996-2020 %.2f  vs  2021-2025 %.2f  -> %+.2f CP\n",
              median(d$mean_past), median(d$mean_recent), median(d$d_mean)))
  invisible(NULL)
}

cat(sprintf("\n=== effect of adding seasons %d-%d ===", SPLIT_YEAR + 1L, LAST_YEAR))
cat(sprintf("\n(reference: the model gave %+.1f CP for the same extension)\n", MODEL_SHIFT))
report(swc, "all spliceable stations")
report(swc[n_recent >= MIN_RECENT], sprintf("with at least %d recent seasons", MIN_RECENT))
report(swc[n_recent >= MIN_RECENT & !is.na(mae) & mae <= MAX_MAE],
       sprintf("plus MAE <= %.0f CP (agreement verified)", MAX_MAE))

# --- § 5 - figure and tables ----------------------------------------------------------------------
dir.create(FIGDIR, showWarnings = FALSE, recursive = TRUE)
old <- list.files(FIGDIR, pattern = "^fig24_", full.names = TRUE)
if (length(old)) { file.remove(old); cat(sprintf("\nremoved %d previous fig24_ figures\n", length(old))) }

core <- swc[n_recent >= MIN_RECENT & !is.na(mae) & mae <= MAX_MAE]
p <- ggplot(core, aes(d_swc)) +
  geom_histogram(bins = 45, fill = "#3182bd", colour = "white", linewidth = .2) +
  geom_vline(xintercept = 0, colour = "grey30", linewidth = .4) +
  geom_vline(xintercept = median(core$d_swc), colour = "#e6550d", linewidth = .7) +
  geom_vline(xintercept = MODEL_SHIFT, colour = "#31a354", linetype = "dashed", linewidth = .6) +
  labs(title = "Effect of extending the observed record from 2020 to 2025",
       subtitle = sprintf("%d stations; median shift %+.2f CP (orange), model expectation %+.1f CP (green dashed)",
                          nrow(core), median(core$d_swc), MODEL_SHIFT),
       x = "Change in Safe Winter Chill, 1995-2025 minus 1995-2020 (chill portions)",
       y = "Stations") +
  theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(), plot.title = element_text(face = "bold", size = 12))
ggsave(file.path(FIGDIR, "fig24_01_swc_shift_1995_2025.png"), p, width = 8, height = 5, dpi = 200)

setcolorder(swc, c("station_id", "lon", "lat", "n_past", "n_recent", "n_all",
                   "swc_1995_2020", "swc_1995_2025", "d_swc", "mean_past", "mean_recent", "d_mean", "mae"))
num <- setdiff(names(swc), c("station_id", "n_past", "n_recent", "n_all"))
swc[, (num) := lapply(.SD, function(x) round(x, 3)), .SDcols = num]
fwrite(swc[order(station_id)], file.path(OUTDIR, "observed_spliced_swc.csv"))

blocks <- list(all = swc, min_recent = swc[n_recent >= MIN_RECENT], core = core)
summary_out <- rbindlist(lapply(names(blocks), function(k) {
  d <- blocks[[k]]
  data.table(subset = k, n_stations = nrow(d),
             swc_1995_2020 = round(median(d$swc_1995_2020), 3),
             swc_1995_2025 = round(median(d$swc_1995_2025), 3),
             d_swc_median = round(median(d$d_swc), 3), d_swc_mean = round(mean(d$d_swc), 3),
             pct_losing = round(100 * mean(d$d_swc < 0), 1),
             d_mean_cp = round(median(d$d_mean), 3))
}))
fwrite(summary_out, file.path(OUTDIR, "observed_spliced_summary.csv"))
cat(sprintf("\nwrote 1 figure to %s and 2 tables to %s\n", FIGDIR, OUTDIR))
print(summary_out)
