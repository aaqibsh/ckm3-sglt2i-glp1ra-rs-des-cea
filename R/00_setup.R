# ==============================================================================
# File: 00_setup.R
# Purpose: Setup and configuration script for the CKM-HEOR project
# Author: CKM-HEOR Team
# Date: 2026-10-14 (revised — production N = 20,000; PSA 10 chunks x 50 x 1,000; DSA shards)
# ==============================================================================

# ---- Section: Package Management ----

#' Ensure packages are installed and loaded
#'
#' @param pkgs Character vector of package names
ensure_packages <- function(pkgs) {
  for (pkg in pkgs) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      install.packages(pkg, dependencies = TRUE)
    }
    library(pkg, character.only = TRUE)
  }
}

# Required packages
required_packages <- c(
  "WARDEN",
  "data.table",
  "ggplot2",
  "MASS",
  "flexsurv",
  "preventr"
)

# Load packages
ensure_packages(required_packages)

# ---- Section: Global Options ----
options(scipen = 999, digits = 4)

# ---- Section: Run Configuration ----
# One switch controls analysis sizes everywhere: the environment variable
# CKM_MODE = "pilot" (default; quick checks) or "production" (final run).
#   Local:          CKM_MODE=production Rscript analysis/run_base_case.R 3
#   GitHub Actions: set by the workflow's "mode" input.
CKM_MODE <- Sys.getenv("CKM_MODE", "pilot")
if (!CKM_MODE %in% c("pilot", "production")) stop("CKM_MODE must be 'pilot' or 'production'")

RUN_SIZES <- list(
  pilot = list(
    base_patients = 500,   scen_patients = 200,   dsa_patients = 500,
    psa_patients  = 100,   psa_sims_per_chunk = 2
  ),
  production = list(
    base_patients = 20000, scen_patients = 20000, dsa_patients = 20000,
    psa_patients  = 1000,  psa_sims_per_chunk = 50
  )
)[[CKM_MODE]]

N_PSA_CHUNKS <- 10  # production: 10 x 50 = 500 PSA iterations
# One seed per PSA chunk. Distinct primes above the chunk size guarantee that no
# two chunks reuse a PSA parameter draw (WARDEN seeds simulation s with s * 1007 * seed).
# All stay within WARDEN's integer-overflow limit at production sizes
# (seed * n_sim * 1007 + seed * npats * 349 < 2^31).
PSA_CHUNK_SEEDS <- c(101, 103, 107, 109, 113, 127, 131, 137, 139, 149)

N_DSA_SHARDS <- 26  # one-way DSA parameters (50) split across this many R processes
# dsa_patients must equal base_patients: the tornado is centred on the base case.

SEED <- 42          # deterministic analyses; keep < 100 (WARDEN integer seed constraint)
DISCOUNT_RATE_COSTS <- 0.03
DISCOUNT_RATE_OUTCOMES <- 0.03
WTP_THRESHOLD <- 120000   # US standard

#' CKM stages requested on the command line (default: all three)
stages_from_args <- function(default = c(2, 3, 4)) {
  args <- commandArgs(trailingOnly = TRUE)
  st <- suppressWarnings(as.integer(args[1]))
  if (length(args) == 0 || is.na(st)) default else st
}

cat(sprintf("CKM_MODE = %s\n", CKM_MODE))
