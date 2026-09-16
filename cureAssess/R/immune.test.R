#' Compute immune-related summary quantities
#'
#' Computes Kaplan-Meier-based summary quantities used to assess whether
#' right-censored survival data may contain a subgroup of long-term survivors
#' (sometimes referred to as "immune" or "cured" individuals).
#'
#' The method evaluates the behavior of the Kaplan-Meier survival curve at the
#' end of follow-up. In particular, it considers:
#'
#' - the estimated event probability by the end of follow-up,
#' - the proportion of censored observations, and
#' - whether the largest observed follow-up time corresponds to a censored
#'   observation.
#'
#' If the largest observed time is censored and the Kaplan-Meier curve appears
#' to level off above zero, this is consistent with the presence of a survival
#' plateau and may suggest a cure fraction. In contrast, if the largest
#' observed time is an event, the evidence for a survival plateau is weaker.
#'
#' This function provides a descriptive summary rather than a formal hypothesis
#' test and is intended to be interpreted together with other diagnostics such
#' as the Maller-Zhou test, qn statistic, Shen test, and RECeUS method.
#'
#' @param dat A data frame containing columns `Y` and `D`, where `Y`
#'   is the observed survival time and `D` is the event indicator
#'   (`1` = event, `0` = censoring).
#'
#' @return An object of class `"immune.test.result"` containing:
#' \describe{
#'   \item{method}{Name of the diagnostic summary.}
#'   \item{p_hat}{Estimated event probability by the end of follow-up,
#'   derived from the Kaplan-Meier curve.}
#'   \item{p_cens}{Observed proportion of censored observations.}
#'   \item{last_observation}{Largest observed follow-up time.}
#'   \item{last_observation_censored}{Logical indicator of whether the
#'   largest observed follow-up time is censored.}
#'   \item{interpretation}{Text describing the implication of the summary
#'   quantities for the presence of a survival plateau and possible cure
#'   fraction.}
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
#' Maller RA, Zhou S (1995).
#' *Testing for the presence of immune or cured individuals.*
#' Biometrics, 51, 1197--1205.
#' \doi{10.2307/2533253}
#'
#' Maller RA, Zhou X (1996).
#' *Survival Analysis with Long-term Survivors.*
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
#' res <- immune.test(dat)
#' res
#'
#' @export
immune.test <- function(dat) {
  .check_surv_data(dat)

  kmfit <- survival::survfit(survival::Surv(dat$Y, dat$D) ~ 1)

  lastObs <- max(dat$Y)
  isCens <- dat$D[which.max(dat$Y)] == 0
  pHat <- 1 - summary(kmfit, times = lastObs, extend = TRUE)$surv
  pCens <- 1 - mean(dat$D)

  interpretation <- if (isTRUE(isCens)) {
    paste0(
      "The last observed time is censored, suggesting a possible survival plateau. ",
      "The estimated event probability by the end of follow-up is ",
      round(pHat, 4), ", and the censoring proportion is ",
      round(pCens, 4), "."
    )
  } else {
    paste0(
      "The last observed time is an event, doesn't suggest a clear survival plateau. ",
      "The estimated event probability by the end of follow-up is ",
      round(pHat, 4), ", and the censoring proportion is ",
      round(pCens, 4), "."
    )
  }

  out <- list(
    method = "Maller-Zhou immune summary (1996)",
    p_hat = unname(pHat),
    p_cens = unname(pCens),
    last_observation = unname(lastObs),
    last_observation_censored = unname(isCens),
    interpretation = interpretation
  )

  class(out) <- "immune.test.result"
  out
}
