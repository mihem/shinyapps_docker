# Source plot controls
source("modules/plot_controls.R")

# Defensive PBMC QC Plots Module
qc_plots_UI <- function(id) {
  ns <- NS(id)
  fluidRow(
    useShinyjs(),  # Enable shinyjs
    tags$script(HTML(sprintf("
      (function(){
        var nsId = '%s';
        var lastW = -1, lastH = -1;
        var timer = null;

        function send(){
          var w = window.innerWidth;
          var h = window.innerHeight;
          if (w === lastW && h === lastH) return; // Size unchanged, don't send
          lastW = w; lastH = h;
          Shiny.setInputValue(nsId, {width:w, height:h}, {priority:'event'});
        }

        function debouncedSend(){
          if (timer) clearTimeout(timer);
          timer = setTimeout(send, 250); // Debounce 250ms
        }

        $(document).on('shiny:connected', function(){
          send();            // Initial send
          $(window).on('resize.'+nsId, debouncedSend);
        });

        // Optional: Unbind on Shiny session end
        $(document).on('shiny:disconnected', function(){
          $(window).off('resize.'+nsId);
        });
      })();
    ", ns("window_size")))),
    column(
      width = 3,
      box(
        title = "Sample Selection",
        status = "primary",
        solidHeader = TRUE,
        width = NULL,
        selectInput(ns("sample_select"), "Select Sample", choices = NULL),
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
        )
      ),
      box(
        title = "Plot Controls",
        status = "primary",
        solidHeader = TRUE,
        width = NULL,
        collapsible = TRUE,
        plot_controls_UI(ns("plot_controls"))
      )
    ),
    column(
      width = 9,
      box(
        status = "primary",
        solidHeader = TRUE,
        width = NULL,
        # Dynamically generate tab panels
        uiOutput(ns("dynamic_tabs"))
      )
    )
  )
}

qc_plots_Server <- function(id, metadata_cell, metadata = NULL, show_cols_cell = NULL, show_cols_meta = NULL) {

  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Check if metadata exists
    has_metadata <- !is.null(metadata)

    # Monitor window size (must be placed in reactive environment)
    window_size <- reactive({
      if (is.null(input$window_size)) {
        return(list(width = 1200, height = 800))  # Default value
      }
      input$window_size
    })

    # Initialize plot controls
    plot_params <- plot_controls_Server("plot_controls")

    # Dynamically generate tab panels
    output$dynamic_tabs <- renderUI({
      tabs <- list()

      # Always add RNA QC tab
      tabs[[1]] <- tabPanel(
        "RNA QC",
        value = "rna_qc",
        uiOutput(ns("rna_qc_plot_ui"))
      )

      # Only add ADT QC tab when metadata exists
      if (has_metadata) {
        tabs[[2]] <- tabPanel(
          "ADT QC",
          value = "adt_qc",
          uiOutput(ns("adt_qc_plot_ui"))
        )
      }

      # Set default selected tab
      default_tab <- "rna_qc"

      do.call(tabsetPanel, c(
        list(id = ns("tabs"), selected = default_tab),
        tabs
      ))
    })

    # Sample name vector
    sample_names <- names(metadata_cell)
    req(length(sample_names) > 0)

    # Initialize dropdown
    updateSelectInput(session, "sample_select", choices = sample_names, selected = sample_names[1])

    # Current sample reactive
    current_sample <- reactive({
      sample <- req(input$sample_select)
      sample
    })

    # Simple column subset utility
    subset_cols <- function(df, cols) {
      if (is.null(cols)) return(df)
      keep <- intersect(cols, colnames(df))
      if (length(keep)) df[, keep, drop = FALSE] else df[ , 0, drop = FALSE]
    }

    # Three data reactives: recalculate only when current sample changes
    # Only create data_meta when metadata exists
    if (has_metadata) {
      data_meta <- reactive({
        sample <- current_sample()

        if (!sample %in% names(metadata)) {
          return(data.frame())
        }

        df <- metadata[[sample]]
        result <- subset_cols(df, show_cols_meta)
        result
      })
    }

    data_cell <- reactive({
      sample <- current_sample()

      if (!sample %in% names(metadata_cell)) {
        return(data.frame())
      }

      df <- metadata_cell[[sample]]
      result <- subset_cols(df, show_cols_cell)
      result
    })

    output$rna_qc_plot_ui <- renderUI({
      shinycssloaders::withSpinner(plotOutput(ns("rna_qc_plot"), height = glue::glue("{window_size()$height-140}px")))
    })

    # Only render ADT QC UI when metadata exists
    if (has_metadata) {
      output$adt_qc_plot_ui <- renderUI({
        shinycssloaders::withSpinner(plotOutput(ns("adt_qc_plot"), height = glue::glue("{window_size()$height-140}px")))
      })
    }

    output$rna_qc_plot <- renderPlot({
      data <- data_cell()

      # Check if data is empty
      if (is.null(data) || nrow(data) == 0) {
        cat("===> [WARNING] Data is empty, returning empty plot\n")
        return(ggplot() +
               geom_text(aes(x = 0.5, y = 0.5, label = "No data available"),
                         size = 6, color = "gray50") +
               theme_void() +
               xlim(0, 1) + ylim(0, 1))
      }

      # Try to generate plot, add tryCatch error handling
      tryCatch({
        p <- plot_rna_qc(
          data,
          sample_name       = current_sample(),
          title_size        = plot_params()$title_size,
          axis_text_size    = plot_params()$axis_text_size,
          axis_title_size   = plot_params()$axis_title_size,
          legend_text_size  = plot_params()$legend_text_size,
          legend_title_size = plot_params()$legend_title_size,
          legend_position   = plot_params()$legend_position
        )
        print(p)
      }, error = function(e) {
        cat("===> [ERROR] plot_rna_qc failed:", e$message, "\n")
        # Return error message plot
        ggplot() +
          geom_text(aes(x = 0.5, y = 0.5, label = paste("Error:", e$message)),
                    size = 4, color = "red", hjust = 0.5) +
          theme_void() +
          xlim(0, 1) + ylim(0, 1)
      })
    })

    # Only render ADT QC plot when metadata exists
    if (has_metadata) {
      output$adt_qc_plot <- renderPlot({
        p <- plot_adt_qc(
          data_meta(),
          data_cell(),
          sample_name       = current_sample(),
          title_size        = plot_params()$title_size,
          axis_text_size    = plot_params()$axis_text_size,
          axis_title_size   = plot_params()$axis_title_size,
          legend_text_size  = plot_params()$legend_text_size,
          legend_title_size = plot_params()$legend_title_size,
          legend_position   = plot_params()$legend_position
        )
        print(p)
      })

      # Only set suspend options when metadata exists
      outputOptions(output, "adt_qc_plot", suspendWhenHidden = TRUE)
    }

    # Previous / Next sample
    observeEvent(input$prev_sample, {
      idx <- match(current_sample(), sample_names)
      if (!is.na(idx) && idx > 1) {
        updateSelectInput(session, "sample_select", selected = sample_names[idx - 1])
      }
    })
    observeEvent(input$next_sample, {
      idx <- match(current_sample(), sample_names)
      if (!is.na(idx) && idx < length(sample_names)) {
        updateSelectInput(session, "sample_select", selected = sample_names[idx + 1])
      }
    })
  })
}