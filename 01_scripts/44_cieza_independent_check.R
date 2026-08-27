#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------------------
# Independent check of the 2021-2025 chill anomaly, and of the model parametrisation, at Cieza.
#
# Everything the project knows about recent winters comes from one network. The archive and the API
# are two products of AEMET, so a change in AEMET's processing around 2021 would look exactly like
# the anomaly of §6.7. This script breaks that dependency using a series measured by somebody else:
# the CEBAS experimental orchard at Cieza (Murcia), published in the repository of
# Muñoz-Morales et al. (2025), MethodsX 15:103686, and covering 2011-2025 without a single gap.
#
# It answers two questions that happen to share the same input:
#
#   1. Does an instrument outside the AEMET network see the same recent drop? Reported in standard
#      deviations, because Murcia is a low-chill area where absolute anomalies are larger than the
#      national mean and comparing chill portions directly would mislead.
#
#   2. How far apart are the two parametrisations of the Dynamic Model? The same paper cites
#      Fishman et al. (1987) and calls chillR's Dynamic_Model, which carries the 1988 parameters.
#      If the cultivar chill requirements were quantified on the 1988 scale while this project
#      computes supply on the 1987 scale, viability is overestimated. The gap measured here is what
#      says whether that matters, and it is the largest open uncertainty in the project.
#
# The nearby-AEMET contrast deliberately uses stations with data on BOTH sides of 2020. Averaging
# whatever stations happen to exist each year mixes a change of network with a change of climate:
# around Cieza six station-seasons report before 2021 and one after, so the naive average falls by
# ~20 CP for reasons that have nothing to do with the weather.
#
# Input : $PLINIUS_DATA/cieza_cebas/Cieza11-25.xlsx (see 00_data/README.md for how to obtain it)
# Output: cieza_seasons.csv, cieza_parametrisation_gap.csv, cieza_check_summary.csv, fig26_*
#
# Usage:
#   Rscript 73_cieza_independent_check.R
#   Rscript 73_cieza_independent_check.R --radius 25
#
# Requires: chillR, data.table, ggplot2, readxl. DM_JOSE.R next to this script.
# ---------------------------------------------------------------------------------------

suppressWarnings(suppressMessages({
  library(chillR); library(data.table); library(ggplot2); library(readxl)
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

CIEZA  <- getarg("--cieza",  plinius_data("cieza_cebas", "Cieza11-25.xlsx"))
ARCH   <- getarg("--archive",tab_path("chill_obs_seasons_1975.csv"))
APIF   <- getarg("--api",    tab_path("chill_api_seasons.csv"))
SERIES <- getarg("--series", tab_path("observed_annual_series.csv"))
OUTDIR <- getarg("--outdir", OUT_DIR)
FIGDIR <- getarg("--figdir", FIG_DIR)

# Orchard coordinates as stated in the paper (38 deg 16' N, 1 deg 16' W, 241 m). The repository's
# own Rmd passes 38.11; the difference changes daylength, and therefore chill, negligibly.
LAT <- as.numeric(getarg("--lat", 38.27)); LON <- as.numeric(getarg("--lon", -1.27))
RADIUS <- as.numeric(getarg("--radius", 20))     # km, for picking comparable AEMET stations
START_JDAY <- 305L; END_JDAY <- 59L; MIN_PERC <- 85
SPLIT <- 2020L; LAST <- 2025L; FIRST_BASE <- 2012L   # Cieza's first complete season is 2012

source_dm_jose()

# --- § 1 - the orchard record --------------------------------------------------------------
# The workbook carries five sheets; only the first holds the full daily series, the other two with
# temperature are shorter versions of it. Picked by content rather than by name so a re-download
# with reordered sheets cannot silently select a truncated series.
if (!file.exists(CIEZA)) stop(sprintf("no Cieza workbook at %s", CIEZA))
need <- c("Year", "Month", "Day", "Tmax", "Tmin")
best <- NULL
for (s in excel_sheets(CIEZA)) {
  d <- suppressMessages(as.data.frame(read_excel(CIEZA, sheet = s)))
  if (!all(need %in% names(d))) next
  d <- d[!is.na(d$Year), need]
  if (is.null(best) || nrow(d) > nrow(best$d)) best <- list(sheet = s, d = d)
}
if (is.null(best)) stop("no sheet carries Year/Month/Day/Tmax/Tmin")
cie <- best$d
cat(sprintf("Cieza: sheet '%s', %s rows, %d-%d, NA in Tmax %d and in Tmin %d\n",
            best$sheet, format(nrow(cie), big.mark = ","), min(cie$Year), max(cie$Year),
            sum(is.na(cie$Tmax)), sum(is.na(cie$Tmin))))

# --- § 2 - chill by season, both parametrisations -------------------------------------------
# Running the two side by side on identical input is the only way to attribute the difference to the
# parametrisation and to nothing else. CP_1987 is what the project uses everywhere.
w <- fix_weather(cie, end_at_present = FALSE)
tr <- tempResponse_daily_list(list(w), latitude = LAT, Start_JDay = START_JDAY, End_JDay = END_JDAY,
        models = list(CP_1987 = DM_JOSE, CP_1988 = Dynamic_Model, Utah = Utah_Model))[[1]]
cz <- as.data.table(tr)[, .(season_end_year = as.integer(End_year),
                            perc_complete = round(Perc_complete, 1),
                            CP_1987 = round(CP_1987, 2), CP_1988 = round(CP_1988, 2),
                            Utah = round(Utah, 1))][order(season_end_year)]
cz[, gap := round(CP_1988 - CP_1987, 2)]
czk <- cz[perc_complete >= MIN_PERC & season_end_year >= FIRST_BASE]

cat(sprintf("\nusable seasons: %d (%d-%d)\n", nrow(czk), min(czk$season_end_year), max(czk$season_end_year)))
cat("\n=== gap between parametrisations ===\n")
cat(sprintf("  mean CP_1987 %.2f, mean CP_1988 %.2f\n", mean(czk$CP_1987), mean(czk$CP_1988)))
cat(sprintf("  mean gap %+.2f CP, range %+.2f to %+.2f, sd %.2f\n",
            mean(czk$gap), min(czk$gap), max(czk$gap), sd(czk$gap)))
cat(sprintf("  gap between cultivars (Ruiz 2019): 13.8 CP -> the parametrisation gap is %.0f%% of it\n",
            100 * abs(mean(czk$gap)) / 13.8))
cat(sprintf("  correlation of the gap with seasonal chill: %.3f",
            cor(czk$gap, czk$CP_1987)))
cat("  (positive = the gap grows in mild winters)\n")

# --- § 3 - the recent block, three instruments -----------------------------------------------
anom <- function(base, rec, label) data.table(
  fuente = label, base_mean = round(mean(base), 2), base_sd = round(sd(base), 2), n_base = length(base),
  recent_mean = round(mean(rec), 2), n_recent = length(rec),
  anomaly_CP = round(mean(rec) - mean(base), 2), anomaly_sd = round((mean(rec) - mean(base)) / sd(base), 2))

blocks <- list(anom(czk[season_end_year <= SPLIT]$CP_1987, czk[season_end_year > SPLIT]$CP_1987,
                    sprintf("Cieza CEBAS orchard (%d-%d)", FIRST_BASE, SPLIT)))

arc <- fread(ARCH, colClasses = list(character = "station_id"))[perc_complete >= MIN_PERC]
api <- fread(APIF, colClasses = list(character = "station_id"))[perc_complete >= MIN_PERC]
st <- unique(arc[, .(station_id, lon, lat)])
st[, dkm := 111 * sqrt((lat - LAT)^2 + ((lon - LON) * cos(LAT * pi / 180))^2)]

# only stations with a series on BOTH sides of the split, for the reason given in the header
cand <- st[dkm <= RADIUS]$station_id
stable <- Filter(function(s) {
  nrow(arc[station_id == s & season_end_year %between% c(FIRST_BASE, SPLIT)]) >= 5 &&
  nrow(api[station_id == s & season_end_year %between% c(SPLIT + 1L, LAST)]) >= 3
}, cand)
cat(sprintf("\nAEMET stations within %g km: %d; with a stable series on both sides: %d (%s)\n",
            RADIUS, length(cand), length(stable), paste(stable, collapse = ", ")))
if (!length(stable)) cat("  none usable for a stable-composition contrast\n")

for (s in stable) {
  b <- arc[station_id == s & season_end_year %between% c(FIRST_BASE, SPLIT)]$CP
  r <- api[station_id == s & season_end_year %between% c(SPLIT + 1L, LAST)]$CP
  blocks[[length(blocks) + 1]] <- anom(b, r, sprintf("AEMET %s (%.0f km)", s, st[station_id == s]$dkm))
  bl <- arc[station_id == s & season_end_year <= SPLIT]$CP     # the full 1976-2020 baseline too
  blocks[[length(blocks) + 1]] <- anom(bl, r, sprintf("AEMET %s (base 1976-%d)", s, SPLIT))
}

if (file.exists(SERIES)) {
  ns <- fread(SERIES)
  blocks[[length(blocks) + 1]] <- anom(ns[season_end_year <= SPLIT]$mean_CP,
                                       ns[season_end_year > SPLIT]$mean_CP, "National (665 stations)")
}
tab <- rbindlist(blocks)
cat("\n=== the 2021-2025 block seen by different instruments ===\n")
print(tab)
cat("\nAbsolute anomalies are not comparable with each other (Murcia is a low-chill area and a\n")
cat("single station has more variance than a mean of 665). The column to compare is anomaly_sd.\n")

# --- § 4 - figures -----------------------------------------------------------------------------
dir.create(FIGDIR, showWarnings = FALSE, recursive = TRUE)
old <- list.files(FIGDIR, pattern = "^fig26_", full.names = TRUE)
if (length(old)) { file.remove(old); cat(sprintf("\nremoved %d previous fig26_ figures\n", length(old))) }

th <- theme_minimal(base_size = 11) +
      theme(panel.grid.minor = element_blank(), legend.position = "top",
            plot.title = element_text(face = "bold", size = 12),
            plot.caption = element_text(size = 8, colour = "grey35", hjust = 0))

# standardised series: the only fair way to overlay records of very different absolute level
z <- list(data.table(y = czk$season_end_year, v = czk$CP_1987, src = "Cieza, CEBAS orchard"))
for (s in stable) {
  d <- rbind(arc[station_id == s & season_end_year >= FIRST_BASE, .(y = season_end_year, v = CP)],
             api[station_id == s & season_end_year %between% c(SPLIT + 1L, LAST), .(y = season_end_year, v = CP)])
  z[[length(z) + 1]] <- d[, .(y, v, src = sprintf("AEMET %s", s))]
}
if (file.exists(SERIES)) {
  ns <- fread(SERIES)
  z[[length(z) + 1]] <- ns[season_end_year >= FIRST_BASE, .(y = season_end_year, v = mean_CP, src = "National mean")]
}
zz <- rbindlist(z)[, .(y, z = (v - mean(v[y <= SPLIT])) / sd(v[y <= SPLIT])), by = src]
p1 <- ggplot(zz, aes(y, z, colour = src)) +
  annotate("rect", xmin = SPLIT + .5, xmax = LAST + .5, ymin = -Inf, ymax = Inf, fill = "#e6550d", alpha = .10) +
  geom_hline(yintercept = 0, colour = "grey30", linewidth = .4) +
  geom_line(linewidth = .8) + geom_point(size = 1.6) +
  scale_x_continuous(breaks = seq(FIRST_BASE, LAST, 2)) +
  labs(title = sprintf("The recent drop seen by %d records from two separate networks", uniqueN(zz$src)),
       subtitle = "Standardised against each record's own 2012-2020 baseline, because absolute chill differs by 15 CP between sites",
       x = NULL, y = "Standard deviations from baseline", colour = NULL,
       caption = "Shaded: 2021-2025. The CEBAS orchard series is instrumentally independent of the AEMET network that supplies\nboth halves of the project's spliced record, so agreement here rules out an AEMET processing change as the cause.") + th
ggsave(fig_in(FIGDIR, "fig26_01_independent_records.png"), p1, width = 9, height = 5, dpi = 200)

pg <- melt(czk[, .(season_end_year, CP_1987, CP_1988)], id.vars = "season_end_year",
           variable.name = "param", value.name = "CP")
p2 <- ggplot(pg, aes(season_end_year, CP, fill = param)) +
  geom_col(position = position_dodge(width = .8), width = .75) +
  scale_fill_manual(values = c(CP_1987 = "#2c7fb8", CP_1988 = "#fdae61"),
                    labels = c("Fishman 1987 (project)", "chillR Dynamic_Model (1988)")) +
  scale_x_continuous(breaks = seq(FIRST_BASE, LAST, 2)) +
  labs(title = "The two parametrisations of the Dynamic Model, same data",
       subtitle = sprintf("Cieza, %d seasons. Mean gap %+.2f CP, ranging %+.2f to %+.2f; the two cultivars are 13.8 CP apart",
                          nrow(czk), mean(czk$gap), min(czk$gap), max(czk$gap)),
       x = NULL, y = "Chill portions", fill = NULL,
       caption = "Muñoz-Morales et al. (2025) cite Fishman et al. (1987) and call chillR's Dynamic_Model, which carries the 1988\nparameters. If the cultivar requirements were quantified on that scale, supply and demand are not on the same one.") + th
ggsave(fig_in(FIGDIR, "fig26_02_parametrisation_gap.png"), p2, width = 9, height = 5, dpi = 200)

# --- § 5 - tables ------------------------------------------------------------------------------
fwrite(cz, file.path(OUTDIR, "cieza_seasons.csv"))
fwrite(czk[, .(season_end_year, CP_1987, CP_1988, gap)], file.path(OUTDIR, "cieza_parametrisation_gap.csv"))
fwrite(tab, file.path(OUTDIR, "cieza_check_summary.csv"))

# The parametrisation gap is quoted in a slide title, so it has to reach the deck through a metrics
# table like every other figure on screen. It was typed by hand until 2026-08-24.
fwrite(data.table(
  metric = c("param_gap_mean_CP", "param_gap_min_CP", "param_gap_max_CP", "param_gap_n_seasons"),
  value = c(round(mean(czk$gap), 4), round(min(czk$gap), 4),
            round(max(czk$gap), 4), nrow(czk))
), file.path(OUTDIR, "cieza_numbers.csv"))
cat(sprintf("\nwrote 2 figures to %s and 3 tables to %s\n", FIGDIR, OUTDIR))
