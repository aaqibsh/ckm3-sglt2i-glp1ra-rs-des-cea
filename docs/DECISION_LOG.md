# Decision Log — CKM-HEOR

> Tracks all architectural and clinical decisions with rationale and alternatives considered.

---

## D-001: Model Engine — WARDEN DES
**Date**: 2026-09-25  
**Decision**: Use WARDEN (v2.0.6) as the DES engine  
**Alternatives**:
- Standalone microsimulation (cycle-based) — rejected: reinvents PSA, discounting, parallelisation
- Custom DES from scratch — rejected: unnecessary given WARDEN exists and is CRAN-published

**Rationale**: WARDEN provides built-in PSA, discounting, CEAC, EVPI, parallelisation. Already has CVD case study (Lin & Briggs). NICE TSD-15 aligned. CRAN-published adds credibility.

---

## D-002: Comparison — Class-Level with Drug-Specific Scenarios
**Date**: 2026-09-25  
**Decision**: SGLT2i class vs GLP-1 RA class (base case); drug-specific as scenarios  
**Rationale**: Guideline gives class-level recommendations. Class-level is most defensible for policy questions. Drug-specific scenarios add granularity without weakening the primary analysis.

---

## D-003: Population — Three CKM Stage Analyses
**Date**: 2026-09-25  
**Decision**: Separate analyses for CKM Stages 2, 3 (primary), 4a  
**Rationale**: Stage 3 is most novel (few existing economic models). Stages 2 and 4a provide breadth. Shared parameter architecture minimises extra work.

---

## D-004: Outcomes — Core Only
**Date**: 2026-09-25  
**Decision**: MACE (MI, stroke, CV death), HF hospitalisation, CKD progression → ESKD, all-cause mortality  
**Alternatives**: T2D, AF, weight/BMI, MASLD/MASH — deferred for model parsimony  
**Rationale**: All core outcomes have strong class-level trial evidence for both drug classes. Lean model is more defensible and faster to validate.

---

## D-005: Arms — 3-Arm Structure
**Date**: 2026-09-25  
**Decision**: SGLT2i+SoC vs GLP-1 RA+SoC vs SoC alone  
**Rationale**: Enables both individual ICERs (each vs SoC) and head-to-head comparison. More informative than 2-arm.

---

## D-006: Perspective & Horizon
**Date**: 2026-09-25  
**Decision**: US healthcare payer + lifetime (base); 10-year and societal (sensitivity)  
**Rationale**: Standard for US HTA. Guideline uses $120K/QALY WTP threshold. 10-year matches PREVENT equations.

---

## D-007: Seed Constraint
**Date**: 2026-09-25  
**Decision**: Use seed ≤ 100 for WARDEN  
**Rationale**: WARDEN's internal seed calculation (seed × n_sim × 1007 + seed × npats × 349) can overflow R's integer.max with large seeds. Discovered during pilot testing.

---

## D-008: df_pop Global Scope
**Date**: 2026-09-25  
**Decision**: Assign df_pop to globalenv() inside run_ckm_model()  
**Rationale**: WARDEN evaluates delayed expressions in an environment chain that doesn't reliably capture function-local variables. Assigning to globalenv() ensures df_pop is visible during expression evaluation. Known WARDEN pattern from Lin & Briggs vignette (which uses global scope directly).

---

## D-009: Non-Recurrent Events (Pilot)
**Date**: 2026-09-25  
**Decision**: MI, stroke, HF fire only once per patient in pilot  
**Rationale**: Simplifies reactions; post-event mortality acceleration captures the recurrence-related risk. Recurrent events planned for production version.

---

## D-010: Recurrent Events (supersedes D-009)
**Date**: 2026-09-27  
**Decision**: MI, stroke and HF are recurrent (caps 3/3/5) with compounding hazard multipliers per prior event (`rr_recur_*`, PSA/DSA-varied). The multiplier is held as patient state (`rr_state`) so yearly age updates keep it; previously each age update recomputed the PREVENT hazard without it and silently undid the recurrence elevation within a year.

---

## D-011: PREVENT Validation Method
**Date**: 2026-09-28  
**Decision**: Validate against `preventr`'s internal, unrounded scoring (`prep_terms()` + `run_models(dp = 12)`) rather than `estimate_risk()`, across base and HbA1c models, both sexes, and the ASCVD, HF, CHD and stroke equations.  
**Rationale**: `estimate_risk()` rounds to 3 decimals, which alone produces >1% relative error for risks below ~5% and caused the apparent failures (patients 1 and 5). Unrounded agreement is ~1e-11; coefficient tables are identical.

---

## D-012: PREVENT Inputs Outside Validated Ranges
**Date**: 2026-09-28  
**Decision**: Winsorise SBP, TC, HDL, BMI, eGFR and HbA1c to PREVENT's validated ranges before scoring; do not clamp age.  
**Alternatives**: Linear extrapolation of all predictors (rejected: spline terms such as BMI ≥ 30 would extrapolate far beyond the data, e.g. BMI 50); clamping age at 79 (rejected: removes all ageing effect after 79).  
**Rationale**: Patients age to 100 in a lifetime model, so age must be extrapolated; the extrapolated risk is smooth and monotone to age 100 (tested).

---

## D-013: MI/Stroke Split from PREVENT CHD and Stroke Sub-models
**Date**: 2026-09-28  
**Decision**: Total ASCVD hazard is split into MI and stroke using the patient-specific ratio of the PREVENT CHD and stroke equations (≈56% MI on average in Stage 3), replacing a fixed 60/40 split.  
**Alternatives**: Use CHD and stroke hazards directly (rejected: separately fitted models sum to ~110% of the ASCVD hazard, inflating MACE).

---

## D-014: Kidney Progression — Continuous eGFR Trajectory, Calibrated to KFRE
**Date**: 2026-09-28  
**Decision**: Each patient follows a linear eGFR trajectory with slope = `egfr_decline_ref` × (UACR/30)^0.451 × mean-one lognormal heterogeneity (SD 1.5). CKD progression events fire at eGFR 60, 30 and 15 (ESKD). `egfr_decline_ref` (0.65 mL/min/yr) and the heterogeneity SD were calibrated so that the model's death-free 2- and 5-year kidney failure risk in patients with eGFR < 60 matches the 4-variable KFRE (North American calibration).  
**Previous approach and why it changed**: (1) the `ckd_prog` reaction advanced stage 1 to a non-existent stage "2", scheduled stage 3 → 4 at +0.1 years, used the untreated slope after the first progression, and scheduled ESKD independently of CKD stage; (2) decline rates (1.0/2.5/4.0 mL/min/yr by stage, SD 0.3) were trial-placebo rates for heavily albuminuric populations and gave a 5-year kidney failure risk of 18.6% vs 6.2% by KFRE and ~43% lifetime ESKD in SoC. The calibrated model gives 4.3% vs 4.4% (5-year) and ~8–10% lifetime ESKD in Stage 3 SoC.  
**External check**: implied mean slope 3.1 mL/min/yr at UACR 950 mg/g (DAPA-CKD placebo ≈3.6); 1.9 at UACR 330.  
**Known limitation**: under-predicts in eGFR 20–30 (5-year 11.7% vs 17.9%) and over-predicts in eGFR 45–60 (2.4% vs 1.1%); a stage-specific rate fit subgroups better but was not identifiable from two targets.

---

## D-015: Treatment Effect on Kidney Progression as a Slope Ratio
**Date**: 2026-09-28  
**Decision**: Treatment multiplies the chronic eGFR slope by a ratio equal to the meta-analytic kidney-progression HR: SGLT2i 0.63 (SMART-C 2022), GLP-1 RA 0.81 (Badve et al. 2024). Time to an eGFR threshold scales with 1/slope, so the slope ratio reproduces the HR for crossing a threshold.  
**Previous approach**: an absolute slope reduction (1.5 and 0.87 mL/min/yr) subtracted from the decline and floored at 0.1, which made SGLT2i slow decline ~10-fold in patients with preserved eGFR (1.0 − 1.5 → 0.1).  
**Rationale**: Same method and comparable endpoints for both classes; proportional effects are consistent with trial subgroup findings across baseline eGFR.

---

## D-016: ESKD Costs and Utility
**Date**: 2026-09-28  
**Decision**: ESKD annual cost (USRDS total per-patient spending) replaces the CKD 4 management cost; the ESKD utility decrement is applied on top of the CKD 4 decrement (0.84 − 0.05 − 0.20 = 0.59, consistent with dialysis utilities of 0.56–0.58).  
**Previous approach**: ESKD cost was added on top of CKD 4 cost (double counting ~$15K/yr).

---

## D-017: Treatment Discontinuation Waning
**Date**: 2026-09-28  
**Decision**: Drug cost stops at discontinuation; the treatment effect (all event HRs and the eGFR slope ratio) wanes linearly to zero over `tx_wane_years` (1 year; DSA 0–2), implemented as 4 equal steps evaluated at interval midpoints (retained effect 0.875, 0.625, 0.375, 0.125, then 0). Effective HR = 1 + (HR − 1) × retained fraction.  
**Alternatives**: 50%/50% two-step (coarser); per-age-update interpolation (ties waning resolution to the yearly age cycle).  
**Rationale**: The step schedule has the same average retained effect (0.5) as continuous linear waning. Pending exponential events are rescaled exactly at each step.

---

## D-018: Dynamic Biomarkers — Natural History Only
**Date**: 2026-09-28  
**Decision**: At each yearly update, SBP rises by `sbp_drift` (0.5 mmHg/yr) and HbA1c in diabetes by `hba1c_drift_dm` (0.1%/yr) in all arms equally; eGFR follows the arm-specific trajectory. Treatment effects on SBP, HbA1c and BMI are **not** fed into PREVENT.  
**Rationale**: Treatment benefit is applied through trial HRs, which already include risk-factor-mediated benefit; lowering SBP/HbA1c/BMI in treated arms as well would double count. The eGFR pathway is kept because kidney-mediated CV risk accrues mainly beyond trial follow-up.

---

## D-019: Hazard Updating by Exact Rescaling; Common Random Numbers
**Date**: 2026-09-28  
**Decision**: All event hazards are exponential between state changes; every change (ageing, biomarker drift, new event, CKD stage, waning) recomputes hazards and rescales each pending event time by h_old/h_new. Prior MI/stroke/HF and CKD stage now update CV death risk immediately, not at the next yearly update. A single arm-generic event definition draws initial times in the same order in every arm, so WARDEN's per-patient seed gives common random numbers across arms (and across DSA analyses).

---

## D-020: DSA via WARDEN's Built-in Mechanism; INMB Tornado
**Date**: 2026-09-28  
**Decision**: One-way DSA uses `input_block(dsa_names = c("DSA_min","DSA_max"))` with `sensitivity_bool = TRUE`; every parameter with `dsa_indicators = 1` is varied (50 parameters, 100 analyses). Tornado diagrams plot INMB at $120,000/QALY; ICER tornados are produced only for comparisons whose base case is in the NE quadrant.  
**Rationale**: SGLT2i dominates GLP-1 RA head-to-head, so ICERs are negative and non-monotone there; INMB is well-defined in every quadrant. Structural assumptions (recurrence and CV-mortality multipliers, waning period, kidney calibration, discount rates) were parameterised so they appear in the tornado.

---

## D-021: Drug-Specific Scenario Inputs
**Date**: 2026-09-28  
**Decision**: Each drug's HRs come from its own placebo-controlled trial in a population without established HF: empagliflozin (EMPA-REG OUTCOME; kidney: EMPA-KIDNEY), dapagliflozin (DECLARE-TIMI 58; kidney: DAPA-CKD), semaglutide (SELECT; kidney: FLOW), liraglutide (LEADER; kidney: LEADER renal). Primary scenario empagliflozin vs semaglutide; secondary dapagliflozin vs liraglutide.  
**Corrections to the handoff table**: DECLARE CV death HR is 0.98 (not 0.83, which is DAPA-HF); SELECT MACE HR is 0.80 (0.74 is SUSTAIN-6); LEADER HHF HR is 0.87 (not 0.93); empagliflozin HHF 0.65 is from EMPA-REG, not EMPEROR. Semaglutide cost uses the 2023 US net price $8,604 cited in the 2026 CKM guideline (Hennessy et al.).

---

## D-022: Population Generator Consistency
**Date**: 2026-09-28  
**Decision**: eGFR drawn from a truncated normal with lower bound 20 (was clamped at 15, leaving ~1.5% of Stage 3/4a patients at eGFR exactly 15, i.e. at kidney failure at baseline); HbA1c redrawn in the non-diabetic range (4.8–6.4%) for patients without diabetes (previously ~7.5% regardless of diabetes status, which inflated PREVENT's HbA1c-without-diabetes term).

---

## D-023: Production Configuration
**Date**: 2026-09-28  
**Decision** (agreed with the project lead):
- Deterministic base case and scenarios: 5,000 patients per stage (single run each; removes the Monte Carlo ambiguity in Stage 2 SGLT2i vs SoC).
- DSA: 500 patients; 14 parameters — drug costs, MACE / HF / CV-death HRs for both classes, both eGFR slope ratios, reference eGFR decline, ESKD cost, GLP-1 RA discontinuation, waning period. Selected from the drivers of the pilot 50-parameter DSA plus the MACE HRs for face validity.
- Discount rates (0% and 5%, costs and outcomes together) reported as scenarios, not in the tornado.
- PSA: 500 iterations × 500 patients per stage, run as 5 chunks of 100 iterations with seeds 101, 103, 107, 109, 113. Distinct primes above the chunk size ensure no two chunks share a PSA parameter draw (WARDEN seeds simulation s with s × 1007 × seed).
- Compute: GitHub Actions, single core per job, private repository; laptop runs remain possible with the same scripts.  
**Rationale**: At 500 patients per iteration, within-iteration Monte Carlo SE of INMB (~$2.4K for SGLT2i vs SoC in Stage 3) is smaller than the parameter-driven spread, so PSA conclusions are informative, though the spread is somewhat overstated. Chunking keeps every job far below GitHub's 6-hour limit and makes failures cheap to re-run.

---

## D-024: CEAC Computed Directly
**Date**: 2026-09-28  
**Decision**: The CEAC is computed as the share of iterations in which each strategy has the highest net monetary benefit, replacing `WARDEN::ceac_des()`, which counts a strategy only when its total NMB is positive and so returns 0 for every arm at low WTP.

---

## D-025: Primary Manuscript Focus on CKM Stage 3
**Date**: 2026-10-01  
**Decision**: Primary manuscript, core tables, and scenario expansions focus exclusively on CKM Stage 3. Stages 2 and 4a results from the production GitHub Actions run are retained for exploratory/supplementary reference.  
**Rationale**:
- **Methodological defensibility**: PREVENT risk equations were developed and validated specifically for *primary prevention* (predicting first ASCVD/HF events). Applying PREVENT to Stage 4a (established clinical ASCVD) is an unvalidated extrapolation prone to reviewer challenge. Stage 2 features low absolute 10-year event rates, rendering lifetime expensive pharmacotherapy sensitive to minor assumptions and near the WTP threshold ($98k/QALY).
- **Clinical alignment**: 2026 AHA/ACC/ADA/ASN CKM Guideline designates Stage 3 (subclinical CVD: elevated PREVENT risk >=7.5-10%, CAC > 0, elevated hs-cTn/NT-proBNP, high-risk CKD) as the primary battleground for initiating SGLT2i and GLP-1 RA.
- **Economic stability**: In Stage 3, SGLT2i demonstrates stable dominance over GLP-1 RA (higher QALYs, lower cost) and strong cost-effectiveness vs SoC ($73,796/QALY vs $120,000 WTP).

---

## D-026: Expansion of Drug-Specific Scenarios to 8 Agents (16 Head-to-Head Pairings)
**Date**: 2026-10-01  
**Decision**: Expand drug-specific scenario analyses in Stage 3 from 4 drugs (4 pairings) to 8 drugs across 16 pairwise combinations (4 SGLT2i × 4 Incretin/GLP-1 RAs), evaluated deterministically at 5,000 patients:
1. **SGLT2 inhibitors (4)**:
   - Empagliflozin (*EMPA-REG OUTCOME / EMPA-KIDNEY*): MACE HR 0.86, HHF HR 0.65, CV death HR 0.62, kidney progression HR 0.71. Net cost $4,600/yr (range: $2,364 Medicare MFP to $7,500 WAC).
   - Dapagliflozin (*DECLARE-TIMI 58 / DAPA-CKD*): MACE HR 0.93, HHF HR 0.73, CV death HR 0.98, kidney progression HR 0.56. Net cost $5,000/yr (range: $2,142 Medicare MFP to $7,000 WAC).
   - Canagliflozin (*CREDENCE / CANVAS Program*): Landmark dedicated renal trial CREDENCE (primary composite renal HR 0.70 [0.59–0.82], HHF HR 0.61, CV death HR 0.78, CANVAS 3P-MACE HR 0.86). Net cost $4,000/yr (range: $1,800 generic parity to $6,500 WAC).
   - Sotagliflozin (*SCORED / SOLOIST-WHF*): Dual SGLT1/2 inhibitor in CKD + T2D matching Stage 3 (published coprimary 3P-MACE HR 0.84 [0.72–0.99], HHF HR 0.66 [0.53–0.82], CV death HR 0.90 [0.73–1.12], renal composite HR 0.71 [0.46–1.08]). Net cost $4,800/yr (range: $2,400 to $7,500 WAC).
2. **Incretins / GLP-1 and Dual GIP/GLP-1 Receptor Agonists (4)**:
   - Semaglutide (*SELECT / FLOW*): 3P-MACE HR 0.80, HF composite HR 0.82, CV death HR 0.85, FLOW primary kidney composite HR 0.76 (0.64–0.89). Net cost $8,604/yr (range: $3,288 Medicare MFP 2027 to $11,628 WAC).
   - Liraglutide (*LEADER / LEADER renal*): 3P-MACE HR 0.87, HHF HR 0.87, CV death HR 0.78, persistent creatinine doubling HR 0.89. Net cost $7,100/yr (range: $3,000 generic to $12,660 WAC).
   - Dulaglutide (*REWIND / AWARD-7*): 68.5% primary prevention without prior CVD (ideal Stage 3 match; 3P-MACE HR 0.88, HHF HR 0.93, CV death HR 0.91, composite renal HR 0.84). Net cost $6,500/yr (range: $3,000 statutory discount to $11,000 WAC).
   - Tirzepatide (*SURPASS program / SUMMIT*): Dual GIP/GLP-1 receptor agonist; SURPASS pre-specified meta-analysis (Sattar 2022 Nat Med: MACE-4 HR 0.80 [0.57–1.11], HHF HR 0.67 [0.26–1.70], CV death HR 0.90 [0.50–1.61]) and SURPASS-4 kidney composite HR 0.58 [0.43–0.80]. Net cost $9,200/yr (range: $4,000 IRA benchmark to $13,000 WAC).
**Rationale**: Enables comprehensive comparative value mapping across all major approved cardioprotective and nephroprotective incretins and SGLT2 inhibitors in CKM Stage 3. Per Decision D-015, the trial composite renal outcome HR is used as a surrogate proxy for the relative attenuation of the chronic eGFR decline slope. Deterministic evaluation at 5,000 patients avoids lengthy PSA re-runs while offering complete 4×4 head-to-head resolution.

---

## D-027: Class-Level Hazard Ratios Corrected to Their Source Meta-Analyses
**Date**: 2026-10-14  
**Decision**: Three class inputs did not match the cited meta-analyses and were corrected (external pre-submission review, item 7.2):
- SGLT2i CV death 0.84 (0.76–0.93) → **0.85 (0.78–0.93)**, McGuire et al. JAMA Cardiol 2021.
- GLP-1 RA HF hospitalisation 0.91 (0.83–1.00) → **0.89 (0.82–0.98)**, Sattar et al. Lancet Diabetes Endocrinol 2021.
- GLP-1 RA CV death 0.88 (0.82–0.94) → **0.87 (0.80–0.94)**, Sattar et al. 2021 (0.88 was all-cause death).
- Badve et al. is Lancet Diabetes Endocrinol 2025;13:15–28 (not 2024); its composite kidney HR 0.81 (0.72–0.92) is unchanged.  
**Effect** (pilot, 500 patients): SGLT2i vs GLP-1 RA INMB about −$1.1K, SGLT2i vs SoC about −$0.4K; conclusions unchanged.  
**Note**: D-025 describes Stage 3 with a PREVENT 7.5–10% threshold; the 2023 advisory defines Stage 3 as subclinical CVD or risk equivalents (very-high-risk CKD; predicted 10-year CVD risk ≥20%). See D-031.

---

## D-028: Revision Production Configuration (Stage 3 Only)
**Date**: 2026-10-14  
**Decision**:
- Every deterministic run (base case, scenarios, agents, DSA) at **20,000 patients**, seed 42, so the DSA is centred on the base case and one base case appears everywhere (review items 9.1, 9.6, 12.1, 16.3).
- PSA: **500 iterations × 1,000 patients**, 10 chunks of 50 (seeds 101–149, distinct primes above the chunk size).
- One-way DSA over **all 48 uncertain parameters** (everything with DSA bounds except discount rates and time horizon, which are scenarios), split round-robin into 12 shards (review item 9.3). Tornados show the top 15.
- GitHub Actions: two R processes per job (both vCPUs; billing is per job minute). The base case, which keeps the patient-level event log (~5 GB at 20,000 patients), runs alone in its job.
- Stages 2 and 4a are not rerun (manuscript is Stage 3 only, D-025).  
**Rationale**: Halves Monte Carlo error versus 5,000 patients (ICER SE ≈ $3.5K) within the free Actions allowance (~1,150 billed minutes).

---

## D-029: Drug Acquisition Cost in Its Own Accumulator; Exact Threshold Prices
**Date**: 2026-10-14  
**Decision**: Drug cost moved from `c_default` to a separate ongoing accumulator `c_drug` (stops at discontinuation or death). Total costs are unchanged (verified identical to 10 decimals). Because drug cost is linear in the annual price, INMB(p) = INMB(p₀) − (p − p₀)·D with D = discounted drug cost / p₀, giving exact break-even prices at $100K/$120K/$150K per QALY without extra runs (`threshold_prices()`, review item 9.7).

---

## D-030: Structural Scenarios Added
**Date**: 2026-10-14  
**Decision**: Discount 0%/5%; Medicare negotiated prices (SGLT2i $2,364/y = 2026 empagliflozin MFP $197/30 days; GLP-1 RA $3,288/y = 2027 semaglutide MFP $274/30 days); 10- and 20-year horizons (new `horizon_years` parameter and `horizon` event); full persistence (no discontinuation); no CV-death treatment effect; equal kidney effect (GLP-1 RA slope ratio = SGLT2i); no kidney effect (both slope ratios 1). A chronic-eGFR-slope-ratio scenario is coded but switched off (`CHRONIC_SLOPE_RATIOS` in `analysis/run_scenarios.R`) until the trial placebo chronic slopes are confirmed from full texts; the slope differences alone (EMPA-KIDNEY 1.37, DAPA-CKD 2.26 in T2D, FLOW 1.16 total) cannot be converted to ratios without them.  
**Rationale**: Answers review items 7.1 and 9.8 with scenarios that need no new evidence: if SGLT2i still dominates GLP-1 RA with equal or no kidney effect, the conclusion does not rest on the HR-as-slope-ratio mapping.

---

## D-031: Patient-Level Outputs, Subgroups and External Validation
**Date**: 2026-10-14  
**Decision**: The base case keeps the WARDEN event log and writes one row per patient and arm (`R/11_patient_outputs.R`, `patient_level_stage3.csv.gz`). From it: subgroups (diabetes, eGFR <45/45–59/≥60, UACR <30/30–299/≥300, age <65/≥65, sex, Stage 3 risk-equivalent), event burden (% with ≥1 event, events per 100 patients and per 100 patient-years over 5 years, kidney failure, CV death, undiscounted life expectancy), and validation (simulated 10-year first-event incidence in SoC vs mean baseline PREVENT prediction for the same patients). Baseline PREVENT risks use `preventr::estimate_risk()` (HbA1c model, inputs clamped to validated ranges). Stage 3 risk-equivalent = KDIGO very-high-risk CKD (G4–5; G3b A2–3; G3a A3) or PREVENT 10-year total CVD ≥20%.  
**Pilot finding**: 10-year first MI/stroke 14.6% vs PREVENT ASCVD 15.3%; first HF hospitalisation 16.8% vs PREVENT HF 17.2%; 67% meet a risk-equivalent.

---

## D-032: Agent-Level Results From Four Runs
**Date**: 2026-10-14  
**Decision**: Each arm is simulated independently with common random numbers, so an arm's result depends only on its own inputs. The 8 agents are run as 4 pairs (empagliflozin/semaglutide, dapagliflozin/liraglutide, canagliflozin/dulaglutide, sotagliflozin/tirzepatide); every agent vs SoC and all 16 SGLT2i-vs-incretin pairs are computed from the per-arm results (`combine_results.R` checks the SoC arm is identical across runs). Presented as exploratory (naive cross-trial inputs).

---

## D-033: Dulaglutide and Semaglutide Kidney Inputs Aligned With the Publications
**Date**: 2026-10-16  
**Decision**: Dulaglutide kidney slope ratio 0.84 (0.74–0.95) → 0.85 (0.77–0.93), the REWIND renal analysis composite renal outcome HR (Gerstein, Lancet 2019;394:131–138); semaglutide FLOW range 0.64–0.89 → 0.66–0.88 (point estimate 0.76 unchanged). Only the canagliflozin/dulaglutide agent run depends on these values (agent runs are deterministic; the class-level base case, DSA and PSA do not use agent inputs). Agent runs part 2 of 2 rerun on the laptop at production size (20,000 patients, same seed, 19 min) and merged; part 1 rerun as a reproducibility check. The empagliflozin/semaglutide run, all SoC arms and both part-1 runs reproduced the cloud run 38523665536 exactly. Effect: dulaglutide INMB vs SoC −$13,278 → −$13,702; SGLT2i-agent pairs vs dulaglutide +$423 each; no qualitative change.

---

## D-034: Drug Prices by Payer and Age (Second Pre-Submission Review)
**Date**: 2026-10-23  
**Decision**: Drug prices depend on the payer, set by age: commercial price before 65, Medicare price from 65 (`age_medicare`; a deterministic `medicare` event switches the price). Drug cost accrues in two accumulators (`c_drug_com`, `c_drug_mcr`), so results at any price set are exact without new runs (`reprice()`, `threshold_prices()` by payer basis; `scripts/price_scenarios.R`). About half of discounted drug spending falls before 65 (mean age 62).
- SGLT2i commercial: $4,250/y, brand acquisition cost without rebate (mean of empagliflozin $11.19 and dapagliflozin $12.08 per tablet, CMS NADAC 21 Oct 2026). The previous $4,800 "net" price exceeded the brand acquisition cost and could not be defended. Medicare: empagliflozin MFP $197/30 days = $2,397/y (fixed in the PSA).
- GLP-1 RA commercial: $6,830/y, semaglutide net price from SSR Health used in the ICER obesity final report (16 Dec 2025); range $4,188 (self-pay $349/mo) to $8,100 (Ozempic list price $675/mo from 1 Jan 2027). Medicare: semaglutide MFP $274/30 days = $3,334/y from 1 Jan 2027 (annualised ×365/30 instead of ×12).
- The reviewer's $245/month Medicare price applies only to obesity use under the Medicare GLP-1 Bridge (Jul 2026–Dec 2027, outside Part D); the Part D component of the BALANCE model (diabetes uses included) was postponed indefinitely in April 2026 (KFF, 11 May 2026). Medicaid $245/month applies in participating states. Both enter as price scenarios, not the base case.
- Generic dapagliflozin (FDA approval 7 Apr 2026; NADAC $0.18 per tablet, $67/y) is a scenario; the base case keeps brand prices, which works against SGLT2i.
**Alternatives considered**: all-Medicare base (public prices, but ignores half of drug spending before 65); keep $7,500 (93% of the 2027 list price).

---

## D-035: Structural Scenarios for the Second Review; SGLT2i Stopped at Kidney Failure
**Date**: 2026-10-23  
**Decision**: Base case: SGLT2i stops at kidney failure (KDIGO 2024; no waning; `stop_sglt2i_at_kf`; continued for life in a scenario). New scenario switches, all off in the base case: add-on SGLT2i at first HF hospitalization or CKD stage 4 in the SoC and GLP-1 RA arms (effects multiply; own discontinuation; `addon_sglt2i`); background mortality multiplier (`bg_mort_mult` 0.7 = Gompertz read as all-cause, split 70/30); kidney effect only with UACR ≥30 or eGFR <60; share of incident HF hospitalized (0.5; see D-036); weight-related utility gain (GLP-1 RA 0.009, SGLT2i 0.002; see D-036); PREVENT age cap 79; optimized SoC (SBP ≤130 on treatment, statin for all, total cholesterol −25% when newly started). Parameter scenarios: SGLT2i effects without ASCVD (McGuire 2021: MACE 0.94, HHF 0.63, CV death 0.95); GLP-1 RA effects from FLOW (MACE 0.82, HF events 0.73, CV death 0.71, total eGFR slope ratio ~0.65); real-world discontinuation (Bowe 2025, Medicare Advantage: 1-year discontinuation SGLT2i 53.0%, GLP-1 RA 62.4%, applied every year); a combined conservative scenario (add-on, mortality 0.7, HF 0.5, no-ASCVD SGLT2i effects, FLOW GLP-1 RA effects, weight utility). The "no CV death effect" scenario is the mediated-only pathway (benefit on CV death only through fewer events and slower CKD). The Medicare-price scenario run is replaced by exact price scenarios. An acute eGFR dip scenario was tried and dropped: the dip pushes patients across eGFR 60 at once and the trial kidney HRs used already include it.  
**PSA**: kidney-decline heterogeneity and UACR exponent now varied; log HRs for MACE, HF hospitalization and CV death correlated within class (ρ = 0.5, marginals unchanged; `correlate_log_hrs()`).  
**Agents**: semaglutide inputs from FLOW (T2D and CKD) instead of SELECT; tirzepatide MACE 0.81 (0.70–0.94) = SURPASS-CVOT 0.92 vs dulaglutide × REWIND 0.88; agent prices from CMS NADAC (generic dapagliflozin $67/y and generic liraglutide $3,196/y; empagliflozin $4,084/y; dulaglutide $6,690/y = NADAC × semaglutide net-to-NADAC ratio) and ICER (tirzepatide $7,973/y).  
**Runs**: 20 structural scenarios in 10 parts, DSA 50 parameters in 26 shards (13 jobs).

---

## D-036: Scenario Inputs Checked Against Primary Sources Before the R2 Production Run
**Date**: 2026-10-23  
**Decision**: Every new R2 input was checked against its primary source before the production run. Confirmed unchanged: FLOW (Perkovic 2024, Table 2: eGFR slope −2.19 vs −3.36 mL/min/1.73 m² per year, ratio 0.65; MACE 0.82, CV death 0.71; Pratley 2024 HF events 0.73, 0.58–0.92); McGuire 2021 without ASCVD (MACE 0.94, 0.83–1.07; HHF 0.63, 0.50–0.80; CV death 0.95, 0.77–1.17); Bowe 2025 (1-year persistence 47.0% SGLT2i, 37.6% GLP-1 RA; 45-day gap); SURPASS-CVOT 0.92 (95.3% CI 0.83–1.01) × REWIND 0.88 → tirzepatide 0.81 (0.70–0.94); DAPA-CKD slopes (Heerspink 2021: total 0.95; chronic 2.26 with T2D, 1.29 without); Bagust and Beale 2005 (Table 3, TTO model: −0.0061 per BMI unit above 25, SE 0.001). Background-mortality multiplier 0.7: major cardiovascular diseases (I00–I78) caused 28.6% of US deaths in 2022 and 26–29% at ages 55–84 (NVSR 74(4), Table 9), so 0.7 approximates a cardiovascular-deleted life table (the reviewer asked for cause-deleted life tables, not for this split).  
Changed: (1) share of incident HF hospitalized 0.7 → 0.5: 52.8% of incident HF in the Veterans Health Administration was diagnosed in acute care, inpatient or emergency department (Tisdale 2023, JACC Heart Fail, PMID 36881392), so 0.7 overstated hospitalization; the lower share is also more conservative for SGLT2i. (2) SGLT2i weight-related utility 0.004 → 0.002: the earlier "about 2 kg" had no source; the placebo-adjusted weight change in the SGLT2i trial in T2D and CKD is −0.80 kg (CREDENCE), matching FLOW for GLP-1 RA (−4.10 kg, 1.46 BMI units, 0.009 unchanged).

