# ==============================================================================
# File: 01_parameters.R
# Purpose: Master parameter file for CKM-HEOR using WARDEN
# Author: CKM-HEOR Team
# Date: 2026-11-09 (revised — sourced 2025 costs, GLP-1 RA price by diabetes,
#       PREVENT full model, R3 scenario switches)
# ==============================================================================
# WARDEN's input_block() expects parallel lists:
#   base           = list(val1, val2, ...)
#   psa            = pick_psa(dist_list, n_list, a_list, b_list)
#   sens           = list(DSA_min = list(...), DSA_max = list(...))
#   names_out      = list("name1", "name2", ...)
#   psa_indicators = list(1, 0, ...)   # 0 = fixed at base value in PSA
#   sens_indicators = list(1, 0, ...)  # 0 = not varied in DSA
#
# run_ckm_model() (08_run_model.R) injects these lists into input_block().
# ==============================================================================

#' Build the parallel-list parameter structure for WARDEN input_block()
#'
#' @return Named list with: parameter_name, base_value, PSA_dist, a, b, n,
#'   psa_indicators, dsa_indicators, DSA_min, DSA_max — each a list of length
#'   n_params.
build_param_lists <- function() {

  # Row format: name, base, PSA dist, a, b, DSA min, DSA max[, psa = 1, dsa = 1]
  # HRs / ratios / multipliers use lognormal (rlnorm): a = log(mean), b = SE on log scale
  # Costs and positive rates use gamma (rgamma_mse): a = mean, b = SE
  # Utilities/probs use beta (rbeta_mse): a = mean, b = SE
  # Drifts use normal (rnorm): a = mean, b = SD
  se_log <- function(lo, hi) (log(hi) - log(lo)) / 3.92

  params <- list(
    # ---- Treatment Effects: SGLT2i (Class-level HRs vs placebo) ----
    # Source: McGuire et al. JAMA Cardiol 2021 meta-analysis
    list("hr_sglt2i_mace",     0.90, "rlnorm", log(0.90), se_log(0.85, 0.95), 0.85, 0.95),
    # Source: McGuire et al. 2021; Zannad et al. Lancet 2020
    list("hr_sglt2i_hf",       0.68, "rlnorm", log(0.68), se_log(0.61, 0.76), 0.61, 0.76),
    # Source: McGuire et al. JAMA Cardiol 2021 (CV death HR 0.85, 0.78-0.93)
    list("hr_sglt2i_cv_death", 0.85, "rlnorm", log(0.85), se_log(0.78, 0.93), 0.78, 0.93),
    # Ratio of on-treatment to SoC chronic eGFR decline. Calibrated to kidney disease
    # progression RR 0.63 (0.58-0.69), SMART-C, Lancet 2022 (time to an eGFR
    # threshold scales with 1/slope, so slope ratio ~ progression HR)
    list("sglt2i_egfr_slope_ratio", 0.63, "rlnorm", log(0.63), se_log(0.58, 0.69), 0.58, 0.69),

    # ---- Treatment Effects: GLP-1 RA (Class-level HRs vs placebo) ----
    # Source: Sattar et al. Lancet Diabetes Endocrinol 2021
    list("hr_glp1_mace",       0.86, "rlnorm", log(0.86), se_log(0.80, 0.93), 0.80, 0.93),
    # Source: Sattar et al. 2021 (HF hospitalisation HR 0.89, 0.82-0.98)
    list("hr_glp1_hf",         0.89, "rlnorm", log(0.89), se_log(0.82, 0.98), 0.82, 0.98),
    # Source: Sattar et al. 2021 (CV death HR 0.87, 0.80-0.94)
    list("hr_glp1_cv_death",   0.87, "rlnorm", log(0.87), se_log(0.80, 0.94), 0.80, 0.94),
    # Composite kidney outcome HR 0.81 (0.72-0.92), Badve et al. Lancet Diabetes
    # Endocrinol 2025;13:15-28 (11 trials incl. FLOW and SELECT); same method as SGLT2i
    list("glp1_egfr_slope_ratio", 0.81, "rlnorm", log(0.81), se_log(0.72, 0.92), 0.72, 0.92),

    # ---- Costs (2025 USD; drug prices 2025-2027) ----
    # Drug prices depend on the payer, which depends on age: commercial net price
    # before age_medicare, Medicare negotiated price (maximum fair price, MFP) from
    # age_medicare. Drug cost is linear in each price, so price scenarios are
    # computed exactly from the drug cost accrued in each payer period (09_results.R).
    # SGLT2i commercial: brand acquisition cost without rebate, mean of empagliflozin
    # ($11.19/tablet) and dapagliflozin ($12.08/tablet), CMS NADAC 21 Oct 2026 =
    # $4,250/y; range = 30% rebate ($2,972) to 2025 WAC (~$6,500; 2026 CKM guideline)
    list("cost_sglt2i",        4250, "rgamma_mse",  4250,      (6500-2972)/3.92,            2972, 6500),
    # GLP-1 RA commercial: semaglutide net price $6,829/y (SSR Health, ICER obesity
    # final report, 16 Dec 2025; Wegovy-based), applied without type 2 diabetes;
    # range = self-pay price $349/mo to 2027 list price $675/mo (Novo Nordisk,
    # effective 1 Jan 2027)
    list("cost_glp1ra",        6830, "rgamma_mse",  6830,      (8100-4188)/3.92,            4188, 8100),
    # With type 2 diabetes the commercial price is the semaglutide net price x the
    # Ozempic/Wegovy list-price ratio (1,028/1,349 = 0.762; $5,205/y). DSA range =
    # Ozempic self-pay price ($349/mo, ratio 0.613) to the Wegovy-based net price (1).
    # Moves with cost_glp1ra in the PSA
    list("glp1_dm_price_ratio", 1028/1349, "rnorm", 1028/1349, 0,                          4188/6830, 1, 0, 1),
    # Medicare: empagliflozin MFP $197 per 30 days (2026) = $2,397/y; DSA range
    # dapagliflozin MFP $178.50/30 d ($2,172/y) to +10%. Statutory: fixed in PSA
    list("cost_sglt2i_mcr",    2397, "rnorm",       2397,      0,                           2172, 2637, 0, 1),
    # Medicare: semaglutide MFP $274 per 30 days (from 1 Jan 2027) = $3,334/y; DSA
    # range $245/mo GLP-1 Bridge price ($2,940/y) to +10%. Fixed in PSA
    list("cost_glp1ra_mcr",    3334, "rnorm",       3334,      0,                           2940, 3667, 0, 1),
    # Non-drug costs: source value x PCE health care price index (BEA; FRED
    # DHLCRG3A086NBEA, 2025 = 120.920; 2022 = 112.045, 2019 = 103.688, 2012 = 94.485).
    # SE = 18% and DSA = +/-20% of the base value unless stated.
    # Assumption: generic statin, ACE inhibitor/ARB, monitoring
    list("cost_soc",           1200, "rgamma_mse",  1200,      240,                         960,  1440),
    # HCUP Statistical Brief #316 (2022 NIS, all payers, Table 1): aggregate hospital
    # cost / stays. AMI $16,332 million / 582,000 = $28,062 (2022 USD)
    list("cost_mi_acute",     30285, "rgamma_mse", 30285,      5451,                       24228, 36342),
    # Cerebral infarction $10,940 million / 542,000 = $20,185 (2022 USD)
    list("cost_stroke_acute", 21784, "rgamma_mse", 21784,      3921,                       17427, 26141),
    # Heart failure $18,236 million / 1,098,000 = $16,608 (2022 USD)
    list("cost_hf_hosp",      17924, "rgamma_mse", 17924,      3226,                       14339, 21509),
    # Ward et al. J Med Econ 2014 annual state costs after the event year (2012 USD):
    # MI $1,904, ischemic stroke $15,541, congestive HF $1,904
    list("cost_mi_post",       2437, "rgamma_mse",  2437,      439,                         1950, 2924),
    list("cost_stroke_post",  19889, "rgamma_mse", 19889,      3580,                       15911, 23867),
    list("cost_hf_post",       2437, "rgamma_mse",  2437,      439,                         1950, 2924),
    # Added annual cost by CKD stage (Tisdale et al. J Gen Intern Med 2022, from
    # Erickson et al. 2013; 2019 USD): 3a $196/mo, 3b $482/mo, 4 $625/mo (also kidney
    # failure without kidney replacement therapy)
    list("cost_ckd3a_annual",  2743, "rgamma_mse",  2743,      494,                         2194, 3292),
    list("cost_ckd3b_annual",  6745, "rgamma_mse",  6745,      1214,                        5396, 8094),
    list("cost_ckd4_annual",   8746, "rgamma_mse",  8746,      1574,                        6997, 10495),
    # Dialysis: USRDS 2024 ADR, Medicare FFS spending per person-year, in-center
    # hemodialysis, $99,369 (2022 USD); replaces the CKD 4 cost
    list("cost_eskd_annual", 107240, "rgamma_mse", 107240,     19303,                      85792, 128688),
    # Background spending: MEPS 2022 mean expenditure per person, $8,406 at 45-64 y
    # and $13,524 at >=65 y, linear between ages 54.5 and 75 (2022 USD: $7,282 at
    # 50 y, $249.7 per year of age)
    list("cost_bg_base",       7859, "rgamma_mse",  7859,      1415,                        6287, 9431),
    # Added each year of age above 50, updated annually
    list("cost_bg_age_coef",    269.4, "rgamma_mse", 269.4,    48.5,                        215.5, 323.3),

    # ---- Utilities ----
    # Source: Sullivan et al. 2011 US norms
    list("util_baseline",       0.84, "rbeta_mse",  0.84,      0.02,                        0.80, 0.88),
    # Source: Published utility studies (decrements coded as positive values)
    list("util_dec_mi_acute",   0.06, "rbeta_mse",  0.06,      0.01,                        0.048, 0.072),
    list("util_dec_mi_chronic", 0.04, "rbeta_mse",  0.04,      0.01,                        0.032, 0.048),
    list("util_dec_stroke_acute", 0.15, "rbeta_mse", 0.15,     0.03,                        0.12,  0.18),
    list("util_dec_stroke_chronic", 0.07, "rbeta_mse", 0.07,   0.02,                        0.056, 0.084),
    list("util_dec_hf",         0.10, "rbeta_mse",  0.10,      0.02,                        0.08,  0.12),
    list("util_dec_ckd3",       0.02, "rbeta_mse",  0.02,      0.01,                        0.016, 0.024),
    list("util_dec_ckd4",       0.05, "rbeta_mse",  0.05,      0.01,                        0.04,  0.06),
    # Applied on top of the CKD 4 decrement while on dialysis (dialysis utility
    # ~0.56-0.58, Wyld et al. 2012)
    list("util_dec_eskd",       0.20, "rbeta_mse",  0.20,      0.04,                        0.16,  0.24),

    # ---- Treatment Discontinuation ----
    # Source: Real-world evidence
    list("prob_disc_sglt2i",    0.10, "rbeta_mse",  0.10,      0.02,                        0.08, 0.12),
    # Source: Real-world evidence
    list("prob_disc_glp1",      0.15, "rbeta_mse",  0.15,      0.03,                        0.12, 0.18),
    # Years over which the treatment effect wanes to zero after discontinuation
    # (0 = immediate loss). Structural assumption: DSA only.
    list("tx_wane_years",       1.0,  "rnorm",      1.0,       0,                           0,    2.0,  0, 1),

    # ---- Natural history: chronic eGFR decline (SoC) ----
    # Patient slope = egfr_decline_ref x (UACR/30)^egfr_uacr_beta x exp(sd*Z - sd^2/2),
    # x egfr_mult_4 below eGFR 30 (egfr_mult_3b at 30-44 fitted as 1).
    # Calibrated (scripts/calibrate_kidney.R) to death-free 2- and 5-year kidney
    # failure by eGFR band in eGFR < 60 (4-variable North American KFRE; Tangri 2016)
    # and to placebo eGFR slopes in populations with the DAPA-CKD and FLOW baseline
    # eGFR and UACR (3.83 and 3.36 mL/min/1.73 m2 per year): KFRE all bands within
    # 20% except 5-year risk at eGFR 45-59 (+75%); trial slopes -15% and -19%.
    # No single parameter set matched both target sets (equal-weight least squares).
    list("egfr_decline_ref",    0.608, "rgamma_mse", 0.608,    0.075,                       0.468, 0.748),
    # KFRE log(UACR) coefficient (time to threshold ~ 1/slope, so HR ~ slope ratio)
    # Both varied in the PSA (normal, SD = DSA range / 3.92)
    list("egfr_uacr_beta",      0.451, "rnorm",     0.451,     (0.55-0.35)/3.92,            0.35, 0.55),
    list("egfr_slope_sdlog",    1.29, "rnorm",      1.29,      (1.59-0.99)/3.92,            0.99, 1.59),
    # Decline-rate multipliers at eGFR 30-44 (fitted 1; fixed) and < 30 (fitted 1.25;
    # range 1 = one rate at every eGFR, to 1.5)
    list("egfr_mult_3b",        1,    "rnorm",      1,         0,                           1,    1,    0, 0),
    list("egfr_mult_4",         1.25, "rnorm",      1.25,      (1.5-1.0)/3.92,              1.0,  1.5),

    # ---- Natural history: biomarker drift (applied equally to all arms) ----
    # SBP rise with age (mmHg/yr); HbA1c drift in diabetes (%/yr, UKPDS-type drift)
    list("sbp_drift",           0.5,  "rnorm",      0.5,       0.15,                        0.0,  1.0),
    list("hba1c_drift_dm",      0.1,  "rnorm",      0.1,       0.03,                        0.0,  0.2),

    # ---- Recurrent event hazard multipliers (per prior event, compounding) ----
    # Structural assumptions; wide uncertainty
    list("rr_recur_mi",         1.5,  "rlnorm", log(1.5),  se_log(1.2, 1.8),               1.2,  1.8),
    list("rr_recur_stroke",     1.3,  "rlnorm", log(1.3),  se_log(1.1, 1.5),               1.1,  1.5),
    list("rr_recur_hf",         2.0,  "rlnorm", log(2.0),  se_log(1.5, 2.5),               1.5,  2.5),

    # ---- CV mortality multipliers (prior events, CKD stage) ----
    list("cvd_mult_mi",         2.0,  "rlnorm", log(2.0),  se_log(1.5, 2.5),               1.5,  2.5),
    list("cvd_mult_stroke",     2.5,  "rlnorm", log(2.5),  se_log(2.0, 3.0),               2.0,  3.0),
    list("cvd_mult_hf",         3.0,  "rlnorm", log(3.0),  se_log(2.0, 4.0),               2.0,  4.0),
    list("cvd_mult_ckd3",       1.5,  "rlnorm", log(1.5),  se_log(1.2, 1.8),               1.2,  1.8),
    list("cvd_mult_ckd4",       2.5,  "rlnorm", log(2.5),  se_log(2.0, 3.0),               2.0,  3.0),
    list("cvd_mult_eskd",       4.0,  "rlnorm", log(4.0),  se_log(3.0, 5.0),               3.0,  5.0),

    # ---- Discount rates (DSA only) ----
    list("drc",                 0.03, "rnorm",      0.03,      0,                           0.0,  0.05, 0, 1),
    list("drq",                 0.03, "rnorm",      0.03,      0,                           0.0,  0.05, 0, 1),

    # ---- Time horizon (years from model entry; 100 = lifetime). Scenarios only ----
    list("horizon_years",       100,  "rnorm",      100,       0,                           100,  100,  0, 0),

    # ---- Structural settings (fixed; changed only in scenarios) ----
    # Age at which drug prices switch from commercial to Medicare
    list("age_medicare",        65,   "rnorm",      65,        0,                           65,   65,   0, 0),
    # SGLT2i stopped at kidney failure (KDIGO 2024: continue until dialysis or
    # transplant); 0 = continued for life
    list("stop_sglt2i_at_kf",   1,    "rnorm",      1,         0,                           1,    1,    0, 0),
    # GLP-1 RA stopped at kidney failure (dialysis start); 0 = continued for life
    list("stop_glp1_at_kf",     0,    "rnorm",      0,         0,                           0,    0,    0, 0),
    # 1 = SoC and GLP-1 RA arms start an SGLT2i at the first HF hospitalization or
    # at CKD stage 4 (guideline class 1 indications)
    list("addon_sglt2i",        0,    "rnorm",      0,         0,                           0,    0,    0, 0),
    # 1 = SGLT2i arm adds a GLP-1 RA at 1 year in type 2 diabetes with persistent
    # albuminuria: baseline UACR x (1 - SGLT2i UACR reduction) >= addon_glp1_uacr
    # (guideline: UACR >= 100 mg/g on first-line therapy; DAPA-CKD UACR -35.1% with
    # type 2 diabetes, Jongs et al. Lancet Diabetes Endocrinol 2021)
    list("addon_glp1",          0,    "rnorm",      0,         0,                           0,    0,    0, 0),
    list("addon_glp1_uacr",     100,  "rnorm",      100,       0,                           100,  100,  0, 0),
    list("sglt2i_uacr_reduction", 0.351, "rnorm",   0.351,     0,                           0.351, 0.351, 0, 0),
    # 1 = GLP-1 RA effects from FLOW in patients with type 2 diabetes (class effects
    # without diabetes): MACE 0.82, HF events 0.73, CV death 0.71 (Perkovic 2024;
    # Pratley 2024); total eGFR slope ratio 2.19/3.36 = 0.65
    list("glp1_flow_dm",        0,    "rnorm",      0,         0,                           0,    0,    0, 0),
    list("hr_flow_mace",        0.82, "rnorm",      0.82,      0,                           0.82, 0.82, 0, 0),
    list("hr_flow_hf",          0.73, "rnorm",      0.73,      0,                           0.73, 0.73, 0, 0),
    list("hr_flow_cv_death",    0.71, "rnorm",      0.71,      0,                           0.71, 0.71, 0, 0),
    list("flow_egfr_slope_ratio", 0.65, "rnorm",    0.65,      0,                           0.65, 0.65, 0, 0),
    # Kidney failure = eGFR < 15 (CV mortality multiplier, kidney failure count).
    # Dialysis (cost, utility, drug stops) starts at dialysis_egfr; 10 = mean eGFR at
    # dialysis start in the US (9.9 mL/min/1.73 m2, USRDS 2023 ADR, 2021 data).
    # Before dialysis, kidney failure costs the CKD 4 amount
    list("dialysis_egfr",       15,   "rnorm",      15,        0,                           15,   15,   0, 0),
    # 1 = age-dependent decision not to start dialysis (p_forgo_dialysis(); Wong et
    # al. CJASN 2016); conservative care costs the CKD 4 amount, drugs continue
    list("dialysis_forgo",      0,    "rnorm",      0,         0,                           0,    0,    0, 0),
    # Multiplier on background mortality: 1 = noncardiovascular Gompertz hazard plus
    # a CV death hazard of 0.3/0.7 of it; 0.7 = the Gompertz hazard read as all-cause
    # mortality and split 70% noncardiovascular / 30% cardiovascular
    list("bg_mort_mult",        1,    "rnorm",      1,         0,                           1,    1,    0, 0),
    # 1 = kidney (eGFR slope) effects only in patients with UACR >= 30 mg/g or eGFR < 60
    list("kidney_effect_restrict", 0, "rnorm",      0,         0,                           0,    0,    0, 0),
    # Share of PREVENT incident HF that is a hospitalization (1 = all)
    list("hf_hosp_frac",        1,    "rnorm",      1,         0,                           1,    1,    0, 0),
    # Utility gain while on treatment (weight-related quality of life); 0 in base case
    list("util_gain_sglt2i",    0,    "rnorm",      0,         0,                           0,    0,    0, 0),
    list("util_gain_glp1",      0,    "rnorm",      0,         0,                           0,    0,    0, 0),
    # Age used in the PREVENT equations is capped at this value (999 = no cap)
    list("prevent_age_cap",     999,  "rnorm",      999,       0,                           999,  999,  0, 0),
    # 1 = standard of care optimized at entry: SBP lowered to <=130 mm Hg on
    # antihypertensives and every patient on a statin (total cholesterol -25% if new)
    list("soc_optimized",       0,    "rnorm",      0,         0,                           0,    0,    0, 0),
    # PREVENT model for MI, stroke and HF hazards: 1 = full model (UACR, HbA1c; SDI
    # missing), 0 = HbA1c model
    list("prevent_full",        1,    "rnorm",      1,         0,                           1,    1,    0, 0),
    # Correlation between the PSA draws of log HRs for MACE, HF hospitalization, and
    # CV death within each class (applied only in the PSA)
    list("psa_hr_rho",          0.5,  "rnorm",      0.5,       0,                           0.5,  0.5,  0, 0)
  )

  opt <- function(row, k, default) if (length(row) >= k) row[[k]] else default

  # Transpose into parallel lists
  l_params <- list(
    parameter_name = lapply(params, `[[`, 1),
    base_value     = lapply(params, `[[`, 2),
    PSA_dist       = lapply(params, `[[`, 3),
    a              = lapply(params, `[[`, 4),
    b              = lapply(params, `[[`, 5),
    n              = as.list(rep(1, length(params))),
    psa_indicators = lapply(params, opt, k = 8, default = 1),
    dsa_indicators = lapply(params, opt, k = 9, default = 1),
    DSA_min        = lapply(params, `[[`, 6),
    DSA_max        = lapply(params, `[[`, 7)
  )

  return(l_params)
}

# ---- Section: Drug-specific scenario inputs ----
# One row per drug x input. est/lo/hi are point estimates and 95% CIs (HRs,
# ratios) or base value and DSA range (annual prices: cost = commercial net price,
# cost_mcr = Medicare price; 2025-2027 USD).
# HRs are from each drug's own placebo-controlled outcome trial in a population
# without established HF (to match CKM Stages 2-4a).
# Per Decision D-015, the trial composite renal outcome HR is used as a surrogate
# proxy for the relative attenuation of the chronic eGFR decline slope.
DRUG_SPECIFIC_INPUTS <- data.frame(
  drug  = rep(c("empagliflozin", "dapagliflozin", "canagliflozin", "sotagliflozin",
                "semaglutide", "liraglutide", "dulaglutide", "tirzepatide"), each = 6),
  class = rep(c("sglt2i", "sglt2i", "sglt2i", "sglt2i",
                "glp1ra", "glp1ra", "glp1ra", "glp1ra"), each = 6),
  input = rep(c("mace", "hf", "cv_death", "egfr_slope_ratio", "cost", "cost_mcr"), times = 8),
  est = c(
    0.86, 0.65, 0.62, 0.71, 4084, 2397,  # empagliflozin
    0.93, 0.73, 0.98, 0.56, 67, 67,  # dapagliflozin
    0.86, 0.61, 0.78, 0.70, 4000, 4000,  # canagliflozin
    0.84, 0.66, 0.90, 0.71, 4800, 4800,  # sotagliflozin
    0.82, 0.73, 0.71, 0.76, 6830, 3334,  # semaglutide
    0.87, 0.87, 0.78, 0.89, 3196, 3196,  # liraglutide
    0.88, 0.93, 0.91, 0.85, 6690, 6690,  # dulaglutide
    0.81, 0.67, 0.90, 0.58, 7973, 7973  # tirzepatide
  ),
  lo  = c(
    0.74, 0.50, 0.49, 0.62, 2397, 2172,  # empagliflozin
    0.84, 0.61, 0.82, 0.45, 67, 67,  # dapagliflozin
    0.75, 0.47, 0.61, 0.59, 1800, 1800,  # canagliflozin
    0.72, 0.53, 0.73, 0.46, 2400, 2400,  # sotagliflozin
    0.68, 0.58, 0.56, 0.66, 4188, 2940,  # semaglutide
    0.78, 0.73, 0.66, 0.67, 3196, 3196,  # liraglutide
    0.79, 0.77, 0.78, 0.77, 4500, 4500,  # dulaglutide
    0.70, 0.26, 0.50, 0.43, 4188, 4188  # tirzepatide
  ),
  hi  = c(
    0.99, 0.85, 0.77, 0.81, 6500, 2637,  # empagliflozin
    1.03, 0.88, 1.17, 0.68, 4408, 2172,  # dapagliflozin
    0.97, 0.80, 1.00, 0.82, 6500, 6500,  # canagliflozin
    0.99, 0.82, 1.12, 1.08, 7500, 7500,  # sotagliflozin
    0.98, 0.92, 0.89, 0.88, 8100, 3667,  # semaglutide
    0.97, 1.05, 0.93, 1.19, 9609, 9609,  # liraglutide
    0.99, 1.12, 1.06, 0.93, 12710, 12710,  # dulaglutide
    0.94, 1.70, 1.61, 0.80, 14040, 14040  # tirzepatide
  ),
  source = c(
    "EMPA-REG OUTCOME (Zinman 2015) 3P-MACE", "EMPA-REG OUTCOME (Fitchett 2016) HHF", "EMPA-REG OUTCOME CV death", "EMPA-KIDNEY (Herrington 2023) kidney progression HR (slope ratio proxy)", "Brand acquisition cost without rebate, CMS NADAC Oct 2026 ($11.19/tablet); range = Medicare MFP to WAC", "Medicare: empagliflozin MFP $197/30 d (2026)",
    "DECLARE-TIMI 58 (Wiviott 2019) 3P-MACE", "DECLARE-TIMI 58 HHF", "DECLARE-TIMI 58 CV death", "DAPA-CKD (Heerspink 2020) composite renal HR (slope ratio proxy)", "Generic dapagliflozin acquisition cost, CMS NADAC Oct 2026 ($0.18/tablet); range up to brand NADAC", "Generic dapagliflozin (Medicare); range up to MFP $178.50/30 d",
    "CANVAS Program (Neal 2017) 3P-MACE; CREDENCE MACE HR 0.80", "CREDENCE (Perkovic 2019) HHF; CANVAS HHF HR 0.67", "CREDENCE CV death; CANVAS CV death HR 0.87", "CREDENCE (Perkovic 2019) primary composite renal HR (slope ratio proxy)", "Net price under generic competition; range = generic parity to WAC", "Medicare: no negotiated price; commercial net price assumed",
    "SCORED (Bhatt 2021) coprimary 3P-MACE in CKD+T2D", "SCORED (Bhatt 2021) HHF; urgent HF visit or HHF HR 0.67", "SCORED CV death", "SCORED (Bhatt 2021) renal composite HR (slope ratio proxy)", "Inpefa net commercial price post-rebate; range = negotiated discount to WAC", "Medicare: no negotiated price; commercial net price assumed",
    "FLOW (Perkovic 2024) 3P-MACE in T2D and CKD", "FLOW HF events (Pratley 2024)", "FLOW CV death", "FLOW (Perkovic 2024) primary composite kidney HR (slope ratio proxy)", "Semaglutide net price $6,829/y (SSR Health; ICER obesity final report 2025); range = self-pay $349/mo to 2027 list price $675/mo", "Medicare: semaglutide MFP $274/30 d (2027)",
    "LEADER (Marso 2016) 3P-MACE", "LEADER HHF", "LEADER CV death", "LEADER renal (Mann 2017) persistent doubling of serum creatinine (slope ratio proxy)", "Generic liraglutide 1.8 mg/d acquisition cost, CMS NADAC Oct 2026 ($29.19/mL); range up to brand NADAC", "Generic liraglutide (Medicare)",
    "REWIND (Gerstein 2019) 3P-MACE (68.5% primary prevention / Stage 3)", "REWIND (Gerstein 2019) adjudicated HHF", "REWIND CV death", "REWIND renal analysis (Gerstein, Lancet 2019) composite renal outcome HR (slope ratio proxy)", "Trulicity NADAC Oct 2026 ($12,710/y) x semaglutide net-to-NADAC ratio (0.53); range up to NADAC", "Medicare: no negotiated price; commercial net price assumed",
    "SURPASS-CVOT (Nicholls 2025) MACE vs dulaglutide 0.92 x REWIND dulaglutide vs placebo 0.88 (indirect)", "SURPASS CV meta-analysis (Sattar 2022) adjudicated HHF; SUMMIT HFpEF HR 0.62", "SURPASS CV meta-analysis (Sattar 2022) CV death", "SURPASS-4 kidney (Heerspink 2022) composite kidney HR (slope ratio proxy)", "Tirzepatide net price $7,973/y (SSR Health; ICER obesity final report 2025); range = self-pay to Mounjaro NADAC", "Medicare: no negotiated price; commercial net price assumed"
  ),
  stringsAsFactors = FALSE
)

#' Build a parameter list for a head-to-head drug-specific scenario
#'
#' @description Replaces the class-level SGLT2i and GLP-1 RA inputs (HRs, kidney
#'   slope ratio, drug cost) with drug-specific values. The arms keep their
#'   class names ("sglt2i", "glp1ra"); all other parameters are unchanged.
#'   PSA distributions and DSA ranges are updated consistently.
#'
#' @param sglt2i_drug One of "empagliflozin", "dapagliflozin", "canagliflozin", "sotagliflozin"
#' @param glp1_drug One of "semaglutide", "liraglutide", "dulaglutide", "tirzepatide"
#' @param params Base parameter lists (default: class-level)
#' @return Modified parameter lists, same structure as build_param_lists()
build_drug_specific_params <- function(sglt2i_drug = "empagliflozin",
                                       glp1_drug = "semaglutide",
                                       params = build_param_lists()) {
  target_names <- list(
    sglt2i = c(mace = "hr_sglt2i_mace", hf = "hr_sglt2i_hf", cv_death = "hr_sglt2i_cv_death",
               egfr_slope_ratio = "sglt2i_egfr_slope_ratio", cost = "cost_sglt2i",
               cost_mcr = "cost_sglt2i_mcr"),
    glp1ra = c(mace = "hr_glp1_mace", hf = "hr_glp1_hf", cv_death = "hr_glp1_cv_death",
               egfr_slope_ratio = "glp1_egfr_slope_ratio", cost = "cost_glp1ra",
               cost_mcr = "cost_glp1ra_mcr")
  )
  pnames <- unlist(params$parameter_name)

  for (drug in c(sglt2i_drug, glp1_drug)) {
    rows <- DRUG_SPECIFIC_INPUTS[DRUG_SPECIFIC_INPUTS$drug == drug, ]
    if (nrow(rows) == 0) stop("Unknown drug: ", drug)
    cls <- rows$class[1]
    for (r in seq_len(nrow(rows))) {
      k <- match(target_names[[cls]][[rows$input[r]]], pnames)
      est <- rows$est[r]; lo <- rows$lo[r]; hi <- rows$hi[r]
      params$base_value[[k]] <- est
      params$DSA_min[[k]]    <- lo
      params$DSA_max[[k]]    <- hi
      if (rows$input[r] %in% c("cost", "cost_mcr")) {
        params$a[[k]] <- est
        params$b[[k]] <- (hi - lo) / 3.92
      } else {
        params$a[[k]] <- log(est)
        params$b[[k]] <- (log(hi) - log(lo)) / 3.92
      }
    }
  }
  # The Ozempic/Wegovy price ratio applies to semaglutide only
  if (glp1_drug != "semaglutide") {
    k <- match("glp1_dm_price_ratio", pnames)
    params$base_value[[k]] <- 1; params$a[[k]] <- 1; params$DSA_min[[k]] <- 1; params$DSA_max[[k]] <- 1
  }
  attr(params, "scenario") <- paste(sglt2i_drug, "vs", glp1_drug)
  params
}

#' Override base values of named parameters (e.g. discount-rate scenarios)
#'
#' @param params Parameter lists
#' @param values Named list of new base values
#' @return Modified parameter lists (PSA means for normal/gamma/beta inputs and
#'   log-means for lognormal inputs are moved to the new value as well)
set_param_values <- function(params, values) {
  pnames <- unlist(params$parameter_name)
  for (nm in names(values)) {
    k <- match(nm, pnames)
    if (is.na(k)) stop("Unknown parameter: ", nm)
    params$base_value[[k]] <- values[[nm]]
    params$a[[k]] <- if (params$PSA_dist[[k]] == "rlnorm") log(values[[nm]]) else values[[nm]]
  }
  params
}

# Build global parameter lists (sourced once at startup)
l_params <- build_param_lists()
