asuse_path <- function() {
  sys_asuse_path <- Sys.getenv("ASUSE_PATH")
  sys_asuse_path <- gsub("\\\\", "/", sys_asuse_path)
  if (sys_asuse_path == "") {
    return(gsub("\\\\", "/", tools::R_user_dir("asuse")))
  } else {
    return(gsub("\\\\", "/", sys_asuse_path))
  }
}

#' Local ASUSE database file path
#'
#' Returns the path to the local ASUSE database directory.
#'
#' @param dir Path to the ASUSE directory on disk. By default this is #' "asuse" inside the user's R data directory, or the
#' directory specified by the `ASUSE_DIR` environment variable if set.
#'
#' @export
#'
#' @examples
#' asuse_file_path()
asuse_file_path <- function(dir = asuse_path()) {
  duckdb_version <- utils::packageVersion("duckdb")
  paste0(dir, "/asuse_duckdb_v", gsub("\\.", "", duckdb_version), ".sql")
}
