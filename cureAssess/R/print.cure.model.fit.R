#' Print a fitted cure model object
#'
#' Prints a summary of a `cure.model.fit` object, including the best
#' model identified by AIC and the full AIC comparison table.
#'
#' @param x An object of class `"cure.model.fit"`.
#' @param ... Additional arguments passed to other methods.
#'
#' @return The input object `x`, returned invisibly.
#'
#' @export
print.cure.model.fit <- function(x, ...) {
  cat("\nCandidate model fitting results\n")
  cat("--------------------------------\n")
  cat("Best model by AIC:", x$best_model, "\n\n")

  print(x$aic_table, row.names = FALSE)

  invisible(x)
}
