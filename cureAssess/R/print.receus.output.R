#' Print RECeUS cure model assessment results
#'
#' Prints the results from a RECeUS-based cure model assessment,
#' including the estimated cure fraction, remaining uncured ratio,
#' and the decision regarding cure model appropriateness.
#'
#' @param x An object of class `"receus.output"`.
#' @param ... Additional arguments passed to other methods.
#'
#' @return The input object `x`, returned invisibly.
#' @export
print.receus.output <- function(x, ...) {

  cat("\nRECeUS Cure Model Assessment\n")
  cat("----------------------------\n")

  cat("Distribution:", x$dist, "\n")
  cat("Tau:", round(x$tau, 4), "\n\n")

  cat("Estimated cure fraction (pi_hat):", round(x$pi_hat, 4), "\n")
  cat("Remaining uncured ratio (r_hat):", round(x$r_hat, 4), "\n\n")

  cat("Decision:", x$decision, "\n\n")

  cat("Interpretation:\n")
  cat(x$interpretation, "\n")

  invisible(x)
}
