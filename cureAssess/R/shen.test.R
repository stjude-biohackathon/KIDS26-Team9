#' Compute Shen's test statistic
#'
#' Computes the Shen (2000) diagnostic test statistic used to assess whether
#' follow-up in right-censored survival data is sufficient to detect a
#' potential cure fraction.
#'
#' The test examines the pattern of events near the end of follow-up. If a
#' cure fraction exists, the Kaplan-Meier survival curve will tend to flatten
#' (plateau) because a subset of individuals will never experience the event
#' of interest. In contrast, if no cure fraction exists, events should
#' continue to occur late in follow-up and the survival curve will continue
#' to decline.
#'
#' Shen's test evaluates whether the number of events occurring in a late
#' follow-up interval is consistent with the presence of such a plateau.
#' Smaller values of the test statistic provide stronger evidence supporting
#' the presence of a cure fraction.
#'
#' The test can only be computed when the largest observed follow-up time
#' corresponds to a censored observation (i.e., follow-up extends beyond the
#' last observed event time).
#'
#' @param dat A data frame containing columns `Y` and `D`, where `Y`
#'   is the observed survival time and `D` is the event indicator
#'   (`1` = event, `0` = censoring).
#' @param alpha Significance level used for interpretation. Default is `0.05`.
#'
#' @return An object of class `"cure.test.result"` containing:
#' \describe{
#'   \item{method}{Name of the diagnostic test.}
#'   \item{statistic}{Computed Shen test statistic.}
#'   \item{alpha}{Significance level used for interpretation.}
#'   \item{interpretation}{Text describing the implication of the statistic
#'   for the presence of a survival plateau and possible cure fraction.}
#' }
#'
#' @references
#' Shen P-S (2000).
#' *Testing for sufficient follow-up in survival data.*
#' Statistics & Probability Letters, 49(4), 313--322.
#' \doi{10.1016/S0167-7152(00)00063-8}
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
#' res <- shen.test(dat)
#' res
#'
#' @export
shen.test <- function(dat, alpha = 0.05) {
  .check_surv_data(dat)

  maxE <- max(dat$Y[dat$D == 1])
  maxAll <- max(dat$Y)

  if (maxAll > maxE) {
    w <- (maxAll - maxE) / maxAll
    tauG <- w * maxE + (1 - w) * maxAll
    numBefore <- sum(dat$D == 1 &
                       (dat$Y >= tauG * maxE / maxAll & dat$Y <= maxE))
    stat <- (1 - numBefore / nrow(dat))^nrow(dat)

    interpretation <- if (stat < alpha) {
      paste0(
        "Since the Shen test statistic (", round(stat, 4),
        ") is less than alpha = ", alpha,
        ", there is evidence of sufficient follow-up, supporting cure model appropriateness."
      )
    } else {
      paste0(
        "Since the Shen test statistic (", round(stat, 4),
        ") is greater than or equal to alpha = ", alpha,
        ", there is insufficient evidence of adequate follow-up to support cure model appropriateness."
      )
    }
  } else {
    stat <- NA_real_
    interpretation <- paste(
      "The Shen test cannot be computed because the largest observed time",
      "corresponds to an event rather than a censored observation."
    )
  }

  out <- list(
    method = "Shen test (2000)",
    statistic = stat,
    alpha = alpha,
    interpretation = interpretation
  )

  class(out) <- "cure.test.result"
  out
}
