#!/usr/bin/env Rscript
# =============================================================================
# Full project status run: all 3 stages + PSA
# Minimal N for quick verification
# =============================================================================

cat("=== CKM-HEOR Full Status Run ===\n")
cat("Time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

source("R/00_setup.R")
source("R/01_parameters.R")
source("R/02_population.R")
source("R/03_risk_equations.R")
source("R/04_treatment.R")
source("R/07_costs_utilities.R")
source("R/05_events.R")
source("R/06_reactions.R")
source("R/08_run_model.R")

# ---- Stage 3 (Primary analysis) ----
cat("\n", strrep("=", 50), "\n")
cat("STAGE 3 — Deterministic (100 pts)\n")
cat(strrep("=", 50), "\n")
res_s3 <- run_ckm_model(ckm_stage=3, n_patients=100, n_sim=1, psa_bool=FALSE, seed=42)
summ_s3 <- WARDEN::summary_results_det(res_s3, wtp=120000)
print(summ_s3[c("costs","lys","qalys","ICER","ICUR","INMB"),])

# ---- Stage 2 ----
cat("\n", strrep("=", 50), "\n")
cat("STAGE 2 — Deterministic (100 pts)\n")
cat(strrep("=", 50), "\n")
res_s2 <- run_ckm_model(ckm_stage=2, n_patients=100, n_sim=1, psa_bool=FALSE, seed=42)
summ_s2 <- WARDEN::summary_results_det(res_s2, wtp=120000)
print(summ_s2[c("costs","lys","qalys","ICER","ICUR","INMB"),])

# ---- Stage 4a ----
cat("\n", strrep("=", 50), "\n")
cat("STAGE 4a — Deterministic (100 pts)\n")
cat(strrep("=", 50), "\n")
res_s4 <- run_ckm_model(ckm_stage=4, n_patients=100, n_sim=1, psa_bool=FALSE, seed=42)
summ_s4 <- WARDEN::summary_results_det(res_s4, wtp=120000)
print(summ_s4[c("costs","lys","qalys","ICER","ICUR","INMB"),])

# ---- PSA Stage 3 (3 sims) ----
cat("\n", strrep("=", 50), "\n")
cat("STAGE 3 — PSA (50 pts, 3 sims)\n")
cat(strrep("=", 50), "\n")
res_psa <- run_ckm_model(ckm_stage=3, n_patients=50, n_sim=3, psa_bool=TRUE, seed=42)
summ_psa <- WARDEN::summary_results_sim(res_psa, wtp=120000)
print(summ_psa[c("costs","lys","qalys","ICER","ICUR","INMB"),])

# ---- Clinical Outcomes Summary ----
cat("\n", strrep("=", 50), "\n")
cat("CLINICAL OUTCOMES SUMMARY\n")
cat(strrep("=", 50), "\n\n")

for (stage_name in c("Stage 2", "Stage 3", "Stage 4a")) {
  r <- switch(stage_name,
    "Stage 2" = res_s2[[1]][[1]],
    "Stage 3" = res_s3[[1]][[1]],
    "Stage 4a" = res_s4[[1]][[1]]
  )
  cat(sprintf("--- %s ---\n", stage_name))
  cat(sprintf("  LYs:      SGLT2i=%.1f  GLP1RA=%.1f  SoC=%.1f\n",
    r$total_lys["sglt2i"], r$total_lys["glp1ra"], r$total_lys["soc"]))
  cat(sprintf("  QALYs:    SGLT2i=%.2f  GLP1RA=%.2f  SoC=%.2f\n",
    r$total_qalys["sglt2i"], r$total_qalys["glp1ra"], r$total_qalys["soc"]))
  cat(sprintf("  Costs:    SGLT2i=$%s  GLP1RA=$%s  SoC=$%s\n",
    format(round(r$total_costs["sglt2i"]), big.mark=","),
    format(round(r$total_costs["glp1ra"]), big.mark=","),
    format(round(r$total_costs["soc"]), big.mark=",")))
  cat(sprintf("  n_mi:     SGLT2i=%.2f  GLP1RA=%.2f  SoC=%.2f\n",
    r$n_mi["sglt2i"], r$n_mi["glp1ra"], r$n_mi["soc"]))
  cat(sprintf("  n_hf:     SGLT2i=%.2f  GLP1RA=%.2f  SoC=%.2f\n",
    r$n_hf["sglt2i"], r$n_hf["glp1ra"], r$n_hf["soc"]))
  cat(sprintf("  n_stroke: SGLT2i=%.2f  GLP1RA=%.2f  SoC=%.2f\n",
    r$n_stroke["sglt2i"], r$n_stroke["glp1ra"], r$n_stroke["soc"]))
  cat(sprintf("  ESKD:     SGLT2i=%.0f%%  GLP1RA=%.0f%%  SoC=%.0f%%\n",
    r$fl_eskd["sglt2i"]*100, r$fl_eskd["glp1ra"]*100, r$fl_eskd["soc"]*100))
  cat(sprintf("  CKD stg:  SGLT2i=%.1f  GLP1RA=%.1f  SoC=%.1f\n",
    r$ckd_stage["sglt2i"], r$ckd_stage["glp1ra"], r$ckd_stage["soc"]))
  cat(sprintf("  Age end:  SGLT2i=%.1f  GLP1RA=%.1f  SoC=%.1f  (baseline=%.1f)\n\n",
    r$pt_age["sglt2i"], r$pt_age["glp1ra"], r$pt_age["soc"],
    r$pt_age_baseline["sglt2i"]))
}

cat("=== COMPLETE ===\n")
cat("Time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
