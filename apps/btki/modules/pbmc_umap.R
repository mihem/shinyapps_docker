# PBMC UMAP Module - Refactored Version
# Simplified to ~200 lines, maintaining all functionality

source("modules/plot_controls.R")
source("utils/plot_layout_calculator.R")

# ============================================================================
# UI
# ============================================================================
umap_UI <- function(id) {
  ns <- NS(id)

  fluidRow(
    useShinyjs(),  # Enable shinyjs
    # JavaScript to monitor window size changes
    tags$script(HTML(sprintf("
      (function(){
        var nsId = '%s';
        var lastW = -1, lastH = -1;
        var timer = null;

        function send(){
          var w = window.innerWidth;
          var h = window.innerHeight;
          if (w === lastW && h === lastH) return;
          lastW = w; lastH = h;
          Shiny.setInputValue(nsId, {width:w, height:h}, {priority:'event'});
        }

        function debouncedSend(){
          if (timer) clearTimeout(timer);
          timer = setTimeout(send, 250);
        }

        $(document).on('shiny:connected', function(){
          send();
          $(window).on('resize.'+nsId, debouncedSend);
        });

        $(document).on('shiny:disconnected', function(){
          $(window).off('resize.'+nsId);
        });
      })();
    ", ns("window_size")))),

    column(
      width = 3,
      box(
        title = "Settings",
        status = "primary",
        solidHeader = TRUE,
        width = NULL,
        selectInput(ns("annotation"), "Annotation", choices = NULL),
        selectInput(ns("split_by"), "Split By", choices = c("None")),
        actionButton(ns("plot_btn"), "Plot", class = "btn-primary btn-block"),
        hr(),
        plot_controls_UI(ns("controls")),
        checkboxInput(ns("show_labels"), "Show Labels", FALSE)
      )
    ),
    column(
      width = 9,
      box(
        status = "primary",
        solidHeader = TRUE,
        width = NULL,
        uiOutput(ns("plot_container"))  # Change to dynamic container
      )
    )
  )
}

# ============================================================================
# Server
# ============================================================================
umap_Server <- function(id, umap_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # === 1. Window size listener (real-time response) ===
    window_size <- reactive({
      if (is.null(input$window_size)) {
        return(list(width = 1200, height = 800))
      }
      input$window_size
    })

    # === 2. Initialize select inputs ===
    observe({
      cols <- colnames(umap_data)

      # Annotation column options
      anno_opts <- intersect(
        c("celltype_merged.l1", "celltype_merged.l2", "treatment", "timepoint", "sample"),
        cols
      )
      if (length(anno_opts) == 0) anno_opts <- cols

      # Split column options
      split_opts <- c("None", intersect(
        c("timepoint", "treatment", "sample", "celltype_merged.l1"),
        cols
      ))

      updateSelectInput(session, "annotation", choices = anno_opts, selected = anno_opts[1])
      updateSelectInput(session, "split_by", choices = split_opts, selected = "None")
    })

    # === 3. Calculate number of groups (for layout calculation) ===
    n_groups <- reactive({
      req(input$split_by)
      if (input$split_by == "None") {
        return(1)
      }
      if (!input$split_by %in% colnames(umap_data)) {
        return(1)
      }
      length(unique(umap_data[[input$split_by]]))
    })

    # === 4. Calculate layout parameters (responsive to window size and group count) ===
    layout_params <- reactive({
      ws <- window_size()
      n <- n_groups()

      layout <- get_umap_layout(
        n_plots = n,
        window_width = (ws$width - 250) / 12 * 9 - 15*2 - 10*2,
        window_height = ws$height - 90,
        sidebar_width = 250,
        header_height = 90,
        min_size = 350
      )

      return(layout)
    })

    # === 5. Plot parameters (responsive to layout) ===
    params <- plot_controls_Server("controls",
      default_params = list(
        title_size = 16,
        axis_title_size = 14,
        axis_text_size = 12,
        legend_title_size = 12,
        legend_text_size = 10,
        legend_position = "top"
      ),
      group_count = n_groups
    )

    # === 6. Dynamically render plot container (height changes with layout) ===
    output$plot_container <- renderUI({
      # Only show after button click
      req(input$plot_btn > 0)
      req(input$annotation)

      layout <- layout_params()

      # Calculate annotation category count, dynamically adjust extra height
      n_categories <- length(unique(umap_data[[input$annotation]]))

      if (n_groups() != 1) {
        # Calculate extra height based on category count (for legend display)
        extra_height <- if (n_categories <= 3) {
          250
        } else {
          300
        }
      } else {
        extra_height <- 0  # When UMAP size is large enough, fixed add 0
      }

      # If using scrollbar, add scroll style
      if (isTRUE(layout$use_scroll)) {
        div(
          style = sprintf("overflow-y: auto; max-height: %dpx;", window_size()$height - 90),
          shinycssloaders::withSpinner(
            plotOutput(ns("plot"), height = paste0(layout$plot_height + extra_height, "px")), type = 6, color = "#0d6efd"
          )
        )
      } else {
        shinycssloaders::withSpinner(
          plotOutput(ns("plot"), height = paste0(layout$plot_height + extra_height, "px")),
          type = 6, color = "#0d6efd"
        )
      }
    })

    # === 7. Plot logic ===
    output$plot <- renderPlot({

      # Trigger: button click or window size change (but button already clicked)
      input$plot_btn
      if (input$plot_btn == 0) return(NULL)

      # Window size change also triggers redraw (must be outside isolate)
      window_size()

      # ⚠️ Critical: Get layout parameters outside isolate, so layout updates when window changes
      layout <- layout_params()

      isolate({
        req(input$annotation)

        # Validate column existence
        validate(
          need(input$annotation %in% colnames(umap_data), "Invalid annotation column"),
          need(input$split_by == "None" || input$split_by %in% colnames(umap_data), "Invalid split column")
        )

        # Get parameters (only get plot style parameters, layout parameters already obtained above)
        p_params <- params()
        split_col <- if (input$split_by == "None") NULL else input$split_by

        # Build plot
        p <- ggplot(umap_data, aes(umap_1, umap_2, color = .data[[input$annotation]])) +
          geom_point(alpha = 0.6, size = 1) +
          labs(
            title = if (is.null(split_col)) {
              paste("UMAP -", gsub("_", " ", input$annotation))
            } else {
              paste("UMAP -", gsub("_", " ", input$annotation),
                   "grouped by", gsub("_", " ", split_col))
            },
            x = "UMAP 1",
            y = "UMAP 2",
            color = gsub("_", " ", input$annotation)
          ) +
          theme_minimal() +
          theme(
            text = element_text(size = p_params$axis_text_size),
            plot.title = element_text(size = p_params$title_size),
            axis.title = element_text(size = p_params$axis_title_size),
            legend.text = element_text(size = p_params$legend_text_size),
            legend.title = element_text(size = p_params$legend_title_size),
            legend.position = p_params$legend_position
          ) +
          coord_fixed(ratio = 1)

        # Color scale
        n_cats <- length(unique(umap_data[[input$annotation]]))
        p <- p + if (n_cats <= 9) {
          scale_color_brewer(palette = "Set1")
        } else if (n_cats <= 12) {
          scale_color_brewer(palette = "Set3")
        } else {
          scale_color_viridis_d(option = "plasma")
        }

        # Faceting (use calculated layout)
        if (!is.null(split_col)) {
          p <- p + facet_wrap(~ .data[[split_col]], ncol = layout$ncol)
        }

        # Labels
        if (input$show_labels) {
          p <- p + ggrepel::geom_text_repel(
            aes(label = .data[[input$annotation]]),
            size = 3, max.overlaps = 10
          )
        }

        print(p)
      })
    })
  })
}
