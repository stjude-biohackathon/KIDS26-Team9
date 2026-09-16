#' Plot a fitted cure model object
#'
#' Displays the Kaplan-Meier plot stored in a `cure.model.fit` object.
#'
#' @param x An object of class `"cure.model.fit"`.
#' @param ... Additional arguments passed to other methods.
#'
#' @return The input object `x`, returned invisibly.
#'
#' @examples
#' library(survival)
#'
#' dat <- prepare.surv.data(gbsg, "rfstime", "status", "days_to_years")
#' fit_res <- model.fitting(dat, plot_km = TRUE)
#'
#' plot(fit_res)
#'
#' @export
plot.cure.model.fit <- function(x, ...) {

  if (is.null(x$kmplot)) {
    stop("No Kaplan-Meier plot available. Re-run with `plot_km = TRUE`.", call. = FALSE)
  }

  print(x$kmplot)
  invisible(x)
}
