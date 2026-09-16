test_that("model.fitting returns structured output", {
  skip_on_cran()

  dat <- prepare.surv.data(
    data = survival::gbsg,
    time = "rfstime",
    status = "status",
    time_scale = "days_to_years"
  )

  res <- model.fitting(dat, plot_km = FALSE)

  expect_type(res, "list")
  expect_s3_class(res, "cure.model.fit")
  expect_true(all(c("kmfit", "kmplot", "fits", "aic_table", "best_model") %in% names(res)))
  expect_s3_class(res$aic_table, "data.frame")
  expect_true("model" %in% names(res$aic_table))
  expect_true("AIC" %in% names(res$aic_table))
  expect_type(res$best_model, "character")
})
