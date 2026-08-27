#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------------------
# Cropland maps at 500 m for the whole country and for Murcia, in density and binary form,
# each with and without the AEMET stations overlaid. The national CORINE is processed once.
#
# CORINE broad cropland (211-244) is turned into a 100 m 0/1 raster, then aggregated to 500 m
# two ways: the mean gives cropland DENSITY (% per cell), the modal gives a BINARY cropland/non-cropland.
# Stations (red, when overlaid) come from the AEMET ESD-RegBA network (constant coordinates
# across observed/historical/future, per J.A. Egea). National maps do NOT highlight Murcia.
#
# Outputs (02_outputs/figures_chill/): density national/Murcia (fig10/fig11 clean, fig8/fig9
# with stations) and binary national/Murcia (fig12/fig14 clean, fig13/fig15 with stations).
#
# Usage: Rscript 67_cropland_density_stations.R
# Requires: terra, sf, mapSpain, ggplot2, viridis, data.table. CORINE 100 m + station lists.
# ---------------------------------------------------------------------------------------

suppressWarnings(suppressMessages({
  library(terra); library(sf); library(mapSpain); library(ggplot2); library(viridis); library(data.table)
}))

EPSG    <- 3035
CELL_M  <- 500
FACT    <- round(CELL_M / 100)
# Paths come from 00_paths.R: it derives the repository root from its own location and demands
# PLINIUS_DATA for anything that lives outside the repository.
.f <- grep("^--file=", commandArgs(FALSE), value = TRUE)
source(file.path(if (length(.f)) dirname(normalizePath(sub("^--file=", "", .f[1]))) else getwd(), "00_paths.R"))

CLC     <- plinius_clc()
ST_NAT  <- plinius_data("tables", "peninsula", "stations.csv")
ST_MUR  <- plinius_data("tables", "murcia", "stations.csv")
RCL     <- rbind(c(11.5, 17.5, 1), c(18.5, 22.5, 1))   # CORINE 211-244 -> cropland
CAP_CLEAN <- "Source: CORINE Land Cover 2018 (Copernicus/EEA), 100 m. Boundaries: mapSpain (IGN)."
CAP_ST    <- "Source: CORINE Land Cover 2018 (Copernicus/EEA), 100 m. Boundaries and stations: mapSpain (IGN) / AEMET."

clc <- rast(CLC)
theme_map <- theme_minimal(base_size = 12) +
  theme(axis.title = element_blank(), axis.text = element_blank(), panel.grid = element_blank())

binary_100m <- function(mask_sf) classify(mask(crop(clc, ext(vect(mask_sf))), vect(mask_sf)), RCL, others = 0)
density_df  <- function(isc) { d <- aggregate(isc, FACT, "mean", na.rm = TRUE) * 100
                               bd <- as.data.frame(d, xy = TRUE); names(bd)[3] <- "pct"; bd[!is.na(bd$pct), ] }
binary_df   <- function(isc) { b <- round(aggregate(isc, FACT, "modal", na.rm = TRUE))
                               bd <- as.data.frame(b, xy = TRUE); names(bd)[3] <- "v"; bd <- bd[!is.na(bd$v), ]
                               bd$clase <- factor(bd$v, levels = c(0, 1), labels = c("non-cropland", "cropland")); bd }
stations_sf <- function(path) st_transform(st_as_sf(fread(path), coords = c("lon", "lat"), crs = 4326), EPSG)

# base is a list of boundary layers; stations NULL or an sf of points; kind "density"/"binary"
make_map <- function(bd, kind, base, stations, size, title, sub, out, w, h) {
  g <- ggplot()
  if (kind == "density") {
    g <- g + geom_raster(data = bd, aes(x, y, fill = pct)) +
      scale_fill_viridis_c(option = "D", name = "% cropland\nper cell", limits = c(0, 100))
  } else {
    g <- g + geom_raster(data = bd, aes(x, y, fill = clase)) +
      scale_fill_manual(values = c("non-cropland" = "grey88", "cropland" = "#1a9850"), name = NULL, drop = FALSE)
  }
  for (l in base) if (!is.null(l)) g <- g + l
  if (!is.null(stations))
    g <- g + geom_sf(data = stations, shape = 21, fill = "#e41a1c", color = "white",
                     size = size, stroke = if (size > 2) 0.5 else 0.25)
  g <- g + coord_sf(crs = EPSG, datum = NA) +
    labs(title = title, subtitle = sub, caption = if (is.null(stations)) CAP_CLEAN else CAP_ST) + theme_map
  ggsave(out, g, width = w, height = h, dpi = 160)
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

# --- national (heavy CORINE step, once) ---------------------------------------------------
cat("national: CORINE -> density and binary 500 m...\n")
isc_nat <- binary_100m(spain)
bd_nat_d <- density_df(isc_nat); bd_nat_b <- binary_df(isc_nat)
st_nat <- stations_sf(ST_NAT); n_nat <- nrow(st_nat)
cat(sprintf("  density cells: %d, stations: %d\n", nrow(bd_nat_d), n_nat))

T_NAT <- "Cropland in Spain (CORINE Land Cover 2018)"
T_NAT_S <- "Cropland and AEMET stations in Spain (CORINE 2018)"
make_map(bd_nat_d, "density", base_nat, NULL, NA, T_NAT,
         "cropland density (211-244) per 500 m cell; Peninsular Spain and the Balearics",
         fig_path("fig10_spain_cropland_density_500m.png"), 11, 9)
make_map(bd_nat_d, "density", base_nat, st_nat, 1.0, T_NAT_S,
         sprintf("cropland density (211-244) per 500 m cell; %d AEMET stations in red (Peninsular Spain and the Balearics)", n_nat),
         fig_path("fig8_spain_cropland_density_stations.png"), 11, 9)
make_map(bd_nat_b, "binary", base_nat, NULL, NA, T_NAT,
         "cropland / non-cropland per 500 m cell; Peninsular Spain and the Balearics",
         fig_path("fig12_spain_cropland_binary_500m.png"), 11, 9)
make_map(bd_nat_b, "binary", base_nat, st_nat, 1.0, T_NAT_S,
         sprintf("cropland / non-cropland per 500 m cell; %d AEMET stations in red (Peninsular Spain and the Balearics)", n_nat),
         fig_path("fig13_spain_cropland_binary_500m_stations.png"), 11, 9)

# --- Murcia -------------------------------------------------------------------------------
cat("Murcia: CORINE -> density and binary 500 m...\n")
isc_mur <- binary_100m(murcia)
bd_mur_d <- density_df(isc_mur); bd_mur_b <- binary_df(isc_mur)
st_mur <- stations_sf(ST_MUR); n_mur <- nrow(st_mur)

T_MUR <- "Cropland in the Region of Murcia (CORINE Land Cover 2018)"
T_MUR_S <- "Cropland and AEMET stations in the Region of Murcia (CORINE 2018)"
make_map(bd_mur_d, "density", base_mur, NULL, NA, T_MUR,
         "cropland density (211-244) per 500 m cell",
         fig_path("fig11_murcia_cropland_density_500m.png"), 9, 7.5)
make_map(bd_mur_d, "density", base_mur, st_mur, 2.6, T_MUR_S,
         sprintf("cropland density (211-244) per 500 m cell; %d AEMET stations in red", n_mur),
         fig_path("fig9_murcia_cropland_density_stations.png"), 9, 7.5)
make_map(bd_mur_b, "binary", base_mur, NULL, NA, T_MUR,
         "cropland / non-cropland per 500 m cell",
         fig_path("fig14_murcia_cropland_binary_500m.png"), 9, 7.5)
make_map(bd_mur_b, "binary", base_mur, st_mur, 2.6, T_MUR_S,
         sprintf("cropland / non-cropland per 500 m cell; %d AEMET stations in red", n_mur),
         fig_path("fig15_murcia_cropland_binary_500m_stations.png"), 9, 7.5)
cat("done: 8 figures (density + binary, national + Murcia, with and without stations)\n")
