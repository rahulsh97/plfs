#' Download the Annual Survey of Industries database from GitHub (2019-2023)
#'
#' This function downloads the database from GitHub and creates a local database (DuckDB) with the data. These
#' datasets cannot be included in the package due to their size and CRAN file size limits.
#'
#' @param ver Which version to download. By default it is the latest version available on GitHub. You can see all
#' versions at <https://github.com/rahulsh97/asuse/releases>.
#'
#' @return NULL
#' @export
#'
#' @examples
#' \dontrun{ asuse_download() }
asuse_download <- function(ver = NULL) {
  duckdb_version <- utils::packageVersion("duckdb")
  db_pattern <- paste0("v", gsub("\\.", "", duckdb_version), ".sql$")
  
  dir <- asuse_path()

  duckdb_current_files <- list.files(dir, db_pattern, full.names = T)
  
  if (length(duckdb_current_files) > 0 && 
      # avoid listing initial empty duckdb files
      all(file.size(duckdb_current_files) > 5000000000)) {
    msg("There is already a census database for your DuckDB version.")
    msg("If you really want to download the database again, run asuse_delete() and then download it again.")
    return(invisible())
  }
  
  msg("Downloading the datasets from GitHub...")

  destdir <- tempdir()
  
  suppressWarnings(try(dir.create(dir, recursive = TRUE)))
  
  rfile <- get_gh_release_file("rahulsh97/asuse", tag_name = ver, dir = destdir)
 
  msg("Delete old versions of the database if any...\n")
  asuse_delete(ask = FALSE)
    
  finp_rds <- list.files(destdir, full.names = TRUE, pattern = "\\.rds$")
  
  try(dir.create(dir, recursive = TRUE))
  con <- DBI::dbConnect(duckdb::duckdb(), asuse_file_path(dir), read_only = FALSE)

  for (x in seq_along(finp_rds)) { 
    msg(sprintf("Importing %s ...", asuse::available_datasets[x]))
    
    d <- readRDS(finp_rds[x])

    ntables <-  paste0(asuse::available_datasets[x], "-", names(d$data))

    for (i in seq_along(d$data)) {
      copy <- try(DBI::dbWriteTable(con, ntables[i],
        as.data.frame(d$data[[i]]), overwrite = FALSE, append = TRUE))

      if (inherits(copy, "try-error")) {
        DBI::dbDisconnect(con, shutdown = TRUE)

        # remove DB
        asuse_delete(ask = FALSE)

        # remove downloaded files
        for (i in seq_along(finp_rds)) {
          unlink(finp_rds[i])
        }

        stop("It was not possible to create the table ", ntables[i], " in the database.")
      }
    }

    unlink(finp_rds[x])
    invisible(gc())
  }

  DBI::dbDisconnect(con, shutdown = TRUE)
}

#' Descarga los archivos tsv/shp desde GitHub
#' @noRd
get_gh_release_file <- function(repo, tag_name = NULL, dir = tempdir(),
                                overwrite = TRUE) {
  releases <- httr::GET(
    paste0("https://api.github.com/repos/", repo, "/releases")
  )

  httr::stop_for_status(releases, "looking for releases")
  
  releases <- httr::content(releases)
  
  if (is.null(tag_name)) {
    release_obj <- releases[1]
  } else {
    idx <- which(vapply(releases, function(x) !is.null(x$tag_name) && x$tag_name == tag_name, logical(1)))
    release_obj <- if (length(idx)) releases[idx] else list()
  }
  
  if (!length(release_obj)) stop("It was not possible to find an available version \"", tag_name, "\"")
  
  if (release_obj[[1]]$prerelease) {
    msg("These datasets have not been validated yet.")
  }

  assets <- release_obj[[1]]$assets
  if (length(assets) == 0) stop("No assets found for release ", release_obj[[1]]$tag_name)

  out_paths <- character(length(assets))
  for (i in seq_along(assets)) {
    download_url <- assets[[i]]$url
    filename <- basename(assets[[i]]$browser_download_url)
    out_path <- normalizePath(file.path(dir, filename), mustWork = FALSE)
    response <- httr::GET(
      download_url,
      httr::accept("application/octet-stream"),
      httr::write_disk(path = out_path, overwrite = overwrite),
      httr::progress()
    )
    httr::stop_for_status(response, paste0("downloading asset ", filename))
    out_paths[i] <- out_path
  }

  return(out_paths)
}
