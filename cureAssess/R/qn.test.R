#' Compute the qn statistic
#'
#' Computes the **qn statistic** proposed by Maller and Zhou (1996), which is a
#' descriptive diagnostic used to assess whether follow-up is sufficient to
#' detect a survival plateau in right-censored survival data. A survival plateau
#' may indicate the presence of a *cure fraction*, meaning that a subset of
#' individuals will never experience the event of interest.
#'
#' The statistic is `qn = Nn / n`, where `Nn` is the number of events falling in
#' the late-time window `(2*Y* - Y_max, Y*]`, `Y*` is the largest event time, and
#' `Y_max` is the largest observed time. The width of this window equals the gap
#' `Y_max - Y*` between the last event and the end of follow-up. A long plateau
#' (sufficient follow-up) produces a wide window that captures many events, so
#' **larger** values of `qn` indicate stronger evidence of sufficient follow-up
#' and a survival plateau. **Smaller** values indicate that events continue up to
#' the end of follow-up, providing weaker evidence for a plateau.
#'
#' For a formal decision, this implementation uses the companion Maller-Zhou
#' statistic `alpha_n = (1 - qn)^n` (Maller & Zhou 1994, their eq. 5):
#' sufficient follow-up is supported when `alpha_n < 0.05`, equivalently when
#' `qn` exceeds `1 - 0.05^(1/n)` (a threshold that depends on the sample size
#' `n`). Note this `alpha_n`-equivalent rule is the same decision used by
#' [mz.test()]; the exact finite-sample critical values for `qn` derived by
#' Maller, Resnick and Shemehsavar (2024) are not implemented here. The `qn`
#' statistic itself is reported and is directionally informative regardless of
#' the cutoff used.
#'
#' The statistic can only be computed when the largest observed follow-up time
#' is a censored observation (i.e., follow-up extends beyond the last event).
#'
#' @param dat A data frame containing columns `Y` and `D`, where `Y` is the
#'   observed survival time and `D` is the event indicator (`1` = event,
#'   `0` = censoring).
#'
#' @return An object of class `"cure.test.result"` containing:
#' \describe{
#'   \item{method}{Name of the statistic.}
#'   \item{statistic}{Computed qn statistic.}
#'   \item{interpretation}{Text describing the implication of the statistic for
#'   the presence of a survival plateau and possible cure fraction.}
#' }
#'
#' @references
#' Maller RA, Resnick S, Shemehsavar S (2024).
#' *Finite sample and asymptotic distributions of a statistic for sufficient
#' follow-up in cure models.*
#' Canadian Journal of Statistics, 52(2), 359--379.
#' \doi{10.1002/cjs.11771}
#'
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
#' res <- qn.test(dat)
#' res
#'
#' @export
qn.test <- function(dat) {

  .check_surv_data(dat)

  maxE <- max(dat$Y[dat$D == 1])
  maxAll <- max(dat$Y)

  if (maxAll > maxE) {

    numPlat <- sum(dat$D == 1 & dat$Y > (2 * maxE - maxAll) & dat$Y <= maxE)

    n <- nrow(dat)
    stat <- numPlat / n
    qn_threshold <- 1 - 0.05^(1 / n)

    interpretation <- if (stat > qn_threshold) {
      paste0(
        "The qn statistic is ", round(stat, 4),
        " (alpha_n-equivalent threshold for sufficient follow-up at the 0.05 ",
        "level is ", round(qn_threshold, 4),
        "). Because qn exceeds this threshold, there is evidence of sufficient ",
        "follow-up, consistent with a survival plateau and supporting cure model ",
        "appropriateness. Larger values of qn provide stronger evidence."
      )
    } else {
      paste0(
        "The qn statistic is ", round(stat, 4),
        " (alpha_n-equivalent threshold for sufficient follow-up at the 0.05 ",
        "level is ", round(qn_threshold, 4),
        "). Because qn does not exceed this threshold, there is insufficient ",
        "evidence of adequate follow-up to support a survival plateau and a cure ",
        "fraction."
      )
    }

  } else {

    stat <- NA_real_

    interpretation <- paste(
      "The qn statistic cannot be computed because the largest observed time",
      "corresponds to an event rather than a censored observation."
    )

  }

  out <- list(
    method = "qn statistic (Maller & Zhou 1996)",
    statistic = stat,
    interpretation = interpretation
  )

  class(out) <- "cure.test.result"

  out
}
