#' Compute the Maller-Zhou test statistic
#'
#' Computes the Maller-Zhou test statistic used to assess whether a cure
#' fraction may exist in right-censored survival data. The test is based on
#' examining the behavior of events near the end of follow-up.
#'
#' The key idea is that if a cure fraction exists, the Kaplan-Meier survival
#' curve will eventually reach a plateau above zero because a subset of
#' individuals will never experience the event. In contrast, if no cure
#' fraction exists, events should continue to occur toward the end of follow-up.
#'
#' The Maller-Zhou statistic evaluates the number of events occurring in a
#' time window near the largest observed event time. If relatively few events
#' occur in this region, it provides evidence consistent with the presence
#' of a cure fraction.
#'
#' The test can only be computed when the largest observed time corresponds
#' to a censored observation (i.e., follow-up extends beyond the last event).
#'
#' @param dat A data frame containing columns `Y` and `D`, where `Y`
#'   is the observed survival time and `D` is the event indicator
#'   (`1` = event, `0` = censoring).
#' @param alpha Significance level used for interpretation. Default is `0.05`.
#'
#' @return An object of class `"cure.test.result"` containing:
#' \describe{
#'   \item{method}{Name of the test.}
#'   \item{statistic}{Computed Maller-Zhou statistic.}
#'   \item{alpha}{Significance level used for interpretation.}
#'   \item{interpretation}{Text describing the implication of the test result
#'   for the presence of a cure fraction.}
#' }
#'
#' @references
#' Maller RA, Zhou S (1992).
#' *Estimating the proportion of immunes in a censored sample.*
#' Biometrika, 79(4), 731--739.
#' \doi{10.1093/biomet/79.4.731}
#'
#' Maller RA, Zhou S (1994).
#' *Testing for sufficient follow-up and outliers in survival data.*
#' Journal of the American Statistical Association, 89(428), 1499--1506.
#' \doi{10.1080/01621459.1994.10476889}
#'
#' Maller RA, Zhou X (1996).
#' *Survival Analysis with Long-Term Survivors.*
#' Wiley.
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
#' res <- mz.test(dat)
#' res
#'
#' @export
mz.test <- function(dat, alpha = 0.05) {
  .check_surv_data(dat)

  maxE <- max(dat$Y[dat$D == 1])
  maxAll <- max(dat$Y)

  if (maxAll > maxE) {
    plat <- maxAll - maxE
    numBefore <- sum(dat$D == 1 & dat$Y > (maxE - plat))
    stat <- (1 - numBefore / nrow(dat))^nrow(dat)

    interpretation <- if (stat < alpha) {
      paste0(
        "Since the Maller-Zhou statistic (", round(stat, 4),
        ") is less than alpha = ", alpha,
        ", there is evidence of sufficient follow-up, supporting cure model appropriateness."
      )
    } else {
      paste0(
        "Since the Maller-Zhou statistic (", round(stat, 4),
        ") is greater than or equal to alpha = ", alpha,
        ", there is insufficient evidence of adequate follow-up to support cure model appropriateness."
      )
    }
  } else {
    stat <- NA_real_
    interpretation <- paste(
      "The test cannot be computed because the largest observed time",
      "corresponds to an event rather than a censored observation."
    )
  }

  out <- list(
    method = "Maller-Zhou test statistic (1994)",
    statistic = stat,
    alpha = alpha,
    interpretation = interpretation
  )

  class(out) <- "cure.test.result"
  out
}
