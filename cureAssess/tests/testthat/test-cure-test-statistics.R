test_that("cure test statistic functions return structured output", {
  dat <- prepare.surv.data(
    data = survival::gbsg,
    time = "rfstime",
    status = "status",
    time_scale = "days_to_years"
  )

  mz  <- mz.test(dat)
  qn  <- qn.test(dat)
  shn <- shen.test(dat)

  expect_s3_class(mz,  "cure.test.result")
  expect_s3_class(qn,  "cure.test.result")
  expect_s3_class(shn, "cure.test.result")

  expect_true(all(c("method", "statistic") %in% names(mz)))
  expect_true(all(c("method", "statistic") %in% names(qn)))
  expect_true(all(c("method", "statistic") %in% names(shn)))
})
