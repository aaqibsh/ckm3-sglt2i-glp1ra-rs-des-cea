#!/usr/bin/env Rscript
# =============================================================================
# CKM-HEOR: Scenario analyses (deterministic)
# =============================================================================
# Usage:  Rscript analysis/run_scenarios.R <stage> <group> [part] [n_parts]
#           group = structural | agents | all (default all)
#           part/n_parts split a group's scenarios across parallel processes
#         CKM_MODE=production Rscript analysis/run_scenarios.R 3 structural 1 2
# Sizes:  pilot 200 patients | production 20,000 (same patients and seed as base case)
#
# Structural scenarios (class-level inputs otherwise). Price scenarios (all
# commercial, all Medicare, Medicaid, self-pay, list prices, generic dapagliflozin)
# need no run: drug cost is linear in each price, so they are computed exactly from
# the base case (scripts/price_scenarios.R).
#   - Discount rates 0% and 5%; time horizon 10 and 20 years
#   - Full persistence; real-world discontinuation (1-year discontinuation in US
#     Medicare Advantage claims, Bowe 2025: SGLT2i 53.0%, GLP-1 RA 62.4%, every year)
#   - No CV death treatment effect (benefit on CV death only through fewer events
#     and slower CKD progression)
#   - Equal kidney effect; no kidney effect; kidney effect only with UACR >= 30 or
#     eGFR < 60
#   - Add-on SGLT2i at first HF hospitalization or CKD stage 4 in the SoC and GLP-1 RA arms
#   - SGLT2i stopped at kidney failure switched off (continued for life)
#   - Background mortality: Gompertz hazard read as all-cause, split 70/30 (major
#     cardiovascular diseases I00-I78 caused 28.6% of US deaths in 2022, NVSR 74(4))
#   - Half of incident HF hospitalized (52.8% of incident HF diagnosed in acute care,
#     inpatient or emergency department; Tisdale 2023, Veterans Health Administration)
#   - SGLT2i effects in patients without ASCVD (McGuire 2021 subgroup)
#   - GLP-1 RA effects from FLOW (semaglutide, T2D and CKD) at semaglutide prices
#   - Weight-related utility gain on treatment
#   - Optimized standard of care; PREVENT age capped at 79
#   - Combined conservative scenario (assumptions against SGLT2i together)
# Agent scenarios: the 8 agents (DRUG_SPECIFIC_INPUTS) in 4 runs. Arms are
#   simulated independently with common random numbers, so each run gives two
#   agents vs SoC and all 16 head-to-head pairs follow from the per-arm results
#   (analysis/combine_results.R).
# Outputs: outputs/tables/scenarios_stage<k>_<group>[_part<j>]_{arms,incremental}.csv,
#   outputs/tables/drug_specific_inputs.csv
# =============================================================================

cat("=== CKM-HEOR Scenario Analyses ===\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

source("R/00_setup.R")
source("R/01_parameters.R")
source("R/02_population.R")
source("R/03_risk_equations.R")
source("R/04_treatment.R")
source("R/07_costs_utilities.R")
source("R/05_events.R")
source("R/06_reactions.R")
source("R/08_run_model.R")
source("R/09_results.R")

args    <- commandArgs(trailingOnly = TRUE)
stages  <- stages_from_args()
group   <- if (length(args) >= 2) args[2] else "all"
part    <- if (length(args) >= 3) as.integer(args[3]) else 1L
n_parts <- if (length(args) >= 4) as.integer(args[4]) else 1L
stopifnot(group %in% c("structural", "agents", "all"), part >= 1, part <= n_parts)
n_pat <- RUN_SIZES$scen_patients

# Chronic eGFR slope ratios (on-treatment / placebo chronic slope). Left NA until
# the placebo chronic slopes are confirmed from the trial reports; the scenario
# is skipped while any value is NA.
CHRONIC_SLOPE_RATIOS <- c(sglt2i = NA_real_, glp1ra = NA_real_)

pv <- function(nm) l_params$base_value[[match(nm, unlist(l_params$parameter_name))]]

# GLP-1 RA effects from FLOW (Perkovic 2024; Pratley 2024): MACE 0.82 (0.68-0.98),
# HF events 0.73 (0.58-0.92), CV death 0.71 (0.56-0.89); kidney: ratio of total eGFR
# slopes, semaglutide vs placebo (about 0.65)
flow <- list(hr_glp1_mace = 0.82, hr_glp1_hf = 0.73, hr_glp1_cv_death = 0.71, glp1_egfr_slope_ratio = 0.65)
# SGLT2i in patients without ASCVD (McGuire 2021): MACE 0.94, HHF 0.63, CV death 0.95
no_ascvd <- list(hr_sglt2i_mace = 0.94, hr_sglt2i_hf = 0.63, hr_sglt2i_cv_death = 0.95)
# Weight-related utility: -0.0061 per BMI unit above 25 (Bagust and Beale 2005, TTO
# model). Placebo-adjusted weight change in T2D and CKD: semaglutide -4.10 kg at a
# baseline of 89.6 kg and BMI 32.0 (FLOW) = 1.46 BMI units; canagliflozin -0.80 kg at
# BMI 31.3 (CREDENCE) = about 0.29 BMI units
weight_util <- list(util_gain_glp1 = 0.009, util_gain_sglt2i = 0.002)

structural <- list(
  "Discount rate 0%"     = set_param_values(l_params, list(drc = 0, drq = 0)),
  "Discount rate 5%"     = set_param_values(l_params, list(drc = 0.05, drq = 0.05)),
  "Time horizon 10 years" = set_param_values(l_params, list(horizon_years = 10)),
  "Time horizon 20 years" = set_param_values(l_params, list(horizon_years = 20)),
  "Full persistence (no discontinuation)" = set_param_values(l_params, list(prob_disc_sglt2i = 0, prob_disc_glp1 = 0)),
  "Real-world discontinuation" = set_param_values(l_params, list(prob_disc_sglt2i = 0.530, prob_disc_glp1 = 0.624)),
  "No CV death treatment effect" = set_param_values(l_params, list(hr_sglt2i_cv_death = 1, hr_glp1_cv_death = 1)),
  "Equal kidney effect" = set_param_values(l_params, list(glp1_egfr_slope_ratio = pv("sglt2i_egfr_slope_ratio"))),
  "No kidney effect" = set_param_values(l_params, list(sglt2i_egfr_slope_ratio = 1, glp1_egfr_slope_ratio = 1)),
  "Kidney effect only with albuminuria or eGFR <60" = set_param_values(l_params, list(kidney_effect_restrict = 1)),
  "Add-on SGLT2i at HF hospitalization or CKD stage 4" = set_param_values(l_params, list(addon_sglt2i = 1)),
  "SGLT2i continued after kidney failure" = set_param_values(l_params, list(stop_sglt2i_at_kf = 0)),
  "Background mortality as all-cause (70% noncardiovascular)" = set_param_values(l_params, list(bg_mort_mult = 0.7)),
  "Half of incident HF hospitalized" = set_param_values(l_params, list(hf_hosp_frac = 0.5)),
  "SGLT2i effects without ASCVD" = set_param_values(l_params, no_ascvd),
  "GLP-1 RA effects from FLOW" = set_param_values(l_params, flow),
  "Weight-related utility gain" = set_param_values(l_params, weight_util),
  "Optimized standard of care" = set_param_values(l_params, list(soc_optimized = 1)),
  "PREVENT age capped at 79 years" = set_param_values(l_params, list(prevent_age_cap = 79)),
  "Combined conservative" = set_param_values(l_params, c(list(addon_sglt2i = 1, bg_mort_mult = 0.7,
                                                              hf_hosp_frac = 0.5), no_ascvd, flow, weight_util))
)
if (!anyNA(CHRONIC_SLOPE_RATIOS)) {
  structural[["Chronic eGFR slope ratios"]] <- set_param_values(l_params, list(
    sglt2i_egfr_slope_ratio = CHRONIC_SLOPE_RATIOS[["sglt2i"]],
    glp1_egfr_slope_ratio   = CHRONIC_SLOPE_RATIOS[["glp1ra"]]))
}

capitalize <- function(x) paste0(toupper(substr(x, 1, 1)), substr(x, 2, nchar(x)))
agent_pairs <- list(c("empagliflozin", "semaglutide"), c("dapagliflozin", "liraglutide"),
                    c("canagliflozin", "dulaglutide"), c("sotagliflozin", "tirzepatide"))
agents <- setNames(lapply(agent_pairs, function(p) build_drug_specific_params(p[1], p[2])),
                   vapply(agent_pairs, function(p) sprintf("Agents: %s; %s", capitalize(p[1]), p[2]), ""))

scenarios <- switch(group, structural = structural, agents = agents, all = c(structural, agents))
idx <- seq_along(scenarios)
scenarios <- scenarios[idx %% n_parts == (part - 1) %% n_parts]
suffix <- if (group == "all") "" else paste0("_", group, if (n_parts > 1) paste0("_part", part) else "")
cat(sprintf("Group %s, part %d/%d: %s\n", group, part, n_parts, paste(names(scenarios), collapse = " | ")))

dir.create("outputs/tables", recursive = TRUE, showWarnings = FALSE)
fwrite(DRUG_SPECIFIC_INPUTS, "outputs/tables/drug_specific_inputs.csv")

for (stage in stages) {
  cat(sprintf("\n===== CKM Stage %d: %d patients =====\n", stage, n_pat))
  arm_rows <- list()
  inc_rows <- list()
  t_run <- system.time(for (sc in names(scenarios)) {
    t_sc <- system.time(
      res <- suppressMessages(run_ckm_model(ckm_stage = stage, n_patients = n_pat,
                                            seed = SEED, params = scenarios[[sc]], ipd_level = 0))
    )
    s <- summarise_deterministic(res, wtp = WTP_THRESHOLD)
    arm_rows[[sc]] <- s$arms[, `:=`(scenario = sc, stage = stage)]
    inc_rows[[sc]] <- s$incremental[, `:=`(scenario = sc, stage = stage)]
    cat(sprintf("  %s: %.1f minutes\n", sc, t_sc[3] / 60))
  })

  arm_tab <- rbindlist(arm_rows); setcolorder(arm_tab, c("stage", "scenario"))
  inc_tab <- rbindlist(inc_rows); setcolorder(inc_tab, c("stage", "scenario"))
  print(inc_tab[, .(scenario, comparison, inc_cost = round(inc_cost), inc_qaly = round(inc_qaly, 3),
                    icer_label, inmb = round(inmb))])
  cat(sprintf("Run time: %.1f minutes\n", t_run[3] / 60))

  fwrite(arm_tab, sprintf("outputs/tables/scenarios_stage%d%s_arms.csv", stage, suffix))
  fwrite(inc_tab, sprintf("outputs/tables/scenarios_stage%d%s_incremental.csv", stage, suffix))
}

cat("\n=== Scenarios Complete ===\n")
cat("End time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
