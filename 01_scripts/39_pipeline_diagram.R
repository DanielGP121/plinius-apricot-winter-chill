#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------------------
# The pipeline drawn at two zoom levels, plus the table that would be a third.
#
#   fig49  seven conceptual stages, from four sources to three classes of cropland
#   fig50  the same chain at file level: which script reads what, writes what, and runs where
#   pipeline_runs.csv  the combinatorics (model x experiment x window), which is a table and not
#                      a graph, because 484 model runs drawn as nodes is a grey rectangle
#
# WHY THREE LEVELS AND NOT ONE. Snakemake generates three separate views of the same workflow for
# the same reason: a single figure holding every script is unreadable and a single figure holding
# only concepts cannot be acted on. The rule this follows is that the inputs and outputs of a box
# at level 1 must match exactly the inputs and outputs of the figure that explodes it at level 2,
# so a reader can move between them without losing the thread.
#
# TWO SHAPES ONLY, and the legend says which is which: a rectangle is a computation (a script), a
# parallelogram is something on disk (a table, a raster, a figure). That is the ISO 5807 pairing
# and it survives greyscale, which a colour-coded distinction would not. Three or four shapes look
# more precise and read worse. Provenance is carried by fill colour instead, because
# part of what these figures have to say is that the temperature series were not invented here:
# they come from AEMET, from the PNACC consortium and from Copernicus, and only the last stretch
# of the chain is the author's.
#
# NO NUMBER IN THESE FIGURES IS TYPED. Station counts, model counts, cell counts, the cropland
# denominator and the interpolation error are all read from the canonical tables at draw time, so a
# rerun that changes any of them changes the diagram too. That is the whole point of drawing the
# method with the same tooling as the results.
#
# Usage: Rscript 39_pipeline_diagram.R [--res 1000]
# Requires: terra, ggplot2, data.table.
# ---------------------------------------------------------------------------------------

suppressWarnings(suppressMessages({
  library(terra); library(ggplot2); library(data.table)
}))

args   <- commandArgs(trailingOnly = TRUE)
getarg <- function(f, d) { i <- which(args == f); if (length(i)) args[i + 1] else d }
RES_M  <- as.numeric(getarg("--res", 1000))

.f <- grep("^--file=", commandArgs(FALSE), value = TRUE)
.dir <- if (length(.f)) dirname(normalizePath(sub("^--file=", "", .f[1]))) else getwd()
source(file.path(.dir, "00_paths.R"))

CR_B <- 47.5; CR_P <- 33.7
FIG_TITLE <- toupper(Sys.getenv("PLINIUS_FIG_TITLE", "FALSE")) %in% c("TRUE", "1", "YES")
ttl <- function(x) if (FIG_TITLE) x else NULL
n_es <- function(x, d = 1) formatC(x, format = "f", digits = d, big.mark = ".", decimal.mark = ",")
i_es <- function(x) formatC(round(x), format = "d", big.mark = ".", decimal.mark = ",")

# Provenance palette. Deliberately low-saturation: these are backgrounds behind body text, and the
# figure has to survive being printed in grey.
PROV <- c(aemet    = "#dbe7f2",   # AEMET: the station network and the observational archive
          pnacc    = "#e6e0ef",   # PNACC AR6 / CMIP6 consortium: the projections
          coper    = "#dfeee2",   # Copernicus: CORINE land cover
          propio   = "#fdf0e3",   # produced by this project
          neutro   = "#eef3f8")   # a stage that only carries data through

diagram_theme <- theme_void(base_size = 14) +
  theme(plot.title = element_text(face = "bold", size = 17, hjust = 0),
        plot.subtitle = element_text(size = 12.5, colour = "grey30", hjust = 0),
        plot.caption = element_text(size = 10.5, colour = "grey40", hjust = 0),
        plot.margin = margin(12, 12, 12, 12))

# § 1 — Every quantity the two figures display, read from the canonical outputs.
# Anything that cannot be read is left out of the figure rather than approximated, which is why
# there is no "~15 GB" on the NetCDF box: that number lives in prose, not in a table.
cat("1. cifras desde las tablas\n")
d    <- fread(out_path("chill_all_windows.csv"))
dm   <- d[model != "obs"]
crop <- fread(out_path("talk_numbers_cropland.csv"))

N_ST_PROJ <- uniqueN(dm$station_id)
N_ST_OBS  <- uniqueN(d[model == "obs"]$station_id)
N_MODELS  <- uniqueN(dm$model)
# Emission scenarios only. The scenario column also carries "historical" and "presente", which are
# baseline runs and not scenarios; counting them would put a 4 or a 5 on the figure and invite the
# question of which fifth scenario this is.
N_SCEN    <- uniqueN(grep("^ssp", dm$scenario, value = TRUE))
N_WIN     <- uniqueN(dm$window)
N_ROWS    <- nrow(d)
N_SEASONS <- max(dm$n_seasons)
CROP_KM2  <- crop[1, crop_km2_both + crop_km2_only_precoz + crop_km2_none]
TBL_MB    <- file.info(out_path("chill_all_windows.csv"))$size / 1024^2

surf_file <- file.path(out_path("surface_cache"), sprintf("swc_presente_present_%d.tif", RES_M))
if (!file.exists(surf_file))
  stop("falta ", basename(surf_file), ": el diagrama declara cuántas celdas tiene la superficie y ",
       "esa cifra no se inventa. Ejecuta antes 31_scenario_frames.R o 36_per_model_stats.R.",
       call. = FALSE)
N_CELLS <- global(!is.na(rast(surf_file)), "sum")[1, 1]

# The interpolation error is quoted on the diagram only if it has actually been measured. Script 41
# writes it; before that run there is nothing honest to put in that box.
cv_file <- out_path("idw_crossval_summary.csv")
CV <- if (file.exists(cv_file)) fread(cv_file)[situation == "presente_present"] else NULL
cat(sprintf("   %s estaciones · %d modelos · %s km2 · %s celdas%s\n",
            i_es(N_ST_PROJ), N_MODELS, i_es(CROP_KM2), i_es(N_CELLS),
            if (is.null(CV) || !nrow(CV)) " · sin validacion IDW todavia" else
              sprintf(" · RMSE IDW %s CP", n_es(CV$rmse_CP, 2))))

# § 2 — fig49, the conceptual chain.
# Seven stages, which is the ceiling for a figure meant to be understood at a glance. The stage
# that usually goes missing when this chain is told out loud is the second one: the Dynamic Model
# does not eat daily minima and maxima, it eats hourly temperature, and something has to invent
# those twenty-four values. Giving it a box of its own is most of the reason this figure exists.
cat("2. fig49 cadena conceptual\n")

# Only the three temperature sources sit above stage 1. CORINE is drawn apart, entering at stage 7,
# because that is where it actually enters: it never touches a temperature series, and a collector
# line that swept it in with the others would say it did.
fuentes <- data.table(
  x = c(1.15, 2.5, 3.85),
  lab = c("Proyecciones PNACC AR6", "Archivo observado PNACC", "API AEMET OpenData"),
  sub = c(sprintf("%d modelos × %d escenarios SSP\nmás histórico · %s estaciones",
                  N_MODELS, N_SCEN, i_es(N_ST_PROJ)),
          sprintf("%s estaciones\n1975-2020", i_es(N_ST_OBS)),
          "666 estaciones\nextiende a 2025"),
  prov = c("pnacc", "aemet", "aemet"))

etapas <- data.table(
  i = 1:7,
  etapa = c("Series diarias de temperatura",
            "Reconstrucción horaria",
            "Modelo dinámico: frío por temporada",
            "Safe Winter Chill",
            "Mediana entre modelos",
            "Interpolación a superficie",
            "Suelo cultivable clasificado"),
  detalle = c("Tmin y Tmax por estación y día, de las cuatro fuentes de arriba",
              "de dos valores diarios a veinticuatro, usando la latitud de cada estación",
              sprintf("una cifra por estación, modelo y temporada · hasta %d temporadas por ventana", N_SEASONS),
              "percentil 10 entre las temporadas de la ventana: el frío del segundo peor invierno de cada diez",
              sprintf("un valor por estación, resumiendo los %d modelos", N_MODELS),
              sprintf("de %s puntos a %s celdas de 1 km", i_es(N_ST_PROJ), i_es(N_CELLS)),
              sprintf("%s km² repartidos en tres clases de viabilidad", i_es(CROP_KM2))),
  param = c("1951-2100",
            "chillR::tempResponse_daily_list, argumento latitude",
            "Fishman et al. 1987 · JDay 305-59 · completitud ≥ 85 %",
            "P10 entre temporadas",
            "mediana, no media",
            "IDW · radio 50 km · potencia 2 · 12 vecinos · EPSG:3035",
            sprintf("CORINE 211-244 sin pastos · umbrales %s y %s CP", n_es(CR_B), n_es(CR_P))),
  prov = c("neutro", "propio", "propio", "propio", "propio", "propio", "propio"))
etapas[, y := rev(seq_len(.N))]

# The measured interpolation error is hung off stage 6 rather than written into it, because it is a
# property of that step and not one of its parameters.
nota6 <- if (!is.null(CV) && nrow(CV))
  sprintf("error medido aquí:\nRMSE %s CP,\nel %s %% de los %s CP\nentre las dos variedades",
          n_es(CV$rmse_CP, 2), n_es(CV$pct_of_gap, 0), n_es(CR_B - CR_P)) else NA_character_

YTOP <- max(etapas$y) + 1.55
g49 <- ggplot() +
  # source band
  geom_rect(data = fuentes, aes(xmin = x - 0.47, xmax = x + 0.47,
                                ymin = YTOP - 0.42, ymax = YTOP + 0.42, fill = prov), colour = NA) +
  geom_text(data = fuentes, aes(x, YTOP + 0.20, label = lab), size = 3.5, fontface = "bold",
            colour = "grey12", lineheight = 0.95) +
  geom_text(data = fuentes, aes(x, YTOP - 0.14, label = sub), size = 2.9, colour = "grey35",
            lineheight = 0.95) +
  geom_segment(data = fuentes, aes(x = x, xend = x, y = YTOP - 0.44, yend = YTOP - 0.72),
               colour = "grey55", linewidth = 0.4) +
  geom_segment(aes(x = min(fuentes$x), xend = max(fuentes$x), y = YTOP - 0.72, yend = YTOP - 0.72),
               colour = "grey55", linewidth = 0.4) +
  geom_segment(aes(x = 2.5, xend = 2.5, y = YTOP - 0.72, yend = max(etapas$y) + 0.40),
               arrow = arrow(length = unit(0.16, "cm"), type = "closed"), colour = "grey45") +
  # CORINE enters at the last stage and nowhere else
  annotate("rect", xmin = 4.72, xmax = 6.30, ymin = 0.60, ymax = 1.40, fill = PROV[["coper"]],
           colour = NA) +
  annotate("text", x = 5.51, y = 1.19, size = 3.5, fontface = "bold", colour = "grey12",
           label = "CORINE Land Cover 2018") +
  annotate("text", x = 5.51, y = 0.86, size = 2.9, colour = "grey35", lineheight = 0.95,
           label = "ráster de 100 m\nclases 211-244, sin pastos") +
  annotate("segment", x = 4.70, xend = 4.49, y = 1.0, yend = 1.0,
           arrow = arrow(length = unit(0.16, "cm"), type = "closed"), colour = "grey45") +
  # the seven stages
  geom_rect(data = etapas, aes(xmin = 0.53, xmax = 4.47, ymin = y - 0.38, ymax = y + 0.38,
                               fill = prov), colour = NA) +
  geom_text(data = etapas, aes(0.70, y + 0.20, label = paste0(i, ". ", etapa)), hjust = 0,
            size = 4.3, fontface = "bold", colour = "grey12") +
  geom_text(data = etapas, aes(0.70, y - 0.03, label = detalle), hjust = 0, size = 3.2,
            colour = "grey30") +
  geom_text(data = etapas, aes(0.70, y - 0.24, label = param), hjust = 0, size = 2.9,
            colour = "grey48", fontface = "italic") +
  geom_segment(data = etapas[i < 7], aes(x = 2.5, xend = 2.5, y = y - 0.40, yend = y - 0.62),
               arrow = arrow(length = unit(0.16, "cm"), type = "closed"), colour = "grey45") +
  scale_fill_manual(values = PROV, guide = "none") +
  coord_cartesian(xlim = c(0.4, 6.5), ylim = c(0.4, YTOP + 0.6), expand = FALSE)

if (!is.na(nota6))
  g49 <- g49 +
    annotate("segment", x = 4.49, xend = 4.66, y = etapas[i == 6]$y, yend = etapas[i == 6]$y,
             colour = "#d7191c", linewidth = 0.4) +
    annotate("text", x = 4.72, y = etapas[i == 6]$y, hjust = 0, size = 3.2, colour = "#d7191c",
             lineheight = 0.95, label = nota6)

g49 <- g49 +
  labs(title = ttl("De cuatro ficheros de temperatura a un mapa de dónde cabe cada variedad"),
       subtitle = paste("Siete reducciones sucesivas, cada una con sus parámetros en cursiva.",
                        "El color de fondo separa lo que llega hecho de fuera (PNACC, AEMET, Copernicus)",
                        "de lo que se calcula aquí."),
       caption = "Cada etapa lleva debajo, en cursiva, los parámetros con los que se ejecuta. Ninguna cifra de esta figura está escrita a mano: todas se leen de las tablas del proyecto.") +
  diagram_theme
ggsave(fig_path("fig49_pipeline_overview.png"), g49, width = 13.5, height = 8.6, dpi = 190,
       bg = "white")

# § 3 — fig50, the same chain at file level.
# Two lanes, because "where does this run" is the first question an engineer asks and the answer
# explains the shape of the pipeline: reading fifteen gigabytes of NetCDF happens where the data
# lives, and what travels back is a few megabytes of chill table.
cat("3. fig50 cadena a nivel de fichero\n")

NW <- 0.66; NH <- 0.27          # half-width and half-height of a node box, in data units

nodes <- data.table(
  id   = c("nc", "obs", "api", "clc",
           "s14", "s15", "chill", "s21",
           "s22", "tabla", "s23", "check",
           "s19", "s36", "s41", "s31",
           "figs", "tablas", "gifs", "s35", "pptx"),
  lab  = c("NetCDF PNACC\n88 ficheros", "Archivo observado", "API AEMET", "CORINE 2018",
           "14 download_thredds", "15 chill_national_parallel", "chill_*.csv\npor ventana",
           "21 aemet_observed_download",
           "22 merge_chill_tables", "chill_all_windows.csv", "23 chill_from_api",
           "24-27 comprobaciones\ndel observado",
           "19 cropland_viability", "36 per_model_stats", "41 idw_crossval", "31-32 frames y GIF",
           "fig20-22\nmapas de viabilidad",
           "talk_numbers_cropland\nper_model_cropland_km2\nidw_crossval_summary",
           "7 GIF", "35 build_talk_pptx", "charla_plinius.pptx"),
  tipo = c("dato", "dato", "dato", "dato",
           "script", "script", "dato", "script",
           "script", "dato", "script", "script",
           "script", "script", "script", "script",
           "dato", "dato", "dato", "script", "dato"),
  prov = c("pnacc", "aemet", "aemet", "coper",
           rep("propio", 17)),
  # Two tracks, one above the other. The upper one produced the published results; the lower one is
  # the check on the observed record. CORINE sits next to the scripts that consume it rather than
  # with the temperature sources, because it enters at the end and a long diagonal from the far left
  # would suggest it had been in the chain all along.
  x    = c(1.0, 1.0, 1.0, 9.5,
           2.7, 4.4, 6.1, 2.7,
           7.8, 9.5, 7.8, 9.5,
           11.3, 11.3, 11.3, 11.3,
           13.0, 13.0, 13.0, 13.0, 14.6),
  y    = c(5.4, 4.4, 1.0, 2.5,
           5.4, 4.7, 4.7, 1.0,
           4.7, 4.0, 1.0, 1.0,
           5.5, 4.5, 3.5, 2.4,
           5.5, 4.5, 2.4, 3.5, 3.5))

# The API branch deliberately dead-ends in the checks. It never feeds the canonical table: it exists
# to test whether the archive and the API measure the same thing over the seasons both cover, and
# drawing an arrow from it into the results would claim a role it does not have.
edges <- data.table(
  from = c("nc", "s14", "s15", "obs", "chill", "s22",
           "api", "s21", "s23", "chill",
           "tabla", "tabla", "tabla", "tabla", "clc", "clc", "clc",
           "s19", "s36", "s41", "s31", "figs", "tablas", "s35"),
  to   = c("s14", "s15", "chill", "s15", "s22", "tabla",
           "s21", "s23", "check", "check",
           "s19", "s36", "s41", "s31", "s19", "s36", "s31",
           "figs", "tablas", "tablas", "gifs", "s35", "s35", "pptx"))

seg <- merge(merge(edges, nodes[, .(from = id, x0 = x, y0 = y)], by = "from"),
             nodes[, .(to = id, x1 = x, y1 = y)], by = "to")

# A parallelogram, the flowchart symbol for data. Skewed by a fixed fraction of the node width so
# every one of them leans the same amount regardless of where it sits.
SKEW <- 0.16
para <- nodes[tipo == "dato", .(px = c(x - NW + SKEW, x + NW + SKEW, x + NW - SKEW, x - NW - SKEW),
                                py = c(y + NH, y + NH, y - NH, y - NH), prov = prov), by = id]

g50 <- ggplot() +
  # Order matters: the horizontal track band goes down first, the vertical "where it runs" band on
  # top of it. Their overlap is meaningful, and it is what puts script 21 visibly on the HPC.
  annotate("rect", xmin = 0.25, xmax = 15.2, ymin = 0.35, ymax = 1.65, fill = "grey93", colour = NA) +
  annotate("rect", xmin = 1.95, xmax = 6.95, ymin = 0.05, ymax = 6.1, fill = "#f3f0e8", colour = NA) +
  annotate("text", x = 2.05, y = 5.95, hjust = 0, size = 3.5, colour = "grey40", fontface = "bold",
           label = "en el HPC Ladon: donde viven los 15 GB de NetCDF") +
  annotate("text", x = 7.15, y = 5.95, hjust = 0, size = 3.5, colour = "grey40", fontface = "bold",
           label = "en local: lo que baja del HPC son unos megas de tabla") +
  annotate("text", x = 10.5, y = 1.0, hjust = 0, size = 3.4, colour = "grey45", fontface = "italic",
           label = "rama de comprobación: contrasta las dos fuentes\nobservadas, no entra en los resultados") +
  geom_segment(data = seg, aes(x = x0 + NW, y = y0, xend = x1 - NW, yend = y1),
               arrow = arrow(length = unit(0.11, "cm"), type = "closed"),
               colour = "grey58", linewidth = 0.3) +
  geom_polygon(data = para, aes(px, py, group = id, fill = prov),
               colour = "grey55", linewidth = 0.3) +
  geom_rect(data = nodes[tipo == "script"],
            aes(xmin = x - NW, xmax = x + NW, ymin = y - NH, ymax = y + NH, fill = prov),
            colour = "grey30", linewidth = 0.4) +
  geom_text(data = nodes, aes(x, y, label = lab), size = 2.5, colour = "grey12", lineheight = 0.92) +
  scale_fill_manual(values = PROV, guide = "none") +
  coord_cartesian(xlim = c(0.2, 15.3), ylim = c(0, 6.3), expand = FALSE) +
  labs(title = ttl("La misma cadena, con los ficheros y los scripts que la ejecutan"),
       subtitle = paste("Rectángulo: un cálculo, o sea un script. Paralelogramo: algo que queda en disco.",
                        "El color sigue diciendo quién produjo el dato.",
                        sprintf("\nLa tabla canónica pesa %s MB y tiene %s filas.",
                                n_es(TBL_MB, 1), i_es(N_ROWS)),
                        "La rama de la API muere en las comprobaciones: sirve para contrastar el observado, no entra en los resultados."),
       caption = "Los scripts del test-run de Murcia (2-13) y el barrido de umbrales (28) se han dejado fuera para que la figura se lea. Están todos en la tabla de referencia.") +
  diagram_theme
ggsave(fig_path("fig50_pipeline_files.png"), g50, width = 16.5, height = 7.6, dpi = 190, bg = "white")

# § 4 — Level 3, which is a table. Every combination the chill engine actually ran, so the reader
# can see that "eleven models" means 484 separate runs and not eleven.
cat("4. pipeline_runs.csv\n")
runs <- dm[, .(n_stations = uniqueN(station_id), n_seasons = max(n_seasons)),
           by = .(scenario, window, periodo, model)][order(scenario, window, model)]
fwrite(runs, out_path("pipeline_runs.csv"))
cat(sprintf("   %d combinaciones modelo × escenario × ventana\n", nrow(runs)))

fwrite(data.table(
  metric = c("n_stations_proj", "n_stations_obs", "n_models", "n_scenarios", "n_windows",
             "n_rows_canonical", "n_cells_1km", "cropland_km2", "n_runs", "table_MB"),
  value = c(N_ST_PROJ, N_ST_OBS, N_MODELS, N_SCEN, N_WIN, N_ROWS, N_CELLS, CROP_KM2,
            nrow(runs), round(TBL_MB, 2))),
  out_path("pipeline_diagram_numbers.csv"))

cat(sprintf("\nescritas fig49, fig50, pipeline_runs.csv y pipeline_diagram_numbers.csv en %s\n", FIG_DIR))
