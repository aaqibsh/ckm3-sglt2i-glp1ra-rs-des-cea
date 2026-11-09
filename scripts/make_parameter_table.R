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
  cost_glp1ra = "Before age 65 (commercial), without type 2 diabetes: semaglutide (Wegovy-based) net price $6,829/y (SSR Health; ICER obesity final report, Dec 2025); range self-pay $349/mo to 2027 list price $675/mo",
  glp1_dm_price_ratio = "With type 2 diabetes: commercial price x Ozempic/Wegovy list-price ratio (1,028/1,349; $5,205/y); range Ozempic self-pay price ($349/mo) to the Wegovy-based net price; moves with the commercial price in the PSA",
  cost_sglt2i_mcr = "From age 65 (Medicare): empagliflozin maximum fair price $197 per 30 days (2026); range dapagliflozin MFP to +10%",
  cost_glp1ra_mcr = "From age 65 (Medicare): semaglutide maximum fair price $274 per 30 days (2027); range $245/mo GLP-1 Bridge price to +10%",
  cost_soc = "Assumption (generic statin, ACEi/ARB and monitoring)",
  cost_mi_acute = "HCUP Statistical Brief #316, 2022 NIS: AMI aggregate cost / stays, $28,062 (2022 USD)",
  cost_stroke_acute = "HCUP Statistical Brief #316, 2022 NIS: cerebral infarction aggregate cost / stays, $20,185 (2022 USD)",
  cost_hf_hosp = "HCUP Statistical Brief #316, 2022 NIS: heart failure aggregate cost / stays, $16,608 (2022 USD)",
  cost_mi_post = "Ward et al. J Med Econ 2014: MI annual state cost $1,904 (2012 USD)",
  cost_stroke_post = "Ward et al. J Med Econ 2014: ischemic stroke annual state cost $15,541 (2012 USD)",
  cost_hf_post = "Ward et al. J Med Econ 2014: congestive HF annual state cost $1,904 (2012 USD)",
  cost_ckd3a_annual = "Tisdale et al. J Gen Intern Med 2022 (from Erickson 2013): added cost CKD 3a $196/mo (2019 USD)",
  cost_ckd3b_annual = "Tisdale et al. 2022: added cost CKD 3b $482/mo (2019 USD)",
  cost_ckd4_annual = "Tisdale et al. 2022: added cost CKD 4 and kidney failure without kidney replacement therapy $625/mo (2019 USD)",
  cost_eskd_annual = "USRDS 2024 Annual Data Report: Medicare FFS spending per person-year, in-center hemodialysis, $99,369 (2022 USD); replaces the CKD 4 cost",
  cost_bg_base = "MEPS 2022 mean expenditure per person: $8,406 at 45-64 y, $13,524 at >=65 y; linear between 54.5 and 75 y ($7,282 at 50 y, 2022 USD)",
  cost_bg_age_coef = "MEPS 2022 (as above): $249.7 per year of age above 50 (2022 USD)",
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
  egfr_decline_ref = "Calibrated to KFRE 2- and 5-year kidney failure by eGFR band (Tangri 2016, 4-variable, North American) and to DAPA-CKD and FLOW placebo eGFR slopes at the trials' baseline eGFR and UACR",
  egfr_uacr_beta = "KFRE log(UACR) coefficient; varied in the PSA",
  egfr_slope_sdlog = "Calibrated jointly with the reference decline; varied in the PSA",
  egfr_mult_3b = "Calibrated (1: no change in decline rate at eGFR 30-44)",
  egfr_mult_4 = "Calibrated: decline rate below eGFR 30 relative to eGFR >= 45; range 1 (one rate) to 1.5",
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
  stop_glp1_at_kf = "Scenario: GLP-1 RA stopped at dialysis start (FLOW excluded dialysis)",
  addon_glp1 = "Scenario: GLP-1 RA added at 1 year in the SGLT2i arm with type 2 diabetes and persistent albuminuria (2026 guideline)",
  addon_glp1_uacr = "2026 guideline: UACR >= 100 mg/g on first-line therapy is an indication for GLP-1 RA in type 2 diabetes",
  sglt2i_uacr_reduction = "DAPA-CKD: UACR -35.1% with type 2 diabetes (Jongs et al. Lancet Diabetes Endocrinol 2021)",
  glp1_flow_dm = "Scenario: GLP-1 RA effects from FLOW in patients with type 2 diabetes",
  hr_flow_mace = "FLOW (Perkovic 2024): MACE HR 0.82 (0.68-0.98)",
  hr_flow_hf = "FLOW (Pratley 2024): HF events HR 0.73 (0.58-0.92)",
  hr_flow_cv_death = "FLOW (Perkovic 2024): CV death HR 0.71 (0.56-0.89)",
  flow_egfr_slope_ratio = "FLOW: total eGFR slope -2.19 vs -3.36 mL/min/1.73 m2 per year (ratio 0.65)",
  dialysis_egfr = "Base 15 (kidney failure); scenario 10: mean eGFR 9.9 at dialysis start, USRDS 2023 ADR (2021 data)",
  dialysis_forgo = "Scenario: decision not to start dialysis rising linearly with age from 3.8% (<45 y) to 46.7% (>=85 y) (Wong et al. CJASN 2016)",
  prevent_full = "PREVENT full model (Khan et al. 2024; preventr), social deprivation index missing; HbA1c model in a scenario",
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
