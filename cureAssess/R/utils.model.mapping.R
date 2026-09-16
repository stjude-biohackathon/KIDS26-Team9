#' Map fitted model names to RECeUS distribution codes
#'
#' Internal helper to convert model names from the AIC table into
#' the distribution codes used by `receus.method()`.
#'
#' @param model_name Character string.
#'
#' @return A character string giving the RECeUS distribution code.
#' @keywords internal
.map_model_to_receus_dist <- function(model_name) {
  model_name <- tolower(model_name)

  map <- c(
    exponential = "expUnc",
    exponential_cure = "exp",
    weibull = "weiUnc",
    weibull_cure = "wei",
    gamma = "gamUnc",
    gamma_cure = "gam",
    loglogistic = "llogisUnc",
    loglogistic_cure = "llogis",
    lognormal = "lnormUnc",
    lognormal_cure = "lnorm"
  )

  if (model_name %in% names(map)) {
    map[[model_name]]
  } else {
    NA_character_
  }
}
