# setup CerebroApp
# this  creates cerebroApp or cerebroAppLite and convert crb to h5 to increase speed
library(cerebroApp)
library(Matrix)
library(HDF5Array)

app_directory <- "cerebro_uveitis"

dir.create(app_directory)
dir.create(file.path(app_directory, "shiny"))

file.copy(
  system.file("extdata", package = "cerebroAppLite"),
  app_directory,
  recursive = TRUE
)

# unlink(
#   c(glue::glue("{app_directory}/extdata/v1.0"),
#     glue::glue("{app_directory}/extdata/v1.1"),
#     glue::glue("{app_directory}/extdata/v1.2")),
#   recursive = TRUE
# )

file.copy(
  system.file("shiny", "v1.4", package = "cerebroAppLite"),
  # system.file("shiny", "v1.4", package = "cerebroApp"),
  file.path(app_directory, "shiny"),
  recursive = TRUE,
  overwrite = TRUE
)

crb_input <- file.path(app_directory, "extdata", "v1.4", "sc_merge_cerebro.crb")
crb_output <- file.path(app_directory, "extdata", "v1.4", "sc_merge_cerebro_h5.crb")
h5_expression <- file.path(app_directory, "extdata", "v1.4", "sc_merge_cerebro.h5")


crb <- readRDS(crb_input)

writeTENxMatrix(
  Matrix::t(crb$expression),
  h5_expression,
  group = "expression"
)

expression_matrix_h5 <- TENxMatrix(h5_expression, group="expression")

crb$expression <- NULL
saveRDS(crb, crb_output)
