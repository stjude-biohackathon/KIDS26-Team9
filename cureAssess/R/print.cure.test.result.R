#' Print cure model test results
#'
#' Prints the results of a cure model diagnostic test, including
#' the test statistic, significance level (if available), and
#' interpretation.
#'
#' @param x An object of class `"cure.test.result"`.
#' @param ... Additional arguments passed to other methods.
#'
#' @return The input object `x`, returned invisibly.
#' @export
print.cure.test.result <- function(x, ...) {

  cat("\n", x$method, "\n", sep = "")
  cat(strrep("-", nchar(x$method)), "\n", sep = "")

  cat("Statistic:", x$statistic, "\n")

  if (!is.null(x$alpha)) {
    cat("Alpha:", x$alpha, "\n")
  }

  if (!is.null(x$interpretation)) {
    cat("Interpretation:", x$interpretation, "\n")
  }

  invisible(x)
}
