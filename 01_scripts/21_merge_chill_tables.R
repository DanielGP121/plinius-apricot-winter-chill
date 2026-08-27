#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------------------
# Merge the chill tables produced by the separate Ladon runs into the one table every figure and
# every quoted number is taken from.
#
# The runs were launched at different times and each covers a different analysis window, so the
# canonical table is assembled here rather than by whoever writes a figure script. A `situation`
# column keys scenario and window together, because neither identifies a period on its own: the
# observed appears twice (1991-2020 and 1995-2020) and the spliced model baseline appears twice
# (1995-2020 and 1995-2025), and only the pair tells them apart.
#
# Windows, and which of them tile the century without overlapping:
#   observado 1991-2020 / 1995-2020   observations from the PNACC archive
#   presente  1995-2020   [TILED]     model baseline, historical spliced to an SSP across 2014/2015
#   actual    1995-2025               most recent model climate; overlaps 2021-2040, so it opens the
#                                     talk but is never the reference a future is differenced against
#   historico 1985-2014               the raw CMIP6 historical window, kept for continuity
#   2021-2040 [TILED] · 2041-2070 [TILED] · 2071-2100 [TILED]
#
# Usage: Rscript 11_merge_chill_tables.R
# ---------------------------------------------------------------------------------------

suppressWarnings(suppressMessages(library(data.table)))

# Paths come from 00_paths.R: it derives the repository root from its own location.
.f <- grep("^--file=", commandArgs(FALSE), value = TRUE)
source(file.path(if (length(.f)) dirname(normalizePath(sub("^--file=", "", .f[1]))) else getwd(), "00_paths.R"))

OUT  <- OUT_DIR
SRC  <- c("chill_national.csv", "chill_present.csv", "chill_near.csv",
          "chill_obs1995.csv", "chill_current.csv")

# § 1 — Read, checking each file is the clean comma-separated original rather than a copy that has
# been through a spreadsheet, which silently rewrites coordinates and drops leading zeros from ids.
tabs <- lapply(SRC, function(f) {
  p <- file.path(OUT, f)
  if (!file.exists(p)) stop("missing ", f)
  d <- fread(p)
  if (!is.numeric(d$lon) || !is.numeric(d$lat))
    stop(f, ": lon/lat are not numeric, the file has been through Excel")
  if (any(!grepl("^[A-Z0-9]+$", unique(d$station_id))))
    stop(f, ": station_id values with an unexpected format")
  cat(sprintf("  %-22s %7d rows\n", f, nrow(d)))
  d
})
cat("reading:\n"); m <- rbindlist(tabs, use.names = TRUE)

# § 2 — Label each scenario-window pair once, so no figure has to re-derive what a period means.
LAB <- data.table(
  scenario = c("observaciones", "observaciones", "presente", "presente", "historical",
               rep(c("ssp126", "ssp245", "ssp370"), each = 3)),
  window   = c("obsref", "present", "present", "current", "ref",
               rep(c("nearterm", "near", "far"), times = 3)),
  periodo  = c("1991-2020", "1995-2020", "1995-2020", "1995-2025", "1985-2014",
               rep(c("2021-2040", "2041-2070", "2071-2100"), times = 3)),
  clase    = c("observado", "observado", "modelo_base", "modelo_actual", "historico",
               rep(c("futuro", "futuro", "futuro"), times = 3)),
  tiled    = c(FALSE, FALSE, TRUE, FALSE, FALSE, rep(TRUE, 9))
)
m <- merge(m, LAB, by = c("scenario", "window"), all.x = TRUE)
if (anyNA(m$periodo)) stop("unlabelled scenario-window combinations: ",
                           paste(unique(m[is.na(periodo), paste(scenario, window)]), collapse = ", "))
m[, situation := paste(scenario, window, sep = "_")]

# § 3 — Checks that would otherwise only surface as a wrong figure.
stopifnot(sum(duplicated(m[, .(scenario, model, station_id, window)])) == 0)
stopifnot(!anyNA(m$safe_winter_chill_P10))
co <- unique(m[, .(station_id, lon = round(lon, 3), lat = round(lat, 3))])
stopifnot(uniqueN(co$station_id) == nrow(co))     # one station, one location

setcolorder(m, c("situation", "scenario", "window", "periodo", "clase", "tiled",
                 "model", "station_id", "lon", "lat"))
setorder(m, clase, periodo, scenario, model, station_id)
fwrite(m, file.path(OUT, "chill_all_windows.csv"))

cat(sprintf("\nwrote chill_all_windows.csv: %d rows, %d stations, %d situations\n",
            nrow(m), uniqueN(m$station_id), uniqueN(m$situation)))
print(m[, .(filas = .N, est = uniqueN(station_id), modelos = uniqueN(model),
            SWC = round(median(safe_winter_chill_P10), 1)), by = .(clase, periodo, scenario)], row.names = FALSE)
