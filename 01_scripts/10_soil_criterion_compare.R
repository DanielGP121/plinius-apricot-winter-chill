#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------------------
# Compare two cultivable-soil criteria for the Murcia stations, to decide with Egea.
#
#   A) Buffer-% (current, 05/07): a station is cultivable if >= X% of a radius-R buffer is
#      CORINE cropland. Implemented in 05_cropland_filter.py / 07_soil_decision_map.py.
#   B) Egea's proposal: a station is cultivable if it is <= 1 km from any cultivated cell AND
#      the altitude difference to that cultivated cell is <= 100 m (temperature/chill depend on
#      altitude, so a nearby but much higher/lower station does not represent the cropland).
#
# Criterion B needs elevations: a DEM is fetched with elevatr (AWS terrain tiles), sampled at
# the stations and at the cultivated cells. Output: a per-station table with both flags, the
# counts and overlap, and a map showing where the two criteria disagree.
#
# Usage:
#   Rscript 10_soil_criterion_compare.R [dist_m] [dalt_m] [z]
#     dist_m  max distance station->cultivated cell (default 1000)
#     dalt_m  max altitude difference (default 100)
#     z       elevatr DEM zoom (default 10, ~76 m/px; 11 ~38 m/px)
#
# Requires: elevatr, terra, sf, mapSpain, data.table, ggplot2. CORINE raster + stations.csv.
# ---------------------------------------------------------------------------------------

suppressWarnings(suppressMessages({
  library(elevatr); library(terra); library(sf); library(mapSpain)
  library(data.table); library(ggplot2)
}))

args <- commandArgs(trailingOnly = TRUE)
DIST_M <- if (length(args) >= 1) as.numeric(args[[1]]) else 1000
DALT_M <- if (length(args) >= 2) as.numeric(args[[2]]) else 100
ZOOM   <- if (length(args) >= 3) as.integer(args[[3]]) else 10L

EPSG <- 3035
# Paths come from 00_paths.R: it derives the repository root from its own location and demands
# PLINIUS_DATA for anything that lives outside the repository.
.f <- grep("^--file=", commandArgs(FALSE), value = TRUE)
source(file.path(if (length(.f)) dirname(normalizePath(sub("^--file=", "", .f[1]))) else getwd(), "00_paths.R"))

TAB  <- plinius_data("tables", "murcia")
CLC  <- plinius_clc()
FIG  <- fig_path("fig6_soil_criteria_compare.png")
OUT  <- file.path(TAB, "soil_criteria_compare.csv")
BROAD_CODES <- c(12:17, 19:22)   # 211-244, "zona cultivada" broad, as Egea means it

# --- stations + DEM -----------------------------------------------------------------------
stations <- fread(file.path(TAB, "stations.csv"))
st_sf <- st_as_sf(stations, coords = c("lon", "lat"), crs = 4326)

cat("bajando DEM (elevatr z=", ZOOM, ")...\n", sep = "")
dem <- rast(get_elev_raster(locations = st_sf, z = ZOOM, clip = "bbox", expand = 0.05, verbose = FALSE))
dem <- project(dem, paste0("EPSG:", EPSG))

st_3035 <- st_transform(st_sf, EPSG)
st_xy <- st_coordinates(st_3035)
st_elev <- terra::extract(dem, st_3035)[, 2]

# --- cultivated cells (CORINE broad) with elevation, aligned to 100 m grid ----------------
murcia <- st_transform(esp_get_prov("Murcia"), EPSG)
clc <- rast(CLC)
clc_m <- crop(clc, ext(vect(st_buffer(murcia, 2000))))
cult <- classify(clc_m, rbind(c(11.5, 17.5, 1), c(18.5, 22.5, 1)), others = NA)  # 1 = cultivo
dem_al <- resample(dem, cult)                     # DEM on the CORINE 100 m grid
cc <- c(cult, dem_al); names(cc) <- c("cult", "elev")
cd <- as.data.frame(cc, xy = TRUE)
cd <- cd[!is.na(cd$cult) & !is.na(cd$elev), ]      # cultivated cells with a valid elevation
cx <- cd$x; cy <- cd$y; ce <- cd$elev
cat("celdas de cultivo (broad, 100 m):", nrow(cd), "\n")

# --- Egea criterion per station -----------------------------------------------------------
# For each station keep the cultivated cells inside a DIST_M box (cheap prefilter), then apply
# the exact distance and the altitude-difference test against the station elevation.
egea <- logical(nrow(st_xy)); dmin <- rep(NA_real_, nrow(st_xy))
for (i in seq_len(nrow(st_xy))) {
  sx <- st_xy[i, 1]; sy <- st_xy[i, 2]; se <- st_elev[i]
  sel <- which(abs(cx - sx) <= DIST_M & abs(cy - sy) <= DIST_M)
  if (!length(sel)) next
  d <- sqrt((cx[sel] - sx)^2 + (cy[sel] - sy)^2)
  in1 <- d <= DIST_M
  if (!any(in1)) { dmin[i] <- min(d); next }
  dmin[i] <- min(d[in1])
  egea[i] <- any(abs(ce[sel][in1] - se) <= DALT_M, na.rm = TRUE)
}

# --- compare with the buffer-% criterion (broad and strict, radius 2 km / 50%) ------------
broad <- fread(file.path(TAB, "stations_cultivable_broad.csv"))[, .(station_id, pct_broad = cultivable)]
strict <- fread(file.path(TAB, "stations_cultivable_strict.csv"))[, .(station_id, pct_strict = cultivable)]

res <- data.table(station_id = stations$station_id, lon = stations$lon, lat = stations$lat,
                  elev_station = round(st_elev), dist_cult_m = round(dmin),
                  cultivable_egea = egea)
res <- merge(res, broad, by = "station_id", all.x = TRUE)
res <- merge(res, strict, by = "station_id", all.x = TRUE)
fwrite(res, OUT)

n <- nrow(res)
cat(sprintf("\n=== criterios de suelo (Murcia, %d estaciones) ===\n", n))
cat(sprintf("Egea (<=%dm cultivo + <=%dm altitud): %d cultivables\n", DIST_M, DALT_M, sum(res$cultivable_egea)))
cat(sprintf("Buffer-%% broad (2 km, 50%%, 211-244):  %d\n", sum(res$pct_broad, na.rm = TRUE)))
cat(sprintf("Buffer-%% strict (2 km, 50%%, 211-223): %d\n", sum(res$pct_strict, na.rm = TRUE)))
cat("\nEgea vs buffer-% broad (nº estaciones):\n")
print(table(egea = res$cultivable_egea, pct_broad = res$pct_broad))

# --- map: where the two criteria (Egea vs buffer-% broad) agree/disagree ------------------
res[, cat := fifelse(cultivable_egea & pct_broad, "ambos",
             fifelse(cultivable_egea & !pct_broad, "solo Egea",
             fifelse(!cultivable_egea & pct_broad, "solo %-buffer", "ninguno")))]
res[, cat := factor(cat, levels = c("ambos", "solo Egea", "solo %-buffer", "ninguno"))]
res_sf <- st_transform(st_as_sf(res, coords = c("lon", "lat"), crs = 4326), EPSG)

g <- ggplot() +
  geom_sf(data = murcia, fill = "grey96", color = "grey50", linewidth = 0.3) +
  geom_sf(data = res_sf, aes(color = cat), size = 2.6) +
  scale_color_manual(values = c("ambos" = "#1a9850", "solo Egea" = "#2166ac",
                                "solo %-buffer" = "#f46d43", "ninguno" = "#999999"),
                     name = "Criterio", drop = FALSE) +
  coord_sf(crs = EPSG, datum = NA) +
  labs(title = "Suelo cultivable: criterio de Egea vs buffer-% (Región de Murcia)",
       subtitle = sprintf("Egea: ≤%d km al cultivo + ≤%d m altitud (%d est.)  |  buffer-%% broad 2 km/50%% (%d est.)",
                          DIST_M / 1000, DALT_M, sum(res$cultivable_egea), sum(res$pct_broad, na.rm = TRUE))) +
  theme_minimal(base_size = 12) +
  theme(axis.title = element_blank(), axis.text = element_blank())
ggsave(FIG, g, width = 9, height = 7.5, dpi = 150)
cat("\nmapa ->", FIG, "\ntabla ->", OUT, "\n")
