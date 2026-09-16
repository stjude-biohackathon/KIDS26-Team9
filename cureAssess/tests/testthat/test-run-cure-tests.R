test_that("run.cure.tests returns all diagnostic results", {
  skip_on_cran()

  dat <- prepare.surv.data(
    data = survival::gbsg,
    time = "rfstime",
    status = "status",
    time_scale = "days_to_years"
  )

  res <- run.cure.tests(dat, dist = "lnorm")

  expect_type(res, "list")
  expect_true(all(c("receus", "mz", "qn", "shen", "immune") %in% names(res)))
  expect_s3_class(res$receus, "receus.output")
  expect_s3_class(res$mz, "cure.test.result")
  expect_s3_class(res$qn, "cure.test.result")
  expect_s3_class(res$shen, "cure.test.result")
  expect_s3_class(res$immune, "immune.test.result")
})
