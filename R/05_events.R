# =============================================================================
# File: 05_events.R
# Purpose: WARDEN event initialization — defines init_event_list
# Author: CKM-HEOR Team
# Date: 2026-10-14 (revised — time-horizon event)
# =============================================================================
# One definition serves all three arms: arm-specific treatment effects are
# already folded into h_cur (unique_pt_inputs, 08_run_model.R). WARDEN seeds the
# initial event draws identically for every arm of a patient, and the draws below
# happen in the same order in every arm, so each arm uses the same underlying
# random numbers (common random numbers) and differences between arms reflect
# treatment effects rather than sampling noise.
#
# Events: start, mi, stroke, hf_hosp, ckd_prog, death_cv, death_noncv,
#         tx_discont, tx_wane, age_update, horizon, medicare, addon_discont
# horizon ends follow-up at horizon_years (100 = lifetime; 10/20 in scenarios).
# ESKD is the ckd_prog event that crosses eGFR 15 (sets fl_eskd = 1).
# medicare switches drug prices from commercial to Medicare at age_medicare;
# addon_discont ends an add-on SGLT2i (addon_sglt2i scenario). Neither draws a
# random number at initialisation.
# =============================================================================

#' Build the initialization event list for WARDEN
#'
#' @description Uses WARDEN's delayed execution pattern — expressions are NOT
#'   evaluated here.
#' @return init_event_list for WARDEN::run_sim()
build_init_events <- function() {

  init_event_list <- add_tte(
    arm = c("soc", "sglt2i", "glp1ra"),
    evts = c("start", "mi", "stroke", "hf_hosp", "ckd_prog",
             "death_cv", "death_noncv", "tx_discont", "tx_wane", "age_update", "horizon",
             "medicare", "addon_discont"),
    input = {
      start       <- 0
      # draw_tte("exp") expects coef1 on the log scale: rexp(1, exp(coef1))
      mi          <- draw_tte(1, "exp", coef1 = log(h_cur[["mi"]]))
      stroke      <- draw_tte(1, "exp", coef1 = log(h_cur[["stroke"]]))
      hf_hosp     <- draw_tte(1, "exp", coef1 = log(h_cur[["hf_hosp"]]))
      ckd_prog    <- t_next_ckd
      death_cv    <- draw_tte(1, "exp", coef1 = log(h_cur[["death_cv"]]))
      death_noncv <- draw_tte(1, "gompertz", coef1 = gomp_shape, coef2 = log_gomp_rate)
      # Drawn last so SoC (no draw) does not shift the other arms' random stream
      # (rate 0 = full persistence scenario: never discontinues)
      tx_discont  <- if (on_tx_arm == 1 && rate_disc_arm > 0) rexp(1, rate_disc_arm) else Inf
      tx_wane     <- Inf   # scheduled by tx_discont
      age_update  <- 1.0   # First yearly update
      horizon     <- horizon_years   # deterministic; no random draw
      medicare    <- if (fl_mcr == 1) Inf else age_medicare - pt_age
      addon_discont <- Inf   # scheduled when an add-on SGLT2i starts
    }
  )

  return(init_event_list)
}
