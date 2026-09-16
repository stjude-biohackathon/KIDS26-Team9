#' Print cure model appropriateness analysis results
#'
#' Prints a summary of a `cure.appropriateness` object, including the
#' screening results, RECeUS model selection, testing status, and
#' final recommendation.
#'
#' @param x An object of class `"cure.appropriateness"`.
#' @param ... Additional arguments passed to other methods.
#'
#' @return The input object `x`, returned invisibly.
#' @export
print.cure.appropriateness <- function(x, ...) {

  cat("\nCure model appropriateness analysis\n")
  cat("-----------------------------------\n")

  cat("Best model by AIC:", x$screening$best_model, "\n")
  cat("Best model type:", x$screening$best_model_type, "\n\n")

  cat("Initial decision:\n")
  cat(x$screening$initial_decision, "\n\n")

  if (!is.null(x$selected_receus_dist) && !is.na(x$selected_receus_dist)) {
    cat("RECeUS distribution used:", x$selected_receus_dist, "\n")
  }

  if (!is.null(x$selected_receus_model) && !is.na(x$selected_receus_model)) {
    cat("Based on cure model:", x$selected_receus_model, "\n\n")
  }

  cat("Testing status:\n")
  cat(x$tests_reason, "\n\n")

  cat("Final recommendation:\n")
  cat(x$final_recommendation, "\n")

  invisible(x)
}
