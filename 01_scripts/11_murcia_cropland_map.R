#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------------------
# Cropland density map of the Region de Murcia (test-run), from CORINE Land Cover 2018.
#
# Same idea as the national density map (09) but zoomed to Murcia, so it can go finer: 500 m
# cells instead of 1 km. Shows the percentage of agricultural land (CORINE broad classes
# 211-244) per cell, with the province outline and municipal boundaries for context. This is
# the cultivable-soil backdrop of the chill maps at the test-run scale.
#
# Usage:
#   Rscript 11_murcia_cropland_map.R [cell_m]
#     cell_m  density cell size in metres (default 500)
#
# Requires: terra, sf, mapSpain, ggplot2, viridis. CORINE 100 m GeoTIFF on disk.
# ---------------------------------------------------------------------------------------

suppressWarnings(suppressMessages({
  library(terra); library(sf); library(mapSpain); library(ggplot2); library(viridis)
}))

args <- commandArgs(trailingOnly = TRUE)
CELL_M <- if (length(args) >= 1) as.numeric(args[[1]]) else 500
EPSG   <- 3035
# Paths come from 00_paths.R: it derives the repository root from its own location and demands
# PLINIUS_DATA for anything that lives outside the repository.
.f <- grep("^--file=", commandArgs(FALSE), value = TRUE)
source(file.path(if (length(.f)) dirname(normalizePath(sub("^--file=", "", .f[1]))) else getwd(), "00_paths.R"))

CLC    <- plinius_clc()
FIG    <- fig_path("fig7_murcia_cropland_density.png")

murcia <- st_transform(esp_get_prov("Murcia"), EPSG)
muni <- tryCatch(st_transform(esp_get_munic(region = "Murcia"), EPSG), error = function(e) NULL)

# CORINE -> broad cropland (211-244) binary at 100 m, cropped and masked to Murcia
clc <- rast(CLC)
clc_m <- mask(crop(clc, ext(vect(murcia))), vect(murcia))
isc <- classify(clc_m, rbind(c(11.5, 17.5, 1), c(18.5, 22.5, 1)), others = 0)

fact <- max(1L, round(CELL_M / 100))              # 100 m native -> CELL_M cells
dens <- aggregate(isc, fact = fact, fun = "mean", na.rm = TRUE) * 100
bd <- as.data.frame(dens, xy = TRUE); names(bd)[3] <- "pct"; bd <- bd[!is.na(bd$pct), ]

pct_murcia <- as.numeric(global(isc, "mean", na.rm = TRUE)) * 100
cat(sprintf("cropland (211-244) in Murcia: %.1f%%; cell %d m; %d cells\n",
            pct_murcia, CELL_M, nrow(bd)))

g <- ggplot() +
  geom_raster(data = bd, aes(x, y, fill = pct)) +
  scale_fill_viridis_c(option = "D", name = "% cropland\nper cell", limits = c(0, 100)) +
  { if (!is.null(muni)) geom_sf(data = muni, fill = NA, color = "grey80", linewidth = 0.2) } +
  geom_sf(data = murcia, fill = NA, color = "grey15", linewidth = 0.6) +
  coord_sf(crs = EPSG, datum = NA) +
  labs(title = "Cropland in the Region of Murcia (CORINE Land Cover 2018)",
       subtitle = sprintf("cropland density (classes 211-244) per %d m cell", CELL_M),
       caption = "Source: CORINE Land Cover 2018 (Copernicus/EEA), 100 m. Boundaries: mapSpain (IGN).") +
  theme_minimal(base_size = 12) +
  theme(axis.title = element_blank(), axis.text = element_blank(), panel.grid = element_blank())
ggsave(FIG, g, width = 9, height = 7.5, dpi = 160)
cat("map ->", FIG, "\n")
