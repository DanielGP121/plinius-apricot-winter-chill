#!/usr/bin/env Rscript
# Data coverage against the analysis windows (fig53).
#
# The deck names the four tiling windows in several results titles but never defines them, and
# never shows which record feeds which stretch of time. This draws both on one axis: the span of
# each source the analysis consumes, and the four windows that tile 1995-2100 underneath.
#
# The layout follows the design agreed on 2026-08-24: two banded lanes, a legend that decodes the
# three provenances, the year range written inside each bar, and only ONE vertical marker. The
# first version carried station, model and season counts in a second label line and three vertical
# markers crowded between 2015 and 2026; both were dropped because the figure is read from the back
# of a room and those counts are already on two earlier slides.
#
# The CMIP6 seam is the marker that survives because it is the one methodological fact no other
# figure shows: the historical experiment ends on 31 December 2014 by design, so the baseline
# window has to be assembled from two files.
#
# Every window bound is derived from the canonical table rather than typed, which is what caught
# the first version drawing the historical experiment from 1995 when the project reads it from 1985
# for the historical_ref window. The three observational bounds (1975, 2020, 2025) are still
# literals: they are properties of the AEMET products, not of any table this script can read.
#
# Usage: Rscript 58_data_timeline.R
# Writes: 02_outputs/figures_chill/fig53_data_coverage_timeline.png
#         02_outputs/timeline_numbers.csv

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

.f <- grep("^--file=", commandArgs(FALSE), value = TRUE)
.dir <- if (length(.f)) dirname(normalizePath(sub("^--file=", "", .f[1]))) else getwd()
source(file.path(.dir, "00_paths.R"))

FIG_TITLE <- toupper(Sys.getenv("PLINIUS_FIG_TITLE", "FALSE")) %in% c("TRUE", "1", "YES")
ttl <- function(x) if (FIG_TITLE) x else NULL

NL <- "\n"

talk_theme <- theme_minimal(base_size = 14) +
  theme(plot.title = element_text(face = "bold", size = 17),
        plot.subtitle = element_text(size = 12.5, colour = "grey30"),
        panel.grid.minor = element_blank(),
        legend.position = "bottom")

# § 1 — every span derived, none typed
#
# The window boundaries live in the `periodo` column of the canonical table, so they are read from
# there rather than written out again here. The historical experiment in particular is consumed
# from 1985, not from the start of the baseline: historical_ref is a situation the deck projects in
# its contact sheet, and drawing the bar from 1995 understated the record by ten years.
d <- fread(out_path("chill_all_windows.csv"),
           select = c("situation", "scenario", "periodo", "model", "station_id", "n_seasons"))

periodo_of <- function(sit) {
  p <- unique(d[situation == sit, periodo])
  stopifnot(length(p) == 1L)
  as.integer(strsplit(p, "-", fixed = TRUE)[[1]])
}
seasons_of <- function(sit) d[situation == sit, round(median(n_seasons))]

W_BASE <- periodo_of("presente_present")
W_NEAR <- periodo_of("ssp370_nearterm")
W_MID <- periodo_of("ssp370_near")
W_FAR <- periodo_of("ssp370_far")
W_HIST_REF <- periodo_of("historical_ref")

n_proj <- d[situation == "presente_present", uniqueN(station_id)]
n_models <- d[model != "obs", uniqueN(model)]
n_scen <- d[grepl("^ssp", scenario), uniqueN(scenario)]

obs_long <- fread(out_path("chill_obs_seasons_1975.csv"),
                  select = c("station_id", "season_end_year"))
api <- fread(out_path("chill_api_seasons.csv"), select = "season_end_year")

ARCHIVE_FIRST <- 1975L
ARCHIVE_LAST <- 2020L
OBS_FIRST_SEASON <- min(obs_long$season_end_year)
N_OBS_SEASONS <- uniqueN(obs_long$season_end_year)
n_obs <- uniqueN(obs_long$station_id)

API_FIRST <- min(api$season_end_year)
API_LAST <- 2025L

SPLICE_CMIP6 <- 2015L        # first year of the SSP experiments; historical ends the day before
HIST_FIRST_USED <- W_HIST_REF[1]
SSP_LAST <- W_FAR[2]

stopifnot(API_LAST %in% api$season_end_year,
          HIST_FIRST_USED < SPLICE_CMIP6,
          n_models == 11L, n_scen == 3L,
          W_BASE[2] + 1L == W_NEAR[1], W_NEAR[2] + 1L == W_MID[1], W_MID[2] + 1L == W_FAR[1])

# § 2 — the eight bars, four sources over four windows
#
# Colours are the desaturated provenance palette the other diagrams use (fig44, fig49) and
# deliberately not the blue/orange/red trio, which carries varietal meaning everywhere else in the
# deck and would be read as such here. The heavy left cap is what gives a pale fill enough presence
# to survive a projector.
FILL <- c(observed = "#DCE8F3", modelled = "#E7E1F0", window = "#FBEEDC")
EDGE <- c(observed = "#4A7CA5", modelled = "#7E6FA5", window = "#B5822F")
INK <- c(observed = "#1F3A52", modelled = "#3A3050", window = "#4A3510")

LANES <- c("SOURCES · PERIOD USED", "ANALYSIS WINDOWS")

bars <- rbindlist(list(
  data.table(lane = LANES[1], kind = "observed", name = "AEMET archive",
             x0 = ARCHIVE_FIRST, x1 = ARCHIVE_LAST),
  data.table(lane = LANES[1], kind = "observed", name = "AEMET open API",
             x0 = API_FIRST, x1 = API_LAST),
  data.table(lane = LANES[1], kind = "modelled", name = "CMIP6 historical",
             x0 = HIST_FIRST_USED, x1 = SPLICE_CMIP6 - 1L),
  data.table(lane = LANES[1], kind = "modelled", name = "CMIP6 SSP scenarios",
             x0 = SPLICE_CMIP6, x1 = SSP_LAST),
  data.table(lane = LANES[2], kind = "window", name = "Baseline",
             x0 = W_BASE[1], x1 = W_BASE[2]),
  data.table(lane = LANES[2], kind = "window", name = "Near term",
             x0 = W_NEAR[1], x1 = W_NEAR[2]),
  data.table(lane = LANES[2], kind = "window", name = "Mid century",
             x0 = W_MID[1], x1 = W_MID[2]),
  data.table(lane = LANES[2], kind = "window", name = "End century",
             x0 = W_FAR[1], x1 = W_FAR[2])
))

# Bars run from the first day of x0 to the last day of x1, so the right edge is x1 + 1. This is the
# trap in porting a mermaid gantt, where end dates are exclusive: copying the literals across
# stretches every bar by a year.
bars[, `:=`(xmin = x0, xmax = x1 + 1L,
            span = sprintf("%d–%d", x0, x1),
            fill_col = FILL[kind], edge_col = EDGE[kind], ink_col = INK[kind])]

# § 3 — the panel
#
# Rows are placed by hand rather than by a discrete scale so the two lanes can carry a background
# band of their own and the gap between them is a real distance, not a facet spacing. The band is
# what makes the structure readable without having to read the lane headers.
Y_SRC <- c(9.4, 8.3, 7.2, 6.1)
Y_WIN <- c(3.6, 2.5, 1.4, 0.3)
bars[, y := c(Y_SRC, Y_WIN)]

HH <- 0.40                        # half-height of a bar
PAD <- 0.42                       # band padding beyond the outermost bar
band <- data.table(
  ymin = c(min(Y_SRC) - HH - PAD, min(Y_WIN) - HH - PAD),
  ymax = c(max(Y_SRC) + HH + PAD, max(Y_WIN) + HH + PAD),
  lab = LANES)

X0 <- 1975
X1 <- 2101
DECADES <- seq(1980, 2100, by = 20)

# The bar label sits inside its own bar, right-aligned. Every bar here is at least fifteen years
# wide, which is enough for a nine-character span at this size, so nothing clips; the counts that
# used to force a second label line outside the bar are gone.
g53 <- ggplot() +
  geom_rect(data = band, aes(xmin = X0, xmax = X1, ymin = ymin, ymax = ymax),
            fill = "#F7F9FB") +
  geom_vline(xintercept = DECADES, colour = "#E4E8EC", linewidth = 0.4) +
  geom_rect(data = bars,
            aes(xmin = xmin, xmax = xmax, ymin = y - HH, ymax = y + HH,
                fill = fill_col, colour = edge_col), linewidth = 0.45) +
  # drawn over the bars, not under them: the window it cuts through is the Baseline, which is
  # exactly the one whose assembly the seam explains
  geom_vline(xintercept = SPLICE_CMIP6, linetype = "22", colour = "#6E7681", linewidth = 0.6) +
  # the heavy left cap, drawn as a narrow rectangle so its width is in data units and stays put
  geom_rect(data = bars,
            aes(xmin = xmin, xmax = xmin + 1.1, ymin = y - HH, ymax = y + HH, fill = edge_col),
            colour = NA) +
  geom_text(data = bars, aes(x = xmax - 1.6, y = y, label = span, colour = ink_col),
            hjust = 1, size = 4.6) +
  geom_text(data = band, aes(x = X0, y = ymax + 0.34, label = lab),
            hjust = 0, vjust = 0, size = 4.2, fontface = "bold", colour = "#5A6068") +
  annotate("segment", x = X0, xend = X1, y = band$ymax[1] + 0.30, yend = band$ymax[1] + 0.30,
           colour = "#ECEFF2", linewidth = 0.4) +
  annotate("segment", x = X0, xend = X1, y = band$ymax[2] + 0.30, yend = band$ymax[2] + 0.30,
           colour = "#ECEFF2", linewidth = 0.4) +
  annotate("text", x = SPLICE_CMIP6 - 1.8, y = max(Y_SRC) + 1.45,
           label = paste0("CMIP6 seam", NL, "2014 / 2015"),
           hjust = 1, vjust = 1, size = 4.0, colour = "#4A5058", lineheight = 0.95) +
  scale_fill_identity() +
  scale_colour_identity() +
  scale_y_continuous(breaks = bars$y, labels = bars$name,
                     limits = c(min(Y_WIN) - HH - PAD - 0.1, max(Y_SRC) + 1.60),
                     expand = expansion(add = 0)) +
  scale_x_continuous(breaks = DECADES, limits = c(X0, X1), expand = expansion(add = 0)) +
  coord_cartesian(clip = "off") +
  labs(title = ttl("Period covered by each source, and the four analysis windows"),
       x = NULL, y = NULL) +
  talk_theme +
  theme(plot.title.position = "plot",
        panel.grid = element_blank(),
        axis.text.y = element_text(size = 12.5, hjust = 0, colour = "#16181D"),
        axis.text.x = element_text(size = 12.5, colour = "#5F6672"),
        axis.ticks = element_blank(),
        plot.margin = margin(6, 10, 4, 6))

# § 3b — the legend, drawn as its own strip so the three provenances are decoded on the slide
#
# The deck's pattern for this (fig30, fig39, fig48) is a hand-built legend composed under the panel
# with patchwork, because a ggplot guide cannot show the pale fill and the heavy cap together.
leg <- data.table(
  x = c(1, 2, 3),
  lab = c("Observed (AEMET)", "Modelled (PNACC · CMIP6)", "Analysis window"),
  kind = c("observed", "modelled", "window"))
leg[, `:=`(fill_col = FILL[kind], edge_col = EDGE[kind])]

# Half-width of a legend swatch, in the legend panel's own units. The panel spans 3.23 units over
# 12.5 in, so one unit is about 3.9 in: a swatch has to be a small fraction of that or it reads as
# another bar rather than as a key.
W <- 0.019
g_leg <- ggplot(leg) +
  geom_rect(aes(xmin = x - W, xmax = x + W, ymin = -0.16, ymax = 0.16,
                fill = fill_col, colour = edge_col), linewidth = 0.45) +
  geom_rect(aes(xmin = x - W, xmax = x - W + 0.008, ymin = -0.16, ymax = 0.16, fill = edge_col),
            colour = NA) +
  geom_text(aes(x = x + W + 0.035, y = 0, label = lab), hjust = 0, size = 4.2,
            colour = "#16181D") +
  scale_fill_identity() +
  scale_colour_identity() +
  scale_x_continuous(limits = c(0.72, 3.95), expand = expansion(add = 0)) +
  scale_y_continuous(limits = c(-0.5, 0.5), expand = expansion(add = 0)) +
  theme_void()

suppressPackageStartupMessages(library(patchwork))
g53_full <- g_leg / g53 + plot_layout(heights = unit(c(0.30, 1), c("in", "null")))

# Sized so the slide's 12.09 x 4.7 in slot barely has to shrink it, which is what keeps the axis
# text above the deck's 10 pt floor once projected.
ggsave(fig_path("fig53_data_coverage_timeline.png"), g53_full,
       width = 12.5, height = 4.9, dpi = 190, bg = "white")

# § 4 — the counts the slide quotes, so none of them is typed into talk_content.py
#
# They no longer appear in the figure, but the caption and the speaker notes still use them and the
# builder reads them from here.
fwrite(data.table(
  metric = c("timeline_archive_first_year", "timeline_archive_last_year",
             "timeline_obs_first_season", "timeline_obs_n_seasons",
             "timeline_api_first_year", "timeline_api_last_year",
             "timeline_splice_year", "timeline_hist_first_used", "timeline_ssp_last_year",
             "timeline_n_stations_proj", "timeline_n_stations_obs",
             "timeline_seasons_base", "timeline_seasons_nearterm",
             "timeline_seasons_near", "timeline_seasons_far", "timeline_n_windows"),
  value = c(ARCHIVE_FIRST, ARCHIVE_LAST, OBS_FIRST_SEASON, N_OBS_SEASONS,
            API_FIRST, API_LAST, SPLICE_CMIP6, HIST_FIRST_USED, SSP_LAST,
            n_proj, n_obs,
            seasons_of("presente_present"), seasons_of("ssp370_nearterm"),
            seasons_of("ssp370_near"), seasons_of("ssp370_far"), 4L)
), out_path("timeline_numbers.csv"))

# Self-check: the four windows must tile without gaps or overlaps, which is the claim the slide
# caption makes. A silent failure here would put a wrong assertion on a slide.
w <- bars[lane == LANES[2]][order(xmin)]
stopifnot(all(w$xmax[-nrow(w)] == w$xmin[-1]))

cat("fig53 written · historical read from ", HIST_FIRST_USED,
    " · windows tile ", min(w$xmin), "-", max(w$xmax) - 1L,
    " · tiling check passed\n", sep = "")
