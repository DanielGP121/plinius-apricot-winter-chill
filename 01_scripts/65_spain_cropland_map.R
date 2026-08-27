#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------------------
# National cultivable-land maps of Spain from CORINE Land Cover 2018.
#
# Purpose: country-scale context of where the agricultural land is, the same CORINE product
# used to filter stations onto cultivable soil. This high-resolution version replaces the earlier
# 5 km density overview (too blocky to see the cropland) with two maps built from the native 100 m:
#   1. BINARY cropland / non-cropland, aggregated to 200 m (crisp, "cropland or not"), drawn with terra.
#   2. DENSITY: % of cropland per 1 km cell (a finer intensity surface than the old 5 km), ggplot.
#
# Cropland = broad agricultural land (CORINE classes 211-244: arable, permanent crops, and
# heterogeneous agriculture). Scope: Peninsula + Balearic Islands (the clean EPSG:3035 window;
# Canary Islands are a separate PNACC domain). Region de Murcia is highlighted as the test-run.
#
# Usage:
#   Rscript 65_spain_cropland_map.R
#
# Requires: terra, sf, mapSpain, ggplot2, viridis. CORINE 100 m GeoTIFF on disk.
# ---------------------------------------------------------------------------------------

suppressWarnings(suppressMessages({
  library(terra); library(sf); library(mapSpain); library(ggplot2); library(viridis)
}))

EPSG    <- 3035
# Paths come from 00_paths.R: it derives the repository root from its own location and demands
# PLINIUS_DATA for anything that lives outside the repository.
.f <- grep("^--file=", commandArgs(FALSE), value = TRUE)
source(file.path(if (length(.f)) dirname(normalizePath(sub("^--file=", "", .f[1]))) else getwd(), "00_paths.R"))

CLC     <- plinius_clc()
FIG_BIN <- fig_path("fig5_spain_cropland_binary.png")
FIG_DEN <- fig_path("fig5_spain_cropland_density.png")
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

# --- boundaries: peninsula + Baleares (drop Canarias) -------------------------------------
ccaa <- esp_get_ccaa()
ccaa <- st_transform(ccaa[!grepl("Canaria", ccaa$ine.ccaa.name), ], EPSG)
murcia <- st_transform(esp_get_prov("Murcia"), EPSG)
spain <- st_union(ccaa)

# --- CORINE -> binary cropland (broad classes 211-244) at 100 m ---------------------------
cat("cropping CORINE to Spain and reclassifying cropland/non-cropland...\n")
clc <- rast(CLC)
clc_c <- crop(clc, ext(vect(spain)))
isc <- classify(clc_c, rbind(c(11.5, 17.5, 1), c(18.5, 22.5, 1)), others = 0)  # 1 cropland, 0 not
isc <- mask(isc, vect(spain))                                                   # NA outside Spain

pct_nacional <- as.numeric(global(isc, "mean", na.rm = TRUE)) * 100
cat(sprintf("cropland (211-244) as a share of total land: %.1f%%\n", pct_nacional))

# --- MAP 1: binary, 200 m, crisp (terra base plot handles the size) -----------------------
cat("binary map (200 m)...\n")
bin <- aggregate(isc, fact = 2, fun = "modal", na.rm = TRUE)   # 100 m -> 200 m, stays 0/1
bin <- round(bin)
levels(bin) <- data.frame(id = c(0, 1), clase = c("no cultivo", "cultivo"))
png(FIG_BIN, width = 3000, height = 2500, res = 220)
par(mar = c(1, 1, 4, 1))
plot(bin, col = c("grey90", "#1a9850"), axes = FALSE, maxcell = 1.2e7,
     plg = list(x = "bottomright", cex = 1.1), mar = c(1, 1, 4, 1))
plot(vect(ccaa), add = TRUE, border = "grey40", lwd = 0.6)
plot(vect(murcia), add = TRUE, border = "#d7191c", lwd = 1.8)
mtext("Cropland in Spain (CORINE 2018, 100 m → 200 m)", side = 3, line = 2.1, cex = 1.4, font = 2)
mtext("cropland (green) vs non-cropland · classes 211-244 · Peninsular Spain and the Balearics · Region of Murcia in red",
      side = 3, line = 0.6, cex = 1.0)
dev.off()
cat("  ->", FIG_BIN, "\n")

# --- MAP 2: cropland density per 1 km cell (ggplot) ---------------------------------------
cat("density map (1 km)...\n")
dens <- aggregate(isc, fact = 10, fun = "mean", na.rm = TRUE) * 100
bd <- as.data.frame(dens, xy = TRUE); names(bd)[3] <- "pct"; bd <- bd[!is.na(bd$pct), ]
g <- ggplot() +
  geom_raster(data = bd, aes(x, y, fill = pct)) +
  scale_fill_viridis_c(option = "D", name = "% cropland\nper cell", limits = c(0, 100)) +
  geom_sf(data = ccaa, fill = NA, color = "grey35", linewidth = 0.2) +
  geom_sf(data = murcia, fill = NA, color = "#d7191c", linewidth = 0.7) +
  coord_sf(crs = EPSG, datum = NA) +
  labs(title = "Cropland in Spain (CORINE Land Cover 2018)",
       subtitle = "cropland density (classes 211-244) per 1 km cell; Peninsular Spain and the Balearics. Region of Murcia in red",
       caption = "Source: CORINE Land Cover 2018 (Copernicus/EEA), 100 m. Boundaries: mapSpain (IGN).") +
  theme_minimal(base_size = 12) +
  theme(axis.title = element_blank(), axis.text = element_blank(), panel.grid = element_blank())
ggsave(FIG_DEN, g, width = 10, height = 8, dpi = 160)
cat("  ->", FIG_DEN, "\n")
