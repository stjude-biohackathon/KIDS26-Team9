#' Internal maximum likelihood wrapper
#'
#' Internal helper used by RECeUS-style calculations.
#'
#' @param dat A data frame with columns `Y` and `D`.
#' @param dist Distribution name.
#'
#' @return A named numeric vector.
#' @keywords internal
mleFun <- function(dat, dist = "exp") {
  .check_surv_data(dat)

  if (dist == "exp") {
    tmp <- flexsurvcure::flexsurvcure(survival::Surv(Y, D) ~ 1, data = dat, dist = "exp")
    return(c(
      pi = tmp$res[1, 1], rate = tmp$res[2, 1],
      piLB = tmp$res[1, 2], piUB = tmp$res[1, 3],
      rateLB = tmp$res[2, 2], rateUB = tmp$res[2, 3],
      AIC = tmp$AIC
    ))
  }

  if (dist == "expUnc") {
    tmp <- flexsurv::flexsurvreg(survival::Surv(Y, D) ~ 1, data = dat, dist = "exp")
    return(c(
      pi = 0, rate = tmp$res[1, 1],
      piLB = NA, piUB = NA,
      rateLB = tmp$res[1, 2], rateUB = tmp$res[1, 3],
      AIC = tmp$AIC
    ))
  }

  if (dist == "wei") {
    tmp <- flexsurvcure::flexsurvcure(survival::Surv(Y, D) ~ 1, data = dat, dist = "weibull")
    return(c(
      pi = tmp$res[1, 1], shape = tmp$res[2, 1], scale = tmp$res[3, 1],
      piLB = tmp$res[1, 2], piUB = tmp$res[1, 3],
      shapeLB = tmp$res[2, 2], shapeUB = tmp$res[2, 3],
      scaleLB = tmp$res[3, 2], scaleUB = tmp$res[3, 3],
      AIC = tmp$AIC
    ))
  }

  if (dist == "weiUnc") {
    tmp <- flexsurv::flexsurvreg(survival::Surv(Y, D) ~ 1, data = dat, dist = "weibull")
    return(c(
      pi = 0, shape = tmp$res[1, 1], scale = tmp$res[2, 1],
      piLB = NA, piUB = NA,
      shapeLB = tmp$res[1, 2], shapeUB = tmp$res[1, 3],
      scaleLB = tmp$res[2, 2], scaleUB = tmp$res[2, 3],
      AIC = tmp$AIC
    ))
  }

  if (dist == "llogis") {
    tmp <- flexsurvcure::flexsurvcure(survival::Surv(Y, D) ~ 1, data = dat, dist = "llogis")
    return(c(
      pi = tmp$res[1, 1], shape = tmp$res[2, 1], scale = tmp$res[3, 1],
      piLB = tmp$res[1, 2], piUB = tmp$res[1, 3],
      shapeLB = tmp$res[2, 2], shapeUB = tmp$res[2, 3],
      scaleLB = tmp$res[3, 2], scaleUB = tmp$res[3, 3],
      AIC = tmp$AIC
    ))
  }

  if (dist == "llogisUnc") {
    tmp <- flexsurv::flexsurvreg(survival::Surv(Y, D) ~ 1, data = dat, dist = "llogis")
    return(c(
      pi = 0, shape = tmp$res[1, 1], scale = tmp$res[2, 1],
      piLB = NA, piUB = NA,
      shapeLB = tmp$res[1, 2], shapeUB = tmp$res[1, 3],
      scaleLB = tmp$res[2, 2], scaleUB = tmp$res[2, 3],
      AIC = tmp$AIC
    ))
  }

  if (dist == "gam") {
    tmp <- flexsurvcure::flexsurvcure(survival::Surv(Y, D) ~ 1, data = dat, dist = "gamma")
    return(c(
      pi = tmp$res[1, 1], shape = tmp$res[2, 1], rate = tmp$res[3, 1],
      piLB = tmp$res[1, 2], piUB = tmp$res[1, 3],
      shapeLB = tmp$res[2, 2], shapeUB = tmp$res[2, 3],
      rateLB = tmp$res[3, 2], rateUB = tmp$res[3, 3],
      AIC = tmp$AIC
    ))
  }

  if (dist == "gamUnc") {
    tmp <- flexsurv::flexsurvreg(survival::Surv(Y, D) ~ 1, data = dat, dist = "gamma")
    return(c(
      pi = 0, shape = tmp$res[1, 1], rate = tmp$res[2, 1],
      piLB = NA, piUB = NA,
      shapeLB = tmp$res[1, 2], shapeUB = tmp$res[1, 3],
      rateLB = tmp$res[2, 2], rateUB = tmp$res[2, 3],
      AIC = tmp$AIC
    ))
  }

  if (dist == "lnorm") {
    tmp <- flexsurvcure::flexsurvcure(survival::Surv(Y, D) ~ 1, data = dat, dist = "lnorm")
    return(c(
      pi = tmp$res[1, 1], meanlog = tmp$res[2, 1], sdlog = tmp$res[3, 1],
      piLB = tmp$res[1, 2], piUB = tmp$res[1, 3],
      meanlogLB = tmp$res[2, 2], meanlogUB = tmp$res[2, 3],
      sdlogLB = tmp$res[3, 2], sdlogUB = tmp$res[3, 3],
      AIC = tmp$AIC
    ))
  }

  if (dist == "lnormUnc") {
    tmp <- flexsurv::flexsurvreg(survival::Surv(Y, D) ~ 1, data = dat, dist = "lnorm")
    return(c(
      pi = 0, meanlog = tmp$res[1, 1], sdlog = tmp$res[2, 1],
      piLB = NA, piUB = NA,
      meanlogLB = tmp$res[1, 2], meanlogUB = tmp$res[1, 3],
      sdlogLB = tmp$res[2, 2], sdlogUB = tmp$res[2, 3],
      AIC = tmp$AIC
    ))
  }

  stop("Unsupported value for `dist`.", call. = FALSE)
}

#' Internal ratio test helper
#'
#' @param dat A data frame with columns `Y` and `D`.
#' @param whichTau Evaluation time point.
#' @param dist Distribution name.
#'
#' @return A numeric vector of estimates.
#' @keywords internal
ratioTest <- function(dat, whichTau, dist = "exp") {
  .check_surv_data(dat)

  est <- tryCatch(mleFun(dat, dist), error = function(e) NULL)

  if (dist == "exp") {
    if (is.null(est)) return(rep(NA_real_, 8))
    return(c(
      est,
      stats::pexp(whichTau, rate = est[2], lower.tail = FALSE) /
        (est[1] + (1 - est[1]) * stats::pexp(whichTau, rate = est[2], lower.tail = FALSE))
    ))
  }

  if (dist == "expUnc") {
    if (is.null(est)) return(rep(NA_real_, 8))
    return(c(est, 1))
  }

  if (dist == "wei") {
    if (is.null(est)) return(rep(NA_real_, 11))
    return(c(
      est,
      stats::pweibull(whichTau, shape = est[2], scale = est[3], lower.tail = FALSE) /
        (est[1] + (1 - est[1]) * stats::pweibull(whichTau, shape = est[2], scale = est[3], lower.tail = FALSE))
    ))
  }

  if (dist == "weiUnc") {
    if (is.null(est)) return(rep(NA_real_, 11))
    return(c(est, 1))
  }

  if (dist == "llogis") {
    if (is.null(est)) return(rep(NA_real_, 11))
    return(c(
      est,
      flexsurv::pllogis(whichTau, shape = est[2], scale = est[3], lower.tail = FALSE) /
        (est[1] + (1 - est[1]) * flexsurv::pllogis(whichTau, shape = est[2], scale = est[3], lower.tail = FALSE))
    ))
  }

  if (dist == "llogisUnc") {
    if (is.null(est)) return(rep(NA_real_, 11))
    return(c(est, 1))
  }

  if (dist == "gam") {
    if (is.null(est)) return(rep(NA_real_, 11))
    return(c(
      est,
      stats::pgamma(whichTau, shape = est[2], rate = est[3], lower.tail = FALSE) /
        (est[1] + (1 - est[1]) * stats::pgamma(whichTau, shape = est[2], rate = est[3], lower.tail = FALSE))
    ))
  }

  if (dist == "gamUnc") {
    if (is.null(est)) return(rep(NA_real_, 11))
    return(c(est, 1))
  }

  if (dist == "lnorm") {
    if (is.null(est)) return(rep(NA_real_, 11))
    return(c(
      est,
      stats::plnorm(whichTau, meanlog = est[2], sdlog = est[3], lower.tail = FALSE) /
        (est[1] + (1 - est[1]) * stats::plnorm(whichTau, meanlog = est[2], sdlog = est[3], lower.tail = FALSE))
    ))
  }

  if (dist == "lnormUnc") {
    if (is.null(est)) return(rep(NA_real_, 11))
    return(c(est, 1))
  }

  stop("Unsupported value for `dist`.", call. = FALSE)
}
