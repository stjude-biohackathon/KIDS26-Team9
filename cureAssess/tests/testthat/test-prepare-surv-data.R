test_that("prepare.surv.data returns Y and D columns", {
  dat <- survival::gbsg
  out <- prepare.surv.data(
    data = dat,
    time = "rfstime",
    status = "status",
    time_scale = "days_to_years"
  )
  expect_s3_class(out, "data.frame")
  expect_true(all(c("Y", "D") %in% names(out)))
  expect_true(is.numeric(out$Y))
  expect_true(all(stats::na.omit(out$D) %in% c(0, 1)))
})
