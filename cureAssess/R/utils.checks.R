#' Validate survival data input
#'
#' Internal helper to validate that the input data frame contains
#' survival time and event indicator columns named `Y` and `D`.
#'
#' @param data A data frame containing survival data.
#'
#' @return Invisibly returns `TRUE` if checks pass.
#' @keywords internal
.check_surv_data <- function(data) {
  if (!is.data.frame(data)) {
    stop("`data` must be a data.frame.", call. = FALSE)
  }

  required_cols <- c("Y", "D")
  missing_cols <- setdiff(required_cols, names(data))

  if (length(missing_cols) > 0) {
    stop(
      paste0(
        "`data` must contain columns: ",
        paste(required_cols, collapse = ", "),
        ". Missing: ",
        paste(missing_cols, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  if (!is.numeric(data$Y)) {
    stop("`Y` must be numeric.", call. = FALSE)
  }

  if (!all(stats::na.omit(data$D) %in% c(0, 1))) {
    stop("`D` must be coded as 0/1.", call. = FALSE)
  }

  invisible(TRUE)
}
