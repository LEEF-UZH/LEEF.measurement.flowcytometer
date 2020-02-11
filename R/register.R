#' Register the processing of flowcytometer data in the LEEF.Data package
#'
#' @return invisibly \code{TRUE} when completed successful
#'

#' @export
#'
register <- function() {
  if (is.null(system.file(package = "LEEF.Data"))) {
    stop("This function requres the package to be installed!")
  }

  LEEF.Data::add_pre_processor( pre_processor_flowcytometer )
  LEEF.Data::add_extractor( extractor_flowcytometer)

  invisible(TRUE)
}
