# =============================================================================
# File: 08_run_model.R
# Purpose: Main orchestrator — ties all modules together and calls WARDEN
# Author: CKM-HEOR Team
# Date: 2026-09-28 (revised — params argument, built-in DSA, eGFR trajectory,
#       arm-generic treatment effects)
# =============================================================================

#' Build the input_block() for the model parameters
#'
#' @description input_block() captures its arguments unevaluated and WARDEN
#'   evaluates them at run time, so the parameter lists are injected as literal
#'   values (bquote) rather than referenced by name. This lets any parameter set
#'   (class-level, drug-specific) be passed to run_ckm_model().
#'
#' @param .data Existing add_item() block to append to
#' @param params Parameter lists from build_param_lists() / build_drug_specific_params()
#' @param dsa Logical; attach DSA_min/DSA_max so WARDEN can run a one-way DSA
build_params_block <- function(.data, params, dsa = FALSE) {
  eval(bquote(input_block(
    .data           = .(.data),
    base            = .(params$base_value),
    psa             = pick_psa(.(params$PSA_dist), .(params$n), .(params$a), .(params$b)),
    sens            = .(if (dsa) params[c("DSA_min", "DSA_max")] else NULL),
    names_out       = .(params$parameter_name),
    psa_indicators  = .(params$psa_indicators),
    sens_indicators = .(params$dsa_indicators),
    indicator_sens_binary = TRUE,
    dsa_names       = .(if (dsa) c("DSA_min", "DSA_max") else NULL)
  )))
}

#' Run the CKM-HEOR Model
#'
#' @description Orchestrates the full CKM discrete event simulation:
#'   generates population, builds WARDEN inputs, runs simulation, returns results.
#'
#' @param ckm_stage Integer (2, 3, or 4). CKM stage for population cohort.
#' @param n_patients Integer. Number of patients per arm.
#' @param n_sim Integer. Number of PSA iterations (1 for deterministic).
#' @param psa_bool Logical. Whether to sample from PSA distributions.
#' @param seed Integer. Random seed for reproducibility. Keep < 100 for large runs.
#' @param arms_to_run Character vector. Treatment arms to simulate.
#' @param params Parameter lists (default: class-level l_params).
#' @param dsa Logical. Run WARDEN's one-way DSA: one analysis per parameter with
#'   dsa_indicators = 1, at DSA_min then DSA_max (results[[k]], k = 1..2*n_dsa).
#' @param ipd_level WARDEN patient-level data (passed as run_sim(ipd); named
#'   differently because WARDEN forbids a variable called `ipd` in scope): 1 = full event log per simulation
#'   (~18 KB per patient per simulation), 0 = aggregate results only. Use 0 for
#'   large PSA runs to keep memory bounded.
#' @param n_cores Integer. 1 = WARDEN::run_sim(); > 1 = WARDEN::run_sim_parallel()
#'   with that many worker processes (parallelises over simulations, so only
#'   useful for PSA).
#'
#' @return WARDEN simulation results object
run_ckm_model <- function(
  ckm_stage  = 3,
  n_patients = 1000,
  n_sim      = 1,
  psa_bool   = FALSE,
  seed       = 42,
  arms_to_run = c("sglt2i", "glp1ra", "soc"),
  params     = l_params,
  dsa        = FALSE,
  ipd_level  = 1,
  n_cores    = 1
) {

  cat(sprintf("  CKM Stage: %d | Patients: %d | Sims: %d | PSA: %s | DSA: %s\n",
              ckm_stage, n_patients, n_sim, psa_bool, dsa))

  # ---- 1. Generate patient population ----
  df_pop <- generate_ckm_population(n_patients, ckm_stage, seed = seed)
  # WARDEN evaluates delayed expressions in an environment chain that
  # ultimately reaches the global environment. Assign df_pop there so it's visible.
  assign("df_pop", df_pop, envir = globalenv())
  cat(sprintf("  Population generated: %d patients\n", nrow(df_pop)))

  # ---- 2. Build common_all_inputs (global parameters) ----
  # Discount rates drc/drq are model parameters (DSA-varied, not PSA).
  # (add_item() only evaluates a pipe LHS that is a symbol or an add_item()/
  # input_block() call, so the injected block is assigned to a variable first.)
  params_block <- build_params_block(add_item(input = {}), params, dsa)
  # log-scale means and SEs of the class HR distributions, for correlated PSA draws
  pv <- setNames(seq_along(params$parameter_name), unlist(params$parameter_name))
  hr_names <- list(sglt2i = c("hr_sglt2i_mace", "hr_sglt2i_hf", "hr_sglt2i_cv_death"),
                   glp1ra = c("hr_glp1_mace", "hr_glp1_hf", "hr_glp1_cv_death"))
  hr_psa_spec <- lapply(hr_names, function(nm) list(
    mu = setNames(unlist(params$a[pv[nm]]), nm), se = setNames(unlist(params$b[pv[nm]]), nm)))
  assign("hr_psa_spec", hr_psa_spec, envir = globalenv())

  common_all_inputs <- params_block |>
  add_item(input = {
    # ---- Correlated class HRs in the PSA (psa_hr_rho; marginals unchanged) ----
    if (psa_bool && psa_hr_rho > 0) {
      z_sg <- rnorm(1)
      z_gl <- rnorm(1)
      hr_sg <- correlate_log_hrs(c(hr_sglt2i_mace = hr_sglt2i_mace, hr_sglt2i_hf = hr_sglt2i_hf,
                                   hr_sglt2i_cv_death = hr_sglt2i_cv_death),
                                 hr_psa_spec$sglt2i$mu, hr_psa_spec$sglt2i$se, z_sg, psa_hr_rho)
      hr_gl <- correlate_log_hrs(c(hr_glp1_mace = hr_glp1_mace, hr_glp1_hf = hr_glp1_hf,
                                   hr_glp1_cv_death = hr_glp1_cv_death),
                                 hr_psa_spec$glp1ra$mu, hr_psa_spec$glp1ra$se, z_gl, psa_hr_rho)
      hr_sglt2i_mace <- hr_sg[["hr_sglt2i_mace"]]
      hr_sglt2i_hf <- hr_sg[["hr_sglt2i_hf"]]
      hr_sglt2i_cv_death <- hr_sg[["hr_sglt2i_cv_death"]]
      hr_glp1_mace <- hr_gl[["hr_glp1_mace"]]
      hr_glp1_hf <- hr_gl[["hr_glp1_hf"]]
      hr_glp1_cv_death <- hr_gl[["hr_glp1_cv_death"]]
    }

    # ---- Derived parameters (computed from PSA/DSA-sampled values) ----
    # Treatment discontinuation: convert annual probability to rate
    rate_disc_sglt2i <- -log(1 - prob_disc_sglt2i)
    rate_disc_glp1   <- -log(1 - prob_disc_glp1)

    cvd_mult <- c(mi = cvd_mult_mi, stroke = cvd_mult_stroke, hf = cvd_mult_hf,
                  ckd3 = cvd_mult_ckd3, ckd4 = cvd_mult_ckd4, eskd = cvd_mult_eskd)

    # Waning is applied in 4 equal steps over tx_wane_years
    n_wane_steps <- 4
  })

  # ---- 3. Build common_pt_inputs (per-patient, arm-independent) ----
  # Evaluated ONCE per patient; everything random here is shared across arms.
  common_pt_inputs <- add_item(input = {
    # Patient demographics from population data.table
    pt_age     <- df_pop$age[as.numeric(i)]
    pt_sex     <- df_pop$sex[as.numeric(i)]
    pt_bmi     <- df_pop$bmi[as.numeric(i)]
    pt_sbp     <- df_pop$sbp[as.numeric(i)]
    pt_egfr    <- df_pop$egfr[as.numeric(i)]
    pt_hba1c   <- df_pop$hba1c[as.numeric(i)]
    pt_tc      <- df_pop$total_chol[as.numeric(i)]
    pt_hdl     <- df_pop$hdl_chol[as.numeric(i)]
    pt_dm      <- df_pop$diabetes[as.numeric(i)]
    pt_smk     <- df_pop$smoking[as.numeric(i)]
    pt_statin  <- df_pop$statin_use[as.numeric(i)]
    pt_antihyp <- df_pop$antihyp_use[as.numeric(i)]
    pt_uacr    <- df_pop$uacr[as.numeric(i)]
    pt_ckd_stage <- df_pop$ckd_stage[as.numeric(i)]

    # Optimized standard of care (scenario): SBP lowered to 130 mm Hg on
    # antihypertensives; statin for all (total cholesterol -25% when newly started)
    if (soc_optimized == 1) {
      if (pt_sbp > 130) { pt_sbp <- 130; pt_antihyp <- 1 }
      if (pt_statin == 0) { pt_statin <- 1; pt_tc <- pt_tc * 0.75 }
    }

    # Baseline age for ageing; time-varying biomarkers start at baseline
    pt_age_baseline <- pt_age
    cur_sbp   <- pt_sbp
    cur_hba1c <- pt_hba1c

    # ---- Gompertz for non-CV mortality (age-adjusted) ----
    # WARDEN does: rgompertz(n, shape = coef1, rate = exp(coef2 + log(beta_tx)))
    # Gompertz hazard: h(t) = rate * exp(shape * t), t measured from entry
    gomp_shape    <- if (pt_sex == 1) 0.085 else 0.088
    gomp_rate0    <- calculate_annual_noncv_mortality(pt_age, pt_sex)
    log_gomp_rate <- log(gomp_rate0 * bg_mort_mult)

    # Individual multiplier on the chronic eGFR decline rate: albuminuria scaling
    # and lognormal heterogeneity, drawn once per patient so all arms share it
    egfr_z       <- rnorm(1)
    egfr_pt_mult <- egfr_patient_multiplier(pt_uacr, egfr_uacr_beta, egfr_slope_sdlog, egfr_z)

    # ---- Initialize state ----
    fl_prior_mi     <- 0
    fl_prior_stroke <- 0
    fl_prior_hf     <- 0
    fl_eskd         <- 0
    n_mi            <- 0
    n_stroke        <- 0
    n_hf            <- 0
    ckd_stage       <- pt_ckd_stage
    rr_state        <- c(mi = 1, stroke = 1, hf_hosp = 1)

    # ---- Recurrence caps ----
    max_mi     <- 3
    max_stroke <- 3
    max_hf     <- 5
  })

  # ---- 4. Build unique_pt_inputs (per-patient, per-arm) ----
  unique_pt_inputs <- add_item(input = {
    # ---- Arm-specific treatment inputs (SoC: no effect, no drug cost) ----
    on_tx_arm       <- as.numeric(arm != "soc")
    fl_on_treatment <- on_tx_arm
    tx_eff          <- on_tx_arm   # fraction of treatment effect retained
    wane_step       <- 0

    hr_mace_arm <- if (arm == "sglt2i") hr_sglt2i_mace else if (arm == "glp1ra") hr_glp1_mace else 1
    hr_hf_arm   <- if (arm == "sglt2i") hr_sglt2i_hf else if (arm == "glp1ra") hr_glp1_hf else 1
    hr_cvd_arm  <- if (arm == "sglt2i") hr_sglt2i_cv_death else if (arm == "glp1ra") hr_glp1_cv_death else 1
    egfr_slope_ratio_arm <- if (arm == "sglt2i") sglt2i_egfr_slope_ratio else if (arm == "glp1ra") glp1_egfr_slope_ratio else 1
    # Kidney effect only with albuminuria or reduced eGFR (scenario)
    kidney_eligible <- kidney_effect_restrict == 0 || pt_uacr >= 30 || pt_egfr < 60
    if (!kidney_eligible) egfr_slope_ratio_arm <- 1
    rate_disc_arm    <- if (arm == "sglt2i") rate_disc_sglt2i else if (arm == "glp1ra") rate_disc_glp1 else 0
    util_gain_arm    <- if (arm == "sglt2i") util_gain_sglt2i else if (arm == "glp1ra") util_gain_glp1 else 0

    # ---- Drug price by payer: commercial before age_medicare, Medicare after ----
    price_com <- if (arm == "sglt2i") cost_sglt2i else if (arm == "glp1ra") cost_glp1ra else 0
    price_mcr <- if (arm == "sglt2i") cost_sglt2i_mcr else if (arm == "glp1ra") cost_glp1ra_mcr else 0
    fl_mcr    <- as.numeric(pt_age >= age_medicare)

    # ---- Add-on SGLT2i in the SoC and GLP-1 RA arms (addon_sglt2i scenario) ----
    addon_on    <- 0
    addon_mult  <- addon_multipliers(0, 1, 1, 1)
    addon_slope <- 1

    # ---- Kidney: linear eGFR trajectory anchored at (t_egfr_ref, egfr_ref) ----
    egfr_cur   <- pt_egfr
    egfr_ref   <- pt_egfr
    t_egfr_ref <- 0
    egfr_slope <- egfr_decline_ref * egfr_pt_mult * hr_effective(egfr_slope_ratio_arm, tx_eff) * addon_slope
    t_next_ckd <- time_to_next_ckd_stage(egfr_cur, egfr_slope, ckd_stage)

    # ---- Event hazards (untreated x recurrence x treatment) ----
    h_base <- calculate_base_hazards(
      pt_age, pt_sex, cur_sbp, pt_tc, pt_hdl, pt_dm, pt_smk,
      egfr_cur, pt_statin, pt_antihyp, pt_bmi, cur_hba1c,
      fl_prior_mi, fl_prior_stroke, fl_prior_hf, ckd_stage, cvd_mult,
      bg_mort_mult, prevent_age_cap, hf_hosp_frac
    )
    h_cur <- total_event_hazards(h_base, rr_state, hr_mace_arm, hr_hf_arm, hr_cvd_arm, tx_eff, addon_mult)

    # ---- Initial ongoing utility and cost ----
    cost_background <- cost_bg_base + cost_bg_age_coef * max(0, pt_age - 50)

    q_default <- util_baseline + util_gain_arm -
      ckd_state_disutility(ckd_stage, util_dec_ckd3, util_dec_ckd4, util_dec_eskd)
    c_default <- cost_background + cost_soc +
      ckd_state_cost(ckd_stage, cost_ckd3_annual, cost_ckd4_annual, cost_eskd_annual)
    # Drug cost in the commercial and Medicare periods; both stop at discontinuation
    # (06_reactions.R). c_addon: add-on SGLT2i (scenario)
    c_drug_com <- if (fl_mcr == 0) price_com else 0
    c_drug_mcr <- if (fl_mcr == 1) price_mcr else 0
    c_addon    <- 0

    # ---- Initialize instant cost/utility accumulators to 0 ----
    c_mi_acute     <- 0
    c_stroke_acute <- 0
    c_hf_acute     <- 0
    q_mi_acute     <- 0
    q_stroke_acute <- 0
    q_hf_acute     <- 0
  })

  # ---- 5. Build event definitions ----
  init_event_list <- build_init_events()

  # ---- 6. Build reaction logic ----
  evt_react_list <- build_reactions()

  # ---- 7. Cost/utility accumulator lists ----
  cu <- get_cost_utility_lists()

  # ---- 8. Run WARDEN simulation ----
  cat("  Running WARDEN simulation...\n")

  sim_args <- list(
    arm_list           = arms_to_run,
    common_all_inputs  = common_all_inputs,
    common_pt_inputs   = common_pt_inputs,
    unique_pt_inputs   = unique_pt_inputs,
    init_event_list    = init_event_list,
    evt_react_list     = evt_react_list,
    util_ongoing_list  = cu$util_ongoing,
    util_instant_list  = cu$util_instant,
    cost_ongoing_list  = cu$cost_ongoing,
    cost_instant_list  = cu$cost_instant,
    npats              = n_patients,
    n_sim              = n_sim,
    psa_bool           = psa_bool,
    sensitivity_bool   = dsa,
    seed               = seed,
    ipd                = ipd_level,
    input_out          = c("n_mi", "n_stroke", "n_hf", "fl_eskd", "ckd_stage",
                           "fl_on_treatment", "pt_age", "pt_age_baseline", "egfr_cur",
                           "addon_on", "fl_mcr")
  )
  results <- if (n_cores > 1) {
    do.call(WARDEN::run_sim_parallel, c(sim_args, list(ncores = n_cores)), quote = TRUE)
  } else {
    do.call(WARDEN::run_sim, sim_args, quote = TRUE)
  }

  cat("  Simulation complete.\n")
  return(results)
}
