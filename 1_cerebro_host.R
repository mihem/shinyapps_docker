# setup CerebroApp
# this  creates cerebroApp or cerebroAppLite
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1) stop("Usage: Rscript setup_cerebro_app.R <app_directory>")
app_directory <- args[1]

dir.create(app_directory)
dir.create(file.path(app_directory, "shiny"))

message("Directory ", app_directory, " created")

file.copy(
  system.file("extdata", package = "cerebroAppLite"),
  app_directory,
  recursive = TRUE
)

file.copy(
  system.file("shiny", "v1.4", package = "cerebroAppLite"),
  file.path(app_directory, "shiny"),
  recursive = TRUE,
  overwrite = TRUE
)

message("Cerebroapp created.")

