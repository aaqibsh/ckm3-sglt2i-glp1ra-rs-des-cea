#!/usr/bin/env Rscript
# =============================================================================
# CKM-HEOR: Drug price scenarios, threshold prices by payer, and the two-way
# price chart (CKM Stage 3). Post-processing only: no simulation.
# =============================================================================
# Drug cost accrues at the commercial price before age 65 and at the Medicare
# price after it (c_drug_com, c_drug_mcr); the commercial GLP-1 RA price depends on
# diabetes status. Costs are linear in each price, so the results at any set of
# prices follow exactly from each patient's base-case drug cost in each payer
# period (reprice(), 09_results.R). QALYs do not depend on price.
#
# Usage:  Rscript scripts/price_scenarios.R      (after run_base_case.R or download)
# Reads:  outputs/tables/patient_level_stage3.csv.gz
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
ps <- fread(tab(sprintf("patient_level_stage%d.csv.gz", STAGE)))
p0 <- drug_prices(l_params)

# ---- Price sets (annual, per patient on treatment) ----
# Medicare negotiated prices: empagliflozin $197 and semaglutide $274 per 30 days.
# GLP-1 Bridge / Medicaid BALANCE price: $245 per month. Self-pay: $349 per month.
# 2027 list price of Ozempic: $675 per month; SGLT2i list price (WAC) about $6,500
# per year. Generic dapagliflozin: CMS NADAC, $0.18445 per 10-mg tablet (21 Oct
# 2026), labeled for glycemic control and HF hospitalization risk reduction in type
# 2 diabetes. SGLT2i at a net price: the semaglutide net-to-list ratio (ICER/SSR
# Health net $6,830 vs Wegovy list $1,349 per month = 0.422) applied to the SGLT2i
# list price.
mfp_s <- 197 * 365 / 30; mfp_g <- 274 * 365 / 30
generic_dapa <- round(0.18445 * 365)
net_to_list <- 6830 / (1349 * 12)
sp <- function(...) { pr <- p0; for (a in list(...)) pr <- do.call(set_prices, c(list(pr), a)); pr }
price_sets <- list(
  "Base case: commercial before 65, Medicare from 65" = p0,
  "All commercial" = sp(list("sglt2i", mcr = p0[["cost_sglt2i"]]),
                        list("glp1ra", mcr = p0[["cost_glp1ra"]], dm = "nodm"),
                        list("glp1ra", mcr = p0[["cost_glp1ra_dm"]], dm = "dm")),
  "All Medicare negotiated prices" = sp(list("sglt2i", com = mfp_s, mcr = mfp_s), list("glp1ra", com = mfp_g, mcr = mfp_g)),
  "GLP-1 RA Wegovy-based net price with and without diabetes ($6,830)" = sp(list("glp1ra", com = 6830)),
  "GLP-1 RA at $245 per month (GLP-1 Bridge, Medicaid)" = sp(list("glp1ra", com = 245 * 12, mcr = 245 * 12)),
  "GLP-1 RA at self-pay price ($349 per month)" = sp(list("glp1ra", com = 349 * 12, mcr = 349 * 12)),
  "2027 list prices before 65 (SGLT2i $6,500; GLP-1 RA $8,100)" = sp(list("sglt2i", com = 6500), list("glp1ra", com = 675 * 12)),
  "Generic dapagliflozin with type 2 diabetes, brand without" = sp(list("sglt2i", com = generic_dapa, mcr = generic_dapa, dm = "dm")),
  "Generic dapagliflozin, all patients" = sp(list("sglt2i", com = generic_dapa, mcr = generic_dapa)),
  "SGLT2i at a net price (semaglutide net-to-list ratio)" = sp(list("sglt2i", com = round(6500 * net_to_list)))
)

rows <- rbindlist(lapply(names(price_sets), function(nm) {
  pr <- price_sets[[nm]]
  r <- reprice(ps, p0, pr, wtp = WTP_THRESHOLD)
  r$incremental[, `:=`(price_set = nm,
                       sglt2i_commercial = pr[["cost_sglt2i"]], sglt2i_commercial_dm = pr[["cost_sglt2i_dm"]],
                       sglt2i_medicare = pr[["cost_sglt2i_mcr"]], sglt2i_medicare_dm = pr[["cost_sglt2i_mcr_dm"]],
                       glp1ra_commercial = pr[["cost_glp1ra"]], glp1ra_commercial_dm = pr[["cost_glp1ra_dm"]],
                       glp1ra_medicare = pr[["cost_glp1ra_mcr"]], glp1ra_medicare_dm = pr[["cost_glp1ra_mcr_dm"]])]
}))
setcolorder(rows, "price_set")
fwrite(rows[, stage := STAGE], tab(sprintf("price_scenarios_stage%d.csv", STAGE)))
print(rows[, .(price_set, comparison, inc_cost = round(inc_cost), inc_qaly = round(inc_qaly, 3),
               icer_label, inmb = round(inmb))])

# ---- Threshold prices by payer basis and WTP ----
thr <- threshold_prices(ps, l_params, wtps = WTPS)[, stage := STAGE]
fwrite(thr, tab(sprintf("price_thresholds_stage%d.csv", STAGE)))
print(thr[wtp == WTP_THRESHOLD, .(comparison, basis, current_price = round(current_price),
                                  threshold_price = round(threshold_price))])

# ---- Two-way chart: preferred strategy by single annual price per class ----
grid <- CJ(p_s = seq(0, 8000, by = 100), p_g = seq(0, 10000, by = 100))
arms <- reprice(ps, p0, c())$arms
d_s <- arms[arm == "sglt2i", d_com + d_mcr]; d_g <- arms[arm == "glp1ra", d_com + d_mcr]
base_cost <- setNames(arms$costs - arms$drug_cost, arms$arm)
q <- setNames(arms$qalys, arms$arm)
grid[, `:=`(nmb_soc = WTP_THRESHOLD * q[["soc"]] - base_cost[["soc"]],
            nmb_s = WTP_THRESHOLD * q[["sglt2i"]] - base_cost[["sglt2i"]] - p_s * d_s,
            nmb_g = WTP_THRESHOLD * q[["glp1ra"]] - base_cost[["glp1ra"]] - p_g * d_g)]
grid[, preferred := c("SoC alone", "SGLT2i + SoC", "GLP-1 RA + SoC")[max.col(cbind(nmb_soc, nmb_s, nmb_g), "first")]]
fwrite(grid[, .(sglt2i_price = p_s, glp1ra_price = p_g, preferred)][, stage := STAGE],
       tab(sprintf("price_surface_stage%d.csv", STAGE)))

eff <- function(pr, a) reprice(ps, p0, pr)$arms[arm == a, drug_cost / (d_com + d_mcr)]
pts <- data.table(
  label = c("Base case", "All commercial", "All Medicare", "Generic dapagliflozin\nwith diabetes"),
  p_s = c(eff(p0, "sglt2i"), eff(price_sets[["All commercial"]], "sglt2i"), mfp_s,
          eff(price_sets[["Generic dapagliflozin with type 2 diabetes, brand without"]], "sglt2i")),
  p_g = c(eff(p0, "glp1ra"), eff(price_sets[["All commercial"]], "glp1ra"), mfp_g, eff(p0, "glp1ra")))
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
