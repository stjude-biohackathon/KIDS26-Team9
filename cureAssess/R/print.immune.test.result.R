#' Print immune test results
#'
#' Prints the results of the immune-based cure model diagnostic test,
#' including estimated proportions and censoring information.
#'
#' @param x An object of class `"immune.test.result"`.
#' @param ... Additional arguments passed to other methods.
#'
#' @return The input object `x`, returned invisibly.
#' @export
print.immune.test.result <- function(x, ...) {

  cat("\n", x$method, "\n", sep = "")
  cat(strrep("-", nchar(x$method)), "\n", sep = "")

  cat("p_hat:", x$p_hat, "\n")
  cat("p_cens:", x$p_cens, "\n")
  cat("Last observation:", x$last_observation, "\n")
  cat("Last observation censored:", x$last_observation_censored, "\n")

  if (!is.null(x$interpretation)) {
    cat("Interpretation:", x$interpretation, "\n")
  }

  invisible(x)
}
