#!/usr/bin/env Rscript
# =============================================================================
# Master parameter table (supplement eTable 3) generated from the model code
# =============================================================================
# Usage:  Rscript scripts/make_parameter_table.R
# Writes outputs/tables/master_parameter_table.csv and the class-level table in
# docs/PARAMETER_SOURCES.md, both from build_param_lists() (R/01_parameters.R),
# so the published values cannot drift from the values the model ran with.
# SOURCES below holds the evidence statement for each parameter; update it when
# a parameter or its source changes.
# =============================================================================

suppressPackageStartupMessages(library(data.table))
source("R/01_parameters.R")
source("R/09_results.R")   # PARAM_LABELS

SOURCES <- c(
  hr_sglt2i_mace = "McGuire et al. JAMA Cardiol 2021 (6 SGLT2i outcome trials): MACE HR 0.90 (0.85-0.95)",
  hr_sglt2i_hf = "McGuire et al. JAMA Cardiol 2021: HF hospitalization HR 0.68 (0.61-0.76)",
  hr_sglt2i_cv_death = "McGuire et al. JAMA Cardiol 2021: CV death HR 0.85 (0.78-0.93)",
  sglt2i_egfr_slope_ratio = "SMART-C, Lancet 2022: kidney disease progression RR 0.63 (0.58-0.69), applied as slope ratio (time to an eGFR threshold scales with 1/slope)",
  hr_glp1_mace = "Sattar et al. Lancet Diabetes Endocrinol 2021 (8 GLP-1 RA outcome trials): MACE HR 0.86 (0.80-0.93)",
  hr_glp1_hf = "Sattar et al. 2021: HF hospitalization HR 0.89 (0.82-0.98)",
  hr_glp1_cv_death = "Sattar et al. 2021: CV death HR 0.87 (0.80-0.94)",
  glp1_egfr_slope_ratio = "Badve et al. Lancet Diabetes Endocrinol 2025 (11 trials incl. FLOW, SELECT): composite kidney outcome HR 0.81 (0.72-0.92), applied as slope ratio",
  cost_sglt2i = "Before age 65 (commercial): brand acquisition cost without rebate, mean of empagliflozin and dapagliflozin, CMS NADAC 21 Oct 2026; range 30% rebate to 2025 WAC",
  cost_glp1ra = "Before age 65 (commercial): semaglutide net price $6,829/y (SSR Health; ICER obesity final report, Dec 2025); range self-pay $349/mo to 2027 list price $675/mo",
  cost_sglt2i_mcr = "From age 65 (Medicare): empagliflozin maximum fair price $197 per 30 days (2026); range dapagliflozin MFP to +10%",
  cost_glp1ra_mcr = "From age 65 (Medicare): semaglutide maximum fair price $274 per 30 days (2027); range $245/mo GLP-1 Bridge price to +10%",
  cost_soc = "Assumption (generic statin and ACEi/ARB)",
  cost_mi_acute = "HCUP National Inpatient Sample",
  cost_stroke_acute = "HCUP National Inpatient Sample",
  cost_hf_hosp = "HCUP National Inpatient Sample",
  cost_mi_post = "Assumption",
  cost_stroke_post = "Assumption",
  cost_hf_post = "Assumption",
  cost_ckd3_annual = "Assumption",
  cost_ckd4_annual = "Assumption",
  cost_eskd_annual = "USRDS 2024 Annual Data Report (total per-patient ESKD spending; replaces CKD 4 cost)",
  cost_bg_base = "MEPS",
  cost_bg_age_coef = "MEPS (added per year of age above 50)",
  util_baseline = "US population norms (Sullivan & Ghushchyan 2006)",
  util_dec_mi_acute = "Assumption (one-time QALY loss)",
  util_dec_mi_chronic = "Assumption",
  util_dec_stroke_acute = "Assumption (one-time QALY loss)",
  util_dec_stroke_chronic = "Assumption",
  util_dec_hf = "Assumption (one-time loss; half persists after the first HF hospitalization)",
  util_dec_ckd3 = "Assumption",
  util_dec_ckd4 = "Assumption",
  util_dec_eskd = "Added to the CKD 4 decrement; dialysis utility ~0.56-0.58 (Wyld et al. 2012)",
  prob_disc_sglt2i = "Assumption (trial-like persistence); real-world 1-year discontinuation 53.0% in a scenario (Bowe et al. 2025, Medicare Advantage)",
  prob_disc_glp1 = "Assumption (trial-like persistence); real-world 1-year discontinuation 62.4% in a scenario (Bowe et al. 2025, Medicare Advantage)",
  tx_wane_years = "Assumption: linear loss of effect after discontinuation (0 = immediate)",
  egfr_decline_ref = "Calibrated to KFRE 2- and 5-year kidney failure risk (Tangri, 4-variable, North American)",
  egfr_uacr_beta = "KFRE log(UACR) coefficient; varied in the PSA",
  egfr_slope_sdlog = "Calibrated jointly with the reference decline; varied in the PSA",
  sbp_drift = "Assumption (age-related SBP rise)",
  hba1c_drift_dm = "Assumption (UKPDS-type glycaemic drift)",
  rr_recur_mi = "Assumption", rr_recur_stroke = "Assumption", rr_recur_hf = "Assumption",
  cvd_mult_mi = "Assumption", cvd_mult_stroke = "Assumption", cvd_mult_hf = "Assumption",
  cvd_mult_ckd3 = "Assumption", cvd_mult_ckd4 = "Assumption", cvd_mult_eskd = "Assumption",
  drc = "Second Panel on Cost-Effectiveness in Health and Medicine",
  drq = "Second Panel on Cost-Effectiveness in Health and Medicine",
  horizon_years = "Lifetime (100 years from entry); 10 and 20 years in scenarios",
  age_medicare = "Medicare eligibility age",
  stop_sglt2i_at_kf = "KDIGO 2024: continue SGLT2i until dialysis or transplant; continued for life in a scenario",
  addon_sglt2i = "Scenario: SGLT2i started at first HF hospitalization or CKD stage 4 in the SoC and GLP-1 RA arms",
  bg_mort_mult = "Scenario 0.7: Gompertz hazard read as all-cause mortality; major cardiovascular diseases 28.6% of US deaths in 2022 (NVSR 74(4))",
  kidney_effect_restrict = "Scenario: kidney effect only with UACR >= 30 mg/g or eGFR < 60",
  hf_hosp_frac = "Scenario 0.5: share of incident HF that is hospitalized (52.8% diagnosed in acute care; Tisdale 2023)",
  util_gain_sglt2i = "Scenario 0.002: weight -0.80 kg vs placebo (CREDENCE), -0.0061 per BMI unit above 25 (Bagust and Beale 2005)",
  util_gain_glp1 = "Scenario 0.009: weight -4.10 kg vs placebo (FLOW), -0.0061 per BMI unit above 25 (Bagust and Beale 2005)",
  prevent_age_cap = "Scenario 79: PREVENT validated age range 30-79",
  soc_optimized = "Scenario: SBP lowered to 130 mm Hg and statin for all",
  psa_hr_rho = "Assumption: correlation of log HRs within a class in the PSA"
)

lp <- build_param_lists()
nm <- unlist(lp$parameter_name)
stopifnot(all(nm %in% names(SOURCES)))
fmt <- function(x) vapply(x, function(v) if (abs(v) >= 100) format(round(v), big.mark = ",", trim = TRUE)
                          else format(signif(v, 3), trim = TRUE, scientific = FALSE), character(1))
psa_text <- mapply(function(d, a, b, on) {
  if (on == 0 || b == 0) return("Fixed")
  switch(d,
         rlnorm = sprintf("Lognormal (log-mean %.3f, SE %.3f)", a, b),
         rgamma_mse = sprintf("Gamma (mean %s, SE %s)", fmt(a), fmt(b)),
         rbeta_mse = sprintf("Beta (mean %s, SE %s)", fmt(a), fmt(b)),
         rnorm = sprintf("Normal (mean %s, SD %s)", fmt(a), fmt(b)),
         d)
}, unlist(lp$PSA_dist), unlist(lp$a), unlist(lp$b), unlist(lp$psa_indicators))

tab <- data.table(
  parameter = nm, label = unname(ifelse(nm %in% names(PARAM_LABELS), PARAM_LABELS[nm], nm)),
  base = unlist(lp$base_value), psa = unname(psa_text),
  dsa_min = unlist(lp$DSA_min), dsa_max = unlist(lp$DSA_max),
  in_psa = unlist(lp$psa_indicators) == 1,
  in_dsa = unlist(lp$dsa_indicators) == 1 & !nm %in% c("drc", "drq", "horizon_years"),
  source = unname(SOURCES[nm])
)
dir.create("outputs/tables", recursive = TRUE, showWarnings = FALSE)
fwrite(tab, "outputs/tables/master_parameter_table.csv")

md_rows <- tab[, sprintf("| `%s` | %s | %s | %s | %s – %s | %s | %s |", parameter, label, fmt(base), psa,
                         fmt(dsa_min), fmt(dsa_max), ifelse(in_dsa, "Yes", "Scenario"), source)]
section <- c("## Model parameters (class-level base case)", "",
             "| Parameter | Description | Base | PSA distribution | DSA range | One-way DSA | Source |",
             "|:--|:--|--:|:--|:--|:--|:--|", md_rows, "")
doc <- readLines("docs/PARAMETER_SOURCES.md")
start <- grep("^## Model parameters", doc)
end <- grep("^## Drug-specific scenario inputs", doc)
writeLines(c(doc[seq_len(start - 1)], section, doc[end:length(doc)]), "docs/PARAMETER_SOURCES.md")
cat(sprintf("%d parameters written to outputs/tables/master_parameter_table.csv and docs/PARAMETER_SOURCES.md\n", nrow(tab)))
