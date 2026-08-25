# ---------------------------------------------------------------------------------------
# Graded diagonal hatching for model agreement.
#
# The AR6 convention is binary: colour where at least 80 % of the models agree, diagonal lines
# where they do not. That answers "is this robust" but not "how far from robust", and with an
# eleven-model ensemble the second question has real spread: on the end-of-century SSP3-7.0 map
# 57 % of the cropland is unanimous, 26 % agrees at 9 or 10 of 11, and 17 % does not reach the AR6
# threshold at all. The binary version paints those last two the same.
#
# THE POSSIBLE VALUES ARE NOT ARBITRARY. Agreement is counted as the larger of the two sides, so
# with 11 models it can only be 6, 7, 8, 9, 10 or 11 out of 11: 54.5, 63.6, 72.7, 81.8, 90.9 or
# 100 %. There is no such thing as 30 % or 50 % agreement here, and a legend promising those bands
# would be describing something the data cannot produce. The bands below are therefore defined in
# MODEL COUNTS and the percentages are derived, not the other way round.
#
#   unanimous   n/n            no lines
#   robust      >= 80 %, < n   sparse thin grey lines            (meets the AR6 criterion)
#   weak        <  80 %        dense near-black crossed lines    (fails it)
#
# On colour. The hatching sits on top of a three-colour categorical fill (blue, orange, red), and
# any mid-tone hue that reads well on one of them disappears on another. The only ramp that keeps
# its contrast over all three is lightness, so the bands are separated by grey against near-black,
# reinforced by line spacing, line width and, for the weakest band, a second set of lines crossing
# the first. That redundancy is also what makes the figure survive greyscale printing and
# colour-vision deficiency. Swap HATCH_COL if literal hues are wanted instead.
# ---------------------------------------------------------------------------------------

AR6_FRAC  <- 0.8

# TWO MODES, and the plain one is the default.
#
# The graded version below was built and then set aside: on a map that already carries a
# three-colour categorical fill, three levels of texture make the transition zones busy enough that
# the viability pattern, which is the actual result, stops being the first thing the eye finds. The
# binary AR6 mark says the one thing a viewer has to know (does the ensemble support this cell or
# not) and says it without competing with the fill.
#
# The graded code is kept rather than deleted because the analysis behind it is sound and the
# decision is aesthetic: set PLINIUS_HATCH_BANDS=TRUE to get three bands back. Nothing else has to
# change, legends included.
HATCH_BANDS <- toupper(Sys.getenv("PLINIUS_HATCH_BANDS", "FALSE")) %in% c("TRUE", "1", "YES")

HATCH_COL <- c(robust = "#787878", weak = "#0d0d0d", plain = "grey15")
HATCH_LWD <- c(robust = 0.13, weak = 0.20, plain = 0.15)
HATCH_GAP <- c(robust = 15000, weak = 7000, plain = 9000)   # metres between lines
# Kept short on purpose: these ride in a one-line legend strip next to three class
# labels, and anything longer collides with the next item at frame width.
HATCH_LAB <- c(robust = "9-10 of 11 (82-91%)",
               weak   = "≤8 of 11 (≤73%)",
               plain  = "fewer than 80% of models agree")

# What the legend has to show, derived from the mode so the callers never decide it themselves.
# Each entry: label, line gap in legend units, colour, and whether the sample is crossed.
hatch_legend_items <- function() {
  if (HATCH_BANDS)
    list(list(lab = HATCH_LAB[["robust"]], gap = 0.075, col = HATCH_COL[["robust"]], cross = FALSE),
         list(lab = HATCH_LAB[["weak"]],   gap = 0.038, col = HATCH_COL[["weak"]],   cross = TRUE))
  else
    list(list(lab = HATCH_LAB[["plain"]],  gap = 0.055, col = HATCH_COL[["plain"]],  cross = FALSE))
}

# Returns an sf of line segments covering the cells where `mask_rast` is TRUE (or 1), ready to add
# to a ggplot with geom_sf(). NULL when nothing is masked, which the caller must tolerate: a run
# where every model agrees is a legitimate outcome, not an error.
#
# Implementation notes, both of which matter:
#   - the mask is coarsened before it is turned into polygons. A 1 km disagreement mask over Spain
#     polygonises into tens of thousands of rings, which is slow to build and produces hatching so
#     fragmented it reads as noise. Hatching is a coarse visual device and 4 km is plenty.
#   - the lines are generated across the bounding box and then clipped to the mask, rather than
#     drawn per polygon. That keeps them continuous and in phase across the whole map, which is
#     what makes the overlay read as one texture instead of as many little patches.
hatch_lines <- function(mask_rast, spacing = 9000, coarsen_to = 4000, angle = 45) {
  stopifnot(inherits(mask_rast, "SpatRaster"))
  r <- mask_rast
  fact <- max(1, round(coarsen_to / mean(res(r))))
  if (fact > 1) r <- aggregate(r, fact = fact, fun = "max", na.rm = TRUE)
  r <- ifel(r > 0, 1L, NA)
  if (all(is.na(values(r)))) return(NULL)

  pol <- tryCatch(as.polygons(r, dissolve = TRUE), error = function(e) NULL)
  if (is.null(pol) || !nrow(pol)) return(NULL)
  ps <- sf::st_make_valid(sf::st_union(sf::st_as_sf(pol)))
  bb <- sf::st_bbox(ps)

  # Parallel lines y = tan(angle) * x + c, with c stepped so the perpendicular gap is `spacing`.
  # The range of c is taken from the four corners of the bounding box rather than from one pair of
  # them: with a negative slope the pairing flips and the sequence would run backwards, which is
  # how the 135-degree pass of the cross-hatch failed with an error from seq().
  m <- tan(angle * pi / 180)
  step <- spacing / abs(cos(atan(m)))
  corners <- expand.grid(x = c(bb[["xmin"]], bb[["xmax"]]), y = c(bb[["ymin"]], bb[["ymax"]]))
  cc <- corners$y - m * corners$x
  cs <- seq(min(cc) - step, max(cc) + step, by = step)
  segs <- lapply(cs, function(c0)
    sf::st_linestring(rbind(c(bb[["xmin"]], m * bb[["xmin"]] + c0),
                            c(bb[["xmax"]], m * bb[["xmax"]] + c0))))
  ln <- sf::st_sfc(segs, crs = sf::st_crs(ps))
  out <- suppressWarnings(sf::st_intersection(ln, ps))
  out <- out[!sf::st_is_empty(out)]
  if (!length(out)) return(NULL)
  sf::st_sf(geometry = out)
}

# Convenience wrapper kept for callers that only want the binary AR6 mask.
# `counter` is the count of models on one side; agreement is the larger of the two sides.
low_agreement_mask <- function(counter, n_models, frac = AR6_FRAC) {
  need <- ceiling(frac * n_models)
  # max() rather than pmax(): on a SpatRaster pmax falls through to the base method and compares
  # the objects rather than the cells, which fails with an unhelpful message about 'x || y'.
  agree <- max(counter, n_models - counter)
  ifel(agree >= need, NA, 1L)
}

# The graded version. Returns a named list of sf objects, one per band that has any area, in the
# order they should be drawn. `restrict` is an optional raster (typically the cropland mask) so the
# hatching never spills onto land the analysis never counted.
agreement_bands <- function(counter, n_models, restrict = NULL, frac = AR6_FRAC) {
  need <- ceiling(frac * n_models)
  agree <- max(counter, n_models - counter)
  keep <- function(r) if (is.null(restrict)) r else mask(r, restrict > 0, maskvalues = c(0, NA))

  # Plain mode: one mark, everything that fails the AR6 threshold, drawn as single diagonals.
  if (!HATCH_BANDS) {
    hp <- hatch_lines(keep(ifel(agree < need, 1L, NA)), spacing = HATCH_GAP[["plain"]])
    return(if (is.null(hp)) list() else list(plain = hp))
  }

  m_robust <- keep(ifel(agree >= need & agree < n_models, 1L, NA))
  m_weak   <- keep(ifel(agree <  need, 1L, NA))

  out <- list()
  hr <- hatch_lines(m_robust, spacing = HATCH_GAP[["robust"]])
  if (!is.null(hr)) out$robust <- hr
  # The weak band is crossed: two sets of lines at right angles. AR6 Approach C uses crossed lines
  # for conflicting signals, and here it doubles as the densest step of the ramp.
  hw1 <- hatch_lines(m_weak, spacing = HATCH_GAP[["weak"]], angle = 45)
  hw2 <- hatch_lines(m_weak, spacing = HATCH_GAP[["weak"]], angle = 135)
  hw <- do.call(rbind, Filter(Negate(is.null), list(hw1, hw2)))
  if (!is.null(hw) && nrow(hw)) out$weak <- hw
  out
}

# Draws the bands returned by agreement_bands(). The weak band gets a white halo underneath so it
# stays crisp over the dark red fill, where a near-black line would otherwise vanish.
geom_agreement <- function(bands) {
  gg <- list()
  if (!is.null(bands$plain))
    return(list(ggplot2::geom_sf(data = bands$plain, colour = HATCH_COL[["plain"]],
                                 linewidth = HATCH_LWD[["plain"]])))
  if (!is.null(bands$robust))
    gg <- c(gg, list(ggplot2::geom_sf(data = bands$robust, colour = HATCH_COL[["robust"]],
                                      linewidth = HATCH_LWD[["robust"]])))
  if (!is.null(bands$weak))
    gg <- c(gg, list(
      ggplot2::geom_sf(data = bands$weak, colour = "white",
                       linewidth = HATCH_LWD[["weak"]] * 2.4, alpha = 0.55),
      ggplot2::geom_sf(data = bands$weak, colour = HATCH_COL[["weak"]],
                       linewidth = HATCH_LWD[["weak"]])))
  gg
}

invisible(NULL)
