test_that("receus.method returns expected structure", {
  skip_on_cran()

  dat <- prepare.surv.data(
    data = survival::gbsg,
    time = "rfstime",
    status = "status",
    time_scale = "days_to_years"
  )

  res <- receus.method(dat, dist = "lnorm")

  expect_type(res, "list")
  expect_s3_class(res, "receus.output")
  expect_true(all(c("dist", "tau", "estimates", "pi_hat", "r_hat") %in% names(res)))
})
