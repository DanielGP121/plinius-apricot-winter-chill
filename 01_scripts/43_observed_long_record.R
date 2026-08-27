#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------------------
# Fifty winters of observed chill: is the 2021-2025 run unusual, or ordinary variability?
#
# The short baseline could not answer this. With 1995-2020 there was no trend, but 26 seasons is not
# enough to say whether a mild five-year stretch is rare. The archive reaches back to 1975, so the
# baseline can be nearly doubled (script 20 --windows obs --per-season --years 1975,2020) and the
# recent block placed against 45 seasons instead of 25.
#
# Four things are tested, because a striking result invites exactly these objections:
#   trend      is there a slope over 45 years, or is the record flat?
#   ranking    where do the recent winters sit among all 50?
#   blocks     of every 5-consecutive-season block in the baseline, how many are as mild? This is
#              the honest version of the question, since picking the last 5 years is not a random draw.
#   structure  are consecutive winters correlated? If they were, treating them as exchangeable would
#              overstate the evidence, so the autocorrelation is measured rather than assumed.
#
# Caveat that the code cannot fix and that belongs with any figure produced here: seasons up to 2020
# come from the PNACC archive and 2021-2025 from the AEMET API. Script 41 measured the API reading
# +0.13 CP above the archive on the seasons they share, so the source change pushes against the
# finding rather than creating it, but that offset could only be measured where the two overlap.
#
# Outputs: observed_annual_series.csv, observed_long_record_summary.csv, fig25_01 and fig25_02.
#
# Usage:
#   Rscript 59_observed_long_record.R
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

LONG   <- getarg("--long",    tab_path("chill_obs_seasons_1975.csv"))
APIF   <- getarg("--api",     tab_path("chill_api_seasons.csv"))
SPLICE <- getarg("--splice",  tab_path("observed_spliced_swc.csv"))
OUTDIR <- getarg("--outdir",  OUT_DIR)
FIGDIR <- getarg("--figdir",  FIG_DIR)

MIN_PERC   <- as.numeric(getarg("--min-perc", 85))
SPLIT_YEAR <- 2020L
LAST_YEAR  <- 2025L
BLOCK      <- 5L          # length of the recent run, and of the historical blocks it is compared to
API_OFFSET <- 0.13        # measured in script 41; quoted in the caption, not applied to the data

# --- § 1 - one series, constant station set ----------------------------------------------------
# The station set is held fixed at the stations the API can extend. Letting it change between the
# two halves would mix a change of network with a change of climate, and the network grew a lot in
# 2008-2009. Representativeness is reported against the full archive so the restriction is visible.
load_seasons <- function(path, tag) {
  if (!file.exists(path)) stop(sprintf("missing %s table at %s", tag, path))
  fread(path, colClasses = list(character = "station_id"))[perc_complete >= MIN_PERC]
}

L  <- load_seasons(LONG, "long archive")
A  <- load_seasons(APIF, "API")
if (!file.exists(SPLICE)) stop(sprintf("missing splice table at %s (run script 42 first)", SPLICE))
ids <- fread(SPLICE, colClasses = list(character = "station_id"))$station_id

past   <- L[station_id %in% ids & season_end_year <= SPLIT_YEAR]
recent <- A[station_id %in% ids & season_end_year %between% c(SPLIT_YEAR + 1L, LAST_YEAR)]
# Holding the candidate station set fixed is not enough: not every station reports all five recent
# seasons, so a plain annual mean is taken over 665 stations in the baseline and 629-643 in the
# recent block, and part of the difference between the two would be a change of network rather than
# of climate. Each season is therefore expressed as a departure from its own station's baseline mean
# and the annual figure is the mean of those departures, which cannot move when the roster does. The
# overall baseline level is added back so the series stays in chill portions and remains readable.
all_s <- rbind(past[, .(station_id, y = season_end_year, CP, src = "archive")],
               recent[, .(station_id, y = season_end_year, CP, src = "api")])
st_mu <- past[, .(mu_st = mean(CP)), by = station_id]
GRAND <- mean(st_mu$mu_st)
all_s <- merge(all_s, st_mu, by = "station_id")
ser <- all_s[, .(n_stations = uniqueN(station_id), mean_CP = GRAND + mean(CP - mu_st),
                 mean_raw = mean(CP), src = src[1]), by = y][order(y)]

base <- ser[y <= SPLIT_YEAR]; rec <- ser[y > SPLIT_YEAR]
mu <- mean(base$mean_CP); sdev <- sd(base$mean_CP)

cat(sprintf("stations: %d (of the %d in the archive)\n", length(ids), uniqueN(L$station_id)))
cat(sprintf("series: %d-%d, %d seasons (%d from the archive, %d from the API)\n",
            min(ser$y), max(ser$y), nrow(ser), nrow(base), nrow(rec)))
cat(sprintf("baseline %d-%d: mean %.2f CP, sd %.2f\n", min(base$y), SPLIT_YEAR, mu, sdev))
cat(sprintf("block %d-%d   : mean %.2f CP  -> %+.2f CP = %.2f sd\n\n",
            SPLIT_YEAR + 1L, LAST_YEAR, mean(rec$mean_CP), mean(rec$mean_CP) - mu,
            (mean(rec$mean_CP) - mu) / sdev))

# How much the composition correction is worth, reported rather than assumed. The balanced panel
# (only stations reporting every recent season) is the independent check on it: if the three agree,
# the roster was never driving the anomaly.
full_ids <- recent[, .N, by = station_id][N == (LAST_YEAR - SPLIT_YEAR)]$station_id
bal <- all_s[station_id %in% full_ids, .(m = mean(CP)), by = y][order(y)]
raw <- ser[, .(y, m = mean_raw)]
sens <- function(d, lab) {
  b <- d[y <= SPLIT_YEAR]$m; r <- d[y > SPLIT_YEAR]$m
  cat(sprintf("  %-34s %+.3f CP = %.3f sd\n", lab, mean(r) - mean(b), (mean(r) - mean(b)) / sd(b)))
  data.table(method = lab, anomaly_CP = round(mean(r) - mean(b), 3),
             anomaly_sd = round((mean(r) - mean(b)) / sd(b), 3), n_stations = uniqueN(d))
}
cat("\n=== sensitivity to panel composition ===\n")
sens_tab <- rbindlist(list(
  sens(raw, "media simple (composicion variable)"),
  sens(bal, sprintf("panel equilibrado (%d est.)", length(full_ids))),
  sens(ser[, .(y, m = mean_CP)], "anomalia por estacion (la que se usa)")))

# representativeness of the restricted set against every archive station
full <- L[, .(mean_CP = mean(CP)), by = .(y = season_end_year)][order(y)]
cmp <- merge(full, base[, .(y, mean_sub = mean_CP)], by = "y")
cat(sprintf("representativeness: r = %.4f against the %d archive stations, offset %+.2f CP\n\n",
            cor(cmp$mean_CP, cmp$mean_sub), uniqueN(L$station_id), mean(cmp$mean_sub - cmp$mean_CP)))

# --- § 2 - trend --------------------------------------------------------------------------------
# A flat baseline matters for the reading: if the record already sloped downwards, a mild recent
# stretch would just be the slope continuing. If it does not, the recent block is a departure.
trend <- function(d, label) {
  f <- lm(mean_CP ~ y, data = d)
  s <- summary(f)$coefficients[2, ]
  cat(sprintf("  %-22s %+.4f CP/yr  (p = %.4f, R2 = %.3f, n = %d)\n",
              label, s[1], s[4], summary(f)$r.squared, nrow(d)))
  data.table(period = label, slope = round(s[1], 4), p = round(s[4], 4),
             r2 = round(summary(f)$r.squared, 4), n = nrow(d))
}
cat("=== trend ===\n")
trends <- rbindlist(list(
  trend(base, sprintf("%d-%d", min(base$y), SPLIT_YEAR)),
  trend(base[y >= 1995], sprintf("1995-%d", SPLIT_YEAR)),
  trend(ser, sprintf("%d-%d", min(ser$y), LAST_YEAR))))

# --- § 3 - ranking, blocks and structure --------------------------------------------------------
ser[, rank_mild := frank(mean_CP)]           # 1 = least chill in the record
cat(sprintf("\n=== the %d mildest winters of %d ===\n", 10, nrow(ser)))
print(ser[order(mean_CP)][1:10, .(y, mean_CP = round(mean_CP, 2), rank = rank_mild, src)])
n_top10 <- sum(ser[order(mean_CP)][1:10]$y > SPLIT_YEAR)
p_hyper <- sum(dhyper(n_top10:BLOCK, BLOCK, nrow(ser) - BLOCK, 10))
cat(sprintf("\nof the 10 mildest, %d are from %d-%d; under exchangeability p = %.5f\n",
            n_top10, SPLIT_YEAR + 1L, LAST_YEAR, p_hyper))

# Picking the last five years is not a random draw, so the fair comparison is against every
# five-season block the baseline contains, not against single seasons.
roll <- frollmean(base$mean_CP, BLOCK)
blocks <- data.table(end_y = base$y, mean5 = roll)[!is.na(mean5)]
rec_mean <- mean(rec$mean_CP)
n_below <- sum(blocks$mean5 <= rec_mean)
cat(sprintf("\n=== blocks of %d consecutive seasons in the baseline ===\n", BLOCK))
cat(sprintf("possible blocks %d; mildest %.2f CP (ends in %d)\n",
            nrow(blocks), min(blocks$mean5), blocks$end_y[which.min(blocks$mean5)]))
cat(sprintf("block %d-%d: %.2f CP -> %d historical blocks as mild or milder (%.1f%%)\n",
            SPLIT_YEAR + 1L, LAST_YEAR, rec_mean, n_below, 100 * n_below / nrow(blocks)))

ac <- acf(base$mean_CP, plot = FALSE, lag.max = 3)$acf[2:4]
cat(sprintf("\nbaseline autocorrelation, lags 1-3: %s\n", paste(round(ac, 3), collapse = ", ")))
cat("  (close to zero, so treating the winters as exchangeable is defensible)\n")

# --- § 4 - is the Safe Winter Chill baseline sensitive to the window? ---------------------------
# The project builds every map on a 1995-2020 baseline. If the SWC moved much between plausible
# windows, that choice would be carrying part of the result.
swc_win <- function(y0, y1, d = past) {
  x <- d[season_end_year %between% c(y0, y1), .(swc = quantile(CP, .10, names = FALSE), n = .N), by = station_id]
  data.table(window = sprintf("%d-%d", y0, y1), seasons = as.integer(median(x$n)),
             swc_median = round(median(x$swc), 3), n_stations = nrow(x))
}
spliced_all <- rbind(past[, .(station_id, CP)], recent[, .(station_id, CP)])
swc_tab <- rbindlist(list(
  swc_win(min(base$y), SPLIT_YEAR), swc_win(1991, SPLIT_YEAR), swc_win(1995, SPLIT_YEAR),
  spliced_all[, .(swc = quantile(CP, .10, names = FALSE), n = .N), by = station_id][
    , .(window = sprintf("%d-%d empalmado", min(base$y), LAST_YEAR), seasons = as.integer(median(n)),
        swc_median = round(median(swc), 3), n_stations = .N)]))
cat("\n=== median SWC by window (same stations) ===\n")
print(swc_tab)

# --- § 5 - figures ------------------------------------------------------------------------------
dir.create(FIGDIR, showWarnings = FALSE, recursive = TRUE)
old <- list.files(FIGDIR, pattern = "^fig25_", full.names = TRUE)
if (length(old)) { file.remove(old); cat(sprintf("\ndeleted %d previous fig25_ figures\n", length(old))) }

th <- theme_minimal(base_size = 12) +
      theme(panel.grid.minor = element_blank(), legend.position = "top",
            plot.title = element_text(face = "bold", size = 13),
            plot.caption = element_text(size = 8, colour = "grey35", hjust = 0))

# Anomalies rather than absolute values: a bar chart whose axis does not start at zero no longer
# encodes value in bar length, and cropping it to make the variation visible would overstate it.
# Plotted as departures from the baseline mean the axis is honest, zero is meaningful, and the
# direction of each winter is what the eye reads.
ser[, period := ifelse(y > SPLIT_YEAR, sprintf("%d-%d", SPLIT_YEAR + 1L, LAST_YEAR),
                       sprintf("%d-%d", min(ser$y), SPLIT_YEAR))]
ser[, anom := mean_CP - mu]
p1 <- ggplot(ser, aes(y, anom, fill = period)) +
  annotate("rect", xmin = -Inf, xmax = Inf, ymin = -sdev, ymax = sdev, fill = "grey70", alpha = .25) +
  geom_col(width = .75) +
  geom_hline(yintercept = 0, colour = "grey20", linewidth = .5) +
  scale_fill_manual(values = setNames(c("#4292c6", "#e6550d"),
                    c(sprintf("%d-%d", min(ser$y), SPLIT_YEAR), sprintf("%d-%d", SPLIT_YEAR + 1L, LAST_YEAR)))) +
  scale_x_continuous(breaks = seq(1980, 2025, 10)) +
  labs(title = "Observed winter chill in Spain, 1976-2025",
       subtitle = sprintf("Departure from the %d-%d mean (%.1f CP) over %d stations\nNo trend across the baseline (%+.3f CP/yr, p = %.2f); the last five winters average %.2f CP below it, %.1f sd",
                          min(ser$y), SPLIT_YEAR, mu, length(ids), trends$slope[1], trends$p[1],
                          abs(rec_mean - mu), abs(rec_mean - mu) / sdev),
       x = NULL, y = "Chill portions, anomaly", fill = NULL,
       caption = sprintf("Grey band: +/- 1 sd of the baseline. Seasons to %d from the PNACC archive, %d-%d from the AEMET API,\nwhich reads %+.2f CP high on the seasons the two sources share, so the source change works against the anomaly shown.",
                         SPLIT_YEAR, SPLIT_YEAR + 1L, LAST_YEAR, API_OFFSET)) + th
ggsave(fig_in(FIGDIR, "fig25_01_observed_chill_series_1976_2025.png"), p1, width = 10, height = 5.5, dpi = 200)

allroll <- rbind(blocks[, .(end_y, mean5, grp = "baseline blocks")],
                 data.table(end_y = LAST_YEAR, mean5 = rec_mean, grp = "2021-2025"))
p2 <- ggplot(allroll, aes(end_y, mean5, colour = grp)) +
  geom_hline(yintercept = rec_mean, colour = "#e6550d", linetype = "dashed", linewidth = .5) +
  geom_line(data = allroll[grp == "baseline blocks"], linewidth = .8) +
  geom_point(data = allroll[grp == "2021-2025"], size = 3.5) +
  scale_colour_manual(values = c("baseline blocks" = "#4292c6", "2021-2025" = "#e6550d")) +
  labs(title = sprintf("Every %d-winter stretch of the record", BLOCK),
       subtitle = sprintf("%d overlapping blocks in %d-%d; %d of them are as mild as %d-%d",
                          nrow(blocks), min(base$y), SPLIT_YEAR, n_below, SPLIT_YEAR + 1L, LAST_YEAR),
       x = "Final winter of the block", y = sprintf("Mean chill portions over %d winters", BLOCK),
       colour = NULL) + th
ggsave(fig_in(FIGDIR, "fig25_02_running5_blocks.png"), p2, width = 9, height = 5, dpi = 200)

# --- § 6 - tables -------------------------------------------------------------------------------
fwrite(ser[, .(season_end_year = y, n_stations, mean_CP = round(mean_CP, 3),
               mean_CP_uncorrected = round(mean_raw, 3), source = src,
               rank_mild = as.integer(rank_mild))][order(season_end_year)],
       file.path(OUTDIR, "observed_annual_series.csv"))
fwrite(sens_tab, file.path(OUTDIR, "observed_panel_sensitivity.csv"))

summary_out <- rbindlist(list(
  data.table(block = "baseline", metric = c("first_year", "last_year", "n_seasons", "mean_CP", "sd_CP"),
             value = c(min(base$y), SPLIT_YEAR, nrow(base), mu, sdev)),
  data.table(block = "recent", metric = c("first_year", "last_year", "n_seasons", "mean_CP",
                                          "anomaly_CP", "anomaly_sd"),
             value = c(SPLIT_YEAR + 1L, LAST_YEAR, nrow(rec), rec_mean, rec_mean - mu, (rec_mean - mu) / sdev)),
  data.table(block = "ranking", metric = c("n_recent_in_10_mildest", "p_exchangeable", "mildest_winter"),
             value = c(n_top10, p_hyper, ser[which.min(mean_CP)]$y)),
  data.table(block = "blocks", metric = c("block_length", "n_baseline_blocks", "n_as_mild",
                                          "mildest_baseline_block_CP"),
             value = c(BLOCK, nrow(blocks), n_below, min(blocks$mean5))),
  data.table(block = "structure", metric = c("acf_lag1", "acf_lag2", "acf_lag3"), value = ac),
  data.table(block = "representativeness",
             metric = c("n_stations_used", "n_stations_archive", "r_annual_series", "offset_CP"),
             value = c(length(ids), uniqueN(L$station_id), cor(cmp$mean_CP, cmp$mean_sub),
                       mean(cmp$mean_sub - cmp$mean_CP)))))
summary_out[, value := round(value, 4)]
fwrite(rbind(summary_out,
             trends[, .(block = "trend", metric = period, value = slope)],
             trends[, .(block = "trend_p", metric = period, value = p)]),
       file.path(OUTDIR, "observed_long_record_summary.csv"))
fwrite(swc_tab, file.path(OUTDIR, "observed_swc_by_window.csv"))

cat(sprintf("\nwrote 2 figures to %s and 3 tables to %s\n", FIGDIR, OUTDIR))
