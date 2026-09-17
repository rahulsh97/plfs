test_that("available_datasets is a well-formed, non-empty character vector", {
  expect_type(available_datasets, "character")
  expect_gt(length(available_datasets), 0)
  expect_false(anyNA(available_datasets))
  expect_identical(anyDuplicated(available_datasets), 0L)
})

test_that("available_datasets entries follow the PLFS survey-year format (YYYY-YY)", {
  expect_true(all(grepl("^[0-9]{4}-[0-9]{2}$", available_datasets)))
})

test_that("available_datasets is listed in chronological order", {
  expect_identical(available_datasets, sort(available_datasets))
})
