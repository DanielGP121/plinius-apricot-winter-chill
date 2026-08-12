#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------------------
# Winter-chill computation for the Murcia test-run (compute engine).
#
# Purpose: turn the PNACC daily Tmin/Tmax slice into Safe Winter Chill per station, scenario
# and model, using J.A. Egea's exact method (plan sect. 2.6): fix_weather + tempResponse_daily_list
# with the DM_JOSE dynamic model (1987 parametrisation, sourced from DM_JOSE.R) plus Utah units.
# This differs from chillR's default Dynamic_Model (1988) and is the project reference. The same
# functions are reused headless (this file, run as a script or on Ladon) and by the figures
# report 08_chill_maps_murcia.Rmd, which sources this file so there is a single source of truth.
#
# Why it matters biologically: Safe Winter Chill (the 10th percentile of accumulated chill
# portions across seasons) is the number that decides whether a cultivar meets its chilling
# requirement. The case study asks where 'Bulida Precoz' (33.7 CP) still gets enough chill
# while 'Bulida' (47.5 CP) no longer does, so this is what turns temperature into that map.
#
# Input: the chill-format slice from 02_pnacc_to_tables.py --chill-format, i.e. one CSV per
# scenario with columns scenario, model, station_id, lon, lat, Year, Month, Day, Tmax, Tmin.
#
# Usage (headless):
#   Rscript 06_chill_murcia.R <slice_dir> <out_csv> [max_stations] [start_jday] [end_jday]
# Usage (from R / Rmd):
#   source("06_chill_murcia.R"); res <- compute_chill_table(slice_dir)
#
# Requires: R packages chillR and data.table.
# ---------------------------------------------------------------------------------------

suppressWarnings(suppressMessages({
  library(chillR)
  library(data.table)
}))

# Paths come from 00_paths.R: it derives the repository root from its own location, so these
# defaults no longer depend on the script being launched from inside 01_scripts/.
.f <- grep("^--file=", commandArgs(FALSE), value = TRUE)
source(file.path(if (length(.f)) dirname(normalizePath(sub("^--file=", "", .f[1]))) else getwd(), "00_paths.R"))

# DM_JOSE (Egea's 1987 dynamic model) lives next to this script; find that folder whether the
# file is run with Rscript (--file=) or sourced from the Rmd (ofile), then load it.
.script_dir <- function() {
  a <- commandArgs(FALSE); f <- grep("^--file=", a, value = TRUE)
  if (length(f)) return(dirname(normalizePath(sub("^--file=", "", f[1]))))
  of <- sys.frames()[[1]]$ofile
  if (!is.null(of)) return(dirname(normalizePath(of)))
  getwd()
}
source_dm_jose()

# season completeness gate: a season needs most of its days present to trust its chill sum
MIN_PERC_COMPLETE <- 85

CR_BULIDA_PRECOZ <- 33.7   # chill requirement (chill portions), low-chill mutant
CR_BULIDA        <- 47.5   # chill requirement, wild-type parent

# --- per-station chill --------------------------------------------------------------------
# One station's daily Tmin/Tmax -> hourly (latitude-based) -> per-season chill portions ->
# distribution summary. Wrapped so one pathological station cannot abort the whole run.
chill_for_station <- function(dt_station, lat, start_jday = 305L, end_jday = 59L) {
  w <- as.data.frame(dt_station[, .(Year, Month, Day, Tmax, Tmin)])
  tryCatch({
    # end_at_present=FALSE is essential: our series run into the future (SSP to 2100), and the
    # default (TRUE) makes fix_weather try to reconcile with "today" and fail on future dates.
    weather <- fix_weather(w, end_at_present = FALSE)   # chillR QC/gap-fill, as in Egea's script
    tr <- tempResponse_daily_list(list(weather), latitude = lat,
            Start_JDay = start_jday, End_JDay = end_jday,
            models = list(Utah_Chill_Units = Utah_Model, Chill_Portions = DM_JOSE))[[1]]
    tr <- tr[tr$Perc_complete >= MIN_PERC_COMPLETE, ]
    cp <- tr$Chill_Portions
    if (length(cp) < 3) return(NULL)   # too few seasons for a P10 to mean anything
    utah <- tr$Utah_Chill_Units
    list(n_seasons = length(cp), mean_CP = mean(cp), median_CP = median(cp),
         min_CP = min(cp), max_CP = max(cp),
         swc_p10 = as.numeric(quantile(cp, 0.10, names = FALSE)),
         mean_Utah = mean(utah), utah_p10 = as.numeric(quantile(utah, 0.10, names = FALSE)))
  }, error = function(e) NULL)
}

# --- driver -------------------------------------------------------------------------------
# Loop the slice (all scenario CSVs) and return a tidy chill table. max_stations caps the run
# for a quick validation pass; NULL/Inf uses every station.
compute_chill_table <- function(slice_dir, max_stations = Inf,
                                start_jday = 305L, end_jday = 59L, verbose = TRUE) {
  csv_files <- list.files(slice_dir, pattern = "\\.csv$", full.names = TRUE)
  if (length(csv_files) == 0) stop(paste("no hay CSV en", slice_dir))
  if (is.null(max_stations)) max_stations <- Inf

  out_rows <- list()
  for (f in csv_files) {
    dt <- fread(f)
    if (!"model" %in% names(dt)) dt[, model := "obs"]
    combos <- unique(dt[, .(scenario, model)])
    stations_all <- unique(dt$station_id)
    stations <- if (is.finite(max_stations)) head(stations_all, max_stations) else stations_all
    if (verbose) cat(sprintf("[%s] %d estaciones (%d en este run) x %d combos scenario-modelo\n",
                             basename(f), length(stations_all), length(stations), nrow(combos)))
    for (i in seq_len(nrow(combos))) {
      sc <- combos$scenario[i]; mo <- combos$model[i]
      sub <- dt[scenario == sc & model == mo & station_id %in% stations]
      for (st in stations) {
        ds <- sub[station_id == st]
        if (nrow(ds) == 0) next
        r <- chill_for_station(ds, ds$lat[1], start_jday, end_jday)
        if (is.null(r)) next
        out_rows[[length(out_rows) + 1]] <- data.table(
          scenario = sc, model = mo, station_id = st, lon = ds$lon[1], lat = ds$lat[1],
          n_seasons = r$n_seasons, mean_CP = round(r$mean_CP, 2),
          median_CP = round(r$median_CP, 2), min_CP = round(r$min_CP, 2),
          max_CP = round(r$max_CP, 2), safe_winter_chill_P10 = round(r$swc_p10, 2),
          mean_Utah = round(r$mean_Utah, 1), utah_P10 = round(r$utah_p10, 1))
      }
    }
  }
  if (length(out_rows) == 0) stop("no se calculo ninguna estacion (revisa el formato del slice)")
  rbindlist(out_rows)
}

# --- case-study summary -------------------------------------------------------------------
# Per scenario x model: median SWC across stations and the share of stations where each
# cultivar's chilling requirement is met (SWC >= CR). This is the headline the poster wants.
print_case_study <- function(res, start_jday, end_jday) {
  summ <- res[, .(
    n_est         = .N,
    swc_mediana   = round(median(safe_winter_chill_P10), 1),
    pct_ok_precoz = round(100 * mean(safe_winter_chill_P10 >= CR_BULIDA_PRECOZ), 0),
    pct_ok_bulida = round(100 * mean(safe_winter_chill_P10 >= CR_BULIDA), 0)
  ), by = .(scenario, model)][order(scenario, model)]
  cat("\n=== resumen por escenario x modelo (Safe Winter Chill, chill portions) ===\n")
  print(summ)
  cat(sprintf("\n(CR: Bulida Precoz %.1f CP, Bulida %.1f CP; season JDay %d..%d)\n",
              CR_BULIDA_PRECOZ, CR_BULIDA, start_jday, end_jday))
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 2) {
    stop("uso: Rscript 06_chill_murcia.R <slice_dir> <out_csv> [max_stations] [start_jday] [end_jday]")
  }
  slice_dir    <- args[[1]]
  out_csv      <- args[[2]]
  max_stations <- if (length(args) >= 3) as.numeric(args[[3]]) else Inf
  start_jday   <- if (length(args) >= 4) as.integer(args[[4]]) else 305L
  end_jday     <- if (length(args) >= 5) as.integer(args[[5]]) else 59L

  res <- compute_chill_table(slice_dir, max_stations, start_jday, end_jday)
  dir.create(dirname(out_csv), recursive = TRUE, showWarnings = FALSE)
  fwrite(res, out_csv)
  cat(sprintf("\nescrito %s (%d filas)\n", out_csv, nrow(res)))
  print_case_study(res, start_jday, end_jday)
}

# run main() only when executed as a script, not when sourced from the Rmd
if (sys.nframe() == 0L) main()
