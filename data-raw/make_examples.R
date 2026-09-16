# data-raw/make_examples.R ---------------------------------------------------
#
# Regenerates every CSV in data/examples/ from a fixed seed.
#
# Run from the repository root:
#
#     Rscript data-raw/make_examples.R
#
# Writes seven comma-delimited CSVs (header row, no row names) into
# data/examples/:
#
#   nwtco_high_risk.csv  survival::nwtco, stage %in% c(3, 4)
#   gbsg.csv             survival::gbsg, all rows
#   colon_lev5fu.csv     survival::colon, etype == 1 & rx == "Lev+5FU"
#   sim_a.csv .. sim_d.csv   simulated scenarios A-D, seed 11
#
# Nothing in this file is statistical. The three real datasets are subset and
# exported with their ORIGINAL column names, so the app's column mapper has a
# real mapping problem to solve; the four simulated datasets are drawn once
# from a fixed seed using the reference implementation in
# docs/data-contract.md section 8. No cureAssess function is called here.
#
# The registry that tells the app how to map each of these files is
# CA_DATASETS in app/R/datasets.R. If you add or rename a file here, change
# that registry too.

# ---- fixed simulation constants (docs/data-contract.md section 8) ----------

SIM_SEED  <- 11L
SIM_N     <- 300L
SIM_SHAPE <- 1.2
SIM_SCALE <- 1


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


#' Simulate a survival dataset with a known cure fraction
#'
#' Verbatim reference implementation from docs/data-contract.md section 8.
#' A cured subject gets a latent event time of `Inf`, so they can only ever be
#' censored; censoring is the earlier of random dropout and the administrative
#' end of follow-up. `set.seed()` is called inside the function, so each
#' scenario is reproducible independently of the order they are generated in.
#' The returned frame is already in the package's `Y` / `D` naming scheme.
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


#' Describe one written file for the console log
#'
#' Reports the analysis-relevant shape of a file: rows, events, the largest
#' observed time, and whether that largest time is an event. The last of these
#' is the condition that makes the Maller-Zhou, qn and Shen statistics
#' undefined, so it is printed for every dataset, not just the simulated ones.
describe_example <- function(name, d, time_col, status_col, event_value) {
  tv <- as.numeric(d[[time_col]])
  ev <- as.integer(as.character(d[[status_col]]) == as.character(event_value))
  imax <- which.max(tv)
  list(
    name        = name,
    n           = nrow(d),
    events      = sum(ev == 1L, na.rm = TRUE),
    max_time    = tv[imax],
    max_is_event = identical(ev[imax], 1L)
  )
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


# ---- 2. simulated scenarios A-D -------------------------------------------
#
# The four corners the app has to handle. A and B exercise the two ordinary
# verdicts; C and D exercise the not-computable path, where the largest
# observed time is an event and Maller-Zhou, qn and Shen are all NA.
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
# rather than one who ran out of follow-up. The assertion below re-checks it on
# every regeneration instead of trusting that argument.

sim_specs <- list(
  sim_a = list(cure_fraction = 0.40, admin_followup = 10,  dropout_rate = 0.03),
  sim_b = list(cure_fraction = 0.40, admin_followup = 1.5, dropout_rate = 0.03),
  sim_c = list(cure_fraction = 0.00, admin_followup = 10,  dropout_rate = 0.03),
  sim_d = list(cure_fraction = 0.00, admin_followup = 10,  dropout_rate = 0.45)
)

sim_data <- lapply(sim_specs, function(spec) {
  d <- do.call(
    simulate_cure_data,
    c(list(n = SIM_N, shape = SIM_SHAPE, scale = SIM_SCALE, seed = SIM_SEED), spec)
  )
  # `.cured` is ground truth for verification only and must never reach the
  # app, where it could be picked as a status column.
  d[, c("Y", "D"), drop = FALSE]
})

for (key in names(sim_data)) {
  write_example(sim_data[[key]], paste0(key, ".csv"), out_dir)
}


# ---- 3. verification -------------------------------------------------------
#
# Re-reads every file from disk and checks the three facts the rest of the
# build depends on: the analysed row counts, and that scenarios C and D really
# do end on an event (and A and B really do not).

checks <- list(
  list(file = "nwtco_high_risk.csv", time = "edrel",   status = "rel",    event = 1, n = 1404L, max_is_event = FALSE),
  list(file = "gbsg.csv",            time = "rfstime", status = "status", event = 1, n = 686L,  max_is_event = FALSE),
  list(file = "colon_lev5fu.csv",    time = "time",    status = "status", event = 1, n = 304L,  max_is_event = FALSE),
  list(file = "sim_a.csv",           time = "Y",       status = "D",      event = 1, n = 300L,  max_is_event = FALSE),
  list(file = "sim_b.csv",           time = "Y",       status = "D",      event = 1, n = 300L,  max_is_event = FALSE),
  list(file = "sim_c.csv",           time = "Y",       status = "D",      event = 1, n = 300L,  max_is_event = TRUE),
  list(file = "sim_d.csv",           time = "Y",       status = "D",      event = 1, n = 300L,  max_is_event = TRUE)
)

message("")
message(sprintf("%-22s %6s %8s %11s %14s", "file", "n", "events", "max time", "max is event"))

failures <- character(0)

for (ck in checks) {
  d <- utils::read.csv(file.path(out_dir, ck$file), stringsAsFactors = FALSE)
  info <- describe_example(ck$file, d, ck$time, ck$status, ck$event)
  message(sprintf("%-22s %6d %8d %11.5f %14s",
                  info$name, info$n, info$events, info$max_time, info$max_is_event))

  if (!identical(info$n, ck$n)) {
    failures <- c(failures, sprintf("%s: expected n = %d, got %d", ck$file, ck$n, info$n))
  }
  if (!identical(info$max_is_event, ck$max_is_event)) {
    failures <- c(failures, sprintf(
      "%s: expected largest observed time to %sbe an event, but it %s",
      ck$file,
      if (ck$max_is_event) "" else "NOT ",
      if (info$max_is_event) "is" else "is not"
    ))
  }
  if (info$events < 1L) {
    failures <- c(failures, sprintf("%s: no events", ck$file))
  }
}

message("")
if (length(failures)) {
  stop("make_examples.R verification FAILED:\n  ",
       paste(failures, collapse = "\n  "), call. = FALSE)
}
message("All seven example datasets written and verified.")
