#!/usr/bin/env Rscript
# =============================================================================
# Extra manuscript tables derived from existing production outputs (no model run)
# =============================================================================
# Usage:  Rscript scripts/derive_manuscript_tables.R
# Reads outputs/tables/patient_level_stage3.csv.gz (base case, N = 20,000) and
# regenerates the base-case cohort (same generator and seed as run_base_case.R,
# checked against the patient-level file). Writes:
#   outputs/tables/baseline_characteristics_stage3.csv  (eTable 1)
#   outputs/tables/soc_event_rates_5y_stage3.csv         (first 5 years, SoC and
#       treated arms: event rates per 100 patient-years for trial comparison)
#   outputs/tables/prevent_composite_stage3.csv          (PREVENT total CVD vs
#       the union of the PREVENT ASCVD and HF predictions)
#   outputs/tables/external_benchmarks_stage3.csv        (SoC subgroups matched to
#       external CKD benchmarks: life expectancy, lifetime and 5-year kidney failure,
#       5-year death)
#   outputs/tables/monte_carlo_error_stage3.csv          (SE of the base case)
# =============================================================================

suppressPackageStartupMessages(library(data.table))
source("R/02_population.R")

SEED <- 42; STAGE <- 3
pl <- fread("outputs/tables/patient_level_stage3.csv.gz")
N <- pl[arm == "soc", .N]   # 20,000 in production
pop <- generate_ckm_population(N, ckm_stage = STAGE, seed = SEED)
soc <- pl[arm == "soc"][order(pat_id)]
stopifnot(nrow(soc) == N, isTRUE(all.equal(pop$age, soc$age)), isTRUE(all.equal(pop$egfr, soc$egfr)))

# ---- eTable 1: baseline characteristics ----
cont <- function(v, lab) data.table(characteristic = lab, mean = mean(v), sd = sd(v),
                                    median = median(v), p25 = quantile(v, .25), p75 = quantile(v, .75),
                                    min = min(v), max = max(v), pct = NA_real_)
bin <- function(v, lab) data.table(characteristic = lab, mean = NA_real_, sd = NA_real_, median = NA_real_,
                                   p25 = NA_real_, p75 = NA_real_, min = NA_real_, max = NA_real_, pct = 100 * mean(v))
bc <- rbind(
  cont(pop$age, "Age, y"), bin(pop$age >= 65, "Age >=65 y"), bin(pop$age > 79, "Age >79 y"),
  bin(pop$sex == 1, "Male sex"), bin(pop$sex == 0, "Female sex"),
  cont(pop$bmi, "BMI"), bin(pop$bmi >= 30, "BMI >=30"),
  cont(pop$sbp, "Systolic blood pressure, mm Hg"),
  cont(pop$egfr, "eGFR, mL/min/1.73 m2"), bin(pop$egfr < 45, "eGFR <45"),
  bin(pop$egfr >= 45 & pop$egfr < 60, "eGFR 45-59"), bin(pop$egfr >= 60, "eGFR >=60"),
  bin(pop$egfr < 30, "eGFR <30"),
  cont(pop$uacr, "UACR, mg/g"), bin(pop$uacr < 30, "UACR <30"),
  bin(pop$uacr >= 30 & pop$uacr < 300, "UACR 30-299"), bin(pop$uacr >= 300, "UACR >=300"),
  bin(pop$diabetes == 1, "Type 2 diabetes"),
  cont(pop[diabetes == 1]$hba1c, "HbA1c (diabetes), %"), cont(pop[diabetes == 0]$hba1c, "HbA1c (no diabetes), %"),
  cont(pop$total_chol, "Total cholesterol, mg/dL"), cont(pop$hdl_chol, "HDL cholesterol, mg/dL"),
  cont(pop$ldl_chol, "LDL cholesterol, mg/dL"),
  bin(pop$smoking == 1, "Current smoking"), bin(pop$statin_use == 1, "Statin use"),
  bin(pop$antihyp_use == 1, "Antihypertensive use"),
  cont(soc$prevent_total_cvd * 100, "PREVENT 10-y total CVD risk, %"),
  bin(soc$prevent_total_cvd >= 0.20, "PREVENT 10-y total CVD risk >=20%"),
  bin(soc$risk_equivalent, "Meets a Stage 3 risk equivalent")
)
fwrite(bc, "outputs/tables/baseline_characteristics_stage3.csv")

# ---- First-5-year event rates per 100 patient-years (for trial placebo arms) ----
rates5 <- pl[, {
  fu <- pmin(t_end, 5)
  py <- sum(fu)
  cvd5 <- sum(end_reason == "death_cv" & t_end <= 5)
  t_mace <- pmin(fifelse(is.na(t_first_mi), Inf, t_first_mi),
                 fifelse(is.na(t_first_stroke), Inf, t_first_stroke),
                 fifelse(end_reason == "death_cv", t_end, Inf))
  first_mace5 <- sum(t_mace <= 5)
  py_mace <- sum(pmin(t_mace, fu))
  .(person_years_5y = py,
    mi_per_100py = 100 * sum(n_mi_5y) / py,
    stroke_per_100py = 100 * sum(n_stroke_5y) / py,
    hf_hosp_per_100py = 100 * sum(n_hf_5y) / py,
    cv_death_per_100py = 100 * cvd5 / py,
    first_3p_mace_per_100py = 100 * first_mace5 / py_mace,
    all_death_5y_pct = 100 * mean(t_end <= 5 & grepl("^death", end_reason)))
}, by = arm]
fwrite(rates5, "outputs/tables/soc_event_rates_5y_stage3.csv")

# ---- PREVENT total CVD vs union of the outcome-specific predictions ----
comp <- soc[, .(prevent_total_cvd = mean(prevent_total_cvd),
                prevent_ascvd = mean(prevent_ascvd), prevent_hf = mean(prevent_hf),
                union_ascvd_hf_independent = mean(1 - (1 - prevent_ascvd) * (1 - prevent_hf)))]
fwrite(comp, "outputs/tables/prevent_composite_stage3.csv")

# ---- External benchmarks (SoC arm) ----
# Life expectancy and lifetime kidney failure from entry at age 55-65 y (Turin 2014,
# 2012: age 60 y, Alberta), and 5-year death and kidney failure at age >= 65 y with
# eGFR 30-59 (USRDS 2015: Medicare beneficiaries with CKD stage 3).
bench <- function(sel, lab, by_sex = TRUE) {
  d <- soc[sel]
  f <- function(x) x[, .(n = .N, life_expectancy = mean(t_end),
                         lifetime_kf_pct = 100 * mean(!is.na(t_eskd)),
                         death_5y_pct = 100 * mean(t_end <= 5 & grepl("^death", end_reason)),
                         kf_5y_pct = 100 * mean(!is.na(t_eskd) & t_eskd <= 5))]
  out <- cbind(sex = "All", f(d))
  if (by_sex) out <- rbind(out, cbind(sex = "Men", f(d[sex == 1])), cbind(sex = "Women", f(d[sex == 0])))
  cbind(benchmark = lab, out)
}
mid <- soc$age >= 55 & soc$age <= 65
benchmarks <- rbind(
  bench(mid & soc$uacr >= 30 & soc$uacr < 300, "le_uacr30_299_age55_65"),
  bench(mid & soc$egfr >= 45 & soc$egfr < 60, "egfr45_59_age55_65"),
  bench(mid & soc$egfr >= 30 & soc$egfr < 45, "egfr30_44_age55_65"),
  bench(soc$age >= 65 & soc$egfr >= 30 & soc$egfr < 60, "egfr30_59_age65plus"))
fwrite(benchmarks, "outputs/tables/external_benchmarks_stage3.csv")
print(benchmarks)

print(bc[, lapply(.SD, function(x) if (is.numeric(x)) round(x, 1) else x)])
print(rates5[, lapply(.SD, function(x) if (is.numeric(x)) round(x, 2) else x)])
print(comp)

# ---- Monte Carlo (first-order) error of the base case ----
# Arms share common random numbers, so per-patient paired differences are
# independent across patients: SE(mean) = SD(difference) / sqrt(N). ICER
# uncertainty from a nonparametric bootstrap over patients (1,000 resamples).
WTP <- 120000
w <- dcast(pl, pat_id ~ arm, value.var = c("costs", "qalys"))
pairs <- list(c("sglt2i", "soc", "SGLT2i + SoC vs SoC"), c("glp1ra", "soc", "GLP-1 RA + SoC vs SoC"),
              c("sglt2i", "glp1ra", "SGLT2i + SoC vs GLP-1 RA + SoC"))
set.seed(2026)
B <- 1000
idx <- replicate(B, sample.int(nrow(w), replace = TRUE), simplify = FALSE)
mc <- rbindlist(lapply(pairs, function(p) {
  dc <- w[[paste0("costs_", p[1])]] - w[[paste0("costs_", p[2])]]
  dq <- w[[paste0("qalys_", p[1])]] - w[[paste0("qalys_", p[2])]]
  nmb <- dq * WTP - dc
  boot_icer <- vapply(idx, function(i) mean(dc[i]) / mean(dq[i]), numeric(1))
  data.table(comparison = p[3], n = length(dc), inc_cost = mean(dc), se_inc_cost = sd(dc) / sqrt(length(dc)),
             inc_qaly = mean(dq), se_inc_qaly = sd(dq) / sqrt(length(dq)),
             inmb = mean(nmb), se_inmb = sd(nmb) / sqrt(length(nmb)),
             icer = mean(dc) / mean(dq), se_icer_boot = sd(boot_icer),
             icer_boot_2.5 = quantile(boot_icer, .025), icer_boot_97.5 = quantile(boot_icer, .975))
}))
fwrite(mc, "outputs/tables/monte_carlo_error_stage3.csv")
print(mc)
