# data-raw/make_examples.R ---------------------------------------------------
#
# Regenerates every CSV in data/examples/ from fixed seeds, then runs the full
# assessment on every file and prints a verification table.
#
# Run from the repository root:
#
#     Rscript data-raw/make_examples.R
#
# Writes nineteen comma-delimited CSVs (header row, no row names) into
# data/examples/, in five families:
#
#   REAL DATA (3, unchanged)
#     nwtco_high_risk.csv  survival::nwtco, stage %in% c(3, 4)
#     gbsg.csv             survival::gbsg, all rows
#     colon_lev5fu.csv     survival::colon, etype == 1 & rx == "Lev+5FU"
#
#   FOUR CORNERS (4, unchanged, seed 11, columns Y / D)
#     sim_a.csv .. sim_d.csv
#
#   CURE-FRACTION LADDER (5, new, columns time / status)
#     sim_pi00.csv sim_pi10.csv sim_pi30.csv sim_pi60.csv sim_pi90.csv
#
#   FOLLOW-UP LADDER (4, new, columns time / status)
#     sim_fu25.csv sim_fu10.csv sim_fu05.csv sim_fu01.csv
#
#   CENSORING AND SAMPLE-SIZE STRESS (3, new, columns time / status)
#     sim_dropout.csv sim_small.csv sim_lastevent.csv
#
# The three real datasets are subset and exported with their ORIGINAL column
# names, so the app's column mapper has a real mapping problem to solve.
#
# The registry that tells the app how to map each of these files is
# CA_DATASETS in app/R/datasets.R. If you add or rename a file here, change
# that registry too.


# ---- fixed simulation constants --------------------------------------------

# The four original corners. Frozen: these four files and their four registry
# entries must not change, so their generator, constants and seed are frozen
# with them.
SIM_SEED  <- 11L
SIM_N     <- 300L
SIM_SHAPE <- 1.2
SIM_SCALE <- 1

# The expanded library. One seed, set inside the generator before every
# scenario, so each scenario is reproducible independently of the order the
# scenarios are written in -- the same convention the four corners use.
RECEUS_SEED  <- 2026L
RECEUS_SHAPE <- 2       # Weibull(2, 1) uncured survival: the main-text
RECEUS_SCALE <- 1       # generating distribution of Selukar & Othus (2023)


#' Locate the repository root from wherever the script was started
#'
#' Walks up at most five directories from `start` looking for the
#' `data-raw/` + `cureAssess/` pair that only the repository root has, so the
#' script works from the root, from `data-raw/`, or from an IDE. Stops rather
#' than guessing a path.
find_repo_root <- function(start = getwd()) {
  d <- normalizePath(start, mustWork = TRUE)
  for (i in seq_len(5L)) {
    if (dir.exists(file.path(d, "data-raw")) && dir.exists(file.path(d, "cureAssess"))) {
      return(d)
    }
    parent <- dirname(d)
    if (identical(parent, d)) break
    d <- parent
  }
  stop("Could not find the repository root from '", start,
       "'. Run this script from the repository root.", call. = FALSE)
}


#' Write one example CSV
#'
#' Comma delimited, header row, no row names, unquoted. Refuses to write a
#' frame whose character or factor fields contain a comma, a double quote or a
#' newline, because unquoted output would silently corrupt such a file.
write_example <- function(x, file, out_dir) {
  txt <- unlist(lapply(x, function(col) {
    if (is.character(col) || is.factor(col)) as.character(col) else character(0)
  }), use.names = FALSE)
  if (length(txt) && any(grepl('[,"\n]', txt))) {
    stop("Refusing to write ", file,
         " unquoted: a text field contains a comma, quote or newline.",
         call. = FALSE)
  }
  path <- file.path(out_dir, file)
  utils::write.csv(x, path, row.names = FALSE, quote = FALSE, na = "NA")
  invisible(path)
}


# ---- generator 1: the original four corners (frozen) -----------------------

#' Simulate a survival dataset with a known cure fraction
#'
#' The original reference implementation (docs/data-contract.md section 8),
#' kept verbatim so sim_a .. sim_d are bit-for-bit what they were. A cured
#' subject gets a latent event time of `Inf`, so they can only ever be
#' censored; censoring is the earlier of random dropout and a flat
#' administrative end of follow-up, with no accrual. `set.seed()` is called
#' inside the function, so each scenario is reproducible independently of the
#' order they are generated in. The returned frame is in the `Y` / `D` naming
#' scheme these four files have always used.
simulate_cure_data <- function(n = 300, cure_fraction = 0.3, shape = 1.0,
                               scale = 1.0, admin_followup = 5,
                               dropout_rate = 0.05, seed = 1) {
  set.seed(seed)
  cured   <- rbinom(n, 1, cure_fraction)
  T_event <- ifelse(cured == 1, Inf, rweibull(n, shape = shape, scale = scale))
  C_drop  <- if (dropout_rate > 0) rexp(n, rate = dropout_rate) else rep(Inf, n)
  C       <- pmin(C_drop, admin_followup)
  data.frame(Y = pmin(T_event, C), D = as.integer(T_event <= C), .cured = cured)
}


# ---- generator 2: the RECeUS trial design ----------------------------------

#' Simulate a mixture-cure trial the way Selukar & Othus (2023) do
#'
#' Reproduces the data-generating mechanism of the RECeUS simulation study
#' (Statistics in Medicine 42(3):209-227, Sections 2.3 and 3.1), which is also
#' the mechanism used by the two-sample long-term-survivor study:
#'
#'   * event times come from the mixture S(t) = pi + (1 - pi) * S_uc(t), with
#'     S_uc a Weibull(shape, scale); a cured subject has a latent event time
#'     of Inf and can only ever be censored;
#'   * subjects accrue uniformly over (0, a) with a = q75 / 2, half the 75th
#'     percentile of the uncured distribution;
#'   * the analysis happens at a fixed administrative time `tau`, so subject i
#'     has follow-up tau - A_i;
#'   * follow-up length is indexed by `u`, the fraction of UNCURED subjects
#'     still event-free at tau, so the same `u` means the same maturity across
#'     distributions. tau solves S_uc(tau) = u and is then rounded to the
#'     nearest quarter, exactly as the paper does, to imitate an analysis at a
#'     prespecified calendar date. For Weibull(2, 1) this reproduces the
#'     paper's tau values 1.25, 1.5, 1.75, 2.25, 2.75 for
#'     u = 0.25, 0.10, 0.05, 0.01, 0.001.
#'
#' `dropout_rate` is the one extension beyond the paper: an optional
#' exponential loss-to-follow-up time competing with the administrative one.
#' The paper has no dropout; rate 0 reproduces it exactly.
#'
#' @return a data.frame with the user-facing columns `time` and `status`
#'   (1 = event, 0 = censored) plus `.cured`, the latent ground truth, which
#'   the caller drops before writing.
simulate_receus_trial <- function(n, cure_fraction, u,
                                  shape = RECEUS_SHAPE, scale = RECEUS_SCALE,
                                  dropout_rate = 0, seed = 1) {
  set.seed(seed)

  q75     <- scale * (-log(0.25))^(1 / shape)   # 75th percentile of S_uc
  accrual <- q75 / 2
  tau     <- round(scale * (-log(u))^(1 / shape) * 4) / 4

  cured   <- rbinom(n, 1, cure_fraction)
  T_event <- ifelse(cured == 1, Inf, rweibull(n, shape = shape, scale = scale))

  A <- runif(n, 0, accrual)
  C <- tau - A
  if (dropout_rate > 0) C <- pmin(C, rexp(n, rate = dropout_rate))

  data.frame(time   = pmin(T_event, C),
             status = as.integer(T_event <= C),
             .cured = cured)
}


# ---- locate the output directory ------------------------------------------

root    <- find_repo_root()
out_dir <- file.path(root, "data", "examples")
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

message("Repository root: ", root)
message("Writing to:      ", out_dir)


# ---- 1. real datasets, original column names kept -------------------------

# survival::nwtco, high-risk subset. `stage` is an integer 1-4; stages 3 and 4
# are the high-risk group. Time is `edrel` (days), status is `rel` (1 = relapse).
# Every original column is kept, including the logical `in.subcohort`, which is
# a deliberate trap for the column mapper (docs/data-contract.md section 7).
nwtco_high_risk <- subset(survival::nwtco, stage %in% c(3L, 4L))
rownames(nwtco_high_risk) <- NULL

# survival::gbsg, all rows. Time is `rfstime` (days), status is `status`.
gbsg <- survival::gbsg
rownames(gbsg) <- NULL

# survival::colon, the Lev+5FU arm, recurrence endpoint. `etype == 1` is the
# recurrence record, which also makes the frame one row per subject; `rx` is a
# factor with levels Obs / Lev / Lev+5FU and one arm at a time is what the data
# contract requires. Time is `time` (days), status is `status`.
colon_lev5fu <- subset(survival::colon, etype == 1 & rx == "Lev+5FU")
rownames(colon_lev5fu) <- NULL

write_example(nwtco_high_risk, "nwtco_high_risk.csv", out_dir)
write_example(gbsg,            "gbsg.csv",            out_dir)
write_example(colon_lev5fu,    "colon_lev5fu.csv",    out_dir)


# ---- 2. the original four corners (frozen) ---------------------------------
#
#   A  a real cure fraction with follow-up long enough to see it
#   B  the same cure fraction with follow-up cut short, so it is invisible
#   C  no cure fraction at all, light censoring: the study ends on an event
#   D  no cure fraction, heavy dropout: a plateau that is a censoring artifact
#
# C and D reach the not-computable condition by construction rather than by
# luck: with a true cure fraction of zero every subject has a finite event
# time, and the administrative limit of 10 sits far out in the Weibull(1.2, 1)
# tail, so the last subject standing is almost certainly one who had the event
# rather than one who ran out of follow-up. The verification block re-checks it
# on every regeneration instead of trusting that argument.

sim_specs <- list(
  sim_a = list(cure_fraction = 0.40, admin_followup = 10,  dropout_rate = 0.03),
  sim_b = list(cure_fraction = 0.40, admin_followup = 1.5, dropout_rate = 0.03),
  sim_c = list(cure_fraction = 0.00, admin_followup = 10,  dropout_rate = 0.03),
  sim_d = list(cure_fraction = 0.00, admin_followup = 10,  dropout_rate = 0.45)
)

for (key in names(sim_specs)) {
  d <- do.call(
    simulate_cure_data,
    c(list(n = SIM_N, shape = SIM_SHAPE, scale = SIM_SCALE, seed = SIM_SEED),
      sim_specs[[key]])
  )
  # `.cured` is ground truth for verification only and must never reach the
  # app, where it could be picked as a status column.
  write_example(d[, c("Y", "D"), drop = FALSE], paste0(key, ".csv"), out_dir)
}


# ---- 3. the expanded library -----------------------------------------------
#
# Three families, all drawn from the RECeUS trial design above with
# Weibull(2, 1) uncured survival.
#
# CURE-FRACTION LADDER  n = 500, u = 0.001 (tau = 2.75, mature follow-up),
#   cure fraction climbing 0 -> 0.90. This is the top row of the paper's
#   Figure 3 / Table 2 grid: the setting in which the method is supposed to
#   say yes for every nonzero cure fraction and no at zero. pi = 0.90 is one
#   rung beyond the paper's 0.80 ceiling and is ours, to show the method
#   under near-total cure and 90%+ censoring.
#
# FOLLOW-UP LADDER  n = 1000, cure fraction fixed at 0.60, u walking
#   0.25 -> 0.01 (tau = 1.25, 1.50, 1.75, 2.25). Straight off the columns of
#   the paper's Table 2. The same population, analysed earlier and earlier;
#   the point at which the verdict flips is the whole subject of the tool.
#   The fifth rung of this ladder, u = 0.001, is sim_pi60 (at n = 500).
#
# STRESS  three designed gap-fillers, not in the paper:
#   sim_dropout    a mature study destroyed by loss to follow-up
#   sim_small      n = 50, the smallest arm size in the two-sample study
#   sim_lastevent  no cure fraction, follow-up run into the tail, so the
#                  largest observed time is an EVENT and the three plateau
#                  diagnostics are undefined

RECEUS_SPECS <- list(

  # -- cure-fraction ladder, mature follow-up --------------------------------
  sim_pi00 = list(n = 500, cure_fraction = 0.00, u = 0.001),
  sim_pi10 = list(n = 500, cure_fraction = 0.10, u = 0.001),
  sim_pi30 = list(n = 500, cure_fraction = 0.30, u = 0.001),
  sim_pi60 = list(n = 500, cure_fraction = 0.60, u = 0.001),
  sim_pi90 = list(n = 500, cure_fraction = 0.90, u = 0.001),

  # -- follow-up ladder, cure fraction fixed at 0.60 -------------------------
  sim_fu25 = list(n = 1000, cure_fraction = 0.60, u = 0.25),
  sim_fu10 = list(n = 1000, cure_fraction = 0.60, u = 0.10),
  sim_fu05 = list(n = 1000, cure_fraction = 0.60, u = 0.05),
  sim_fu01 = list(n = 1000, cure_fraction = 0.60, u = 0.01),

  # -- censoring and sample-size stress --------------------------------------
  sim_dropout   = list(n = 400, cure_fraction = 0.50, u = 0.001, dropout_rate = 1.5),
  sim_small     = list(n =  50, cure_fraction = 0.50, u = 0.001),
  sim_lastevent = list(n = 250, cure_fraction = 0.00, u = 0.05)
)

for (key in names(RECEUS_SPECS)) {
  d <- do.call(simulate_receus_trial,
               c(RECEUS_SPECS[[key]], list(seed = RECEUS_SEED)))
  # `.cured` is ground truth for verification only and must never reach the
  # app, where it could be picked as a status column.
  write_example(d[, c("time", "status"), drop = FALSE],
                paste0(key, ".csv"), out_dir)
}


# ---- 4. verification -------------------------------------------------------
#
# Re-reads every file from disk and runs the complete assessment on it, with
# the same column mapping and time scaling the app's registry uses, then
# prints n, events, the best model, its AIC, the three follow-up diagnostics,
# the two RECeUS quantities and the RECeUS decision.
#
# Every number in the table below is read off the returned object. Nothing in
# this block computes a statistic.

suppressPackageStartupMessages({
  library(cureAssess)
})

# time / status / event level / time_scale must match app/R/datasets.R exactly.
# `expect` is the RECeUS decision the scenario is documented to produce, and
# `expect_na` records whether the three follow-up diagnostics are expected to
# be unavailable because the largest observed time is an event.
CHECKS <- list(
  list(file = "gbsg.csv",            time = "rfstime", status = "status", event = "1", scale = "days_to_years", n = 686L,  expect = "Follow-up insufficient for cure modeling", expect_na = FALSE),
  list(file = "nwtco_high_risk.csv", time = "edrel",   status = "rel",    event = "1", scale = "days_to_years", n = 1404L, expect = "Cure model appropriate",                 expect_na = FALSE),
  list(file = "colon_lev5fu.csv",    time = "time",    status = "status", event = "1", scale = "days_to_years", n = 304L,  expect = "Follow-up insufficient for cure modeling", expect_na = FALSE),

  list(file = "sim_a.csv", time = "Y", status = "D", event = "1", scale = "none", n = 300L, expect = "Cure model appropriate",  expect_na = FALSE),
  list(file = "sim_b.csv", time = "Y", status = "D", event = "1", scale = "none", n = 300L, expect = "Cure model not supported", expect_na = FALSE),
  list(file = "sim_c.csv", time = "Y", status = "D", event = "1", scale = "none", n = 300L, expect = "Cure model not supported", expect_na = TRUE),
  list(file = "sim_d.csv", time = "Y", status = "D", event = "1", scale = "none", n = 300L, expect = "Cure model not supported", expect_na = TRUE),

  list(file = "sim_pi00.csv", time = "time", status = "status", event = "1", scale = "none", n = 500L,  expect = "Cure model not supported", expect_na = FALSE),
  list(file = "sim_pi10.csv", time = "time", status = "status", event = "1", scale = "none", n = 500L,  expect = "Cure model appropriate",   expect_na = FALSE),
  list(file = "sim_pi30.csv", time = "time", status = "status", event = "1", scale = "none", n = 500L,  expect = "Cure model appropriate",   expect_na = FALSE),
  list(file = "sim_pi60.csv", time = "time", status = "status", event = "1", scale = "none", n = 500L,  expect = "Cure model appropriate",   expect_na = FALSE),
  list(file = "sim_pi90.csv", time = "time", status = "status", event = "1", scale = "none", n = 500L,  expect = "Cure model appropriate",   expect_na = FALSE),

  list(file = "sim_fu25.csv", time = "time", status = "status", event = "1", scale = "none", n = 1000L, expect = "Follow-up insufficient for cure modeling", expect_na = FALSE),
  list(file = "sim_fu10.csv", time = "time", status = "status", event = "1", scale = "none", n = 1000L, expect = "Follow-up insufficient for cure modeling", expect_na = FALSE),
  list(file = "sim_fu05.csv", time = "time", status = "status", event = "1", scale = "none", n = 1000L, expect = "Follow-up insufficient for cure modeling", expect_na = FALSE),
  list(file = "sim_fu01.csv", time = "time", status = "status", event = "1", scale = "none", n = 1000L, expect = "Cure model appropriate",                   expect_na = FALSE),

  list(file = "sim_dropout.csv",   time = "time", status = "status", event = "1", scale = "none", n = 400L, expect = "Follow-up insufficient for cure modeling", expect_na = FALSE),
  list(file = "sim_small.csv",     time = "time", status = "status", event = "1", scale = "none", n =  50L, expect = "Cure model appropriate",                   expect_na = FALSE),
  list(file = "sim_lastevent.csv", time = "time", status = "status", event = "1", scale = "none", n = 250L, expect = "Cure model not supported",                 expect_na = TRUE)
)

fmt <- function(x, digits = 4) {
  if (is.null(x) || length(x) != 1L || is.na(x)) "     --" else
    formatC(as.numeric(x), format = "f", digits = digits, width = 7)
}

message("")
message(strrep("-", 150))
message(sprintf(
  "%-20s %5s %6s %6s %-18s %9s %8s %8s %8s %8s %8s  %s",
  "file", "n", "events", "cens%", "best model", "AIC",
  "MZ", "qn", "Shen", "pi-hat", "r-hat", "RECeUS decision"))
message(strrep("-", 150))

failures <- character(0)

for (ck in CHECKS) {
  raw <- utils::read.csv(file.path(out_dir, ck$file), stringsAsFactors = FALSE)

  # Status is recoded to 0/1 before any package call (app rule S5), and the
  # time scaling is left to prepare.surv.data() inside cure.appropriateness()
  # so it happens exactly once.
  d <- raw
  d[[ck$status]] <- as.integer(as.character(raw[[ck$status]]) == ck$event)

  res <- tryCatch(
    cure.appropriateness(
      data       = d,
      time       = ck$time,
      status     = ck$status,
      time_scale = ck$scale,
      plot_km    = FALSE,
      run_tests  = "yes"
    ),
    error = function(e) e
  )

  if (inherits(res, "error")) {
    failures <- c(failures, sprintf("%s: assessment failed: %s",
                                    ck$file, conditionMessage(res)))
    message(sprintf("%-20s  ASSESSMENT FAILED: %s", ck$file,
                    conditionMessage(res)))
    next
  }

  n       <- nrow(res$data)
  events  <- sum(res$data$D == 1L)
  censpct <- 100 * (1 - events / n)
  imax    <- which.max(res$data$Y)
  max_is_event <- identical(as.integer(res$data$D[imax]), 1L)

  aic_tab <- res$screening$aic_table
  best    <- res$screening$best_model
  best_aic <- if (all(is.na(aic_tab$AIC))) NA_real_ else min(aic_tab$AIC, na.rm = TRUE)

  tt  <- res$tests
  mz  <- tt$mz$statistic
  qn  <- tt$qn$statistic
  sh  <- tt$shen$statistic
  pih <- tt$receus$pi_hat
  rh  <- tt$receus$r_hat
  dec <- tt$receus$decision

  message(sprintf(
    "%-20s %5d %6d %6.1f %-18s %9.2f %8s %8s %8s %8s %8s  %s",
    ck$file, n, events, censpct, best, best_aic,
    fmt(mz), fmt(qn), fmt(sh), fmt(pih), fmt(rh), dec))

  # -- assertions ------------------------------------------------------------
  if (!identical(n, ck$n)) {
    failures <- c(failures, sprintf("%s: expected n = %d, got %d", ck$file, ck$n, n))
  }
  if (events < 1L) {
    failures <- c(failures, sprintf("%s: no events", ck$file))
  }
  if (!identical(dec, ck$expect)) {
    failures <- c(failures, sprintf("%s: expected decision '%s', got '%s'",
                                    ck$file, ck$expect, dec))
  }
  if (!identical(max_is_event, ck$expect_na)) {
    failures <- c(failures, sprintf(
      "%s: expected largest observed time to %sbe an event, but it %s",
      ck$file, if (ck$expect_na) "" else "NOT ",
      if (max_is_event) "is" else "is not"))
  }
  # The three follow-up diagnostics must be NA together, and exactly when the
  # largest observed time is an event.
  na_together <- c(is.na(mz), is.na(qn), is.na(sh))
  if (length(unique(na_together)) != 1L) {
    failures <- c(failures, sprintf(
      "%s: MZ, qn and Shen did not return NA together", ck$file))
  }
  if (!identical(unique(na_together), max_is_event)) {
    failures <- c(failures, sprintf(
      "%s: the three follow-up diagnostics are %savailable but the largest observed time %s an event",
      ck$file, if (unique(na_together)) "un" else "",
      if (max_is_event) "is" else "is not"))
  }
}

message(strrep("-", 150))

n_na <- sum(vapply(CHECKS, function(ck) isTRUE(ck$expect_na), logical(1)))
if (n_na < 2L) {
  failures <- c(failures, sprintf(
    "only %d scenario(s) end on an event; at least 2 are required", n_na))
}

# -- coverage of the three verdicts ------------------------------------------
#
# Each row's own decision is asserted above; this block asserts the SHAPE of
# the library, so that a future edit cannot quietly leave one verdict with a
# single example or drop a family. The counts are the ones the design was
# signed off with: 8 appropriate, 6 insufficient, 5 not supported, 3 ending on
# an event.
COVERAGE <- c("Cure model appropriate"                   = 8L,
              "Follow-up insufficient for cure modeling" = 6L,
              "Cure model not supported"                 = 5L)

expected_decisions <- vapply(CHECKS, function(ck) ck$expect, character(1))
for (verdict in names(COVERAGE)) {
  got <- sum(expected_decisions == verdict)
  if (!identical(got, COVERAGE[[verdict]])) {
    failures <- c(failures, sprintf(
      "coverage: expected %d scenario(s) with '%s', found %d",
      COVERAGE[[verdict]], verdict, got))
  }
}
if (!identical(n_na, 3L)) {
  failures <- c(failures, sprintf(
    "coverage: expected 3 scenario(s) ending on an event, found %d", n_na))
}
if (!identical(sum(COVERAGE), length(CHECKS))) {
  failures <- c(failures, sprintf(
    "coverage: the three verdict counts total %d but there are %d scenarios",
    sum(COVERAGE), length(CHECKS)))
}

message("")
if (length(failures)) {
  stop("make_examples.R verification FAILED:\n  ",
       paste(failures, collapse = "\n  "), call. = FALSE)
}
message(sprintf("All %d example datasets written and verified.", length(CHECKS)))
