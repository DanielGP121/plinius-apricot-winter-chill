#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------------------
# National winter-chill computation (Peninsula + Baleares), parallel, for Ladon.
#
# Reads the PNACC AR6 station NetCDFs directly (ncdf4, no giant CSV intermediates), windows each
# series to the analysis periods, and computes Safe Winter Chill per station with Egea's method
# (fix_weather + tempResponse_daily_list + DM_JOSE 1987 + Utah), parallelised over stations with
# mclapply (fork). Output is one compact table; the maps are built from it later, in local.
#
# Two NetCDF families are read and they are NOT laid out alike. Nothing here may assume one:
#   THREDDS (projections, from script 14): tas* is [time x station], 'station' is a coordinate
#     variable, time is "days since 1850-01-01".
#   AEMET archive / web form (the observed set): tas* is [station x time], 'station' is a bare
#     dimension and the ids live in a char variable 'station_id', time is "hours since 1900-01-01".
# read_var() detects the three differences (id source, dimension order, time unit) per file.
#
# Every scenario x model combo is written to --outdir the moment it finishes, and is skipped if
# already there, so a crash or a kill never costs more than the combo in flight. The merged table
# is rebuilt from those parts at the end (or with --merge-only). The full national run is ~1 day.
#
# File layout expected in --data (from THREDDS, script 14):
#   {tasmax,tasmin}_SP-005_<MODEL>_<scenario>_ESD-RegBA_day.nc   (3460 stations, degC)
# Observed (optional, --obs): the archive files tasmax_obs.nc / tasmin_obs.nc (own 3044-station set).
#
# Window sets, selected with --windows:
#   default  historical reference 1985-2014, futures 2041-2070 (near) and 2071-2100 (far), plus the
#            observed baseline 1991-2020 when --obs is given.
#   present  1995-2020 baseline for the models, SPLICED from the historical run (to 2014) and an SSP
#            (from 2015), because the CMIP6 historical experiment stops in 2014. It matches the
#            observed period exactly, so model bias can be read without a period mismatch.
#            Scenarios barely diverge before 2020, so it is computed once per model.
#   near     2021-2040, the IPCC AR6 near-term. Fills the 2015-2040 stretch that the default set
#            leaves unanalysed even though the SSP files cover it.
# Together with the default futures these tile 1995-2100 with no gaps and no overlaps.
# Season: JDay 305-59 (1 Nov - 28 Feb), P10 across seasons.
#
# --per-season replaces the P10 aggregate with one row per season, carrying Perc_complete. It exists
# to compare this archive against another observed source (the AEMET API record) season by season:
# the P10 of a station with 12 seasons is close to its coldest winter while the P10 of one with 26 is
# a genuine decile, so comparing aggregates across sources of unequal length measures sample size as
# much as climate. Joining on the seasons the two sources share removes that artefact entirely.
#
# Usage (Ladon):
#   Rscript 15_chill_national_parallel.R --data <dir> --obs <dir> --check          # pre-flight, no compute
#   Rscript 15_chill_national_parallel.R --data <dir> --obs <dir> --maxst 40 ...   # smoke test, own paths
#   nohup Rscript 15_chill_national_parallel.R --data <dir> --obs <dir> --cores 10 > chill.log 2>&1 &
#   Rscript 15_chill_national_parallel.R --obs <dir> --windows obs --per-season \
#         --outdir chill_parts_obs_seasons --out chill_obs_seasons.csv --cores 10
#   Rscript 15_chill_national_parallel.R --obs <dir> --windows obs --per-season --years 1975,2020 \
#         --outdir chill_parts_obs_seasons_long --out chill_obs_seasons_1975.csv --cores 10
#   nohup Rscript 15_chill_national_parallel.R --data <dir> --windows present --outdir parts_present \
#         --out chill_present.csv --cores 10 > chill_present.log 2>&1 &
#   nohup Rscript 15_chill_national_parallel.R --data <dir> --windows near --outdir parts_near \
#         --out chill_near.csv --cores 10 > chill_near.log 2>&1 &
#   Rscript 15_chill_national_parallel.R --merge-only --outdir <dir> --out <csv>   # rebuild the table
#
# Requires: chillR, data.table, ncdf4, parallel. DM_JOSE.R next to this script (or in getwd()).
# ---------------------------------------------------------------------------------------

suppressWarnings(suppressMessages({
  library(chillR); library(data.table); library(ncdf4); library(parallel)
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
hasflag <- function(flag) flag %in% args
DATA   <- getarg("--data")
OBS    <- getarg("--obs", NA)
NCORES <- as.integer(getarg("--cores", max(1, detectCores() - 2)))
MAXST  <- as.numeric(getarg("--maxst", Inf))    # cap stations for a quick test
CHECK  <- hasflag("--check")                    # open every file, report structure, compute nothing
MERGE_ONLY <- hasflag("--merge-only")           # rebuild the merged csv from --outdir and exit
PER_SEASON <- hasflag("--per-season")           # one row per season instead of the P10 aggregate

# A --maxst smoke test must never be able to write where the real run reads: a 25-station part is
# indistinguishable from a complete one, and the resume would skip that combo forever and ship a
# national table holding 25 stations for it. The observed baseline is a single combo, so one smoke
# test would wipe the whole reference layer. Hence --maxst dictates its own paths and ignores
# --out/--outdir, rather than trusting whoever launches it to remember.
OUT    <- if (is.finite(MAXST)) sprintf("chill_maxst%g.csv", MAXST) else
          getarg("--out", if (PER_SEASON) "chill_seasons.csv" else "chill_national.csv")
OUTDIR <- if (is.finite(MAXST)) sprintf("chill_parts_maxst%g", MAXST) else
          getarg("--outdir", if (PER_SEASON) "chill_parts_seasons" else "chill_parts")

# print warnings as they happen: mclapply's "core N did not deliver a result" is otherwise buffered
# to the end of main() and would surface a day late, collapsed into "There were 50 or more warnings"
options(warn = 1)

# portable parallel map: fork on Linux/Ladon, serial on Windows (only used for local testing)
pmap <- if (.Platform$OS.type == "windows") function(X, FUN) lapply(X, FUN) else function(X, FUN) mclapply(X, FUN, mc.cores = NCORES)

# DM_JOSE.R lives next to this script (Rscript --file=) or in the working directory
.script_dir <- function() {
  a <- commandArgs(FALSE); f <- grep("^--file=", a, value = TRUE)
  if (length(f)) return(dirname(normalizePath(sub("^--file=", "", f[1]))))
  getwd()
}
src <- file.path(.script_dir(), "DM_JOSE.R")
if (!file.exists(src)) src <- "DM_JOSE.R"
source(src)

ALL_MODELS <- c("ACCESS-CM2","CMCC-CM2-SR5","CNRM-ESM2-1","EC-Earth3-Veg","IITM-ESM","KACE-1-0-G",
                "MIROC6","MPI-ESM1-2-HR","MRI-ESM2-0","NorESM2-MM","UKESM1-0-LL")
ALL_SCEN   <- c("historical", "ssp126", "ssp245", "ssp370")
MODELS <- if (!is.null(getarg("--models"))) strsplit(getarg("--models"), ",")[[1]] else ALL_MODELS
SCEN   <- if (!is.null(getarg("--scenarios"))) strsplit(getarg("--scenarios"), ",")[[1]] else ALL_SCEN

START_JDAY <- 305L; END_JDAY <- 59L; MIN_PERC <- 85
MAX_NA_FRAC <- 0.4          # skip stations that are mostly gaps (or masked fill values)
T_PHYS <- c(-90, 70)        # degC range used to catch undeclared fill values
# target windows per scenario: name -> c(year_min, year_max) of the season End_year
WIN_HIST <- list(ref  = c(1985, 2014))
WIN_SSP  <- list(near = c(2041, 2070), far = c(2071, 2100))
WIN_OBS  <- list(obsref = c(1991, 2020))
# The four analysis windows tile 1995-2100 without gaps or overlaps. 2021-2040 is the IPCC AR6
# near-term definition and is 20 seasons long, matching the horizon length Egea et al. 2022 used;
# anything shorter makes the P10 rest on one or two seasons.
WIN_PRESENT <- list(present  = c(1995, 2020))   # baseline, spliced historical + SSP across 2014/2015
WIN_NEAR    <- list(nearterm = c(2021, 2040))   # AR6 near-term, entirely inside the SSP files
# The most recent climate the models can describe, for the opening panel. It deliberately sits
# OUTSIDE the tiled series: it overlaps 2021-2040 by five years, so it must never be used as the
# reference the future windows are differenced against or a quarter of the near-term change would
# cancel itself by construction.
WIN_CURRENT <- list(current = c(1995, 2025))

WINDOWS <- getarg("--windows", "default")       # default | present | near | obs | current
if (!WINDOWS %in% c("default", "present", "near", "obs", "current"))
  stop("--windows must be default, present, near, obs or current")

# --years y0,y1 overrides the bounds of the selected window, so a different span can be asked for
# without adding a mode per question (the observed archive starts in 1975, which gives a 46-season
# baseline instead of 26 and a much better idea of whether a recent run of mild winters is unusual).
# It is refused on the default set, which holds several windows at once and has no single span to
# override. The years travel in the checkpoint tag for the reason set out at combo_path().
YEARS <- getarg("--years", NA_character_)
if (!is.na(YEARS) && WINDOWS == "default")
  stop("--years needs a single-window mode (obs, present, near or current), not the default set")
parse_years <- function(s) {
  yy <- suppressWarnings(as.integer(strsplit(s, ",")[[1]]))
  if (length(yy) != 2 || anyNA(yy) || yy[1] >= yy[2]) stop("--years expects y0,y1 with y0 < y1")
  yy
}
apply_years <- function(win) {
  if (is.na(YEARS)) return(win)
  yy <- parse_years(YEARS)
  setNames(list(yy), sprintf("%s_%d_%d", names(win)[1], yy[1], yy[2]))
}
# The historical run ends in 2014, so the 1991-2020 normal has to be completed with an SSP from 2015.
# Before 2020 the scenarios have barely separated, so it is taken from one of them and computed once
# per model rather than three times; the choice is recorded in the output as scenario "presente".
SPLICE_SCEN <- getarg("--splice-scenario", "ssp245")

# --- CF time decoding --------------------------------------------------------------------
# Time is not always in days: THREDDS uses "days since 1850-01-01" but the AEMET archive uses
# "hours since 1900-01-01", so the unit is parsed instead of assumed (reading hours as days sent
# every archive date 24x into the future and emptied the window). Stamps sit at midday in the
# archive files, hence the floor.
parse_time_units <- function(units) {
  u <- tolower(trimws(units))
  unit <- sub("^([a-z]+).*$", "\\1", u)
  scale <- switch(unit,
    day = 1, days = 1, hour = 1/24, hours = 1/24,
    minute = 1/1440, minutes = 1/1440, second = 1/86400, seconds = 1/86400,
    stop(sprintf("unsupported time unit: '%s' (from '%s')", unit, units)))
  origin <- as.Date(substr(trimws(sub("^[a-z]+\\s+since\\s+", "", u)), 1, 10))
  if (is.na(origin)) stop(sprintf("unreadable time origin: '%s'", units))
  list(scale = scale, origin = origin, unit = unit)
}

# CMIP6 models may use non-Gregorian calendars; as.Date() would silently mis-date them. All 11
# models of this archive declare 'standard', so the other branches are only a safety net. 360_day
# has no Gregorian equivalent and is remapped monotonically onto a 365-day year (<=5-day shift,
# negligible for winter chill; fix_weather fills the small gaps left).
decode_time <- function(tv, units, calendar) {
  cal <- tolower(if (is.null(calendar) || is.na(calendar) || calendar == "") "standard" else calendar)
  tu <- parse_time_units(units)
  days <- floor(tv * tu$scale + 1e-6)
  oy <- as.integer(format(tu$origin, "%Y"))
  if (cal %in% c("standard", "gregorian", "proleptic_gregorian", "julian")) {
    d <- as.Date(days, origin = tu$origin)
    return(list(Year = as.integer(format(d, "%Y")), Month = as.integer(format(d, "%m")), Day = as.integer(format(d, "%d"))))
  }
  tot <- as.integer(days)
  if (cal %in% c("noleap", "365_day", "365day", "no_leap")) {
    cum <- cumsum(c(0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30))   # month-start day offsets (365-day)
    Year <- oy + tot %/% 365L; doy <- tot %% 365L
    Month <- findInterval(doy, cum); Day <- doy - cum[Month] + 1L
    return(list(Year = Year, Month = as.integer(Month), Day = as.integer(Day)))
  }
  if (cal %in% c("360_day", "360day")) {
    Year <- oy + tot %/% 360L; doy360 <- tot %% 360L
    doy365 <- pmin(365L, pmax(1L, as.integer(round((doy360 + 0.5) * 365 / 360))))
    d <- as.Date(paste0(Year, "-01-01")) + (doy365 - 1L)
    return(list(Year = as.integer(format(d, "%Y")), Month = as.integer(format(d, "%m")), Day = as.integer(format(d, "%d"))))
  }
  stop(paste("unsupported calendar:", cal))
}

# --- NetCDF reader -----------------------------------------------------------------------
# Station ids come from a char 'station_id' variable in the archive files and from the 'station'
# coordinate variable in the THREDDS ones; in the archive 'station' is a dimension with no dimvar,
# which is what ncvar_get(nc, "station") died on.
station_ids <- function(nc) {
  vn <- names(nc$var)
  if ("station_id" %in% vn) return(trimws(as.character(ncvar_get(nc, "station_id"))))
  if (isTRUE(nc$dim[["station"]]$create_dimvar)) return(trimws(as.character(ncvar_get(nc, "station"))))
  as.character(seq_len(nc$dim[["station"]]$len))   # last resort: positional ids
}

# Report a file's layout without reading any data (used by --check).
nc_structure <- function(file) {
  nc <- nc_open(file); on.exit(nc_close(nc))
  tvar <- grep("^tas", names(nc$var), value = TRUE)[1]
  dn <- vapply(nc$var[[tvar]]$dim, function(x) x$name, "")
  tv <- nc$dim[["time"]]$vals
  ca <- ncatt_get(nc, "time", "calendar"); cal <- if (isTRUE(ca$hasatt)) ca$value else "standard"
  dt <- decode_time(range(tv), nc$dim[["time"]]$units, cal)
  list(var = tvar, dims = paste(dn, collapse = " x "), n_station = nc$dim[["station"]]$len,
       n_time = nc$dim[["time"]]$len, id_src = if ("station_id" %in% names(nc$var)) "station_id" else "station dimvar",
       units = nc$dim[["time"]]$units, calendar = cal, years = paste(dt$Year, collapse = "-"))
}

# Read one variable file into station ids/coords + a [time x station] matrix, keeping only the days
# within [ymin, ymax] so the data shared with the workers stays small.
read_var <- function(file, ymin, ymax) {
  nc <- nc_open(file)
  on.exit(nc_close(nc))
  sid <- station_ids(nc)
  lon <- as.numeric(ncvar_get(nc, "lon")); lat <- as.numeric(ncvar_get(nc, "lat"))
  tv <- nc$dim[["time"]]$vals
  ca <- ncatt_get(nc, "time", "calendar"); cal <- if (isTRUE(ca$hasatt)) ca$value else "standard"
  dt <- decode_time(tv, nc$dim[["time"]]$units, cal)
  keep <- which(dt$Year >= ymin & dt$Year <= ymax)
  if (!length(keep)) stop(sprintf("no days within %d-%d in %s", ymin, ymax, basename(file)))
  k0 <- min(keep); k1 <- max(keep); idx <- k0:k1   # the time axis is monotonic, so the window is contiguous

  var <- grep("^tas", names(nc$var), value = TRUE)[1]
  dn <- vapply(nc$var[[var]]$dim, function(x) x$name, "")
  ti <- match("time", dn); si <- match("station", dn)
  if (is.na(ti) || is.na(si)) stop(sprintf("%s: expected time and station dims, found [%s]", basename(file), paste(dn, collapse = ", ")))
  start <- rep(1L, length(dn)); count <- rep(-1L, length(dn))
  start[ti] <- k0; count[ti] <- length(idx)
  mat <- ncvar_get(nc, var, start = start, count = count, collapse_degen = FALSE)
  if (si < ti) mat <- t(mat)          # archive files are [station x time]; normalise to [time x station]
  dim(mat) <- c(length(idx), length(sid))

  # The physical range below is in Celsius, so the unit has to be read rather than assumed. CMIP6's
  # native unit is Kelvin, and a Kelvin file would put every value above the upper bound: the mask
  # would turn the whole matrix into NA, MAX_NA_FRAC would drop every station, and the combo would
  # report "no results" as though the stations were the problem. Both families this script reads
  # happen to ship degC, which is exactly why the assumption would go unnoticed until it did not.
  ua <- ncatt_get(nc, var, "units")
  un <- tolower(trimws(if (isTRUE(ua$hasatt)) ua$value else ""))
  if (un %in% c("k", "kelvin", "degk", "deg_k")) {
    mat <- mat - 273.15
  } else if (!un %in% c("degc", "celsius", "c", "degree_celsius", "degrees_celsius", "deg_c", "")) {
    stop(sprintf("%s: unexpected temperature unit '%s'; expected degC or K", basename(file), ua$value))
  }
  if (!nzchar(un)) warning(sprintf("%s: variable has no units attribute, assuming degC", basename(file)))

  # some models (CMCC, KACE, NorESM, UKESM) carry -999 fill values NOT declared as _FillValue,
  # so ncdf4 reads them as real -999 degC. Mask anything outside a physical range to NA.
  mat[mat < T_PHYS[1] | mat > T_PHYS[2]] <- NA
  list(sid = sid, lon = lon, lat = lat, calendar = cal,
       Year = dt$Year[idx], Month = dt$Month[idx], Day = dt$Day[idx], mat = mat)
}

# Locate a variable file by content of its name rather than by a fixed template, because the two
# sources name them differently: THREDDS uses tasmax_SP-005_<MODEL>_<scenario>_ESD-RegBA_day.nc and
# the web-form archive uses tasmax_<MODEL>_r1i1p1f1_<scenario>_ESD-RegBA.nc. Matching on the tokens
# keeps the same script usable against either, which is what allows the splice to be tested locally.
find_var_file <- function(dir, var, model, scenario) {
  f <- list.files(dir, pattern = "\\.nc$", full.names = TRUE)
  hit <- f[startsWith(basename(f), paste0(var, "_")) &
           grepl(model, basename(f), fixed = TRUE) &
           grepl(paste0("_", scenario, "_"), basename(f), fixed = TRUE)]
  if (length(hit) != 1) return(NA_character_)
  hit
}

# Read a series that crosses the 2014/2015 boundary by joining the historical run to an SSP.
# The CMIP6 historical experiment stops in 2014 by design, so any present-day window that reaches
# past it (the 1991-2020 normal) does not exist in a single file and has to be assembled.
read_var_spliced <- function(dir, var, model, scen_future, ymin, ymax) {
  parts <- list()
  if (ymin <= 2014) {
    fh <- find_var_file(dir, var, model, "historical")
    if (is.na(fh)) stop(sprintf("no historical file for %s %s in %s", var, model, dir))
    parts[[1]] <- read_var(fh, ymin, min(ymax, 2014))
  }
  if (ymax >= 2015) {
    fs <- find_var_file(dir, var, model, scen_future)
    if (is.na(fs)) stop(sprintf("no %s file for %s %s in %s", scen_future, var, model, dir))
    parts[[length(parts) + 1]] <- read_var(fs, max(ymin, 2015), ymax)
  }
  if (length(parts) == 1) return(parts[[1]])
  a <- parts[[1]]; b <- parts[[2]]
  if (!identical(a$sid, b$sid)) stop(sprintf("%s %s: historical and %s carry different station sets", var, model, scen_future))
  list(sid = a$sid, lon = a$lon, lat = a$lat, calendar = a$calendar,
       Year = c(a$Year, b$Year), Month = c(a$Month, b$Month), Day = c(a$Day, b$Day),
       mat = rbind(a$mat, b$mat))
}

# --- per-station chill over the requested windows ----------------------------------------
chill_station <- function(df, lat, windows) {
  tryCatch({
    # skip stations that are mostly masked (whole -999 periods): avoids garbage chill and hangs
    if (mean(is.na(df$Tmax)) > MAX_NA_FRAC || mean(is.na(df$Tmin)) > MAX_NA_FRAC) return(NULL)
    weather <- fix_weather(df, end_at_present = FALSE)   # future dates need end_at_present=FALSE
    tr <- tempResponse_daily_list(list(weather), latitude = lat, Start_JDay = START_JDAY, End_JDay = END_JDAY,
            models = list(Utah_Chill_Units = Utah_Model, Chill_Portions = DM_JOSE))[[1]]
    # Season-level output: one row per season, labelled with the window it falls in, instead of the
    # P10 aggregate. Seasons are deliberately NOT filtered by Perc_complete here; the completeness
    # travels in the table so that a comparison against another source can apply a single identical
    # filter to both sides. Filtering here would let each source drop a different set of seasons
    # before they are ever joined, which is the artefact this mode exists to avoid.
    if (PER_SEASON) {
      lab <- rep(NA_character_, nrow(tr))
      for (wn in names(windows)) {
        yr <- windows[[wn]]
        lab[tr$End_year >= yr[1] & tr$End_year <= yr[2]] <- wn
      }
      sel <- !is.na(lab)
      if (!any(sel)) return(NULL)
      return(data.table(window = lab[sel],
                        season_end_year = as.integer(tr$End_year[sel]),
                        perc_complete   = round(as.numeric(tr$Perc_complete[sel]), 1),
                        CP              = round(as.numeric(tr$Chill_Portions[sel]), 2),
                        Utah            = round(as.numeric(tr$Utah_Chill_Units[sel]), 1)))
    }
    tr <- tr[tr$Perc_complete >= MIN_PERC, ]
    rows <- list()
    for (wn in names(windows)) {
      yr <- windows[[wn]]; sel <- tr$End_year >= yr[1] & tr$End_year <= yr[2]
      cp <- tr$Chill_Portions[sel]; ut <- tr$Utah_Chill_Units[sel]
      if (length(cp) >= 3)
        rows[[wn]] <- data.table(window = wn, n_seasons = length(cp),
          mean_CP = round(mean(cp), 2), safe_winter_chill_P10 = round(as.numeric(quantile(cp, .10, names = FALSE)), 2),
          mean_Utah = round(mean(ut), 1), utah_P10 = round(as.numeric(quantile(ut, .10, names = FALSE)), 1))
    }
    if (length(rows)) rbindlist(rows) else NULL
  # A swallowed message makes a systematic failure (a chillR API change, a renamed column, an NA
  # latitude) look exactly like a station legitimately dropped for gaps, and the national run takes
  # a day to reach that conclusion. Errors come back as a string, legitimate skips as NULL, so the
  # caller can tell them apart and count the distinct causes before checkpointing anything.
  }, error = function(e) conditionMessage(e))
}

# Station loop shared by the file-based and the spliced paths: both arrive here with tasmax and
# tasmin already read into [time x station] matrices.
process_stations <- function(tx, tn, scenario, model, windows) {
  if (!identical(tx$sid, tn$sid)) stop(sprintf("%s %s: tasmax and tasmin station sets differ", scenario, model))
  if (length(tx$Year) != length(tn$Year)) stop(sprintf("%s %s: tasmax and tasmin time axes differ", scenario, model))
  nst <- length(tx$sid); stations <- if (is.finite(MAXST)) seq_len(min(nst, MAXST)) else seq_len(nst)
  res <- pmap(stations, function(s) {
    df <- data.frame(Year = tx$Year, Month = tx$Month, Day = tx$Day, Tmax = tx$mat[, s], Tmin = tn$mat[, s])
    r <- chill_station(df, tx$lat[s], windows)
    if (is.character(r)) return(list(ok = TRUE, dt = NULL, err = r))   # computation failed
    if (is.null(r)) return(list(ok = TRUE, dt = NULL, err = NULL))     # skipped (gaps/fill values)
    r[, `:=`(scenario = scenario, model = model, station_id = tx$sid[s], lon = tx$lon[s], lat = tx$lat[s])]
    list(ok = TRUE, dt = r)
  })
  # A fork that dies (kernel OOM kill, node event) does not raise an error: mclapply warns and fills
  # that worker's whole ~350-station stripe with NULLs. Without the ok sentinel those NULLs are
  # indistinguishable from stations skipped above, so the combo would be checkpointed ~10% short and
  # the resume would trust it forever -- and a short count looks plausible for the four models that
  # really do lose stations to the undeclared -999. Anything not carrying ok=TRUE means the stripe
  # never ran, so refuse the combo and let the next run redo it.
  bad <- which(!vapply(res, function(x) is.list(x) && isTRUE(x$ok), NA))
  if (length(bad)) stop(sprintf("%d/%d stations lost to a dead or errored worker stripe; refusing to checkpoint a truncated combo",
                                length(bad), length(stations)))
  # Errors are surfaced, and a combo where the computation failed everywhere is refused rather than
  # written: an empty part is indistinguishable from a legitimate one once it is on disk, and the
  # resume would trust it forever.
  errs <- unlist(lapply(res, `[[`, "err"))
  if (length(errs)) {
    tb <- sort(table(errs), decreasing = TRUE)
    cat(sprintf("  %d/%d stations failed to compute; distinct causes:\n", length(errs), length(stations)))
    for (i in seq_len(min(3L, length(tb))))
      cat(sprintf("    %4d x %s\n", tb[i], substr(names(tb)[i], 1, 90)))
    if (length(errs) == length(stations))
      stop(sprintf("every station failed (%s); refusing to checkpoint an empty combo", names(tb)[1]))
  }
  dt <- rbindlist(Filter(Negate(is.null), lapply(res, `[[`, "dt")))
  setattr(dt, "n_attempted", length(stations))   # so the log can show delivered/attempted
  dt
}

# Resolve a variable file: the expected THREDDS name first, then a token search, so the same run
# works whether the inputs came from THREDDS or from the web-form archive, which name them
# differently. Without the fallback the run and the splice would disagree about where files are.
resolve_var_file <- function(dir, prefix, var, model, scenario) {
  p <- file.path(dir, prefix)
  if (file.exists(p)) return(p)
  find_var_file(dir, var, model, scenario)
}

# one scenario x model from a single pair of files
process_combo <- function(dir, prefix_tmax, prefix_tmin, scenario, model, windows, ymin, ymax) {
  ftx <- resolve_var_file(dir, prefix_tmax, "tasmax", model, scenario)
  ftn <- resolve_var_file(dir, prefix_tmin, "tasmin", model, scenario)
  if (is.na(ftx) || is.na(ftn)) { cat("  missing file:", scenario, model, "\n"); return(NULL) }
  process_stations(read_var(ftx, ymin, ymax), read_var(ftn, ymin, ymax), scenario, model, windows)
}

# one model, series assembled across the 2014/2015 boundary
process_combo_spliced <- function(dir, model, scen_future, windows, ymin, ymax) {
  tx <- read_var_spliced(dir, "tasmax", model, scen_future, ymin, ymax)
  tn <- read_var_spliced(dir, "tasmin", model, scen_future, ymin, ymax)
  process_stations(tx, tn, "presente", model, windows)
}

# --- checkpointing -----------------------------------------------------------------------
# One csv per scenario x model, written as soon as the combo ends. A re-run skips whatever is
# already on disk, so an interrupted national run resumes instead of starting over.
#
# The window set is part of the name for everything except the default set, whose parts already
# exist on disk under the old name and must keep being recognised. Without this tag a run of a
# different window set pointed at an existing parts directory would find <scenario>__<model>.csv,
# report "skipped, already done" and silently return the wrong period: the resume cannot tell two
# window sets apart from the scenario and model alone.
#
# --per-season changes what a part holds without changing which combo it is, so it carries its own
# tag for the same reason: a season-level part and an aggregate part of the same window would
# otherwise share a filename, and the resume would hand back a table of the wrong shape.
window_tag <- function() {
  t <- if (PER_SEASON) paste0(WINDOWS, "-seasons") else WINDOWS
  if (!is.na(YEARS)) t <- paste0(t, "-", gsub(",", "_", YEARS, fixed = TRUE))
  t
}

combo_path <- function(scenario, model) {
  f <- if (WINDOWS == "default" && !PER_SEASON) sprintf("%s__%s.csv", scenario, model)
       else sprintf("%s__%s__%s.csv", window_tag(), scenario, model)
  file.path(OUTDIR, f)
}

# make() is whatever produces the combo's table, so the checkpoint, resume, atomic write and logging
# below are shared by the file-based and the spliced paths instead of being duplicated.
run_labelled <- function(scenario, model, windows, make, t0) {
  f <- combo_path(scenario, model)
  if (file.exists(f) && file.info(f)$size > 0) {
    cat(sprintf("[%s | %-14s] skipped, already done\n", scenario, model)); return(invisible(NULL))
  }
  r <- tryCatch(make(),
                error = function(e) { cat(sprintf("[%s | %-14s] ERROR: %s\n", scenario, model, conditionMessage(e))); NULL })
  if (is.null(r) || !nrow(r)) { cat(sprintf("[%s | %-14s] no results\n", scenario, model)); return(invisible(NULL)) }
  # write to a temp path and rename so a part is either absent or complete, never a truncated prefix
  # that the resume would accept as done (rename is atomic within a filesystem, and the .tmp suffix
  # keeps any leftover out of merge_parts' *.csv glob)
  tmp <- paste0(f, ".tmp")
  fwrite(r, tmp)
  if (!file.rename(tmp, f)) stop(sprintf("%s %s: could not rename %s -> %s", scenario, model, tmp, f))
  cat(sprintf("[%s | %-14s] %d/%d stations x %s  (%.1f min)\n", scenario, model,
              uniqueN(r$station_id), attr(r, "n_attempted"),
              if (PER_SEASON) sprintf("%d seasons", nrow(r)) else sprintf("%d windows", length(windows)),
              as.numeric(difftime(Sys.time(), t0, units = "mins"))))
  invisible(NULL)
}

run_combo <- function(dir, prefix_tmax, prefix_tmin, scenario, model, windows, ymin, ymax, t0) {
  run_labelled(scenario, model, windows,
               function() process_combo(dir, prefix_tmax, prefix_tmin, scenario, model, windows, ymin, ymax), t0)
}

run_combo_spliced <- function(dir, model, scen_future, windows, ymin, ymax, t0) {
  run_labelled("presente", model, windows,
               function() process_combo_spliced(dir, model, scen_future, windows, ymin, ymax), t0)
}

# The glob is filtered by the same tag the checkpoints are named with. Taking every csv in the
# directory would silently merge two window sets, or per-season parts with aggregate ones, into a
# table half of whose columns are NA: fill = TRUE makes that succeed quietly, which is worse than
# failing. The default set keeps its legacy unprefixed names, so it matches on those instead.
merge_parts <- function() {
  pat <- if (WINDOWS == "default" && !PER_SEASON) "^[a-z]+__[^_]+.*\\.csv$"
         else sprintf("^%s__.*\\.csv$", window_tag())
  parts <- list.files(OUTDIR, pattern = pat, full.names = TRUE)
  if (!length(parts)) { cat("nothing to merge in", OUTDIR, "\n"); return(invisible(NULL)) }
  cols <- lapply(parts, function(p) names(fread(p, nrows = 0)))
  if (length(unique(lapply(cols, sort))) > 1)
    stop(sprintf("the parts in %s do not share a column set; two different runs wrote there", OUTDIR))
  final <- rbindlist(lapply(parts, fread), use.names = TRUE, fill = TRUE)
  setcolorder(final, c("scenario", "model", "station_id", "lon", "lat", "window"))
  fwrite(final, OUT)
  cat(sprintf("\nwrote %s: %d rows, %d stations, from %d parts\n", OUT, nrow(final), uniqueN(final$station_id), length(parts)))
}

# --- driver ------------------------------------------------------------------------------
main <- function() {
  if (MERGE_ONLY) { merge_parts(); return(invisible(NULL)) }
  if (is.null(DATA)) stop("missing --data <dir with the .nc files>")

  # pre-flight: open every file and report its layout, without computing anything. Cheap (headers
  # only) and it catches a structural surprise in seconds instead of a day into the run.
  if (CHECK) {
    cat("pre-flight check: every file the run will open, structure only, no compute\n")
    todo <- list()
    add <- function(dir, f, tag) todo[[length(todo) + 1]] <<- list(dir = dir, f = f, tag = tag)
    # both variables: the run reads tasmax AND tasmin, so checking tasmax alone would wave through
    # a half-broken input set
    if (!is.na(OBS)) for (v in c("tasmax", "tasmin")) add(OBS, sprintf("%s_obs.nc", v), sprintf("observaciones | obs | %s", v))
    for (scen in SCEN) for (mo in MODELS) for (v in c("tasmax", "tasmin"))
      add(DATA, sprintf("%s_SP-005_%s_%s_ESD-RegBA_day.nc", v, mo, scen), sprintf("%s | %s | %s", scen, mo, v))
    bad <- 0L
    for (it in todo) {
      p <- file.path(it$dir, it$f)
      if (!file.exists(p)) { cat(sprintf("  [%-32s] MISSING %s\n", it$tag, it$f)); bad <- bad + 1L; next }
      s <- tryCatch(nc_structure(p), error = function(e) conditionMessage(e))
      if (is.character(s)) { cat(sprintf("  [%-32s] UNREADABLE %s: %s\n", it$tag, it$f, s)); bad <- bad + 1L; next }
      cat(sprintf("  [%-32s] %s [%s] %d st, %d days, ids=%s, %s, %s\n",
                  it$tag, s$var, s$dims, s$n_station, s$n_time, s$id_src, s$years, s$calendar))
    }
    cat(sprintf("\n%d files checked, %d unusable\n", length(todo), bad))
    return(invisible(NULL))
  }

  dir.create(OUTDIR, showWarnings = FALSE, recursive = TRUE)
  cat(sprintf("cores=%d, parts=%s, out=%s\n", NCORES, OUTDIR, OUT))
  t0 <- Sys.time()

  span <- function(win) { yy <- range(unlist(win)); c(yy[1] - 1, yy[2] + 1) }   # +-1 for season boundaries

  if (WINDOWS == "present") {
    # 1991-2020 normal for the models, spliced across the 2014/2015 break. One run per model: the
    # scenarios have not separated by 2020, so computing it three times would triple the cost for
    # differences far below the model spread.
    win <- apply_years(WIN_PRESENT)
    cat(sprintf("ventana presente %d-%d, empalme historical + %s, %d modelos\n",
                win[[1]][1], win[[1]][2], SPLICE_SCEN, length(MODELS)))
    yy <- span(win)
    for (mo in MODELS) run_combo_spliced(DATA, mo, SPLICE_SCEN, win, yy[1], yy[2], t0)

  } else if (WINDOWS == "current") {
    # Same splice as the present baseline, carried to 2025: the most recent 31 years the models
    # cover. Used to open the talk, not to difference the futures against (see WIN_CURRENT).
    win <- apply_years(WIN_CURRENT)
    cat(sprintf("clima actual %d-%d, empalme historical + %s, %d modelos\n",
                win[[1]][1], win[[1]][2], SPLICE_SCEN, length(MODELS)))
    yy <- span(win)
    for (mo in MODELS) run_combo_spliced(DATA, mo, SPLICE_SCEN, win, yy[1], yy[2], t0)

  } else if (WINDOWS == "obs") {
    # The observed on the SAME window as the spliced present. The default set computed it over
    # 1991-2020, so comparing it against a 1995-2020 model baseline would fold a four-year period
    # difference into what is supposed to be a pure model-bias figure.
    if (is.na(OBS)) stop("--windows obs needs --obs <dir>")
    win <- apply_years(WIN_PRESENT)
    yy <- span(win)
    cat(sprintf("observado sobre %d-%d%s\n", win[[1]][1], win[[1]][2],
                if (is.na(YEARS)) ", la ventana del presente simulado" else ", ventana pedida con --years"))
    run_combo(OBS, "tasmax_obs.nc", "tasmin_obs.nc", "observaciones", "obs", win, yy[1], yy[2], t0)

  } else if (WINDOWS == "near") {
    # 2021-2050, the stretch the default set left unanalysed. Entirely inside the SSP files.
    win <- apply_years(WIN_NEAR)
    cat(sprintf("ventana %d-%d, %d escenarios x %d modelos\n", win[[1]][1], win[[1]][2],
                length(setdiff(SCEN, "historical")), length(MODELS)))
    yy <- span(win)
    for (scen in setdiff(SCEN, "historical")) for (mo in MODELS) {
      tag <- sprintf("SP-005_%s_%s_ESD-RegBA_day.nc", mo, scen)
      run_combo(DATA, paste0("tasmax_", tag), paste0("tasmin_", tag), scen, mo, win, yy[1], yy[2], t0)
    }

  } else {
    # observed first: it is one cheap combo and it exercises the other NetCDF layout, so a structural
    # problem shows up in minutes rather than after the ~23 h of projections
    if (!is.na(OBS)) {
      yy <- span(WIN_OBS)
      run_combo(OBS, "tasmax_obs.nc", "tasmin_obs.nc", "observaciones", "obs", WIN_OBS, yy[1], yy[2], t0)
    }
    # historical (reference window) + the 3 SSP (near + far)
    for (scen in SCEN) {
      win <- if (scen == "historical") WIN_HIST else WIN_SSP
      yy <- span(win)
      for (mo in MODELS) {
        tag <- sprintf("SP-005_%s_%s_ESD-RegBA_day.nc", mo, scen)
        run_combo(DATA, paste0("tasmax_", tag), paste0("tasmin_", tag), scen, mo, win, yy[1], yy[2], t0)
      }
    }
  }

  merge_parts()
  cat(sprintf("total %.1f min\n", as.numeric(difftime(Sys.time(), t0, units = "mins"))))
}

if (sys.nframe() == 0L) main()
