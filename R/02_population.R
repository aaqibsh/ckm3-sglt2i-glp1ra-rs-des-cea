# ---- Header ----
# Purpose: Generate synthetic patient populations for CKM stages
# Author: CKM-HEOR Agent
# Date: 2026-09-28 (revised — eGFR truncated at 20, HbA1c consistent with diabetes)
# ----------------

library(data.table)

#' Truncated normal draws by inverse CDF (one uniform per draw, so the random
#' stream length matches rnorm and avoids point masses at the bounds)
rtruncnorm_inv <- function(n, mean, sd, lower, upper) {
  qnorm(runif(n, pnorm(lower, mean, sd), pnorm(upper, mean, sd)), mean, sd)
}

#' Generate Synthetic Patient Population for CKM Stages
#'
#' @description
#' Generates a synthetic population of patients matching the characteristics
#' of specific Cardiovascular-Kidney-Metabolic (CKM) syndrome stages.
#'
#' @param n Integer, number of patients to generate
#' @param ckm_stage Integer (2, 3, or 4), specifies the CKM stage
#' @param seed Integer, random seed for reproducibility
#'
#' @return A data.table containing patient characteristics
#' @export
#'
#' @import data.table
generate_ckm_population <- function(n, ckm_stage, seed = NULL) {
  if (!is.null(seed)) {
    set.seed(seed)
  }

  if (!ckm_stage %in% c(2, 3, 4)) {
    stop("ckm_stage must be 2, 3, or 4")
  }

  # ---- Section: Initialize Base Population ----
  dt <- data.table::data.table(pat_id = 1:n)
  dt[, ckm_stage := ckm_stage]

  # ---- Section: Simulate Characteristics by Stage ----
  if (ckm_stage == 2) {
    # CKM Stage 2: Metabolic risk factors ± CKD
    dt[, age := pmax(30, pmin(80, rnorm(n, 55, 10)))]
    dt[, sex := rbinom(n, 1, 0.55)]
    dt[, bmi := pmax(25, pmin(50, rnorm(n, 32, 5)))]
    dt[, sbp := rnorm(n, 138, 15)]
    dt[, egfr := rtruncnorm_inv(n, 65, 20, 20, 120)]
    dt[, uacr := pmax(0, pmin(500, rnorm(n, 80, 60)))]
    dt[, hba1c := pmax(5.5, pmin(12, rnorm(n, 7.2, 1.0)))]
    dt[, total_chol := rnorm(n, 210, 35)]
    dt[, hdl_chol := rnorm(n, 42, 10)]
    dt[, ldl_chol := rnorm(n, 130, 30)]
    dt[, smoking := rbinom(n, 1, 0.20)]
    dt[, diabetes := rbinom(n, 1, 0.60)]
    dt[, statin_use := rbinom(n, 1, 0.50)]
    dt[, antihyp_use := rbinom(n, 1, 0.65)]
  } else if (ckm_stage == 3) {
    # CKM Stage 3: Subclinical CVD / PREVENT >= 20%
    dt[, age := pmax(40, pmin(85, rnorm(n, 62, 8)))]
    dt[, sex := rbinom(n, 1, 0.60)]
    dt[, bmi := rnorm(n, 33, 5)]
    dt[, sbp := rnorm(n, 145, 15)]
    dt[, egfr := rtruncnorm_inv(n, 55, 18, 20, 100)]
    dt[, uacr := pmax(0, pmin(1000, rnorm(n, 150, 100)))]
    dt[, hba1c := rnorm(n, 7.5, 1.2)]
    dt[, total_chol := rnorm(n, 220, 40)]
    dt[, hdl_chol := rnorm(n, 40, 10)]
    dt[, ldl_chol := rnorm(n, 140, 35)]
    dt[, smoking := rbinom(n, 1, 0.25)]
    dt[, diabetes := rbinom(n, 1, 0.70)]
    dt[, statin_use := rbinom(n, 1, 0.55)]
    dt[, antihyp_use := rbinom(n, 1, 0.75)]
  } else if (ckm_stage == 4) {
    # CKM Stage 4a: Established CVD
    dt[, age := pmax(45, pmin(90, rnorm(n, 67, 8)))]
    dt[, sex := rbinom(n, 1, 0.65)]
    dt[, bmi := rnorm(n, 31, 5)]
    dt[, sbp := rnorm(n, 140, 18)]
    dt[, egfr := rtruncnorm_inv(n, 58, 20, 20, 110)]
    dt[, uacr := rnorm(n, 120, 90)]
    dt[, hba1c := rnorm(n, 7.3, 1.1)]
    dt[, total_chol := rnorm(n, 195, 35)]
    dt[, hdl_chol := rnorm(n, 43, 10)]
    dt[, ldl_chol := rnorm(n, 110, 30)]
    dt[, smoking := rbinom(n, 1, 0.15)]
    dt[, diabetes := rbinom(n, 1, 0.55)]
    dt[, statin_use := rbinom(n, 1, 0.75)]
    dt[, antihyp_use := rbinom(n, 1, 0.80)]
  }

  # ---- Section: HbA1c consistent with diabetes status ----
  # HbA1c above is drawn for everyone (kept to preserve the random stream);
  # non-diabetics are redrawn in the normoglycaemic/prediabetes range (< 6.5%,
  # the ADA diagnostic threshold) and diabetics are floored at 5.7%.
  dt[diabetes == 0, hba1c := pmin(6.4, pmax(4.8, rnorm(.N, 5.8, 0.35)))]
  dt[diabetes == 1, hba1c := pmax(5.7, hba1c)]

  # ---- Section: Derive CKD Stage ----
  # Assign CKD stage based on eGFR: Stage 1-2 (>=60), Stage 3 (30-59), Stage 4 (15-29), Stage 5 (<15)
  dt[, ckd_stage := data.table::fcase(
    egfr >= 60, 1L,
    egfr >= 30 & egfr < 60, 3L,
    egfr >= 15 & egfr < 30, 4L,
    egfr < 15, 5L,
    default = 1L
  )]

  return(dt)
}
