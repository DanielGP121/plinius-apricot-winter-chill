#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------------------
# Binary cropland maps at native 100 m (cultivo / no cultivo), national and Murcia, with and
# without the AEMET stations. Companion to the 500 m maps (script 12); these keep the full
# CORINE resolution. geom_spatraster (tidyterra) draws the raster without turning it into a
# data.frame, so the ~60 M-cell national map is feasible; it downsamples for display, so at
# national scale the 100 m detail is only visible when zooming into the image.
#
# Outputs (02_outputs/figures_chill/):
#   fig16 national clean, fig17 national + stations, fig18 Murcia clean, fig19 Murcia + stations.
# National maps do NOT highlight Murcia.
#
# Usage: Rscript 13_cropland_binary_100m.R
# Requires: terra, tidyterra, sf, mapSpain, ggplot2, data.table. CORINE 100 m + station lists.
# ---------------------------------------------------------------------------------------

suppressWarnings(suppressMessages({
  library(terra); library(tidyterra); library(sf); library(mapSpain); library(ggplot2); library(data.table)
}))

EPSG    <- 3035
# Paths come from 00_paths.R: it derives the repository root from its own location and demands
# PLINIUS_DATA for anything that lives outside the repository.
.f <- grep("^--file=", commandArgs(FALSE), value = TRUE)
source(file.path(if (length(.f)) dirname(normalizePath(sub("^--file=", "", .f[1]))) else getwd(), "00_paths.R"))

CLC     <- plinius_clc()
ST_NAT  <- plinius_data("tables", "peninsula", "stations.csv")
ST_MUR  <- plinius_data("tables", "murcia", "stations.csv")
RCL     <- rbind(c(11.5, 17.5, 1), c(18.5, 22.5, 1))
CAP_CLEAN <- "Fuente: CORINE Land Cover 2018 (Copernicus/EEA), 100 m. Límites: mapSpain (IGN)."
CAP_ST    <- "Fuente: CORINE Land Cover 2018 (Copernicus/EEA), 100 m. Límites y estaciones: mapSpain (IGN) / AEMET."
FILL <- c("no cultivo" = "grey88", "cultivo" = "#1a9850")

clc <- rast(CLC)
theme_map <- theme_minimal(base_size = 12) +
  theme(axis.title = element_blank(), axis.text = element_blank(), panel.grid = element_blank())

# 100 m binary as a categorical raster (cultivo / no cultivo), masked to the region
binary_100m <- function(mask_sf) {
  isc <- classify(mask(crop(clc, ext(vect(mask_sf))), vect(mask_sf)), RCL, others = 0)
  isc <- as.int(isc)
  levels(isc) <- data.frame(id = c(0, 1), clase = c("no cultivo", "cultivo"))
  names(isc) <- "clase"
  isc
}
stations_sf <- function(path) st_transform(st_as_sf(fread(path), coords = c("lon", "lat"), crs = 4326), EPSG)

make_binary_map <- function(rast_cat, base, stations, size, maxcell, title, sub, out, w, h) {
  g <- ggplot() +
    geom_spatraster(data = rast_cat, maxcell = maxcell) +
    scale_fill_manual(values = FILL, name = NULL, na.value = "transparent", na.translate = FALSE)
  for (l in base) if (!is.null(l)) g <- g + l
  if (!is.null(stations))
    g <- g + geom_sf(data = stations, shape = 21, fill = "#e41a1c", color = "white",
                     size = size, stroke = if (size > 2) 0.5 else 0.25)
  g <- g + coord_sf(crs = EPSG, datum = NA) +
    labs(title = title, subtitle = sub, caption = if (is.null(stations)) CAP_CLEAN else CAP_ST) + theme_map
  ggsave(out, g, width = w, height = h, dpi = 200)
  cat("  ->", basename(out), "\n")
}

# --- boundaries (national maps do not highlight Murcia) -----------------------------------
ccaa <- esp_get_ccaa()
ccaa <- st_transform(ccaa[!grepl("Canaria", ccaa$ine.ccaa.name), ], EPSG)
murcia <- st_transform(esp_get_prov("Murcia"), EPSG)
spain <- st_union(ccaa)
muni <- tryCatch(st_transform(esp_get_munic(region = "Murcia"), EPSG), error = function(e) NULL)
base_nat <- list(geom_sf(data = ccaa, fill = NA, color = "grey35", linewidth = 0.2))
base_mur <- list(if (!is.null(muni)) geom_sf(data = muni, fill = NA, color = "grey80", linewidth = 0.2),
                 geom_sf(data = murcia, fill = NA, color = "grey15", linewidth = 0.6))

# --- national (100 m, geom_spatraster with high maxcell) ----------------------------------
cat("nacional binario 100 m...\n")
rn <- binary_100m(spain)
st_nat <- stations_sf(ST_NAT); n_nat <- nrow(st_nat)
make_binary_map(rn, base_nat, NULL, NA, 5e6,
                "Suelo cultivable en España (CORINE Land Cover 2018, 100 m)",
                "cultivo / no cultivo a 100 m; Península y Baleares",
                file.path(FIG_DIR, "fig16_spain_cropland_binary_100m.png"), 12, 10)
make_binary_map(rn, base_nat, st_nat, 1.0, 5e6,
                "Suelo cultivable y estaciones AEMET en España (CORINE 2018, 100 m)",
                sprintf("cultivo / no cultivo a 100 m; %d estaciones AEMET en rojo (Península y Baleares)", n_nat),
                file.path(FIG_DIR, "fig17_spain_cropland_binary_100m_stations.png"), 12, 10)

# --- Murcia (100 m, real detail) ----------------------------------------------------------
cat("Murcia binario 100 m...\n")
rm <- binary_100m(murcia)
st_mur <- stations_sf(ST_MUR); n_mur <- nrow(st_mur)
make_binary_map(rm, base_mur, NULL, NA, 2e6,
                "Suelo cultivable en la Región de Murcia (CORINE Land Cover 2018, 100 m)",
                "cultivo / no cultivo a 100 m",
                file.path(FIG_DIR, "fig18_murcia_cropland_binary_100m.png"), 9, 7.5)
make_binary_map(rm, base_mur, st_mur, 2.6, 2e6,
                "Suelo cultivable y estaciones AEMET en la Región de Murcia (CORINE 2018, 100 m)",
                sprintf("cultivo / no cultivo a 100 m; %d estaciones AEMET en rojo", n_mur),
                file.path(FIG_DIR, "fig19_murcia_cropland_binary_100m_stations.png"), 9, 7.5)
cat("hecho: 4 figuras binarias a 100 m\n")
