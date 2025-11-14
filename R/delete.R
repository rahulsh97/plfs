#' Delete local plfs database
#'
#' Removes the plfs directory and all its contents.
#'
#' @param ask whether to prompt the user for confirmation before deleting existing census databases. Defaults to TRUE.
#' @return NULL (invisibly)
#' @export
#'
#' @examples
#' \dontrun{ plfs_delete() }
plfs_delete <- function(ask = TRUE) {
  if (ask) {
    answer <- utils::menu(c("Proceed", "Cancel"), 
                   title = "This will delete all plfs databases",
                   graphics = FALSE)
    if (answer == 2L) {
       return(invisible())
    }
  }
  
  try(unlink(plfs_path(), recursive = TRUE))
  return(invisible())
}
