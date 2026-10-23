# =============================================================================
# File: 06_reactions.R
# Purpose: WARDEN event reaction logic — defines evt_react_list
# Author: CKM-HEOR Team
# Date: 2026-10-14 (revised — drug cost in its own accumulator, horizon event)
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
    e$bg_mort_mult, e$prevent_age_cap, e$hf_hosp_frac
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

#' Re-anchor the eGFR trajectory and reschedule the next CKD progression
#'
#' @param e The patient-arm environment WARDEN evaluates reactions in
refresh_kidney <- function(e) {
  e$egfr_cur   <- egfr_at(e$curtime, e$egfr_ref, e$t_egfr_ref, e$egfr_slope)
  e$egfr_ref   <- e$egfr_cur
  e$t_egfr_ref <- e$curtime
  e$egfr_slope <- e$egfr_decline_ref * e$egfr_pt_mult *
    hr_effective(e$egfr_slope_ratio_arm, e$tx_eff) * e$addon_slope
  t_next <- time_to_next_ckd_stage(e$egfr_cur, e$egfr_slope, e$ckd_stage)
  modify_event(c(ckd_prog = e$curtime + t_next), ptr = e$cur_evtlist, patient_id = e$i)
}

#' Start an add-on SGLT2i in the SoC or GLP-1 RA arm (addon_sglt2i scenario)
#'
#' @description Guideline class 1 triggers: first HF hospitalization or CKD stage 4.
#'   The add-on's effects multiply those of the arm's own drug; its cost follows
#'   the current payer; it stops at a constant SGLT2i discontinuation rate (effect
#'   lost at once) or at kidney failure. Callers refresh kidney and hazards.
#' @param e The patient-arm environment
maybe_start_addon <- function(e) {
  g <- function(x) get(x, envir = e)   # parameters may live in a parent environment
  if (g("addon_sglt2i") != 1 || g("arm") == "sglt2i" || g("addon_on") == 1 || g("ckd_stage") >= 5) {
    return(invisible(FALSE))
  }
  e$addon_on    <- 1
  e$addon_mult  <- addon_multipliers(1, g("hr_sglt2i_mace"), g("hr_sglt2i_hf"), g("hr_sglt2i_cv_death"))
  eligible      <- g("kidney_effect_restrict") == 0 || g("pt_uacr") >= 30 || g("pt_egfr") < 60
  e$addon_slope <- if (eligible) g("sglt2i_egfr_slope_ratio") else 1
  e$c_addon     <- if (g("fl_mcr") == 1) g("cost_sglt2i_mcr") else g("cost_sglt2i")
  rate <- g("rate_disc_sglt2i")
  t_stop <- if (rate > 0) g("curtime") + rexp(1, rate) else Inf
  modify_event(c(addon_discont = t_stop), ptr = g("cur_evtlist"), patient_id = g("i"))
  invisible(TRUE)
}

#' Stop an add-on SGLT2i (callers refresh kidney and hazards)
stop_addon <- function(e) {
  e$addon_on    <- 0
  e$addon_mult  <- addon_multipliers(0, 1, 1, 1)
  e$addon_slope <- 1
  e$c_addon     <- 0
  modify_event(c(addon_discont = Inf), ptr = get("cur_evtlist", envir = e), patient_id = get("i", envir = e))
}

#' Build the event reaction list for WARDEN
#'
#' @description Defines reactions for all 13 events. Uses delayed execution —
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
        if (maybe_start_addon(environment())) refresh_kidney(environment())

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

        old_stage <- ckd_stage
        ckd_stage <- next_ckd_stage(ckd_stage)

        # Replace the previous stage's management cost and decrement
        c_default <- c_default +
          ckd_state_cost(ckd_stage, cost_ckd3_annual, cost_ckd4_annual, cost_eskd_annual) -
          ckd_state_cost(old_stage, cost_ckd3_annual, cost_ckd4_annual, cost_eskd_annual)
        q_default <- q_default -
          (ckd_state_disutility(ckd_stage, util_dec_ckd3, util_dec_ckd4, util_dec_eskd) -
             ckd_state_disutility(old_stage, util_dec_ckd3, util_dec_ckd4, util_dec_eskd))

        if (ckd_stage >= 5) fl_eskd <- 1

        # Add-on SGLT2i at CKD stage 4 (scenario)
        if (ckd_stage == 4) maybe_start_addon(environment())

        # SGLT2i stopped at kidney failure (dialysis or transplant), no waning
        if (ckd_stage >= 5 && stop_sglt2i_at_kf == 1) {
          if (arm == "sglt2i" && tx_eff > 0) {
            if (fl_on_treatment == 1) q_default <- q_default - util_gain_arm
            fl_on_treatment <- 0
            c_drug_com <- 0
            c_drug_mcr <- 0
            tx_eff <- 0
            modify_event(c(tx_discont = Inf, tx_wane = Inf))
          }
          if (addon_on == 1) stop_addon(environment())
        }

        # Reschedule to the next boundary; ESKD stops further progression
        refresh_kidney(environment())
        # CKD stage changes CV mortality and PREVENT eGFR terms
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
        if (addon_on == 1) c_addon <- cost_sglt2i_mcr
      }
    )

  # ---- Add-on SGLT2i discontinuation (scenario) ----
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

        refresh_hazards(environment())

        modify_event(c(age_update = curtime + 1.0))
      }
    )

  return(evt_react_list)
}
