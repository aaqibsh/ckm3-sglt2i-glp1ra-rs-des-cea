# =============================================================================
# File: 10_validation.R
# Purpose: Validation checks for CKM-HEOR model
# Author: CKM-HEOR Team
# Date: 2026-09-28 (revised — unrounded PREVENT cross-validation over all four
#       equations; KFRE kidney calibration check)
# =============================================================================

library(data.table)

#' Validate initial population characteristics
#'
#' @param df_pop Simulated population data.table
#' @return Logical indicating pass/fail
#' @export
validate_population <- function(df_pop) {
  if (nrow(df_pop) == 0) return(FALSE)
  
  pass <- TRUE
  if (any(df_pop$age < 18 | df_pop$age > 100)) pass <- FALSE
  if (any(!df_pop$sex %in% c(0, 1))) pass <- FALSE
  
  cat("Population validation:", ifelse(pass, "PASS", "FAIL"), "\n")
  return(pass)
}

#' Validate event rates
#'
#' @param results Output from WARDEN run_sim()
#' @return Logical indicating pass/fail
#' @export
validate_event_rates <- function(results) {
  res_base <- results[[1]][[1]]
  pass <- TRUE
  
  n_mi <- res_base$n_mi
  n_hf <- res_base$n_hf
  n_stroke <- res_base$n_stroke
  total_lys <- res_base$total_lys
  
  arms <- names(total_lys)
  
  cat("--- Event Rates Validation ---\n")
  for (arm in arms) {
    lys <- total_lys[arm]
    if (is.na(lys) || lys <= 0) next
    
    mi_rate <- if (!is.null(n_mi)) n_mi[arm] / lys else NA
    hf_rate <- if (!is.null(n_hf)) n_hf[arm] / lys else NA
    stroke_rate <- if (!is.null(n_stroke)) n_stroke[arm] / lys else NA
    
    cat(sprintf("Arm: %s\n", arm))
    cat(sprintf("  MI annual rate: %.4f\n", mi_rate))
    cat(sprintf("  HF annual rate: %.4f\n", hf_rate))
    cat(sprintf("  Stroke annual rate: %.4f\n", stroke_rate))
    
    # Plausible checks (arbitrary rough bounds)
    if (!is.na(mi_rate) && (mi_rate > 0.2)) pass <- FALSE
    if (!is.na(hf_rate) && (hf_rate > 0.2)) pass <- FALSE
    if (!is.na(stroke_rate) && (stroke_rate > 0.2)) pass <- FALSE
  }
  
  cat("Event rates validation:", ifelse(pass, "PASS", "FAIL"), "\n")
  return(pass)
}

#' Validate survival (LYs)
#'
#' @param results Output from WARDEN run_sim()
#' @return Logical indicating pass/fail
#' @export
validate_survival <- function(results) {
  total_lys <- results[[1]][[1]]$total_lys
  
  pass <- TRUE
  cat("--- Survival Validation ---\n")
  for (arm in names(total_lys)) {
    mean_lys <- total_lys[arm]
    cat(sprintf("Arm: %s, Mean LYs: %.2f\n", arm, mean_lys))
    if (mean_lys < 2 || mean_lys > 40) {
      pass <- FALSE
      cat("  -> FAILED bounds check (2 < mean_lys < 40)\n")
    }
  }
  
  cat("Survival validation:", ifelse(pass, "PASS", "FAIL"), "\n")
  return(pass)
}

#' Validate aging logic
#'
#' @param results Output from WARDEN run_sim()
#' @return Logical indicating pass/fail
#' @export
validate_aging <- function(results) {
  res_base <- results[[1]][[1]]
  
  pt_age <- res_base$pt_age
  pt_age_baseline <- res_base$pt_age_baseline
  
  pass <- TRUE
  cat("--- Aging Validation ---\n")
  
  if (is.null(pt_age) || is.null(pt_age_baseline)) {
    cat("Aging validation: SKIP (age variables not found in results)\n")
    return(TRUE)
  }
  
  arms <- names(pt_age)
  for (arm in arms) {
    end_age <- pt_age[arm]
    base_age <- pt_age_baseline[arm]
    
    cat(sprintf("Arm: %s, Mean Baseline Age: %.2f, Mean End Age: %.2f\n", arm, base_age, end_age))
    
    if (end_age <= base_age) {
      pass <- FALSE
      cat("  -> FAILED: End age is not greater than baseline age\n")
    }
  }
  
  cat("Aging validation:", ifelse(pass, "PASS", "FAIL"), "\n")
  return(pass)
}

#' Validate PREVENT risk equations against the preventr package
#'
#' @description Compares our hardcoded implementation with preventr's internal
#'   scoring (preventr:::prep_terms + preventr:::run_models with dp = 12, i.e.
#'   unrounded — the public estimate_risk() rounds to 3 decimals, which alone
#'   produces >1% relative differences for small risks). Covers the base and
#'   HbA1c models, both sexes, and the ASCVD, HF, CHD and stroke equations, for
#'   random patients drawn within PREVENT's validated input ranges.
#'
#' @param n_test Number of test patients
#' @param seed Random seed
#' @param tol Maximum allowed relative error in 10-year risk
#' @return Logical indicating pass/fail (invisibly, with the error table attached)
#' @export
validate_prevent_equations <- function(n_test = 20, seed = 123, tol = 0.01) {
  if (!requireNamespace("preventr", quietly = TRUE)) {
    warning("preventr package is required for this validation.")
    return(TRUE)
  }

  set.seed(seed)
  cat("--- PREVENT Equations Validation (vs preventr, unrounded) ---\n")
  outcomes <- c(ascvd = "ascvd", hf = "heart_failure", chd = "chd", stroke = "stroke")
  errs <- list()

  for (k in seq_len(n_test)) {
    d <- data.frame(
      age = runif(1, 30, 79), sex = sample(c("female", "male"), 1),
      sbp = runif(1, 90, 180), bp_tx = sample(c(TRUE, FALSE), 1),
      total_c = runif(1, 130, 320), hdl_c = runif(1, 20, 100),
      statin = sample(c(TRUE, FALSE), 1), dm = sample(c(TRUE, FALSE), 1),
      smoking = sample(c(TRUE, FALSE), 1), egfr = runif(1, 15, 140),
      bmi = runif(1, 18.5, 39.9), hba1c = runif(1, 4.5, 15)
    )
    for (mdl in c("base", "hba1c")) {
      ref <- preventr:::run_models(mdl, d$sex, "10yr", preventr:::prep_terms(d, mdl), dp = 12)
      for (o in names(outcomes)) {
        ours_h <- calculate_prevent_hazard(
          d$age, as.integer(d$sex == "male"), d$sbp, d$total_c, d$hdl_c, d$dm, d$smoking,
          d$egfr, d$statin, d$bp_tx, d$bmi, if (mdl == "hba1c") d$hba1c else NULL,
          outcome = o, use_hba1c = (mdl == "hba1c"))
        ours_p <- 1 - exp(-10 * ours_h)
        ref_p <- ref[[outcomes[[o]]]]
        errs[[length(errs) + 1]] <- data.frame(patient = k, model = mdl, outcome = o,
                                              ours = ours_p, preventr = ref_p,
                                              rel_error = abs(ours_p - ref_p) / ref_p)
      }
    }
  }
  errs <- do.call(rbind, errs)
  pass <- all(errs$rel_error < tol)

  agg <- aggregate(rel_error ~ model + outcome, errs, max)
  for (r in seq_len(nrow(agg))) {
    cat(sprintf("  %-6s %-7s max relative error = %.2e\n", agg$model[r], agg$outcome[r], agg$rel_error[r]))
  }
  cat("PREVENT equations validation:", ifelse(pass, "PASS", "FAIL"), "\n")
  invisible(structure(pass, errors = errs))
}

#' Validate kidney progression against the Kidney Failure Risk Equation (KFRE)
#'
#' @description Death-free probability that the model's SoC eGFR trajectory
#'   reaches eGFR 15 within 2 and 5 years, versus the 4-variable KFRE (Tangri et
#'   al., North American recalibration), for patients with eGFR < 60 pooled
#'   across the three CKM cohorts. KFRE is a Cox model with death censored, so it
#'   estimates the same death-free (net) risk.
#'
#' @param params Parameter lists (base values are used)
#' @param n_per_stage Patients generated per CKM stage
#' @param n_rep Heterogeneity draws per patient
#' @param tol Maximum allowed relative difference in mean risk
#' @return Logical indicating pass/fail (invisibly, with a summary attached)
validate_kidney_calibration <- function(params = l_params, n_per_stage = 2000, n_rep = 40,
                                        seed = 42, tol = 0.15) {
  base <- setNames(params$base_value, unlist(params$parameter_name))
  kfre <- function(age, male, egfr, uacr, yrs) {
    lp <- -0.2201 * (age / 10 - 7.036) + 0.2467 * (male - 0.5642) -
      0.5567 * (egfr / 5 - 7.222) + 0.4510 * (log(pmax(uacr, 1)) - 5.137)
    1 - (if (yrs == 2) 0.9832 else 0.9365)^exp(lp)
  }
  pop <- rbindlist(lapply(c(2, 3, 4), function(s) generate_ckm_population(n_per_stage, s, seed = seed)))
  pop <- pop[egfr < 60]

  set.seed(seed)
  z <- matrix(rnorm(nrow(pop) * n_rep), nrow(pop))
  slope <- base$egfr_decline_ref *
    egfr_patient_multiplier(pop$uacr, base$egfr_uacr_beta, base$egfr_slope_sdlog, z)
  t_eskd <- (pop$egfr - 15) / slope   # linear decline; no stage dependence

  res <- data.table(
    horizon = c(2, 5),
    kfre = c(mean(kfre(pop$age, pop$sex, pop$egfr, pop$uacr, 2)),
             mean(kfre(pop$age, pop$sex, pop$egfr, pop$uacr, 5))),
    model = c(mean(t_eskd <= 2), mean(t_eskd <= 5))
  )
  res[, rel_diff := model / kfre - 1]
  pass <- all(abs(res$rel_diff) < tol)

  cat("--- Kidney Progression Calibration (vs KFRE, eGFR < 60) ---\n")
  for (r in seq_len(nrow(res))) {
    cat(sprintf("  %d-year kidney failure: KFRE %.2f%%, model %.2f%% (%+.0f%%)\n",
                res$horizon[r], 100 * res$kfre[r], 100 * res$model[r], 100 * res$rel_diff[r]))
  }
  cat("Kidney calibration validation:", ifelse(pass, "PASS", "FAIL"), "\n")
  invisible(structure(pass, summary = res))
}

#' Run all validations
#'
#' @param results Output from WARDEN run_sim()
#' @param df_pop Simulated population data.table
#' @return Logical indicating overall pass/fail
#' @export
run_all_validations <- function(results, df_pop) {
  cat("=== Starting Validations ===\n")
  
  p1 <- validate_population(df_pop)
  p2 <- validate_event_rates(results)
  p3 <- validate_survival(results)
  p4 <- validate_aging(results)
  p5 <- validate_prevent_equations()
  p6 <- validate_kidney_calibration()

  overall_pass <- p1 && p2 && p3 && p4 && p5 && p6
  
  cat("=== Validations Complete ===\n")
  cat("Overall status:", ifelse(overall_pass, "PASS", "FAIL"), "\n")
  
  return(overall_pass)
}
