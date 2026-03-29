# create h5 expression for cerebroAppLite
# https://github.com/mihem/cerebroAppLite/blob/master/vignettes/create_expression_matrix_in_h5_format.Rmd
suppressPackageStartupMessages({
    library(Matrix)
    library(HDF5Array)
})

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 1) {
    stop(
        "Use: Rscript setup_cerebro_app.R <app_directory>"
    )
}
app_directory <- args[1]

crb_input <- file.path(app_directory, "extdata", "v1.4", "sc_merge_cerebro.crb")
crb_output <- file.path(
    app_directory,
    "extdata",
    "v1.4",
    "sc_merge_cerebro_h5.crb"
)
h5_expression <- file.path(
    app_directory,
    "extdata",
    "v1.4",
    "sc_merge_cerebro.h5"
)

message("Reading crb file.")
crb <- readRDS(crb_input)

message("Writing h5 file.")
writeTENxMatrix(
    Matrix::t(crb$expression),
    h5_expression,
    group = "expression"
)

message("h5 file created.")

expression_matrix_h5 <- TENxMatrix(h5_expression, group = "expression")

crb$expression <- NULL
saveRDS(crb, crb_output)

message("crb input file: ", file.info(crb_input)$size / 1e6, " MB")
message("crb output file: ", file.info(crb_output)$size / 1e6, " MB")
message("h5 file: ", file.info(h5_expression)$size / 1e6, " MB")

message(
    "Successfully added h5 file and removed expression matrix from .crb object (_h5.crb file)."
)

