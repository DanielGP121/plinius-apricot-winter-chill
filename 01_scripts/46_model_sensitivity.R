#!/usr/bin/env Rscript
# Model sensitivity against the chill each model leaves at the end of the century (fig55).
#
# fig54 ranks the eleven models by the chill they leave and says nothing about why the order is
# what it is. The obvious explanation is global sensitivity: a model that warms more should leave
# less chill. This figure tests that against the published sensitivity of each model, and the
# answer is only half yes, which is the part worth knowing.
#
# The harsh end behaves as expected. The mild end does not: the model that leaves the most chill
# has a mid-table transient response, above four models that leave less chill than it does. If the
# optimistic bound of the study rests on a regional feature of one model rather than on its global
# sensitivity, then screening the ensemble by sensitivity would not address it, which is a
# different conclusion from the one the harsh end alone would suggest.
#
# The figure also marks the three models that declare a byte-identical atmospheric component in the
# CMIP6 controlled vocabulary. The ensemble was assembled with one model per institutional family,
# and those three come from different institutions, so an institutional filter passes them as
# independent while they share a code base.
#
# SENSITIVITY VALUES ARE LITERATURE, NOT OUTPUT. They are typed below because no table in this
# project produces them, in the same way the two cultivar requirements are typed. Their source is
# IPCC AR6 WG1, Chapter 7 Supplementary Material, Table 7.SM.5 (Forster et al. 2021), which reports
# ECS and TCR per CMIP6 model from Schlund et al. 2020, Meehl et al. 2020 and Zelinka et al. 2020.
# One cell of that table is blank: IITM-ESM has no ECS entry. The value used for it comes from the
# Zelinka et al. 2020 companion dataset instead, is an effective sensitivity computed a different
# way, and is flagged on the figure rather than passed off as an AR6 number.
#
# Usage: Rscript 46_model_sensitivity.R [--scenario ssp370]
# Writes: 02_outputs/figures_chill/fig55_model_sensitivity.png
#         02_outputs/model_sensitivity_numbers.csv
# Needs:  02_outputs/model_ranking_<scenario>.csv, written by 43_model_ranking.R

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(patchwork)
  library(ggrepel)
})

# Long strings are folded before they reach ggplot. A subtitle wider than the panel is silently
# clipped at the device edge rather than wrapped, which cost the first version of this figure both
# of its subtitles and its caption.
fold <- function(x, width = 108) paste(strwrap(x, width = width), collapse = "\n")

.f <- grep("^--file=", commandArgs(FALSE), value = TRUE)
.dir <- if (length(.f)) dirname(normalizePath(sub("^--file=", "", .f[1]))) else getwd()
source(file.path(.dir, "00_paths.R"))

getarg <- function(flag, default) {
  a <- commandArgs(TRUE)
  i <- match(flag, a)
  if (is.na(i) || i == length(a)) default else a[i + 1L]
}
SCEN <- getarg("--scenario", "ssp370")
SCEN_LAB <- c(ssp126 = "SSP1-2.6", ssp245 = "SSP2-4.5", ssp370 = "SSP3-7.0")[[SCEN]]

FIG_TITLE <- toupper(Sys.getenv("PLINIUS_FIG_TITLE", "FALSE")) %in% c("TRUE", "1", "YES")
ttl <- function(x) if (FIG_TITLE) x else NULL

n_en <- function(x, d = 2) formatC(x, format = "f", digits = d, big.mark = ",", decimal.mark = ".")

talk_theme <- theme_minimal(base_size = 13) +
  theme(plot.title = element_text(face = "bold", size = 14),
        plot.subtitle = element_text(size = 11, colour = "grey30"),
        plot.caption = element_text(size = 8.5, colour = "grey40", hjust = 0),
        panel.grid.minor = element_blank(),
        legend.position = "none")

# § 1 — the published sensitivities, and the shared atmospheric component
#
# `ecs_source` exists so the one non-AR6 value cannot be quietly plotted as if it were AR6. The
# `shared_atmos` flag marks the models declaring MetUM-HadGEM3-GA7.1 (N96, 192 x 144, 85 levels),
# which is identical string for string across the three.
SENS <- data.table(
  model    = c("ACCESS-CM2", "CMCC-CM2-SR5", "CNRM-ESM2-1", "EC-Earth3-Veg", "IITM-ESM",
               "KACE-1-0-G", "MIROC6", "MPI-ESM1-2-HR", "MRI-ESM2-0", "NorESM2-MM",
               "UKESM1-0-LL"),
  ecs      = c(4.72, 3.52, 4.76, 4.31, 2.37, 4.75, 2.61, 2.98, 3.15, 2.50, 5.34),
  tcr      = c(2.10, 2.09, 1.86, 2.62, 1.71, 2.04, 1.55, 1.66, 1.64, 1.33, 2.79),
  ecs_ar6  = c(TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE),
  shared_atmos = c(TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, TRUE)
)

# AR6 WG1 Chapter 7, Section 7.5.5: assessed best estimates and likely ranges.
AR6 <- list(ecs = c(best = 3.0, lo = 2.5, hi = 4.0),
            tcr = c(best = 1.8, lo = 1.4, hi = 2.2))

# § 2 — the chill each model leaves, from the ranking table rather than recomputed
rank_path <- file.path(OUT_DIR, sprintf("model_ranking_%s.csv", SCEN))
if (!file.exists(rank_path))
  stop("missing ", rank_path, "\n  run: Rscript 43_model_ranking.R --scenario ", SCEN)
rk <- fread(rank_path)

d <- merge(rk[, .(model, far_swc_CP, base_swc_CP, delta_CP, far_n_seasons)], SENS, by = "model")
if (nrow(d) != nrow(SENS))
  stop("model names in model_ranking_", SCEN, ".csv do not match the sensitivity table; ",
       "missing: ", paste(setdiff(SENS$model, rk$model), collapse = ", "))

# § 3 — how much of the ranking sensitivity explains
#
# Spearman rather than Pearson: the claim being tested is about ordering, and with eleven points a
# single leveraged model would dominate a Pearson coefficient. Both are reported so the difference
# between them is visible rather than hidden by the choice.
rho_tcr <- suppressWarnings(cor(d$tcr, d$far_swc_CP, method = "spearman"))
rho_ecs <- suppressWarnings(cor(d$ecs, d$far_swc_CP, method = "spearman"))
r2_tcr  <- suppressWarnings(cor(d$tcr, d$far_swc_CP)^2)
r2_ecs  <- suppressWarnings(cor(d$ecs, d$far_swc_CP)^2)

# The mild outlier, and how many models with a LOWER transient response leave LESS chill than it
# does. If that count is zero the mild end is explained by sensitivity; if it is not, it is not.
mild <- d[which.max(far_swc_CP)]
n_below_mild <- d[tcr < mild$tcr & far_swc_CP < mild$far_swc_CP, .N]
harsh <- d[which.min(far_swc_CP)]

cat(sprintf("chill vs TCR: rho = %.2f, R2 = %.2f\n", rho_tcr, r2_tcr))
cat(sprintf("chill vs ECS: rho = %.2f, R2 = %.2f\n", rho_ecs, r2_ecs))
cat(sprintf("harshest: %s, TCR %.2f, %.1f CP\n", harsh$model, harsh$tcr, harsh$far_swc_CP))
cat(sprintf("mildest:  %s, TCR %.2f, %.1f CP; %d models with lower TCR leave less chill\n",
            mild$model, mild$tcr, mild$far_swc_CP, n_below_mild))

# § 4 — the panels
#
# Labels are repelled rather than placed by hand. Four of the eleven models sit close enough in
# both coordinates that a fixed offset overlapped them, and on this figure an unreadable label is
# the whole point lost: the argument is about which named model sits where.
panel <- function(xvar, xlab, assessed, sub) {
  dd <- copy(d)
  dd[, xx := get(xvar)]
  rng <- range(dd$xx)
  pad <- diff(rng) * 0.14
  dd[, lab := model]
  if (xvar == "ecs") dd[ecs_ar6 == FALSE, lab := paste0(model, " *")]

  ggplot(dd, aes(xx, far_swc_CP)) +
    annotate("rect", xmin = assessed[["lo"]], xmax = assessed[["hi"]], ymin = -Inf, ymax = Inf,
             fill = "grey70", alpha = 0.16) +
    annotate("segment", x = assessed[["best"]], xend = assessed[["best"]], y = -Inf, yend = Inf,
             colour = "grey55", linetype = "22", linewidth = 0.4) +
    geom_smooth(method = "lm", formula = y ~ x, se = FALSE, colour = "grey65",
                linewidth = 0.5, linetype = "solid") +
    geom_point(aes(shape = shared_atmos, fill = shared_atmos), size = 3.4, stroke = 0.7,
               colour = "grey20") +
    geom_text_repel(aes(label = lab), size = 3.3, colour = "grey15", seed = 42,
                    min.segment.length = 0.25, segment.colour = "grey70", segment.size = 0.3,
                    box.padding = 0.34, point.padding = 0.22, max.overlaps = 20) +
    scale_shape_manual(values = c(`FALSE` = 21, `TRUE` = 24)) +
    scale_fill_manual(values = c(`FALSE` = "white", `TRUE` = "#2C7BB6")) +
    scale_x_continuous(limits = c(rng[1] - pad, rng[2] + pad)) +
    labs(x = xlab, y = "Safe Winter Chill 2071-2100 (CP)", subtitle = fold(sub)) +
    talk_theme
}

p_tcr <- panel("tcr", "Transient climate response (°C)", AR6$tcr,
               sprintf("Transient response explains the ordering only in part: Spearman %.2f. %s, the model leaving the most chill, sits mid-table, and %d models with a lower response leave less chill than it does.",
                       rho_tcr, mild$model, n_below_mild))

p_ecs <- panel("ecs", "Equilibrium climate sensitivity (°C)", AR6$ecs,
               sprintf("Equilibrium sensitivity orders it slightly less well, Spearman %.2f. Shaded band: the AR6 assessed likely range, dashed line its best estimate.",
                       rho_ecs))

cap <- paste0(
  "Filled triangles: the three models declaring the same atmospheric component in the CMIP6 ",
  "controlled vocabulary (MetUM-HadGEM3-GA7.1), from three different institutions. ",
  "Sensitivity from IPCC AR6 WG1 Ch.7 SM Table 7.SM.5",
  if (any(!d$ecs_ar6)) paste0("; * ECS absent from that table, value from Zelinka et al. 2020.")
  else ".")

# The caption rides on the lower panel rather than on the assembled figure: patchwork 1.2.0 with
# ggplot2 4.0.2 has neither a working annotation theme nor a & operator for themes here.
p_ecs <- p_ecs + labs(caption = fold(cap, 132))

fig <- (p_tcr / p_ecs) +
  plot_layout(heights = c(1.32, 1)) +
  plot_annotation(
    title = ttl(sprintf("Model sensitivity against the chill each model leaves under %s",
                        SCEN_LAB)))

# 9 x 7 in is chosen for the slot this figure goes into: a `twocol` slide gives the image about
# 6.8 by 5.3 in, an aspect ratio near 1.28, and a figure drawn far from that ratio gets scaled down
# and loses its labels. Stacked panels reach it; two panels side by side would not.
out <- file.path(FIG_DIR, "fig55_model_sensitivity.png")
ggsave(out, fig, width = 9, height = 7, dpi = 200)
cat("wrote ", out, "\n", sep = "")

fwrite(data.table(
  metric = c("sens_rho_tcr", "sens_rho_ecs", "sens_r2_tcr", "sens_r2_ecs",
             "sens_harsh_model", "sens_harsh_tcr", "sens_mild_model", "sens_mild_tcr",
             "sens_n_lower_tcr_less_chill", "sens_n_shared_atmos"),
  value  = c(n_en(rho_tcr), n_en(rho_ecs), n_en(r2_tcr), n_en(r2_ecs),
             harsh$model, n_en(harsh$tcr), mild$model, n_en(mild$tcr),
             n_below_mild, sum(d$shared_atmos))
), file.path(OUT_DIR, "model_sensitivity_numbers.csv"))
cat("wrote ", file.path(OUT_DIR, "model_sensitivity_numbers.csv"), "\n", sep = "")
