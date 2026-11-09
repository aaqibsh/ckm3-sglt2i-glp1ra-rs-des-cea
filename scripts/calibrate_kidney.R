#!/usr/bin/env Rscript
# =============================================================================
# CKM-HEOR: Calibration of the untreated eGFR decline (R3)
# =============================================================================
# Patient slope = egfr_decline_ref x (UACR/30)^egfr_uacr_beta x exp(sd*Z - sd^2/2)
#                 x band multiplier (1 at eGFR >= 45, egfr_mult_3b at 30-44,
#                 egfr_mult_4 below 30).
# Fitted targets (analytic, no simulation; death-free kidney failure as in KFRE):
#   1. KFRE 2- and 5-year kidney failure by eGFR band (45-59, 30-44, 20-29) in
#      simulated patients with eGFR < 60 (CKM stage 2-4 cohorts pooled), 4-variable
#      North American KFRE (Tangri 2016)
#   2. Placebo eGFR slopes in populations with the trials' baseline kidney
#      function: DAPA-CKD 3.83 mL/min/1.73 m2 per year (total slope; Heerspink
#      2021), eGFR 43.1 (SD 12.4), UACR median 949 (IQR 477-1885); FLOW 3.36
#      (Perkovic 2024), eGFR 47.0 (SD 15.2), UACR median 568 (5th-95th percentile
#      51-3225). The UACR exponent stays at the KFRE log(UACR) coefficient.
# Held back for validation (simulation, derive_manuscript_tables.R): Alberta life
# expectancy and lifetime kidney failure, USRDS 5-year outcomes.
# Usage: Rscript scripts/calibrate_kidney.R      (prints the fit; writes nothing
#        unless --write is given: outputs/tables/kidney_calibration_stage3.csv)
# =============================================================================

suppressMessages({
  source("R/00_setup.R")
  source("R/01_parameters.R")
  source("R/02_population.R")
  source("R/04_treatment.R")
})

args  <- commandArgs(trailingOnly = TRUE)
pv    <- function(nm) l_params$base_value[[match(nm, unlist(l_params$parameter_name))]]
beta  <- pv("egfr_uacr_beta")
N_REP <- 20

kfre <- function(age, male, egfr, uacr, yrs) {
  lp <- -0.2201 * (age / 10 - 7.036) + 0.2467 * (male - 0.5642) -
    0.5567 * (egfr / 5 - 7.222) + 0.4510 * (log(pmax(uacr, 1)) - 5.137)
  1 - (if (yrs == 2) 0.9832 else 0.9365)^exp(lp)
}

pop <- rbindlist(lapply(c(2, 3, 4), function(s) generate_ckm_population(2000, s, seed = SEED)))
pop <- pop[egfr < 60]
pop[, band := cut(egfr, c(0, 30, 45, 60), right = FALSE, labels = c("20-29", "30-44", "45-59"))]
pop[, `:=`(kfre2 = kfre(age, sex, egfr, uacr, 2), kfre5 = kfre(age, sex, egfr, uacr, 5))]
set.seed(SEED)
z <- matrix(rnorm(nrow(pop) * N_REP), nrow(pop))

trial_pop <- function(n, egfr_mean, egfr_sd, egfr_rng, uacr_med, uacr_sdlog) {
  set.seed(SEED)
  e <- rnorm(4 * n, egfr_mean, egfr_sd); e <- e[e >= egfr_rng[1] & e <= egfr_rng[2]][seq_len(n)]
  data.table(egfr = e, uacr = exp(rnorm(n, log(uacr_med), uacr_sdlog)))
}
dapa <- trial_pop(20000, 43.1, 12.4, c(25, 75), 949, log(1885 / 477) / (2 * qnorm(0.75)))
flow <- trial_pop(20000, 47.0, 15.2, c(25, 75), 568, log(3225 / 51) / (2 * qnorm(0.95)))
mean_slope <- function(d, ref, m3b, m4) {
  band_m <- ifelse(d$egfr < 30, m4, ifelse(d$egfr < 45, m3b, 1))
  ref * mean((pmax(d$uacr, 3) / 30)^beta * band_m)
}

fit_table <- function(x) {
  ref <- x[["ref"]]; sd <- x[["sdlog"]]; m3b <- x[["m3b"]]; m4 <- x[["m4"]]
  s <- ref * egfr_patient_multiplier(pop$uacr, beta, sd, z)
  t_kf <- years_to_egfr15(pop$egfr, s, m3b, m4)
  kf <- pop[, .(band)][, `:=`(m2 = rowMeans(t_kf <= 2), m5 = rowMeans(t_kf <= 5))]
  kf <- cbind(kf, pop[, .(kfre2, kfre5)])
  rows <- kf[, .(target = c(mean(kfre2), mean(kfre5)), model = c(mean(m2), mean(m5)),
                 measure = c("KFRE 2-y kidney failure", "KFRE 5-y kidney failure")), by = band]
  all_rows <- kf[, .(band = "All <60", target = c(mean(kfre2), mean(kfre5)), model = c(mean(m2), mean(m5)),
                     measure = c("KFRE 2-y kidney failure", "KFRE 5-y kidney failure"))]
  slopes <- data.table(band = c("DAPA-CKD population", "FLOW population"),
                       measure = "Placebo eGFR slope", target = c(3.83, 3.36),
                       model = c(mean_slope(dapa, ref, m3b, m4), mean_slope(flow, ref, m3b, m4)))
  rbind(rows, all_rows, slopes, use.names = TRUE)[, rel_diff := model / target - 1]
}

loss <- function(p, fixed_bands = FALSE) {
  x <- c(ref = exp(p[1]), sdlog = p[2], m3b = if (fixed_bands) 1 else exp(p[3]), m4 = if (fixed_bands) 1 else exp(p[4]))
  if (x[["sdlog"]] < 0.1 || x[["sdlog"]] > 2.5) return(1e6)
  f <- fit_table(x)[band != "All <60"]
  sum(log(f$model / f$target)^2)
}

report <- function(label, x) {
  f <- fit_table(x)
  cat(sprintf("\n== %s: ref %.3f, sdlog %.3f, mult 30-44 %.3f, mult <30 %.3f ==\n",
              label, x[["ref"]], x[["sdlog"]], x[["m3b"]], x[["m4"]]))
  print(f[, .(measure, band, target = round(target, 4), model = round(model, 4), rel_diff = sprintf("%+.0f%%", 100 * rel_diff))])
  invisible(f)
}

cur <- c(ref = pv("egfr_decline_ref"), sdlog = pv("egfr_slope_sdlog"), m3b = pv("egfr_mult_3b"), m4 = pv("egfr_mult_4"))
r2  <- c(ref = 0.65, sdlog = 1.5, m3b = 1, m4 = 1)   # R2 calibration (KFRE overall only)
report("R2 calibration", r2)
report("Current parameters (01_parameters.R)", cur)

o1 <- optim(c(log(1.4), 0.8), loss, fixed_bands = TRUE, method = "Nelder-Mead")
x1 <- c(ref = exp(o1$par[1]), sdlog = o1$par[2], m3b = 1, m4 = 1)
report("Fit, one decline rate", x1)

o2 <- optim(c(o1$par, 0, 0), loss, method = "Nelder-Mead", control = list(maxit = 2000))
x2 <- c(ref = exp(o2$par[1]), sdlog = o2$par[2], m3b = exp(o2$par[3]), m4 = exp(o2$par[4]))
f2 <- report("Fit, decline rate by eGFR band", x2)
cat(sprintf("\nLoss: R2 %.3f | base case %.3f | one rate %.3f | by band %.3f\n",
            loss(c(log(r2[["ref"]]), r2[["sdlog"]], 0, 0)),
            loss(c(log(cur[["ref"]]), cur[["sdlog"]], log(cur[["m3b"]]), log(cur[["m4"]]))), o1$value, o2$value))

if ("--write" %in% args) {
  fits <- list("R2 calibration" = r2, "One decline rate" = x1, "Decline rate by eGFR band (unconstrained)" = x2,
               "Base case (decline rate below eGFR 30)" = cur)
  out <- rbindlist(lapply(names(fits), function(k) {
    x <- fits[[k]]
    fit_table(x)[, `:=`(fit = k, ref = x[["ref"]], sdlog = x[["sdlog"]], mult_3b = x[["m3b"]], mult_4 = x[["m4"]])]
  }))
  fwrite(out, "outputs/tables/kidney_calibration_stage3.csv")
  cat("Written outputs/tables/kidney_calibration_stage3.csv\n")
}
