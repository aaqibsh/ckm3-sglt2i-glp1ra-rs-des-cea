# =============================================================================
# File: 04_treatment.R
# Purpose: Treatment-effect, waning and kidney-trajectory helpers used inside
#          WARDEN delayed-execution blocks (05_events.R, 06_reactions.R)
# Author: CKM-HEOR Team
# Date: 2026-09-28 (rewritten — previous helpers were unused)
# =============================================================================
# All event hazards are exponential (piecewise-constant), so whenever a hazard
# changes from h_old to h_new at time t, a pending event time T can be updated
# exactly by T' = t + (T - t) * h_old / h_new (memorylessness).
#
# Treatment effect is carried by `tx_eff` in [0, 1]: 1 = full trial HR, 0 = no
# effect. The effective HR is linear in tx_eff: HR_eff = 1 + (HR - 1) * tx_eff.
# =============================================================================

# ---- Section: Treatment effect ----

#' Effective hazard ratio for a partially retained treatment effect
#' @param hr Trial hazard ratio (on treatment vs SoC)
#' @param tx_eff Fraction of effect retained (1 on treatment, 0 off)
hr_effective <- function(hr, tx_eff) 1 + (hr - 1) * tx_eff

#' Total event hazards = untreated hazard x recurrence multiplier x treatment HR
#'
#' @param h_base Named numeric from calculate_base_hazards()
#' @param rr_state Named numeric recurrence multipliers (mi, stroke, hf_hosp)
#' @param hr_mace,hr_hf,hr_cvd Arm hazard ratios (1 for SoC)
#' @param tx_eff Fraction of treatment effect retained
#' @return Named numeric: mi, stroke, hf_hosp, death_cv
# addon_mult: hazard multipliers of an SGLT2i added later in the SoC or GLP-1 RA
# arm (addon_sglt2i scenario); effects of the two drugs multiply
total_event_hazards <- function(h_base, rr_state, hr_mace, hr_hf, hr_cvd, tx_eff,
                                addon_mult = c(mi = 1, stroke = 1, hf_hosp = 1, death_cv = 1)) {
  h_base * c(mi = rr_state[["mi"]], stroke = rr_state[["stroke"]], hf_hosp = rr_state[["hf_hosp"]], death_cv = 1) *
    c(mi = hr_effective(hr_mace, tx_eff), stroke = hr_effective(hr_mace, tx_eff),
      hf_hosp = hr_effective(hr_hf, tx_eff), death_cv = hr_effective(hr_cvd, tx_eff)) *
    addon_mult[c("mi", "stroke", "hf_hosp", "death_cv")]
}

#' Hazard multipliers of an add-on SGLT2i (1 when not on an add-on)
addon_multipliers <- function(on, hr_mace, hr_hf, hr_cvd) {
  if (on == 1) c(mi = hr_mace, stroke = hr_mace, hf_hosp = hr_hf, death_cv = hr_cvd)
  else c(mi = 1, stroke = 1, hf_hosp = 1, death_cv = 1)
}

#' Correlated PSA draws of log HRs within a class
#'
#' @description The PSA draws each log HR independently from N(mu, se). This
#'   mixes the standardised draws with one common draw per class so that any two
#'   log HRs of the class have correlation rho; marginals are unchanged.
#' @param hr Named numeric of independently drawn HRs
#' @param mu,se Named numerics: log-scale means and SEs of the PSA distributions
#' @param z_common One standard normal draw shared by the class
#' @param rho Correlation
correlate_log_hrs <- function(hr, mu, se, z_common, rho) {
  d <- (log(hr) - mu[names(hr)]) / se[names(hr)]
  exp(mu[names(hr)] + se[names(hr)] * (sqrt(rho) * z_common + sqrt(1 - rho) * d))
}

#' Rescale pending exponential event times after a hazard change
#'
#' @param t_pending Named numeric of currently scheduled times (may be Inf)
#' @param now Current simulation time
#' @param h_old,h_new Named numeric hazards (same names as t_pending)
#' @return Named numeric of updated event times
rescale_pending <- function(t_pending, now, h_old, h_new) {
  ev <- names(t_pending)
  remaining <- pmax(t_pending - now, 0)
  out <- ifelse(is.finite(t_pending), now + remaining * h_old[ev] / h_new[ev], Inf)
  setNames(out, ev)
}

#' Fraction of treatment effect retained during post-discontinuation waning
#'
#' @description The effect declines linearly from 1 to 0 over `wane_years`,
#'   approximated by `n_steps` equal steps evaluated at interval midpoints, so the
#'   average effect over the waning period is exactly 0.5 (same as linear).
#' @param step Waning step reached (1 = just discontinued)
#' @param n_steps Number of steps in the waning period
#' @return Numeric in [0, 1]
wane_fraction <- function(step, n_steps) {
  if (step > n_steps) return(0)
  1 - (step - 0.5) / n_steps
}

# ---- Section: Kidney trajectory ----

#' Patient-specific multiplier on the reference eGFR decline rate
#'
#' @description Albuminuria scaling (UACR/30)^beta times a mean-one lognormal
#'   heterogeneity term. Arm-independent: computed once per patient (CRN).
#' @param uacr Urine albumin-creatinine ratio (mg/g); floored at 3
#' @param z Standard normal draw for the patient
egfr_patient_multiplier <- function(uacr, beta, sdlog, z) {
  (pmax(uacr, 3) / 30)^beta * exp(sdlog * z - sdlog^2 / 2)
}

#' eGFR at time `now` on a linear trajectory anchored at (t_ref, egfr_ref)
egfr_at <- function(now, egfr_ref, t_ref, slope) egfr_ref - slope * (now - t_ref)

#' Lower eGFR boundary of a CKD stage (crossing it moves to the next stage)
#'
#' Stages follow get_ckd_stage_from_egfr(): 1 (>= 60), 3 (30-59), 4 (15-29), 5 (< 15).
#' Boundaries are defined by stage rather than by eGFR value so that an eGFR
#' sitting exactly on a boundary after a progression event cannot re-trigger it.
stage_lower_bound <- function(ckd_stage) {
  if (ckd_stage <= 2) 60 else if (ckd_stage == 3) 30 else if (ckd_stage == 4) 15 else NA_real_
}

#' CKD stage entered when the current stage's lower boundary is crossed
next_ckd_stage <- function(ckd_stage) {
  if (ckd_stage <= 2) 3L else if (ckd_stage == 3) 4L else 5L
}

#' Time until a linear eGFR trajectory crosses the current stage's lower boundary
time_to_next_ckd_stage <- function(egfr, slope, ckd_stage) {
  b <- stage_lower_bound(ckd_stage)
  if (is.na(b) || slope <= 0) return(Inf)
  max(0, (egfr - b) / slope)
}

#' Annual CKD management cost for a CKD stage (ESKD replaces, not adds to, CKD 4)
ckd_state_cost <- function(ckd_stage, cost_ckd3, cost_ckd4, cost_eskd) {
  if (ckd_stage >= 5) cost_eskd else if (ckd_stage == 4) cost_ckd4 else if (ckd_stage == 3) cost_ckd3 else 0
}

#' Utility decrement for a CKD stage (ESKD decrement is on top of the CKD 4 decrement)
ckd_state_disutility <- function(ckd_stage, dec_ckd3, dec_ckd4, dec_eskd) {
  if (ckd_stage >= 5) dec_ckd4 + dec_eskd else if (ckd_stage == 4) dec_ckd4 else if (ckd_stage == 3) dec_ckd3 else 0
}
