#!/usr/bin/env Rscript
# =============================================================================
# Quick validation: minimal end-to-end test of the model (~15 seconds)
# Run after every change: Rscript analysis/validate_minimal.R
# =============================================================================

cat("=== Minimal Validation Run ===\n")
cat("Time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# ---- Source modules ----
source("R/00_setup.R")
source("R/01_parameters.R")
source("R/02_population.R")
source("R/03_risk_equations.R")
source("R/04_treatment.R")
source("R/07_costs_utilities.R")
source("R/05_events.R")
source("R/06_reactions.R")
source("R/08_run_model.R")
source("R/09_results.R")
source("R/10_validation.R")

checks <- c()
record <- function(name, ok) {
  cat(sprintf("  %-55s %s\n", name, ifelse(ok, "PASS", "FAIL")))
  checks[name] <<- ok
}

# ---- Test 1: Deterministic, Stage 3, 100 patients ----
cat("\n========================================\n")
cat("TEST 1: Deterministic, Stage 3, 100 patients\n")
cat("========================================\n")
t1 <- system.time({
  results_det <- suppressMessages(run_ckm_model(ckm_stage = 3, n_patients = 100, seed = 42))
})
s <- summarise_deterministic(results_det)
print(s$arms[, .(label, costs = round(costs), qalys = round(qalys, 3), lys = round(lys, 3),
                 n_mi, n_stroke, n_hf, prop_eskd, prop_on_tx)])
print(s$incremental[, .(comparison, inc_cost = round(inc_cost), inc_qaly = round(inc_qaly, 3), icer_label)])
cat(sprintf("Deterministic run time: %.1f seconds\n", t1[3]))

# ---- Test 2: PSA, 50 patients, 2 sims ----
cat("\n========================================\n")
cat("TEST 2: PSA, Stage 3, 50 patients, 2 sims\n")
cat("========================================\n")
t2 <- system.time({
  results_psa <- suppressMessages(run_ckm_model(ckm_stage = 3, n_patients = 50, n_sim = 2,
                                                psa_bool = TRUE, seed = 42))
})
cat(sprintf("PSA run time: %.1f seconds\n", t2[3]))

# ---- Test 3: Drug-specific parameters run ----
results_es <- suppressMessages(run_ckm_model(ckm_stage = 3, n_patients = 30, seed = 42,
                                             params = build_drug_specific_params("empagliflozin", "semaglutide")))

# ---- Key validation checks ----
cat("\n========================================\n")
cat("VALIDATION CHECKS\n")
cat("========================================\n")

det <- results_det[[1]][[1]]
lys <- det$total_lys
record("LYs in plausible range (5-30)", all(lys > 5 & lys < 30))
record("LY ordering (sglt2i >= glp1ra >= soc)", lys["sglt2i"] >= lys["glp1ra"] & lys["glp1ra"] >= lys["soc"])
record("Ageing (end age > baseline)", all(det$pt_age > det$pt_age_baseline))
record("CKD protection (end eGFR sglt2i >= soc)", det$egfr_cur["sglt2i"] >= det$egfr_cur["soc"])
record("Lifetime ESKD in SoC plausible (1-25%)", det$fl_eskd["soc"] > 0.01 & det$fl_eskd["soc"] < 0.25)
record("SoC never on treatment", det$fl_on_treatment["soc"] == 0)
record("Treated arms discontinue over lifetime", all(det$fl_on_treatment[c("sglt2i", "glp1ra")] < 1))
record("Recurrence caps respected (mean n_mi <= 3)", all(det$n_mi <= 3))
record("PSA parameter variation (sim1 != sim2)",
       !identical(results_psa[[1]][[1]]$total_costs, results_psa[[1]][[2]]$total_costs))
record("Drug-specific scenario runs", all(is.finite(results_es[[1]][[1]]$total_costs)))
record("PREVENT equations match preventr", isTRUE(as.logical(validate_prevent_equations(n_test = 10))))
record("Kidney progression matches KFRE", isTRUE(as.logical(validate_kidney_calibration())))

cat(sprintf("\n%d/%d checks passed\n", sum(checks), length(checks)))
cat("=== ALL VALIDATION COMPLETE ===\n")
cat("Time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
if (!all(checks)) quit(status = 1)
