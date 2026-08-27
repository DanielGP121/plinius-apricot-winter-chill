# ---------------------------------------------------------------------------------------
# Path resolution shared by every R script in this repository.
#
# Two roots, and they differ in kind:
#
#   ROOT  the repository itself. Derived from this file's own location, so it is always
#         resolvable and never has to be configured.
#   DATA  the heavy inputs: the CORINE raster, the PNACC NetCDFs, the station tables. These are
#         NOT in the repository, because they belong to third parties and weigh gigabytes. No
#         default is guessed for them. An unset PLINIUS_DATA aborts on the first line with an
#         explanation, rather than failing two hundred lines later inside terra::rast with a
#         message about a file that was never going to be there.
#
# Both can be overridden with environment variables, which is what lets the pipeline run on a
# machine that is not the author's:
#
#   PLINIUS_ROOT   repository root, if for some reason it should not be inferred
#   PLINIUS_DATA   folder holding the external data (see 00_data/README.md)
#   PLINIUS_CLC    full path to the CORINE GeoTIFF, if it does not sit under PLINIUS_DATA
#   PLINIUS_DM     full path to DM_JOSE.R, which is not distributed with this repository
#
# Every script begins with the same two-line bootstrap, which is the smallest thing that can find
# this file without already knowing where it is:
#
#   .f <- grep("^--file=", commandArgs(FALSE), value = TRUE)
#   source(file.path(if (length(.f)) dirname(normalizePath(sub("^--file=", "", .f[1]))) else getwd(),
#                    "00_paths.R"))
# ---------------------------------------------------------------------------------------

.plinius_script_dir <- function() {
  f <- grep("^--file=", commandArgs(FALSE), value = TRUE)              # Rscript
  if (length(f)) return(dirname(normalizePath(sub("^--file=", "", f[1]))))
  for (i in seq_len(sys.nframe())) {                                   # source() from another file
    of <- sys.frames()[[i]]$ofile
    if (!is.null(of)) return(dirname(normalizePath(of)))
  }
  if (requireNamespace("knitr", quietly = TRUE)) {                     # knit of an .Rmd
    ci <- try(knitr::current_input(dir = TRUE), silent = TRUE)
    if (!inherits(ci, "try-error") && !is.null(ci)) return(dirname(normalizePath(ci)))
  }
  getwd()
}

SCRIPTS_DIR <- .plinius_script_dir()
ROOT <- Sys.getenv("PLINIUS_ROOT", unset = dirname(SCRIPTS_DIR))
if (!dir.exists(ROOT)) stop(sprintf("PLINIUS_ROOT points at a folder that does not exist: %s", ROOT))

OUT_DIR  <- file.path(ROOT, "02_outputs")
FIG_DIR  <- file.path(OUT_DIR, "figures_chill")
TAB_DIR  <- file.path(OUT_DIR, "tables")
PRES_DIR <- file.path(ROOT, "03_presentacion")

# out_path() still addresses 02_outputs itself, which is where the subdirectories live
# (surface_cache, model_agreement, gif_frames) and the few files that are not tables.
# Tables and logs go through tab_path(), so that a reader opening 02_outputs sees the
# shape of the output rather than sixty loose files.
out_path <- function(...) file.path(OUT_DIR, ...)
# figures_chill/ is filed by role: ninety-seven PNGs in one folder is a pile rather than a
# set. The number-to-folder map lives here and not in each script, so a script keeps calling
# fig_path("figNN_name.png") and its output lands where it belongs on the next render. A
# number with no entry falls back to the root, which is where a new figure sits until it is
# filed. Readers resolve either way: the book and the deck builder search recursively.
FIG_GROUPS <- list(
  "01_inputs" = c(8, 16, 17, 18, 19),
  "02_method" = c(34, 35, 36, 44, 46, 49, 50, 51, 53),
  "03_chill_surfaces" = c(21),
  "04_results" = c(20, 22, 30, 31, 33, 37, 47),
  "05_model_spread" = c(38, 39, 40, 41, 42, 48, 54, 55),
  "06_checks" = c(6, 23, 24, 26, 43, 45, 52),
  "07_observed_record" = c(25, 32),
  "_superseded" = c(1, 2, 3, 4, 5, 7, 9, 10, 11, 12, 13, 14, 15)
)

.fig_group <- function(name) {
  n <- suppressWarnings(as.integer(sub("^fig([0-9]+).*$", "\\1", name)))
  if (is.na(n)) return("")
  for (g in names(FIG_GROUPS)) if (n %in% FIG_GROUPS[[g]]) return(g)
  ""
}

# Several scripts address the figure directory through an alias or through a --figdir argument a
# caller can override, so the filing has to work against any base, not only FIG_DIR.
fig_in <- function(dir, name) {
  g <- .fig_group(basename(name))
  if (nzchar(g)) {
    dir.create(file.path(dir, g), showWarnings = FALSE, recursive = TRUE)
    return(file.path(dir, g, name))
  }
  file.path(dir, name)
}

fig_path <- function(...) {
  parts <- c(...)
  if (length(parts) == 1L) return(fig_in(FIG_DIR, parts))
  file.path(FIG_DIR, ...)
}
tab_path <- function(...) {
  dir.create(TAB_DIR, showWarnings = FALSE, recursive = TRUE)
  file.path(TAB_DIR, ...)
}

# --- external data ---------------------------------------------------------------------------
# The message is long on purpose. Whoever hits it is a stranger to the project, and the cost of
# reading four extra lines is nothing next to the cost of guessing what the script wanted.
plinius_data <- function(...) {
  d <- Sys.getenv("PLINIUS_DATA", unset = NA_character_)
  if (is.na(d) || !nzchar(d)) stop(
    "PLINIUS_DATA is not set.\n",
    "  It must point at the folder holding the external inputs (CORINE raster, PNACC NetCDFs,\n",
    "  station tables). None of them are in this repository: they belong to third parties and\n",
    "  weigh several gigabytes. 00_data/README.md explains what goes where and how to obtain\n",
    "  each one. Then, for example:\n",
    "      Sys.setenv(PLINIUS_DATA = '/path/to/plinius_data')      # from R\n",
    "      export PLINIUS_DATA=/path/to/plinius_data               # from the shell\n",
    call. = FALSE)
  if (!dir.exists(d)) stop(sprintf("PLINIUS_DATA points at a folder that does not exist: %s", d), call. = FALSE)
  if (!length(list(...))) return(d)
  file.path(d, ...)
}

# CORINE ships under a long versioned folder name, so the file is searched for rather than spelled
# out: the 2018 release and the 2012 one differ only in digits buried in that path.
plinius_clc <- function() {
  p <- Sys.getenv("PLINIUS_CLC", unset = NA_character_)
  if (!is.na(p) && nzchar(p)) {
    if (!file.exists(p)) stop(sprintf("PLINIUS_CLC points at a file that does not exist: %s", p), call. = FALSE)
    return(p)
  }
  # The pattern has to be the strict one first. The Copernicus download also ships the French
  # overseas departments under DATA/French_DOMs/, whose names differ only by a country suffix, and a
  # loose match sorts Guadeloupe ahead of the European raster: the run then dies much later with
  # "extents do not overlap", which says nothing about the real cause.
  all_tif <- list.files(plinius_data(), pattern = "^U20[0-9]{2}_CLC20[0-9]{2}.*\\.tif$",
                        recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  strict <- grep("^U20[0-9]{2}_CLC20[0-9]{2}_V[0-9]+_[0-9]+u[0-9]+\\.tif$", basename(all_tif),
                 ignore.case = TRUE)
  hits <- if (length(strict)) all_tif[strict] else all_tif
  if (!length(hits)) stop(
    "No CORINE raster found under PLINIUS_DATA (looked for U20xx_CLC20xx*.tif at any depth).\n",
    "  Download CORINE Land Cover 2018, 100 m raster, from the Copernicus Land Monitoring Service\n",
    "  (free registration) and unzip it under PLINIUS_DATA, or set PLINIUS_CLC to the .tif itself.",
    call. = FALSE)
  if (length(hits) > 1)
    message(sprintf("several CORINE rasters match, using %s (set PLINIUS_CLC to override)", hits[1]))
  hits[1]
}

# --- the chill model -------------------------------------------------------------------------
# DM_JOSE.R is not distributed here. It is the Dynamic Model under the Fishman et al. (1987)
# parametrisation, written by J.A. Egea, and this repository has no licence to redistribute it.
# The scripts that need it fail here, early and with instructions, rather than deep inside a
# tempResponse call complaining about an object that does not exist.
source_dm_jose <- function() {
  cand <- c(Sys.getenv("PLINIUS_DM", unset = ""), file.path(SCRIPTS_DIR, "DM_JOSE.R"),
            file.path(getwd(), "DM_JOSE.R"))
  hit <- cand[nzchar(cand) & file.exists(cand)]
  if (!length(hit)) stop(
    "DM_JOSE.R not found, and it is not part of this repository.\n",
    "  It implements the Dynamic Model with the parametrisation of Fishman et al. (1987) and was\n",
    "  written by J.A. Egea; the repository has no licence to redistribute it. Request it from the\n",
    "  authors, or write an equivalent: it is chillR's Dynamic_Model with E0=4457.8, E1=10161.9,\n",
    "  A0=419700, A1=1.797e14, slope=1.6, Tf=277. Note that chillR's own defaults are the 1988\n",
    "  parametrisation and give results some 7 chill portions apart, so the two are not\n",
    "  interchangeable. Place the file next to the scripts or set PLINIUS_DM to it.",
    call. = FALSE)
  source(hit[1])
  invisible(hit[1])
}

invisible(NULL)
