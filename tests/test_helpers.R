#!/usr/bin/env Rscript
# =============================================================================
# Unit checks for pure helper functions (no WARDEN run needed)
# Run from the project root: Rscript tests/test_helpers.R
# =============================================================================

suppressMessages({
  library(data.table)
  source("R/01_parameters.R")
  source("R/02_population.R")
  source("R/03_risk_equations.R")
  source("R/04_treatment.R")
})

check <- function(desc, cond) {
  cat(sprintf("  [%s] %s\n", if (isTRUE(cond)) "PASS" else "FAIL", desc))
  if (!isTRUE(cond)) quit(status = 1)
}

cat("--- Treatment effect ---\n")
check("hr_effective: full effect", hr_effective(0.7, 1) == 0.7)
check("hr_effective: no effect", hr_effective(0.7, 0) == 1)
check("hr_effective: half effect", abs(hr_effective(0.7, 0.5) - 0.85) < 1e-12)

cat("--- Waning schedule ---\n")
w <- sapply(1:5, wane_fraction, n_steps = 4)
check("wane_fraction steps 0.875, 0.625, 0.375, 0.125, 0", isTRUE(all.equal(w, c(0.875, 0.625, 0.375, 0.125, 0))))
check("mean retained effect over waning period is 0.5", abs(mean(w[1:4]) - 0.5) < 1e-12)

cat("--- Rescaling pending exponential events ---\n")
t_new <- rescale_pending(c(mi = 12, stroke = Inf), now = 2, h_old = c(mi = 0.1, stroke = 0.1), h_new = c(mi = 0.2, stroke = 0.2))
check("doubling hazard halves remaining time", abs(t_new[["mi"]] - 7) < 1e-12)
check("Inf stays Inf", is.infinite(t_new[["stroke"]]))
# Memorylessness: rescaled Exp(h_old) remainder is Exp(h_new)
set.seed(1); rem <- rexp(2e5, 0.1) * 0.1 / 0.25
check("rescaled remainder has mean 1/h_new", abs(mean(rem) - 4) < 0.05)

cat("--- Kidney trajectory ---\n")
check("stage bounds", stage_lower_bound(1) == 60 && stage_lower_bound(3) == 30 && stage_lower_bound(4) == 15 && is.na(stage_lower_bound(5)))
check("stage sequence 1 -> 3 -> 4 -> 5", next_ckd_stage(1) == 3 && next_ckd_stage(3) == 4 && next_ckd_stage(4) == 5)
check("time to boundary", abs(time_to_next_ckd_stage(45, 1.5, 3) - 10) < 1e-12)
check("eGFR on boundary gives 0, not negative", time_to_next_ckd_stage(30, 2, 3) == 0)
check("ESKD has no further progression", is.infinite(time_to_next_ckd_stage(14, 2, 5)))
set.seed(2); m <- egfr_patient_multiplier(rep(30, 2e5), 0.451, 1.5, rnorm(2e5))
check("heterogeneity multiplier has mean ~1 at UACR 30", abs(mean(m) - 1) < 0.05)
check("ESKD cost replaces CKD 4 cost", ckd_state_cost(5, 7500, 15000, 92000) == 92000)
check("ESKD decrement adds to CKD 4", ckd_state_disutility(5, 0.02, 0.05, 0.20) == 0.25)

cat("--- Risk equations ---\n")
h <- calculate_base_hazards(62, 1, 145, 220, 40, 1, 0, 50, 1, 1, 33, 7.5, 0, 0, 0, 3,
                            c(mi = 2, stroke = 2.5, hf = 3, ckd3 = 1.5, ckd4 = 2.5, eskd = 4))
h_ascvd <- calculate_annual_ascvd_hazard(62, 1, 145, 220, 40, 1, 0, 50, 1, 1, 33, 7.5)
check("MI + stroke hazards sum to ASCVD hazard", abs(h[["mi"]] + h[["stroke"]] - h_ascvd) < 1e-12)
check("BMI clamped at 39.9", calculate_annual_hf_hazard(62, 1, 50, 145, 50, 7.5, 1, 0) ==
                             calculate_annual_hf_hazard(62, 1, 39.9, 145, 50, 7.5, 1, 0))
ages <- seq(60, 100, 5)
r <- sapply(ages, function(a) calculate_annual_ascvd_hazard(a, 1, 145, 220, 40, 1, 0, 45, 1, 1, 33, 7.5))
check("ASCVD hazard increases monotonically with age to 100", all(diff(r) > 0))

cat("--- Parameters and population ---\n")
check("parameter lists aligned", length(unique(lengths(l_params))) == 1)
p_es <- build_drug_specific_params("empagliflozin", "semaglutide")
nm <- unlist(p_es$parameter_name)
check("drug-specific: empagliflozin CV death HR", p_es$base_value[[match("hr_sglt2i_cv_death", nm)]] == 0.62)
check("drug-specific: semaglutide commercial and Medicare prices",
      p_es$base_value[[match("cost_glp1ra", nm)]] == 6830 && p_es$base_value[[match("cost_glp1ra_mcr", nm)]] == 3334)
check("drug-specific: non-drug parameters unchanged",
      identical(p_es$base_value[[match("cost_eskd_annual", nm)]], l_params$base_value[[match("cost_eskd_annual", nm)]]))
pv <- setNames(unlist(l_params$base_value), unlist(l_params$parameter_name))
check("class HRs match source meta-analyses (McGuire 2021; Sattar 2021)",
      pv[["hr_sglt2i_cv_death"]] == 0.85 && pv[["hr_glp1_hf"]] == 0.89 && pv[["hr_glp1_cv_death"]] == 0.87)
check("lifetime horizon by default", pv[["horizon_years"]] == 100)
check("payer-by-age prices", pv[["cost_sglt2i"]] == 4250 && pv[["cost_glp1ra"]] == 6830 && pv[["cost_glp1ra_mcr"]] == 3334 &&
        pv[["cost_sglt2i_mcr"]] == 2397 && pv[["age_medicare"]] == 65)
check("scenario switches off in the base case", pv[["addon_sglt2i"]] == 0 && pv[["bg_mort_mult"]] == 1 &&
        pv[["kidney_effect_restrict"]] == 0 && pv[["hf_hosp_frac"]] == 1 && pv[["soc_optimized"]] == 0 &&
        pv[["util_gain_glp1"]] == 0 && pv[["prevent_age_cap"]] == 999)

cat("--- Correlated PSA draws ---\n")
set.seed(1)
mu <- c(a = log(0.9), b = log(0.7)); se <- c(a = 0.05, b = 0.1)
draws <- t(replicate(20000, {
  hr <- c(a = exp(rnorm(1, mu[["a"]], se[["a"]])), b = exp(rnorm(1, mu[["b"]], se[["b"]])))
  log(correlate_log_hrs(hr, mu, se, rnorm(1), 0.5))
}))
check("correlated log HRs keep their means and SDs",
      all(abs(colMeans(draws) - mu) < 0.003) && all(abs(apply(draws, 2, sd) / se - 1) < 0.03))
check("correlated log HRs have the target correlation", abs(cor(draws)[1, 2] - 0.5) < 0.03)
check("add-on multipliers", identical(unname(addon_multipliers(1, 0.9, 0.7, 0.85)), c(0.9, 0.9, 0.7, 0.85)) &&
        all(addon_multipliers(0, 0.9, 0.7, 0.85) == 1))

cat("--- Patient-level helpers ---\n")
source("R/11_patient_outputs.R")
check("risk-equivalent: eGFR < 30", stage3_risk_equivalent(25, 10, 0.05))
check("risk-equivalent: G3b A2", stage3_risk_equivalent(40, 50, 0.05))
check("risk-equivalent: G3a A2 is not very high risk", !stage3_risk_equivalent(50, 50, 0.05))
check("risk-equivalent: total CVD >= 20%", stage3_risk_equivalent(80, 10, 0.20))
source("R/09_results.R")
# Treatment-years: SGLT2i 2.5 + 3, GLP-1 RA 2 + 2 (commercial + Medicare)
pr <- drug_prices(l_params)
arms <- data.table(arm = c("sglt2i", "glp1ra", "soc"), costs = c(220000, 230000, 200000),
                   qalys = c(8.25, 8.10, 8.00), lys = c(10.2, 10.1, 10),
                   drug_cost_com = c(pr[["cost_sglt2i"]] * 2.5, 6830 * 2, 0),
                   drug_cost_mcr = c(pr[["cost_sglt2i_mcr"]] * 3, 3334 * 2, 0))
arms[, drug_cost := drug_cost_com + drug_cost_mcr]
inc <- rbindlist(lapply(DEFAULT_COMPARISONS, function(cp) compare_tab(arms, cp[1], cp[2])))
thr <- threshold_prices(arms, inc, l_params, wtps = 120000)
g_soc <- thr[comparison == "GLP-1 RA + SoC vs SoC"]
check("threshold price: GLP-1 RA vs SoC, commercial price", abs(g_soc[1, threshold_price] -
        (6830 + (120000 * 0.10 - 30000) / 2)) < 1e-9)
check("threshold price: GLP-1 RA vs SoC, single price", abs(g_soc[2, threshold_price] -
        ((6830 * 2 + 3334 * 2) + (120000 * 0.10 - 30000)) / 4) < 1e-9)
check("threshold price: GLP-1 RA vs SGLT2i uses reversed INMB",
      abs(thr[comparison == "GLP-1 RA + SoC vs SGLT2i + SoC"][1, threshold_price] -
            (6830 - (120000 * 0.15 + 10000) / 2)) < 1e-9)
rp <- reprice(arms, drug_prices(l_params), c(cost_glp1ra = 6830 + 1000, cost_glp1ra_mcr = 3334 - 500))
check("reprice: GLP-1 RA cost changes by treatment-years x price change",
      abs(rp$arms[arm == "glp1ra", costs] - (230000 + 1000 * 2 - 500 * 2)) < 1e-9 &&
        rp$arms[arm == "sglt2i", costs] == 220000)
rp0 <- reprice(arms, drug_prices(l_params), c(cost_sglt2i = pr[["cost_sglt2i"]]))
check("reprice: unchanged prices reproduce the increments", isTRUE(all.equal(rp0$incremental$inc_cost, inc$inc_cost)))

pop <- generate_ckm_population(5000, 3, seed = 42)
check("non-diabetic HbA1c < 6.5%", all(pop[diabetes == 0, hba1c] < 6.5))
check("eGFR within [20, 100], no point mass at bound", min(pop$egfr) >= 20 && mean(pop$egfr == 20) == 0)

cat("\nAll helper checks passed.\n")
