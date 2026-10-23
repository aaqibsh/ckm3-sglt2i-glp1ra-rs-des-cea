# Parameter Sources — CKM-HEOR

Generated from `build_param_lists()` and `DRUG_SPECIFIC_INPUTS` in `R/01_parameters.R`. Regenerate after changing parameters.

## Model parameters (class-level base case)

| Parameter | Description | Base | PSA distribution | DSA range | One-way DSA | Source |
|:--|:--|--:|:--|:--|:--|:--|
| `hr_sglt2i_mace` | SGLT2i HR: MACE | 0.9 | Lognormal (log-mean -0.105, SE 0.028) | 0.85 – 0.95 | Yes | McGuire et al. JAMA Cardiol 2021 (6 SGLT2i outcome trials): MACE HR 0.90 (0.85-0.95) |
| `hr_sglt2i_hf` | SGLT2i HR: HF hospitalization | 0.68 | Lognormal (log-mean -0.386, SE 0.056) | 0.61 – 0.76 | Yes | McGuire et al. JAMA Cardiol 2021: HF hospitalization HR 0.68 (0.61-0.76) |
| `hr_sglt2i_cv_death` | SGLT2i HR: CV death | 0.85 | Lognormal (log-mean -0.163, SE 0.045) | 0.78 – 0.93 | Yes | McGuire et al. JAMA Cardiol 2021: CV death HR 0.85 (0.78-0.93) |
| `sglt2i_egfr_slope_ratio` | SGLT2i eGFR slope ratio | 0.63 | Lognormal (log-mean -0.462, SE 0.044) | 0.58 – 0.69 | Yes | SMART-C, Lancet 2022: kidney disease progression RR 0.63 (0.58-0.69), applied as slope ratio (time to an eGFR threshold scales with 1/slope) |
| `hr_glp1_mace` | GLP-1 RA HR: MACE | 0.86 | Lognormal (log-mean -0.151, SE 0.038) | 0.8 – 0.93 | Yes | Sattar et al. Lancet Diabetes Endocrinol 2021 (8 GLP-1 RA outcome trials): MACE HR 0.86 (0.80-0.93) |
| `hr_glp1_hf` | GLP-1 RA HR: HF hospitalization | 0.89 | Lognormal (log-mean -0.117, SE 0.045) | 0.82 – 0.98 | Yes | Sattar et al. 2021: HF hospitalization HR 0.89 (0.82-0.98) |
| `hr_glp1_cv_death` | GLP-1 RA HR: CV death | 0.87 | Lognormal (log-mean -0.139, SE 0.041) | 0.8 – 0.94 | Yes | Sattar et al. 2021: CV death HR 0.87 (0.80-0.94) |
| `glp1_egfr_slope_ratio` | GLP-1 RA eGFR slope ratio | 0.81 | Lognormal (log-mean -0.211, SE 0.063) | 0.72 – 0.92 | Yes | Badve et al. Lancet Diabetes Endocrinol 2025 (11 trials incl. FLOW, SELECT): composite kidney outcome HR 0.81 (0.72-0.92), applied as slope ratio |
| `cost_sglt2i` | SGLT2i annual price, commercial | 4,250 | Gamma (mean 4,250, SE 900) | 2,972 – 6,500 | Yes | Before age 65 (commercial): brand acquisition cost without rebate, mean of empagliflozin and dapagliflozin, CMS NADAC 21 Oct 2026; range 30% rebate to 2025 WAC |
| `cost_glp1ra` | GLP-1 RA annual price, commercial | 6,830 | Gamma (mean 6,830, SE 998) | 4,188 – 8,100 | Yes | Before age 65 (commercial): semaglutide net price $6,829/y (SSR Health; ICER obesity final report, Dec 2025); range self-pay $349/mo to 2027 list price $675/mo |
| `cost_sglt2i_mcr` | SGLT2i annual price, Medicare | 2,397 | Fixed | 2,172 – 2,637 | Yes | From age 65 (Medicare): empagliflozin maximum fair price $197 per 30 days (2026); range dapagliflozin MFP to +10% |
| `cost_glp1ra_mcr` | GLP-1 RA annual price, Medicare | 3,334 | Fixed | 2,940 – 3,667 | Yes | From age 65 (Medicare): semaglutide maximum fair price $274 per 30 days (2027); range $245/mo GLP-1 Bridge price to +10% |
| `cost_soc` | SoC annual cost | 1,200 | Gamma (mean 1,200, SE 240) | 960 – 1,440 | Yes | Assumption (generic statin and ACEi/ARB) |
| `cost_mi_acute` | MI acute cost | 28,000 | Gamma (mean 28,000, SE 5,000) | 22,400 – 33,600 | Yes | HCUP National Inpatient Sample |
| `cost_stroke_acute` | Stroke acute cost | 25,000 | Gamma (mean 25,000, SE 4,500) | 20,000 – 30,000 | Yes | HCUP National Inpatient Sample |
| `cost_hf_hosp` | HF hospitalization cost | 16,500 | Gamma (mean 16,500, SE 3,000) | 13,200 – 19,800 | Yes | HCUP National Inpatient Sample |
| `cost_mi_post` | Post-MI annual cost | 3,200 | Gamma (mean 3,200, SE 600) | 2,560 – 3,840 | Yes | Assumption |
| `cost_stroke_post` | Post-stroke annual cost | 8,000 | Gamma (mean 8,000, SE 1,500) | 6,400 – 9,600 | Yes | Assumption |
| `cost_hf_post` | Post-HF annual cost | 5,500 | Gamma (mean 5,500, SE 1,000) | 4,400 – 6,600 | Yes | Assumption |
| `cost_ckd3_annual` | CKD 3 annual cost | 7,500 | Gamma (mean 7,500, SE 1,500) | 6,000 – 9,000 | Yes | Assumption |
| `cost_ckd4_annual` | CKD 4 annual cost | 15,000 | Gamma (mean 15,000, SE 3,000) | 12,000 – 18,000 | Yes | Assumption |
| `cost_eskd_annual` | Kidney failure annual cost | 92,000 | Gamma (mean 92,000, SE 10,000) | 73,600 – 110,400 | Yes | USRDS 2024 Annual Data Report (total per-patient ESKD spending; replaces CKD 4 cost) |
| `cost_bg_base` | Background cost (base) | 6,000 | Gamma (mean 6,000, SE 1,200) | 4,800 – 7,200 | Yes | MEPS |
| `cost_bg_age_coef` | Background cost per year of age | 150 | Gamma (mean 150, SE 30) | 120 – 180 | Yes | MEPS (added per year of age above 50) |
| `util_baseline` | Baseline utility | 0.84 | Beta (mean 0.84, SE 0.02) | 0.8 – 0.88 | Yes | US population norms (Sullivan & Ghushchyan 2006) |
| `util_dec_mi_acute` | Disutility: MI (acute) | 0.06 | Beta (mean 0.06, SE 0.01) | 0.048 – 0.072 | Yes | Assumption (one-time QALY loss) |
| `util_dec_mi_chronic` | Disutility: MI (chronic) | 0.04 | Beta (mean 0.04, SE 0.01) | 0.032 – 0.048 | Yes | Assumption |
| `util_dec_stroke_acute` | Disutility: stroke (acute) | 0.15 | Beta (mean 0.15, SE 0.03) | 0.12 – 0.18 | Yes | Assumption (one-time QALY loss) |
| `util_dec_stroke_chronic` | Disutility: stroke (chronic) | 0.07 | Beta (mean 0.07, SE 0.02) | 0.056 – 0.084 | Yes | Assumption |
| `util_dec_hf` | Disutility: HF | 0.1 | Beta (mean 0.1, SE 0.02) | 0.08 – 0.12 | Yes | Assumption (one-time loss; half persists after the first HF hospitalization) |
| `util_dec_ckd3` | Disutility: CKD 3 | 0.02 | Beta (mean 0.02, SE 0.01) | 0.016 – 0.024 | Yes | Assumption |
| `util_dec_ckd4` | Disutility: CKD 4 | 0.05 | Beta (mean 0.05, SE 0.01) | 0.04 – 0.06 | Yes | Assumption |
| `util_dec_eskd` | Disutility: kidney failure | 0.2 | Beta (mean 0.2, SE 0.04) | 0.16 – 0.24 | Yes | Added to the CKD 4 decrement; dialysis utility ~0.56-0.58 (Wyld et al. 2012) |
| `prob_disc_sglt2i` | SGLT2i annual discontinuation | 0.1 | Beta (mean 0.1, SE 0.02) | 0.08 – 0.12 | Yes | Assumption (trial-like persistence); real-world 1-year discontinuation 53.0% in a scenario (Bowe et al. 2025, Medicare Advantage) |
| `prob_disc_glp1` | GLP-1 RA annual discontinuation | 0.15 | Beta (mean 0.15, SE 0.03) | 0.12 – 0.18 | Yes | Assumption (trial-like persistence); real-world 1-year discontinuation 62.4% in a scenario (Bowe et al. 2025, Medicare Advantage) |
| `tx_wane_years` | Waning period after discontinuation (y) | 1 | Fixed | 0 – 2 | Yes | Assumption: linear loss of effect after discontinuation (0 = immediate) |
| `egfr_decline_ref` | eGFR decline at UACR 30 (mL/min/y) | 0.65 | Gamma (mean 0.65, SE 0.08) | 0.5 – 0.8 | Yes | Calibrated to KFRE 2- and 5-year kidney failure risk (Tangri, 4-variable, North American) |
| `egfr_uacr_beta` | eGFR decline: UACR exponent | 0.451 | Normal (mean 0.451, SD 0.051) | 0.35 – 0.55 | Yes | KFRE log(UACR) coefficient; varied in the PSA |
| `egfr_slope_sdlog` | eGFR decline heterogeneity (SD log) | 1.5 | Normal (mean 1.5, SD 0.153) | 1.2 – 1.8 | Yes | Calibrated jointly with the reference decline; varied in the PSA |
| `sbp_drift` | SBP drift (mmHg/y) | 0.5 | Normal (mean 0.5, SD 0.15) | 0 – 1 | Yes | Assumption (age-related SBP rise) |
| `hba1c_drift_dm` | HbA1c drift in diabetes (%/y) | 0.1 | Normal (mean 0.1, SD 0.03) | 0 – 0.2 | Yes | Assumption (UKPDS-type glycaemic drift) |
| `rr_recur_mi` | Recurrent MI hazard multiplier | 1.5 | Lognormal (log-mean 0.405, SE 0.103) | 1.2 – 1.8 | Yes | Assumption |
| `rr_recur_stroke` | Recurrent stroke hazard multiplier | 1.3 | Lognormal (log-mean 0.262, SE 0.079) | 1.1 – 1.5 | Yes | Assumption |
| `rr_recur_hf` | Recurrent HF hazard multiplier | 2 | Lognormal (log-mean 0.693, SE 0.130) | 1.5 – 2.5 | Yes | Assumption |
| `cvd_mult_mi` | CV death multiplier: prior MI | 2 | Lognormal (log-mean 0.693, SE 0.130) | 1.5 – 2.5 | Yes | Assumption |
| `cvd_mult_stroke` | CV death multiplier: prior stroke | 2.5 | Lognormal (log-mean 0.916, SE 0.103) | 2 – 3 | Yes | Assumption |
| `cvd_mult_hf` | CV death multiplier: prior HF | 3 | Lognormal (log-mean 1.099, SE 0.177) | 2 – 4 | Yes | Assumption |
| `cvd_mult_ckd3` | CV death multiplier: CKD 3 | 1.5 | Lognormal (log-mean 0.405, SE 0.103) | 1.2 – 1.8 | Yes | Assumption |
| `cvd_mult_ckd4` | CV death multiplier: CKD 4 | 2.5 | Lognormal (log-mean 0.916, SE 0.103) | 2 – 3 | Yes | Assumption |
| `cvd_mult_eskd` | CV death multiplier: kidney failure | 4 | Lognormal (log-mean 1.386, SE 0.130) | 3 – 5 | Yes | Assumption |
| `drc` | Discount rate: costs | 0.03 | Fixed | 0 – 0.05 | Scenario | Second Panel on Cost-Effectiveness in Health and Medicine |
| `drq` | Discount rate: outcomes | 0.03 | Fixed | 0 – 0.05 | Scenario | Second Panel on Cost-Effectiveness in Health and Medicine |
| `horizon_years` | Time horizon (y) | 100 | Fixed | 100 – 100 | Scenario | Lifetime (100 years from entry); 10 and 20 years in scenarios |
| `age_medicare` | Age at switch to Medicare prices (y) | 65 | Fixed | 65 – 65 | Scenario | Medicare eligibility age |
| `stop_sglt2i_at_kf` | SGLT2i stopped at kidney failure | 1 | Fixed | 1 – 1 | Scenario | KDIGO 2024: continue SGLT2i until dialysis or transplant; continued for life in a scenario |
| `addon_sglt2i` | Add-on SGLT2i in SoC and GLP-1 RA arms | 0 | Fixed | 0 – 0 | Scenario | Scenario: SGLT2i started at first HF hospitalization or CKD stage 4 in the SoC and GLP-1 RA arms |
| `bg_mort_mult` | Background mortality multiplier | 1 | Fixed | 1 – 1 | Scenario | Scenario 0.7: Gompertz hazard read as all-cause mortality; major cardiovascular diseases 28.6% of US deaths in 2022 (NVSR 74(4)) |
| `kidney_effect_restrict` | Kidney effect restricted | 0 | Fixed | 0 – 0 | Scenario | Scenario: kidney effect only with UACR >= 30 mg/g or eGFR < 60 |
| `hf_hosp_frac` | Share of incident HF hospitalized | 1 | Fixed | 1 – 1 | Scenario | Scenario 0.5: share of incident HF that is hospitalized (52.8% diagnosed in acute care; Tisdale 2023) |
| `util_gain_sglt2i` | Utility gain on SGLT2i | 0 | Fixed | 0 – 0 | Scenario | Scenario 0.002: weight -0.80 kg vs placebo (CREDENCE), -0.0061 per BMI unit above 25 (Bagust and Beale 2005) |
| `util_gain_glp1` | Utility gain on GLP-1 RA | 0 | Fixed | 0 – 0 | Scenario | Scenario 0.009: weight -4.10 kg vs placebo (FLOW), -0.0061 per BMI unit above 25 (Bagust and Beale 2005) |
| `prevent_age_cap` | PREVENT age cap (y) | 999 | Fixed | 999 – 999 | Scenario | Scenario 79: PREVENT validated age range 30-79 |
| `soc_optimized` | Optimized standard of care | 0 | Fixed | 0 – 0 | Scenario | Scenario: SBP lowered to 130 mm Hg and statin for all |
| `psa_hr_rho` | Correlation of class log HRs in PSA | 0.5 | Fixed | 0.5 – 0.5 | Scenario | Assumption: correlation of log HRs within a class in the PSA |

## Drug-specific scenario inputs

HRs are point estimates (95% CI) from each drug's placebo-controlled outcome trial in populations matching CKM stages. Costs are annual net prices (2025 USD) with DSA ranges spanning Medicare MFP/generic floors to brand WAC.
Per Decision D-015, the trial composite renal outcome HR is used as a surrogate proxy for the relative attenuation of the chronic eGFR decline slope (because time to an eGFR threshold scales inversely with slope, so hazard ratio ~ slope ratio).

| Drug | Class | Input | Estimate | Lower | Upper | Source |
|:--|:--|:--|--:|--:|--:|:--|
| empagliflozin | sglt2i | mace | 0.86 | 0.74 | 0.99 | EMPA-REG OUTCOME (Zinman 2015) 3P-MACE |
| empagliflozin | sglt2i | hf | 0.65 | 0.50 | 0.85 | EMPA-REG OUTCOME (Fitchett 2016) HHF |
| empagliflozin | sglt2i | cv_death | 0.62 | 0.49 | 0.77 | EMPA-REG OUTCOME (Zinman 2015) CV death |
| empagliflozin | sglt2i | egfr_slope_ratio | 0.71 | 0.62 | 0.81 | EMPA-KIDNEY (Herrington 2023) kidney progression HR (slope ratio proxy; D-015) |
| empagliflozin | sglt2i | cost | 4,600 | 2,364 | 7,500 | Net price assumption; range = 2026 Medicare MFP ($197/30d = $2,364/yr) to WAC |
| dapagliflozin | sglt2i | mace | 0.93 | 0.84 | 1.03 | DECLARE-TIMI 58 (Wiviott 2019) 3P-MACE |
| dapagliflozin | sglt2i | hf | 0.73 | 0.61 | 0.88 | DECLARE-TIMI 58 (Wiviott 2019) HHF |
| dapagliflozin | sglt2i | cv_death | 0.98 | 0.82 | 1.17 | DECLARE-TIMI 58 (Wiviott 2019) CV death |
| dapagliflozin | sglt2i | egfr_slope_ratio | 0.56 | 0.45 | 0.68 | DAPA-CKD (Heerspink 2020) composite renal HR (slope ratio proxy; D-015) |
| dapagliflozin | sglt2i | cost | 5,000 | 2,142 | 7,000 | Net price assumption; range = 2026 Medicare MFP ($178.50/30d = $2,142/yr) to WAC |
| canagliflozin | sglt2i | mace | 0.86 | 0.75 | 0.97 | CANVAS Program (Neal 2017) 3P-MACE; CREDENCE MACE was 0.80 (0.67-0.95) |
| canagliflozin | sglt2i | hf | 0.61 | 0.47 | 0.80 | CREDENCE (Perkovic 2019) adjudicated HHF; CANVAS HHF was 0.67 (0.52-0.87) |
| canagliflozin | sglt2i | cv_death | 0.78 | 0.61 | 1.00 | CREDENCE (Perkovic 2019) CV death; CANVAS CV death was 0.87 (0.72-1.06) |
| canagliflozin | sglt2i | egfr_slope_ratio | 0.70 | 0.59 | 0.82 | CREDENCE (Perkovic 2019) primary composite renal HR (slope ratio proxy; D-015) |
| canagliflozin | sglt2i | cost | 4,000 | 1,800 | 6,500 | Net price under generic competition; range = generic parity ($1,800/yr) to WAC ($6,500/yr) |
| sotagliflozin | sglt2i | mace | 0.84 | 0.72 | 0.99 | SCORED (Bhatt 2021) coprimary 3P-MACE in CKD+T2D; total MACE was 0.77 (0.65-0.91) |
| sotagliflozin | sglt2i | hf | 0.66 | 0.53 | 0.82 | SCORED (Bhatt 2021) HHF; urgent HF visit or HHF was 0.67 (0.55-0.82) |
| sotagliflozin | sglt2i | cv_death | 0.90 | 0.73 | 1.12 | SCORED (Bhatt 2021) CV death |
| sotagliflozin | sglt2i | egfr_slope_ratio | 0.71 | 0.46 | 1.08 | SCORED (Bhatt 2021) predefined renal composite HR (slope ratio proxy; D-015) |
| sotagliflozin | sglt2i | cost | 4,800 | 2,400 | 7,500 | Inpefa net commercial price post-rebate; range = negotiated discount ($2,400/yr) to WAC |
| semaglutide | glp1ra | mace | 0.80 | 0.72 | 0.90 | SELECT (Lincoff 2023) 3P-MACE |
| semaglutide | glp1ra | hf | 0.82 | 0.71 | 0.96 | SELECT (Lincoff 2023) HF composite (CV death or HF hosp/urgent visit) |
| semaglutide | glp1ra | cv_death | 0.85 | 0.71 | 1.01 | SELECT (Lincoff 2023) CV death |
| semaglutide | glp1ra | egfr_slope_ratio | 0.76 | 0.66 | 0.88 | FLOW (Perkovic 2024) primary composite kidney HR (slope ratio proxy; D-015) |
| semaglutide | glp1ra | cost | 8,604 | 3,288 | 11,628 | 2023 US net price (Hennessy et al., cited in 2026 CKM guideline); range = 2027 Medicare MFP ($274/30d) to WAC |
| liraglutide | glp1ra | mace | 0.87 | 0.78 | 0.97 | LEADER (Marso 2016) 3P-MACE |
| liraglutide | glp1ra | hf | 0.87 | 0.73 | 1.05 | LEADER (Marso 2016) HHF |
| liraglutide | glp1ra | cv_death | 0.78 | 0.66 | 0.93 | LEADER (Marso 2016) CV death |
| liraglutide | glp1ra | egfr_slope_ratio | 0.89 | 0.67 | 1.19 | LEADER renal (Mann 2017) persistent serum creatinine doubling (slope ratio proxy; D-015) |
| liraglutide | glp1ra | cost | 7,100 | 3,000 | 12,660 | Brand net price assumption; range = generic liraglutide ($3,000/yr) to brand WAC ($12,660/yr) |
| dulaglutide | glp1ra | mace | 0.88 | 0.79 | 0.99 | REWIND (Gerstein 2019) 3P-MACE (68.5% primary prevention / matching Stage 3) |
| dulaglutide | glp1ra | hf | 0.93 | 0.77 | 1.12 | REWIND (Gerstein 2019) adjudicated HHF |
| dulaglutide | glp1ra | cv_death | 0.91 | 0.78 | 1.06 | REWIND (Gerstein 2019) CV death |
| dulaglutide | glp1ra | egfr_slope_ratio | 0.85 | 0.77 | 0.93 | REWIND renal analysis (Gerstein, Lancet 2019) composite renal outcome HR (slope ratio proxy; D-015) |
| dulaglutide | glp1ra | cost | 6,500 | 3,000 | 11,000 | Trulicity net commercial price (~45% rebate); range = statutory discount ($3,000/yr) to WAC ($11,000/yr) |
| tirzepatide | glp1ra | mace | 0.80 | 0.57 | 1.11 | SURPASS pre-specified CV meta-analysis (Sattar 2022 Nat Med) MACE-4 |
| tirzepatide | glp1ra | hf | 0.67 | 0.26 | 1.70 | SURPASS CV meta-analysis (Sattar 2022) adjudicated HHF; SUMMIT HFpEF was 0.62 (0.41-0.95) |
| tirzepatide | glp1ra | cv_death | 0.90 | 0.50 | 1.61 | SURPASS CV meta-analysis (Sattar 2022 Nat Med) CV death; all-cause mortality was 0.80 (0.51-1.25) |
| tirzepatide | glp1ra | egfr_slope_ratio | 0.58 | 0.43 | 0.80 | SURPASS-4 kidney (Heerspink 2022) composite kidney HR (slope ratio proxy; chronic slope ratio ~0.62; D-015) |
| tirzepatide | glp1ra | cost | 9,200 | 4,000 | 13,000 | Mounjaro/Zepbound net price (~25-30% rebate); range = high volume/IRA benchmark to WAC |


## Fixed model inputs outside `l_params`

| Input | Value | Location | Source |
|:--|:--|:--|:--|
| PREVENT coefficients (ASCVD, HF, CHD, stroke; base and HbA1c models) | Published | `R/03_risk_equations.R` | Khan et al. Circulation 2024; identical to `preventr` tables |
| PREVENT input ranges (winsorised) | SBP 90–180, TC 130–320, HDL 20–100, BMI 18.5–39.9, eGFR 15–140, HbA1c 4.5–15 | `R/03_risk_equations.R` | `preventr` validity limits |
| Non-CV mortality (Gompertz) | Male 0.0001·e^(0.085·age); female 0.00006·e^(0.088·age) | `R/03_risk_equations.R` | Approximation of CDC NVSS 2022 life tables |
| CV share of all-cause mortality | 30% | `R/03_risk_equations.R` | Assumption |
| Recurrence caps | MI 3, stroke 3, HF 5 | `R/08_run_model.R` | Assumption |
| Waning steps | 4 | `R/08_run_model.R` | Discretisation of linear waning |
