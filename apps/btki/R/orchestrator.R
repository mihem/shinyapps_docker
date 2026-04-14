# R/orchestrator.R
# Module orchestrator - Responsible for coordinating data loading and module initialization

# create_orchestrator() - Main constructor with complete API documentation
# init() - Initialize orchestrator
# init_immediate_modules() - Initialize immediate modules
# try_init_lazy_module() - Try to initialize lazy-loaded module
# handle_tab_change() - Handle tab switching
# poll_pending_modules() - Poll pending modules
# generate_status_report() - Generate status report
# create_status_reactive() - Create status reactive expression
# get_state() - Get current state
# reset() - Reset orchestrator state


library(shiny)

#' Create Module Orchestrator
#'
#' Creates a module orchestrator that coordinates data loading and module initialization.
#' The orchestrator manages the lifecycle of Shiny modules, handling dependency checking,
#' lazy initialization, and automatic module activation based on user navigation.
#'
#' @param async_loader Object. The async data loader instance for resource management.
#' @param module_specs List. Module specifications containing type, resources, init_fn, etc.
#'   Each module spec should have: type, resources, description, init_fn, and optionally
#'   tab_name, poll_ms, optional_resources, ready_fn.
#' @param progress_output_id Character or NULL. Optional output ID for progress display.
#' @param verbose Logical. Whether to print orchestrator messages. Default is FALSE.
#'
#' @return List containing orchestrator API functions:
#'   - init: Initialize orchestrator with session
#'   - init_immediate_modules: Initialize modules that load immediately
#'   - try_init_lazy_module: Attempt to initialize a lazy-loaded module
#'   - handle_tab_change: Handle user tab navigation
#'   - poll_pending_modules: Check and process pending modules
#'   - generate_status_report: Create status summary
#'   - create_status_reactive: Create reactive status expression
#'   - get_state: Get current state for debugging
#'   - reset: Reset orchestrator state
#'
#' @details
#' The orchestrator maintains internal state including:
#' - initialized_modules: List of successfully initialized modules
#' - pending_modules: Queue of modules waiting for dependencies
#' - async_loader: Reference to data loading system
#' - session: Shiny session object for reactive updates
#' - module_specs: Injected module configuration
#'
#' Dependencies are now injected as parameters instead of relying on global variables.
#' This improves testability, maintainability, and allows for dynamic configuration.
#'
#' @examples
#' module_specs <- load_module_specs()
#' orchestrator <- create_orchestrator(async_loader, module_specs, "status_output")
#' orchestrator$init(session)
#' orchestrator$init_immediate_modules()
#'
#' Create module orchestrator using dependency injection pattern to avoid global variable coupling
#'
# Create module orchestrator
create_orchestrator <- function(async_loader, module_specs, progress_output_id = NULL, verbose = FALSE) {

  # Internal state
  state <- list(
    initialized_modules = character(0),  # Initialized modules
    pending_modules = character(0),      # Modules waiting for initialization
    async_loader = async_loader,
    module_specs = module_specs,         # Injected module specifications
    session = NULL,
    progress_output_id = progress_output_id,
    verbose = verbose                    # Whether to show detailed logs
  )

  # Internal utility functions (replacing original global functions)
  get_immediate_modules <- function() {
    Filter(function(spec) spec$type == "immediate", module_specs)
  }

  get_lazy_modules <- function() {
    Filter(function(spec) spec$type == "lazy", module_specs)
  }

  get_module_by_tab <- function(tab_name) {
    for (name in names(module_specs)) {
      spec <- module_specs[[name]]
      if (!is.null(spec$tab_name) && spec$tab_name == tab_name) {
        return(list(name = name, spec = spec))
      }
    }
    NULL
  }

  is_module_ready <- function(spec, loader) {
    if (!is.null(spec$ready_fn)) {
      spec$ready_fn(loader)
    } else {
      # Default check: all required resources are loaded
      all(sapply(spec$resources, loader$is_loaded))
    }
  }

  # API functions
  orchestrator_api <- list(

    #' Initialize Orchestrator
    #'
    #' Sets up the orchestrator with the Shiny session object, enabling
    #' reactive updates and session-specific functionality.
    #'
    #' @param session Object. Shiny session object.
    #'
    #' @return NULL (called for side effects)
    #'
    #' Global variables used:
    #' - state: Internal orchestrator state object
    #'
    #' Initialize orchestrator, set session object
    #'
    # Initialize orchestrator (set session)
    init = function(session) {
      state$session <<- session
      if (state$verbose) {
        message("\n[ORCHESTRATOR] Initialized")
      }
    },

    #' Initialize Immediate Modules
    #'
    #' Initializes all modules marked for immediate loading. These are typically
    #' lightweight modules that depend on small, quickly-loaded resources and
    #' are needed for the initial UI display.
    #'
    #' @return Character vector. Names of initialized modules (invisibly).
    #'
    #' Dependencies injected:
    #' - module_specs: Module specifications (via constructor parameter)
    #'
    #' Initialize first screen modules immediately for quick display of initial interface
    #'
    # Initialize immediate modules (first screen modules)
    init_immediate_modules = function() {
      immediate_specs <- get_immediate_modules()

      for (name in names(immediate_specs)) {
        spec <- immediate_specs[[name]]
        # print(spec$description)

        tryCatch({
          # Check if resources are available
          resources <- list()
          for (res_name in spec$resources) {

            res_data <- state$async_loader$get(res_name)

            # print("我是诸葛亮")
            # print(names(res_data))
            if (is.null(res_data)) {
              stop(sprintf("Required resource '%s' not available for module '%s'", res_name, name))
            }
            resources[[res_name]] <- res_data
          }

          # Initialize module
          spec$init_fn(name, resources)
          state$initialized_modules <<- c(state$initialized_modules, name)
          if (state$verbose) {
            message(sprintf("[ORCHESTRATOR] Immediately initialize module: %s", spec$description))
          }

        }, error = function(e) {
          warning(sprintf("\n[ORCHESTRATOR] Module '%s' [Immediate initialization] initialization failed: %s", name, conditionMessage(e)))
        })
      }

      invisible(state$initialized_modules)
    },

    #' Try Initialize Lazy Module
    #'
    #' Attempts to initialize a single lazy-loaded module by checking if all
    #' its required resources are available. If dependencies are satisfied,
    #' the module is initialized immediately.
    #'
    #' @param module_name Character. Name of the module to initialize.
    #'
    #' @return Logical. TRUE if module was successfully initialized,
    #'   FALSE if dependencies are not yet ready.
    #'
    #' Dependencies injected:
    #' - module_specs: Module specifications (via constructor parameter)
    #'
    #' Try to initialize a single lazy-loaded module, check if dependencies are satisfied
    #'
    # Try to initialize a single lazy-loaded module
    try_init_lazy_module = function(module_name) {
      # print(paste0("Attempting to initialize module: ", module_name))

      if (module_name %in% state$initialized_modules) {
        # print(paste0("Module ", module_name, " already initialized"))
        return(TRUE)  # Already initialized
      }

      spec <- state$module_specs[[module_name]]

      print(glue::glue("Checking tab: {spec$tab_name}"))

      if (is.null(spec) || spec$type != "lazy") {
        return(FALSE)
      }

      # Check if ready
      if (!is_module_ready(spec, state$async_loader)) {
        return(FALSE)
      }

      tryCatch({
        # Collect required resources
        resources <- list()

        # Required resources
        for (res_name in spec$resources) {
          resources[[res_name]] <- state$async_loader$get(res_name)
        }

        # Optional resources (handle cache and fallback logic)
        if (!is.null(spec$optional_resources)) {
          for (group_name in names(spec$optional_resources)) {
            res_candidates <- spec$optional_resources[[group_name]]

            if (group_name == "cached") {
              # cached group: only one resource, try to get it directly
              for (res_name in res_candidates) {
                res_data <- state$async_loader$get(res_name)
                if (!is.null(res_data)) {
                  resources[[res_name]] <- res_data
                  print(paste0("Successfully obtained cached resource: ", res_name))
                  break  # Found cache, stop processing fallback
                }
              }
            } else if (group_name == "fallback") {
              # fallback group: all resources must be available to use
              fallback_resources <- list()
              all_fallback_available <- TRUE

              for (res_name in res_candidates) {
                res_data <- state$async_loader$get(res_name)
                if (module_name %in% c("csf_celltype_marker_heatmap", "pbmc_celltype_marker_heatmap")) {
                  print(paste0("Checking fallback resource: ", res_name))
                  print(paste0("Resource data type: ", class(res_data)))
                  if (!is.null(res_data)) {
                    print(paste0("Resource data dimensions: ", ifelse(is.null(dim(res_data)), "NULL", paste(dim(res_data), collapse = " x "))))
                  }
                }

                if (!is.null(res_data)) {
                  fallback_resources[[res_name]] <- res_data
                } else {
                  all_fallback_available <- FALSE
                  print(paste0("Fallback resource unavailable: ", res_name))
                  break  # If any fallback resource is unavailable, break
                }
              }

              # Only add to resources when all fallback resources are available
              if (all_fallback_available) {
                print("All fallback resources available, adding to resources")
                for (res_name in names(fallback_resources)) {
                  resources[[res_name]] <- fallback_resources[[res_name]]
                }
              } else {
                print("Some fallback resources unavailable, skipping fallback group")
              }
            }
          }
        }
        print("All resources collected")
        # Initialize module
        spec$init_fn(module_name, resources)
        state$initialized_modules <<- c(state$initialized_modules, module_name)

        if (state$verbose) {
          message(sprintf("\n[ORCHESTRATOR] Lazy initialize module: %s", spec$description))
        }
        return(TRUE)

      }, error = function(e) {
        warning(sprintf("\n[ORCHESTRATOR] Module '%s' [Lazy initialization] initialization failed: %s", module_name, conditionMessage(e)))
        return(FALSE)
      })
    },

    #' Handle Tab Change Event
    #'
    #' Responds to user tab navigation by attempting to initialize the
    #' corresponding module if not already loaded. This enables lazy loading
    #' of heavy modules only when users actually visit those tabs.
    #'
    #' @param tab_name Character. Name of the newly selected tab.
    #'
    #' @return NULL (called for side effects)
    #'
    #' Dependencies injected:
    #' - module_specs: Module specifications (via constructor parameter)
    #'
    #' Handle tab change event, initialize corresponding module on demand
    #'
    # Trigger module initialization based on tab switching
    handle_tab_change = function(tab_name) {
      if (is.null(tab_name)) return()

      # Find corresponding module
      module_info <- get_module_by_tab(tab_name)
      if (is.null(module_info)) {
        return()  # No corresponding module
      }

      module_name <- module_info$name
      spec <- module_info$spec

      if (module_name %in% state$initialized_modules) {
        return()  # Already initialized
      }

      # Add to pending list
      if (!module_name %in% state$pending_modules) {
        state$pending_modules <<- c(state$pending_modules, module_name)
        if (state$verbose) {
          message(sprintf("\n[ORCHESTRATOR] Module '%s' added to initialization queue", spec$description))
        }
      }

      # Try to initialize
      success <- orchestrator_api$try_init_lazy_module(module_name)
      if (success) {
        state$pending_modules <<- setdiff(state$pending_modules, module_name)
      } else {
        # Set up polling check
        if (!is.null(state$session)) {
          invalidateLater(spec$poll_ms %||% 200, state$session)
        }
      }
    },

    #' Poll Pending Modules
    #'
    #' Periodically checks if any pending modules can now be initialized
    #' based on newly available resources. This function is typically called
    #' from reactive contexts to continuously attempt lazy module initialization.
    #'
    #' @return NULL (called for side effects)
    #'
    #' Global variables used:
    #' - state: Internal orchestrator state (pending_modules, session)
    #'
    #' Poll pending modules and try to initialize
    #'
    # Poll pending modules
    poll_pending_modules = function() {
      if (length(state$pending_modules) == 0) return()

      initialized_this_round <- character(0)

      for (module_name in state$pending_modules) {
        if (orchestrator_api$try_init_lazy_module(module_name)) {
          initialized_this_round <- c(initialized_this_round, module_name)
        }
      }

      # Remove initialized modules from pending list
      state$pending_modules <<- setdiff(state$pending_modules, initialized_this_round)

      # If there are still pending modules, continue polling
      if (length(state$pending_modules) > 0 && !is.null(state$session)) {
        invalidateLater(200, state$session)
      }
    },

    #' Generate Status Report
    #'
    #' Creates a comprehensive status report showing the current state of
    #' all modules and resources. Useful for debugging and monitoring
    #' the application loading progress.
    #'
    #' @return List. Status report containing modules status, resources status,
    #'   and summary statistics.
    #'
    #' Dependencies injected:
    #' - module_specs: Module specifications (via constructor parameter)
    #'
    #' Generate system status report for monitoring loading progress
    #'
    # Generate loading status report
    generate_status_report = function() {
      loader_status <- state$async_loader$get_status()

      list(
        modules = list(
          initialized = state$initialized_modules,
          pending = state$pending_modules,
          total_modules = length(state$module_specs)
        ),
        resources = loader_status,
        summary = sprintf(
          "Modules: %d/%d initialized, %d pending | Resources: %d loaded, %d loading, %d queued, %d failed",
          length(state$initialized_modules),
          length(state$module_specs),
          length(state$pending_modules),
          loader_status$total_completed,
          loader_status$total_active,
          loader_status$total_queued,
          loader_status$total_failed
        )
      )
    },

    #' Create Status Reactive
    #'
    #' Creates a reactive expression that automatically updates when the
    #' system status changes. This reactive can be used in Shiny outputs
    #' to display real-time loading progress.
    #'
    #' @return Reactive expression returning the current status report.
    #'
    #' Global variables used:
    #' - state: Internal orchestrator state (async_loader)
    #'
    #' Create reactive expression for status monitoring
    #'
    # Create reactive expression for status display
    create_status_reactive = function() {
      reactive({
        # Force dependency on loader status changes
        state$async_loader$get_status()
        orchestrator_api$generate_status_report()
      })
    },

    #' Get State
    #'
    #' Returns the current internal state of the orchestrator for debugging
    #' and inspection purposes. Provides insight into which modules are
    #' initialized, pending, and the overall loader status.
    #'
    #' @return List. Current orchestrator state including initialized modules,
    #'   pending modules, and loader status.
    #'
    #' Global variables used:
    #' - state: Internal orchestrator state
    #'
    #' Get current state for debugging
    #'
    # Get current state (for debugging)
    get_state = function() {
      list(
        initialized_modules = state$initialized_modules,
        pending_modules = state$pending_modules,
        loader_status = state$async_loader$get_status()
      )
    },

    #' Reset Orchestrator
    #'
    #' Resets the orchestrator state by clearing all initialized and pending
    #' modules. Useful for testing or reinitializing the system.
    #'
    #' @return NULL (called for side effects)
    #'
    #' Global variables used:
    #' - state: Internal orchestrator state
    #'
    #' Reset orchestrator state
    #'
    # Reset orchestrator state
    reset = function() {
      state$initialized_modules <<- character(0)
      state$pending_modules <<- character(0)
      if (state$verbose) {
        message("\n[ORCHESTRATOR] State reset")
      }
    },

    # ========== Optional: Expose utility functions ==========
    # These functions are usually not needed for external access, but provided for advanced users

    #' Get Immediate Modules
    #'
    #' Returns all modules marked for immediate loading.
    #'
    #' @return List. Immediate modules specifications.
    #'
    #' Get all immediately loaded module specifications
    #'
    .get_immediate_modules = get_immediate_modules,

    #' Get Lazy Modules
    #'
    #' Returns all modules marked for lazy loading.
    #'
    #' @return List. Lazy modules specifications.
    #'
    #' Get all lazy-loaded module specifications
    #'
    .get_lazy_modules = get_lazy_modules,

    #' Get Module by Tab
    #'
    #' Finds module configuration by tab name.
    #'
    #' @param tab_name Character. Tab name to search for.
    #' @return List or NULL. Module information (name and spec).
    #'
    #' Find module by tab name
    #'
    .get_module_by_tab = get_module_by_tab,

    #' Check Module Readiness
    #'
    #' Checks if a module's dependencies are satisfied.
    #'
    #' @param spec List. Module specification.
    #' @param loader Object. Async loader instance.
    #' @return Logical. TRUE if module is ready for initialization.
    #'
    #' Check if module is ready
    #'
    .is_module_ready = function(spec, loader) {
      is_module_ready(spec, loader)
    }
  )

  # Explicitly return API object
  return(orchestrator_api)
}

#' Setup Orchestrator in Shiny Server
#'
#' Convenience function for setting up the orchestrator in a Shiny server function.
#' This function creates an orchestrator, initializes it with the session,
#' sets up reactive listeners for tab changes, and configures automatic polling.
#'
#' @param session Object. Shiny session object.
#' @param async_loader Object. Async loader instance created with create_async_loader().
#' @param module_specs List. Module specifications containing module configurations.
#' @param progress_output_id Character. Output ID for displaying loading progress.
#'   If NULL, no progress output will be created.
#' @param verbose Logical. Whether to show orchestrator messages. Default is FALSE.
#'
#' @return Object. Configured orchestrator instance.
#'
#' @details
#' This function automatically sets up:
#' - Tab change listeners (observeEvent for main_menu input)
#' - Periodic polling every 500ms to check module status
#' - Optional progress output display
#'
#' @examples
#' \dontrun{
#' # In your Shiny server function:
#' module_specs <- load_module_specs()
#' orchestrator <- setup_orchestrator(session, async_loader, module_specs, "loading_status")
#' }
#'
#' Convenience function: quickly set up orchestrator in server using dependency injection pattern
#'
# Convenience function: set up orchestrator in server
setup_orchestrator <- function(session, async_loader, module_specs, progress_output_id = "loading_status", verbose = FALSE) {
  orchestrator <- create_orchestrator(async_loader, module_specs, progress_output_id, verbose)
  orchestrator$init(session)

  # Set up tab listener
  observeEvent(session$input$main_menu, {
    orchestrator$handle_tab_change(session$input$main_menu)
    orchestrator$poll_pending_modules()
  }, ignoreNULL = TRUE)

  # Regular polling (ensure no status changes are missed)
  observe({
    invalidateLater(500, session)
    orchestrator$poll_pending_modules()
  })

  # Status display (if output ID is specified)
  if (!is.null(progress_output_id)) {
    session$output[[progress_output_id]] <- renderText({
      report <- orchestrator$generate_status_report()
      report$summary
    })
  }

  return(orchestrator)
}