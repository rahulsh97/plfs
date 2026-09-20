test_that("plfs_delete removes the local database directory without prompting when ask = FALSE", {
  tmp_root <- file.path(tempdir(), paste0("plfs-test-delete-", as.integer(Sys.time())))
  dir.create(tmp_root)
  writeLines("dummy", file.path(tmp_root, "placeholder.sql"))

  old_env <- Sys.getenv("plfs_PATH", unset = NA)
  Sys.setenv(plfs_PATH = tmp_root)
  on.exit({
    if (is.na(old_env)) Sys.unsetenv("plfs_PATH") else Sys.setenv(plfs_PATH = old_env)
    unlink(tmp_root, recursive = TRUE)
  }, add = TRUE)

  expect_true(dir.exists(tmp_root))

  result <- plfs_delete(ask = FALSE)

  expect_null(result)
  expect_false(dir.exists(tmp_root))
})

test_that("plfs_delete is safe to call when the database directory does not exist", {
  tmp_root <- file.path(tempdir(), paste0("plfs-test-missing-", as.integer(Sys.time())))

  old_env <- Sys.getenv("plfs_PATH", unset = NA)
  Sys.setenv(plfs_PATH = tmp_root)
  on.exit({
    if (is.na(old_env)) Sys.unsetenv("plfs_PATH") else Sys.setenv(plfs_PATH = old_env)
  }, add = TRUE)

  expect_false(dir.exists(tmp_root))
  expect_error(plfs_delete(ask = FALSE), NA)
})
