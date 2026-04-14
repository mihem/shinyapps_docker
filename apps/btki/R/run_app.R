# R/run_app.R
# Application startup function

source("ui/ui_main.R")
source("server/server_main.R")

#' Run Shiny Application
#'
#' @param port Port number, auto-select by default
#' @param host Host address, default 127.0.0.1
#' @param debug Whether to enable debug mode
#' @param verbose Whether to enable verbose logging mode (async loader and orchestrator)
#' @param ... Other parameters passed to shinyApp
#'
run_app <- function(port = NULL, host = "127.0.0.1", debug = FALSE, verbose = FALSE, ...) {

  # # Set debug options
  # if (debug) {
  #   options(
  #     shiny.debug = TRUE,
  #     shiny.error = browser,
  #     shiny.trace = TRUE
  #   )
  # }

  # Set verbose mode (passed to app_server via global options)
  options(app.verbose = verbose)

  # Check dependency files
  required_files <- c(
    "R/data_registry.R",
    "R/async_loader.R",
    "R/module_specs.R",
    "R/orchestrator.R",
    "modules/pbmc_modules.R",
    "ui/ui_sidebar.R",
    "ui/ui_body.R"
  )

  missing_files <- required_files[!file.exists(required_files)]
  if (length(missing_files) > 0) {
    stop("Missing required files:\n", paste(missing_files, collapse = "\n"))
  }

  # Print startup information
  cat("=== Multi-omics Analysis Dashboard ===\n")
  cat("Start time:", format(Sys.time()), "\n")
  cat("Working directory:", getwd(), "\n")
  cat("Debug mode:", if(debug) "Enabled" else "Disabled", "\n")
  cat("=====================================\n")

  # 1) Build base UI first
  base_ui <- app_ui()

  # 2) Wrap UI with secure_app (login interface + optional built-in user management backend)
  protected_ui <- shinymanager::secure_app(
    ui = base_ui,
    enable_admin = TRUE,
    language     = "zh-CN",
    tags_bottom = tags$div(
      class = "login-footer",
      HTML(
        sprintf("&copy; Wang Xue Song from MzH Lab （%s） · All rights reserved", format(Sys.Date(), "%Y"))
      )
    )
  )

  # Create and launch application
  app <- shinyApp(
    ui = protected_ui,
    server = app_server,
    options = list(
      port = port,
      host = host,
      ...
    )
  )

  return(app)
}

#' Run application in production environment
run_app_production <- function(port = 3838, host = "0.0.0.0") {
  run_app(port = port, host = host, debug = FALSE, verbose = FALSE)
}

#' Run application in development environment
run_app_dev <- function(port = NULL, host = "127.0.0.1") {
  run_app(port = port, host = host, debug = FALSE, verbose = TRUE)
}

#' Run application in development environment (verbose logging)
run_app_dev_verbose <- function(port = NULL, host = "127.0.0.1") {
  run_app(port = port, host = host, debug = TRUE, verbose = TRUE)
}

#' Run application in development environment (skip authentication)
run_app_dev_no_auth <- function(port = NULL, host = "127.0.0.1") {

  options(app.verbose = TRUE)

  # Use original UI directly, skip authentication
  app <- shinyApp(
    ui = app_ui(),
    server = app_server,
    options = list(
      port = port,
      host = host
    )
  )

  return(app)
}
