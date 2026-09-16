test_that("cure.appropriateness wrapper returns structured output", {
  skip_on_cran()

  res <- cure.appropriateness(
    data = survival::gbsg,
    time = "rfstime",
    status = "status",
    time_scale = "days_to_years",
    dist = "lnorm",
    plot_km = FALSE,
    run_tests = "no"
  )

  expect_type(res, "list")
  expect_s3_class(res, "cure.appropriateness")

  expect_true(all(c(
    "data",
    "screening",
    "tests",
    "tests_run",
    "tests_reason",
    "final_recommendation"
  ) %in% names(res)))

  expect_true(all(c(
    "kmfit",
    "kmplot",
    "aic_table",
    "best_model",
    "best_model_type",
    "initial_decision"
  ) %in% names(res$screening)))

  expect_s3_class(res$screening$aic_table, "data.frame")
  expect_type(res$screening$best_model, "character")
  expect_type(res$screening$best_model_type, "character")
  expect_type(res$tests_run, "logical")
  expect_type(res$tests_reason, "character")
  expect_type(res$final_recommendation, "character")
})
