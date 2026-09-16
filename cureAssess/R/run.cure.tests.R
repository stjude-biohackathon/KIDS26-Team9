#' Run cure model appropriateness diagnostics
#'
#' Runs a set of diagnostic procedures used to assess whether a cure model
#' may be appropriate for right-censored survival data. The diagnostics
#' include the Maller-Zhou test, qn statistic, Shen test, immune summary,
#' and RECeUS method.
#'
#' @param data A data frame containing columns `Y` and `D`, where `Y`
#'   is the observed survival time and `D` is the event indicator
#'   (`1` = event, `0` = censoring).
#' @param dist Character string giving the distribution to be used for the
#'   RECeUS method. If `NULL`, the distribution must be supplied elsewhere
#'   or selected before calling this function.
#'
#' @return An object of class `"cure.tests"` containing:
#' \describe{
#'   \item{mz}{Result of the Maller-Zhou diagnostic test.}
#'   \item{qn}{Result of the qn statistic.}
#'   \item{shen}{Result of Shen's test.}
#'   \item{immune}{Result of the immune summary diagnostic.}
#'   \item{receus}{Result of the RECeUS method.}
#' }
#'
#' @examples
#' library(survival)
#'
#' dat <- prepare.surv.data(
#'   data = gbsg,
#'   time = "rfstime",
#'   status = "status",
#'   time_scale = "days_to_years"
#' )
#'
#' res <- run.cure.tests(dat, dist = "lnorm")
#' res$mz
#' res$receus
#'
#' @export
run.cure.tests <- function(data, dist = NULL) {
  .check_surv_data(data)

  if (is.null(dist)) {
    stop(
      "`dist` must be provided in `run.cure.tests()`, or selected before ",
      "calling this function.",
      call. = FALSE
    )
  }

  out <- list(
    mz = mz.test(data),
    qn = qn.test(data),
    shen = shen.test(data),
    immune = immune.test(data),
    receus = receus.method(data, dist = dist)
  )

  class(out) <- "cure.tests"
  out
}
