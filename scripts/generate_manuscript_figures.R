#!/usr/bin/env Rscript
# =============================================================================
# Publication figures for the CKM Stage 3 manuscript
# =============================================================================
# Usage:  Rscript scripts/generate_manuscript_figures.R [output_dir]
#         (default output_dir: manuscript/figures)
# Run after analysis/combine_results.R. Every number shown is read from
# outputs/tables, so figures and tables cannot disagree. Figures carry no
# in-figure titles (legends carry them); 300 dpi PNG plus vector PDF.
#   Figure 1: cost-effectiveness planes, (A) SGLT2i + SoC vs SoC,
#             (B) SGLT2i + SoC vs GLP-1 RA + SoC
#   Figure 2: cost-effectiveness acceptability curves
#   Figure 3: one-way sensitivity tornados (INMB), (A) vs SoC, (B) head-to-head
# =============================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(scales)
  library(patchwork)
})
source("R/09_results.R")   # PARAM_LABELS

args <- commandArgs(trailingOnly = TRUE)
out_dir <- if (length(args) >= 1) args[1] else "manuscript/figures"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
tab <- function(x) fread(file.path("outputs/tables", x))

WTP <- 120000
COLOR_SGLT2I <- "#1B365D"; COLOR_GLP1RA <- "#8B263E"; COLOR_SOC <- "#5C6F84"; COLOR_WTP <- "#333333"
CMP_SOC <- "SGLT2i + SoC vs SoC"; CMP_H2H <- "SGLT2i + SoC vs GLP-1 RA + SoC"

theme_pub <- function(base_size = 10) {
  theme_minimal(base_size = base_size) +
    theme(
      axis.title = element_text(face = "bold", size = rel(0.95), color = "#222222"),
      axis.text = element_text(color = "#333333", size = rel(0.9)),
      panel.grid.major = element_line(color = "#E5E5E5", linewidth = 0.4),
      panel.grid.minor = element_blank(),
      legend.position = "bottom", legend.title = element_blank(),
      legend.text = element_text(size = rel(0.9), color = "#222222"),
      plot.tag = element_text(face = "bold", size = rel(1.2)),
      plot.margin = margin(t = 8, r = 14, b = 8, l = 8)
    )
}
save_fig <- function(p, name, w, h) {
  ggsave(file.path(out_dir, paste0(name, ".png")), p, width = w, height = h, dpi = 300, bg = "white")
  ggsave(file.path(out_dir, paste0(name, ".pdf")), p, width = w, height = h)
}
usd <- function(x) paste0(ifelse(x < 0, "-$", "$"), format(round(abs(x)), big.mark = ",", trim = TRUE))

# ---- Figure 1: CE planes ----
psa <- tab("psa_stage3_iterations.csv")
psa_sum <- tab("psa_stage3_summary.csv")
ce_panel <- function(cmp, colour) {
  d <- psa[comparison == cmp]
  s <- psa_sum[comparison == cmp]
  xr <- range(c(0, d$inc_qaly)); yr <- range(c(0, d$inc_cost))
  ggplot(d, aes(inc_qaly, inc_cost)) +
    geom_hline(yintercept = 0, color = "#888888", linewidth = 0.4) +
    geom_vline(xintercept = 0, color = "#888888", linewidth = 0.4) +
    geom_abline(intercept = 0, slope = WTP, linetype = "dashed", color = COLOR_WTP, linewidth = 0.7) +
    geom_point(color = colour, alpha = 0.45, size = 1.4) +
    annotate("point", x = s$mean_inc_qaly, y = s$mean_inc_cost, shape = 23, size = 3.5,
             fill = "#D95F0E", color = "#111111") +
    coord_cartesian(xlim = xr + c(-0.05, 0.05) * diff(xr), ylim = yr + c(-0.05, 0.05) * diff(yr)) +
    scale_x_continuous(labels = number_format(accuracy = 0.01)) +
    scale_y_continuous(labels = dollar_format(big.mark = ",")) +
    labs(x = "Incremental QALYs", y = "Incremental lifetime cost (2025 US $)") +
    theme_pub()
}
fig1 <- (ce_panel(CMP_SOC, COLOR_SGLT2I) | ce_panel(CMP_H2H, COLOR_GLP1RA)) + plot_annotation(tag_levels = "A")
save_fig(fig1, "figure1_ce_plane", 10, 4.6)

# ---- Figure 2: CEAC ----
ceac <- tab("psa_stage3_ceac.csv")
ceac[, Strategy := factor(comparator, levels = c("sglt2i", "glp1ra", "soc"),
                          labels = c("SGLT2i + SoC", "GLP-1 RA + SoC", "SoC alone"))]
fig2 <- ggplot(ceac[wtp <= 200000], aes(wtp, prob_best, color = Strategy, linetype = Strategy)) +
  geom_vline(xintercept = WTP, linetype = "dashed", color = COLOR_WTP, linewidth = 0.6) +
  geom_line(linewidth = 1) +
  scale_color_manual(values = c("SGLT2i + SoC" = COLOR_SGLT2I, "GLP-1 RA + SoC" = COLOR_GLP1RA, "SoC alone" = COLOR_SOC)) +
  scale_linetype_manual(values = c("SGLT2i + SoC" = "solid", "GLP-1 RA + SoC" = "dotdash", "SoC alone" = "longdash")) +
  scale_x_continuous(labels = dollar_format(big.mark = ","), breaks = seq(0, 200000, 40000)) +
  scale_y_continuous(labels = percent_format(accuracy = 1), limits = c(0, 1)) +
  labs(x = "Willingness-to-pay threshold ($/QALY)", y = "Probability strategy is preferred") +
  theme_pub()
save_fig(fig2, "figure2_ceac", 7, 4.8)

# ---- Figure 3: tornados ----
dsa <- tab("dsa_stage3_results.csv")
base <- tab("base_case_stage3_incremental.csv")
tornado_panel <- function(cmp, top_n = 15) {
  b <- base[comparison == cmp, inmb]
  w <- dcast(dsa[comparison == cmp], parameter ~ direction, value.var = c("inmb", "value"))
  w[, range := abs(inmb_DSA_max - inmb_DSA_min)]
  w <- w[order(-range)][seq_len(min(top_n, .N))]
  fv <- function(v) vapply(v, function(x) if (abs(x) >= 100) format(round(x), big.mark = ",", trim = TRUE)
                           else format(signif(x, 3), trim = TRUE, scientific = FALSE), character(1))
  w[, label := sprintf("%s (%s to %s)", ifelse(parameter %in% names(PARAM_LABELS), PARAM_LABELS[parameter], parameter),
                       fv(value_DSA_min), fv(value_DSA_max))]
  w[, label := factor(label, levels = rev(label))]
  bars <- rbind(w[, .(label, input = "Lower bound", xmin = pmin(b, inmb_DSA_min), xmax = pmax(b, inmb_DSA_min))],
                w[, .(label, input = "Upper bound", xmin = pmin(b, inmb_DSA_max), xmax = pmax(b, inmb_DSA_max))])
  ggplot(bars) +
    geom_vline(xintercept = 0, color = "#999999", linewidth = 0.4) +
    geom_linerange(aes(y = label, xmin = xmin, xmax = xmax, color = input), linewidth = 3.6,
                   position = position_dodge(width = 0.55)) +
    geom_vline(xintercept = b, linetype = "dashed", color = "#111111", linewidth = 0.6) +
    scale_color_manual(values = c("Lower bound" = "#2B6CB0", "Upper bound" = "#C53030")) +
    scale_x_continuous(labels = dollar_format(big.mark = ",")) +
    labs(x = sprintf("INMB at $120,000/QALY (base case %s)", usd(b)), y = NULL) +
    theme_pub(9)
}
fig3 <- (tornado_panel(CMP_SOC) / tornado_panel(CMP_H2H)) +
  plot_annotation(tag_levels = "A") + plot_layout(guides = "collect") & theme(legend.position = "bottom")
save_fig(fig3, "figure3_tornado", 8.5, 10)

cat(sprintf("Figures written to %s\n", out_dir))
