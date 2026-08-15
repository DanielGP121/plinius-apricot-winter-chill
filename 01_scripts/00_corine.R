# ---------------------------------------------------------------------------------------
# Selection of cultivable land from the CORINE Land Cover 100 m raster.
#
# Shared by every script that reports an area, because the cropland mask is the denominator of
# every km2 in the talk and two scripts disagreeing about it would be invisible in the output and
# fatal to the result.
#
# The criterion is CLC classes 211 to 244 excluding 231 (pastures): arable land irrigated or not,
# rice, vineyards, fruit trees, olive groves, and the heterogeneous agricultural classes. In the
# 100 m raster these are grid codes 12-17 and 19-22, and the pixel values ARE those grid codes.
#
# Why this file exists at all. The raster attribute table is read differently by different terra
# versions: older ones returned NULL and left the caller working on raw numeric codes, terra 1.9
# returns a table whose columns are Value and LABEL3. A check written against a third spelling
# (GRID_CODE) passed silently under the first behaviour and aborted under the second, so the same
# script stopped being able to reproduce its own figures without a line of it having changed.
# The selection is therefore verified against the class LABELS, which are stable across versions
# and actually say what is being selected, instead of against a column name.
# ---------------------------------------------------------------------------------------

# Grid codes of the cultivable classes, and the label each one must carry for the selection to be
# trusted. Matching is done on a distinctive fragment, lower-cased, because Copernicus has changed
# capitalisation and punctuation between releases but not the wording.
CORINE_CROP_CODES <- c(12L, 13L, 14L, 15L, 16L, 17L, 19L, 20L, 21L, 22L)
CORINE_CROP_MARKS <- c("arable", "irrigated", "rice", "vineyard", "fruit tree", "olive",
                       "annual crops", "complex cultivation", "principally occupied",
                       "agro-forestry")
CORINE_EXCLUDED   <- c(`18` = "pasture")   # adjacent to the range and deliberately left out

# Area of one cell of the analysis grid, in square kilometres.
#
# NOT (RES_M / 1000)^2, which is what every script here used until 2026-08-14 and which is wrong by
# 0.031 %. terra::rast(ext, resolution = 1000) honours the EXTENT and adjusts the resolution so that
# a whole number of cells fits inside it. Over the bounding box of Spain that lands on 1072 columns
# and 1028 rows, and therefore on cells of 1000.3189 x 999.9947 m rather than 1000 x 1000. The
# analysis grid is EPSG:3035, which is equal-area, so a cell's area is exactly the product of the
# two resolutions everywhere on the map; the nominal value silently understated every square
# kilometre the project reported, by 72 km2 on the national cropland total.
#
# It lives here, next to the mask, because these are the two halves of the same sentence: the mask
# decides which cells count and this decides what one of them is worth. Seven scripts had their own
# copy of the second half and all seven were wrong in the same way.
cell_area_km2 <- function(r) {
  stopifnot(inherits(r, "SpatRaster"))
  prod(res(r)) / 1e6
}

# Returns a 0/1 numeric SpatRaster: 1 where the cell is one of the cultivable classes.
# `verbose` prints the classes actually selected, which is the cheapest possible audit of a mask
# that otherwise only shows up as a number several hundred lines later.
corine_crop_mask <- function(clc, verbose = TRUE) {
  lv <- levels(clc)[[1]]

  if (!is.null(lv)) {
    code_col <- intersect(c("GRID_CODE", "Value", "ID", "value"), names(lv))
    lab_col  <- intersect(c("LABEL3", "LABEL", "label3", "CLC_CODE"), names(lv))
    if (!length(code_col) || !length(lab_col))
      stop(sprintf(paste0("the CORINE attribute table has columns (%s) and none of them could be ",
                          "read as a class code plus a label.\n  This is not the CLC 100 m raster ",
                          "the selection was written for."),
                   paste(names(lv), collapse = ", ")), call. = FALSE)

    codes <- as.integer(lv[[code_col[1]]])
    labs  <- tolower(as.character(lv[[lab_col[1]]]))

    got <- match(CORINE_CROP_CODES, codes)
    if (anyNA(got))
      stop(sprintf("CORINE grid codes absent from the raster: %s",
                   paste(CORINE_CROP_CODES[is.na(got)], collapse = ", ")), call. = FALSE)

    # Every selected code must look like the class it is supposed to be. A raster whose codes mean
    # something else would pass a numeric range check and quietly measure the wrong territory.
    bad <- CORINE_CROP_MARKS[!mapply(grepl, CORINE_CROP_MARKS, labs[got], fixed = TRUE)]
    if (length(bad))
      stop(sprintf(paste0("the CORINE class labels do not match the expected cultivable classes.\n",
                          "  expected a class containing %s, found instead:\n    %s"),
                   paste(sQuote(bad), collapse = ", "),
                   paste(sprintf("%d = %s", CORINE_CROP_CODES, labs[got]), collapse = "\n    ")),
           call. = FALSE)

    for (k in names(CORINE_EXCLUDED)) {
      j <- match(as.integer(k), codes)
      if (!is.na(j) && !grepl(CORINE_EXCLUDED[[k]], labs[j], fixed = TRUE))
        stop(sprintf("grid code %s was expected to be %s but is '%s'; the class numbering differs",
                     k, CORINE_EXCLUDED[[k]], labs[j]), call. = FALSE)
    }

    if (verbose) {
      cat("   clases CORINE seleccionadas:\n")
      cat(sprintf("     %2d  %s\n", CORINE_CROP_CODES, lv[[lab_col[1]]][got]), sep = "")
    }
  } else if (verbose) {
    cat("   el raster CORINE no trae tabla de atributos; se usan los codigos numericos directos\n")
  }

  # Categories are dropped before comparing. On a categorical SpatRaster the comparison operators
  # work on the level index rather than on the stored code, and the two coincide only by accident.
  num <- clc
  levels(num) <- NULL
  as.numeric(num %in% CORINE_CROP_CODES)
}

invisible(NULL)
