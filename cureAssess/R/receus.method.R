#' Compute RECeUS cure model diagnostic outputs
#'
#' Computes cure-fraction-related summary quantities using a selected
#' parametric survival model and evaluates cure model appropriateness
#' using the RECeUS method proposed by Selukar and Othus (2023).
#'
#' The RECeUS method is based on two quantities:
#'
#' - `pi_hat`: the estimated cure fraction
#' - `r_hat`: the estimated proportion of uncured subjects remaining
#'   censored at the end of follow-up
#'
#' This diagnostic is typically applied after model screening when a
#' cure model is selected as the preferred model based on information
#' criteria such as AIC (e.g., `"exp"`, `"wei"`,
#' `"llogis"`, `"gam"`, `"lnorm"`). However, the method can also be
#' applied using non-cure parametric models.
#'
#' When a non-cure model is used (e.g., `"expUnc"`, `"weiUnc"`,
#' `"llogisUnc"`, `"gamUnc"`, `"lnormUnc"`), the cure fraction is
#' constrained to zero by the model specification. In this case the
#' method will always return:
#'
#' - `pi_hat = 0`
#' - `r_hat = 1`
#'
#' A cure model is considered appropriate when both of the following
#' conditions are satisfied:
#'
#' - `pi_hat > 0.025`
#' - `r_hat < 0.05`
#'
#' The first condition indicates that the estimated cure fraction is
#' meaningfully greater than zero, while the second condition indicates
#' that only a small proportion of uncured subjects remain censored at the
#' end of follow-up. Together, these conditions suggest both the presence
#' of a cure fraction and sufficient follow-up for reliable cure model
#' estimation.
#'
#' This function can be applied using either cure or non-cure parametric
#' model specifications, depending on the value of `dist`.
#'
#' @param data A data frame containing columns `Y` and `D`, where `Y`
#'   is the observed survival time and `D` is the event indicator
#'   (`1` = event, `0` = censoring).
#' @param dist Character string specifying the parametric model used in the
#'   RECeUS calculation. Supported values are:
#'   \describe{
#'     \item{`"exp"`}{Exponential cure model.}
#'     \item{`"expUnc"`}{Exponential non-cure model.}
#'     \item{`"wei"`}{Weibull cure model.}
#'     \item{`"weiUnc"`}{Weibull non-cure model.}
#'     \item{`"llogis"`}{Log-logistic cure model.}
#'     \item{`"llogisUnc"`}{Log-logistic non-cure model.}
#'     \item{`"gam"`}{Gamma cure model.}
#'     \item{`"gamUnc"`}{Gamma non-cure model.}
#'     \item{`"lnorm"`}{Lognormal cure model.}
#'     \item{`"lnormUnc"`}{Lognormal non-cure model.}
#'   }
#' @param whichTau Optional evaluation time. If `NULL`, the largest observed
#'   follow-up time is used.
#'
#' @return An object of class `"receus.output"` containing:
#' \describe{
#'   \item{method}{Name of the diagnostic procedure.}
#'   \item{dist}{Distribution used in the RECeUS calculation.}
#'   \item{tau}{Evaluation time used in the calculation.}
#'   \item{estimates}{Raw vector of estimated model quantities returned by
#'   the internal RECeUS calculation.}
#'   \item{pi_hat}{Estimated cure fraction.}
#'   \item{r_hat}{Estimated proportion of uncured subjects remaining censored
#'   at the end of follow-up.}
#'   \item{cure_fraction_condition}{Logical indicator of whether
#'   `pi_hat > 0.025`.}
#'   \item{followup_condition}{Logical indicator of whether
#'   `r_hat < 0.05`.}
#'   \item{decision}{Text summary of whether the RECeUS criteria support
#'   cure model appropriateness.}
#'   \item{interpretation}{Text describing the implication of the RECeUS
#'   quantities for cure model appropriateness and sufficiency of follow-up.}
#' }
#'
#' @references
#' Selukar S, Othus M (2023).
#' *RECeUS: Ratio estimation of censored uncured subjects.*
#' Statistics in Medicine, 42(3), 209--227.
#' \doi{10.1002/sim.9610}
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
#' res <- receus.method(dat, dist = "lnorm")
#' res
#'
#' @export
receus.method <- function(data, dist = "exp", whichTau = NULL) {

  .check_surv_data(data)

  if (is.null(whichTau)) {
    whichTau <- max(data$Y, na.rm = TRUE)
  }

  res <- ratioTest(data, whichTau = whichTau, dist = dist)

  pi_hat <- unname(res[1])
  r_hat <- unname(res[length(res)])

  cure_fraction_condition <- pi_hat > 0.025
  followup_condition <- r_hat < 0.05

  if (cure_fraction_condition && followup_condition) {

    decision <- "Cure model appropriate"

    interpretation <- paste(
      "Both RECeUS conditions are satisfied:",
      "pi_hat > 0.025 and r_hat < 0.05.",
      "This suggests the presence of a cure fraction",
      "and sufficient follow-up for reliable cure model estimation."
    )

  } else if (!cure_fraction_condition) {

    decision <- "Cure model not supported"

    interpretation <- paste(
      "The estimated cure fraction (pi_hat =", round(pi_hat, 4),
      ") is less than or equal to 0.025.",
      "This suggests that the cure fraction is negligible",
      "and a cure model may not be appropriate."
    )

  } else {

    decision <- "Follow-up insufficient for cure modeling"

    interpretation <- paste(
      "The remaining uncured ratio (r_hat =", round(r_hat, 4),
      ") is greater than or equal to 0.05.",
      "This suggests that a large proportion of uncured subjects",
      "remain censored at the end of follow-up,",
      "indicating insufficient follow-up to reliably estimate a cure fraction."
    )

  }

  out <- list(
    method = "RECeUS method (Selukar & Othus, 2023)",
    dist = dist,
    tau = whichTau,
    estimates = res,
    pi_hat = pi_hat,
    r_hat = r_hat,
    cure_fraction_condition = cure_fraction_condition,
    followup_condition = followup_condition,
    decision = decision,
    interpretation = interpretation
  )

  class(out) <- "receus.output"
  out
}
