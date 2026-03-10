#==============================================================================
# Cerebro Shiny App - Static Login Page Optimized Version
# Displays static login form immediately when user opens the page
# Shiny loads in the background; seamless transition to main app after login
#==============================================================================

library(dplyr)
library(DT)
library(plotly)
library(shiny)
library(shinydashboard)
library(shinyWidgets)



# Define result save directory
cerebro_root <- "."

## Load configuration
if (file.exists("cerebro_config.rds")) {
  Cerebro.options <<- readRDS("cerebro_config.rds")
} else {
  stop("cerebro_config.rds not found!")
}

# Backward compatibility: if colors option exists, set as global variable
if (!is.null(Cerebro.options$colors)) {
  colors <- Cerebro.options$colors
}

shiny_options <- list(
  maxRequestSize = 10000 * 1024^2,
  port = 3838,
  host = "127.0.0.1",
  launch.browser = TRUE,
  quiet = FALSE,
  display.mode = "normal"
)

## Expose data directory for spatial images
shiny::addResourcePath("data", file.path(cerebro_root, "data"))

## Load server and UI functions
source(file.path(cerebro_root, "shiny/shiny_UI.R"))
source(file.path(cerebro_root, "shiny/shiny_server.R"))

# Authentication setup
library(shinymanager)

credentials_path <- file.path(cerebro_root, "credentials.sqlite")
auth_passphrase <- "123123"

# Check if credentials database exists
if (!file.exists(credentials_path)) {
  stop("Credentials database not found: ", credentials_path)
}

# Initialize credentials check
check_credentials <- shinymanager::check_credentials(
  credentials_path,
  passphrase = auth_passphrase
)

## Start Shiny App
# Wrap UI with secure_app
secure_ui <- shinymanager::secure_app(ui)
shiny::shinyApp(
  ui = secure_ui,
  server = function(input, output, session) {
  res_auth <- shinymanager::secure_server(check_credentials = check_credentials)
  server(input, output, session)
},
  options = shiny_options
)
