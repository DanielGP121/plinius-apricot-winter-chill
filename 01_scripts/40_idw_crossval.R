#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------------------
# How wrong is the interpolated chill surface? Leave-one-out cross-validation of the IDW.
#
# Every square kilometre this project reports comes from a surface that was invented between
# stations: each 1 km cell is a distance-weighted average of the stations within 50 km. The method
# replicates Egea et al. 2022 and is defensible on that ground alone, but nothing in the pipeline
# had ever measured how far that invention lands from reality. This script measures it, and it is
# the only number in the study that defends the map without leaning on a citation.
#
# WHY IT MATTERS HERE SPECIFICALLY, and not as a routine statistic. The result is a threshold
# crossing: a cell is classified by whether its interpolated Safe Winter Chill sits above or below
# 47.5 and 33.7 chill portions. Cells misclassified by interpolation error are those whose true
# value lies within that error of a threshold. So the error has a natural yardstick, the 13.8 CP
# that separate the two cultivars: an error well under that leaves the classification standing,
# an error of the same order means a good part of the boundary between classes is noise.
#
# TWO LIMITS OF THIS NUMBER, both of which belong next to it wherever it is quoted.
#   - It is measured AT stations, and stations cluster in valleys, towns and airports. On a sierra
#     forty kilometres from the nearest thermometer the real error is worse than this reports.
#     Panel 2 is here to show how fast it degrades with distance.
#   - IDW knows nothing about altitude. Panel 3 plots the residual against elevation for the
#     stations whose altitude is in the public inventory, which is the obvious way this method
#     fails in a mountainous country.
#
# HOW THE PREDICTION IS COMPUTED. Not by calling terra and extracting, because terra interpolates
# onto cell centres and a station sits up to half a cell away from one; that offset would be folded
# into the error and inflate it. The weights are applied directly at the station coordinate, with
# the same three parameters script 30 uses (radius 50 km, power 2, at most 12 neighbours), so the
# only difference from the published surface is the one being measured. Two self-checks guard the
# implementation and both must pass before any number is written:
#   1. including a point in its own neighbour set must return that point's value exactly, which is
#      the defining property of an exact interpolator and exercises the zero-distance branch;
#   2. the all-points prediction is compared against terra's own surface sampled at the stations,
#      which should agree to within the cell-centre offset and not more.
#
# Distances are Euclidean in EPSG:3035 metres. That is not an approximation of the real method: it
# is the real method, since the published surfaces are built on that projected grid.
#
# Usage: Rscript 57_idw_crossval.R [--res 1000] [--sits all|base] [--no-check]
# Writes: 02_outputs/tables/idw_crossval.csv, idw_crossval_summary.csv, fig52_idw_crossval.png
# Requires: terra, sf, mapSpain, ggplot2, data.table, patchwork.
# ---------------------------------------------------------------------------------------

suppressWarnings(suppressMessages({
  library(terra); library(sf); library(mapSpain); library(ggplot2); library(data.table)
  library(patchwork)
}))

args   <- commandArgs(trailingOnly = TRUE)
getarg <- function(f, d) { i <- which(args == f); if (length(i)) args[i + 1] else d }
RES_M  <- as.numeric(getarg("--res", 1000))
SITS   <- getarg("--sits", "all")
CHECK  <- !("--no-check" %in% args)

.f <- grep("^--file=", commandArgs(FALSE), value = TRUE)
.dir <- if (length(.f)) dirname(normalizePath(sub("^--file=", "", .f[1]))) else getwd()
source(file.path(.dir, "00_paths.R"))

EPSG       <- 3035
CR_B       <- 47.5
CR_P       <- 33.7
CR_GAP     <- CR_B - CR_P                    # 13.8 CP, the yardstick every error is read against
IDW_RADIUS <- 50000
IDW_POWER  <- 2
IDW_NMAX   <- 12
BASE_SIT   <- "presente_present"

FIG_TITLE <- toupper(Sys.getenv("PLINIUS_FIG_TITLE", "FALSE")) %in% c("TRUE", "1", "YES")
ttl <- function(x) if (FIG_TITLE) x else NULL
n_en <- function(x, d = 1) formatC(x, format = "f", digits = d, big.mark = ",", decimal.mark = ".")
i_en <- function(x) formatC(round(x), format = "d", big.mark = ",", decimal.mark = ".")

talk_theme <- theme_minimal(base_size = 14) +
  theme(plot.title = element_text(face = "bold", size = 17),
        plot.subtitle = element_text(size = 12.5, colour = "grey30"),
        panel.grid.minor = element_blank(), legend.position = "bottom")

# § 1 — Neighbour structure.
# Built once per station set rather than once per situation. The fourteen situations share only two
# distinct sets of coordinates (3460 stations for the projections, 3044 for the observations), and
# the expensive half of the work depends on the coordinates alone, not on the values.
#
# The zero-distance case is not hypothetical here: 151 locations in this network hold two stations,
# so a neighbour at exactly 0 m is a routine occurrence rather than a defensive branch.
neighbour_structure <- function(xy, radius, nmax, block = 400L) {
  n <- nrow(xy)
  idx <- vector("list", n); dst <- vector("list", n)
  for (i0 in seq(1L, n, by = block)) {
    ii <- i0:min(i0 + block - 1L, n)
    d  <- sqrt(outer(xy[ii, 1], xy[, 1], "-")^2 + outer(xy[ii, 2], xy[, 2], "-")^2)
    d[cbind(seq_along(ii), ii)] <- Inf                      # a station is not its own neighbour
    for (k in seq_along(ii)) {
      dk <- d[k, ]
      j  <- which(dk <= radius)
      if (!length(j)) { idx[[ii[k]]] <- integer(0); dst[[ii[k]]] <- numeric(0); next }
      o  <- order(dk[j])[seq_len(min(nmax, length(j)))]
      idx[[ii[k]]] <- j[o]; dst[[ii[k]]] <- dk[j][o]
    }
  }
  list(idx = idx, dst = dst)
}

# Apply the weights. `self` reproduces the interpolator without leaving anything out, which is what
# the exactness check needs; the cross-validation itself always runs with self = FALSE.
idw_predict <- function(nb, z, power, self = FALSE, z_self = NULL) {
  vapply(seq_along(nb$idx), function(i) {
    d <- nb$dst[[i]]; j <- nb$idx[[i]]
    if (self) { d <- c(0, d); j <- c(i, j) }
    if (!length(j)) return(NA_real_)
    if (any(d == 0)) return(mean(z[j[d == 0]]))             # co-located stations: no weight is finite
    w <- 1 / d^power
    sum(w * z[j]) / sum(w)
  }, numeric(1))
}

cat("1. data\n")
d <- fread(tab_path("chill_all_windows.csv"))
ens <- d[, .(SWC = median(safe_winter_chill_P10)), by = .(situation, station_id, lon, lat)]
sits <- if (SITS == "base") BASE_SIT else unique(ens$situation)
cat(sprintf("   %d situations, %s stations in the largest\n", length(sits),
            i_en(max(ens[, .N, by = situation]$N))))

# The structure is keyed by station set rather than by situation, because the fourteen situations
# reduce to two networks. The key is the station count, which is cheap, and reuse is then VERIFIED
# against the actual station list instead of trusted: a key collision would silently apply one
# network's neighbours to another's values, and the output would look entirely reasonable.
cat("2. neighbour structure\n")
structures <- list(); ids_of <- list(); key_of <- character(0)
for (s in sits) {
  p <- ens[situation == s]; setorder(p, station_id)
  k <- as.character(nrow(p))
  if (is.null(structures[[k]])) {
    pv <- project(vect(as.data.frame(p[, .(lon, lat)]), geom = c("lon", "lat"), crs = "EPSG:4326"),
                  paste0("EPSG:", EPSG))
    xy <- crds(pv)
    t0 <- Sys.time()
    structures[[k]] <- neighbour_structure(xy, IDW_RADIUS, IDW_NMAX)
    ids_of[[k]] <- p$station_id
    cat(sprintf("   %s stations in %.0f s\n", i_en(nrow(xy)),
                as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  } else {
    stopifnot(identical(ids_of[[k]], p$station_id))
  }
  key_of[s] <- k
}

# § 2 — Co-located stations, and the floor they put under every error figure below.
#
# 151 locations in this network hold two stations at the same coordinate. Where two thermometers
# share a position and disagree, the difference is not interpolation error: it is the measurement
# and processing noise the surface is built on. No interpolation can predict a location better than
# its own instruments agree there, so this is the yardstick for reading the cross-validation, and it
# is computed first for that reason. It also surfaces data-quality outliers that no other check in
# the pipeline would catch, because both members of a pair enter the median untouched.
cat("3. co-located stations\n")
pb <- ens[situation == BASE_SIT]; setorder(pb, station_id)
pvb <- project(vect(as.data.frame(pb[, .(lon, lat)]), geom = c("lon", "lat"), crs = "EPSG:4326"),
               paste0("EPSG:", EPSG))
pb[, `:=`(x = crds(pvb)[, 1], y = crds(pvb)[, 2])]
pb[, xy_key := paste(round(x, 3), round(y, 3))]
colo <- pb[, .(n = .N, spread = if (.N > 1) diff(range(SWC)) else 0,
               swc_min = min(SWC), swc_max = max(SWC),
               stations = paste(station_id, collapse = " "),
               ids = list(station_id),
               lon = lon[1], lat = lat[1]), by = xy_key][n > 1][order(-spread)]

# The same disagreement, measured on the OBSERVATIONS instead of on the models, and only where every
# member of the group actually has an observed record.
#
# This distinction turned out to matter. The projected series are downscaled and calibrated against
# each station's own observations, so two codes at one coordinate where only ONE has a record do not
# disagree because two thermometers disagree: they disagree because one of them was calibrated and
# the other inherited something else. Those groups say nothing about measurement noise and they
# include the largest gap in the whole set. The floor is therefore quoted from the groups where both
# members were measured, over identical seasons, which is the only comparison that means what the
# phrase "measurement noise" claims.
obs_swc <- d[situation == "observaciones_present", .(station_id, swc = safe_winter_chill_P10)]
setkey(obs_swc, station_id)
colo[, todos_obs := vapply(ids, function(v) all(v %in% obs_swc$station_id), logical(1))]
colo[, spread_obs := vapply(ids, function(v) {
  s <- obs_swc[.(v)]$swc
  if (anyNA(s) || length(s) < 2) NA_real_ else diff(range(s))
}, numeric(1))]

NOISE_FLOOR <- median(colo[todos_obs == TRUE]$spread_obs, na.rm = TRUE)
N_FLOOR     <- colo[todos_obs == TRUE & !is.na(spread_obs), .N]
cat(sprintf("   %d groups, %d stations · in the model, median %s CP, maximum %s CP (%s)\n",
            nrow(colo), sum(colo$n), n_en(median(colo$spread), 2), n_en(max(colo$spread), 2),
            colo$stations[1]))
cat(sprintf("   noise floor over the %d groups measured in both: median %s CP\n",
            N_FLOOR, n_en(NOISE_FLOOR, 2)))
fwrite(colo[, .(stations, n, lon, lat, swc_min, swc_max, spread, todos_obs, spread_obs)],
       tab_path("idw_colocated.csv"))

# § 3 — Self-checks. They run before anything is written, because a silently wrong interpolator
# would produce a plausible error figure and there would be no way to tell from the output.
if (CHECK) {
  cat("4. checks\n")
  nb <- structures[[key_of[BASE_SIT]]]
  p  <- ens[situation == BASE_SIT]; setorder(p, station_id)
  z  <- p$SWC

  # Exactness holds only where the point is alone at its coordinate. At a shared coordinate the
  # value is genuinely ambiguous and any interpolator has to pick a rule; ours averages, as terra
  # does. Testing exactness there would be testing the wrong thing, so those stations are excluded
  # and counted rather than quietly tolerated.
  alone <- vapply(nb$dst, function(x) !length(x) || x[1] > 0, logical(1))
  exact <- idw_predict(nb, z, IDW_POWER, self = TRUE)
  worst <- max(abs(exact[alone] - z[alone]), na.rm = TRUE)
  cat(sprintf("   exactness at the %s stations with no twin: maximum deviation %.2e CP\n",
              i_en(sum(alone)), worst))
  if (worst > 1e-9) stop("the interpolator is not exact at its own points; check the weights")

  ccaa  <- esp_get_ccaa(epsg = 4326)
  ccaa  <- st_transform(ccaa[!grepl("Canaria", ccaa$ine.ccaa.name), ], EPSG)
  spain <- st_union(ccaa)
  tmpl  <- rast(ext(vect(spain)), resolution = RES_M, crs = paste0("EPSG:", EPSG))
  pv    <- project(vect(as.data.frame(p[, .(lon, lat, SWC)]), geom = c("lon", "lat"),
                        crs = "EPSG:4326"), paste0("EPSG:", EPSG))
  surf  <- interpIDW(tmpl, pv, field = "SWC", radius = IDW_RADIUS, power = IDW_POWER,
                     maxPoints = IDW_NMAX, near = TRUE)
  ter   <- terra::extract(surf, pv)[, 2]
  gap   <- median(abs(ter - exact), na.rm = TRUE)
  cat(sprintf("   against terra on the %d m grid: median difference %.3f CP\n", RES_M, gap))
  # Not an equality test. terra answers at the cell centre and the station sits somewhere inside the
  # cell, so a difference of this order is the grid, not a bug. An order of magnitude more would be.
  if (is.finite(gap) && gap > 1) warning("difference against terra larger than the grid explains")
}

# § 4 — The cross-validation itself, one pass per situation.
cat("5. cross-validation\n")
res <- rbindlist(lapply(sits, function(s) {
  nb <- structures[[key_of[s]]]
  p  <- ens[situation == s]; setorder(p, station_id)
  pred <- idw_predict(nb, p$SWC, IDW_POWER, self = FALSE)
  data.table(situation = s, station_id = p$station_id, lon = p$lon, lat = p$lat,
             obs = p$SWC, pred = pred, resid = pred - p$SWC,
             d_nn = vapply(nb$dst, function(x) if (length(x)) x[1] else NA_real_, numeric(1)),
             n_nb = lengths(nb$idx))
}))
# A station with a twin at the same coordinate is predicted from that twin at zero distance, so its
# residual is the disagreement between two instruments and not a test of the interpolation at all.
# Leaving those 306 in would flatter the surface. They are kept in the file and excluded from the
# headline, which is why every summary below carries both numbers.
res[, has_twin := !is.na(d_nn) & d_nn == 0]

summ <- res[!is.na(resid) & !has_twin, .(
  n_stations   = .N,
  mae_CP       = mean(abs(resid)),
  rmse_CP      = sqrt(mean(resid^2)),
  bias_CP      = mean(resid),
  p90_abs_CP   = unname(quantile(abs(resid), 0.90)),
  r            = cor(pred, obs),
  pct_of_gap   = 100 * sqrt(mean(resid^2)) / CR_GAP), by = situation]
# Two counts that only mean anything over the whole set: stations with no neighbour inside the
# radius produce no residual at all, and stations with a twin produce one that measures something
# else. Both belong in the file so the headline can be read against them.
summ <- merge(summ, res[, .(n_no_neigh = sum(is.na(pred)), n_twin = sum(has_twin),
                            rmse_all_CP = sqrt(mean(resid^2, na.rm = TRUE))), by = situation],
              by = "situation")
setorder(summ, rmse_CP)

fwrite(res, tab_path("idw_crossval.csv"))
fwrite(summ, tab_path("idw_crossval_summary.csv"))
print(summ[, .(situation, n_stations, mae_CP = round(mae_CP, 2), rmse_CP = round(rmse_CP, 2),
               rmse_all = round(rmse_all_CP, 2), bias_CP = round(bias_CP, 3),
               pct_of_gap = round(pct_of_gap, 1))])

# § 5 — The error expressed as territory.
#
# An RMSE in chill portions is not an answer to "how much of this map should I believe". The
# classification is a threshold crossing, so what matters is how much cropland sits close enough to
# 47.5 or 33.7 CP that an error of the measured size could put it in the wrong class. That band is
# the honest uncertainty of every square kilometre this project reports, and until now no figure of
# the project carried it.
#
# This is deliberately not a confidence interval. It is a count of the land where the answer is
# within reach of the error, which is the weakest claim the data actually support.
cat("6. uncertainty band around the thresholds\n")
CACHE <- out_path("surface_cache")
crop_f <- file.path(CACHE, sprintf("cropfrac_%d.tif", RES_M))
band <- NULL
if (file.exists(crop_f)) {
  source(file.path(.dir, "00_corine.R"))
  cropfrac <- rast(crop_f)
  CELL <- cell_area_km2(cropfrac)
  band <- rbindlist(lapply(summ$situation, function(s) {
    f <- file.path(CACHE, sprintf("swc_%s_%d.tif", s, RES_M))
    if (!file.exists(f)) return(NULL)
    surf <- rast(f)
    e <- summ[situation == s]$rmse_CP
    near_b <- abs(surf - CR_B) < e
    near_p <- abs(surf - CR_P) < e
    km <- function(m) global(mask(cropfrac, m, maskvalues = c(0, NA)), "sum", na.rm = TRUE)[1, 1] * CELL
    tot <- global(cropfrac, "sum", na.rm = TRUE)[1, 1] * CELL
    data.table(situation = s, rmse_CP = e,
               km2_near_bulida = km(near_b), km2_near_precoz = km(near_p),
               km2_near_any = km(near_b | near_p), km2_total = tot)
  }))
  if (!is.null(band) && nrow(band)) {
    band[is.na(band)] <- 0
    band[, pct_near_any := 100 * km2_near_any / km2_total]
    fwrite(band, tab_path("idw_threshold_band.csv"))
    for (i in seq_len(nrow(band)))
      cat(sprintf("   %-22s %s km2 within %.2f CP of a threshold (%.1f%%)\n",
                  band$situation[i], i_en(band$km2_near_any[i]),
                  band$rmse_CP[i], band$pct_near_any[i]))
  }
} else {
  cat("   no cached cropfrac; skipped (run 32_per_model_stats.R first)\n")
}

# § 6 — fig52. Three panels answering three different questions about the same residuals: how big
# is the error, where does it get worse, and does it have the altitude structure IDW cannot capture.
cat("7. fig52\n")
rb <- res[situation == BASE_SIT & !is.na(resid) & !has_twin]
sb <- summ[situation == BASE_SIT]

# The residual distribution has a long thin tail: a handful of stations miss by tens of chill
# portions. Letting them set the axis squashes the 99 % that carry the message into three bars, so
# the view is clipped and the clipped ones are counted on the figure rather than dropped in silence.
XLIM <- c(-25, 25)
n_out <- rb[abs(resid) > XLIM[2], .N]

p1 <- ggplot(rb, aes(resid)) +
  annotate("rect", xmin = -CR_GAP / 2, xmax = CR_GAP / 2, ymin = 0, ymax = Inf,
           fill = "#2c7bb6", alpha = 0.10) +
  geom_histogram(binwidth = 0.5, fill = "#4a7fb0", colour = NA) +
  geom_vline(xintercept = 0, colour = "grey30") +
  annotate("text", x = CR_GAP / 2 + 0.8, y = Inf, hjust = 0, vjust = 1.5, size = 3.7,
           colour = "#2c7bb6", lineheight = 0.95,
           label = sprintf("the blue band is half of the %s CP\nthat separate the two cultivars",
                           n_en(CR_GAP))) +
  annotate("text", x = XLIM[1], y = Inf, hjust = 0, vjust = 1.5, size = 3.4, colour = "grey45",
           label = sprintf("%d stations fall outside this range", n_out)) +
  scale_x_continuous(labels = function(x) paste0(n_en(x, 0), " CP")) +
  coord_cartesian(xlim = XLIM) +
  labs(title = sprintf("1. Interpolation error: RMSE %s CP, %s%% of the gap between the two cultivars",
                       n_en(sb$rmse_CP, 2), n_en(sb$pct_of_gap, 0)),
       subtitle = sprintf(paste("Leaving each of the %s stations out and predicting it from the rest. Median absolute error %s CP, bias %s CP, r = %s.",
                                "\nFor reference: where two codes share a coordinate and both have a measured record, their observations differ by a median of %s CP. Those %s stations are left out of this calculation."),
                          i_en(sb$n_stations), n_en(median(abs(rb$resid)), 2), n_en(sb$bias_CP, 3),
                          n_en(sb$r, 3), n_en(NOISE_FLOOR, 2), i_en(sb$n_twin)),
       x = "predicted minus measured", y = "stations") +
  talk_theme + theme(plot.title = element_text(size = 13.5), plot.subtitle = element_text(size = 11))

# Conditional medians by distance band, not a scatter of three thousand overplotted points.
# The title is written from the numbers rather than asserting a direction, because the direction is
# not the one the panel was built expecting.
rb[, d_bin := cut(d_nn / 1000, breaks = c(0, 2, 5, 10, 15, 20, 40),
                  labels = c("<2", "2-5", "5-10", "10-15", "15-20", "20-40"))]
db <- rb[!is.na(d_bin), .(med = median(abs(resid)), q75 = quantile(abs(resid), .75), n = .N),
         by = d_bin][order(d_bin)]

p2 <- ggplot(db, aes(d_bin, med)) +
  geom_segment(aes(xend = d_bin, y = med, yend = q75), colour = "grey70", linewidth = 1.2) +
  geom_point(size = 3.4, colour = "#4a7fb0") +
  geom_text(aes(label = i_en(n)), y = 0, vjust = -0.4, size = 3.1, colour = "grey45") +
  scale_y_continuous(labels = function(x) paste0(n_en(x, 0), " CP"), limits = c(0, NA)) +
  labs(title = sprintf("2. Error by distance to the nearest station: %s to %s CP across the bands",
                       n_en(min(db$med), 2), n_en(max(db$med), 2)),
       subtitle = sprintf(paste("Median absolute error by distance to the nearest station, with the 75th percentile; the grey number is how many stations fall in each band.",
                                "\nMind the reach: the network is so dense that no station has its neighbour further than %s km away, so this says nothing about the genuinely isolated cells."),
                          n_en(max(rb$d_nn, na.rm = TRUE) / 1000, 0)),
       x = "distance to the nearest station (km)", y = NULL) +
  talk_theme + theme(plot.title = element_text(size = 13.5), plot.subtitle = element_text(size = 11))

# Elevation is only available for the stations in the public AEMET inventory, a fifth of the
# network. The panel says so on its face rather than in a footnote, because a subset presented as if
# it were the whole is the kind of thing this project has already had to correct once.
inv <- fread(tab_path("aemet_station_inventory_public.csv"))
re  <- merge(rb, unique(inv[, .(station_id = INDCLIM, alt)]), by = "station_id")
p3 <- if (nrow(re) > 50) {
  fit <- lm(resid ~ alt, data = re)
  ci  <- confint(fit)[2, ] * 1000
  ylim3 <- c(-1, 1) * unname(quantile(abs(re$resid), 0.99))
  ggplot(re, aes(alt, resid)) +
    geom_hline(yintercept = 0, colour = "grey30") +
    geom_point(alpha = 0.35, size = 1.6, colour = "#4a7fb0") +
    geom_smooth(method = "lm", formula = y ~ x, se = TRUE, colour = "#d7191c", linewidth = 0.9) +
    scale_y_continuous(labels = function(x) paste0(n_en(x, 0), " CP")) +
    coord_cartesian(ylim = ylim3) +
    labs(title = sprintf("3. Residual against station elevation: %s CP per 1,000 m of altitude",
                         n_en(1000 * coef(fit)[2], 2)),
         subtitle = sprintf(paste("The interpolation overestimates chill on the flat and underestimates it high up, which is exactly how an IDW fails in a mountainous country.",
                                  "\n95%% confidence interval: %s to %s CP per 1,000 m. Only the %s stations whose elevation appears in the public inventory, out of the %s in the network."),
                            n_en(ci[1], 2), n_en(ci[2], 2), i_en(nrow(re)), i_en(sb$n_stations)),
         x = "station elevation (m)", y = "predicted minus measured") +
    talk_theme + theme(plot.title = element_text(size = 13.5), plot.subtitle = element_text(size = 11))
} else NULL

g52 <- (if (is.null(p3)) (p1 / p2) else (p1 / p2 / p3)) +
  plot_annotation(
    title = ttl("Error of the interpolated chill surface, measured by leave-one-out cross-validation"),
    subtitle = sprintf(paste("Leaving one station out at a time, with the same parameters as the published maps:",
                             "radius %s km, power %d, at most %d neighbours.\nThe error is measured AT the stations, which cluster in valleys and",
                             "towns; between them, in the sierras, it is larger than this figure says."),
                       i_en(IDW_RADIUS / 1000), IDW_POWER, IDW_NMAX),
    theme = theme(plot.title = element_text(face = "bold", size = 17),
                  plot.subtitle = element_text(size = 12, colour = "grey30")))
ggsave(fig_path("fig52_idw_crossval.png"), g52, width = 13.5,
       height = if (is.null(p3)) 8.2 else 11.6, dpi = 190, bg = "white")

cat(sprintf("\nwritten idw_crossval.csv (%s rows), idw_crossval_summary.csv and fig52\n", i_en(nrow(res))))
