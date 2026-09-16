#' Summarize cure model appropriateness results
#'
#' Returns a summary of a `cure.appropriateness` object, including
#' the best model identified during screening, the AIC comparison
#' table, tests performed, and the final recommendation.
#'
#' @param object An object of class `"cure.appropriateness"`.
#' @param ... Additional arguments passed to other methods.
#'
#' @return An object of class `"summary.cure.appropriateness"`
#' containing key results from the cure model appropriateness analysis.
#'
#' @examples
#' library(survival)
#'
#' res <- cure.appropriateness(
#'   data = gbsg,
#'   time = "rfstime",
#'   status = "status",
#'   time_scale = "days_to_years",
#'   plot_km = FALSE,
#'   run_tests = "no"
#' )
#'
#' summary(res)
#'
#' @export
summary.cure.appropriateness <- function(object, ...) {

  out <- list(
    best_model = object$screening$best_model,
    best_model_type = object$screening$best_model_type,
    aic_table = object$screening$aic_table,
    tests_run = object$tests_run,
    tests_reason = object$tests_reason,
    final_recommendation = object$final_recommendation
  )

  class(out) <- "summary.cure.appropriateness"
  out
}
