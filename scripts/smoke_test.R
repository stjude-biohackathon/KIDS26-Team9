# ─────────────────────────────────────────────────────────────────────────────
# KIDS26 Team 9 — environment smoke test
#
# Run this FIRST, before you write any app code (task T-03).
# It answers one question: "is my machine ready to work on this project?"
#
#   Rscript scripts/smoke_test.R
#
# or, from inside RStudio with the repo as your working directory:
#
#   source("scripts/smoke_test.R")
#
# A PASS means your environment is good and you can start your first task.
# A FAIL tells you exactly what to install or fix.
# ─────────────────────────────────────────────────────────────────────────────

cat("\n==========================================================\n")
cat("  KIDS26 Team 9 - cureAssessApp environment smoke test\n")
cat("==========================================================\n\n")

failures <- character(0)
note <- function(ok, label, detail = "") {
  cat(sprintf("  [%s] %-34s %s\n", if (ok) "OK  " else "FAIL", label, detail))
  if (!ok) failures <<- c(failures, label)
}

# ── 1. R version ─────────────────────────────────────────────────────────────
cat("1. R version\n")
r_ok <- getRversion() >= "4.1.0"
note(r_ok, "R >= 4.1.0", R.version.string)

# ── 2. Packages ──────────────────────────────────────────────────────────────
cat("\n2. Required packages\n")
pkg_required <- c(
  # cureAssess dependencies
  "survival", "flexsurv", "flexsurvcure", "survminer", "ggplot2", "dplyr",
  # Shiny app dependencies
  "shiny", "bslib", "DT", "rmarkdown", "knitr"
)
pkg_optional <- c("shinycssloaders", "devtools")

installed <- rownames(installed.packages())
for (p in pkg_required) {
  has <- p %in% installed
  note(has, p, if (has) as.character(packageVersion(p)) else "not installed")
}
for (p in pkg_optional) {
  has <- p %in% installed
  cat(sprintf("  [%s] %-34s %s\n",
              if (has) "OK  " else "skip", paste0(p, " (optional)"),
              if (has) as.character(packageVersion(p)) else "not installed"))
}

if (length(failures)) {
  cat("\n  To install what is missing, run:\n\n")
  cat('    install.packages(c(',
      paste(sprintf('"%s"', setdiff(pkg_required, installed)), collapse = ", "),
      '))\n\n', sep = "")
}

# ── 3. cureAssess ────────────────────────────────────────────────────────────
cat("\n3. The cureAssess package\n")
pkg_loaded <- FALSE
if ("cureAssess" %in% installed) {
  suppressPackageStartupMessages(library(cureAssess))
  pkg_loaded <- TRUE
  note(TRUE, "cureAssess (installed)", as.character(packageVersion("cureAssess")))
} else if (dir.exists("cureAssess") && "devtools" %in% installed) {
  ok <- tryCatch({
    suppressMessages(devtools::load_all("cureAssess", quiet = TRUE)); TRUE
  }, error = function(e) {cat("       ", conditionMessage(e), "\n"); FALSE})
  pkg_loaded <- ok
  note(ok, "cureAssess (loaded from source)", "via devtools::load_all('cureAssess')")
} else {
  note(FALSE, "cureAssess", "not installed and could not load from source")
  cat("\n  Install it from the copy vendored in this repo:\n\n")
  cat('    install.packages("cureAssess/cureAssess_0.1.0.tar.gz",\n')
  cat('                     repos = NULL, type = "source")\n\n')
}

# ── 4. End-to-end analysis ───────────────────────────────────────────────────
# The real test: does a full cure.appropriateness() run produce the numbers we
# expect? Expected values are the reference oracle in project-management/qa-plan.md.
if (pkg_loaded && "survival" %in% installed) {
  cat("\n4. End-to-end run on the nwtco High risk cohort\n")
  suppressPackageStartupMessages(library(survival))

  dat <- subset(survival::nwtco, stage %in% c(3, 4))

  t0 <- Sys.time()
  res <- tryCatch(
    cure.appropriateness(
      data = dat, time = "edrel", status = "rel",
      time_scale = "days_to_years", plot_km = FALSE, run_tests = "yes"
    ),
    error = function(e) {cat("       ", conditionMessage(e), "\n"); NULL}
  )
  elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

  if (is.null(res)) {
    note(FALSE, "cure.appropriateness() runs", "errored - see message above")
  } else {
    note(TRUE, "cure.appropriateness() runs", sprintf("%.2f seconds", elapsed))

    close_enough <- function(x, target, tol = 1e-3) {
      is.numeric(x) && length(x) == 1 && !is.na(x) && abs(x - target) < tol
    }

    note(nrow(dat) == 1404, "n = 1404", sprintf("n = %d", nrow(dat)))
    note(identical(res$screening$best_model, "loglogistic_cure"),
         "best model = loglogistic_cure", res$screening$best_model)
    note(close_enough(res$tests$receus$pi_hat, 0.7823),
         "pi_hat = 0.7823", sprintf("%.4f", res$tests$receus$pi_hat))
    note(close_enough(res$tests$receus$r_hat, 0.0041),
         "r_hat = 0.0041", sprintf("%.4f", res$tests$receus$r_hat))
    note(identical(res$tests$receus$decision, "Cure model appropriate"),
         'verdict = "Cure model appropriate"', res$tests$receus$decision)

    cat("\n  Full verdict:\n    ", res$final_recommendation, "\n", sep = "")
  }
}

# ── Result ───────────────────────────────────────────────────────────────────
cat("\n==========================================================\n")
if (length(failures) == 0) {
  cat("  PASS - your environment is ready. Start your first task.\n")
  cat("  Next: shiny::runApp(\"app-scaffold\") to check Shiny works.\n")
} else {
  cat(sprintf("  FAIL - %d check(s) did not pass:\n", length(failures)))
  for (f in failures) cat("    -", f, "\n")
  cat("\n  Fix these, re-run, and ask Geethanjalee or Sharon if you are stuck.\n")
  cat("  If it is an access or install problem you cannot solve, tell Durbadal\n")
  cat("  before 11:15 am Wednesday so it can be escalated to the organisers.\n")
}
cat("==========================================================\n\n")

invisible(length(failures) == 0)
