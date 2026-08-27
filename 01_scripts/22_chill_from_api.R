#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------------------
# Winter chill, season by season, from the AEMET OpenData daily record.
#
# Companion to 20_chill_national_parallel.R --per-season. That one reads the PNACC archive NetCDFs
# and stops in 2020; this one reads the CSV downloaded from the API (script 11), which reaches 2025
# but covers only 666 of the 3044 archive stations and is thin before 2008. Both emit the same table
# so 41_observed_api_vs_archive.R can join them season by season and decide whether the two observed
# products can be spliced into a single 1995-2025 record.
#
# Why season-level and not Safe Winter Chill: the API series are of very unequal length (median 17
# usable seasons, 131 stations reaching back to 1995 out of 666). A P10 over 12 seasons sits at the
# coldest winter of the sample while a P10 over 26 is a real decile, so comparing aggregates across
# sources of different length would measure sample size rather than climate. Joining on the seasons
# the two sources actually share removes that artefact.
#
# Station latitude is taken from the archive table rather than from the API station census, on
# purpose: the dynamic model derives hourly temperatures from daylength, so feeding a different
# latitude to each source would put a second difference into a comparison meant to isolate one.
#
# Input : observed_1995_2025.csv[.gz] with station_id,Year,Month,Day,Tmax,Tmin (script 11 --merge)
# Output: chill_api_seasons.csv, same columns as chill_obs_seasons.csv
#
# Usage:
#   Rscript 21_chill_from_api.R --maxst 12                       # smoke test, own output path
#   Rscript 21_chill_from_api.R --cores 8
#   Rscript 21_chill_from_api.R --api <csv.gz> --coords <csv> --out <csv> --cores 8
#
# Requires: chillR, data.table, parallel. DM_JOSE.R next to this script (or in getwd()).
# ---------------------------------------------------------------------------------------

suppressWarnings(suppressMessages({
  library(chillR); library(data.table); library(parallel)
}))

# --- args --------------------------------------------------------------------------------
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

API    <- getarg("--api",    out_path("observed_1995_2025.csv.gz"))
COORDS <- getarg("--coords", tab_path("chill_obs_seasons.csv"))
NCORES <- as.integer(getarg("--cores", max(1, detectCores() - 2)))
MAXST  <- as.numeric(getarg("--maxst", Inf))

# A smoke test writes its own file for the same reason as in script 20: a 12-station table is
# indistinguishable from a complete one once it is on disk, and script 41 would happily join it.
OUT <- if (is.finite(MAXST)) out_path(sprintf("chill_api_seasons_maxst%g.csv", MAXST)) else
       getarg("--out", tab_path("chill_api_seasons.csv"))

options(warn = 1)
setDTthreads(1)   # the parallelism here is across stations; nested threading only adds contention

# These must stay identical to 20_chill_national_parallel.R. The comparison in script 41 is only
# meaningful if both tables come from the same season definition and the same chill models, so a
# change to any of them has to be made in both scripts at once.
START_JDAY  <- 305L      # 1 Nov
END_JDAY    <- 59L       # 28 Feb
MAX_NA_FRAC <- 0.4
MIN_PERC    <- 85        # not applied here; reported so script 41 can filter both sides identically

source_dm_jose()

# --- § 1 - the API record ------------------------------------------------------------------
# station_id must be read as character: 69 of these ids carry leading zeros ("0009X") and any
# numeric coercion silently merges them with each other and with the archive ids.
read_api <- function(path) {
  if (!file.exists(path)) stop(sprintf("no API csv at %s", path))
  d <- fread(path, colClasses = list(character = "station_id"))
  need <- c("station_id", "Year", "Month", "Day", "Tmax", "Tmin")
  miss <- setdiff(need, names(d))
  if (length(miss)) stop(sprintf("API csv is missing columns: %s", paste(miss, collapse = ", ")))
  # empty strings for a missing reading are the only non-numeric content in these columns; the
  # coercion turns them into NA, which is what fix_weather expects to see
  d[, Tmax := suppressWarnings(as.numeric(Tmax))]
  d[, Tmin := suppressWarnings(as.numeric(Tmin))]
  setorder(d, station_id, Year, Month, Day)
  d[]
}

# --- § 2 - station coordinates from the archive table ---------------------------------------
read_coords <- function(path) {
  if (!file.exists(path)) stop(sprintf("no archive season table at %s (run script 20 --per-season first)", path))
  a <- fread(path, colClasses = list(character = "station_id"), select = c("station_id", "lon", "lat"))
  unique(a, by = "station_id")
}

# --- § 3 - chill by season for one station --------------------------------------------------
# Mirrors the --per-season branch of script 20 on purpose: same window, same two models, and the
# same decision not to filter by completeness here. Seasons keep their Perc_complete so that one
# identical filter can be applied to both sources downstream; filtering now would let each source
# drop a different set of seasons before they were ever joined.
#
# The output is what carries the science: one Chill Portions value per winter per station, which is
# what a grower's chill requirement is actually compared against, and the raw material for the Safe
# Winter Chill decile used everywhere else in the project.
chill_seasons <- function(df, lat) {
  tryCatch({
    if (mean(is.na(df$Tmax)) > MAX_NA_FRAC || mean(is.na(df$Tmin)) > MAX_NA_FRAC) return(NULL)
    weather <- fix_weather(df, end_at_present = FALSE)   # series ending in the future need FALSE
    tr <- tempResponse_daily_list(list(weather), latitude = lat,
            Start_JDay = START_JDAY, End_JDay = END_JDAY,
            models = list(Utah_Chill_Units = Utah_Model, Chill_Portions = DM_JOSE))[[1]]
    if (is.null(tr) || !nrow(tr)) return(NULL)
    data.table(season_end_year = as.integer(tr$End_year),
               perc_complete   = round(as.numeric(tr$Perc_complete), 1),
               CP              = round(as.numeric(tr$Chill_Portions), 2),
               Utah            = round(as.numeric(tr$Utah_Chill_Units), 1))
  }, error = function(e) NULL)
}

# fork on Linux, PSOCK on Windows. Stations are handed over already split, so a worker receives one
# station's rows instead of a copy of the whole 4.8 M-row table.
run_parallel <- function(chunks, lats) {
  idx <- seq_along(chunks)
  work <- function(i) {
    r <- chill_seasons(chunks[[i]], lats[i])
    if (is.null(r)) return(NULL)
    r[, station_id := names(chunks)[i]][]
  }
  if (.Platform$OS.type == "windows") {
    cl <- makeCluster(NCORES); on.exit(stopCluster(cl))
    clusterEvalQ(cl, suppressWarnings(suppressMessages({ library(chillR); library(data.table) })))
    clusterExport(cl, c("chill_seasons", "chunks", "lats", "DM_JOSE",
                        "START_JDAY", "END_JDAY", "MAX_NA_FRAC"), envir = environment())
    parLapply(cl, idx, work)
  } else {
    mclapply(idx, work, mc.cores = NCORES)
  }
}

# --- § 4 - driver ---------------------------------------------------------------------------
main <- function() {
  t0 <- Sys.time()
  api <- read_api(API)
  cat(sprintf("API: %s rows, %d stations, %d-%d\n", format(nrow(api), big.mark = ","),
              uniqueN(api$station_id), min(api$Year), max(api$Year)))

  co <- read_coords(COORDS)
  ids <- sort(unique(api$station_id))
  missing <- setdiff(ids, co$station_id)
  if (length(missing))
    cat(sprintf("WARNING: %d stations have no archive coordinates and are dropped: %s\n",
                length(missing), paste(head(missing, 10), collapse = ", ")))
  ids <- setdiff(ids, missing)
  if (is.finite(MAXST)) ids <- head(ids, MAXST)
  cat(sprintf("computing %d stations on %d cores\n", length(ids), NCORES))

  api <- api[station_id %in% ids]
  chunks <- split(api[, .(Year, Month, Day, Tmax, Tmin)], api$station_id)
  chunks <- chunks[ids]                                   # keep the order the coords are taken in
  lats <- co[match(ids, station_id), lat]
  lons <- co[match(ids, station_id), lon]
  if (anyNA(lats)) stop("some stations resolved to a missing latitude; refusing to run")

  res <- run_parallel(chunks, lats)
  ok <- !vapply(res, is.null, NA)
  if (!any(ok)) stop("no station produced any season")
  cat(sprintf("%d/%d stations produced seasons\n", sum(ok), length(ids)))

  out <- rbindlist(res[ok])
  out[, `:=`(scenario = "observaciones_api", model = "api", window = "api")]
  out[, lon := lons[match(station_id, ids)]]
  out[, lat := lats[match(station_id, ids)]]
  setcolorder(out, c("scenario", "model", "station_id", "lon", "lat", "window",
                     "season_end_year", "perc_complete", "CP", "Utah"))
  setorder(out, station_id, season_end_year)
  fwrite(out, OUT)

  pass <- out[perc_complete >= MIN_PERC]
  cat(sprintf("\nwrote %s: %d rows, %d stations, seasons %d-%d\n", OUT, nrow(out),
              uniqueN(out$station_id), min(out$season_end_year), max(out$season_end_year)))
  cat(sprintf("seasons clearing %d%% completeness: %d of %d (%d stations, median %d per station)\n",
              MIN_PERC, nrow(pass), nrow(out), uniqueN(pass$station_id),
              as.integer(median(pass[, .N, by = station_id]$N))))
  cat(sprintf("total %.1f min\n", as.numeric(difftime(Sys.time(), t0, units = "mins"))))
}

if (sys.nframe() == 0L) main()
