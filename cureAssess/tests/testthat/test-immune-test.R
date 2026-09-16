test_that("immune.test returns immune summary quantities", {
  dat <- prepare.surv.data(
    data = survival::gbsg,
    time = "rfstime",
    status = "status",
    time_scale = "days_to_years"
  )

  res <- immune.test(dat)

  expect_type(res, "list")
  expect_s3_class(res, "immune.test.result")
  expect_true(all(c(
    "method", "p_hat", "p_cens", "last_observation",
    "last_observation_censored"
  ) %in% names(res)))
})
