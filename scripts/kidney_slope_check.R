#!/usr/bin/env Rscript
# =============================================================================
# CKM-HEOR: Model-implied eGFR slope differences in trial-like patients
# =============================================================================
# Compares the absolute eGFR slope difference implied by the class slope ratios
# with the differences reported in DAPA-CKD (dapagliflozin vs placebo, total
# slope 0.95 mL/min/1.73 m2 per year, placebo 3.83; Heerspink 2021) and FLOW
# (semaglutide vs placebo, 1.16, placebo 3.36; Perkovic 2024), in two sets of
# patients: simulated cohort members meeting each trial's entry criteria, and
# populations with each trial's baseline eGFR and UACR (as in
# scripts/calibrate_kidney.R). Also gives the trial-slope-matched ratios
# 1 - trial difference / model untreated decline in the trial populations.
# No simulation. Usage: Rscript scripts/kidney_slope_check.R [--write]
#   --write: outputs/tables/kidney_slope_check_stage3.csv
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
m3b <- pv("egfr_mult_3b"); m4 <- pv("egfr_mult_4")
ratio <- c(sglt2i = pv("sglt2i_egfr_slope_ratio"), glp1ra = pv("glp1_egfr_slope_ratio"))

# Mean untreated decline at baseline: the heterogeneity multiplier has mean 1
mean_decline <- function(d) {
  band_m <- ifelse(d$egfr < 30, m4, ifelse(d$egfr < 45, m3b, 1))
  ref * mean((pmax(d$uacr, 3) / 30)^beta * band_m)
}
trial_pop <- function(n, egfr_mean, egfr_sd, uacr_med, uacr_sdlog) {
  set.seed(SEED)
  e <- rnorm(4 * n, egfr_mean, egfr_sd); e <- e[e >= 25 & e <= 75][seq_len(n)]
  data.table(egfr = e, uacr = exp(rnorm(n, log(uacr_med), uacr_sdlog)))
}

sets <- list(
  "DAPA-CKD entry criteria (simulated cohort)" = pop[egfr >= 25 & egfr <= 75 & uacr >= 200 & uacr <= 5000],
  "FLOW entry criteria (simulated cohort)" = pop[diabetes == 1 & ((egfr >= 50 & egfr <= 75 & uacr > 300 & uacr < 5000) |
                                                                (egfr >= 25 & egfr < 50 & uacr > 100 & uacr < 5000))],
  "DAPA-CKD baseline eGFR and UACR" = trial_pop(20000, 43.1, 12.4, 949, log(1885 / 477) / (2 * qnorm(0.75))),
  "FLOW baseline eGFR and UACR" = trial_pop(20000, 47.0, 15.2, 568, log(3225 / 51) / (2 * qnorm(0.95)))
)
trial <- c(sglt2i = 0.95, glp1ra = 1.16)
placebo <- c(sglt2i = 3.83, glp1ra = 3.36)
out <- rbindlist(lapply(names(sets), function(nm) {
  d <- sets[[nm]]; cls <- if (grepl("DAPA", nm)) "sglt2i" else "glp1ra"
  dec <- mean_decline(d)
  data.table(population = nm, class = cls, n = nrow(d), mean_uacr = mean(d$uacr), median_uacr = median(d$uacr),
             mean_egfr = mean(d$egfr), untreated_decline = dec, trial_placebo_slope = placebo[[cls]],
             slope_ratio = ratio[[cls]], implied_difference = (1 - ratio[[cls]]) * dec,
             trial_difference = trial[[cls]], pct_of_trial = 100 * (1 - ratio[[cls]]) * dec / trial[[cls]],
             matched_ratio = 1 - trial[[cls]] / dec)
}))
print(out[, lapply(.SD, function(x) if (is.numeric(x)) round(x, 3) else x)])

sdlog <- pv("egfr_slope_sdlog")
set.seed(SEED)
band_m <- ifelse(pop$egfr < 30, m4, ifelse(pop$egfr < 45, m3b, 1))
slopes <- ref * band_m * egfr_patient_multiplier(pop$uacr, beta, sdlog, rnorm(nrow(pop)))
cohort <- data.table(population = "Whole cohort at baseline", n = nrow(pop), mean_uacr = mean(pop$uacr),
                     median_uacr = median(pop$uacr), mean_egfr = mean(pop$egfr), untreated_decline = mean(slopes),
                     median_decline = median(slopes), p25_decline = quantile(slopes, 0.25),
                     p75_decline = quantile(slopes, 0.75),
                     pct_kidney_effect_eligible = 100 * mean(pop$uacr >= 30 | pop$egfr < 60))
print(cohort)
if ("--write" %in% commandArgs(trailingOnly = TRUE))
  fwrite(rbind(out, cohort, fill = TRUE), "outputs/tables/kidney_slope_check_stage3.csv")
