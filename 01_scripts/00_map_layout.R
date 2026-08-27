# Shared layout for the map figures of the talk: legend to the right, map as large as the slide
# allows.
#
# Why this exists. A `figure` slide gives the image 12.09 x 4.68 in, an aspect ratio of 2.58, while
# the map of Spain used here is 0.88 high per unit wide. Composing the legend as a strip UNDER the
# maps, which is what every map figure did until 2026-08-24, added 1.2 to 2.15 in of height and
# pushed the whole figure to an aspect ratio between 1.65 and 1.80. PowerPoint then scales to fit,
# the binding dimension becomes the height, and between a quarter and a third of the available
# width is left empty on both sides. The maps end up drawn much smaller than the slide can afford,
# which is why the agreement hatching was unreadable when projected.
#
# Moving the legend into a right-hand column removes that height and spends it on width instead, so
# the figure's aspect ratio lands near the slot's and the map fills what it is given.
#
# Sourced by the figure scripts after 00_paths.R.

# --- the slide's own geometry ------------------------------------------------------------------
# Kept in step with 72_build_talk_pptx.py: W 13.333 in, MARGIN 0.62, a one-line title block of
# 0.52 in plus a 0.12 rule and 0.22 of air, a caption band of 0.62 and a footer of 0.72.
SLOT_W <- 12.093
SLOT_H <- 4.68
SLOT_AR <- SLOT_W / SLOT_H

# Height that makes a figure of this width match the slide slot exactly, so neither dimension is
# wasted when PowerPoint scales it.
slot_height <- function(width) width / SLOT_AR

# Width in inches to reserve for the legend column. Two values because a legend of three class
# labels needs less room than one that also carries hatch samples with a sentence beside them.
LEG_IN <- c(plain = 1.85, hatch = 2.45)

# --- the legend itself -------------------------------------------------------------------------
# Items stack downwards from the top, so the legend reads in the same order as the classes and
# leaves the bottom of the column empty rather than centring a short list against a tall map.
#
# `items` is a list of entries, each either
#   list(lab = , fill = )                        a solid class swatch, or
#   list(lab = , hatch = list(gap=, col=, cross=))  a sample of the real hatch texture.
# The hatch sample is drawn rather than described so it can be matched against the map by eye.
legend_column <- function(items, size = 4.0, title = NULL, wrap = 20) {
  n <- length(items)
  top <- n + 0.85
  SW <- 0.34                             # half-width of a swatch, in the column's own x units
  X0 <- 0.10

  # A column is narrow by construction, so a label that fits a full-width strip does not fit here.
  # The hatch entry in particular is a sentence, not a word. Wrapping it keeps the column from
  # having to be widened at the maps' expense, which is the whole point of moving the legend.
  fold <- function(x) paste(strwrap(x, width = wrap), collapse = "\n")

  g <- ggplot() + coord_cartesian(xlim = c(0, 10), ylim = c(0.25, top + 0.35), expand = FALSE)

  for (k in seq_len(n)) {
    it <- items[[k]]
    y <- n - k + 1                       # first item at the top
    if (!is.null(it$fill)) {
      g <- g + annotate("rect", xmin = X0, xmax = X0 + 2 * SW, ymin = y - 0.22, ymax = y + 0.22,
                        fill = it$fill, colour = NA)
    } else {
      h <- it$hatch
      xs <- seq(X0, X0 + 2 * SW, by = max(h$gap, 0.02) * 2.6)
      seg <- data.frame(x = xs, xend = xs + 0.30, y = y - 0.22, yend = y + 0.22)
      g <- g + geom_segment(data = seg, aes(x = x, y = y, xend = xend, yend = yend),
                            colour = h$col, linewidth = 0.5)
      if (isTRUE(h$cross))
        g <- g + geom_segment(data = seg, aes(x = xend, y = y, xend = x, yend = yend),
                              colour = h$col, linewidth = 0.5)
    }
    g <- g + annotate("text", x = X0 + 2 * SW + 0.30, y = y, label = fold(it$lab),
                      hjust = 0, vjust = 0.5, size = size, colour = "grey20", lineheight = 0.95)
  }

  if (!is.null(title))
    g <- g + annotate("text", x = X0, y = top, label = title, hjust = 0, vjust = 1,
                      size = size - 0.4, fontface = "bold", colour = "grey45")

  g + theme_void() + theme(plot.margin = margin(2, 2, 2, 6))
}

# --- composition -------------------------------------------------------------------------------
# Builds the row of map panels with the legend column on its right, and sizes it so the maps share
# all the width the legend does not take.
#
# The row is assembled with wrap_plots rather than with `|`, because `|` flattens a patchwork on its
# left-hand side: composing three maps and then adding a legend with `|` yields four columns, and a
# widths vector of length two then fails inside wrap_dims(). Sizing the row here keeps the two in
# step whatever the caller passes.
map_row_with_legend <- function(panels, legend, legend_in = LEG_IN[["plain"]]) {
  n <- length(panels)
  patchwork::wrap_plots(c(panels, list(legend)), nrow = 1) +
    patchwork::plot_layout(widths = grid::unit(c(rep(1, n), legend_in),
                                               c(rep("null", n), "in")))
}
