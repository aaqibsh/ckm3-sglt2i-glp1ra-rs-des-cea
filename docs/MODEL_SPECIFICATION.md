# CKM-HEOR Model Specification

> **Version**: 0.5.0 (pre-production)  
> **Last Updated**: 2026-09-28  
> **Status**: Phase 5 — analytical capabilities complete; production run pending

---

## 1. Model Overview

| Attribute | Value |
|:---|:---|
| **Model Type** | Patient-level Discrete Event Simulation (DES) |
| **Engine** | WARDEN R package (v2.0.6) |
| **Condition** | Cardiovascular-Kidney-Metabolic (CKM) Syndrome |
| **Clinical Framework** | 2026 AHA/ACC/ADA/ASN CKM Guideline (Ndumele et al.) |
| **Interventions** | SGLT2i + SoC vs GLP-1 RA + SoC vs SoC alone |
| **Comparison Level** | Class-level (base case); drug-specific (scenarios) |
| **Population** | Adults with CKM Stages 2, 3 (primary), 4a |
| **Perspective** | US Healthcare Payer (base); Societal (sensitivity, planned) |
| **Time Horizon** | Lifetime (base); 10- and 20-year (scenarios) |
| **Cycle Length** | N/A — continuous time; state updated yearly and at every event |
| **Discount Rate** | 3% costs and outcomes (DSA 0–5%) |
| **Currency** | 2025 USD |
| **WTP threshold** | $120,000/QALY |

## 2. Population

Synthetic cohorts per CKM stage (`R/02_population.R`): age, sex, BMI, SBP, eGFR, UACR, HbA1c, total and HDL cholesterol, smoking, diabetes, statin and antihypertensive use, and CKD stage (1 = eGFR ≥ 60, 3 = 30–59, 4 = 15–29).

- eGFR is drawn from a truncated normal with lower bound 20 mL/min/1.73m².
- HbA1c is consistent with diabetes status (non-diabetic 4.8–6.4%; diabetic ≥ 5.7%).

## 3. Events

| Event | Type | Hazard |
|:--|:--|:--|
| MI | Recurrent (cap 3) | PREVENT ASCVD × patient-specific CHD share × recurrence multiplier × treatment HR |
| Stroke | Recurrent (cap 3) | PREVENT ASCVD × stroke share × recurrence multiplier × treatment HR |
| HF hospitalisation | Recurrent (cap 5) | PREVENT HF × recurrence multiplier × treatment HR |
| CKD progression | At eGFR 60, 30, 15 | Deterministic crossing of the patient's eGFR trajectory; eGFR 15 = ESKD |
| CV death | Terminal | Life-table-based CV mortality × prior-event and CKD-stage multipliers × treatment HR |
| Non-CV death | Terminal | Gompertz approximation to US life tables |
| Treatment discontinuation | Once | Constant annual probability (treated arms) |
| Treatment waning | 4 steps | Scheduled after discontinuation |
| Age update | Yearly | Ageing, biomarker drift, background cost, hazard refresh |

All hazards are piecewise constant. Whenever the patient's state changes, all hazards are recomputed and pending event times are rescaled exactly by h_old/h_new (memorylessness).

## 4. Risk Equations

### 4.1 ASCVD and HF (PREVENT)
Exact 10-year PREVENT equations (Khan et al. 2024), HbA1c-enhanced model, sex-specific. The 10-year risk is converted to an annual hazard assuming a constant hazard. Inputs are winsorised to PREVENT's validated ranges (SBP 90–180, TC 130–320, HDL 20–100, BMI 18.5–39.9, eGFR 15–140, HbA1c 4.5–15); age is extrapolated beyond 79. Coefficients match `preventr` exactly (relative error ~1e-11).

### 4.2 MI vs stroke
ASCVD hazard is apportioned using the ratio of the PREVENT CHD and stroke sub-model hazards.

### 4.3 Background and CV mortality
Non-CV mortality: Gompertz (male 0.0001·e^(0.085·age); female 0.00006·e^(0.088·age)). CV mortality: (0.3/0.7) × non-CV hazard, multiplied by prior MI (2.0), stroke (2.5), HF (3.0) and CKD stage (3: 1.5; 4: 2.5; ESKD: 4.0).

### 4.4 CKD progression
Linear eGFR trajectory per patient. Slope = 0.65 mL/min/yr × (UACR/30)^0.451 × lognormal heterogeneity (SD 1.5, mean 1) × treatment slope ratio. Calibrated to the KFRE 2- and 5-year kidney failure risk (eGFR < 60).

### 4.5 Dynamic biomarkers
Yearly: SBP +0.5 mmHg; HbA1c +0.1% (diabetes only); age; eGFR from the trajectory. These feed back into PREVENT. Treatment effects on SBP/HbA1c/BMI are not added (captured by trial HRs).

## 5. Treatment Effects

| Effect | SGLT2i | GLP-1 RA |
|:--|:--|:--|
| MACE (MI, stroke) HR | 0.90 | 0.86 |
| HF hospitalisation HR | 0.68 | 0.91 |
| CV death HR | 0.84 | 0.88 |
| eGFR slope ratio | 0.63 | 0.81 |
| Annual discontinuation | 10% | 15% |
| Annual drug cost | $4,800 | $7,500 |

After discontinuation the drug cost stops and the effect wanes linearly to zero over 1 year.
In addition to class-level parameters, drug-specific parameters for 8 individual agents (empagliflozin, dapagliflozin, canagliflozin, sotagliflozin, semaglutide, liraglutide, dulaglutide, tirzepatide) are defined from landmark trial data and evaluated across a 16-comparison head-to-head matrix in CKM Stage 3.

## 6. Costs and Utilities

- **Ongoing costs**: background (MEPS; rises yearly with age above 50) + SoC + drug (separate accumulator `c_drug`, stops at discontinuation) + post-event (first MI/stroke/HF) + CKD-stage management (CKD 3, CKD 4; ESKD replaces CKD 4).
- **Instant costs**: acute MI, stroke, HF hospitalisation (each occurrence).
- **Ongoing utility**: baseline 0.84 minus chronic decrements (first MI/stroke/HF, CKD stage; ESKD decrement on top of CKD 4).
- **Instant disutility**: acute MI, stroke, HF events.

See [PARAMETER_SOURCES.md](PARAMETER_SOURCES.md) for all values, distributions, DSA ranges and citations.

## 7. Sensitivity Analyses

- **DSA**: One-way over all 48 uncertain parameters at DSA_min/DSA_max via WARDEN's built-in DSA (`analysis/run_dsa.R`, 12 shards), 20,000 patients — the same patients, seed and random numbers as the base case, so every bar is centred on the base case. INMB tornados (top 15) for SGLT2i vs SoC and SGLT2i vs GLP-1 RA.
- **PSA**: `analysis/run_psa.R`; 500 iterations × 1,000 patients in 10 chunks; CE planes, CEACs, convergence of mean INMB; 95% uncertainty intervals.
- **Scenarios** (`analysis/run_scenarios.R`, 20,000 patients): discount 0%/5%; Medicare negotiated prices (SGLT2i $2,364/y, GLP-1 RA $3,288/y); 10- and 20-year horizons; full persistence; no CV-death treatment effect; equal kidney effect; no kidney effect; chronic-eGFR-slope ratios (coded, off until placebo slopes are confirmed).
- **Agents** (exploratory): 8 agents in 4 runs; each agent vs SoC and the 16 SGLT2i-vs-incretin pairs (D-032).
- **Threshold prices**: exact annual break-even prices at $100K/$120K/$150K per QALY from the drug-cost accumulator (D-029).
- **Subgroups**: diabetes, eGFR, UACR, age, sex, Stage 3 risk-equivalent, from the base-case patient-level output (D-031).
- **Not modelled**: societal perspective, adverse events, combination therapy.

## 8. Validation

`R/10_validation.R`, `analysis/validate_minimal.R`, `tests/test_helpers.R`:
- PREVENT implementation vs `preventr` (all four equations, both models, unrounded).
- Kidney progression vs KFRE (2- and 5-year).
- Plausibility: life-years, event rates, ageing, ESKD proportion, arm ordering, PSA variation.
- External: simulated 10-year first MI/stroke and first HF hospitalisation in SoC vs mean baseline PREVENT prediction (`R/11_patient_outputs.R`).

## 9. Outputs

- Discounted costs, QALYs and LYs per arm; clinical event counts; ESKD proportion
- Pairwise incremental costs, QALYs, ICERs (with CE-plane quadrant) and INMB
- CEAC and CE plane (PSA)
- Tornado diagrams (DSA)
- Scenario comparison tables
