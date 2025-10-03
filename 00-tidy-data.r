library(haven)
library(janitor)
library(purrr)
library(xml2)
library(usethis)

# use_cc0_license()

obs <- paste0("data-raw/", c("202324"))

# remove extra whitespace from list elements and from character attributes
# e.g. $citation$prodStmt$producer[[1]] == "\n  Industrial Statistics Wing\n"
# should become "Industrial Statistics Wing"

trim_recursive <- function(x) {
  # trim character vectors
  if (is.character(x)) {
    return(trimws(x))
  }

  # if atomic but not character, leave as is
  if (!is.list(x)) {
    return(x)
  }

  # if list, recurse into elements and also trim any character attributes
  x <- map(x, trim_recursive)

  # trim character attributes
  attrs <- attributes(x)
  if (!is.null(attrs)) {
    for (an in names(attrs)) {
      if (is.character(attrs[[an]])) {
        attrs[[an]] <- trimws(attrs[[an]])
      }
    }
    attributes(x) <- attrs
  }

  # Additionally, some lists carry attributes on their elements; normalize those
  x <- imap(x, function(el, nm) {
    if (!is.null(attributes(el))) {
      at <- attributes(el)
      for (an in names(at)) {
        if (is.character(at[[an]])) {
          at[[an]] <- trimws(at[[an]])
        }
      }
      attributes(el) <- at
    }
    el
  })

  x
}

# unwrap/splice list elements whose names are NA or empty so their children move up
# e.g. $<NA>$var$sumStat -> $var$sumStat
normalize_lists <- function(x) {
  if (!is.list(x)) {
    return(x)
  }

  # recurse first
  x <- imap(x, function(el, nm) normalize_lists(el))

  nms <- names(x)
  if (is.null(nms)) {
    return(x)
  }

  new <- list()
  new_nms <- character()

  for (i in seq_along(x)) {
    nm <- nms[i]
    el <- x[[i]]

    # skip empty list elements
    if (is.list(el) && length(el) == 0) next

    if (is.na(nm) || nm == "") {
      if (is.list(el) && length(el) > 0) {
        inner_nms <- names(el)
        if (is.null(inner_nms)) {
          for (j in seq_along(el)) {
            # skip empty inner elements
            if (is.list(el[[j]]) && length(el[[j]]) == 0) next
            new <- c(new, list(el[[j]]))
            new_nms <- c(new_nms, ifelse(is.null(names(el)[j]), "", names(el)[j]))
          }
        } else {
          for (j in seq_along(el)) {
            if (is.list(el[[j]]) && length(el[[j]]) == 0) next
            new <- c(new, list(el[[j]]))
            new_nms <- c(new_nms, inner_nms[j])
          }
        }
      } else {
        new <- c(new, list(el))
        new_nms <- c(new_nms, "")
      }
    } else {
      new <- c(new, list(el))
      new_nms <- c(new_nms, nm)
    }
  }

  # remove any elements that are NULL
  keep <- vapply(new, function(e) !is.null(e), logical(1))
  if (length(keep) > 0) {
    new <- new[keep]
    new_nms <- new_nms[keep]
  }

  if (length(new) == 0) {
    return(list())
  }
  # assign names, but treat empty strings as unnamed
  if (all(new_nms == "")) {
    names(new) <- NULL
  } else {
    # replace empty name entries with NA so they become unnamed
    new_nms[new_nms == ""] <- NA_character_
    names(new) <- new_nms
  }

  new
}

try(dir.create("data-tidy"))

map(
  obs,
  function(x) {
    message("===============================")
    message(x)
    # x = obs[1]

    nm <- paste0("plfs", sub("data-raw/", "", x))

    fout <- paste0("data-tidy/", nm, ".rds")

    if (file.exists(fout)) {
      return(FALSE)
    }

    savs <- sort(list.files(x, pattern = "\\.sav$", full.names = TRUE, recursive = TRUE))

    # move files with "rectified" in name to end of list
    savs <- c(savs[!grepl("rectified", savs)], savs[grepl("rectified", savs)])

    d <- map(
      savs,
      function(y) {
        # y = savs[1]
        clean_names(read_sav(y))
      }
    )

    # start with this structure
    # > colnames(d[[1]])
    # [1] "fi_hhrv"         "b1q2_hhrv"       "qtr_hhrv"        "visit_hhrv"     
    # [5] "b1q3_hhrv"       "state_hhrv"      "distcode_hhrv"   "nss_region_hhrv"
    # [9] "b1q5_hhrv"       "b1q6_hhrv"       "b1q11_hhrv"      "b1q12_hhrv"     
    # [13] "b1q1_hhrv"       "b1q13_hhrv"      "b1q14_hhrv"      "b1q15_hhrv"     
    # [17] "b1q9_hhrv"       "b1q17_hhrv"      "b1q18_hhrv"      "b1q19_hhrv"     
    # [21] "b3q1_hhrv"       "b3q2_hhrv"       "b3q3_hhrv"       "b3q4_hhrv"      
    # [25] "b3q5_hhrv"       "b1q16_hhrv"      "b2q2i_hhrv"      "b2q4_hhrv"      
    # [29] "nss_hhrv"        "nsc_hhrv"        "mult_hhrv"       "no_qtr_hhrv"

    # > unique(d[[1]]$fi_hhrv)
    # [1] "RVH7"

    names(d) <- gsub("\\.sav", "", basename(savs))

    xmls <- list.files(x, pattern = "\\.xml$", full.names = TRUE, recursive = TRUE)

    d2 <- read_xml(xmls)

    d2 <- as_list(d2)
    d2 <- d2$codeBook

    names(d2) <- "codeBook"

    d2 <- trim_recursive(d2)

    d2 <- normalize_lists(d2)

    d <- list(data = d, metadata = d2)

    saveRDS(d, file = fout, compress = "xz")
  }
)
