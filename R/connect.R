plfs_path <- function() {
  sys_plfs_path <- Sys.getenv("plfs_PATH")
  sys_plfs_path <- gsub("\\\\", "/", sys_plfs_path)
  if (sys_plfs_path == "") {
    return(gsub("\\\\", "/", tools::R_user_dir("plfs")))
  } else {
    return(gsub("\\\\", "/", sys_plfs_path))
  }
}

#' Local plfs database file path
#'
#' Returns the path to the local plfs database directory.
#'
#' @param dir Path to the plfs directory on disk. By default this is #' "plfs" inside the user's R data directory, or the
#' directory specified by the `plfs_DIR` environment variable if set.
#'
#' @export
#'
#' @examples
#' plfs_file_path()
plfs_file_path <- function(dir = plfs_path()) {
  duckdb_version <- utils::packageVersion("duckdb")
  paste0(dir, "/plfs_duckdb_v", gsub("\\.", "", duckdb_version), ".sql")
}
