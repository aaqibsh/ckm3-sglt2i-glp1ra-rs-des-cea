# =============================================================================
# File: 11_patient_outputs.R
# Purpose: Patient-level summaries from the base-case event log (ipd = 1):
#          event burden, subgroups, external-validation checks
# Author: CKM-HEOR Team
# Date: 2026-10-14
# =============================================================================
# The base case writes one row per patient and arm (patient_summary()); every
# table below is computed from that file, so subgroup and validation tables can
# be rebuilt without rerunning the model.
# =============================================================================

library(data.table)

#' Baseline PREVENT 10-year risks with the official preventr implementation
#'
#' @description Inputs are clamped to PREVENT's validated ranges (age 30-79,
#'   SBP 90-180, total cholesterol 130-320, HDL 20-100, BMI 18.5-39.9,
#'   eGFR 15-140) so every patient gets a prediction; the model's own hazards
#'   use the same winsorisation (03_risk_equations.R). HbA1c model, as in the
#'   simulation.
#' @param pop Population from generate_ckm_population()
#' @return data.table: pat_id, prevent_total_cvd, prevent_ascvd, prevent_hf
prevent_baseline_risk <- function(pop) {
  cl <- function(x, lo, hi) pmin(pmax(x, lo), hi)
  d <- data.frame(
    age = cl(pop$age, 30, 79), sex = ifelse(pop$sex == 1, "male", "female"),
    sbp = cl(pop$sbp, 90, 180), bp_tx = pop$antihyp_use == 1,
    total_c = cl(pop$total_chol, 130, 320), hdl_c = cl(pop$hdl_chol, 20, 100),
    statin = pop$statin_use == 1, dm = pop$diabetes == 1, smoking = pop$smoking == 1,
    egfr = cl(pop$egfr, 15, 140), bmi = cl(pop$bmi, 18.5, 39.9), hba1c = cl(pop$hba1c, 4.5, 15),
    model = "hba1c", time = "10yr"
  )
  r <- preventr::estimate_risk(use_dat = d, progress = FALSE, quiet = TRUE)
  data.table(pat_id = pop$pat_id, prevent_total_cvd = r$total_cvd,
             prevent_ascvd = r$ascvd, prevent_hf = r$heart_failure)
}

#' Stage 3 risk-equivalent flag (2023 AHA presidential advisory)
#'
#' @description Very-high-risk CKD (KDIGO: G4-G5; G3b with A2-A3; G3a with A3)
#'   or predicted 10-year total CVD risk >= 20%. Subclinical atherosclerosis or
#'   subclinical HF (imaging, biomarkers) is not represented in the cohort.
stage3_risk_equivalent <- function(egfr, uacr, total_cvd) {
  kdigo_vh <- egfr < 30 | (egfr < 45 & uacr >= 30) | (egfr < 60 & uacr >= 300)
  kdigo_vh | total_cvd >= 0.20
}

#' One row per patient and arm from the base-case event log
#'
#' @param res Output of run_ckm_model(ipd_level = 1), deterministic
#' @param pop The population that was simulated (same n and seed)
#' @return data.table with outcomes, event counts and times, and covariates
patient_summary <- function(res, pop) {
  d <- as.data.table(res[[1]][[1]]$merged_df)
  setorder(d, arm, pat_id, evttime)
  first_t <- function(ev, t, name) if (any(ev == name)) min(t[ev == name]) else NA_real_
  n_before <- function(ev, t, name, h) sum(ev == name & t <= h)

  ps <- d[, .(
    costs = sum(costs), qalys = sum(qalys), lys = sum(lys), lys_undisc = sum(lys_undisc),
    qalys_undisc = sum(qalys_undisc),
    drug_cost = sum(c_drug_com) + sum(c_drug_mcr), drug_cost_com = sum(c_drug_com),
    drug_cost_mcr = sum(c_drug_mcr), addon_cost = sum(c_addon),
    n_mi = sum(evtname == "mi"), n_stroke = sum(evtname == "stroke"), n_hf = sum(evtname == "hf_hosp"),
    n_mi_5y = n_before(evtname, evttime, "mi", 5), n_stroke_5y = n_before(evtname, evttime, "stroke", 5),
    n_hf_5y = n_before(evtname, evttime, "hf_hosp", 5),
    t_first_mi = first_t(evtname, evttime, "mi"), t_first_stroke = first_t(evtname, evttime, "stroke"),
    t_first_hf = first_t(evtname, evttime, "hf_hosp"),
    t_eskd = if (any(evtname == "ckd_prog" & ckd_stage == 5)) min(evttime[evtname == "ckd_prog" & ckd_stage == 5]) else NA_real_,
    t_end = max(evttime),
    end_reason = evtname[which.max(evttime)]
  ), by = .(pat_id, arm)]

  base_risk <- prevent_baseline_risk(pop)
  cov <- merge(pop[, .(pat_id, age, sex, bmi, sbp, egfr, uacr, hba1c, diabetes)], base_risk, by = "pat_id")
  cov[, risk_equivalent := stage3_risk_equivalent(egfr, uacr, prevent_total_cvd)]
  merge(ps, cov, by = "pat_id")
}

#' Subgroup definitions used in the manuscript
subgroup_labels <- function(ps) {
  ps <- copy(ps)
  ps[, `:=`(
    sg_diabetes = ifelse(diabetes == 1, "Diabetes", "No diabetes"),
    sg_egfr = cut(egfr, c(-Inf, 45, 60, Inf), right = FALSE,
                  labels = c("eGFR <45", "eGFR 45-59", "eGFR >=60")),
    sg_uacr = cut(uacr, c(-Inf, 30, 300, Inf), right = FALSE,
                  labels = c("UACR <30 mg/g", "UACR 30-299 mg/g", "UACR >=300 mg/g")),
    sg_age = ifelse(age < 65, "Age <65 y", "Age >=65 y"),
    sg_sex = ifelse(sex == 1, "Male", "Female"),
    sg_risk = ifelse(risk_equivalent, "Meets Stage 3 risk-equivalent", "Does not meet risk-equivalent")
  )]
  ps
}

#' Incremental results by subgroup for each pairwise comparison
#'
#' @param ps Output of patient_summary()
#' @param wtp Willingness-to-pay threshold
#' @param comparisons List of c(intervention, comparator)
#' @return data.table: dimension, subgroup, n, comparison, inc_cost, inc_qaly, icer_label, inmb
subgroup_table <- function(ps, wtp = 120000, comparisons = DEFAULT_COMPARISONS) {
  ps <- subgroup_labels(ps)
  dims <- c(Overall = NA, `Diabetes status` = "sg_diabetes", `Baseline eGFR` = "sg_egfr",
            `Baseline UACR` = "sg_uacr", Age = "sg_age", Sex = "sg_sex",
            `Stage 3 risk-equivalent` = "sg_risk")
  rbindlist(lapply(names(dims), function(dn) {
    col <- dims[[dn]]
    groups <- if (is.na(col)) list(Overall = rep(TRUE, nrow(ps))) else
      lapply(setNames(levels(factor(ps[[col]])), levels(factor(ps[[col]]))), function(g) ps[[col]] == g)
    rbindlist(lapply(names(groups), function(g) {
      sub <- ps[groups[[g]]]
      means <- sub[, .(costs = mean(costs), qalys = mean(qalys), lys = mean(lys)), by = arm]
      res_like <- list(total_costs = setNames(means$costs, means$arm),
                       total_qalys = setNames(means$qalys, means$arm),
                       total_lys = setNames(means$lys, means$arm))
      out <- rbindlist(lapply(comparisons, function(cp) compare_arms(res_like, cp[1], cp[2], wtp)))
      out[, `:=`(dimension = dn, subgroup = g, n_patients = uniqueN(sub$pat_id))]
      setcolorder(out, c("dimension", "subgroup", "n_patients"))
      out
    }))
  }))
}

#' Clinical event burden per arm
#'
#' @return data.table per arm: % with >= 1 event, events per 100 patients and per
#'   100 patient-years (lifetime and first 5 years), kidney failure, undiscounted
#'   life expectancy
event_table <- function(ps) {
  ps[, .(
    n_patients = .N,
    pct_any_mi = 100 * mean(n_mi > 0), pct_any_stroke = 100 * mean(n_stroke > 0),
    pct_any_hf = 100 * mean(n_hf > 0), pct_kidney_failure = 100 * mean(!is.na(t_eskd)),
    mi_per_100pts = 100 * mean(n_mi), stroke_per_100pts = 100 * mean(n_stroke),
    hf_per_100pts = 100 * mean(n_hf),
    mi_per_100py = 100 * sum(n_mi) / sum(lys_undisc),
    stroke_per_100py = 100 * sum(n_stroke) / sum(lys_undisc),
    hf_per_100py = 100 * sum(n_hf) / sum(lys_undisc),
    mi_per_100py_5y = 100 * sum(n_mi_5y) / sum(pmin(t_end, 5)),
    stroke_per_100py_5y = 100 * sum(n_stroke_5y) / sum(pmin(t_end, 5)),
    hf_per_100py_5y = 100 * sum(n_hf_5y) / sum(pmin(t_end, 5)),
    cv_death_pct = 100 * mean(end_reason == "death_cv"),
    cv_death_per_100pts = 100 * mean(end_reason == "death_cv"),
    life_expectancy_undisc = mean(lys_undisc),
    qalys_undisc = mean(qalys_undisc),
    pct_at_cap_mi = 100 * mean(n_mi >= 3), pct_at_cap_stroke = 100 * mean(n_stroke >= 3),
    pct_at_cap_hf = 100 * mean(n_hf >= 5),
    pct_persontime_age_gt79 = 100 * sum(pmax(0, age + t_end - pmax(age, 79))) / sum(t_end),
    mean_age_at_death = mean(age + t_end)
  ), by = arm]
}

#' External-validation checks in the SoC arm
#'
#' @description Simulated 10-year cumulative incidence (crude proportion with a
#'   first event by year 10; death competes) compared with the mean baseline
#'   PREVENT 10-year prediction for the same patients.
#' @return data.table: check, simulated, predicted
validation_table <- function(ps) {
  soc <- ps[arm == "soc"]
  ascvd_10 <- with(soc, pmin(t_first_mi, t_first_stroke, na.rm = TRUE) <= 10)
  ascvd_10[is.na(ascvd_10)] <- FALSE
  hf_10 <- !is.na(soc$t_first_hf) & soc$t_first_hf <= 10
  any_10 <- ascvd_10 | hf_10
  data.table(
    check = c("10-year first MI or stroke vs PREVENT ASCVD",
              "10-year first HF hospitalisation vs PREVENT HF",
              "10-year first MI, stroke or HF vs PREVENT total CVD",
              "Proportion meeting Stage 3 risk-equivalent"),
    simulated = c(mean(ascvd_10), mean(hf_10), mean(any_10), mean(soc$risk_equivalent)),
    predicted = c(mean(soc$prevent_ascvd), mean(soc$prevent_hf), mean(soc$prevent_total_cvd), NA)
  )
}

#' PREVENT risk distribution of the simulated cohort
risk_distribution <- function(ps) {
  soc <- ps[arm == "soc"]
  q <- function(x) as.list(setNames(quantile(x, c(0.25, 0.5, 0.75)), c("p25", "median", "p75")))
  rbind(
    data.table(measure = "PREVENT 10-y total CVD", mean = mean(soc$prevent_total_cvd), as.data.table(q(soc$prevent_total_cvd)),
               pct_ge_20 = 100 * mean(soc$prevent_total_cvd >= 0.20)),
    data.table(measure = "PREVENT 10-y ASCVD", mean = mean(soc$prevent_ascvd), as.data.table(q(soc$prevent_ascvd)),
               pct_ge_20 = 100 * mean(soc$prevent_ascvd >= 0.20)),
    data.table(measure = "PREVENT 10-y HF", mean = mean(soc$prevent_hf), as.data.table(q(soc$prevent_hf)),
               pct_ge_20 = 100 * mean(soc$prevent_hf >= 0.20))
  )
}
