# ==========================
# Sample Summary Module
# ==========================
#
# Features:
# - Provides interactive viewing interface for sample metadata
# - Supports three data types: Background+Cell, Cell Raw, Cell Filtered
# - Includes sample navigation and data download functions
#
# Cache Mechanism:
# - Uses environment cache to store accessed sample data, avoiding redundant calculations
# - Cache key format: "sample_ID_data_type" (e.g.: PBMC_1002_Post_meta_all)
# - When users switch samples/tabs, prioritize cached data for improved response speed
# - Automatically cleans cache at session end to prevent memory leaks
# ==========================

# Module-level cache environment
.sample_summary_cache <- new.env(parent = emptyenv())

sample_summary_UI <- function(id) {
  ns <- NS(id)
  tagList(
    # Include Tabulator library (v5.5.2)
    tags$head(
      tags$script(src = "https://unpkg.com/tabulator-tables@5.5.2/dist/js/tabulator.min.js"),
      tags$link(rel = "stylesheet", href = "https://unpkg.com/tabulator-tables@5.5.2/dist/css/tabulator.min.css")
    ),
    fluidRow(
      column(
        width = 3,
        box(
          title = "Sample Selection",
          status = "primary",
          solidHeader = TRUE,
          width = NULL,

          selectInput(
            ns("sample_select"),
            label = "Select Sample",
            choices = NULL,
            selected = NULL
          ),
          div(
            style = "text-align: center; margin-top: 15px; margin-bottom: 15px;",
            actionButton(
              ns("prev_sample"),
              "Previous",
              icon = icon("chevron-left"),
              style = "width: 120px; margin-right: 10px;",
              class = "btn-outline-primary"
            ),
            actionButton(
              ns("next_sample"),
              "Next",
              icon = icon("chevron-right"),
              style = "width: 120px;",
              class = "btn-outline-primary"
            )
          ),
          div(
            style = "margin-top: 20px;",
            h5("Download Data", style = "text-align: center; margin-bottom: 15px; color: #495057;"),
            div(
              style = "text-align: center;",
              # Conditionally display Background+Cell download button
              conditionalPanel(
                condition = "output.show_metadata_controls",
                ns = ns,
                downloadButton(
                  ns("download_meta"),
                  "Background+Cell",
                  icon = icon("download"),
                  style = "width: 150px; margin-bottom: 8px;",
                  class = "btn-success"
                ),
                br()
              ),
              downloadButton(
                ns("download_cell"),
                "Cell Raw",
                icon = icon("download"),
                style = "width: 150px; margin-bottom: 8px;",
                class = "btn-info"
              ),
              br(),
              downloadButton(
                ns("download_cell_f"),
                "Cell Filtered",
                icon = icon("download"),
                style = "width: 150px;",
                class = "btn-warning"
              )
            )
          )
        )
      ),
      column(
        width = 9,
        box(
          status = "primary", solidHeader = TRUE, width = NULL,
          div(id = "placeholder", uiOutput(ns("d3")))
        )
      )
    )
  )
}

sample_summary_Server <- function(
  id,
  metadata_cell,
  metadata_cell_filtered,
  metadata = NULL,
  cache_enabled = FALSE
) {
  moduleServer(id, function(input, output, session) {

    ns <- session$ns

    # Check if metadata exists
    has_metadata <- !is.null(metadata)

    # Get sample list - determined based on available data source
    sample_names <- names(metadata_cell)
    req(length(sample_names) > 0)

    # Initialize sample selection
    updateSelectInput(session, "sample_select", choices = sample_names, selected = sample_names[1])

    # Control whether to display metadata-related controls
    output$show_metadata_controls <- reactive({ has_metadata })
    outputOptions(output, "show_metadata_controls", suspendWhenHidden = FALSE)

    # Currently selected sample
    current_sample <- reactive({
      req(input$sample_select)
      input$sample_select  # Return currently selected sample
    })

    # Navigation buttons
    observeEvent(input$prev_sample, {
      req(current_sample())  # Use current_sample()
      current_idx <- which(sample_names == current_sample())
      if (length(current_idx) > 0 && current_idx > 1) {
        updateSelectInput(session, "sample_select", selected = sample_names[current_idx - 1])
      }
    })

    observeEvent(input$next_sample, {
      req(current_sample())  # Use current_sample()
      current_idx <- which(sample_names == current_sample())
      if (length(current_idx) > 0 && current_idx < length(sample_names)) {
        updateSelectInput(session, "sample_select", selected = sample_names[current_idx + 1])
      }
    })

    # Local data retrieval (cache priority)
    get_sample_data_base <- function(sample_id, data_type) {
      switch(data_type,
        "meta_all"           = if (has_metadata) metadata[[sample_id]] else NULL,
        "meta_cell"          = metadata_cell[[sample_id]],
        "meta_cell_filtered" = metadata_cell_filtered[[sample_id]]
      )
    }

    get_sample_data <- if (cache_enabled) {
      function(sample_id, data_type) {
        if (data_type == "meta_all" && !has_metadata) return(NULL)
        cache_key <- paste0(sample_id, "_", data_type)
        if (exists(cache_key, envir = .sample_summary_cache)) {
          return(get(cache_key, envir = .sample_summary_cache))
        }
        result <- get_sample_data_base(sample_id, data_type)
        assign(cache_key, result, envir = .sample_summary_cache)
        result
      }
    } else {
      get_sample_data_base
    }

    output$download_meta <- downloadHandler(
      filename = function() {
        paste0("meta_cell_and_background_", current_sample(), ".csv")
      },
      content = function(file) {
        data <- metadata
        if (!is.null(data)) {
          data.table::fwrite(data, file)
        }
      }
    )

    output$download_cell <- downloadHandler(
      filename = function() {
        paste0("meta_cell_raw_", current_sample(), ".csv")
      },
      content = function(file) {
        data <- metadata_cell
        if (!is.null(data)) {
          data.table::fwrite(data, file)
        }
      }
    )

    output$download_cell_f <- downloadHandler(
      filename = function() {
        paste0("meta_cell_filtered_", current_sample(), ".csv")
      },
      content = function(file) {
        data <- metadata_cell_filtered
        if (!is.null(data)) {
          data.table::fwrite(data, file)
        }
      }
    )

    # Dynamically generate tab panels
    output$d3 <- renderUI({
      tabs <- list()

      # Only add first tab when metadata exists
      if (has_metadata) {
        tabs[[1]] <- tabPanel(
          "Metadata (Background + Cell)",
            value = "meta_all",
            div(id = ns("meta_all_div"), uiOutput(ns("meta_all_container")))
          )
      }

      # Add other two tab panels
      tabs <- append(tabs, list(
        tabPanel(
          "Metadata Cell",
          value = "meta_cell",
          # div(id = ns("meta_cell_container"), style = "height: 70vh;")
          div(id = ns("meta_cell_div"), uiOutput(ns("meta_cell_container")))
        ),
        tabPanel(
          "Metadata Cell Filtered",
          value = "meta_cell_filtered",
          # div(id = ns("meta_cell_filtered_container"), style = "height: 70vh;")
          div(id = ns("meta_cell_filtered_div"), uiOutput(ns("meta_cell_filtered_container")))
        )
      ))

      # Set default selected tab
      default_tab <- if (has_metadata) "meta_all" else "meta_cell"
      do.call(tabsetPanel, c(list(id = ns("data_tabs"), selected = default_tab), tabs))
    })

    # Reactive expression to manage data processing
    processed_data <- reactive({
      req(current_sample(), input$data_tabs)

      # Fetch data based on current inputs
      dat <- get_sample_data(current_sample(), input$data_tabs)

      # Return NULL if no data is found
      if (is.null(dat)) {
        message("No data found for sample: ", current_sample(), ", tab: ", input$data_tabs)
        return(NULL)
      }

      # Optimize data format
      dat <- dat %>%
        dplyr::mutate(across(where(is.numeric), ~ round(., 2))) %>%
        dplyr::mutate(across(where(is.factor), as.character))

      dat$id <- seq_len(nrow(dat))  # Add unique ID column
      dat$cell_name <- rownames(dat)  # Preserve original row names as cell_name

      # Reorder columns
      dat <- dat[, c("id", "cell_name", setdiff(names(dat), c("id", "cell_name")))]

      # Replace dots in column names with underscores
      names(dat) <- gsub("\\.", "_", names(dat))

      return(dat)
    })

    # Observer to handle sending data to the frontend
    observe({
      dat <- processed_data()
      if (!is.null(dat)) {
        # Send data to the frontend
        session$sendCustomMessage("renderTabulator", list(
          container = ns(paste0(input$data_tabs, "_div")),
          data = jsonify::pretty_json(jsonify::to_json(dat))
        ))
      }
    })

    # Clean up cache
    session$onSessionEnded(function() {
      if (cache_enabled) {
        # Clean up cache related to current module
        cache_keys <- ls(.sample_summary_cache)
        rm(list = cache_keys, envir = .sample_summary_cache)
        message("[CACHE] Sample summary cache cleared on session end")
      }
    })
  })
}