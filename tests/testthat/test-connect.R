test_that("plfs_file_path builds a path under the supplied directory", {
  tmp <- file.path(tempdir(), paste0("plfs-test-path-", as.integer(Sys.time())))
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  path <- plfs_file_path(dir = tmp)

  expect_type(path, "character")
  expect_length(path, 1)
  expect_true(startsWith(path, tmp))
  expect_match(basename(path), "^plfs_duckdb_v[0-9]+\\.sql$")
})

test_that("plfs_file_path encodes the installed duckdb version with dots removed", {
  duckdb_version <- utils::packageVersion("duckdb")
  expected_suffix <- paste0("plfs_duckdb_v", gsub("\\.", "", duckdb_version), ".sql")

  path <- plfs_file_path(dir = tempdir())

  expect_identical(basename(path), expected_suffix)
})

test_that("plfs_file_path respects the plfs_PATH environment variable when dir is left at its default", {
  # plfs_path() normalises backslashes to forward slashes (see R/connect.R);
  # tempdir() returns native separators on Windows, so the expected prefix
  # must be normalised the same way before comparing.
  tmp <- file.path(tempdir(), paste0("plfs-test-envpath-", as.integer(Sys.time())))
  tmp_normalised <- gsub("\\\\", "/", tmp)

  old_env <- Sys.getenv("plfs_PATH", unset = NA)
  Sys.setenv(plfs_PATH = tmp)
  on.exit({
    if (is.na(old_env)) Sys.unsetenv("plfs_PATH") else Sys.setenv(plfs_PATH = old_env)
  }, add = TRUE)

  path <- plfs_file_path()

  expect_true(startsWith(path, tmp_normalised))
})
