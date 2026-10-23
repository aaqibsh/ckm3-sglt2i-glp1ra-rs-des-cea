# Cost-effectiveness of SGLT2 inhibitors vs GLP-1 receptor agonists in CKM syndrome stage 3

Individual-level discrete event simulation of US adults with cardiovascular-kidney-metabolic (CKM) syndrome stage 3, comparing an SGLT2 inhibitor (SGLT2i) plus standard of care (SoC), a GLP-1 receptor agonist (GLP-1 RA) plus SoC, and SoC alone, from the US health care sector perspective over a lifetime horizon. This repository holds the model code behind the manuscript of the same title (under review).

## Model in brief

- Engine: the WARDEN discrete event simulation package for R (version 2.0.6).
- Events: myocardial infarction, stroke and heart failure hospitalization (recurrent), CKD progression and kidney failure, cardiovascular and noncardiovascular death, treatment discontinuation.
- Event risks: PREVENT 10-year equations (with HbA1c), implemented from the published coefficients and checked against the `preventr` package (relative difference below 1e-10).
- Kidney function: a linear eGFR trajectory per patient, scaled by albuminuria and calibrated to the Kidney Failure Risk Equation; treatment effects act as ratios on the rate of decline.
- Treatment effects: class-level meta-analyses of outcome trials; drug prices by payer (commercial before age 65, Medicare negotiated prices from 65).
- Uncertainty: one-way sensitivity analysis over 50 parameters, probabilistic sensitivity analysis (500 iterations × 1,000 patients), structural and price scenarios, subgroups.

Full specification: `docs/MODEL_SPECIFICATION.md`. Every input with its distribution, range and source: `docs/PARAMETER_SOURCES.md` (generated from the code). Design decisions and their rationale: `docs/DECISION_LOG.md`.

## Repository layout

| Folder | Contents |
|:--|:--|
| `R/` | Model: parameters, population, risk equations, treatment helpers, events, reactions, costs and utilities, orchestration, results, validation, patient-level outputs |
| `analysis/` | Run scripts: base case, scenarios, one-way DSA, PSA, combining results, validation checks |
| `scripts/` | Post-processing: price scenarios and thresholds, manuscript tables and figures, parameter table |
| `tests/` | Unit checks of helper functions |
| `.github/`, `ci/` | GitHub Actions workflow that runs the full analysis in the cloud |

## Reproducing the results

Requirements: R 4.5.1 with the packages listed in `DESCRIPTION` (WARDEN 2.0.6, preventr 0.12.0).

```bash
Rscript tests/test_helpers.R            # unit checks (seconds)
Rscript analysis/validate_minimal.R     # 12 end-to-end checks (about 20 s)
```

Sizes are set by the environment variable `CKM_MODE` (`pilot`, the default, for quick checks; `production` for the published sizes: 20,000 patients for every deterministic run).

```bash
CKM_MODE=production Rscript analysis/run_base_case.R 3
CKM_MODE=production Rscript analysis/run_scenarios.R 3 structural
CKM_MODE=production Rscript analysis/run_scenarios.R 3 agents
CKM_MODE=production Rscript analysis/run_dsa.R 3
CKM_MODE=production Rscript analysis/run_psa.R 3
CKM_MODE=production Rscript analysis/combine_results.R
Rscript scripts/price_scenarios.R
```

On a single core the production analysis takes more than a day. The workflow `.github/workflows/ckm-run.yml` runs the same scripts in parallel on GitHub Actions (Actions tab, "CKM model run", mode `pilot` first, then `production`); results are uploaded as the artifact `ckm-results-<mode>` and summarised on the run page. Common random numbers and fixed seeds make every run reproducible.

## Development and use of AI tools

The model code, checks and documentation were developed with the assistance of AI coding tools (Anthropic Claude Code; Google Gemini). `AGENTS.md` and `GEMINI.md` are the working instructions given to these tools and are kept for transparency. All code was reviewed by the authors and verified with the unit checks, the end-to-end checks, and comparison of the PREVENT implementation with the `preventr` package.

## Licence

MIT (see `LICENSE`). WARDEN (GPL ≥ 3) and preventr (MIT) are used as installed R packages and are not redistributed here.
