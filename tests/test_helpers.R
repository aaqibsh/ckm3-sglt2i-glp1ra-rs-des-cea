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
check("dialysis cost replaces CKD 4 cost", ckd_state_cost(5, 1, 1, 2743, 6745, 8746, 107240) == 107240)
check("kidney failure before dialysis costs the CKD 4 amount", ckd_state_cost(5, 1, 0, 2743, 6745, 8746, 107240) == 8746)
check("stage 3a and 3b costs", ckd_state_cost(3, 0, 0, 2743, 6745, 8746, 107240) == 2743 &&
        ckd_state_cost(3, 1, 0, 2743, 6745, 8746, 107240) == 6745)
check("dialysis decrement adds to CKD 4", ckd_state_disutility(5, 1, 0.02, 0.05, 0.20) == 0.25 &&
        ckd_state_disutility(5, 0, 0.02, 0.05, 0.20) == 0.05)
check("band multipliers", kidney_band_multiplier(3, 0, 1.2, 1.5) == 1 && kidney_band_multiplier(3, 1, 1.2, 1.5) == 1.2 &&
        kidney_band_multiplier(4, 1, 1.2, 1.5) == 1.5)
check("years to eGFR 15 piecewise", abs(years_to_egfr15(60, 1, 1, 2) - (15 + 15 + 7.5)) < 1e-12 &&
        abs(years_to_egfr15(25, 2, 1, 2) - 2.5) < 1e-12)
check("time to eGFR target", time_to_egfr(50, 2, 45) == 2.5 && time_to_egfr(40, 2, 45) == 0 && is.infinite(time_to_egfr(50, 0, 45)))
check("dialysis decision by age (Wong 2016)", abs(p_forgo_dialysis(30) - 0.038) < 1e-12 &&
        abs(p_forgo_dialysis(90) - 0.467) < 1e-12 && abs(p_forgo_dialysis(65) - (0.038 + 0.429 / 2)) < 1e-12)

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
        pv[["util_gain_glp1"]] == 0 && pv[["prevent_age_cap"]] == 999 && pv[["addon_glp1"]] == 0 &&
        pv[["stop_glp1_at_kf"]] == 0 && pv[["glp1_flow_dm"]] == 0 && pv[["dialysis_egfr"]] == 15 &&
        pv[["dialysis_forgo"]] == 0)
check("PREVENT full model in the base case", pv[["prevent_full"]] == 1)

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
# Patient-level repricing: one patient per arm and diabetes status. Treatment-years
# 2 commercial + 3 Medicare for every treated patient.
pr <- drug_prices(l_params)
check("GLP-1 RA commercial price with diabetes is Ozempic-adjusted", abs(pr[["cost_glp1ra_dm"]] - 6830 * 1028 / 1349) < 1e-9)
ps <- CJ(arm = c("sglt2i", "glp1ra", "soc"), diabetes = c(0, 1))
ps[, `:=`(pat_id = diabetes + 1, qalys = c(8.25, 8.25, 8.10, 8.10, 8.00, 8.00)[match(paste(arm, diabetes), paste(rep(c("sglt2i", "glp1ra", "soc"), each = 2), c(0, 1)))],
          lys = 10)]
ps[, drug_cost_com := 2 * pt_price(pr, arm, "com", diabetes)]
ps[, drug_cost_mcr := 3 * pt_price(pr, arm, "mcr", diabetes)]
ps[, costs := 200000 + drug_cost_com + drug_cost_mcr]
r0 <- reprice(ps, pr, c())
check("reprice: treatment-years recovered", isTRUE(all.equal(r0$arms[arm != "soc", d_com], c(2, 2))) &&
        isTRUE(all.equal(r0$arms[arm != "soc", d_mcr], c(3, 3))))
r1 <- reprice(ps, pr, set_prices(pr, "glp1ra", com = 6830))
check("reprice: one GLP-1 RA price adds the diabetes discount back",
      abs(r1$arms[arm == "glp1ra", costs] - r0$arms[arm == "glp1ra", costs] - 0.5 * 2 * (6830 - pr[["cost_glp1ra_dm"]])) < 1e-6)
r2 <- reprice(ps, pr, set_prices(pr, "sglt2i", com = 67, mcr = 67, dm = "dm"))
check("reprice: generic dapagliflozin only with diabetes",
      abs(r2$arms[arm == "sglt2i", costs] - r0$arms[arm == "sglt2i", costs] - 0.5 * (2 * (67 - 4250) + 3 * (67 - 2397))) < 1e-6)
thr <- threshold_prices(ps, l_params, wtps = 120000)
g_soc <- thr[comparison == "GLP-1 RA + SoC vs SoC"]
inmb0 <- 120000 * 0.10 - (r0$arms[arm == "glp1ra", costs] - r0$arms[arm == "soc", costs])
check("threshold price: GLP-1 RA vs SoC, commercial price", abs(g_soc[1, threshold_price] -
        (r0$arms[arm == "glp1ra", drug_cost_com] + inmb0) / 2) < 1e-6)
check("threshold price: GLP-1 RA vs SoC, single price", abs(g_soc[2, threshold_price] -
        (r0$arms[arm == "glp1ra", drug_cost] + inmb0) / 5) < 1e-6)

pop <- generate_ckm_population(5000, 3, seed = 42)
check("non-diabetic HbA1c < 6.5%", all(pop[diabetes == 0, hba1c] < 6.5))
check("eGFR within [20, 100], no point mass at bound", min(pop$egfr) >= 20 && mean(pop$egfr == 20) == 0)

cat("\nAll helper checks passed.\n")
