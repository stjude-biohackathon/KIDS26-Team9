#' Prepare survival data for cure model assessment
#'
#' Standardizes survival data into a format required by the package.
#' The returned data frame always contains columns `Y` for survival time
#' and `D` for event indicator, D = 1 for event and D = 0 for censoring.
#'
#' @param data A data frame.
#' @param time Character string giving the survival time column name.
#' @param status Character string giving the event indicator column name.
#' @param time_scale Either `"none"` or `"days_to_years"`.
#'
#' @return A data frame with standardized columns `Y` for survival time
#' and `D` for event indicator, D = 1 for event and D = 0 for censoring.
#'
#' @seealso
#' \code{\link{model.fitting}},
#' \code{\link{cure.appropriateness}}
#'
#' @examples
#' library(survival)
#'
#' # `rfstime` is recorded in days, so convert it to years
#' dat <- prepare.surv.data(
#'   data = gbsg,
#'   time = "rfstime",
#'   status = "status",
#'   time_scale = "days_to_years"
#' )
#'
#' head(dat[, c("Y", "D")])
#'
#' @importFrom dplyr .data
#' @export
prepare.surv.data <- function(data,
                              time,
                              status,
                              time_scale = c("none", "days_to_years")) {
  time_scale <- match.arg(time_scale)

  out <- data |>
    dplyr::mutate(
      Y = .data[[time]],
      D = .data[[status]]
    )

  if (time_scale == "days_to_years") {
    out <- out |>
      dplyr::mutate(Y = .data$Y / 365.25)
  }

  .check_surv_data(out)
  out
}
