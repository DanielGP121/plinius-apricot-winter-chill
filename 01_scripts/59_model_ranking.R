#!/usr/bin/env Rscript
# The eleven models ranked by how much winter chill they leave at the end of the century (fig54).
#
# The deck already orders the eleven models three different ways and none of them answers the
# question an audience actually asks: which model is the optimistic one and which is the harsh one.
# fig43 ranks by bias against the observed baseline, fig38 by chill in the near term over the 446
# marginal stations, and the panels of fig40 by the fraction the mutant rescues. In fig41, the one
# figure about the spread itself, the eleven points carry no labels at all, so the disagreement is
# visible but anonymous.
#
# What this draws is each model twice, at its own 1995-2020 baseline and at the far window under
# one scenario, joined by the distance between them. The point of the figure is the shape that
# appears: the eleven national baselines sit almost on top of each other while the end-century
# values fan out over a range wider than the gap between the two cultivars. Nearly all of the
# disagreement is sensitivity, not starting point, which is the same argument the no-bias-correction
# slide makes from the other direction.
#
# Each model is compared against itself, never against the ensemble, because a model's own offset
# would otherwise be counted as climate change. This is the rule 32_per_model_stats.R already
# applies to the agreement counters.
#
# Two robustness checks run before anything is drawn, because a ranking invites the audience to
# read positions that the data may not support: the ordering is recomputed with the median instead
# of the mean, and the season count behind each model's percentile is compared across models. Both
# results are reported and the second one is drawn on the figure when it is not uniform.
#
# Usage: Rscript 59_model_ranking.R [--scenario ssp370]
# Writes: 02_outputs/figures_chill/fig54_model_ranking_<scenario>.png
#         02_outputs/model_ranking_<scenario>.csv
#         02_outputs/model_ranking_numbers.csv

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

.f <- grep("^--file=", commandArgs(FALSE), value = TRUE)
.dir <- if (length(.f)) dirname(normalizePath(sub("^--file=", "", .f[1]))) else getwd()
source(file.path(.dir, "00_paths.R"))

getarg <- function(flag, default) {
  a <- commandArgs(TRUE)
  i <- match(flag, a)
  if (is.na(i) || i == length(a)) default else a[i + 1L]
}
SCEN <- getarg("--scenario", "ssp370")
SCEN_LAB <- c(ssp126 = "SSP1-2.6", ssp245 = "SSP2-4.5", ssp370 = "SSP3-7.0")[[SCEN]]

FIG_TITLE <- toupper(Sys.getenv("PLINIUS_FIG_TITLE", "FALSE")) %in% c("TRUE", "1", "YES")
ttl <- function(x) if (FIG_TITLE) x else NULL

n_en <- function(x, d = 1) formatC(x, format = "f", digits = d, big.mark = ",", decimal.mark = ".")

talk_theme <- theme_minimal(base_size = 14) +
  theme(plot.title = element_text(face = "bold", size = 17),
        plot.subtitle = element_text(size = 12.5, colour = "grey30"),
        panel.grid.minor = element_blank(),
        legend.position = "bottom")

CR_B <- 47.5   # 'Búlida', Ruiz et al. 2019
CR_P <- 33.7   # 'Búlida Precoz', same source
CR_GAP <- CR_B - CR_P
NL <- "\n"

# § 1 — one number per model and window, averaged over the stations
#
# Safe Winter Chill is already a per-station statistic (the 10th percentile across the seasons of
# the window), so what is left is to summarise it over the stations. n_seasons travels along
# because it is the denominator of that percentile: a model computed over fewer seasons has a
# percentile that is not strictly comparable with the rest, and the first version of this script
# could not have noticed because it never read the column.
d <- fread(tab_path("chill_all_windows.csv"),
           select = c("situation", "model", "station_id", "n_seasons", "safe_winter_chill_P10"))

summarise_sit <- function(sit) {
  d[situation == sit,
    .(swc = mean(safe_winter_chill_P10), swc_med = median(safe_winter_chill_P10),
      n_seasons = max(n_seasons), n_stations = .N), by = model]
}

FAR_SIT <- paste0(SCEN, "_far")
base <- summarise_sit("presente_present")
far <- summarise_sit(FAR_SIT)
setnames(base, c("swc", "swc_med", "n_seasons", "n_stations"),
         c("base", "base_med", "base_seasons", "n_base"))
setnames(far, c("swc", "swc_med", "n_seasons", "n_stations"),
         c("far", "far_med", "far_seasons", "n_far"))

r <- merge(base, far, by = "model")[model != "obs"]
r[, delta := far - base]
setorder(r, far)

stopifnot(nrow(r) == 11L, all(r$n_base == r$n_far), uniqueN(r$n_base) == 1L)

# § 1b — the two robustness checks
#
# Check one: the position of a model must not be an artefact of summarising the stations with the
# mean rather than the median. If the two disagree, the figure would assert that model A is harsher
# than model B while an equally defensible summary reverses it, and that has to be known before it
# reaches a slide rather than after someone in the room asks.
rank_mean <- r$model
rank_med <- r[order(far_med), model]
n_swaps <- sum(rank_mean != rank_med)
r[, rank_by_mean := .I]
r[, rank_by_median := match(model, rank_med)]
cat("ordering check: ", n_swaps, " of 11 positions move between mean and median\n", sep = "")
if (n_swaps > 0) cat("  stable at the ends: ",
                     paste(intersect(head(rank_mean, 4), head(rank_med, 4)), collapse = ", "),
                     " / ", tail(rank_mean, 1), "\n", sep = "")

# Check two: the window each percentile is computed over. A model short of seasons has its P10
# taken from a smaller sample, and if the missing seasons are not random the percentile shifts. It
# is flagged on the axis rather than silently averaged in.
MODAL_SEASONS <- as.integer(names(sort(table(r$far_seasons), decreasing = TRUE))[1])
r[, short_window := far_seasons != MODAL_SEASONS]
if (any(r$short_window)) {
  cat("season check: ", sum(r$short_window), " model(s) computed over fewer than ",
      MODAL_SEASONS, " seasons: ",
      paste(sprintf("%s (%d)", r$model[r$short_window], r$far_seasons[r$short_window]),
            collapse = ", "), "\n", sep = "")
} else {
  cat("season check: all models over ", MODAL_SEASONS, " seasons\n", sep = "")
}

# Check three: the headline says the baselines cluster. That claim is about the eleven national
# means, so the spread between models *within* a station is computed too, which is a different and
# larger number, and the subtitle is worded to say which one it quotes.
per_station <- d[situation == "presente_present" & model != "obs",
                 .(rng = max(safe_winter_chill_P10) - min(safe_winter_chill_P10)),
                 by = station_id]
STATION_RANGE_MED <- median(per_station$rng)

N_ST <- r$n_base[1]
SPREAD_BASE <- max(r$base) - min(r$base)
SPREAD_FAR <- max(r$far) - min(r$far)
WORST <- r$model[1]
BEST <- r$model[nrow(r)]
BEST_MARGIN <- r$far[nrow(r)] - r$far[nrow(r) - 1L]

# § 2 — the panel
#
# Most pessimistic on top so the figure reads as a ranked list from one to eleven. The baseline
# point is grey because it is the reference, not a result; the end-century point takes the AR6
# colour of the scenario, so anyone who saw the earlier maps recognises it without a legend.
SSP_COL <- c(ssp126 = "#173C66", ssp245 = "#F79420", ssp370 = "#E71D25")
COL_FAR <- SSP_COL[[SCEN]]

r[, y_lab := ifelse(short_window, sprintf("%s *", model), model)]
r[, model_f := factor(y_lab, levels = rev(y_lab))]
r[, delta_lab := paste0(n_en(delta, 1), " CP")]

XMIN <- floor(min(r$far, CR_P) - 3)
X_DELTA <- ceiling(max(r$base) + 5)
XMAX <- X_DELTA + 0.5

# Both extremes are labelled outwards, away from their own segment: the first version pointed the
# lower one along the bar and painted over most of it.
# Offset half a row as well as sideways: the benign end has its baseline point only 6,8 CP away,
# so a label on the row itself lies across its own segment however it is anchored.
lab_ext <- data.table(
  x = c(r$far[1] - 0.7, r$far[nrow(r)] + 0.7),
  y = c(11.34, 0.62),
  lab = c("harshest model", "mildest model"),
  hj = c(1, 0))

g54 <- ggplot(r, aes(y = model_f)) +
  geom_vline(xintercept = CR_B, colour = "#b2182b", linewidth = 0.9) +
  geom_vline(xintercept = CR_P, colour = "#2166ac", linewidth = 0.9) +
  geom_segment(aes(x = far, xend = base, yend = model_f),
               colour = "grey78", linewidth = 1.6) +
  geom_point(aes(x = base), colour = "grey55", size = 3.4) +
  geom_point(aes(x = far), colour = COL_FAR, size = 4.6) +
  geom_text(aes(x = X_DELTA, label = delta_lab), hjust = 1, size = 4.0,
            colour = "grey20", fontface = "bold") +
  geom_text(data = lab_ext, aes(x = x, y = y, label = lab, hjust = hj),
            colour = COL_FAR, size = 3.6, inherit.aes = FALSE) +
  annotate("text", x = CR_B, y = 11.8, label = paste0("requirement", NL, "of 'Búlida'"),
           hjust = 0.5, vjust = 0, size = 3.5, colour = "#b2182b", fontface = "bold",
           lineheight = 0.92) +
  annotate("text", x = CR_P, y = 11.8, label = paste0("requirement", NL, "of 'Búlida Precoz'"),
           hjust = 0.5, vjust = 0, size = 3.5, colour = "#2166ac", fontface = "bold",
           lineheight = 0.92) +
  annotate("text", x = X_DELTA, y = 11.8, label = "change", hjust = 1, vjust = 0,
           size = 3.5, colour = "grey35", fontface = "bold") +
  scale_x_continuous(limits = c(XMIN, XMAX), breaks = seq(30, 75, by = 5),
                     expand = expansion(add = 0)) +
  coord_cartesian(clip = "off") +
  labs(title = ttl("The eleven models, ranked by the winter chill they leave at the end of the century"),
       subtitle = paste0(
         "Each model against itself: grey point its baseline ", "1995-2020",
         ", coloured point ", SCEN_LAB, " at 2071-2100.", NL,
         "The eleven national baseline means fit within ", n_en(SPREAD_BASE, 1),
         " CP and fan out over ", n_en(SPREAD_FAR, 1), " CP at the end of the century."),
       x = "Mean Safe Winter Chill across the stations (chill portions)", y = NULL,
       caption = if (any(r$short_window))
         paste0("* ", paste(r$model[r$short_window], collapse = ", "),
                ": percentile computed over ",
                paste(unique(r$far_seasons[r$short_window]), collapse = "/"),
                " seasons and not ", MODAL_SEASONS, ".") else NULL) +
  talk_theme +
  theme(plot.title.position = "plot",
        plot.caption.position = "plot",
        plot.caption = element_text(hjust = 0, size = 10.5, colour = "grey40",
                                    margin = margin(t = 10)),
        panel.grid.major.y = element_line(colour = "grey93"),
        panel.grid.major.x = element_line(colour = "grey95"),
        axis.text.y = element_text(size = 11.5, colour = "grey15"),
        axis.text.x = element_text(size = 11),
        axis.title.x = element_text(size = 11.5, colour = "grey30", margin = margin(t = 8)),
        plot.subtitle = element_text(size = 12.5, colour = "grey30", margin = margin(b = 30)),
        plot.margin = margin(14, 14, 8, 8))

ggsave(fig_path(sprintf("fig54_model_ranking_%s.png", SCEN)), g54,
       width = 12.5, height = 5.0, dpi = 190, bg = "white")

# § 3 — the table behind the figure, which did not exist anywhere on disk before
#
# Every per-model chill figure in the project was computed inside a plotting script and thrown
# away. Writing it out means the ranking can be quoted, checked and reused without re-running the
# figure. Both orderings are exported so nobody has to take the mean-based one on trust, and the
# file carries the scenario in its name because the figure does too.
out <- r[, .(rank_by_mean, rank_by_median, model,
             base_swc_CP = base, far_swc_CP = far, delta_CP = delta,
             base_median_CP = base_med, far_median_CP = far_med,
             far_n_seasons = far_seasons, n_stations = n_base, scenario = SCEN)]
fwrite(out, out_path(sprintf("model_ranking_%s.csv", SCEN)))

fwrite(data.table(
  metric = c("rank_worst_model", "rank_best_model",
             "rank_worst_swc", "rank_best_swc", "rank_best_margin_CP",
             "rank_spread_far_CP", "rank_spread_base_CP", "rank_station_range_base_CP",
             "rank_delta_worst_CP", "rank_delta_best_CP",
             "rank_n_below_bulida", "rank_n_stations", "rank_n_models",
             "rank_order_swaps_mean_vs_median", "rank_cultivar_gap_CP",
             "rank_short_window_models", "rank_short_window_seasons", "rank_modal_seasons"),
  value = c(WORST, BEST,
            round(r$far[1], 4), round(r$far[nrow(r)], 4), round(BEST_MARGIN, 4),
            round(SPREAD_FAR, 4), round(SPREAD_BASE, 4), round(STATION_RANGE_MED, 4),
            round(r$delta[1], 4), round(r$delta[nrow(r)], 4),
            sum(r$far < CR_B), N_ST, nrow(r),
            n_swaps, CR_GAP,
            if (any(r$short_window)) paste(r$model[r$short_window], collapse = ", ") else "none",
            if (any(r$short_window)) min(r$far_seasons[r$short_window]) else MODAL_SEASONS,
            MODAL_SEASONS),
  scenario = SCEN
), tab_path("model_ranking_numbers.csv"), dec = ".")

cat("fig54 written · ", SCEN_LAB, " · worst ", WORST, " ", n_en(r$far[1], 1),
    " CP · best ", BEST, " ", n_en(r$far[nrow(r)], 1), " CP (margin ",
    n_en(BEST_MARGIN, 2), ") · spread ", n_en(SPREAD_FAR, 1), " CP\n", sep = "")
