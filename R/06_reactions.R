# =============================================================================
# File: 06_reactions.R
# Purpose: WARDEN event reaction logic — defines evt_react_list
# Author: CKM-HEOR Team
# Date: 2026-11-09 (revised — kidney state helpers, dialysis start, two-way add-on)
# =============================================================================
# Every change to the patient's state (ageing, biomarker drift, eGFR decline,
# prior events, CKD stage, treatment effect) goes through two helpers:
#
#   refresh_kidney(e)  — re-anchors the linear eGFR trajectory at the current
#                        time with the slope implied by the current treatment
#                        effect, and reschedules ckd_prog.
#   refresh_hazards(e) — recomputes untreated PREVENT/mortality hazards, applies
#                        recurrence multipliers and the current treatment HRs, and
#                        rescales every pending exponential event (exact, by
#                        memorylessness). Events listed in `redraw` are drawn
#                        afresh (used for the recurrence of the event that fired).
#
# Both take the reaction's evaluation environment: call them as
# `refresh_hazards(environment())` inside an add_reactevt() input block.
# =============================================================================

#' Recompute event hazards and rescale pending events
#'
#' @param e The patient-arm environment WARDEN evaluates reactions in
#' @param redraw Event names to draw afresh from the new hazard
#' @return Invisibly, the new total hazards
refresh_hazards <- function(e, redraw = character(0)) {
  e$egfr_cur <- egfr_at(e$curtime, e$egfr_ref, e$t_egfr_ref, e$egfr_slope)

  h_base <- calculate_base_hazards(
    e$pt_age, e$pt_sex, e$cur_sbp, e$pt_tc, e$pt_hdl, e$pt_dm, e$pt_smk,
    e$egfr_cur, e$pt_statin, e$pt_antihyp, e$pt_bmi, e$cur_hba1c,
    e$fl_prior_mi, e$fl_prior_stroke, e$fl_prior_hf, e$ckd_stage, e$cvd_mult,
    e$bg_mort_mult, e$prevent_age_cap, e$hf_hosp_frac, e$pt_uacr, get("prevent_full", envir = e)
  )
  h_new <- total_event_hazards(h_base, e$rr_state, e$hr_mace_arm, e$hr_hf_arm,
                               e$hr_cvd_arm, e$tx_eff, e$addon_mult)

  keep <- setdiff(names(h_new), redraw)
  t_pending <- vapply(keep, function(ev) get_event(ev, ptr = e$cur_evtlist, patient_id = e$i),
                      numeric(1))
  new_times <- rescale_pending(t_pending, e$curtime, e$h_cur, h_new)
  for (ev in redraw) new_times[[ev]] <- e$curtime + rexp(1, h_new[[ev]])

  modify_event(new_times, ptr = e$cur_evtlist, patient_id = e$i)
  e$h_cur <- h_new
  invisible(h_new)
}

#' Re-anchor the eGFR trajectory and reschedule kidney events
#'
#' @description Reschedules ckd_prog (next stage boundary), egfr45 (stage 3b cost)
#'   and, after kidney failure, dialysis (when dialysis starts below eGFR 15).
#' @param e The patient-arm environment WARDEN evaluates reactions in
refresh_kidney <- function(e) {
  g <- function(x) get(x, envir = e)   # parameters may live in a parent environment
  e$egfr_cur   <- egfr_at(e$curtime, e$egfr_ref, e$t_egfr_ref, e$egfr_slope)
  e$egfr_ref   <- e$egfr_cur
  e$t_egfr_ref <- e$curtime
  e$egfr_slope <- e$egfr_decline_ref * e$egfr_pt_mult *
    hr_effective(e$egfr_slope_ratio_arm, e$tx_eff) * e$addon_slope *
    kidney_band_multiplier(g("ckd_stage"), g("fl_ckd3b"), g("egfr_mult_3b"), g("egfr_mult_4"))
  t_next <- time_to_next_ckd_stage(e$egfr_cur, e$egfr_slope, e$ckd_stage)
  t_45   <- if (g("fl_ckd3b") == 0) time_to_egfr(e$egfr_cur, e$egfr_slope, 45) else Inf
  t_dial <- if (g("ckd_stage") >= 5 && g("fl_dialysis") == 0 && g("fl_conservative") == 0)
    time_to_egfr(e$egfr_cur, e$egfr_slope, g("dialysis_egfr")) else Inf
  modify_event(c(ckd_prog = e$curtime + t_next, egfr45 = e$curtime + t_45, dialysis = e$curtime + t_dial),
               ptr = e$cur_evtlist, patient_id = e$i)
}

#' Move to a new kidney state, replacing its annual cost and utility decrement
#'
#' @param e The patient-arm environment
#' @param stage,sub3b,dialysis New CKD stage, stage 3b flag, and dialysis flag
set_kidney_state <- function(e, stage, sub3b, dialysis) {
  g <- function(x) get(x, envir = e)
  cost <- function(st, sb, dl) ckd_state_cost(st, sb, dl, g("cost_ckd3a_annual"), g("cost_ckd3b_annual"),
                                              g("cost_ckd4_annual"), g("cost_eskd_annual"))
  dec <- function(st, dl) ckd_state_disutility(st, dl, g("util_dec_ckd3"), g("util_dec_ckd4"), g("util_dec_eskd"))
  e$c_default <- g("c_default") + cost(stage, sub3b, dialysis) - cost(g("ckd_stage"), g("fl_ckd3b"), g("fl_dialysis"))
  e$q_default <- g("q_default") - (dec(stage, dialysis) - dec(g("ckd_stage"), g("fl_dialysis")))
  e$ckd_stage   <- stage
  e$fl_ckd3b    <- sub3b
  e$fl_dialysis <- dialysis
}

#' Stop the arm's own drug at once (no waning), e.g. at dialysis start
stop_arm_drug <- function(e) {
  g <- function(x) get(x, envir = e)
  if (g("tx_eff") <= 0) return(invisible(FALSE))
  if (g("fl_on_treatment") == 1) e$q_default <- g("q_default") - g("util_gain_arm")
  e$fl_on_treatment <- 0
  e$c_drug_com <- 0
  e$c_drug_mcr <- 0
  e$tx_eff <- 0
  modify_event(c(tx_discont = Inf, tx_wane = Inf), ptr = g("cur_evtlist"), patient_id = g("i"))
  invisible(TRUE)
}

#' Start kidney replacement at kidney failure (eGFR 15, or dialysis_egfr)
#'
#' @description Dialysis replaces the CKD 4 cost and adds the dialysis decrement;
#'   SGLT2i (and GLP-1 RA if stop_glp1_at_kf) stop. In the dialysis_forgo scenario
#'   patients decide against dialysis with probability p_forgo_dialysis(age):
#'   conservative care keeps the CKD 4 cost and decrement, and drugs continue.
#' @param e The patient-arm environment. Callers refresh kidney and hazards.
start_kidney_replacement <- function(e) {
  g <- function(x) get(x, envir = e)
  age_now <- g("pt_age_baseline") + g("curtime")
  if (g("dialysis_forgo") == 1 && g("u_dialysis") < p_forgo_dialysis(age_now)) {
    e$fl_conservative <- 1
    return(invisible(FALSE))
  }
  set_kidney_state(e, g("ckd_stage"), g("fl_ckd3b"), 1)
  if ((g("arm") == "sglt2i" && g("stop_sglt2i_at_kf") == 1) ||
      (g("arm") == "glp1ra" && g("stop_glp1_at_kf") == 1)) stop_arm_drug(e)
  if (g("addon_on") == 1 && ((g("addon_type") == "sglt2i" && g("stop_sglt2i_at_kf") == 1) ||
                             (g("addon_type") == "glp1" && g("stop_glp1_at_kf") == 1))) stop_addon(e)
  invisible(TRUE)
}

#' Start an add-on drug (addon_sglt2i, addon_glp1 scenarios)
#'
#' @description SGLT2i in the SoC or GLP-1 RA arm at the first HF hospitalization
#'   or CKD stage 4 (guideline class 1 indications). GLP-1 RA in the SGLT2i arm at
#'   1 year in type 2 diabetes with persistent albuminuria on SGLT2i (baseline UACR
#'   lowered by sglt2i_uacr_reduction still >= addon_glp1_uacr), while on SGLT2i and
#'   not on dialysis. The add-on's effects multiply those of the arm's own drug; its
#'   cost follows the current payer; it stops at its class discontinuation rate
#'   (effect lost at once) or at dialysis start. Callers refresh kidney and hazards.
#' @param e The patient-arm environment
#' @param type "sglt2i" or "glp1"
maybe_start_addon <- function(e, type = "sglt2i") {
  g <- function(x) get(x, envir = e)   # parameters may live in a parent environment
  if (g("addon_on") == 1) return(invisible(FALSE))
  if (type == "sglt2i") {
    if (g("addon_sglt2i") != 1 || g("arm") == "sglt2i" || g("ckd_stage") >= 5) return(invisible(FALSE))
    hrs  <- c(g("hr_sglt2i_mace"), g("hr_sglt2i_hf"), g("hr_sglt2i_cv_death"), g("sglt2i_egfr_slope_ratio"))
    pr   <- c(g("cost_sglt2i"), g("cost_sglt2i_mcr"))
    rate <- g("rate_disc_sglt2i")
  } else {
    if (g("addon_glp1") != 1 || g("arm") != "sglt2i" || g("pt_dm") != 1 || g("fl_on_treatment") != 1 ||
        g("fl_dialysis") == 1 ||
        g("pt_uacr") * (1 - g("sglt2i_uacr_reduction")) < g("addon_glp1_uacr")) return(invisible(FALSE))
    hrs  <- if (g("glp1_flow_dm") == 1) c(g("hr_flow_mace"), g("hr_flow_hf"), g("hr_flow_cv_death"), g("flow_egfr_slope_ratio")) else
      c(g("hr_glp1_mace"), g("hr_glp1_hf"), g("hr_glp1_cv_death"), g("glp1_egfr_slope_ratio"))
    pr   <- c(g("cost_glp1ra") * g("glp1_dm_price_ratio"), g("cost_glp1ra_mcr"))
    rate <- g("rate_disc_glp1")
  }
  e$addon_on    <- 1
  e$addon_type  <- type
  e$addon_mult  <- addon_multipliers(1, hrs[1], hrs[2], hrs[3])
  eligible      <- g("kidney_effect_restrict") == 0 || g("pt_uacr") >= 30 || g("pt_egfr") < 60
  e$addon_slope <- if (eligible) hrs[4] else 1
  e$c_addon     <- if (g("fl_mcr") == 1) pr[2] else pr[1]
  t_stop <- if (rate > 0) g("curtime") + rexp(1, rate) else Inf
  modify_event(c(addon_discont = t_stop), ptr = g("cur_evtlist"), patient_id = g("i"))
  invisible(TRUE)
}

#' Stop an add-on (callers refresh kidney and hazards)
stop_addon <- function(e) {
  e$addon_on    <- 0
  e$addon_type  <- "none"
  e$addon_mult  <- addon_multipliers(0, 1, 1, 1)
  e$addon_slope <- 1
  e$c_addon     <- 0
  modify_event(c(addon_discont = Inf), ptr = get("cur_evtlist", envir = e), patient_id = get("i", envir = e))
}

#' Build the event reaction list for WARDEN
#'
#' @description Defines reactions for all 15 events. Uses delayed execution —
#'   all variables are resolved at WARDEN runtime, not at definition time.
#' @return evt_react_list for WARDEN::run_sim()
build_reactions <- function() {

  # ---- Start event ----
  evt_react_list <- add_reactevt(
    name_evt = "start",
    input = {
      # No action needed — initial costs/utilities set in unique_pt_inputs
    }
  )

  # ---- MI event (RECURRENT, capped at max_mi) ----
  evt_react_list <- evt_react_list |>
    add_reactevt(
      name_evt = "mi",
      input = {
        n_mi <- n_mi + 1
        fl_prior_mi <- 1

        # Instant acute cost and disutility (every recurrence)
        c_mi_acute <- cost_mi_acute
        q_mi_acute <- -util_dec_mi_acute

        # Chronic decrement only on first event
        if (n_mi == 1) {
          q_default <- q_default - util_dec_mi_chronic
          c_default <- c_default + cost_mi_post
        }

        # Recurrence hazard compounds per prior MI; persists through age updates
        rr_state[["mi"]] <- rr_recur_mi^n_mi

        # Prior MI also raises CV mortality: refresh rescales death_cv
        if (n_mi < max_mi) {
          refresh_hazards(environment(), redraw = "mi")
        } else {
          modify_event(c(mi = Inf))
          refresh_hazards(environment())
        }
      }
    )

  # ---- Stroke event (RECURRENT, capped at max_stroke) ----
  evt_react_list <- evt_react_list |>
    add_reactevt(
      name_evt = "stroke",
      input = {
        n_stroke <- n_stroke + 1
        fl_prior_stroke <- 1

        c_stroke_acute <- cost_stroke_acute
        q_stroke_acute <- -util_dec_stroke_acute

        # Chronic decrement only on first event
        if (n_stroke == 1) {
          q_default <- q_default - util_dec_stroke_chronic
          c_default <- c_default + cost_stroke_post
        }

        rr_state[["stroke"]] <- rr_recur_stroke^n_stroke

        if (n_stroke < max_stroke) {
          refresh_hazards(environment(), redraw = "stroke")
        } else {
          modify_event(c(stroke = Inf))
          refresh_hazards(environment())
        }
      }
    )

  # ---- HF Hospitalisation event (RECURRENT, capped at max_hf) ----
  evt_react_list <- evt_react_list |>
    add_reactevt(
      name_evt = "hf_hosp",
      input = {
        n_hf <- n_hf + 1
        fl_prior_hf <- 1

        c_hf_acute <- cost_hf_hosp
        q_hf_acute <- -util_dec_hf

        # Chronic decrement only on first event
        if (n_hf == 1) {
          c_default <- c_default + cost_hf_post
          q_default <- q_default - util_dec_hf * 0.5  # Half acute decrement persists
        }

        rr_state[["hf_hosp"]] <- rr_recur_hf^n_hf

        # Add-on SGLT2i at the first HF hospitalization (scenario)
        if (maybe_start_addon(environment(), "sglt2i")) refresh_kidney(environment())

        if (n_hf < max_hf) {
          refresh_hazards(environment(), redraw = "hf_hosp")
        } else {
          modify_event(c(hf_hosp = Inf))
          refresh_hazards(environment())
        }
      }
    )

  # ---- CKD Progression event (crossing eGFR 60, 30 or 15) ----
  evt_react_list <- evt_react_list |>
    add_reactevt(
      name_evt = "ckd_prog",
      input = {
        # Pin the trajectory exactly on the boundary just crossed
        egfr_ref   <- stage_lower_bound(ckd_stage)
        t_egfr_ref <- curtime

        # Replace the previous stage's management cost and decrement
        new_stage <- next_ckd_stage(ckd_stage)
        set_kidney_state(environment(), new_stage, if (new_stage >= 4) 1 else fl_ckd3b, fl_dialysis)

        if (ckd_stage >= 5) fl_eskd <- 1

        # Add-on SGLT2i at CKD stage 4 (scenario)
        if (ckd_stage == 4) maybe_start_addon(environment(), "sglt2i")

        # Kidney failure: dialysis starts now unless it starts at a lower eGFR
        # (dialysis_egfr scenario; refresh_kidney() then schedules it)
        if (ckd_stage >= 5 && dialysis_egfr >= 15) start_kidney_replacement(environment())

        # Reschedule to the next boundary; kidney failure stops further progression
        refresh_kidney(environment())
        # CKD stage changes CV mortality and PREVENT eGFR terms
        refresh_hazards(environment())
      }
    )

  # ---- eGFR falls below 45: stage 3b cost and decline rate ----
  evt_react_list <- evt_react_list |>
    add_reactevt(
      name_evt = "egfr45",
      input = {
        egfr_ref   <- 45
        t_egfr_ref <- curtime
        set_kidney_state(environment(), ckd_stage, 1, fl_dialysis)
        refresh_kidney(environment())
      }
    )

  # ---- Dialysis start below eGFR 15 (dialysis_egfr scenario) ----
  evt_react_list <- evt_react_list |>
    add_reactevt(
      name_evt = "dialysis",
      input = {
        egfr_ref   <- dialysis_egfr
        t_egfr_ref <- curtime
        start_kidney_replacement(environment())
        refresh_kidney(environment())
        refresh_hazards(environment())
      }
    )

  # ---- CV Death event ----
  evt_react_list <- evt_react_list |>
    add_reactevt(
      name_evt = "death_cv",
      input = {
        q_default <- 0
        c_default <- 0
        c_drug_com <- 0
        c_drug_mcr <- 0
        c_addon <- 0
        curtime <- Inf  # Terminate patient simulation
      }
    )

  # ---- Non-CV Death event ----
  evt_react_list <- evt_react_list |>
    add_reactevt(
      name_evt = "death_noncv",
      input = {
        q_default <- 0
        c_default <- 0
        c_drug_com <- 0
        c_drug_mcr <- 0
        c_addon <- 0
        curtime <- Inf  # Terminate patient simulation
      }
    )

  # ---- End of time horizon (scenarios with a finite horizon) ----
  evt_react_list <- evt_react_list |>
    add_reactevt(
      name_evt = "horizon",
      input = {
        q_default <- 0
        c_default <- 0
        c_drug_com <- 0
        c_drug_mcr <- 0
        c_addon <- 0
        curtime <- Inf  # Stop follow-up
      }
    )

  # ---- Treatment Discontinuation event ----
  # Drug cost (c_drug) stops immediately; the treatment effect (event HRs and eGFR slope)
  # wanes linearly to zero over tx_wane_years, in n_wane_steps steps.
  evt_react_list <- evt_react_list |>
    add_reactevt(
      name_evt = "tx_discont",
      input = {
        fl_on_treatment <- 0
        c_drug_com <- 0
        c_drug_mcr <- 0
        q_default <- q_default - util_gain_arm

        if (tx_wane_years > 0) {
          wane_step <- 1
          tx_eff <- wane_fraction(wane_step, n_wane_steps)
          modify_event(c(tx_wane = curtime + tx_wane_years / n_wane_steps))
        } else {
          tx_eff <- 0
        }

        refresh_kidney(environment())
        refresh_hazards(environment())
      }
    )

  # ---- Treatment Waning step ----
  evt_react_list <- evt_react_list |>
    add_reactevt(
      name_evt = "tx_wane",
      input = {
        wane_step <- wane_step + 1
        tx_eff <- wane_fraction(wane_step, n_wane_steps)
        if (wane_step <= n_wane_steps) {
          modify_event(c(tx_wane = curtime + tx_wane_years / n_wane_steps))
        }

        refresh_kidney(environment())
        refresh_hazards(environment())
      }
    )

  # ---- Switch to Medicare prices at age_medicare ----
  evt_react_list <- evt_react_list |>
    add_reactevt(
      name_evt = "medicare",
      input = {
        fl_mcr <- 1
        if (fl_on_treatment == 1) {
          c_drug_com <- 0
          c_drug_mcr <- price_mcr
        }
        if (addon_on == 1) c_addon <- if (addon_type == "glp1") cost_glp1ra_mcr else cost_sglt2i_mcr
      }
    )

  # ---- Add-on discontinuation (scenario) ----
  evt_react_list <- evt_react_list |>
    add_reactevt(
      name_evt = "addon_discont",
      input = {
        stop_addon(environment())
        refresh_kidney(environment())
        refresh_hazards(environment())
      }
    )

  # ---- Age Update event (fires every 1 year) ----
  # Ages the patient, applies natural biomarker drift (identical in all arms;
  # treatment effects on biomarkers are NOT added because the trial HRs already
  # capture them), updates background cost, and refreshes all hazards.
  evt_react_list <- evt_react_list |>
    add_reactevt(
      name_evt = "age_update",
      input = {
        pt_age <- pt_age_baseline + curtime

        cur_sbp <- cur_sbp + sbp_drift
        if (pt_dm == 1) cur_hba1c <- cur_hba1c + hba1c_drift_dm

        # Background cost rises by cost_bg_age_coef per year of age above 50
        c_default <- c_default + cost_bg_age_coef * min(1, max(0, pt_age - 50))

        # Add-on GLP-1 RA in the SGLT2i arm at 1 year (scenario)
        if (abs(curtime - 1) < 1e-9 && maybe_start_addon(environment(), "glp1")) refresh_kidney(environment())

        refresh_hazards(environment())

        modify_event(c(age_update = curtime + 1.0))
      }
    )

  return(evt_react_list)
}
