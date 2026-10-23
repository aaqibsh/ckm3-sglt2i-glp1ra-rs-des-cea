# ==============================================================================
# File: 01_parameters.R
# Purpose: Master parameter file for CKM-HEOR using WARDEN
# Author: CKM-HEOR Team
# Date: 2026-10-14 (revised — class HRs corrected to source meta-analyses,
#       time-horizon parameter)
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

    # ---- Costs (2025 USD) ----
    # Drug prices depend on the payer, which depends on age: commercial net price
    # before age_medicare, Medicare negotiated price (maximum fair price, MFP) from
    # age_medicare. Drug cost is linear in each price, so price scenarios are
    # computed exactly from the drug cost accrued in each payer period (09_results.R).
    # SGLT2i commercial: brand acquisition cost without rebate, mean of empagliflozin
    # ($11.19/tablet) and dapagliflozin ($12.08/tablet), CMS NADAC 21 Oct 2026 =
    # $4,250/y; range = 30% rebate ($2,972) to 2025 WAC (~$6,500; 2026 CKM guideline)
    list("cost_sglt2i",        4250, "rgamma_mse",  4250,      (6500-2972)/3.92,            2972, 6500),
    # GLP-1 RA commercial: semaglutide net price $6,829/y (SSR Health, ICER obesity
    # final report, 16 Dec 2025); range = self-pay price $349/mo to 2027 list price
    # $675/mo (Novo Nordisk, effective 1 Jan 2027)
    list("cost_glp1ra",        6830, "rgamma_mse",  6830,      (8100-4188)/3.92,            4188, 8100),
    # Medicare: empagliflozin MFP $197 per 30 days (2026) = $2,397/y; DSA range
    # dapagliflozin MFP $178.50/30 d ($2,172/y) to +10%. Statutory: fixed in PSA
    list("cost_sglt2i_mcr",    2397, "rnorm",       2397,      0,                           2172, 2637, 0, 1),
    # Medicare: semaglutide MFP $274 per 30 days (from 1 Jan 2027) = $3,334/y; DSA
    # range $245/mo GLP-1 Bridge price ($2,940/y) to +10%. Fixed in PSA
    list("cost_glp1ra_mcr",    3334, "rnorm",       3334,      0,                           2940, 3667, 0, 1),
    # Source: Generic statins, ACEi/ARB
    list("cost_soc",           1200, "rgamma_mse",  1200,      240,                         960,  1440),
    # Source: HCUP NIS
    list("cost_mi_acute",     28000, "rgamma_mse", 28000,      5000,                       22400, 33600),
    # Source: HCUP NIS
    list("cost_stroke_acute", 25000, "rgamma_mse", 25000,      4500,                       20000, 30000),
    # Source: HCUP NIS
    list("cost_hf_hosp",      16500, "rgamma_mse", 16500,      3000,                       13200, 19800),
    # Source: Published literature
    list("cost_mi_post",       3200, "rgamma_mse",  3200,      600,                         2560, 3840),
    # Source: Published literature
    list("cost_stroke_post",   8000, "rgamma_mse",  8000,      1500,                        6400, 9600),
    # Source: Published literature
    list("cost_hf_post",       5500, "rgamma_mse",  5500,      1000,                        4400, 6600),
    # Source: Published literature
    list("cost_ckd3_annual",   7500, "rgamma_mse",  7500,      1500,                        6000, 9000),
    # Source: Published literature
    list("cost_ckd4_annual",  15000, "rgamma_mse", 15000,      3000,                       12000, 18000),
    # Source: USRDS 2024 ADR (total per-patient ESKD spending; replaces CKD 4 cost)
    list("cost_eskd_annual",  92000, "rgamma_mse", 92000,      10000,                      73600, 110400),
    # Source: MEPS
    list("cost_bg_base",       6000, "rgamma_mse",  6000,      1200,                        4800, 7200),
    # Source: MEPS (added each year of age above 50, updated annually)
    list("cost_bg_age_coef",    150, "rgamma_mse",   150,      30,                          120,  180),

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
    # Applied on top of the CKD 4 decrement (dialysis utility ~0.56-0.58, Wyld et al. 2012)
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
    # Patient slope = egfr_decline_ref x (UACR/30)^egfr_uacr_beta x exp(sd*Z - sd^2/2).
    # egfr_decline_ref and egfr_slope_sdlog calibrated jointly so that the model's
    # death-free 2- and 5-year kidney failure risk in eGFR < 60 matches the KFRE
    # (4-variable, North American; Tangri 2016): 1.10% vs 1.12% and 4.16% vs 4.10%.
    # Implied mean slope 3.1 mL/min/yr at UACR 950 (DAPA-CKD placebo ~3.6).
    list("egfr_decline_ref",    0.65, "rgamma_mse", 0.65,      0.08,                        0.50, 0.80),
    # KFRE log(UACR) coefficient (time to threshold ~ 1/slope, so HR ~ slope ratio)
    # Both varied in the PSA (normal, SD = DSA range / 3.92)
    list("egfr_uacr_beta",      0.451, "rnorm",     0.451,     (0.55-0.35)/3.92,            0.35, 0.55),
    list("egfr_slope_sdlog",    1.5,  "rnorm",      1.5,       (1.8-1.2)/3.92,              1.2,  1.8),

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
    # 1 = SoC and GLP-1 RA arms start an SGLT2i at the first HF hospitalization or
    # at CKD stage 4 (guideline class 1 indications)
    list("addon_sglt2i",        0,    "rnorm",      0,         0,                           0,    0,    0, 0),
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
