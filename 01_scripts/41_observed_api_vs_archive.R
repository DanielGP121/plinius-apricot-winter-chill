#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------------------
# Are the two observed chill records interchangeable? Paired comparison, season by season.
#
# The project has two observational sources and neither covers the whole period. The PNACC archive
# (script 20 --per-season) has 3044 stations but stops in 2020; the AEMET API record (script 22) runs
# to 2025 but holds 666 stations and is thin before 2008. If they measure the same thing, they can be
# spliced into one observed 1995-2025 series and the record no longer ends five years in the past.
#
# The comparison is PAIRED on (station, season): only seasons that both sources report, with one
# completeness filter applied to both at the same time. Comparing Safe Winter Chill directly would
# not work, because the P10 of a station with 12 seasons sits at its coldest winter while the P10 of
# one with 26 is a genuine decile, so the aggregate difference would partly measure series length.
#
# Three questions are answered, in this order:
#   1. Do the two agree season by season, and how large is the disagreement next to the -0.45 CP
#      model bias the project already accepts as negligible?
#   2. Does the disagreement concentrate in barely-complete seasons? If it does, the fix is a
#      stricter completeness threshold rather than abandoning the splice (--min-perc sweep).
#   3. On the seasons they share, do the two produce the same Safe Winter Chill? That is the number
#      the splice decision rests on, because SWC is what the maps are built from.
#
# Outputs: api_vs_archive_summary.csv, api_vs_archive_by_station.csv and the fig23_* family.
#
# Usage:
#   Rscript 40_observed_api_vs_archive.R
#   Rscript 40_observed_api_vs_archive.R --min-perc 90 --min-seasons 10
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

ARCH    <- getarg("--archive", tab_path("chill_obs_seasons.csv"))
APIF    <- getarg("--api",     tab_path("chill_api_seasons.csv"))
OUTDIR  <- getarg("--outdir",  TAB_DIR)
FIGDIR  <- getarg("--figdir",  FIG_DIR)
MIN_PERC    <- as.numeric(getarg("--min-perc", 85))     # same filter on both sources
MIN_SEASONS <- as.integer(getarg("--min-seasons", 8))   # per-station stats need a few seasons
# A P10 needs enough seasons to be a decile rather than a minimum. Below this the SWC comparison is
# reported but flagged, because at 10 seasons the P10 is the second-coldest winter.
MIN_SWC_SEASONS <- as.integer(getarg("--min-swc-seasons", 15))

REF_MODEL_BIAS <- -0.45   # model vs observed bias already accepted by the project, as a yardstick
# Stations whose two records genuinely disagree are flagged on mean absolute error rather than on
# correlation. Correlation is normalised by variance, so a mild-winter station whose chill barely
# moves between years scores low without being wrong; MAE says how far apart the two sources are in
# chill portions, which is the question. Measured here, the low-correlation group does also carry a
# much larger MAE, so the flag catches real disagreement and not just quiet stations.
MAX_MAE <- as.numeric(getarg("--max-mae", 3))

# --- § 1 - load and pair ---------------------------------------------------------------------
# station_id stays character throughout: 69 ids carry leading zeros and a numeric read would merge
# them, joining the wrong stations to each other without any error surfacing.
load_one <- function(path, tag) {
  if (!file.exists(path)) stop(sprintf("missing %s table at %s", tag, path))
  d <- fread(path, colClasses = list(character = "station_id"))
  need <- c("station_id", "lon", "lat", "season_end_year", "perc_complete", "CP")
  miss <- setdiff(need, names(d))
  if (length(miss)) stop(sprintf("%s table lacks columns: %s", tag, paste(miss, collapse = ", ")))
  d[, .(station_id, lon, lat, season_end_year, perc_complete, CP)]
}

arch <- load_one(ARCH, "archive")
api  <- load_one(APIF, "API")

cat(sprintf("archive : %d rows, %d stations, seasons %d-%d\n", nrow(arch), uniqueN(arch$station_id),
            min(arch$season_end_year), max(arch$season_end_year)))
cat(sprintf("API     : %d rows, %d stations, seasons %d-%d\n", nrow(api), uniqueN(api$station_id),
            min(api$season_end_year), max(api$season_end_year)))

pair_at <- function(min_perc) {
  a <- arch[perc_complete >= min_perc, .(station_id, season_end_year, lon, lat, CP_arch = CP)]
  b <- api[perc_complete >= min_perc, .(station_id, season_end_year, CP_api = CP, pc_api = perc_complete)]
  j <- merge(a, b, by = c("station_id", "season_end_year"))
  j[, d := CP_api - CP_arch]
  j[]
}

j <- pair_at(MIN_PERC)
if (!nrow(j)) stop("no season is reported by both sources at this completeness threshold")
cat(sprintf("\npaired: %d seasons at %d stations (filter %.0f%%), %d-%d\n\n",
            nrow(j), uniqueN(j$station_id), MIN_PERC, min(j$season_end_year), max(j$season_end_year)))

# --- § 2 - agreement, pooled and within station ----------------------------------------------
# Pooled correlation is flattered by geography: a cold station is cold in both sources, so most of
# the shared variance is between stations and not between years. The within-station correlation is
# the one that says whether the API reproduces the archive's year-to-year signal, which is what a
# chill series is for, so both are reported and the second is the one to trust.
pooled <- data.table(
  n_seasons = nrow(j), n_stations = uniqueN(j$station_id),
  bias_mean = round(mean(j$d), 3), bias_median = round(median(j$d), 3),
  bias_sd = round(sd(j$d), 3), mae = round(mean(abs(j$d)), 3),
  r_pooled = round(cor(j$CP_api, j$CP_arch), 4),
  pct_abs_gt5 = round(100 * mean(abs(j$d) > 5), 2))

per_st <- j[, .(n = .N, bias = mean(d), mae = mean(abs(d)), sd_arch = sd(CP_arch),
                r = if (.N >= 3) cor(CP_api, CP_arch) else NA_real_,
                lon = lon[1], lat = lat[1]), by = station_id]
st_ok <- per_st[n >= MIN_SEASONS]

cat("=== 1. agreement season by season ===\n")
print(pooled)
cat(sprintf("\nper station (>= %d seasons, n = %d):\n", MIN_SEASONS, nrow(st_ok)))
cat(sprintf("  median bias          : %+.2f CP  (p10 %+.2f, p90 %+.2f)\n",
            median(st_ok$bias), quantile(st_ok$bias, .10), quantile(st_ok$bias, .90)))
cat(sprintf("  median correlation   : %.3f  (p10 %.3f)\n",
            median(st_ok$r, na.rm = TRUE), quantile(st_ok$r, .10, na.rm = TRUE)))
cat(sprintf("  median MAE           : %.2f CP\n", median(st_ok$mae)))
cat(sprintf("  stations with |bias| > 5 CP: %d of %d (%.1f%%)\n",
            sum(abs(st_ok$bias) > 5), nrow(st_ok), 100 * mean(abs(st_ok$bias) > 5)))
cat(sprintf("  stations with MAE > %.0f CP (candidates to exclude): %d of %d (%.1f%%)\n",
            MAX_MAE, sum(st_ok$mae > MAX_MAE), nrow(st_ok), 100 * mean(st_ok$mae > MAX_MAE)))
cat(sprintf("  after excluding them: median bias %+.2f CP, median MAE %.2f\n",
            median(st_ok[mae <= MAX_MAE]$bias), median(st_ok[mae <= MAX_MAE]$mae)))
cat(sprintf("  reference: the model-observed bias the project already accepts is %+.2f CP\n\n", REF_MODEL_BIAS))

# --- § 3 - does the disagreement live in the barely-complete seasons? -------------------------
# The smoke test on 12 stations showed a median bias of zero with a right tail. If that tail sits in
# seasons that only just clear the threshold, the answer is a stricter threshold, not a rejected
# splice. This is the check that tells the two apart.
j[, pc_bin := cut(pc_api, breaks = c(85, 90, 95, 99.999, 100.001), right = FALSE,
                  labels = c("85-90", "90-95", "95-100", "100"))]
by_pc <- j[!is.na(pc_bin), .(n = .N, bias_mean = round(mean(d), 2), bias_median = round(median(d), 2),
                             mae = round(mean(abs(d)), 2), pct_gt5 = round(100 * mean(abs(d) > 5), 1)),
           by = pc_bin][order(pc_bin)]
cat("=== 2. disagreement against how complete the API season is ===\n")
print(by_pc)

sweep <- rbindlist(lapply(c(85, 90, 95, 100), function(p) {
  k <- pair_at(p)
  data.table(min_perc = p, n_seasons = nrow(k), n_stations = uniqueN(k$station_id),
             bias_mean = round(mean(k$d), 3), bias_median = round(median(k$d), 3),
             mae = round(mean(abs(k$d)), 3), r = round(cor(k$CP_api, k$CP_arch), 4),
             pct_abs_gt5 = round(100 * mean(abs(k$d) > 5), 2))
}))
cat("\ncompleteness threshold sweep:\n")
print(sweep)

# --- § 4 - Safe Winter Chill on the seasons the two sources share ------------------------------
# The decision rests here: SWC is what every map in the project is built from, so what matters is
# not whether individual winters agree but whether the decile they define does. Both P10 are taken
# over exactly the same seasons, so series length cannot contribute to the difference.
swc <- j[, .(n = .N,
             swc_arch = as.numeric(quantile(CP_arch, .10, names = FALSE)),
             swc_api  = as.numeric(quantile(CP_api,  .10, names = FALSE)),
             lon = lon[1], lat = lat[1]), by = station_id]
swc[, d := swc_api - swc_arch]
swc_ok <- swc[n >= MIN_SWC_SEASONS]

cat(sprintf("\n=== 3. Safe Winter Chill on the common seasons (>= %d seasons) ===\n", MIN_SWC_SEASONS))
cat(sprintf("stations: %d of %d\n", nrow(swc_ok), nrow(swc)))
cat(sprintf("  median archive SWC  : %.2f CP\n", median(swc_ok$swc_arch)))
cat(sprintf("  median API SWC      : %.2f CP\n", median(swc_ok$swc_api)))
cat(sprintf("  API-archive bias    : mean %+.2f, median %+.2f CP\n", mean(swc_ok$d), median(swc_ok$d)))
cat(sprintf("  spatial correlation : %.4f\n", cor(swc_ok$swc_api, swc_ok$swc_arch)))
cat(sprintf("  stations with |bias| > 5 CP: %d (%.1f%%)\n",
            sum(abs(swc_ok$d) > 5), 100 * mean(abs(swc_ok$d) > 5)))

# --- § 5 - figures -----------------------------------------------------------------------------
# The fig23 family is deleted before being written, so the directory always reflects one run rather
# than accumulating panels from earlier parameter choices.
dir.create(FIGDIR, showWarnings = FALSE, recursive = TRUE)
old <- list.files(FIGDIR, pattern = "^fig23_", full.names = TRUE)
if (length(old)) { file.remove(old); cat(sprintf("\ndeleted %d previous fig23_ figures\n", length(old))) }

th <- theme_minimal(base_size = 11) +
      theme(panel.grid.minor = element_blank(), plot.title = element_text(face = "bold", size = 12))

lims <- range(c(j$CP_arch, j$CP_api))
p1 <- ggplot(j, aes(CP_arch, CP_api)) +
  geom_abline(slope = 1, intercept = 0, colour = "grey40", linewidth = .4) +
  geom_point(alpha = .12, size = .7, colour = "#2c7fb8") +
  coord_equal(xlim = lims, ylim = lims) +
  labs(title = "Chill portions per season: AEMET API vs PNACC archive",
       subtitle = sprintf("%s paired seasons, %d stations, completeness >= %.0f%%; bias %+.2f CP (median %+.2f), r = %.3f",
                          format(nrow(j), big.mark = ","), uniqueN(j$station_id), MIN_PERC,
                          pooled$bias_mean, pooled$bias_median, pooled$r_pooled),
       x = "Chill portions, archive", y = "Chill portions, API") + th
ggsave(fig_in(FIGDIR, "fig23_01_api_vs_archive_seasons.png"), p1, width = 7, height = 7, dpi = 200)

slims <- range(c(swc_ok$swc_arch, swc_ok$swc_api))
p2 <- ggplot(swc_ok, aes(swc_arch, swc_api)) +
  geom_abline(slope = 1, intercept = 0, colour = "grey40", linewidth = .4) +
  geom_point(alpha = .5, size = 1.3, colour = "#d95f0e") +
  coord_equal(xlim = slims, ylim = slims) +
  labs(title = "Safe Winter Chill on the seasons both sources share",
       subtitle = sprintf("%d stations with >= %d common seasons; bias %+.2f CP (median %+.2f), r = %.3f",
                          nrow(swc_ok), MIN_SWC_SEASONS, mean(swc_ok$d), median(swc_ok$d),
                          cor(swc_ok$swc_api, swc_ok$swc_arch)),
       x = "Safe Winter Chill, archive (P10)", y = "Safe Winter Chill, API (P10)") + th
ggsave(fig_in(FIGDIR, "fig23_02_api_vs_archive_swc.png"), p2, width = 7, height = 7 / 1.28,
       dpi = 200)

p3 <- ggplot(j[!is.na(pc_bin)], aes(pc_bin, d)) +
  geom_hline(yintercept = 0, colour = "grey40", linewidth = .4) +
  geom_boxplot(outlier.alpha = .15, outlier.size = .6, fill = "#addd8e") +
  labs(title = "Disagreement against how complete the API season is",
       subtitle = "If the tail sat in barely-complete seasons, a stricter threshold would fix it",
       x = "API season completeness (%)", y = "API minus archive (chill portions)") + th
ggsave(fig_in(FIGDIR, "fig23_03_bias_vs_completeness.png"), p3, width = 7, height = 5, dpi = 200)

# --- § 6 - tables ------------------------------------------------------------------------------
# Every number that can end up on a slide has to exist in one of these, so nothing is ever
# recomputed by hand for the talk.
summary_out <- rbindlist(list(
  data.table(block = "pooled_seasons", metric = names(pooled), value = as.numeric(unlist(pooled))),
  data.table(block = "per_station",
             metric = c("n_stations", "bias_median", "mae_median", "r_median", "pct_bias_gt5",
                        "max_mae_threshold", "n_flagged_mae", "bias_median_after_flagging",
                        "mae_median_after_flagging"),
             value = c(nrow(st_ok), median(st_ok$bias), median(st_ok$mae), median(st_ok$r, na.rm = TRUE),
                       100 * mean(abs(st_ok$bias) > 5), MAX_MAE, sum(st_ok$mae > MAX_MAE),
                       median(st_ok[mae <= MAX_MAE]$bias), median(st_ok[mae <= MAX_MAE]$mae))),
  data.table(block = "swc_common_seasons",
             metric = c("n_stations", "swc_arch_median", "swc_api_median", "bias_mean", "bias_median",
                        "r_spatial", "pct_bias_gt5"),
             value = c(nrow(swc_ok), median(swc_ok$swc_arch), median(swc_ok$swc_api), mean(swc_ok$d),
                       median(swc_ok$d), cor(swc_ok$swc_api, swc_ok$swc_arch),
                       100 * mean(abs(swc_ok$d) > 5)))))
summary_out[, value := round(value, 4)]
fwrite(summary_out, file.path(OUTDIR, "api_vs_archive_summary.csv"))
fwrite(sweep, file.path(OUTDIR, "api_vs_archive_threshold_sweep.csv"))
fwrite(merge(per_st, swc[, .(station_id, n_swc = n, swc_arch, swc_api, swc_d = d)],
             by = "station_id", all.x = TRUE), file.path(OUTDIR, "api_vs_archive_by_station.csv"))

cat(sprintf("\nwrote 3 figures to %s and 3 tables to %s\n", FIGDIR, OUTDIR))
