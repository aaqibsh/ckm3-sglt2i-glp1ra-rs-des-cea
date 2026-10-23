#!/usr/bin/env Rscript
# =============================================================================
# CKM-HEOR: Deterministic Base Case
# =============================================================================
# Usage:  Rscript analysis/run_base_case.R [stage]       (default: stages 2, 3, 4)
#         CKM_MODE=production Rscript analysis/run_base_case.R 3
# Sizes:  pilot 500 patients | production 20,000 patients per stage
# Arms:   SGLT2i + SoC vs GLP-1 RA + SoC vs SoC alone
# Outputs per stage (outputs/tables/): base_case_stage<k>_arms.csv,
#   base_case_stage<k>_incremental.csv, threshold_prices_stage<k>.csv,
#   patient_level_stage<k>.csv.gz (one row per patient and arm), and the
#   tables built from it: subgroups, events, validation, PREVENT risk
#   distribution (R/11_patient_outputs.R); outputs/base_case_stage<k>.RData
# =============================================================================

cat("=== CKM-HEOR Base Case Analysis ===\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

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
source("R/11_patient_outputs.R")

stages <- stages_from_args()
n_pat  <- RUN_SIZES$base_patients
dir.create("outputs/tables", recursive = TRUE, showWarnings = FALSE)

for (stage in stages) {
  cat(sprintf("\n--- CKM Stage %d: %d patients ---\n", stage, n_pat))
  t_run <- system.time(
    res <- suppressMessages(run_ckm_model(ckm_stage = stage, n_patients = n_pat, seed = SEED))
  )
  s <- summarise_deterministic(res, wtp = WTP_THRESHOLD)
  s$arms[, stage := stage]
  s$incremental[, stage := stage]
  print(s$arms[, .(label, costs = round(costs), qalys = round(qalys, 3), lys = round(lys, 3),
                   n_mi, n_stroke, n_hf, prop_eskd)])
  print(s$incremental[, .(comparison, inc_cost = round(inc_cost), inc_qaly = round(inc_qaly, 3),
                          icer_label, inmb = round(inmb))])
  cat(sprintf("Run time: %.1f minutes\n", t_run[3] / 60))

  fwrite(s$arms, sprintf("outputs/tables/base_case_stage%d_arms.csv", stage))
  fwrite(s$incremental, sprintf("outputs/tables/base_case_stage%d_incremental.csv", stage))
  thr <- threshold_prices(s$arms, s$incremental, l_params)[, stage := stage]
  print(thr[wtp == WTP_THRESHOLD, .(comparison, current_price, threshold_price = round(threshold_price))])
  fwrite(thr, sprintf("outputs/tables/threshold_prices_stage%d.csv", stage))

  # ---- Patient-level outputs (subgroups, event burden, validation) ----
  pop <- generate_ckm_population(n_pat, ckm_stage = stage, seed = SEED)
  ps <- patient_summary(res, pop)
  stopifnot(isTRUE(all.equal(ps[, mean(costs), keyby = arm]$V1,
                             unname(res[[1]][[1]]$total_costs[sort(names(res[[1]][[1]]$total_costs))]))))
  fwrite(ps, sprintf("outputs/tables/patient_level_stage%d.csv.gz", stage))
  fwrite(subgroup_table(ps, wtp = WTP_THRESHOLD)[, stage := stage],
         sprintf("outputs/tables/subgroups_stage%d.csv", stage))
  fwrite(event_table(ps)[, stage := stage], sprintf("outputs/tables/events_stage%d.csv", stage))
  fwrite(validation_table(ps)[, stage := stage], sprintf("outputs/tables/validation_stage%d.csv", stage))
  fwrite(risk_distribution(ps)[, stage := stage], sprintf("outputs/tables/risk_distribution_stage%d.csv", stage))
  print(validation_table(ps))
  save(s, thr, file = sprintf("outputs/base_case_stage%d.RData", stage))

  if (stage == 3) {
    cat("\n--- Validations (Stage 3) ---\n")
    ok <- run_all_validations(res, generate_ckm_population(n_pat, ckm_stage = 3, seed = SEED))
    if (!isTRUE(ok)) warning("One or more validations failed; see log above.")
  }
}

cat("\n=== Base Case Analysis Complete ===\n")
cat("End time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
