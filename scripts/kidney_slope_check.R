#!/usr/bin/env Rscript
# =============================================================================
# CKM-HEOR: Model-implied eGFR slope differences in trial-like patients
# =============================================================================
# Compares the absolute eGFR slope difference implied by the class slope ratios
# with the differences reported in DAPA-CKD (dapagliflozin vs placebo, total
# slope 0.95 mL/min/1.73 m2 per year; Heerspink 2021) and FLOW (semaglutide vs
# placebo, 1.16; Perkovic 2024). Generates the base-case cohort only (no
# simulation, nothing written). Usage: Rscript scripts/kidney_slope_check.R
# =============================================================================

suppressMessages({
  source("R/00_setup.R")
  source("R/01_parameters.R")
  source("R/02_population.R")
  source("R/04_treatment.R")
})

pop <- generate_ckm_population(20000, 3, seed = SEED)
pv  <- function(nm) l_params$base_value[[match(nm, unlist(l_params$parameter_name))]]
ref <- pv("egfr_decline_ref"); beta <- pv("egfr_uacr_beta")
ratio <- c(sglt2i = pv("sglt2i_egfr_slope_ratio"), glp1ra = pv("glp1_egfr_slope_ratio"))

# Mean untreated decline: the patient-level heterogeneity multiplier has mean 1
mean_decline <- function(d) ref * mean((pmax(d$uacr, 3) / 30)^beta)

dapa <- pop[egfr >= 25 & egfr <= 75 & uacr >= 200 & uacr <= 5000]
flow <- pop[diabetes == 1 & ((egfr >= 50 & egfr <= 75 & uacr > 300 & uacr < 5000) |
                             (egfr >= 25 & egfr < 50 & uacr > 100 & uacr < 5000))]

sdlog <- pv("egfr_slope_sdlog")
set.seed(SEED)
slopes <- ref * egfr_patient_multiplier(pop$uacr, beta, sdlog, rnorm(nrow(pop)))
cat(sprintf("Whole cohort: untreated decline mean %.2f, median %.2f, IQR %.2f-%.2f mL/min/1.73 m2 per year\n",
            mean_decline(pop), median(slopes), quantile(slopes, 0.25), quantile(slopes, 0.75)))
cat(sprintf("DAPA-CKD entry criteria: n = %d, untreated decline %.2f, SGLT2i difference %.2f (trial 0.95)\n",
            nrow(dapa), mean_decline(dapa), (1 - ratio[["sglt2i"]]) * mean_decline(dapa)))
cat(sprintf("FLOW entry criteria: n = %d, untreated decline %.2f, GLP-1 RA difference %.2f (trial 1.16)\n",
            nrow(flow), mean_decline(flow), (1 - ratio[["glp1ra"]]) * mean_decline(flow)))
cat(sprintf("Kidney effect eligible (UACR >= 30 mg/g or eGFR < 60): %.1f%%\n",
            100 * mean(pop$uacr >= 30 | pop$egfr < 60)))
