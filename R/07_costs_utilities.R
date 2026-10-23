# =============================================================================
# File: 07_costs_utilities.R
# Purpose: Define cost and utility accumulator lists for WARDEN model
# Author: CKM-HEOR Team
# Date: 2026-10-14 (revised — drug acquisition cost in its own accumulator)
# =============================================================================
# Ongoing accumulators (q_default, c_default, c_drug_com, c_drug_mcr, c_addon) are
# built in unique_pt_inputs
# (08_run_model.R) and updated in reactions (06_reactions.R). CKD-stage costs and
# decrements come from ckd_state_cost() / ckd_state_disutility() (04_treatment.R).
# c_drug_com and c_drug_mcr hold the study drug's acquisition cost before and after
# the switch to Medicare prices, so discounted drug spending per arm and payer is
# reported directly (price scenarios and threshold prices are exact: drug cost is
# linear in each price). c_addon holds the cost of an add-on SGLT2i (scenario).
# =============================================================================

#' Get cost and utility accumulator lists
#' @return A list containing utility and cost accumulator vectors
get_cost_utility_lists <- function() {
  list(
    util_ongoing = c("q_default"),
    util_instant = c("q_mi_acute", "q_stroke_acute", "q_hf_acute"),
    cost_ongoing = c("c_default", "c_drug_com", "c_drug_mcr", "c_addon"),
    cost_instant = c("c_mi_acute", "c_stroke_acute", "c_hf_acute")
  )
}
