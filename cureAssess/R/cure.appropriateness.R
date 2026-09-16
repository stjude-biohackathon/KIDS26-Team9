#' Assess cure model appropriateness in two stages
#'
#' Performs a two-stage workflow for cure model assessment.
#'
#' Stage 1:
#' - Prepares the data
#' - Fits a Kaplan-Meier curve
#' - Fits candidate cure and non-cure models
#' - Compares them using AIC
#' - Selects the model with the smallest AIC
#' - Provides an initial recommendation
#'
#' Stage 2:
#' - Runs cure-appropriateness tests
#'   such as Maller-Zhou statistics, Shen's test,
#'   immune summaries and RECeUS-style outputs.
#'
#' If the smallest-AIC model is a non-cure model, the function reports
#' that a cure model is not supported by the initial model-comparison step,
#' while still allowing the user to proceed with additional tests if desired.
#'
#' @param data A data frame.
#' @param time Character string giving the survival time column name.
#' @param status Character string giving the event indicator column name.
#' @param time_scale Either `"none"` or `"days_to_years"`.
#' @param dist Optional distribution to use for the RECeUS method.
#'   If `NULL`, the function automatically selects the best-fitting
#'   cure-model distribution from the Stage 1 AIC table.
#' @param plot_km Logical; if `TRUE`, include Kaplan-Meier plot object.
#' @param run_tests One of `"auto"`, `"yes"`, or `"no"`.
#' @param include_lognormal Logical; passed to [model.fitting()]. If `TRUE`, the
#'   lognormal cure and non-cure models are added to the Stage 1 candidate set.
#'   Defaults to `FALSE` so the candidate set matches the four distributions used
#'   in the tutorial. Because the automatic RECeUS distribution (`dist = NULL`)
#'   is selected as the smallest-AIC cure model, enabling lognormal can change
#'   both the selected model and the RECeUS conclusion.
#'
#' @return An object of class `"cure.appropriateness"` containing:
#' \describe{
#'   \item{data}{The standardized survival dataset returned by
#'   `prepare.surv.data()`, containing the survival time (`Y`) and
#'   event indicator (`D`).}
#'
#'   \item{screening}{A list containing results from the model screening
#'   step.}
#'
#'   \item{screening$kmfit}{Kaplan-Meier estimate of the survival
#'   function (`survival::survfit` object).}
#'
#'   \item{screening$kmplot}{Kaplan-Meier plot generated using
#'   `survminer::ggsurvplot`, returned when `plot_km = TRUE`.}
#'
#'   \item{screening$aic_table}{A data frame summarizing the fitted
#'   candidate models, including model name, model type
#'   (`"cure"` or `"non-cure"`), AIC value, and parameter estimates.}
#'
#'   \item{screening$best_model}{The model with the smallest AIC.}
#'
#'   \item{screening$best_model_type}{Indicates whether the best model is
#'   a `"cure"` or `"non-cure"` model.}
#'
#'   \item{screening$initial_decision}{Text summarizing the initial
#'   interpretation based on the AIC comparison.}
#'
#'   \item{selected_receus_model}{The cure model selected for the RECeUS
#'   method, based on the smallest AIC among cure models.}
#'
#'   \item{selected_receus_dist}{The distribution code used by the
#'   RECeUS procedure.}
#'
#'   \item{tests}{A list containing results from additional
#'   cure-appropriateness diagnostics.}
#'
#'   \item{tests_run}{Logical indicator specifying whether additional
#'   diagnostic tests were executed.}
#'
#'   \item{tests_reason}{Explanation describing why the diagnostic tests
#'   were or were not executed.}
#'
#'   \item{final_recommendation}{A text summary combining the screening
#'   results and optional diagnostic tests to provide a final
#'   interpretation regarding cure model appropriateness.}
#' }
#'
#' @seealso
#' \code{\link{prepare.surv.data}},
#' \code{\link{model.fitting}},
#' \code{\link{run.cure.tests}}
#'
#' @examples
#' library(survival)
#'
#' # Stage 1 only: Kaplan-Meier screening and AIC model comparison
#' res <- cure.appropriateness(
#'   data = gbsg,
#'   time = "rfstime",
#'   status = "status",
#'   time_scale = "days_to_years",
#'   plot_km = FALSE,
#'   run_tests = "no"
#' )
#' res
#'
#' # Stage 1 and Stage 2: also run the cure-appropriateness diagnostics
#' res_full <- cure.appropriateness(
#'   data = gbsg,
#'   time = "rfstime",
#'   status = "status",
#'   time_scale = "days_to_years",
#'   plot_km = FALSE,
#'   run_tests = "yes"
#' )
#' summary(res_full)
#'
#' @export
cure.appropriateness <- function(
  data,
  time,
  status,
  time_scale = c("none", "days_to_years"),
  dist = NULL,
  plot_km = TRUE,
  run_tests = c("auto", "yes", "no"),
  include_lognormal = FALSE
) {
  time_scale <- match.arg(time_scale)
  run_tests <- match.arg(run_tests)

  dat <- prepare.surv.data(
    data = data,
    time = time,
    status = status,
    time_scale = time_scale
  )

  fit_res <- model.fitting(dat, plot_km = plot_km, include_lognormal = include_lognormal)

  best_model <- fit_res$best_model
  best_model_type <- fit_res$best_model_type

  if (is.na(best_model)) {
    initial_decision <- paste(
      "No candidate model was successfully fitted,",
      "so cure model appropriateness could not be assessed",
      "from AIC comparison."
    )
  } else if (best_model_type == "cure") {
    initial_decision <- paste0(
      "The model with the smallest AIC is a cure model (",
      best_model,
      "). This provides initial support for cure model appropriateness."
    )
  } else {
    initial_decision <- paste0(
      "The model with the smallest AIC is a non-cure model (",
      best_model,
      "). Based on initial model comparison, a cure model is not ",
      "supported as the preferred choice. Additional ",
      "cure-appropriateness tests can still be run if desired."
    )
  }

  selected_dist <- dist
  selected_receus_model <- NULL

  if (is.null(selected_dist)) {
    cure_rows <- fit_res$aic_table[
      fit_res$aic_table$model_type == "cure" &
        !is.na(fit_res$aic_table$AIC),
      ,
      drop = FALSE
    ]

    if (nrow(cure_rows) > 0) {
      best_cure_model <- cure_rows$model[which.min(cure_rows$AIC)]
      selected_dist <- .map_model_to_receus_dist(best_cure_model)
      selected_receus_model <- best_cure_model
    } else {
      selected_dist <- NA_character_
      selected_receus_model <- NA_character_
    }
  }

  tests <- NULL
  tests_run <- FALSE
  tests_reason <- "Tests were not run."

  if (run_tests == "yes") {
    if (!is.null(selected_dist) && !is.na(selected_dist)) {
      tests <- run.cure.tests(dat, dist = selected_dist)
      tests_run <- TRUE
      tests_reason <- paste0(
        "Tests were run because `run_tests = \"yes\"`. ",
        "RECeUS used distribution: ",
        selected_dist,
        "."
      )
    } else {
      tests_run <- FALSE
      tests_reason <- paste(
        "Tests could not be run because no cure models were",
        "successfully fitted in Stage 1."
      )
    }
  } else if (
    run_tests == "auto" &&
      identical(best_model_type, "cure")
  ) {
    if (!is.null(selected_dist) && !is.na(selected_dist)) {
      tests <- run.cure.tests(dat, dist = selected_dist)
      tests_run <- TRUE
      tests_reason <- paste(
        "Tests were run automatically because the smallest-AIC model",
        "was a cure model.",
        paste0("RECeUS used distribution: ", selected_dist, ".")
      )
    } else {
      tests_run <- FALSE
      tests_reason <- paste(
        "Tests were not run because no cure models were",
        "successfully fitted in Stage 1."
      )
    }
  } else if (
    run_tests == "auto" &&
      identical(best_model_type, "non-cure")
  ) {
    tests_run <- FALSE
    tests_reason <- paste(
      "Tests were not run automatically because the smallest-AIC",
      "model was a non-cure model."
    )
  } else if (run_tests == "no") {
    tests_run <- FALSE
    tests_reason <- "Tests were not run because `run_tests = \"no\"`."
  }

  final_recommendation <- if (!tests_run) {
    initial_decision
  } else {
    paste(
      initial_decision,
      "Additional cure-appropriateness diagnostics were run",
      "for further evaluation."
    )
  }

  out <- list(
    data = dat,
    screening = list(
      kmfit = fit_res$kmfit,
      kmplot = fit_res$kmplot,
      aic_table = fit_res$aic_table,
      best_model = best_model,
      best_model_type = best_model_type,
      initial_decision = initial_decision
    ),
    selected_receus_model = selected_receus_model,
    selected_receus_dist = selected_dist,
    tests = tests,
    tests_run = tests_run,
    tests_reason = tests_reason,
    final_recommendation = final_recommendation
  )

  class(out) <- "cure.appropriateness"
  out
}
