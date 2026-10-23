#!/usr/bin/env Rscript
# =============================================================================
# CKM-HEOR: Pilot Test — Full Integration
# =============================================================================

cat("=== CKM-HEOR Pilot Test (Full Integration) ===\n")
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

# ---- Test 1: Deterministic base case, Stage 3 ----
cat("\n========================================\n")
cat("TEST: CKM Stage 3 — 500 patients, deterministic\n")
cat("========================================\n")

results_s3 <- run_ckm_model(
  ckm_stage  = 3,
  n_patients = 500,
  n_sim      = 1,
  psa_bool   = FALSE,
  seed       = 42
)

cat("\n--- Stage 3 Results ---\n")
summ_s3 <- WARDEN::summary_results_det(results_s3, wtp = 120000)
print(summ_s3)

# ---- Test 2: Stage 2 ----
cat("\n========================================\n")
cat("TEST: CKM Stage 2 — 500 patients, deterministic\n")
cat("========================================\n")

results_s2 <- run_ckm_model(
  ckm_stage  = 2,
  n_patients = 500,
  n_sim      = 1,
  psa_bool   = FALSE,
  seed       = 42
)

cat("\n--- Stage 2 Results ---\n")
summ_s2 <- WARDEN::summary_results_det(results_s2, wtp = 120000)
print(summ_s2)

# ---- Test 3: Stage 4a ----
cat("\n========================================\n")
cat("TEST: CKM Stage 4a — 500 patients, deterministic\n")
cat("========================================\n")

results_s4 <- run_ckm_model(
  ckm_stage  = 4,
  n_patients = 500,
  n_sim      = 1,
  psa_bool   = FALSE,
  seed       = 42
)

cat("\n--- Stage 4a Results ---\n")
summ_s4 <- WARDEN::summary_results_det(results_s4, wtp = 120000)
print(summ_s4)

# ---- Test 4: PSA (10 iterations, Stage 3) ----
cat("\n========================================\n")
cat("TEST: PSA — 10 iterations, Stage 3, 200 patients\n")
cat("========================================\n")

results_psa <- run_ckm_model(
  ckm_stage  = 3,
  n_patients = 200,
  n_sim      = 10,
  psa_bool   = TRUE,
  seed       = 42
)

cat("\n--- PSA Results ---\n")
summ_psa <- WARDEN::summary_results_sim(results_psa, wtp = 120000)
print(summ_psa)

# ---- Save all results ----
dir.create("outputs", showWarnings = FALSE, recursive = TRUE)
save(results_s3, results_s2, results_s4, results_psa,
     summ_s3, summ_s2, summ_s4, summ_psa,
     file = "outputs/pilot_results.RData")

cat("\n=== ALL PILOT TESTS COMPLETE ===\n")
cat("Time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
