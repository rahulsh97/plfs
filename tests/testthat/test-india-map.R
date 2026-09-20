# These tests validate region-codes/india_states_map.rds, the package's
# bundled India administrative boundary layer (see region-codes/MAP_SOURCE.md
# for full provenance). That directory is intentionally excluded from the
# built package via .Rbuildignore (it is source-tree reference material for
# the README examples, not installed package data), so it is not present
# when these tests run inside R CMD check's isolated build. Every test here
# skips cleanly, rather than failing, when the file cannot be found.

find_map_file <- function() {
  candidates <- c(
    testthat::test_path("..", "..", "region-codes", "india_states_map.rds")
  )
  hit <- candidates[file.exists(candidates)]
  if (length(hit) == 0) return(NA_character_)
  # Normalise so downstream dirname()/file.path() arithmetic (used by the
  # cross-repository byte-identity check below) works on a resolved path
  # rather than a literal, unresolved "../.." string.
  normalizePath(hit[[1]], winslash = "/", mustWork = TRUE)
}

map_path <- find_map_file()

skip_if_missing_map <- function() {
  testthat::skip_if(
    is.na(map_path),
    "region-codes/india_states_map.rds not present (excluded from the built package by .Rbuildignore; only available in a full source checkout)"
  )
}

test_that("the map file has exactly 36 administrative units", {
  skip_if_missing_map()
  obj <- readRDS(map_path)
  expect_equal(nrow(obj), 36)
})

test_that("the map file has the required columns", {
  skip_if_missing_map()
  obj <- readRDS(map_path)
  expect_true(all(c("state_name", "state_code", "geometry") %in% names(obj)))
})

test_that("the map file CRS is WGS84 (EPSG:4326)", {
  skip_if_missing_map()
  obj <- readRDS(map_path)
  expect_true(sf::st_crs(obj) == sf::st_crs(4326))
})

test_that("all geometries are valid and non-empty", {
  skip_if_missing_map()
  obj <- readRDS(map_path)
  expect_true(all(sf::st_is_valid(obj)))
  expect_false(any(sf::st_is_empty(obj)))
})

test_that("state_name and state_code are unique", {
  skip_if_missing_map()
  obj <- readRDS(map_path)
  expect_equal(anyDuplicated(obj$state_name), 0L)
  expect_equal(anyDuplicated(obj$state_code), 0L)
})

test_that("Jammu and Kashmir exists in the map", {
  skip_if_missing_map()
  obj <- readRDS(map_path)
  expect_true("Jammu and Kashmir" %in% obj$state_name)
})

test_that("Ladakh exists in the map", {
  skip_if_missing_map()
  obj <- readRDS(map_path)
  expect_true("Ladakh" %in% obj$state_name)
})

test_that("Jammu and Kashmir and Ladakh are separate geometries", {
  skip_if_missing_map()
  obj <- readRDS(map_path)
  jk <- obj[obj$state_name == "Jammu and Kashmir", ]
  la <- obj[obj$state_name == "Ladakh", ]
  expect_equal(nrow(jk), 1)
  expect_equal(nrow(la), 1)
  expect_false(isTRUE(sf::st_equals(jk, la, sparse = FALSE)[1, 1]))
})

test_that("the combined Jammu and Kashmir / Ladakh geometry includes the approved claimed-area extent", {
  skip_if_missing_map()
  obj <- readRDS(map_path)
  jkla <- obj[obj$state_name %in% c("Jammu and Kashmir", "Ladakh"), ]
  bbox <- sf::st_bbox(jkla)
  # The approved SimpleMaps candidate extends materially further north/west
  # than the Line of Control / Line of Actual Control it replaces (see
  # region-codes/MAP_SOURCE.md). These thresholds are set just inside the
  # combined bounding box measured from the approved source, as a
  # regression guard against silently reverting to a LoC/LAC-only extent.
  expect_lt(bbox[["xmin"]], 73.5)
  expect_gt(bbox[["xmax"]], 79.5)
  expect_gt(bbox[["ymax"]], 36.5)
})

test_that("reference coordinates around Muzaffarabad, Gilgit, and Skardu fall within the combined Jammu and Kashmir / Ladakh geometry", {
  skip_if_missing_map()
  obj <- readRDS(map_path)
  jkla <- obj[obj$state_name %in% c("Jammu and Kashmir", "Ladakh"), ]
  combined <- sf::st_union(sf::st_geometry(jkla))

  ref_points <- data.frame(
    name = c("Muzaffarabad", "Gilgit", "Skardu"),
    lon  = c(73.4712, 74.3587, 75.6333),
    lat  = c(34.3700, 35.9200, 35.3000)
  )
  pts <- sf::st_as_sf(ref_points, coords = c("lon", "lat"), crs = 4326)

  hits <- sf::st_intersects(pts, combined, sparse = FALSE)[, 1]
  expect_true(all(hits))
})

test_that("Leh falls within the Ladakh geometry specifically", {
  skip_if_missing_map()
  obj <- readRDS(map_path)
  la <- obj[obj$state_name == "Ladakh", ]

  leh <- sf::st_as_sf(
    data.frame(name = "Leh", lon = 77.5770, lat = 34.1526),
    coords = c("lon", "lat"), crs = 4326
  )

  expect_true(sf::st_intersects(leh, la, sparse = FALSE)[1, 1])
})

test_that("the map RDS files for ASI, ASUSE, and PLFS are byte-identical", {
  # This is a local, cross-repository sanity check only: it requires the
  # three sibling package checkouts to be present side by side on disk, as
  # they are not part of any single package's own source tree and cannot be
  # verified from within a single R CMD check run or CI job. It skips
  # cleanly whenever that layout is not present, e.g. in CI or a solo
  # checkout of just this package.
  skip_if_missing_map()

  this_pkg_root <- dirname(dirname(map_path))
  siblings_root <- dirname(this_pkg_root)

  candidate_dirs <- c("asi_project", "asuse_project", "plfs_project")
  candidate_paths <- file.path(siblings_root, candidate_dirs, "region-codes", "india_states_map.rds")
  names(candidate_paths) <- candidate_dirs

  testthat::skip_if(
    !all(file.exists(candidate_paths)),
    "not all three sibling package checkouts (asi_project, asuse_project, plfs_project) are present alongside this one; skipping the cross-repository byte-identity check"
  )

  hashes <- vapply(candidate_paths, function(p) {
    as.character(tools::md5sum(p))
  }, character(1))

  expect_equal(length(unique(hashes)), 1L)
})
