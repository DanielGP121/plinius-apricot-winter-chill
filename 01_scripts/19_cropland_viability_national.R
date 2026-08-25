#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------------------
# National cultivar viability over cropland: where does 'Búlida Precoz' still meet its chill
# requirement while 'Búlida' no longer does?
#
# Station-level Safe Winter Chill is interpolated to a 1 km surface with inverse distance
# weighting, replicating the method of Egea et al. 2022 (Front. Plant Sci. 13:842628), which
# interpolated with IDW and kept only the area within 50 km of a weather station. That mask is
# reproduced here through the search radius, so cells with no station within 50 km stay empty.
# This network has 3460 stations against the 270 of the reference, so the surface is far better
# constrained.
#
# The surface is then intersected with CORINE cropland and every cell is classified by which
# cultivars it can still support. Reporting the result as a share of CROPLAND AREA rather than a
# share of stations matters: stations cluster in valleys, airports and towns, so a station count
# is not an estimate of territory. 151 locations even carry two co-located stations.
#
# Chill requirements come from Ruiz et al. 2019 (Sci. Hortic. 254:187-192, Table 2): 'Búlida'
# 47.5 ± 3.3 CP and 'Búlida Precoz' 33.7 ± 3.3 CP, both quantified with the Dynamic Model of
# Fishman et al. 1987, the same parametrisation DM_JOSE implements, so supply and demand are on
# the same scale.
#
# Outputs (02_outputs/): figures_chill/fig20_* viability maps per scenario and window,
# fig21_swc_surface_* the underlying chill surfaces, fig22_viability_bars the summary, and
# talk_numbers_cropland.csv with every figure quoted in the talk.
#
# Usage: Rscript 19_cropland_viability_national.R [--res 1000] [--quick]
# Requires: terra, sf, mapSpain, ggplot2, viridis, data.table. CORINE 100 m raster on D:.
# ---------------------------------------------------------------------------------------

suppressWarnings(suppressMessages({
  library(terra); library(sf); library(mapSpain); library(ggplot2); library(viridis); library(data.table)
}))

args    <- commandArgs(trailingOnly = TRUE)
getarg  <- function(f, d) { i <- which(args == f); if (length(i)) args[i + 1] else d }
RES_M   <- as.numeric(getarg("--res", 1000))
QUICK   <- "--quick" %in% args              # one scenario only, to check the chain end to end

EPSG    <- 3035                             # ETRS89 / LAEA Europe, the CORINE projection
CR_B    <- 47.5                             # 'Búlida'        chill requirement (Ruiz 2019)
CR_P    <- 33.7                             # 'Búlida Precoz' chill requirement (Ruiz 2019)
IDW_RADIUS <- 50000                         # 50 km, the Egea et al. 2022 mask
IDW_POWER  <- 2
IDW_NMAX   <- 12                            # neighbours per cell; beyond this IDW barely moves

# Paths come from 00_paths.R: it derives the repository root from its own location and demands
# PLINIUS_DATA for anything that lives outside the repository.
.f <- grep("^--file=", commandArgs(FALSE), value = TRUE)
.dir <- if (length(.f)) dirname(normalizePath(sub("^--file=", "", .f[1]))) else getwd()
source(file.path(.dir, "00_paths.R"))
source(file.path(.dir, "00_corine.R"))

CHILL <- out_path("chill_all_windows.csv")   # built by 22_merge_chill_tables.R
CLC   <- plinius_clc()
FIGS  <- FIG_DIR
dir.create(FIGS, showWarnings = FALSE, recursive = TRUE)

# § 1 — Station-level chill, collapsed to one value per station and scenario-window.
# The ensemble is summarised with the median across the 11 models for the maps. The spread it
# hides is large (24.8 CP between models at a typical station) and is reported separately by the
# agreement layer, never silently.
cat("1. leyendo frio por estacion\n")
d <- fread(CHILL)
stopifnot(!anyNA(d$safe_winter_chill_P10), is.numeric(d$lon))
ens <- d[, .(SWC = median(safe_winter_chill_P10), n_models = .N),
         by = .(situation, scenario, window, periodo, clase, station_id, lon, lat)]

# 2021-2040 pooled over the three scenarios. At that horizon they are not distinguishable: the
# median station differs by 0.62 CP between SSP1-2.6 and SSP3-7.0 while the 11 models span 8.91 CP,
# and in 62% of stations the pessimistic scenario returns MORE chill than the optimistic one. Three
# separate panels would invite reading that noise as a scenario effect, so the pooled panel is the
# one that says what the data support. By 2071-2100 the scenarios do separate (-8.61 CP) and are
# shown apart.
pooled <- d[window == "nearterm", .(SWC = median(safe_winter_chill_P10), n_models = .N),
            by = .(station_id, lon, lat)]
pooled[, `:=`(situation = "pooled_nearterm", scenario = "ensemble", window = "nearterm",
              periodo = "2021-2040", clase = "futuro")]
ens <- rbind(ens, pooled, use.names = TRUE)

# Chronological order, baselines first. Every panel is labelled with its period so no one has to
# remember what "near" or "present" meant in the run that produced it.
SIT_ORDER <- c("observaciones_present", "presente_present", "presente_current",
               "observaciones_obsref", "historical_ref",
               "pooled_nearterm",
               "ssp126_nearterm", "ssp245_nearterm", "ssp370_nearterm",
               "ssp126_near", "ssp245_near", "ssp370_near",
               "ssp126_far", "ssp245_far", "ssp370_far")
SIT_LABEL <- c(
  observaciones_present = "Observed 1995-2020",
  presente_present      = "Model, baseline 1995-2020",
  presente_current      = "Model, current climate 1995-2025",
  observaciones_obsref  = "Observed 1991-2020",
  historical_ref        = "Simulated historical 1985-2014",
  pooled_nearterm       = "2021-2040, three scenarios pooled",
  ssp126_nearterm = "SSP1-2.6 · 2021-2040", ssp245_nearterm = "SSP2-4.5 · 2021-2040", ssp370_nearterm = "SSP3-7.0 · 2021-2040",
  ssp126_near     = "SSP1-2.6 · 2041-2070", ssp245_near     = "SSP2-4.5 · 2041-2070", ssp370_near     = "SSP3-7.0 · 2041-2070",
  ssp126_far      = "SSP1-2.6 · 2071-2100", ssp245_far      = "SSP2-4.5 · 2071-2100", ssp370_far      = "SSP3-7.0 · 2071-2100")

sits <- SIT_ORDER[SIT_ORDER %in% unique(ens$situation)]
missing <- setdiff(unique(ens$situation), sits)
if (length(missing)) stop("situaciones sin etiqueta: ", paste(missing, collapse = ", "))
if (QUICK) sits <- sits[1]
cat(sprintf("   %d situaciones\n", length(sits)))

# § 2 — Country outline and the 1 km template every layer is aligned to.
cat("2. plantilla y contorno\n")
ccaa <- esp_get_ccaa(epsg = 4326)
ccaa <- st_transform(ccaa[!grepl("Canaria", ccaa$ine.ccaa.name), ], EPSG)
spain <- st_union(ccaa)
tmpl <- rast(ext(vect(spain)), resolution = RES_M, crs = paste0("EPSG:", EPSG))

# § 3 — Cropland fraction per template cell, from the 100 m CORINE.
# Broad cropland is codes 211-244 (arable, permanent crops, heterogeneous agricultural areas),
# excluding 231 pasture, matching the "broad" criterion used earlier in the project. Aggregating
# the 0/1 mask by mean gives the fraction of each cell that is cropland, which is what turns a
# per-cell classification into an area statistic.
cat("3. suelo cultivable CORINE\n")
clc <- rast(CLC)
clc_c <- crop(clc, ext(project(vect(spain), crs(clc))))
# Class selection and its verification live in 00_corine.R, shared with 31_scenario_frames.R so the
# animation and the static maps cannot end up measuring different territory.
isc <- corine_crop_mask(clc_c)
cropfrac <- resample(isc, tmpl, method = "average")     # share of each 1 km cell that is cropland
cropfrac <- mask(cropfrac, vect(spain))
cell_km2 <- cell_area_km2(cropfrac)   # not (RES_M/1000)^2; see 00_corine.R
total_crop_km2 <- global(cropfrac, "sum", na.rm = TRUE)[1, 1] * cell_km2
# Spain has of the order of 2e5 km2 of cropland. A total near zero means the class selection matched
# nothing, and every percentage computed from it downstream would be NaN in a file that still gets
# written and plotted.
if (!is.finite(total_crop_km2) || total_crop_km2 < 1e4)
  stop(sprintf("cropland mask selected %.0f km2, which cannot be right; check the CORINE product and its class codes",
               total_crop_km2))
cat(sprintf("   superficie cultivable nacional: %.0f km2\n", total_crop_km2))

# § 4 — IDW surface per situation, masked to cropland, then classified by cultivar viability.
# Three classes: both cultivars viable, only the low-chill mutant, neither. The middle class is
# the window the talk is about, the land the mutant buys back.
classify_cell <- function(swc) ifel(swc >= CR_B, 1L, ifel(swc >= CR_P, 2L, 3L))
LAB <- c("Both cultivars", "Only 'Búlida Precoz'", "Neither")
COL <- c("#2c7bb6", "#fdae61", "#d7191c")

pretty_sit <- function(s) unname(SIT_LABEL[s])

rows <- list(); surfaces <- list(); classes <- list()
for (s in sits) {
  cat(sprintf("4. interpolando %s\n", s))
  p <- ens[situation == s]
  pv <- vect(as.data.frame(p[, .(lon, lat, SWC)]), geom = c("lon", "lat"), crs = "EPSG:4326")
  pv <- project(pv, paste0("EPSG:", EPSG))
  surf <- interpIDW(tmpl, pv, field = "SWC", radius = IDW_RADIUS, power = IDW_POWER,
                    maxPoints = IDW_NMAX, near = TRUE)
  surf <- mask(surf, vect(spain))
  cls <- mask(classify_cell(surf), cropfrac > 0, maskvalues = c(0, NA))

  # area-weighted statistics: every cell contributes its cropland fraction, not a whole cell
  km2 <- sapply(1:3, function(k) global(mask(cropfrac, cls == k, maskvalues = c(0, NA)), "sum", na.rm = TRUE)[1, 1] * cell_km2)
  km2[is.na(km2)] <- 0
  rows[[s]] <- data.table(situation = s, label = pretty_sit(s), n_stations = nrow(p),
                          crop_km2_both = km2[1], crop_km2_only_precoz = km2[2], crop_km2_none = km2[3],
                          pct_both = 100 * km2[1] / sum(km2), pct_only_precoz = 100 * km2[2] / sum(km2),
                          pct_none = 100 * km2[3] / sum(km2),
                          swc_median = median(values(surf), na.rm = TRUE))
  surfaces[[s]] <- surf; classes[[s]] <- cls
  cat(sprintf("   ambas %.1f%% | solo Precoz %.1f%% | ninguna %.1f%%\n",
              rows[[s]]$pct_both, rows[[s]]$pct_only_precoz, rows[[s]]$pct_none))
}
tab <- rbindlist(rows)

# § 5 — Figures. One viability map per situation plus the chill surface behind it, and a summary
# bar chart that carries the whole story in a single slide.
cat("5. figuras\n")
# Clear the two families this script owns before writing them again. The panel index used to come
# from the loop position, so changing how many situations are drawn renamed every file and left the
# previous run's figures behind, indistinguishable from the current ones. The index is now taken
# from SIT_ORDER, which is fixed, and the directory is cleaned so it always reflects one run.
old <- list.files(FIGS, pattern = "^fig2[01]_.*\\.png$", full.names = TRUE)
if (length(old)) { file.remove(old); cat(sprintf("   %d figuras previas retiradas\n", length(old))) }
base_map <- function() list(
  geom_sf(data = ccaa, fill = NA, colour = "grey55", linewidth = 0.15),
  coord_sf(crs = EPSG, datum = NA),
  theme_minimal(base_size = 11),
  theme(panel.grid = element_blank(), axis.text = element_blank(), axis.title = element_blank(),
        legend.position = "bottom", plot.title = element_text(face = "bold"))
)

ord <- sits

for (i in seq_along(ord)) {
  s <- ord[i]
  idx <- match(s, SIT_ORDER)          # stable across runs, unlike the loop position
  df <- as.data.frame(classes[[s]], xy = TRUE, na.rm = TRUE); names(df)[3] <- "cls"
  df$clase <- factor(LAB[df$cls], levels = LAB)
  r <- tab[situation == s]
  g <- ggplot() + geom_raster(data = df, aes(x, y, fill = clase)) + base_map() +
    scale_fill_manual(values = setNames(COL, LAB), drop = FALSE, name = NULL) +
    labs(title = sprintf("Viable cropland — %s", r$label),
         subtitle = sprintf("Both %.1f%%  ·  only 'Búlida Precoz' %.1f%%  ·  neither %.1f%%  (of %s km² of cropland)",
                            r$pct_both, r$pct_only_precoz, r$pct_none,
                            formatC(round(total_crop_km2), format = "d", big.mark = ",")))
  ggsave(file.path(FIGS, sprintf("fig20_%02d_viability_%s.png", idx, s)), g, width = 8, height = 7, dpi = 200)

  sdf <- as.data.frame(surfaces[[s]], xy = TRUE, na.rm = TRUE); names(sdf)[3] <- "SWC"
  gs <- ggplot() + geom_raster(data = sdf, aes(x, y, fill = SWC)) + base_map() +
    scale_fill_viridis_c(name = "Chill portions (P10)", option = "viridis") +
    labs(title = sprintf("Safe Winter Chill — %s", r$label),
         subtitle = "IDW interpolation from 3,460 AEMET stations, 50 km radius (method of Egea et al. 2022)")
  ggsave(file.path(FIGS, sprintf("fig21_%02d_swc_surface_%s.png", idx, s)), gs, width = 8, height = 7, dpi = 200)
}

bars <- melt(tab[, .(label = factor(label, levels = tab[match(ord, situation)]$label),
                     `Both cultivars` = pct_both, `Only 'Búlida Precoz'` = pct_only_precoz,
                     `Neither` = pct_none)],
             id.vars = "label", variable.name = "clase", value.name = "pct")
bars[, clase := factor(clase, levels = LAB)]
gb <- ggplot(bars, aes(label, pct, fill = clase)) +
  geom_col(width = 0.7) + coord_flip() +
  scale_fill_manual(values = setNames(COL, LAB), name = NULL) +
  scale_x_discrete(limits = rev(levels(bars$label))) +
  labs(title = "Cropland area in Spain per viability class",
       subtitle = sprintf("%% of the %s km² of cropland (CORINE 211-244)",
                          formatC(round(total_crop_km2), format = "d", big.mark = ",")),
       x = NULL, y = "% of cropland area") +
  theme_minimal(base_size = 11) + theme(legend.position = "bottom", plot.title = element_text(face = "bold"))
ggsave(file.path(FIGS, "fig22_viability_bars.png"), gb, width = 9, height = 5.5, dpi = 200)

fwrite(tab, file.path(ROOT, "02_outputs", "talk_numbers_cropland.csv"))
cat("\n=== RESUMEN (% de superficie cultivable) ===\n")
print(tab[match(ord, situation), .(label, pct_both = round(pct_both, 1),
      pct_only_precoz = round(pct_only_precoz, 1), pct_none = round(pct_none, 1))], row.names = FALSE)
cat(sprintf("\nescrito talk_numbers_cropland.csv y %d figuras en %s\n", 2 * length(ord) + 1, FIGS))
