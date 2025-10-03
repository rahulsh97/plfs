#' Delete local ASUSE database
#'
#' Removes the ASUSE directory and all its contents.
#'
#' @param ask whether to prompt the user for confirmation before deleting existing census databases. Defaults to TRUE.
#' @return NULL (invisibly)
#' @export
#'
#' @examples
#' \dontrun{ asuse_delete() }
asuse_delete <- function(ask = TRUE) {
  if (ask) {
    answer <- utils::menu(c("Proceed", "Cancel"), 
                   title = "This will delete all ASUSE databases",
                   graphics = FALSE)
    if (answer == 2L) {
       return(invisible())
    }
  }
  
  try(unlink(asuse_path(), recursive = TRUE))
  return(invisible())
}
