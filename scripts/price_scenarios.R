#!/usr/bin/env Rscript
# =============================================================================
# CKM-HEOR: Drug price scenarios, threshold prices by payer, and the two-way
# price chart (CKM Stage 3). Post-processing only: no simulation.
# =============================================================================
# Drug cost accrues at the commercial price before age 65 and at the Medicare
# price after it (c_drug_com, c_drug_mcr). Costs are linear in each price, so the
# results at any set of prices follow exactly from the base-case drug cost in each
# payer period (reprice(), 09_results.R). QALYs do not depend on price.
#
# Usage:  Rscript scripts/price_scenarios.R      (after run_base_case.R or download)
# Writes: outputs/tables/price_scenarios_stage3.csv
#         outputs/tables/price_thresholds_stage3.csv
#         outputs/tables/price_surface_stage3.csv
#         outputs/figures/price_surface_stage3.png
# =============================================================================

suppressMessages({
  source("R/00_setup.R")
  source("R/01_parameters.R")
  source("R/09_results.R")
})

STAGE <- 3
WTPS <- c(50000, 100000, 120000, 150000)
tab <- function(x) sprintf("outputs/tables/%s", x)
arms <- fread(tab(sprintf("base_case_stage%d_arms.csv", STAGE)))
p0 <- drug_prices(l_params)

# ---- Price sets (annual, per patient on treatment) ----
# Medicare negotiated prices: empagliflozin $197 and semaglutide $274 per 30 days.
# GLP-1 Bridge / Medicaid BALANCE price: $245 per month. Self-pay: $349 per month.
# 2027 list price of Ozempic: $675 per month. Generic dapagliflozin: CMS NADAC,
# $0.18445 per 10-mg tablet (21 Oct 2026). Ozempic-adjusted commercial net: ICER
# semaglutide net price x Ozempic/Wegovy list-price ratio (1,028/1,349).
mfp_s <- 197 * 365 / 30; mfp_g <- 274 * 365 / 30
generic_dapa <- round(0.18445 * 365)
price_sets <- list(
  "Base case: commercial before 65, Medicare from 65" = c(),
  "All commercial" = c(cost_sglt2i_mcr = p0[["cost_sglt2i"]], cost_glp1ra_mcr = p0[["cost_glp1ra"]]),
  "All Medicare negotiated prices" = c(cost_sglt2i = mfp_s, cost_glp1ra = mfp_g,
                                       cost_sglt2i_mcr = mfp_s, cost_glp1ra_mcr = mfp_g),
  "GLP-1 RA at $245 per month (GLP-1 Bridge, Medicaid)" = c(cost_glp1ra = 245 * 12, cost_glp1ra_mcr = 245 * 12),
  "GLP-1 RA at self-pay price ($349 per month)" = c(cost_glp1ra = 349 * 12, cost_glp1ra_mcr = 349 * 12),
  "GLP-1 RA commercial net adjusted to Ozempic" = c(cost_glp1ra = round(6830 * 1028 / 1349)),
  "2027 list prices before 65 (SGLT2i $6,500; GLP-1 RA $8,100)" = c(cost_sglt2i = 6500, cost_glp1ra = 675 * 12),
  "Generic dapagliflozin, all payers" = c(cost_sglt2i = generic_dapa, cost_sglt2i_mcr = generic_dapa),
  "Previous analysis prices (SGLT2i $4,800; GLP-1 RA $7,500, all payers)" =
    c(cost_sglt2i = 4800, cost_glp1ra = 7500, cost_sglt2i_mcr = 4800, cost_glp1ra_mcr = 7500)
)

rows <- rbindlist(lapply(names(price_sets), function(nm) {
  pr <- p0; pr[names(price_sets[[nm]])] <- price_sets[[nm]]
  r <- reprice(arms, p0, pr, wtp = WTP_THRESHOLD)
  r$incremental[, `:=`(price_set = nm,
                       sglt2i_commercial = pr[["cost_sglt2i"]], sglt2i_medicare = pr[["cost_sglt2i_mcr"]],
                       glp1ra_commercial = pr[["cost_glp1ra"]], glp1ra_medicare = pr[["cost_glp1ra_mcr"]])]
}))
setcolorder(rows, "price_set")
fwrite(rows[, stage := STAGE], tab(sprintf("price_scenarios_stage%d.csv", STAGE)))
print(rows[, .(price_set, comparison, inc_cost = round(inc_cost), inc_qaly = round(inc_qaly, 3),
               icer_label, inmb = round(inmb))])

# ---- Threshold prices by payer basis and WTP ----
inc <- rbindlist(lapply(DEFAULT_COMPARISONS, function(cp) compare_tab(arms, cp[1], cp[2])))
thr <- threshold_prices(arms, inc, l_params, wtps = WTPS)[, stage := STAGE]
fwrite(thr, tab(sprintf("price_thresholds_stage%d.csv", STAGE)))
print(thr[wtp == WTP_THRESHOLD, .(comparison, basis, current_price = round(current_price),
                                  threshold_price = round(threshold_price))])

# ---- Two-way chart: preferred strategy by single annual price per class ----
grid <- CJ(p_s = seq(0, 8000, by = 100), p_g = seq(0, 10000, by = 100))
ty <- treatment_years(arms, p0)
d_s <- ty[arm == "sglt2i", d_com + d_mcr]; d_g <- ty[arm == "glp1ra", d_com + d_mcr]
base_cost <- setNames(arms$costs - arms$drug_cost, arms$arm)
q <- setNames(arms$qalys, arms$arm)
grid[, `:=`(nmb_soc = WTP_THRESHOLD * q[["soc"]] - base_cost[["soc"]],
            nmb_s = WTP_THRESHOLD * q[["sglt2i"]] - base_cost[["sglt2i"]] - p_s * d_s,
            nmb_g = WTP_THRESHOLD * q[["glp1ra"]] - base_cost[["glp1ra"]] - p_g * d_g)]
grid[, preferred := c("SoC alone", "SGLT2i + SoC", "GLP-1 RA + SoC")[max.col(cbind(nmb_soc, nmb_s, nmb_g), "first")]]
fwrite(grid[, .(sglt2i_price = p_s, glp1ra_price = p_g, preferred)][, stage := STAGE],
       tab(sprintf("price_surface_stage%d.csv", STAGE)))

eff <- function(pc, pm, a) (pc * ty[arm == a, d_com] + pm * ty[arm == a, d_mcr]) / ty[arm == a, d_com + d_mcr]
pts <- data.table(
  label = c("Base case", "All commercial", "All Medicare", "Generic dapagliflozin,\nGLP-1 RA base"),
  p_s = c(eff(p0[["cost_sglt2i"]], p0[["cost_sglt2i_mcr"]], "sglt2i"), p0[["cost_sglt2i"]], mfp_s, generic_dapa),
  p_g = c(eff(p0[["cost_glp1ra"]], p0[["cost_glp1ra_mcr"]], "glp1ra"), p0[["cost_glp1ra"]], mfp_g,
          eff(p0[["cost_glp1ra"]], p0[["cost_glp1ra_mcr"]], "glp1ra")))
dir.create("outputs/figures", recursive = TRUE, showWarnings = FALSE)
g <- ggplot(grid, aes(p_s, p_g, fill = preferred)) +
  geom_raster() +
  scale_fill_manual(values = c("SGLT2i + SoC" = "#9ecae1", "GLP-1 RA + SoC" = "#fdae6b", "SoC alone" = "#d9d9d9"),
                    name = "Preferred strategy") +
  geom_point(data = pts, aes(p_s, p_g), inherit.aes = FALSE, size = 2) +
  geom_text(data = pts, aes(p_s, p_g, label = label), inherit.aes = FALSE, hjust = -0.08, vjust = 0.5, size = 3) +
  scale_x_continuous(labels = scales::dollar, expand = c(0, 0)) +
  scale_y_continuous(labels = scales::dollar, expand = c(0, 0)) +
  labs(x = "SGLT2i annual price (all payers)", y = "GLP-1 RA annual price (all payers)") +
  theme_minimal(base_size = 11) + theme(legend.position = "bottom", plot.margin = margin(5, 20, 5, 5))
ggsave(sprintf("outputs/figures/price_surface_stage%d.png", STAGE), g, width = 7, height = 6, dpi = 300)
cat("Price scenarios written.\n")
