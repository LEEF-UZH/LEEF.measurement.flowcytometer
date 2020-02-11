#' Preprocessor flowcytometer data
#'
#' Convert all \code{.fxs} files in \code{flowcytometrie} folder to \code{data.frame} and save as \code{.rds} file.
#'
#' This function is extracting data to be added to the database (and therefore make accessible for further analysis and forecasting)
#' from \code{.fcs} files.
#'
#' @param input directory from which to read the data
#' @param output directory to which to write the data
#'
#' @return invisibly \code{TRUE} when completed successful
#'
#' @importFrom flowCore read.flowSet pData phenoData exprs logTransform truncateTransform transform rectangleGate
#'
#' @export
#'
extractor_flowcytometer <- function(
  input,
  output
) {
  message("\n########################################################\n")
  message("Extracting flowcytometer...\n")

# Based on flowcyt_1_c6_to_RData.R ----------------------------------------
  # Converting the Flowcytometer Output of bacterial abundances into a usable data frame
  # David Inauen, 19.06.2017


# Get fcs file names ------------------------------------------------------

  fcs_path <- file.path( input, "flowcytometer" )
  fcs_files <- list.files(
    path = fcs_path,
    pattern = "*.fcs",
    recursive = TRUE,
    full.names = TRUE
  )

  if (length(fcs_files) == 0) {
    message("nothing to extract\n")
    message("\n########################################################\n")
    return(invisible(FALSE))
  }
# check file sizes and delete empty wells ---------------------------------

  fcs_files <- sapply(
    fcs_files,
    function(fn) {
      result <-  TRUE
      if ( file.info(fn)[["size"]] <= 3000 ) {
        file.remove(fn)
        result <- NULL
      }
      invisible(fn)
    }
  )
  names(fcs_files) <- NULL
  fcs_files <- fcs_files[!is.null(fcs_files)]

# read flowSet automatically ----------------------------------------------
  fsa <- flowCore::read.flowSet(
    path = fcs_path,
    transformation = FALSE,
    phenoData = list(
      filename = "#SAMPLE",
      sample = "$SMNO",
      date = "$DATE",
      volume = "$VOL",
      proj = "$PROJ"
    )
  )

# CREATE FLOW DATA FRAME AND FILL WITH UNGATED COUNT ----------------------

  flow.data <- flowCore::pData( flowCore::phenoData(fsa) )

  # find the number of events (equals the number of rows)
  num <- sapply(
    1:length(fsa),
    function(i) {
      num <- dim( flowCore::exprs(fsa[[i]]) )[1]
    }
  )
  flow.data <- cbind(
    flow.data,
    "total.counts" = num
  )

  # Extract the volume of medium sampled
  flow.data[["volume"]] <- as.numeric(
    as.character(
      flowCore::phenoData(fsa)[["volume"]]
    )
  )

  # calculate events recorded per ml
  flow.data[["tot_density_perml"]] <- flow.data[["total.counts"]] * 1000000 / flow.data[["volume"]] * 10
  flow.data[["specname"]] <- paste(
    flow.data[["filename"]],
    flow.data[["proj"]],
    sep = "_"
  )

  # standardize naming
  flow.data <- flow.data[, c("filename","sample","date","volume","total.counts","tot_density_perml","specname")]

  rownames(flow.data) <- NULL


  # define transformation
  # logTrans <- logTransform( transformationId="log10-transformation", logbase = 10, r = 1, d = 1 )
  # aTrans <- truncateTransform( "truncate at 1", a = 1 )

  # exclude values < 1
  fsa <- transform(
    fsa,
    `FL1-H` = flowCore::truncateTransform( "truncate at 1", a = 1 )(`FL1-H`),
    `FL3-H` = flowCore::truncateTransform( "truncate at 1", a = 1 )(`FL3-H`),
    `FSC-A` = flowCore::truncateTransform( "truncate at 1", a = 1 )(`FSC-A`),
    `SSC-A` = flowCore::truncateTransform( "truncate at 1", a = 1 )(`SSC-A`),
    `Width` = flowCore::truncateTransform( "truncate at 1", a = 1 )(`Width`)
  )
  # log transform
  fsa <- transform(
    fsa,
    `FL1-H` = flowCore::logTransform( transformationId = "log10-transformation", logbase = 10, r = 1, d = 1 )(`FL1-H`),
    `FL3-H` = flowCore::logTransform( transformationId = "log10-transformation", logbase = 10, r = 1, d = 1 )(`FL3-H`),
    `FSC-A` = flowCore::logTransform( transformationId = "log10-transformation", logbase = 10, r = 1, d = 1 )(`FSC-A`),
    `SSC-A` = flowCore::logTransform( transformationId = "log10-transformation", logbase = 10, r = 1, d = 1 )(`SSC-A`),
    `Width` = flowCore::logTransform( transformationId = "log10-transformation", logbase = 10, r = 1, d = 1 )(`Width`)
  )

# Apply the gating --------------------------------------------------------

  rectGate <- flowCore::rectangleGate(
    filterId = "Global",
    "FL1-H" = c(2.9,7),
    "FL3-H" = c(1,7)
  )

  # #----- HAVING A LOOK AT THE GATING -----#
  #
  #
  # i=9
  # flowViz::xyplot(`FL3-H` ~ `FL1-H`, data = fsa[[i]], filter = rectGate)
  # fsa[[i]]
  #
  # i=199
  # flowViz::xyplot(`FL3-H` ~ `FL1-H`, data = fsa[[i]], filter = rectGate)
  # fsa[[i]]
  #
  # i=192
  # flowViz::xyplot(`FL3-H` ~ `FL1-H`, data = fsa[[i]], filter = rectGate)
  # fsa[[i]]
  #
  # i=200
  # flowViz::xyplot(`FL3-H` ~ `FL1-H`, data = fsa[[i]], filter = rectGate)
  # fsa[[i]]
  #
  # i=203
  # flowViz::xyplot(`FL3-H` ~ `FL1-H`, data = fsa[[i]], filter = rectGate)
  # fsa[[i]]


# ABUNDANCE DYNAMICS ------------------------------------------------------

  # applying filter to whole flowSet
  result <- flowCore::filter(fsa, rectGate)

  # extract absolute counts
  l <- lapply(result, flowCore::summary)
  # counts <- plyr::ldply(
  #   lapply(
  #     l,
  #     function(i) {
  #       i$true
  #     }
  #   )
  # )

  counts <- sapply(
    l,
    function(i) {
      i$true
    }
  )
  flow.data[["gated_counts"]] <- counts
  flow.data[["gated_density_perml"]] <- flow.data[["gated_counts"]] * 1000000/flow.data[["volume"]] * 10
  flow.data$sample_letter <- substr(
    x = flow.data$sample,
    start = 1,
    stop = 1
  )
  flow.data[["sample_number"]] <- as.numeric(
    substr(
      x = flow.data[["sample"]],
      start = 2,
      stop = 3
    )
  )
  flow.data[["date"]] <- format(
    as.Date(
      flow.data$date,
      "%d-%b-%Y"
    ),
    "%Y-%m-%d"
  )
  flow.data <- flow.data[ order(
    flow.data$date,
    flow.data$sample_letter,
    flow.data$sample_number
  ),]


# Based on flowcyt_2_RData_to_final_data.R --------------------------------

  ## Here some metadata was added - maybe later.


# SAVE --------------------------------------------------------------------

  add_path <- file.path( output, "flowcytometer" )
  dir.create( add_path, recursive = TRUE )
  saveRDS(
    object = flow.data,
    file = file.path(add_path, "flowcytometer.rds")
  )

# Finalize ----------------------------------------------------------------

  message("done\n")
  message("\n########################################################\n")

  invisible(TRUE)
}