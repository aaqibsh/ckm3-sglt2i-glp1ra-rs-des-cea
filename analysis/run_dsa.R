#!/usr/bin/env Rscript
# =============================================================================
# CKM-HEOR: One-way deterministic sensitivity analysis (sharded)
# =============================================================================
# Usage:  Rscript analysis/run_dsa.R <stage> [shard] [n_shards] [part n_parts]
#           shard omitted -> run every shard in turn (local use)
#           part/n_parts  -> run only part <part> of the shard's parameters (to rerun
#                            one shard as smaller jobs); writes ..._shard<j>_part<p>.csv
#         CKM_MODE=production Rscript analysis/run_dsa.R 3 5 12
#         CKM_MODE=production Rscript analysis/run_dsa.R 3 7 12 1 4
# Sizes:  same patients and seed as the base case (pilot 500 | production 20,000),
#         so each one-way result is directly comparable with the base case.
#
# Every uncertain model parameter is varied between its DSA bounds (eTable 3).
# Discount rates are reported as scenarios (run_scenarios.R) and the time
# horizon is a scenario, so they are excluded here. Parameters are assigned to
# shards round-robin; each shard writes outputs/tables/dsa_stage<k>_shard<j>.csv.
# Tornado diagrams are drawn after all shards are merged (combine_results.R).
# =============================================================================

cat("=== CKM-HEOR One-way DSA ===\n")
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

args     <- commandArgs(trailingOnly = TRUE)
stage    <- if (length(args) >= 1) as.integer(args[1]) else 3L
n_shards <- if (length(args) >= 3) as.integer(args[3]) else N_DSA_SHARDS
shards   <- if (length(args) >= 2) as.integer(args[2]) else seq_len(n_shards)
part     <- if (length(args) >= 4) as.integer(args[4]) else 1L
n_parts  <- if (length(args) >= 5) as.integer(args[5]) else 1L
stopifnot(stage %in% c(2, 3, 4), all(shards %in% seq_len(n_shards)),
          n_parts >= 1, part %in% seq_len(n_parts), n_parts == 1 || length(shards) == 1)
stopifnot(RUN_SIZES$dsa_patients == RUN_SIZES$base_patients)
n_pat <- RUN_SIZES$dsa_patients

pnames <- unlist(l_params$parameter_name)
EXCLUDED <- c("drc", "drq", "horizon_years")
DSA_PARAMS <- pnames[unlist(l_params$dsa_indicators) == 1 & !pnames %in% EXCLUDED]
cat(sprintf("%d parameters in the one-way DSA, %d shards\n", length(DSA_PARAMS), n_shards))

dir.create("outputs/tables", recursive = TRUE, showWarnings = FALSE)

for (shard in shards) {
  shard_params <- DSA_PARAMS[(seq_along(DSA_PARAMS) - 1) %% n_shards + 1 == shard]
  # Patient seeds do not depend on which parameters share a run, so a part gives
  # exactly the rows the whole shard would have given for its parameters
  shard_params <- shard_params[(seq_along(shard_params) - 1) %% n_parts + 1 == part]
  f <- if (n_parts == 1) sprintf("outputs/tables/dsa_stage%d_shard%d.csv", stage, shard) else
    sprintf("outputs/tables/dsa_stage%d_shard%d_part%d.csv", stage, shard, part)
  if (length(shard_params) == 0) next
  cat(sprintf("\n===== Stage %d, shard %d/%d%s: %d patients; %s =====\n",
              stage, shard, n_shards, if (n_parts > 1) sprintf(", part %d/%d", part, n_parts) else "",
              n_pat, paste(shard_params, collapse = ", ")))

  dsa_params <- l_params
  dsa_params$dsa_indicators <- as.list(as.numeric(pnames %in% shard_params))

  t_dsa <- system.time({
    res_dsa <- suppressMessages(run_ckm_model(ckm_stage = stage, n_patients = n_pat,
                                              seed = SEED, params = dsa_params, dsa = TRUE,
                                              ipd_level = 0))
  })
  dsa_tab <- extract_dsa_results(res_dsa, dsa_params, wtp = WTP_THRESHOLD)
  dsa_tab[, `:=`(stage = stage, shard = shard)]
  fwrite(dsa_tab, f)
  cat(sprintf("Saved %s (%.1f minutes)\n", f, t_dsa[3] / 60))
}

cat("\n=== DSA Complete ===\n")
cat("End time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
