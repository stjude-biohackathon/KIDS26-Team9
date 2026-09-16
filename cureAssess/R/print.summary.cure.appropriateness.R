#' Print a summary of cure model appropriateness results
#'
#' Prints the condensed summary produced by
#' [summary.cure.appropriateness()], including the best model identified
#' during screening, the AIC comparison table, whether diagnostic tests were
#' run, and the final recommendation.
#'
#' @param x An object of class `"summary.cure.appropriateness"`.
#' @param ... Additional arguments passed to other methods.
#'
#' @return The input object `x`, returned invisibly.
#' @export
print.summary.cure.appropriateness <- function(x, ...) {

  cat("\nSummary: cure model appropriateness\n")
  cat("-----------------------------------\n")

  cat("Best model by AIC:", x$best_model, "\n")
  cat("Best model type:", x$best_model_type, "\n\n")

  cat("AIC comparison table:\n")
  print(x$aic_table, row.names = FALSE)
  cat("\n")

  cat("Tests run:", x$tests_run, "\n")
  cat("Testing status:\n")
  cat(x$tests_reason, "\n\n")

  cat("Final recommendation:\n")
  cat(x$final_recommendation, "\n")

  invisible(x)
}
