#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------------------
# How much cropland is viable as a function of the chill requirement, for every situation.
#
# Everything the project reports rests on two numbers measured by somebody else: 47.5 and 33.7
# chill portions (Ruiz et al. 2019, Table 2), each with a standard error of 3.3. Two findings since
# then make their exact value the largest open uncertainty of the work:
#
#   the published standard error alone moves the "only Búlida Precoz" band from 5.6% to 18.2% of
#   stations, a factor of three; and
#
#   Muñoz-Morales et al. (2025), from the same group and with Ruiz as a coauthor, cite Fishman
#   et al. (1987) while running chillR's Dynamic_Model, which carries the 1988 parameters. Measured
#   at Cieza the two scales differ by 6.94 CP on average, half the gap between the cultivars
#   (script 27). If the requirements were quantified on the 1988 scale, every threshold used here
#   should sit about 7 CP higher.
#
# Rather than argue about the right value, this sweeps them. The interpolated chill surface does not
# depend on the thresholds at all, only the classification does, so one surface per situation gives
# the viable area at every threshold for free. Everything else follows from that single curve:
#
#   viable for a cultivar with requirement C  = F(C)
#   only the mutant                           = F(CR_precoz) - F(CR_bulida)
#   neither                                   = total - F(CR_precoz)
#
# Interpolation, cropland mask and ensemble handling are identical to 19_cropland_viability_national.R
# on purpose; this script answers a different question about the same surfaces, and any divergence
# between the two would make their numbers incomparable. As a check it recomputes the published
# figures at the official thresholds and refuses to write if they do not match.
#
# Outputs: cropland_threshold_sweep.csv (the curves) and cropland_threshold_check.csv.
#
# Usage:
#   Rscript 28_threshold_sweep_cropland.R
#   Rscript 28_threshold_sweep_cropland.R --quick --from 30 --to 60 --by 1
#
# Requires: terra, sf, mapSpain, data.table. CORINE 100 m raster on D:.
# ---------------------------------------------------------------------------------------

suppressWarnings(suppressMessages({
  library(terra); library(sf); library(mapSpain); library(data.table)
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
RES_M <- as.numeric(getarg("--res", 1000))
QUICK <- "--quick" %in% args
THR   <- seq(as.numeric(getarg("--from", 20)), as.numeric(getarg("--to", 75)),
             by = as.numeric(getarg("--by", 0.5)))

EPSG <- 3035
CR_B <- 47.5; CR_P <- 33.7          # official thresholds (Ruiz et al. 2019, Table 2)
SE   <- 3.3                         # their standard error, same for both cultivars
IDW_RADIUS <- 50000; IDW_POWER <- 2; IDW_NMAX <- 12
TOL <- 0.5                          # km2 tolerance against the published table

# Paths come from 00_paths.R: it derives the repository root from its own location and demands
# PLINIUS_DATA for anything that lives outside the repository.
.f <- grep("^--file=", commandArgs(FALSE), value = TRUE)
source(file.path(if (length(.f)) dirname(normalizePath(sub("^--file=", "", .f[1]))) else getwd(), "00_paths.R"))
source(file.path(SCRIPTS_DIR, "00_corine.R"))   # for cell_area_km2(); this script still selects the
                                                # CORINE classes with its own inline rule, see § below

# The 1988-minus-1987 gap is measured by script 27, so it is read from that script's output rather
# than copied here: a literal would keep the old value after any re-run of 27 and nothing would say
# so. The fallback covers a checkout where 27 has not been run yet. It has to come after 00_paths.R,
# since it needs out_path().
GAP_DEFAULT <- 6.94
GAP <- local({
  f <- out_path("cieza_parametrisation_gap.csv")
  if (!file.exists(f)) { message(sprintf("cieza_parametrisation_gap.csv missing, using %.2f", GAP_DEFAULT)); return(GAP_DEFAULT) }
  g <- abs(mean(fread(f)$gap))
  if (abs(g - GAP_DEFAULT) > 0.5)
    message(sprintf("the measured parametrisation gap is %.2f CP, not the %.2f assumed when this was written", g, GAP_DEFAULT))
  round(g, 2)
})

# The thresholds that carry a claim have to sit exactly on the grid. Reading them off a regular
# sequence by interpolation is accurate to a few km2, which is harmless for a curve but enough to
# fail the self-check against the published figures, and those must reconcile exactly.
THR <- sort(unique(c(THR, CR_B, CR_P, CR_B + SE, CR_B - SE, CR_P + SE, CR_P - SE,
                     CR_B + GAP, CR_P + GAP)))

CHILL <- out_path("chill_all_windows.csv")
CLC   <- plinius_clc()
OUT   <- OUT_DIR
REF   <- file.path(OUT, "talk_numbers_cropland.csv")

# --- § 1 - station chill, ensemble median, same pooling as script 19 --------------------------
cat("1. frio por estacion\n")
d <- fread(CHILL, colClasses = list(character = "station_id"))
ens <- d[, .(SWC = median(safe_winter_chill_P10)), by = .(situation, station_id, lon, lat)]

# 2021-2040 pooled across scenarios: at that horizon they are indistinguishable (0.62 CP between
# scenarios against 8.91 CP between models), so three panels would invite reading noise as signal.
nt <- d[window == "nearterm", .(SWC = median(safe_winter_chill_P10)), by = .(station_id, lon, lat)]
if (nrow(nt)) ens <- rbind(ens[!grepl("_nearterm$", situation)],
                           nt[, .(situation = "pooled_nearterm", station_id, lon, lat, SWC)])
sits <- unique(ens$situation)
if (QUICK) sits <- sits[1]
cat(sprintf("   %d situaciones, %d estaciones\n", length(sits), uniqueN(ens$station_id)))

# --- § 2 - template and cropland fraction, identical to script 19 -----------------------------
cat("2. plantilla, contorno y CORINE\n")
ccaa <- esp_get_ccaa(epsg = 4326)
ccaa <- st_transform(ccaa[!grepl("Canaria", ccaa$ine.ccaa.name), ], EPSG)
spain <- st_union(ccaa)
tmpl <- rast(ext(vect(spain)), resolution = RES_M, crs = paste0("EPSG:", EPSG))

clc <- rast(CLC)
clc_c <- crop(clc, ext(project(vect(spain), crs(clc))))
codes <- levels(clc_c)[[1]]
crop_ids <- if (!is.null(codes) && "GRID_CODE" %in% names(codes)) codes$ID[codes$GRID_CODE %in% c(12:17, 19:22)] else NULL
isc <- if (length(crop_ids)) clc_c %in% crop_ids else (clc_c >= 12 & clc_c <= 22 & clc_c != 18)
isc <- as.numeric(isc)
cropfrac <- mask(resample(isc, tmpl, method = "average"), vect(spain))
cell_km2 <- cell_area_km2(cropfrac)   # not (RES_M/1000)^2; see 00_corine.R
cf <- values(cropfrac)[, 1]
total_km2 <- sum(cf, na.rm = TRUE) * cell_km2
cat(sprintf("   superficie cultivable nacional: %.0f km2\n", total_km2))

# --- § 3 - one surface per situation, then the whole curve in memory ---------------------------
# Pulling the cell values out once and sweeping the thresholds as a vector operation avoids
# rasterising the same surface a hundred times; the raster work is the expensive part and it does
# not depend on the threshold.
cat(sprintf("3. barriendo %d umbrales de %.1f a %.1f CP\n", length(THR), min(THR), max(THR)))
curves <- list()
for (s in sits) {
  p <- ens[situation == s]
  pv <- project(vect(as.data.frame(p[, .(lon, lat, SWC)]), geom = c("lon", "lat"), crs = "EPSG:4326"),
                paste0("EPSG:", EPSG))
  surf <- mask(interpIDW(tmpl, pv, field = "SWC", radius = IDW_RADIUS, power = IDW_POWER,
                         maxPoints = IDW_NMAX, near = TRUE), vect(spain))
  v <- values(surf)[, 1]
  keep <- !is.na(v) & !is.na(cf) & cf > 0            # cropland cells the interpolation reaches
  vv <- v[keep]; ww <- cf[keep]
  curves[[s]] <- data.table(situation = s, threshold = THR,
                            km2_at_or_above = vapply(THR, function(t) sum(ww[vv >= t]) * cell_km2, 0))
  cat(sprintf("   %-24s %6.0f km2 de cultivable alcanzado por la interpolacion\n", s, sum(ww) * cell_km2))
}
sweep <- rbindlist(curves)
sweep[, pct_at_or_above := round(100 * km2_at_or_above / total_km2, 4)]
sweep[, km2_at_or_above := round(km2_at_or_above, 2)]

# --- § 4 - self-check against the published table ----------------------------------------------
# The two scripts must agree where they overlap. If they do not, one of them has drifted and the
# sweep cannot be used to reason about the published numbers.
at <- function(s, t) approx(sweep[situation == s]$threshold, sweep[situation == s]$km2_at_or_above, xout = t)$y
chk <- NULL
if (file.exists(REF)) {
  ref <- fread(REF)
  chk <- rbindlist(lapply(intersect(ref$situation, sits), function(s) {
    r <- ref[situation == s]
    data.table(situation = s,
               both_ref = round(r$crop_km2_both, 2),        both_sweep = round(at(s, CR_B), 2),
               only_ref = round(r$crop_km2_only_precoz, 2), only_sweep = round(at(s, CR_P) - at(s, CR_B), 2))
  }))
  chk[, `:=`(d_both = round(both_sweep - both_ref, 2), d_only = round(only_sweep - only_ref, 2))]
  worst <- max(abs(c(chk$d_both, chk$d_only)))
  cat(sprintf("\n4. comprobacion contra talk_numbers_cropland.csv: discrepancia maxima %.2f km2\n", worst))
  print(chk[order(-abs(d_both))][1:min(4, .N)])
  if (worst > TOL)
    stop(sprintf("el barrido no reproduce las cifras publicadas (%.2f km2 > %.2f de tolerancia); una de las dos rutas ha derivado", worst, TOL))
  cat("   coinciden dentro de la tolerancia\n")
} else {
  cat("\n4. AVISO: no encuentro talk_numbers_cropland.csv, no se puede comprobar contra lo publicado\n")
}

# --- § 5 - what the parametrisation question would cost ----------------------------------------
# Restating the open question of script 27 in the currency the talk uses. Not a claim that the
# thresholds are wrong, a measurement of what it would mean if they were.
worst_sit <- "ssp370_far"
if (worst_sit %in% sits) {
  a_now  <- at(worst_sit, CR_P) - at(worst_sit, CR_B)
  a_shift<- at(worst_sit, CR_P + GAP) - at(worst_sit, CR_B + GAP)
  none_now   <- total_km2 - at(worst_sit, CR_P)
  none_shift <- total_km2 - at(worst_sit, CR_P + GAP)
  cat(sprintf("\n5. si los umbrales estuvieran %.2f CP mas altos (escala 1988), en %s:\n", GAP, worst_sit))
  cat(sprintf("   banda 'solo Precoz': %.0f -> %.0f km2 (%+.0f%%)\n", a_now, a_shift, 100 * (a_shift / a_now - 1)))
  cat(sprintf("   'ninguna variedad'  : %.0f -> %.0f km2 (%+.0f%%)\n", none_now, none_shift, 100 * (none_shift / none_now - 1)))
}

fwrite(sweep, file.path(OUT, "cropland_threshold_sweep.csv"))
if (!is.null(chk)) fwrite(chk, file.path(OUT, "cropland_threshold_check.csv"))
fwrite(data.table(metric = c("total_cropland_km2", "cell_km2", "idw_radius_m", "n_thresholds"),
                  value = c(round(total_km2, 2), cell_km2, IDW_RADIUS, length(THR))),
       file.path(OUT, "cropland_threshold_meta.csv"))
cat(sprintf("\nescrito cropland_threshold_sweep.csv: %d filas (%d situaciones x %d umbrales)\n",
            nrow(sweep), length(sits), length(THR)))
