#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------------------
# Installs the R packages the pipeline needs.
#
# The order matters for exactly one of them. chillR is not on conda-forge and pulls in a chain of
# spatial and numerical dependencies; on the HPC where the national run happens, installing it
# directly cost an afternoon of compilation failures. Installing its heavy dependencies as
# conda-forge binaries first and only then chillR from CRAN takes minutes. That recipe is at the
# bottom of this file.
#
# Two version floors are real, not precautionary:
#   ggplot2 >= 3.4.0   `linewidth` replaced `size` for lines; every figure script uses it
#   terra   >= 1.7     `interpIDW(..., near = TRUE)` is the core of the viability maps
#
# Usage:  Rscript install_deps.R
# ---------------------------------------------------------------------------------------

PKGS <- c(
  # core
  "data.table", "jsonlite",
  # chill model and weather handling
  "chillR",
  # NetCDF
  "ncdf4",
  # spatial
  "terra", "sf", "mapSpain", "tidyterra",
  # figures
  "ggplot2", "viridis", "patchwork", "ggrepel",
  # readers and encoders used by the deck builders
  "readxl", "png", "jpeg", "base64enc",
  # only for 64_soil_criterion_compare.R, which downloads a DEM
  "elevatr",
  # only to knit 61_chill_maps_murcia.Rmd
  "knitr", "rmarkdown"
)

MIN <- c(ggplot2 = "3.4.0", terra = "1.7.0")

missing <- PKGS[!vapply(PKGS, requireNamespace, NA, quietly = TRUE)]
if (length(missing)) {
  cat("installing:", paste(missing, collapse = ", "), "\n")
  install.packages(missing, repos = "https://cloud.r-project.org")
} else {
  cat("every package already present\n")
}

cat("\n--- versions ---\n")
bad <- character(0)
for (p in PKGS) {
  if (!requireNamespace(p, quietly = TRUE)) { cat(sprintf("  %-12s MISSING\n", p)); bad <- c(bad, p); next }
  v <- as.character(packageVersion(p))
  flag <- ""
  if (p %in% names(MIN) && package_version(v) < package_version(MIN[[p]])) {
    flag <- sprintf("  <-- needs >= %s", MIN[[p]]); bad <- c(bad, p)
  }
  cat(sprintf("  %-12s %s%s\n", p, v, flag))
}
cat(sprintf("\nR: %s\n", R.version.string))
cat("developed on R 4.4.1 (local figures and analysis) and R 4.5.3 (HPC, national chill run)\n")
if (length(bad)) {
  cat("\nunusable:", paste(unique(bad), collapse = ", "), "\n")
  quit(status = 1)
}

# ---------------------------------------------------------------------------------------
# chillR on a conda-based HPC
#
# Install the heavy dependencies as binaries first, then chillR from CRAN inside that env:
#
#   conda create -n egu_r -c conda-forge r-base=4.5
#   conda activate egu_r
#   conda install -c conda-forge r-metr r-raster r-sf r-terra r-units r-rcurl r-xml r-sp \
#                                r-fields r-pls r-kendall r-httr r-jsonlite r-ncdf4 r-data.table
#   Rscript -e "install.packages('chillR', repos='https://cloud.r-project.org')"
#
# Only scripts 10 and 20 run there, and they are uploaded as loose files rather than as a clone,
# so 20 deliberately does not depend on 00_paths.R.
# ---------------------------------------------------------------------------------------
