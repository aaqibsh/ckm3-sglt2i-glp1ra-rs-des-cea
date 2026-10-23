#!/usr/bin/env Rscript
# =============================================================================
# CKM-HEOR: Combine job outputs into final results (CKM Stage 3)
# =============================================================================
# Usage:  Rscript analysis/combine_results.R
# Reads the outputs of run_base_case.R, run_scenarios.R (structural, agents),
# run_dsa.R (shards) and run_psa.R (chunks) under outputs/ — from a local run or
# a downloaded GitHub Actions artifact — and writes:
#   outputs/tables/scenarios_stage3_{arms,incremental}.csv
#   outputs/tables/agents_vs_soc_stage3.csv, agent_pairs_stage3.csv
#   outputs/tables/dsa_stage3_results.csv, dsa_stage3_summary.csv
#   outputs/tables/psa_stage3_{iterations,summary,convergence,ceac}.csv, run_times.csv
#   outputs/figures/tornado_stage3_*.png, ce_plane_stage3.png, ceac_stage3.png
#   outputs/RESULTS_SUMMARY.md
# =============================================================================

source("R/00_setup.R")
source("R/09_results.R")

STAGE <- 3
tab <- function(x) sprintf("outputs/tables/%s", x)
read_files <- function(pattern) {
  files <- list.files("outputs/tables", pattern = pattern, full.names = TRUE)
  if (length(files) == 0) return(NULL)
  rbindlist(lapply(files, fread), fill = TRUE)
}
md_table <- function(dt) {
  dt <- as.data.frame(dt)
  c(paste0("| ", paste(names(dt), collapse = " | "), " |"),
    paste0("|", paste(rep(":--", ncol(dt)), collapse = "|"), "|"),
    apply(dt, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")))
}
fmt_usd <- function(x) ifelse(is.na(x), "", paste0(ifelse(x < 0, "-$", "$"), format(round(abs(x)), big.mark = ",", trim = TRUE)))
pct <- function(x, d = 1) sprintf(paste0("%.", d, "f%%"), x)
dir.create("outputs/figures", recursive = TRUE, showWarnings = FALSE)
slug <- function(x) gsub("[^a-z0-9]+", "_", tolower(x))

md <- c("# CKM-HEOR Results — CKM Stage 3", "",
        sprintf("Generated %s (mode: %s). Willingness-to-pay $%s/QALY; costs in 2025 USD; 3%% discounting; lifetime horizon unless stated.",
                format(Sys.time(), "%Y-%m-%d %H:%M"), CKM_MODE, format(WTP_THRESHOLD, big.mark = ",")), "")

# ---- Base case ----
base_arms <- fread(tab(sprintf("base_case_stage%d_arms.csv", STAGE)))
base_inc  <- fread(tab(sprintf("base_case_stage%d_incremental.csv", STAGE)))
md <- c(md, "## Deterministic base case", "",
        md_table(base_arms[, .(Strategy = label, Costs = fmt_usd(costs), `Drug costs` = fmt_usd(drug_cost),
                               QALYs = sprintf("%.3f", qalys), LYs = sprintf("%.3f", lys),
                               `LYs undiscounted` = sprintf("%.2f", lys_undisc),
                               `Kidney failure (%)` = sprintf("%.1f", 100 * prop_eskd))]), "",
        md_table(base_inc[, .(Comparison = comparison, `Inc. cost` = fmt_usd(inc_cost),
                              `Inc. QALYs` = sprintf("%.3f", inc_qaly), `Inc. LYs` = sprintf("%.3f", inc_ly),
                              ICER = icer_label, INMB = fmt_usd(inmb))]), "")

# ---- Threshold prices ----
thr <- fread(tab(sprintf("threshold_prices_stage%d.csv", STAGE)))
md <- c(md, "## Threshold annual drug prices (INMB = 0)", "",
        md_table(thr[, .(Comparison = comparison, Basis = basis, WTP = fmt_usd(wtp), `Current price` = fmt_usd(current_price),
                         `Discounted treatment-years` = sprintf("%.2f", discounted_treatment_years),
                         `Threshold price` = fmt_usd(threshold_price))]), "")

# ---- Event burden, validation, cohort risk ----
ev <- fread(tab(sprintf("events_stage%d.csv", STAGE)))
md <- c(md, "## Clinical events (base case)", "",
        md_table(ev[, .(Arm = unname(ARM_LABELS[arm]),
                        `≥1 MI` = pct(pct_any_mi), `≥1 stroke` = pct(pct_any_stroke), `≥1 HF hosp.` = pct(pct_any_hf),
                        `MI /100 pts` = sprintf("%.1f", mi_per_100pts), `Stroke /100 pts` = sprintf("%.1f", stroke_per_100pts),
                        `HF hosp. /100 pts` = sprintf("%.1f", hf_per_100pts),
                        `MI /100 PY (5 y)` = sprintf("%.2f", mi_per_100py_5y),
                        `Stroke /100 PY (5 y)` = sprintf("%.2f", stroke_per_100py_5y),
                        `HF hosp. /100 PY (5 y)` = sprintf("%.2f", hf_per_100py_5y),
                        `Kidney failure` = pct(pct_kidney_failure), `CV death` = pct(cv_death_pct),
                        `Life expectancy (undisc.)` = sprintf("%.2f", life_expectancy_undisc))]), "")
val <- fread(tab(sprintf("validation_stage%d.csv", STAGE)))
rd  <- fread(tab(sprintf("risk_distribution_stage%d.csv", STAGE)))
md <- c(md, "## External validation (SoC arm)", "",
        md_table(val[, .(Check = check, Simulated = pct(100 * simulated),
                         `PREVENT predicted` = ifelse(is.na(predicted), "", pct(100 * predicted)))]), "",
        "PREVENT 10-year risk of the simulated cohort:", "",
        md_table(rd[, .(Measure = measure, Mean = pct(100 * mean), `25th pct` = pct(100 * p25),
                        Median = pct(100 * median), `75th pct` = pct(100 * p75), `≥20%` = pct(pct_ge_20))]), "")

# ---- Subgroups ----
sg <- fread(tab(sprintf("subgroups_stage%d.csv", STAGE)))
md <- c(md, "## Subgroups (base case patients)", "",
        md_table(sg[, .(Dimension = dimension, Subgroup = subgroup, N = n_patients, Comparison = comparison,
                        `Inc. cost` = fmt_usd(inc_cost), `Inc. QALYs` = sprintf("%.3f", inc_qaly),
                        ICER = icer_label, INMB = fmt_usd(inmb))]), "")

# ---- Scenarios ----
scen_inc  <- read_files(sprintf("^scenarios_stage%d_(structural|agents).*_incremental[.]csv$", STAGE))
scen_arms <- read_files(sprintf("^scenarios_stage%d_(structural|agents).*_arms[.]csv$", STAGE))
if (!is.null(scen_inc)) {
  fwrite(scen_inc, tab(sprintf("scenarios_stage%d_incremental.csv", STAGE)))
  fwrite(scen_arms, tab(sprintf("scenarios_stage%d_arms.csv", STAGE)))
  structural <- scen_inc[!grepl("^Agents:", scenario)]
  md <- c(md, "## Scenario analyses", "",
          md_table(rbind(base_inc[, .(scenario = "Base case", comparison, inc_cost, inc_qaly, icer_label, inmb)],
                         structural[, .(scenario, comparison, inc_cost, inc_qaly, icer_label, inmb)])[
            , .(Scenario = scenario, Comparison = comparison, `Inc. cost` = fmt_usd(inc_cost),
                `Inc. QALYs` = sprintf("%.3f", inc_qaly), ICER = icer_label, INMB = fmt_usd(inmb))]), "")

  # Agents: each run holds one SGLT2i agent (arm sglt2i) and one incretin (arm glp1ra)
  ag <- scen_arms[grepl("^Agents:", scenario)]
  if (nrow(ag) > 0) {
    ag[, agent := ifelse(arm == "soc", "SoC",
                         ifelse(arm == "sglt2i", sub("^Agents: ([^;]+);.*$", "\\1", scenario),
                                sub("^.*; ", "", scenario)))]
    ag[, agent := paste0(toupper(substr(agent, 1, 1)), substr(agent, 2, nchar(agent)))]
    soc <- ag[arm == "soc"]
    stopifnot(uniqueN(round(soc$costs, 6)) == 1)  # identical SoC arm in every run (CRN)
    soc <- soc[1]
    agents <- unique(ag[arm != "soc", .(agent, class = ifelse(arm == "sglt2i", "SGLT2i", "Incretin-based"),
                                        costs, qalys, lys)])
    vs_soc <- agents[, .(agent, class, inc_cost = costs - soc$costs, inc_qaly = qalys - soc$qalys,
                         inc_ly = lys - soc$lys)]
    vs_soc[, `:=`(icer_label = mapply(icer_label, inc_cost, inc_qaly), inmb = WTP_THRESHOLD * inc_qaly - inc_cost)]
    fwrite(vs_soc, tab(sprintf("agents_vs_soc_stage%d.csv", STAGE)))
    s_ag <- agents[class == "SGLT2i"]; i_ag <- agents[class != "SGLT2i"]
    pairs <- CJ(sglt2i_agent = s_ag$agent, incretin_agent = i_ag$agent)
    pairs[, `:=`(inc_cost = s_ag$costs[match(sglt2i_agent, s_ag$agent)] - i_ag$costs[match(incretin_agent, i_ag$agent)],
                 inc_qaly = s_ag$qalys[match(sglt2i_agent, s_ag$agent)] - i_ag$qalys[match(incretin_agent, i_ag$agent)],
                 inc_ly   = s_ag$lys[match(sglt2i_agent, s_ag$agent)] - i_ag$lys[match(incretin_agent, i_ag$agent)])]
    pairs[, `:=`(icer_label = mapply(icer_label, inc_cost, inc_qaly), inmb = WTP_THRESHOLD * inc_qaly - inc_cost)]
    fwrite(pairs, tab(sprintf("agent_pairs_stage%d.csv", STAGE)))
    md <- c(md, "## Individual agents vs SoC (exploratory)", "",
            md_table(vs_soc[, .(Agent = agent, Class = class, `Inc. cost` = fmt_usd(inc_cost),
                                `Inc. QALYs` = sprintf("%.3f", inc_qaly), ICER = icer_label, INMB = fmt_usd(inmb))]), "",
            "## SGLT2 inhibitor vs incretin-based agent, 16 pairs (exploratory)", "",
            md_table(pairs[, .(`SGLT2i agent` = sglt2i_agent, `Incretin agent` = incretin_agent,
                               `Inc. cost` = fmt_usd(inc_cost), `Inc. QALYs` = sprintf("%.3f", inc_qaly),
                               ICER = icer_label, INMB = fmt_usd(inmb))]), "")
  }
}

# ---- DSA ----
dsa_res <- read_files(sprintf("^dsa_stage%d_shard[0-9]+(_part[0-9]+)?[.]csv$", STAGE))
if (!is.null(dsa_res)) {
  dsa_res <- unique(dsa_res, by = c("comparison", "parameter", "direction"))
  if (uniqueN(dsa_res$shard) < N_DSA_SHARDS) warning(sprintf("Only %d of %d DSA shards present", uniqueN(dsa_res$shard), N_DSA_SHARDS))
  fwrite(dsa_res, tab(sprintf("dsa_stage%d_results.csv", STAGE)))
  wide <- dcast(dsa_res, comparison + parameter ~ direction, value.var = "inmb")
  wide <- merge(wide, base_inc[, .(comparison, base_inmb = inmb)], by = "comparison")
  wide[, range := abs(DSA_max - DSA_min)]
  dsa_sum <- wide[order(comparison, -range)][, .(
    n_parameters = .N, base_inmb = base_inmb[1],
    inmb_min = min(DSA_min, DSA_max), inmb_max = max(DSA_min, DSA_max),
    n_sign_changes = sum(sign(DSA_min) != sign(base_inmb) | sign(DSA_max) != sign(base_inmb)),
    top_drivers = paste(head(ifelse(parameter %in% names(PARAM_LABELS), PARAM_LABELS[parameter], parameter), 5),
                        collapse = "; ")
  ), by = comparison]
  fwrite(dsa_sum, tab(sprintf("dsa_stage%d_summary.csv", STAGE)))
  md <- c(md, "## One-way sensitivity analysis (INMB)", "",
          md_table(dsa_sum[, .(Comparison = comparison, Parameters = n_parameters, `Base INMB` = fmt_usd(base_inmb),
                               `DSA range` = paste(fmt_usd(inmb_min), "to", fmt_usd(inmb_max)),
                               `Bounds changing sign` = n_sign_changes, `Top 5 drivers` = top_drivers)]), "")
  for (cmp in base_inc$comparison) {
    p <- generate_tornado(dsa_res, base_inc, cmp, outcome = "inmb", top_n = 15, wtp = WTP_THRESHOLD)
    ggsave(sprintf("outputs/figures/tornado_stage%d_%s.png", STAGE, slug(cmp)), p, width = 10, height = 7, dpi = 300)
  }
}

# ---- PSA ----
psa_files <- list.files("outputs/psa", pattern = sprintf("^psa_stage%d_chunk[0-9]+[.]rds$", STAGE), full.names = TRUE)
if (length(psa_files) > 0) {
  chunks <- lapply(psa_files, readRDS)
  info <- rbindlist(lapply(seq_along(chunks), function(k) {
    a <- attr(chunks[[k]], "run_info")
    data.table(file = basename(psa_files[k]), mode = a$mode, n_patients = a$n_patients,
               n_sim = a$n_sim, minutes = round(a$minutes, 1))
  }))
  fwrite(info, tab("run_times.csv"))
  if (uniqueN(info[, .(mode, n_patients, n_sim)]) > 1) stop("PSA chunks come from different run configurations; remove old chunk files")
  if (nrow(info) < N_PSA_CHUNKS) warning(sprintf("Only %d of %d PSA chunks present", nrow(info), N_PSA_CHUNKS))
  d <- rbindlist(chunks)[order(iteration)]
  results_like <- list(lapply(split(d, d$iteration), function(x) list(
    total_costs = setNames(x$costs, x$arm), total_qalys = setNames(x$qalys, x$arm),
    total_lys = setNames(x$lys, x$arm))))
  inc <- rbindlist(lapply(seq_along(results_like[[1]]), function(s) {
    rbindlist(lapply(DEFAULT_COMPARISONS, function(cp) compare_arms(results_like[[1]][[s]], cp[1], cp[2], WTP_THRESHOLD)))[, iteration := s]
  }))
  psa_sum <- inc[, .(n_iterations = .N, patients_per_iteration = info$n_patients[1],
                     mean_inc_cost = mean(inc_cost), mean_inc_qaly = mean(inc_qaly),
                     icer_of_mean_values = mean(inc_cost) / mean(inc_qaly),
                     mean_inmb = mean(inmb),
                     inmb_ui_2.5 = quantile(inmb, 0.025), inmb_ui_97.5 = quantile(inmb, 0.975),
                     prob_cost_effective = mean(inmb > 0),
                     prob_dominant = mean(inc_cost <= 0 & inc_qaly >= 0)), by = comparison]
  conv <- inc[order(iteration), .(iteration, running_mean_inmb = cumsum(inmb) / seq_along(inmb)), by = comparison]
  ceac <- generate_ceac(results_like, wtp_range = seq(0, 300000, by = 5000))
  fwrite(inc, tab(sprintf("psa_stage%d_iterations.csv", STAGE)))
  fwrite(psa_sum, tab(sprintf("psa_stage%d_summary.csv", STAGE)))
  fwrite(conv, tab(sprintf("psa_stage%d_convergence.csv", STAGE)))
  fwrite(ceac, tab(sprintf("psa_stage%d_ceac.csv", STAGE)))
  ggsave(sprintf("outputs/figures/ce_plane_stage%d.png", STAGE), plot_ce_plane(results_like, wtp = WTP_THRESHOLD),
         width = 8, height = 6, dpi = 300)
  ggsave(sprintf("outputs/figures/ceac_stage%d.png", STAGE), plot_ceac(ceac), width = 8, height = 6, dpi = 300)
  md <- c(md, "## Probabilistic sensitivity analysis", "",
          md_table(psa_sum[, .(Comparison = comparison, Iterations = n_iterations, `Patients/iteration` = patients_per_iteration,
                               `Mean inc. cost` = fmt_usd(mean_inc_cost), `Mean inc. QALYs` = sprintf("%.3f", mean_inc_qaly),
                               `ICER of mean values` = mapply(icer_label, mean_inc_cost, mean_inc_qaly),
                               `Mean INMB (95% UI)` = sprintf("%s (%s to %s)", fmt_usd(mean_inmb), fmt_usd(inmb_ui_2.5), fmt_usd(inmb_ui_97.5)),
                               `P(cost-effective)` = pct(100 * prob_cost_effective), `P(dominant)` = pct(100 * prob_dominant))]), "",
          "Probability each strategy is preferred:", "",
          md_table(dcast(ceac[wtp %in% c(50000, 100000, 120000, 150000)], wtp ~ comparator, value.var = "prob_best")[
            , .(WTP = fmt_usd(wtp), `SGLT2i + SoC` = pct(100 * sglt2i), `GLP-1 RA + SoC` = pct(100 * glp1ra), SoC = pct(100 * soc))]), "")
}

writeLines(md, "outputs/RESULTS_SUMMARY.md")
cat(paste(md, collapse = "\n"), "\n")
cat("\n=== Combine Complete ===\n")
