# =============================================================================
# File: 09_results.R
# Purpose: Process and visualise WARDEN DES model results
# Author: CKM-HEOR Team
# Date: 2026-10-14 (revised — drug cost per arm, threshold prices)
# =============================================================================
# WARDEN results structure: results[[analysis]][[simulation]], each element
# holding named-by-arm vectors (total_costs, total_qalys, total_lys, and any
# input_out variables). Analysis 1 is the base case unless a DSA was run, in
# which case analysis k = 1..n is DSA_min and n+1..2n is DSA_max.
# =============================================================================

library(data.table)
library(ggplot2)
library(WARDEN)

ARM_LABELS <- c(sglt2i = "SGLT2i + SoC", glp1ra = "GLP-1 RA + SoC", soc = "SoC")

# Pairwise comparisons reported: each active arm vs SoC, and head-to-head
DEFAULT_COMPARISONS <- list(c("sglt2i", "soc"), c("glp1ra", "soc"), c("sglt2i", "glp1ra"))

PARAM_LABELS <- c(
  hr_sglt2i_mace = "SGLT2i HR: MACE", hr_sglt2i_hf = "SGLT2i HR: HF hospitalization",
  hr_sglt2i_cv_death = "SGLT2i HR: CV death", sglt2i_egfr_slope_ratio = "SGLT2i eGFR slope ratio",
  hr_glp1_mace = "GLP-1 RA HR: MACE", hr_glp1_hf = "GLP-1 RA HR: HF hospitalization",
  hr_glp1_cv_death = "GLP-1 RA HR: CV death", glp1_egfr_slope_ratio = "GLP-1 RA eGFR slope ratio",
  cost_sglt2i = "SGLT2i annual price, commercial", cost_glp1ra = "GLP-1 RA annual price, commercial",
  cost_sglt2i_mcr = "SGLT2i annual price, Medicare", cost_glp1ra_mcr = "GLP-1 RA annual price, Medicare",
  cost_soc = "SoC annual cost",
  cost_mi_acute = "MI acute cost", cost_stroke_acute = "Stroke acute cost", cost_hf_hosp = "HF hospitalization cost",
  cost_mi_post = "Post-MI annual cost", cost_stroke_post = "Post-stroke annual cost", cost_hf_post = "Post-HF annual cost",
  cost_ckd3_annual = "CKD 3 annual cost", cost_ckd4_annual = "CKD 4 annual cost", cost_eskd_annual = "Kidney failure annual cost",
  cost_bg_base = "Background cost (base)", cost_bg_age_coef = "Background cost per year of age",
  util_baseline = "Baseline utility", util_dec_mi_acute = "Disutility: MI (acute)",
  util_dec_mi_chronic = "Disutility: MI (chronic)", util_dec_stroke_acute = "Disutility: stroke (acute)",
  util_dec_stroke_chronic = "Disutility: stroke (chronic)", util_dec_hf = "Disutility: HF",
  util_dec_ckd3 = "Disutility: CKD 3", util_dec_ckd4 = "Disutility: CKD 4", util_dec_eskd = "Disutility: kidney failure",
  prob_disc_sglt2i = "SGLT2i annual discontinuation", prob_disc_glp1 = "GLP-1 RA annual discontinuation",
  tx_wane_years = "Waning period after discontinuation (y)",
  egfr_decline_ref = "eGFR decline at UACR 30 (mL/min/y)", egfr_uacr_beta = "eGFR decline: UACR exponent",
  egfr_slope_sdlog = "eGFR decline heterogeneity (SD log)",
  sbp_drift = "SBP drift (mmHg/y)", hba1c_drift_dm = "HbA1c drift in diabetes (%/y)",
  rr_recur_mi = "Recurrent MI hazard multiplier", rr_recur_stroke = "Recurrent stroke hazard multiplier",
  rr_recur_hf = "Recurrent HF hazard multiplier",
  cvd_mult_mi = "CV death multiplier: prior MI", cvd_mult_stroke = "CV death multiplier: prior stroke",
  cvd_mult_hf = "CV death multiplier: prior HF", cvd_mult_ckd3 = "CV death multiplier: CKD 3",
  cvd_mult_ckd4 = "CV death multiplier: CKD 4", cvd_mult_eskd = "CV death multiplier: kidney failure",
  drc = "Discount rate: costs", drq = "Discount rate: outcomes",
  horizon_years = "Time horizon (y)", age_medicare = "Age at switch to Medicare prices (y)",
  stop_sglt2i_at_kf = "SGLT2i stopped at kidney failure", addon_sglt2i = "Add-on SGLT2i in SoC and GLP-1 RA arms",
  bg_mort_mult = "Background mortality multiplier", kidney_effect_restrict = "Kidney effect restricted",
  hf_hosp_frac = "Share of incident HF hospitalized", util_gain_sglt2i = "Utility gain on SGLT2i",
  util_gain_glp1 = "Utility gain on GLP-1 RA", prevent_age_cap = "PREVENT age cap (y)",
  soc_optimized = "Optimized standard of care",
  psa_hr_rho = "Correlation of class log HRs in PSA"
)

#' Process model results with WARDEN's summary functions
#'
#' @param results Output from WARDEN run_sim()
#' @param wtp Willingness-to-pay threshold
#' @param ref_arm Reference arm name
#' @return Processed summary table
#' @export
process_results <- function(results, wtp = 120000, ref_arm = "soc") {
  n_sims <- length(results[[1]])

  if (n_sims == 1) {
    res_summary <- WARDEN::summary_results_det(results[[1]][[1]], arm = ref_arm, wtp = wtp)
  } else {
    res_summary <- WARDEN::summary_results_sim(results[[1]], arm = ref_arm, wtp = wtp)
  }

  return(res_summary)
}

#' Describe an ICER with its cost-effectiveness plane quadrant
#'
#' @param inc_cost,inc_qaly Incremental costs and QALYs (intervention - comparator)
#' @return Character label
icer_label <- function(inc_cost, inc_qaly) {
  if (inc_qaly >= 0 && inc_cost <= 0) return("Dominant")
  if (inc_qaly <= 0 && inc_cost >= 0) return("Dominated")
  icer <- inc_cost / inc_qaly
  if (inc_qaly > 0) return(sprintf("$%s/QALY", format(round(icer), big.mark = ",")))
  sprintf("$%s saved per QALY lost", format(round(icer), big.mark = ","))
}

#' Incremental results for one pairwise comparison
#'
#' @param res One simulation result: results[[analysis]][[simulation]]
#' @param int,comp Intervention and comparator arm names
#' @param wtp Willingness-to-pay threshold
#' @return One-row data.table
compare_arms <- function(res, int, comp, wtp = 120000) {
  dc <- unname(res$total_costs[int] - res$total_costs[comp])
  dq <- unname(res$total_qalys[int] - res$total_qalys[comp])
  dl <- unname(res$total_lys[int] - res$total_lys[comp])
  data.table(
    comparison = paste(ARM_LABELS[[int]], "vs", ARM_LABELS[[comp]]),
    int = int, comp = comp,
    inc_cost = dc, inc_qaly = dq, inc_ly = dl,
    icer = dc / dq,
    inmb = wtp * dq - dc,
    icer_label = icer_label(dc, dq)
  )
}

#' Deterministic summary: per-arm outcomes and pairwise incremental results
#'
#' @param results Output from WARDEN run_sim() (deterministic)
#' @param wtp Willingness-to-pay threshold
#' @param comparisons List of c(intervention, comparator) pairs
#' @param analysis Analysis index within results
#' @return List with `arms` and `incremental` data.tables
summarise_deterministic <- function(results, wtp = 120000,
                                    comparisons = DEFAULT_COMPARISONS, analysis = 1) {
  res <- results[[analysis]][[1]]
  arms <- names(res$total_costs)
  get_var <- function(v) if (is.null(res[[v]])) rep(NA_real_, length(arms)) else unname(res[[v]][arms])

  arm_tab <- data.table(
    arm = arms, label = unname(ARM_LABELS[arms]),
    costs = get_var("total_costs"), qalys = get_var("total_qalys"), lys = get_var("total_lys"),
    lys_undisc = get_var("total_lys_undisc"), qalys_undisc = get_var("total_qalys_undisc"),
    n_mi = get_var("n_mi"), n_stroke = get_var("n_stroke"), n_hf = get_var("n_hf"),
    prop_eskd = get_var("fl_eskd"), end_egfr = get_var("egfr_cur"),
    prop_on_tx = get_var("fl_on_treatment"),
    drug_cost_com = get_var("c_drug_com"), drug_cost_mcr = get_var("c_drug_mcr"),
    addon_cost = get_var("c_addon"), prop_addon = get_var("addon_on")
  )
  arm_tab[, drug_cost := drug_cost_com + drug_cost_mcr]
  comparisons <- Filter(function(cp) all(cp %in% arms), comparisons)
  inc_tab <- rbindlist(lapply(comparisons, function(cp) compare_arms(res, cp[1], cp[2], wtp)))
  list(arms = arm_tab, incremental = inc_tab)
}

#' Base-case drug prices of a parameter set
#' @return Named numeric: cost_sglt2i, cost_sglt2i_mcr, cost_glp1ra, cost_glp1ra_mcr
drug_prices <- function(params) {
  pv <- setNames(unlist(params$base_value), unlist(params$parameter_name))
  pv[c("cost_sglt2i", "cost_sglt2i_mcr", "cost_glp1ra", "cost_glp1ra_mcr")]
}

#' Discounted treatment-years per patient in each payer period
#'
#' @description Drug cost accrues at the commercial price before the switch to
#'   Medicare and at the Medicare price after it (c_drug_com, c_drug_mcr), so
#'   drug cost / price gives the discounted years on treatment in each period.
#' @param arms Arm table from summarise_deterministic()
#' @param prices Prices used for the run (drug_prices())
#' @return data.table: arm, d_com, d_mcr
treatment_years <- function(arms, prices) {
  pc <- c(sglt2i = prices[["cost_sglt2i"]], glp1ra = prices[["cost_glp1ra"]], soc = NA)
  pm <- c(sglt2i = prices[["cost_sglt2i_mcr"]], glp1ra = prices[["cost_glp1ra_mcr"]], soc = NA)
  data.table(arm = arms$arm,
             d_com = ifelse(arms$arm == "soc", 0, arms$drug_cost_com / pc[arms$arm]),
             d_mcr = ifelse(arms$arm == "soc", 0, arms$drug_cost_mcr / pm[arms$arm]))
}

#' Pairwise comparison from an arm table (costs, qalys, lys)
compare_tab <- function(arms, int, comp, wtp = 120000) {
  a <- arms[arm == int]; b <- arms[arm == comp]
  dc <- a$costs - b$costs; dq <- a$qalys - b$qalys; dl <- a$lys - b$lys
  data.table(comparison = paste(ARM_LABELS[[int]], "vs", ARM_LABELS[[comp]]), int = int, comp = comp,
             inc_cost = dc, inc_qaly = dq, inc_ly = dl, icer = dc / dq, inmb = wtp * dq - dc,
             icer_label = icer_label(dc, dq))
}

#' Results at other drug prices, exactly
#'
#' @description Drug cost is linear in each price, so total cost at new prices is
#'   the run's cost minus its drug cost plus the treatment-years times the new
#'   prices. QALYs and life-years do not depend on price.
#' @param arms Arm table from summarise_deterministic()
#' @param prices0 Prices used for the run (drug_prices())
#' @param prices1 New prices: named numeric with any of the four price names
#' @return list(arms, incremental)
reprice <- function(arms, prices0, prices1, wtp = 120000, comparisons = DEFAULT_COMPARISONS) {
  p1 <- prices0; p1[names(prices1)] <- prices1
  ty <- treatment_years(arms, prices0)
  out <- merge(copy(arms), ty, by = "arm", sort = FALSE)
  pc <- c(sglt2i = p1[["cost_sglt2i"]], glp1ra = p1[["cost_glp1ra"]], soc = 0)
  pm <- c(sglt2i = p1[["cost_sglt2i_mcr"]], glp1ra = p1[["cost_glp1ra_mcr"]], soc = 0)
  out[, `:=`(drug_cost_com = d_com * pc[arm], drug_cost_mcr = d_mcr * pm[arm])]
  out[, costs := costs - drug_cost + drug_cost_com + drug_cost_mcr]
  out[, drug_cost := drug_cost_com + drug_cost_mcr]
  out[, c("d_com", "d_mcr") := NULL]
  comparisons <- Filter(function(cp) all(cp %in% out$arm), comparisons)
  list(arms = out, incremental = rbindlist(lapply(comparisons, function(cp) compare_tab(out, cp[1], cp[2], wtp))))
}

#' Threshold annual drug prices at which a comparison breaks even
#'
#' @description INMB is linear in each price: INMB(p) = INMB(p0) - (p - p0) * D,
#'   with D the discounted treatment-years in the payer period(s) whose price
#'   varies. Two thresholds per comparison and WTP: the commercial price with the
#'   Medicare price held at its base value, and a single price paid by all payers.
#' @param arms,incremental Tables from summarise_deterministic()
#' @param params Parameter lists used for the run (base prices)
#' @param wtps Willingness-to-pay thresholds
#' @return data.table: drug, comparison, basis, wtp, current_price, treatment years,
#'   INMB at current prices, threshold_price
threshold_prices <- function(arms, incremental, params, wtps = c(100000, 120000, 150000)) {
  pr <- drug_prices(params)
  ty <- treatment_years(arms, pr)
  pc <- c(sglt2i = pr[["cost_sglt2i"]], glp1ra = pr[["cost_glp1ra"]])
  inc <- function(a, b) incremental[incremental$int == a & incremental$comp == b]
  specs <- list(
    list(drug = "glp1ra", vs = "soc",    label = "GLP-1 RA + SoC vs SoC"),
    list(drug = "glp1ra", vs = "sglt2i", label = "GLP-1 RA + SoC vs SGLT2i + SoC"),
    list(drug = "sglt2i", vs = "soc",    label = "SGLT2i + SoC vs SoC"),
    list(drug = "sglt2i", vs = "glp1ra", label = "SGLT2i + SoC vs GLP-1 RA + SoC")
  )
  rbindlist(lapply(specs, function(sp) {
    row <- inc(sp$drug, sp$vs); sgn <- 1
    if (nrow(row) == 0) { row <- inc(sp$vs, sp$drug); sgn <- -1 }
    d_com <- ty[arm == sp$drug]$d_com; d_mcr <- ty[arm == sp$drug]$d_mcr
    drug0 <- arms[arm == sp$drug]$drug_cost
    rbindlist(lapply(wtps, function(w) {
      inmb <- sgn * (w * row$inc_qaly - row$inc_cost)
      data.table(drug = sp$drug, comparison = sp$label, wtp = w,
                 basis = c("Commercial price (Medicare price fixed)", "Single price, all payers"),
                 current_price = c(pc[[sp$drug]], drug0 / (d_com + d_mcr)),
                 discounted_treatment_years = c(d_com, d_com + d_mcr),
                 inmb_at_current_price = inmb,
                 threshold_price = c(pc[[sp$drug]] + inmb / d_com, (drug0 + inmb) / (d_com + d_mcr)))
    }))
  }))
}

#' Extract one-way DSA results from a WARDEN DSA run
#'
#' @param results_dsa Output of run_ckm_model(dsa = TRUE)
#' @param params The parameter lists used for the run
#' @param wtp Willingness-to-pay threshold
#' @param comparisons List of c(intervention, comparator) pairs
#' @return data.table: parameter, direction, value, plus compare_arms() columns
extract_dsa_results <- function(results_dsa, params, wtp = 120000,
                                comparisons = DEFAULT_COMPARISONS) {
  pnames <- unlist(params$parameter_name)
  active <- which(unlist(params$dsa_indicators) == 1)
  n_act <- length(active)
  if (length(results_dsa) != 2 * n_act) {
    stop(sprintf("Expected %d DSA analyses (2 x %d parameters), got %d",
                 2 * n_act, n_act, length(results_dsa)))
  }

  rbindlist(lapply(seq_along(results_dsa), function(k) {
    res <- results_dsa[[k]][[1]]
    direction <- res$sensitivity_name
    idx <- active[((k - 1) %% n_act) + 1]
    arms <- names(res$total_costs)
    cps <- Filter(function(cp) all(cp %in% arms), comparisons)
    out <- rbindlist(lapply(cps, function(cp) compare_arms(res, cp[1], cp[2], wtp)))
    out[, `:=`(parameter = pnames[idx], direction = direction,
               value = params[[direction]][[idx]], analysis = k)]
    setcolorder(out, c("parameter", "direction", "value", "analysis"))
    out
  }))
}

#' Tornado diagram for one pairwise comparison
#'
#' @param dsa_table Output of extract_dsa_results()
#' @param base_table `incremental` table from summarise_deterministic() (base case,
#'   same patients and seed as the DSA)
#' @param comparison_name Value of the `comparison` column to plot
#' @param outcome "inmb" (default; well-defined in every CE-plane quadrant) or "icer"
#' @param top_n Number of most influential parameters to show
#' @param wtp WTP used for INMB (for the axis label)
#' @return ggplot object (the plotted data is attached as attr "tornado_data")
generate_tornado <- function(dsa_table, base_table, comparison_name,
                             outcome = c("inmb", "icer"), top_n = 20, wtp = 120000) {
  outcome <- match.arg(outcome)
  base_val <- base_table[comparison == comparison_name][[outcome]]
  d <- dsa_table[comparison == comparison_name]
  wide <- dcast(d, parameter ~ direction, value.var = c(outcome, "value"))
  setnames(wide, c(paste0(outcome, "_DSA_min"), paste0(outcome, "_DSA_max")), c("out_low", "out_high"))
  wide[, range := abs(out_high - out_low)]
  wide <- wide[order(-range)][seq_len(min(top_n, .N))]

  fmt_val <- function(x) vapply(x, function(v) {
    if (abs(v) >= 100) format(round(v), big.mark = ",", trim = TRUE) else format(signif(v, 3), trim = TRUE)
  }, character(1))
  wide[, label := sprintf("%s (%s to %s)",
                          ifelse(parameter %in% names(PARAM_LABELS), PARAM_LABELS[parameter], parameter),
                          fmt_val(value_DSA_min), fmt_val(value_DSA_max))]
  wide[, label := factor(label, levels = rev(label))]

  bars <- rbind(
    wide[, .(label, input = "Lower input value", ymin = pmin(base_val, out_low), ymax = pmax(base_val, out_low))],
    wide[, .(label, input = "Upper input value", ymin = pmin(base_val, out_high), ymax = pmax(base_val, out_high))]
  )

  x_lab <- if (outcome == "inmb") {
    sprintf("Incremental net monetary benefit at $%s/QALY", format(wtp, big.mark = ","))
  } else {
    "ICER ($/QALY)"
  }

  p <- ggplot(bars) +
    geom_linerange(aes(y = label, xmin = ymin, xmax = ymax, colour = input),
                   linewidth = 5, position = position_dodge(width = 0.6)) +
    geom_vline(xintercept = base_val, linetype = "dashed") +
    scale_colour_manual(values = c("Lower input value" = "#2C7FB8", "Upper input value" = "#D95F0E")) +
    scale_x_continuous(labels = function(x) paste0("$", format(x, big.mark = ",", scientific = FALSE))) +
    labs(title = paste("One-way sensitivity analysis:", comparison_name),
         subtitle = sprintf("Base case %s = $%s; parameters ranked by range",
                            toupper(outcome), format(round(base_val), big.mark = ",")),
         x = x_lab, y = NULL, colour = NULL) +
    theme_minimal() +
    theme(legend.position = "bottom")

  attr(p, "tornado_data") <- wide
  p
}

#' Generate Cost-Effectiveness Acceptability Curve (CEAC) data
#'
#' @param results Output from WARDEN run_sim()
#' @param wtp_range Vector of WTP thresholds
#' @description Probability that each strategy has the highest net monetary
#'   benefit across PSA iterations. (WARDEN::ceac_des() only counts a strategy
#'   when its total NMB is positive, so at low WTP — where every strategy's total
#'   NMB is negative — it returns 0 for all arms.)
#' @return data.table: wtp, comparator, prob_best
#' @export
generate_ceac <- function(results, wtp_range = seq(0, 200000, by = 5000)) {
  sims <- results[[1]]
  costs <- do.call(rbind, lapply(sims, `[[`, "total_costs"))
  qalys <- do.call(rbind, lapply(sims, `[[`, "total_qalys"))
  rbindlist(lapply(wtp_range, function(w) {
    best <- colnames(costs)[max.col(w * qalys - costs, ties.method = "first")]
    data.table(wtp = w, comparator = colnames(costs),
               prob_best = vapply(colnames(costs), function(a) mean(best == a), numeric(1)))
  }))
}

#' Plot Cost-Effectiveness Plane (PSA)
#'
#' @param results Output from WARDEN run_sim() with n_sim > 1
#' @param wtp Willingness-to-pay threshold
#' @param comparisons List of c(intervention, comparator) pairs
#' @return ggplot object
#' @export
plot_ce_plane <- function(results, wtp = 120000, comparisons = DEFAULT_COMPARISONS) {
  inc_df <- rbindlist(lapply(seq_along(results[[1]]), function(s) {
    res <- results[[1]][[s]]
    cps <- Filter(function(cp) all(cp %in% names(res$total_costs)), comparisons)
    rbindlist(lapply(cps, function(cp) compare_arms(res, cp[1], cp[2], wtp)))[, sim := s]
  }))

  ggplot(inc_df, aes(x = inc_qaly, y = inc_cost, colour = comparison)) +
    geom_point(alpha = 0.5) +
    geom_abline(intercept = 0, slope = wtp, linetype = "dashed", colour = "grey30") +
    geom_vline(xintercept = 0, colour = "grey60") +
    geom_hline(yintercept = 0, colour = "grey60") +
    labs(
      title = "Cost-Effectiveness Plane",
      x = "Incremental QALYs",
      y = "Incremental Costs ($)",
      colour = NULL,
      subtitle = sprintf("Dashed line: WTP $%s/QALY", format(wtp, big.mark = ","))
    ) +
    theme_minimal() +
    theme(legend.position = "bottom")
}

#' Plot CEAC
#'
#' @param ceac_data Output from generate_ceac()
#' @return ggplot object
#' @export
plot_ceac <- function(ceac_data) {
  wtp_col <- grep("wtp", names(ceac_data), ignore.case = TRUE, value = TRUE)[1]
  prob_col <- grep("prob", names(ceac_data), ignore.case = TRUE, value = TRUE)[1]
  arm_col <- setdiff(names(ceac_data), c(wtp_col, prob_col))[1]

  p <- ggplot(ceac_data, aes(x = .data[[wtp_col]], y = .data[[prob_col]], color = .data[[arm_col]])) +
    geom_line(linewidth = 1) +
    labs(
      title = "Cost-Effectiveness Acceptability Curve",
      x = "Willingness-to-Pay Threshold ($)",
      y = "Probability of Being Cost-Effective",
      color = "Strategy"
    ) +
    theme_minimal() +
    scale_y_continuous(labels = scales::percent)

  return(p)
}

#' Create Results Tables
#'
#' @param results Output from WARDEN run_sim()
#' @param wtp Willingness-to-pay threshold
#' @param ref_arm Reference arm name
#' @return List of data.frames containing formatted tables
#' @export
create_results_tables <- function(results, wtp = 120000, ref_arm = "soc") {
  res_base <- results[[1]][[1]]

  # Clinical outcomes
  n_mi <- res_base$n_mi
  n_hf <- res_base$n_hf
  n_stroke <- res_base$n_stroke

  clin_df <- data.frame(
    Outcome = c("Myocardial Infarction", "Heart Failure", "Stroke")
  )

  arms <- names(res_base$total_lys)
  for (arm in arms) {
    clin_df[[paste0("Mean_", arm)]] <- c(
      ifelse(!is.null(n_mi), n_mi[arm], NA),
      ifelse(!is.null(n_hf), n_hf[arm], NA),
      ifelse(!is.null(n_stroke), n_stroke[arm], NA)
    )
  }

  # Cost categories
  cost_vars <- grep("^c_", names(res_base), value = TRUE)

  if (length(cost_vars) > 0) {
    cost_df <- data.frame(Category = cost_vars)
    for (arm in arms) {
      vals <- sapply(cost_vars, function(v) res_base[[v]][arm])
      cost_df[[paste0("Cost_", arm)]] <- vals
    }
  } else {
    cost_df <- data.frame(Category = character(0))
  }

  return(list(
    clinical_outcomes = clin_df,
    cost_breakdown = cost_df
  ))
}
