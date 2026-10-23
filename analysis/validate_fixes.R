#!/usr/bin/env Rscript
# =============================================================================
# Quick validation: test all 4 changes at low N
# =============================================================================

cat("=== Validation Run (4 fixes) ===\n")
cat("Time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# ---- Source modules ----
source("R/00_setup.R")
source("R/01_parameters.R")   # Revised: parallel-list format
source("R/02_population.R")
source("R/03_risk_equations.R")
source("R/04_treatment.R")
source("R/07_costs_utilities.R")
source("R/05_events.R")       # Revised: +age_update event
source("R/06_reactions.R")    # Revised: recurrent + age-updating
source("R/08_run_model.R")    # Revised: input_block PSA wiring

# ---- Test 1: Deterministic, Stage 3, 100 patients ----
cat("\n========================================\n")
cat("TEST 1: Deterministic, Stage 3, 100 patients\n")
cat("========================================\n")

results_det <- run_ckm_model(
  ckm_stage  = 3,
  n_patients = 100,
  n_sim      = 1,
  psa_bool   = FALSE,
  seed       = 42
)

cat("\n--- Deterministic Results ---\n")
summ_det <- WARDEN::summary_results_det(results_det, wtp = 120000)
print(summ_det)

# ---- Test 2: PSA with parameter uncertainty, 100 patients, 5 sims ----
cat("\n========================================\n")
cat("TEST 2: PSA, Stage 3, 100 patients, 5 sims\n")
cat("========================================\n")

results_psa <- run_ckm_model(
  ckm_stage  = 3,
  n_patients = 100,
  n_sim      = 5,
  psa_bool   = TRUE,
  seed       = 42
)

cat("\n--- PSA Results ---\n")
summ_psa <- WARDEN::summary_results_sim(results_psa, wtp = 120000)
print(summ_psa)

cat("\n=== VALIDATION COMPLETE ===\n")
cat("Time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
