# AGENTS.md — CKM-HEOR Project

> **Project**: Health Economic Model for Cardiovascular-Kidney-Metabolic (CKM) Syndrome  
> **Status**: Revision after external pre-submission review (Oct 2026). Phase 1 (model code) done; Stage 3 production rerun complete (15 Oct 2026; results in `outputs/`, figures in `manuscript/figures/`). Manuscript Phases 2–4 done 15 Oct 2026; agent inputs corrected and agent runs rerun 16 Oct (D-033). Deliverables in `manuscript/revised/`, log and open items in `manuscript/NOTES.md`; only author items (title page, contributions, COI) remain.  
> **Engine**: WARDEN DES v2.0.6 (R package)  
> **Last Updated**: 2026-10-23 (R2: second pre-submission review; branch r2-revision; plan in manuscript/R2_PLAN.md)

---

## Project Overview

This project builds a **patient-level Discrete Event Simulation (DES)** to evaluate the cost-effectiveness of **SGLT2 inhibitors vs GLP-1 receptor agonists** in US adults with CKM Syndrome, using the **WARDEN** R package as the simulation engine.

### Clinical Basis
- **2026 AHA/ACC/ADA/ASN CKM Guideline** (Ndumele et al.) — defines CKM stages, treatment recommendations
- **PREVENT risk equations** (Khan et al. 2024) — exact 10-year equations (ASCVD, HF, CHD/stroke split), verified against `preventr`
- **KFRE** (Tangri et al.) — calibration target for kidney progression

### Key Design Decisions (Locked)
| Decision | Choice |
|:---|:---|
| Engine | WARDEN DES (CRAN-published) |
| Comparison | Class-level SGLT2i vs GLP-1 RA (base); 8-drug 16-pair matrix (Stage 3 scenario) |
| Population | CKM Stages 2, 3 (primary focus), 4a — three separate analyses |
| Arms | 3-arm: SGLT2i+SoC vs GLP-1 RA+SoC vs SoC alone |
| Outcomes | MACE (MI/stroke), HF hospitalisation, CKD→ESKD, mortality |
| Perspective | US healthcare sector (societal not modelled) |
| Horizon | Lifetime (base); 10- and 20-year (scenarios) |
| Discount | 3% costs and outcomes |
| WTP | $120,000/QALY (US standard) |

---

## File Structure

```
RS_CKM/
├── AGENTS.md                    # THIS FILE — project guide
├── GEMINI.md                    # Workspace rules (WARDEN-ref read-only)
├── R/                           # Model source code
│   ├── 00_setup.R               # Package loading, config constants
│   ├── 01_parameters.R          # Master parameters (input_block, PSA distributions)
│   ├── 02_population.R          # Synthetic CKM population generator
│   ├── 03_risk_equations.R      # PREVENT-like risk equations, mortality
│   ├── 04_treatment.R           # Treatment-effect, waning, rescaling, eGFR-trajectory helpers
│   ├── 05_events.R              # WARDEN init_event_list (TTE draws)
│   ├── 06_reactions.R           # WARDEN evt_react_list (event logic)
│   ├── 07_costs_utilities.R     # Cost/utility accumulator definitions
│   ├── 08_run_model.R           # Main orchestrator — calls WARDEN::run_sim()
│   ├── 09_results.R             # Pairwise comparisons, DSA extraction, tornado, CE plane, CEAC
│   ├── 10_validation.R          # Validation checks (incl. PREVENT vs preventr, KFRE)
│   └── 11_patient_outputs.R     # Patient-level summary → subgroups, event rates, PREVENT validation
├── analysis/                    # Run scripts
│   ├── validate_minimal.R       # 12 end-to-end checks (~15 s) — run after every change
│   ├── run_base_case.R          # Deterministic base case [stage]
│   ├── run_scenarios.R          # <stage> <structural|agents> [part n_parts]
│   ├── run_dsa.R                # 50-parameter one-way DSA <stage> [shard n_shards]
│   ├── run_psa.R                # PSA <stage> [chunk], chunked and resumable
│   ├── combine_results.R        # Merge shards/chunks → Stage 3 tables, figures, RESULTS_SUMMARY.md
│   ├── pilot_test.R, run_status.R, validate_fixes.R  # Earlier phase checks (still run)
├── scripts/
│   ├── generate_manuscript_figures.R  # Figures 1–3 from outputs/tables (run after download)
│   ├── price_scenarios.R              # Payer price scenarios, thresholds, two-way price chart (no simulation)
│   ├── derive_manuscript_tables.R     # Baseline, event-rate, PREVENT and Monte Carlo tables from outputs (no simulation)
│   └── make_parameter_table.R         # eTable 3 + docs/PARAMETER_SOURCES.md from the code
├── manuscript/                  # Word manuscript, supplement, checklist, reviewer table, REVISION_PLAN.md (not in git)
├── tests/
│   └── test_helpers.R           # Unit checks for pure helper functions
├── .github/workflows/ckm-run.yml   # GitHub Actions production workflow
├── .github/actions/setup-ckm/    # Shared R 4.5.1 + package setup (cached binaries)
├── ci/check_versions.R          # Fails the cloud run unless WARDEN 2.0.6 / preventr 0.12.0
├── ci/run_parallel.sh           # Runs 2 R processes per cloud job (both vCPUs)
├── DESCRIPTION                  # R dependency list for GitHub Actions (not a package)
├── docs/                        # Documentation
│   ├── MODEL_SPECIFICATION.md   # Technical specification
│   ├── GITHUB_ACTIONS_GUIDE.md  # Step-by-step cloud run instructions
│   ├── PARAMETER_SOURCES.md     # Generated parameter table with sources
│   └── DECISION_LOG.md          # Design decisions with rationale (D-001 to D-036)
├── outputs/                     # Generated results (git-ignored; archive_pre_github/ = earlier pilots)
├── backup_phase4/               # Snapshot of R/, analysis/, docs/ before Phase 5 changes
├── WARDEN-ref -> ...            # READ-ONLY local copy of the WARDEN source (not in the repository)
└── ndumele-et-al-2026-...epub   # CKM guideline document (not in the repository)
```

---

## Module Dependency Chain

```
00_setup.R → (loads packages)
01_parameters.R → (standalone; l_params, DRUG_SPECIFIC_INPUTS, build_drug_specific_params())
02_population.R → (standalone, uses data.table)
03_risk_equations.R → (standalone, pure functions)
04_treatment.R → (standalone, pure functions)
07_costs_utilities.R → (standalone, pure functions)
05_events.R → (requires WARDEN loaded, references runtime vars)
06_reactions.R → (requires WARDEN loaded, references runtime vars)
08_run_model.R → (orchestrates all above + calls WARDEN::run_sim)
09_results.R → (requires WARDEN for summary functions)
10_validation.R → (requires results object)
```

---

## How to Run

All scripts take an optional CKM stage argument and read sizes from `CKM_MODE` (`pilot` default, `production`), defined in `R/00_setup.R`.

| Run | pilot | production |
|:--|:--|:--|
| Base case (`run_base_case.R 3`; keeps patient-level output) | 500 pts | 20,000 pts |
| Scenarios (`run_scenarios.R 3 structural|agents [part n_parts]`: 20 structural + 4 agent runs) | 200 pts | 20,000 pts |
| DSA (`run_dsa.R 3 [shard 26]`: 50 parameters, 26 shards) | 500 pts | 20,000 pts (= base case) |
| Price scenarios (`scripts/price_scenarios.R`, post-processing) | — | exact from the base case |
| PSA (`run_psa.R 3 [chunk]`: 10 chunks, seeds 101–149) | 10 × 2 sims × 100 pts | 10 × 50 sims × 1,000 pts = 500 iterations |

### Check after every change (~20 seconds)
```bash
Rscript tests/test_helpers.R
Rscript analysis/validate_minimal.R
```

### Production run — GitHub Actions (chosen approach)
Step-by-step instructions: `docs/GITHUB_ACTIONS_GUIDE.md`. Workflow `.github/workflows/ckm-run.yml` (manual trigger, input `mode`; Stage 3 only): tests → base case (alone; ~5 GB) + 2 scenario jobs + 6 DSA jobs + 5 PSA jobs, two R processes per job (`ci/run_parallel.sh`) → combine → artifact `ckm-results-<mode>` and results on the run's Summary page. Always run `mode=pilot` first. Private-repo runners: 2 vCPU / 7 GB, 6 h job limit, 20 concurrent jobs, 2,000 free minutes per month (production ≈ 1,150). After downloading: `Rscript scripts/generate_manuscript_figures.R` and `Rscript scripts/make_parameter_table.R`.
DSA jobs that hit the 5.5 h limit on a slow runner: rerun only those shards with `task=dsa-shards` (one parameter per R process; reuses the earlier run's `ckm-results-<mode>` artifact; see the guide). Production run 38523665536 (14 Oct 2026) finished everything except DSA shards 7+8 (time limit); those 8 parameters were run on the laptop on 15 Oct (`run_dsa.R 3 <7|8> 12 <part> 4`, identical patients and seeds) and combined with the run's `ckm-results-production` artifact. Earlier outputs are in `outputs_archive_20261015/`.

### Production run — locally (alternative)
```bash
CKM_MODE=production Rscript analysis/run_base_case.R 3
CKM_MODE=production Rscript analysis/run_scenarios.R 3 structural
CKM_MODE=production Rscript analysis/run_scenarios.R 3 agents
CKM_MODE=production Rscript analysis/run_dsa.R 3          # all 26 shards in turn
CKM_MODE=production Rscript analysis/run_psa.R 3          # all chunks; resumable
Rscript analysis/combine_results.R
```
Single core throughout: ~0.02 s per patient per simulation on the M2 (~30 h total at production sizes — use GitHub Actions). `run_ckm_model(n_cores = )` exists but is not used by the scripts.

---

## Current Status & Known Issues

### ✅ Working
- Population generation for CKM Stages 2, 3, 4a (eGFR truncated at 20; HbA1c consistent with diabetes status)
- **Exact PREVENT equations** (ASCVD, HF, CHD, stroke; base + HbA1c models) — identical to `preventr` (relative error ~1e-11); inputs winsorised to validated ranges, age extrapolated
- **Recurrent events** with persistent, compounding recurrence multipliers
- **Continuous eGFR trajectory** calibrated to KFRE; CKD progression at eGFR 60/30/15; treatment as slope ratio
- **Exact hazard rescaling** at every state change (ageing, biomarkers, events, CKD stage, waning); CRN across arms and DSA analyses
- **Treatment discontinuation waning** (linear over 1 year, 4 steps)
- **Dynamic biomarkers** (SBP, HbA1c drift; eGFR trajectory) feeding PREVENT
- **PSA** via `input_block()`; **DSA** via WARDEN built-in (50 parameters); **drug-specific scenarios**
- Results: pairwise increments with CE-plane quadrant labels, INMB, tornado, CE plane, CEAC
- Validation: 12 end-to-end checks + helper unit checks

### 🔄 Phase 8 — R2 after second pre-submission review (2026-10-23; code done, production rerun pending)
1. **Prices by payer and age** (commercial before 65, Medicare from 65), exact price scenarios and thresholds by payer, two-way price chart (D-034).
2. **SGLT2i stopped at kidney failure**; 20 structural scenarios incl. add-on SGLT2i (sequencing), background mortality, FLOW-based GLP-1 RA effects, real-world discontinuation, combined conservative (D-035).
3. **PSA** widened (kidney heterogeneity, UACR exponent, correlated class HRs); DSA 50 parameters in 26 shards.
4. Manuscript R2 work in `manuscript/revised/R2/` (plan `manuscript/R2_PLAN.md`).

### ✅ Phase 7 — Revision after external review (2026-10-14; code done, rerun pending)
1. **Class HRs corrected** to McGuire 2021 / Sattar 2021 (SGLT2i CV death 0.85; GLP-1 RA HHF 0.89, CV death 0.87) (D-027).
2. **Production configuration**: 20,000 patients for every deterministic run; DSA over all 48 uncertain parameters centred on the base case; PSA 500 × 1,000; Stage 3 only (D-028).
3. **Drug cost accumulator `c_drug`** and exact threshold prices (D-029).
4. **Scenarios**: discount 0/5%, Medicare negotiated prices, 10/20-year horizon (`horizon_years`), full persistence, no CV-death effect, equal / no kidney effect; chronic-slope scenario coded but off (D-030).
5. **Patient-level outputs** (`R/11_patient_outputs.R`): subgroups, event rates, PREVENT 10-year validation, Stage 3 risk-equivalent share (D-031).
6. **Agents** from 4 runs, 16 pairs computed (D-032). Figures and eTable 3 generated from outputs/code (`scripts/`).

### ✅ Completed in Phase 6 (2026-10-01)
1. **8-Drug Scenario Expansion**: Expanded `DRUG_SPECIFIC_INPUTS` in `R/01_parameters.R` from 4 to 8 agents (4 SGLT2i/dual: empagliflozin, dapagliflozin, canagliflozin, sotagliflozin; 4 incretins/dual: semaglutide, liraglutide, dulaglutide, tirzepatide).
2. **Clinical Endpoint Verification & Audit**: Corrected parameter conflations (SCORED MACE 0.84, SURPASS CV death 0.90 / HHF 0.67, FLOW renal composite 0.76, CREDENCE renal composite 0.70; all 2026/2027 Medicare MFP and WAC ranges verified).
3. **Continuous eGFR Trajectory Modeling (D-015)**: Confirmed and documented that trial composite renal HRs proxy relative attenuation of the chronic decline slope.
4. **Stage 3 Production Head-to-Head Suite (5,000 patients)**: Executed all 16 pairwise head-to-head scenarios + 3 references in CKM Stage 3. SGLT2i universally cost-effective/dominant vs incretin therapies (INMB +$12K to +$35K).
5. **Baseline Artifact Synchronization**: Fully merged cloud GitHub Actions production results (500-iteration PSA across all stages, one-way DSA, deterministic base cases) with newly computed Stage 3 scenarios in `outputs/RESULTS_SUMMARY.md`.

### ✅ Fixed in Phase 5 (2026-09-28)
1. **PREVENT validation**: apparent failures were `preventr` 3-decimal rounding; validation now unrounded, all 4 equations × 2 models.
2. **CKD progression logic**: stage 1 advanced to a non-existent stage 2; stage 3→4 fired 0.1 y later; untreated slope used after first progression; ESKD scheduled independently of CKD stage. Replaced by a single eGFR trajectory.
3. **Kidney calibration**: 5-year kidney failure 18.6% vs KFRE 6.2%; ~43% lifetime ESKD in SoC. Now 4.3% vs 4.4%; ~8–10% lifetime.
4. **SGLT2i eGFR benefit**: absolute 1.5 mL/min/yr subtraction floored at 0.1 (≈10× slower decline at preserved eGFR). Now slope ratio from SMART-C / Badve 2024.
5. **ESKD cost** double-counted with CKD 4 cost. ESKD now replaces it.
6. **Recurrence multiplier** was undone at the next age update. Now persistent state.
7. **CV death** did not respond to prior events/CKD stage until the next yearly update. Now immediate.
8. **Unused parameters** `hr_sglt2i_mort`, `hr_glp1_mort` removed; dead helpers in `04_treatment.R` and `07_costs_utilities.R` removed.
9. **Seeds** in `run_base_case.R`/`run_psa.R` (12345) would overflow at production size; now 42.

### ✅ Fixed in Phase 4 (2026-09-28)
1. PSA `rlnorm_mse` → `rlnorm`. 2. Exact PREVENT coefficients. 3. CV mortality double counting. 4. Recurrence hazard state. 5. Multi-stage CKD. 6. CRN for CKD noise. 7–9. Results/validation/pilot script fixes.

### ✅ Fixed in Phase 3A (2026-09-26)
1. `draw_tte("exp")` log-scale `coef1`. 2. `draw_tte("gompertz")` parameters. 3. Discontinuation direction.

### ⚠️ Known Limitations (Remaining)
1. **Monte Carlo error**: at 500 patients the SE of the Stage 3 SGLT2i vs SoC ICER is ~$7K (INMB ~$2.4K); PSA at 500 patients per iteration somewhat overstates parameter uncertainty. Stage 2 SGLT2i vs SoC (pilot INMB ~+$4K) is the least robust conclusion.
2. **Kidney calibration by eGFR band**: under-predicts kidney failure at eGFR 20–30 and over-predicts at 45–60 (single decline rate across stages).
3. **Mortality**: non-CV Gompertz hazard exceeds US all-cause mortality at age 62 (~1.9% vs ~1.5% men); implicitly includes excess CKM mortality but is not calibrated to a CKM-specific target.
4. **PREVENT 10-year → annual hazard**: the constant-hazard conversion assigns the 10-year average hazard to the current age (slight upward bias, partly offset by yearly updates).
5. **Structural assumptions without direct sources**: recurrence multipliers, CV mortality multipliers, biomarker drift — parameterised with wide DSA/PSA ranges.
6. **Drug prices**: commercial SGLT2i price is brand acquisition cost without rebate (CMS NADAC); commercial GLP-1 RA price is the SSR Health semaglutide net price (ICER 2025); rebates are confidential (D-034).
7. **Not implemented**: societal perspective; adverse events and treatment disutilities; combination SGLT2i + GLP-1 RA arm; network-meta-analysis inputs for the agent comparison.

---

## External References

### Read-Only Reference
- **WARDEN-ref** → a local, read-only copy of the WARDEN source (github.com/jsanchezalv/WARDEN); not part of this repository
- Contains source code for the WARDEN DES engine
- The Lin & Briggs CVD case study (`vignettes/articles/example_ScotCVD_LinBriggs.Rmd`) was the primary template for this model
- **NEVER modify** files in this directory

### CKM Guideline
- **ndumele-et-al-2026-...epub** — 2026 AHA/ACC/ADA/ASN CKM Guideline
- Defines CKM staging (0–4), PREVENT equations, treatment recommendations
- Contains economic value statements with ICERs for both drug classes

---

## Agent Instructions

When working on this project:
1. **Source files in order**: 00_setup → 01_parameters → 02_population → 03_risk → 04_treatment → 07_costs → 05_events → 06_reactions → 08_run_model (→ 09_results, 10_validation)
2. **WARDEN API**: Uses `add_item(input={...})`, `add_tte(arm=..., evts=..., input={...})`, `add_reactevt(name_evt=..., input={...})`. Expressions inside `input={}` use **delayed execution** — variables are resolved at WARDEN runtime.
3. **Scoping**: `df_pop` must be assigned to `globalenv()` for WARDEN's delayed execution to access it. See `08_run_model.R` line 36.
4. **WARDEN forbidden names**: Do NOT use `arm_list`, `i`, `curtime`, `arm`, `evt`, `simulation`, `sens`, `npats`, `ipd` as input variable names — they are reserved by WARDEN.
5. **Seed constraint**: WARDEN's seed * n_sim * 1007 + seed * npats * 349 must not overflow R's integer max. Use small seeds (< 100) with large patient counts.
6. **Drug prices**: never compute drug cost by hand; prices change by payer at `age_medicare` (`medicare` event) and are split into `c_drug_com`/`c_drug_mcr`. Price scenarios use `reprice()`.
7. **State changes go through the helpers**: in reactions, call `refresh_kidney(environment())` after anything that changes the eGFR slope, and `refresh_hazards(environment())` after anything that changes event hazards. Never modify pending event times by hand.
8. **Parameters**: add new parameters as rows in `build_param_lists()` (optional 8th/9th elements are PSA/DSA indicators), give them a label in `PARAM_LABELS` (09_results.R), then regenerate `docs/PARAMETER_SOURCES.md`. `run_ckm_model(params = ...)` injects the lists into `input_block()` by value.
9. **add_item pipe gotcha**: `add_item()` only evaluates a pipe LHS that is a symbol or an `add_item()`/`input_block()` call; assign other blocks to a variable first.
