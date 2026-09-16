#' Fit candidate cure and non-cure survival models
#'
#' Fits a set of parametric survival models and corresponding cure models to
#' right-censored survival data, compares them using the Akaike Information
#' Criterion (AIC), and identifies the model with the smallest AIC.
#'
#' The default candidate distributions are exponential, Weibull, gamma, and
#' log-logistic, matching the four distributions used in the tutorial worked
#' example. The lognormal distribution is available as an optional addition via
#' `include_lognormal = TRUE`.
#'
#' For each distribution, both a non-cure model and a cure model are fitted.
#' A Kaplan-Meier estimate is also computed, and a Kaplan-Meier plot can be
#' optionally returned.
#'
#' @param data A data frame containing columns `Y` and `D`, where `Y` is the
#'   observed survival time and `D` is the event indicator (`1` = event,
#'   `0` = censoring).
#' @param plot_km Logical; if `TRUE`, also returns a Kaplan-Meier plot created
#'   using `survminer::ggsurvplot`.
#' @param include_lognormal Logical; if `TRUE`, the lognormal cure and non-cure
#'   models are added to the candidate set. Defaults to `FALSE` so that the
#'   default candidate set matches the four distributions used in the tutorial
#'   (exponential, Weibull, gamma, log-logistic). The lognormal distribution has
#'   a heavy tail that can substantially change the RECeUS remaining-uncured
#'   ratio and the selected model, so it is opt-in.
#'
#' @return An object of class `"cure.model.fit"` containing:
#' \describe{
#'   \item{kmfit}{A `survival::survfit` object representing the Kaplan-Meier
#'   estimate of the survival function.}
#'
#'   \item{kmplot}{A Kaplan-Meier plot object created using
#'   `survminer::ggsurvplot`. This is returned only when `plot_km = TRUE`.}
#'
#'   \item{fits}{A named list of fitted model results. Each element contains:
#'   \describe{
#'     \item{fit}{The fitted model object, or `NULL` if fitting failed.}
#'     \item{AIC}{The Akaike Information Criterion value for the fitted model.}
#'     \item{error}{An error message if model fitting failed, otherwise `NULL`.}
#'   }}
#'
#'   \item{aic_table}{A data frame summarizing the fitted models, including
#'   model name, model type (`"cure"` or `"non-cure"`), AIC value,
#'   parameter estimates, and fitting errors. The table is ordered by
#'   increasing AIC.}
#'
#'   \item{best_model}{A character string giving the name of the model with the
#'   smallest AIC.}
#'
#'   \item{best_model_type}{A character string indicating whether the best model
#'   is a `"cure"` or `"non-cure"` model.}
#' }
#'
#' Objects of class `"cure.model.fit"` represent the model-screening stage of
#' cure model assessment and are typically used as input for downstream
#' functions such as `run.cure.tests()` and `cure.appropriateness()`.
#'
#' @seealso
#' \code{\link{prepare.surv.data}},
#' \code{\link{run.cure.tests}},
#' \code{\link{cure.appropriateness}},
#' \code{\link{print.cure.model.fit}},
#' \code{\link{summary.cure.model.fit}},
#' \code{\link{plot.cure.model.fit}}
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
#' fit_res <- model.fitting(dat, plot_km = FALSE)
#'
#' fit_res$aic_table
#' fit_res$best_model
#' fit_res$best_model_type
#' @export
model.fitting <- function(data, plot_km = TRUE, include_lognormal = FALSE) {
  .check_surv_data(data)

  kmfit <- survival::survfit(survival::Surv(Y, D) ~ 1, data = data)

  kmplot <- NULL
  if (isTRUE(plot_km)) {
    kmplot <- survminer::ggsurvplot(
      kmfit,
      conf.int = TRUE,
      pval = FALSE,
      risk.table = TRUE,
      ggtheme = ggplot2::theme_minimal(),
      title = "Kaplan-Meier Survival Curve",
      xlab = "Time",
      ylab = "Survival Probability",
      data = data
    )
  }

  fit_one <- function(dist, cure = FALSE) {
    tryCatch(
      {
        fit <- if (cure) {
          flexsurvcure::flexsurvcure(
            survival::Surv(Y, D) ~ 1,
            data = data,
            dist = dist
          )
        } else {
          flexsurv::flexsurvreg(
            survival::Surv(Y, D) ~ 1,
            data = data,
            dist = dist
          )
        }

        list(
          fit = fit,
          AIC = fit$AIC,
          error = NULL
        )
      },
      error = function(e) {
        list(
          fit = NULL,
          AIC = NA_real_,
          error = e$message
        )
      }
    )
  }

  fits <- list(
    exponential = fit_one("exp", cure = FALSE),
    exponential_cure = fit_one("exp", cure = TRUE),
    weibull = fit_one("weibull", cure = FALSE),
    weibull_cure = fit_one("weibull", cure = TRUE),
    gamma = fit_one("gamma", cure = FALSE),
    gamma_cure = fit_one("gamma", cure = TRUE),
    loglogistic = fit_one("llogis", cure = FALSE),
    loglogistic_cure = fit_one("llogis", cure = TRUE)
  )

  if (isTRUE(include_lognormal)) {
    fits$lognormal <- fit_one("lnorm", cure = FALSE)
    fits$lognormal_cure <- fit_one("lnorm", cure = TRUE)
  }

  extract_estimates <- function(x) {
    if (is.null(x$fit)) {
      return(NA_character_)
    }

    est <- tryCatch(
      x$fit$res[, 1],
      error = function(e) NULL
    )

    if (is.null(est)) {
      return(NA_character_)
    }

    paste(
      paste0(names(est), "=", round(unname(est), 4)),
      collapse = "; "
    )
  }

  aic_table <- data.frame(
    model = names(fits),
    model_type = ifelse(grepl("_cure$", names(fits)), "cure", "non-cure"),
    AIC = vapply(fits, function(x) x$AIC, numeric(1)),
    parameter_estimates = vapply(fits, extract_estimates, character(1)),
    error = vapply(
      fits,
      function(x) if (is.null(x$error)) "" else x$error,
      character(1)
    ),
    stringsAsFactors = FALSE
  )

  aic_table <- aic_table[order(aic_table$AIC), , drop = FALSE]
  rownames(aic_table) <- NULL

  valid_rows <- which(!is.na(aic_table$AIC))
  if (length(valid_rows) == 0) {
    best_model <- NA_character_
    best_model_type <- NA_character_
  } else {
    best_model <- aic_table$model[valid_rows[1]]
    best_model_type <- aic_table$model_type[valid_rows[1]]
  }

  out <- list(
    kmfit = kmfit,
    kmplot = kmplot,
    fits = fits,
    aic_table = aic_table,
    best_model = best_model,
    best_model_type = best_model_type
  )

  class(out) <- "cure.model.fit"
  out
}
