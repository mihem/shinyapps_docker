# R/app_server.R
# Refactored main server logic - Clear layered architecture

# Dependencies
library(shiny)
library(future)
library(promises)
library(shinyjs)
library(qs)
library(shinymanager)


# Disable Shiny WebSocket debug messages
options(shiny.trace = FALSE)
options(shiny.reactlog = FALSE)
options(shiny.error = function() {})
options(shiny.error = traceback)
options(shiny.fullstacktrace = FALSE)
options(shiny.stacktrace = FALSE)

# Load global configuration (compatible with old modules)
source("utils/global.R")

# Load refactored modules
source("R/data_registry.R")
source("R/async_loader.R")
source("R/module_specs.R")
source("R/orchestrator.R")

# Load business modules
source("modules/qc_plots.R")

source("modules/pbmc_modules.R")

source("modules/plot_controls.R")
source("modules/pbmc_modules_adt.R")
source("modules/sample_summary.R")
source("modules/pbmc_umap.R")
source("modules/featureplot.R")
source("modules/pbmc_marker_heatmap.R")
source("modules/pbmc_cell_composition_boxplot.R")
source("modules/pbmc_pseudo_bulk_per_celltype.R")
source("modules/pbmc_adt_rna_cell_type_corr_viz.R")

source("modules/csf_featureplot.R")
source("modules/csf_marker_heatmap.R")

source("modules/wilcoxon.R")
source("modules/propeller.R")
source("modules/paired_ttest.R")
source("modules/de_analysis.R")

source("modules/adt_gene_pair.R")

# Main server function
app_server <- function(input, output, session) {

  shinyjs::useShinyjs()

  # === 0. User Authentication (must be first with strong validation) ===
  cred_path <- normalizePath("credentials.sqlite", mustWork = FALSE)
  if (!file.exists(cred_path) || is.na(file.info(cred_path)$size) || file.info(cred_path)$size < 100) {
    stop("credentials.sqlite does not exist or file is abnormal. Please run init_db.R first to generate credential database. Current search path: ", cred_path)
  }

  # passphrase <- Sys.getenv("SM_PASSPHRASE")
  passphrase <- "123123"
  if (!nzchar(passphrase)) {
    stop("Environment variable SM_PASSPHRASE is not set. Please configure the same strong passphrase as when creating the database in the deployment environment.")
  }

  res_auth <- tryCatch({
    shinymanager::secure_server(
      check_credentials = shinymanager::check_credentials(
        cred_path,
        passphrase = passphrase
      )
    )
  }, error = function(e) {
    stop("Unable to decrypt credentials.sqlite. Most common cause is passphrase mismatch (DB creation vs runtime).",
         "\nPlease ensure SM_PASSPHRASE is the same as when running init_db.R.",
         "\nOriginal error: ", conditionMessage(e))
  })

  # ========================================================
  # Key modification: Move async system initialization to after successful login
  # ========================================================
  observeEvent(res_auth$user, {
    req(res_auth$user)  # Ensure user is logged in

    # Display username and logout (can ignore if you already have this)
    output$header_username <- renderText({
      paste0(res_auth$user, if (isTRUE(res_auth$admin)) " (Admin)" else "")
    })
    observeEvent(input$btn_logout, ignoreInit = TRUE, {
      shinymanager::logout(session = session)
    })

    # Load timeout handler
    source("server/timeout_handler.R", local = TRUE)
    timeout_handler(input, output, session)

    # Get verbose setting from global options
    verbose_mode <- getOption("app.verbose", FALSE)

    # =============== 1. Initialize async system ===============
    message("\n[APP SERVER] Initializing async loading system...")
    message("[APP SERVER] Available CPU cores: ", parallel::detectCores(logical = TRUE))
    message("[APP SERVER] Physical CPU cores: ", parallel::detectCores(logical = FALSE))
    message("[APP SERVER] Custom concurrent cores: ", getOption("future.custom.cores", 4))
    # Set future plan
    if (.Platform$OS.type == "unix") {
      # future::plan(future::multicore, workers = max(1, parallel::detectCores() - 2))
      future::plan(future::multicore, workers = max(1, 5))
    } else {
      future::plan(future::multisession, workers = max(1, 5))
    }

    # Create async loader (based on verbose mode setting)
    async_loader <- create_default_loader(verbose = verbose_mode, session = session, async_loader_started_id = "async_loader_started")

    # Validate data resources
    validate_data_resources()

    # =============== 2. Synchronously load first-screen blocking resources ===============
    message(
      "\n",
      red_bold("[APP SERVER] "),
      "Synchronously loading first-screen resources..."
    )

    blocking_resources <- get_blocking_resources()
    for (name in names(blocking_resources)) {
      res <- blocking_resources[[name]]

      tryCatch({
        start_time <- Sys.time()
        data <- res$load_fn(res$path)
        load_time <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

        # Store directly into async loader's result environment
        assign(name, data, envir = environment(async_loader$get)$results_env)
        message(
          green_bold("[SYNC LOADED] "),
          pad_label(res$description, 30),
          blue$italic(sprintf(" (%.2fs", load_time)),
          magenta(sprintf(", %.1fMB)", as.numeric(object.size(data)) / 1024^2))
        )

      }, error = function(e) {
        warning(sprintf("[SYNC ERROR  ] %s: %s", name, conditionMessage(e)))
      })
    }
    # Before testing
    # =============== 3. (Deferred) Start async resource loading ===============
    # Previously submitted immediately here, now changed to execute after first flush
    session$onFlushed(function() {
      message(
        red_bold("\n[APP SERVER] "),
        "(Deferred) Starting async resource loading..."
      )
      async_resources <- get_async_resources()
      async_loader$submit_batch(async_resources, session = session)
    }, once = TRUE)

    # Do not have any other heavy computation before flush

    # =============== 4. Initialize orchestrator ===============
    # Load module specs (dependency injection pattern)
    module_specs <- load_module_specs()

    orchestrator <- setup_orchestrator(session, async_loader, module_specs, "loading_status", verbose = verbose_mode)

    # =============== 5. Immediately initialize first-screen modules ===============
    message("[APP SERVER] Initializing first-screen modules...")
    tryCatch({
      orchestrator$init_immediate_modules()
      message("[APP SERVER] First-screen module initialization completed")
    }, error = function(e) {
      message("[APP SERVER] First-screen module initialization failed: ", conditionMessage(e))
      print(traceback())
      print(e)
    })

    showNotification(id = "async_loader_started", "Async loader started.", type = "error", duration = 88, session = session)

    app_start_time <- Sys.time()
    session$onFlushed(function() {
      message(sprintf("\n[TIMING] First UI flush: %.2fs\n", as.numeric(difftime(Sys.time(), app_start_time, units="secs"))))
    }, once = TRUE)

    # =============== 6. Dataset switching logic ===============
    values <- reactiveValues(current_dataset = NULL)

    observeEvent(input$main_menu, {
      # Check if input is valid
      if (is.null(input$main_menu) || length(input$main_menu) == 0 || input$main_menu == "") {
        return()
      }

      if (grepl("^pbmc", input$main_menu)) {
        values$current_dataset <- "PBMC"
      } else if (grepl("^csf", input$main_menu)) {
        values$current_dataset <- "CSF"
      }

      # Toggle control panel display
      shinyjs::toggle("pbmc_controls", condition = values$current_dataset == "PBMC")
      shinyjs::toggle("csf_controls", condition = values$current_dataset == "CSF")
    })

    # =============== 7. Status output ===============

    # Loading status
    output$loading_status <- renderText({
      report <- orchestrator$generate_status_report()
      report$summary
    })

    # Session info
    output$session_info <- renderText({
      if (isTRUE(getOption("shiny.debug", FALSE))) {
        list(
          orchestrator_state = orchestrator$get_state(),
          loader_stats = async_loader$get_stats()
        )
      }
    })

    # =============== 8. Error handling and cleanup ===============

    # Clean up resources when session ends
    session$onSessionEnded(function() {
      message("[APP SERVER] Session ended, cleaning up resources...")
      # Can add cleanup logic here, such as canceling unfinished future tasks
    })

    # Global error handling
    options(shiny.error = function() {
      message("[APP SERVER] Caught Shiny error")
      # Can add error reporting logic
    })

    message("[APP SERVER] Initialization completed")
  }, once = TRUE)  # Key: execute only once
}

# Export function
get_app_server <- function() {
  app_server
}
