#' cureAssess: Assessing Cure Model Appropriateness for Survival Data
#'
#' Tools for deciding whether a cure model is appropriate for right-censored
#' survival data, that is, whether the data plausibly contain a fraction of
#' subjects who will never experience the event of interest.
#'
#' The package implements a two-stage workflow.
#'
#' **Stage 1 -- screening.** [prepare.surv.data()] standardizes a data frame
#' into the survival time (`Y`) and event indicator (`D`) columns used
#' throughout the package. [model.fitting()] then fits matched cure and
#' non-cure parametric models and ranks them by AIC. If the smallest-AIC model
#' is a cure model, that is initial support for cure modeling.
#'
#' **Stage 2 -- diagnostics.** [run.cure.tests()] applies the formal
#' diagnostics: [mz.test()] and [qn.test()] (Maller-Zhou statistics for
#' sufficient follow-up), [shen.test()] (Shen's test), [immune.test()] (a
#' descriptive summary of the tail of the Kaplan-Meier curve), and
#' [receus.method()] (the RECeUS ratio of censored uncured subjects).
#'
#' [cure.appropriateness()] runs both stages and returns a single object with
#' `print()` and `summary()` methods.
#'
#' Diagnostics for sufficient follow-up ask whether the study ran long enough
#' to distinguish a genuine cure fraction from a plateau caused by censoring.
#' They are descriptive aids and should be read together, and alongside
#' subject-matter knowledge, rather than treated as a single decision rule.
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
#' Shen P-S (2000).
#' *Testing for sufficient follow-up in survival data.*
#' Statistics & Probability Letters, 49(4), 313--322.
#' \doi{10.1016/S0167-7152(00)00063-8}
#'
#' Selukar S, Othus M (2023).
#' *RECeUS: Ratio estimation of censored uncured subjects, a different
#' approach for assessing cure model appropriateness in studies with
#' long-term survivors.*
#' Statistics in Medicine, 42(3), 209--227.
#' \doi{10.1002/sim.9610}
#'
#' @seealso
#' Useful entry points:
#' \code{\link{cure.appropriateness}},
#' \code{\link{prepare.surv.data}},
#' \code{\link{model.fitting}},
#' \code{\link{run.cure.tests}}
#'
#' @keywords internal
"_PACKAGE"
