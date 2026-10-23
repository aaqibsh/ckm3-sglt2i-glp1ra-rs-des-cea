#!/usr/bin/env Rscript
# =============================================================================
# CKM-HEOR: Probabilistic Sensitivity Analysis (chunked, resumable)
# =============================================================================
# Usage:  Rscript analysis/run_psa.R <stage> [chunk]
#           chunk given   -> run only that chunk (1..N_PSA_CHUNKS); used by GitHub Actions
#           chunk omitted -> run all chunks for the stage, skipping chunks already saved
#         CKM_MODE=production Rscript analysis/run_psa.R 3
# Sizes:  pilot 2 sims x 100 patients per chunk | production 50 sims x 1,000 patients
#         per chunk; 10 chunks per stage (production: 500 iterations per stage).
#
# Each chunk uses its own seed (PSA_CHUNK_SEEDS, 00_setup.R) so chunks never
# repeat a PSA parameter draw, runs single-core, stores aggregate results only,
# and is saved as outputs/psa/psa_stage<k>_chunk<j>.rds. Combine chunks with
# analysis/combine_results.R.
# =============================================================================

cat("=== CKM-HEOR PSA ===\n")
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

args   <- commandArgs(trailingOnly = TRUE)
stage  <- if (length(args) >= 1) as.integer(args[1]) else 3
chunks <- if (length(args) >= 2) as.integer(args[2]) else seq_len(N_PSA_CHUNKS)
stopifnot(stage %in% c(2, 3, 4), all(chunks %in% seq_len(N_PSA_CHUNKS)))

n_pat  <- RUN_SIZES$psa_patients
n_sim  <- RUN_SIZES$psa_sims_per_chunk
dir.create("outputs/psa", recursive = TRUE, showWarnings = FALSE)

for (chunk in chunks) {
  f <- sprintf("outputs/psa/psa_stage%d_chunk%d.rds", stage, chunk)
  if (file.exists(f)) {
    cat(sprintf("Stage %d chunk %d already saved (%s); skipping\n", stage, chunk, f))
    next
  }
  seed <- PSA_CHUNK_SEEDS[chunk]
  cat(sprintf("\n--- Stage %d, chunk %d/%d: %d sims x %d patients, seed %d ---\n",
              stage, chunk, N_PSA_CHUNKS, n_sim, n_pat, seed))

  t_run <- system.time(
    res <- suppressMessages(run_ckm_model(ckm_stage = stage, n_patients = n_pat, n_sim = n_sim,
                                          psa_bool = TRUE, seed = seed, ipd_level = 0))
  )

  sims <- rbindlist(lapply(seq_along(res[[1]]), function(s) {
    r <- res[[1]][[s]]
    arms <- names(r$total_costs)
    data.table(stage = stage, chunk = chunk, seed = seed, sim_in_chunk = s,
               iteration = (chunk - 1) * n_sim + s, arm = arms,
               costs = unname(r$total_costs[arms]), qalys = unname(r$total_qalys[arms]),
               lys = unname(r$total_lys[arms]))
  }))
  attr(sims, "run_info") <- list(mode = CKM_MODE, n_patients = n_pat, n_sim = n_sim,
                                 minutes = unname(t_run[3]) / 60, finished = Sys.time())
  saveRDS(sims, f)
  cat(sprintf("Saved %s (%.1f minutes)\n", f, t_run[3] / 60))
}

cat("\n=== PSA Complete ===\n")
cat("End time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
