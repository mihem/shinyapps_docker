# UI for Propeller's T-Test Results
propeller_UI <- function(id) {
  ns <- NS(id)
  fluidRow(
    shinyjs::useShinyjs(),
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
          // console.log('Sending window size:', w, 'x', h);
          Shiny.setInputValue(nsId, {width:w, height:h}, {priority:'event'});
        }

        function debouncedSend(){
          if (timer) clearTimeout(timer);
          timer = setTimeout(send, 250); // Debounce 250ms
        }

        $(document).on('shiny:connected', function(){
          // console.log('Shiny connected, sending initial window size');
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
      width = 4,
      box(
        title = "Analysis Settings",
        status = "primary",
        solidHeader = TRUE,
        width = NULL,
        selectInput(
          ns("cell_type_grouping"),
          "Select Cell Type Grouping:",
          choices = c("celltype_merged.l1", "celltype_merged.l2"),
          selected = "celltype_merged.l2"
        ),
        selectInput(
          ns("treatment_variable"),
          "Select Treatment Variable:",
          choices = c("treatment", "timepoint"),
          selected = "timepoint"
        ),
        selectInput(
          ns("transform_method"),
          "Select Transform Method:",
          choices = c("asin", "logit", "sqrt"),
          selected = "asin"
        ),
        div(
          id = ns("plot_btn_wrapper"),
          style = "position: relative;",
          actionButton(
            ns("run_analysis"),
            HTML('<i class="fa fa-hourglass"></i> Preparing...'),
            class = "btn btn-secondary",
            disabled = TRUE,
            style = "opacity: 0.6; cursor: not-allowed; min-width: 120px;"
          )
        ),
        # Add warning message display area
        uiOutput(ns("warning_message"))
      ),
      box(
        title = "Plot Controls",
        status = "primary",
        solidHeader = TRUE,
        collapsible = TRUE,
        collapsed = TRUE,
        width = NULL,
        plot_controls_UI(ns("plot_controls"))
      )
    ),
    column(
      width = 8,
      box(
        status = "primary",
        solidHeader = TRUE,
        width = NULL,
        tabsetPanel(
          id = ns("results_tabs"),
          tabPanel(
            title = "Results Table",
            icon = icon("table"),
            br(),
            DT::dataTableOutput(ns("propeller_table"))
          ),
          tabPanel(
            title = "Volcano Plot",
            icon = icon("fas fa-chart-scatter"),
            br(),
            plotOutput(ns("volcano_plot"), height = "600px")
          )
        )
      )
    )
  )
}

propeller_Server <- function(id, meta_df, cached_data, tissue = "PBMC") {
  moduleServer(id, function(input, output, session) {
    req(nrow(meta_df) > 0 && ncol(meta_df) > 0)
    ns <- session$ns

    # === 1. Monitor window size ===
    window_size <- reactive({
      if (is.null(input$window_size)) {
        return(list(width = 1200, height = 800))
      }
      input$window_size
    })

    plot_params <- plot_controls_Server(
      "plot_controls",
      default_params = list(
        show_plot_size     = TRUE,
        title_size         = 16,
        axis_title_size    = 14,
        axis_text_size     = 12,
        legend_title_size  = 12,
        legend_text_size   = 10,
        legend_position    = "top"
      )
    )

    # 2. Check data availability
    data_available <- reactive({
      req(meta_df)

      # Check if required columns exist
      has_cell_types <- any(c("celltype_merged.l1", "celltype_merged.l2") %in% names(meta_df))
      has_treatments <- any(c("treatment", "timepoint") %in% names(meta_df))
      has_sample <- "sample" %in% names(meta_df)

      return(has_cell_types && has_treatments && has_sample)
    })

    # 3. Update selector options
    observe({
      req(meta_df)

      # Update cell type selector
      cell_type_options <- c("celltype_merged.l1", "celltype_merged.l2")
      available_cell_types <- intersect(cell_type_options, names(meta_df))

      if(length(available_cell_types) > 0) {
        updateSelectInput(
          session = session,
          inputId = "cell_type_grouping",
          choices = available_cell_types,
          selected = available_cell_types[1]
        )
      }

      # Update treatment selector
      treatment_options    <- c("treatment", "timepoint")
      available_treatments <- c()
      for (t in treatment_options) {
        if (t %in% names(meta_df) && length(unique(meta_df[[t]])) == 2) {
          available_treatments <- c(available_treatments, t)
        }
      }

      if(length(available_treatments) > 0) {
        updateSelectInput(
          session = session,
          inputId = "treatment_variable",
          choices = available_treatments,
          selected = available_treatments[1]
        )
      }

      if (length(available_cell_types) == 0 || length(available_treatments) == 0) {
        updateActionButton(
          ns("run_analysis"),
          label = HTML('<i class="fa fa-exclamation-triangle"></i> Data Error'),
          class = "btn btn-secondary",
          # disabled = TRUE,
          style = "opacity: 0.6; cursor: not-allowed; min-width: 120px;"
        )
        # shinyjs::disable(ns("run_analysis"))
      } else {
        # Use JavaScript to directly update button state
        shinyjs::runjs(sprintf("
          var btn = $('#%s');
          btn.html('<i class=\"fa fa-rocket\"></i> Run Analysis!');
          btn.removeClass('btn-secondary disabled').addClass('btn-primary');
          btn.css({'opacity': '1', 'cursor': 'pointer'});
          btn.prop('disabled', false);
          ", ns("run_analysis")))
        shinyjs::enable(ns("run_analysis"))
      }
    })

    # Generate warning message
    output$warning_message <- renderUI({
      if(data_available()) {
        div(
          class = "alert alert-success",
          style = "margin-top: 15px;",
          p(icon("check"), strong("Ready for analysis!"), "All required variables are available.")
        )
      } else {
        div(
          class = "alert alert-warning",
          style = "margin-top: 15px;",
          h5(icon("exclamation-triangle"), "Analysis Unavailable"),
          p("Missing required metadata columns for analysis.")
        )
      }
    })

    # Analysis logic
    analysis_results <- eventReactive(input$run_analysis, {
      # Basic checks
      req(meta_df, input$cell_type_grouping, input$treatment_variable, input$transform_method)

      # Show progress notification
      showNotification("Starting Propeller analysis...", type = "message", duration = 2)

      # Check cache
      cache_file <- sprintf("data/cached_%s_propeller_statistics_ordered.qs", tolower(tissue))

      if (!is.null(cached_data) &&
          input$cell_type_grouping == "celltype_merged.l2" &&
          input$treatment_variable == "timepoint" &&
          input$transform_method == "asin") {

        showNotification("Using cached results", type = "message", duration = 2)
        return(list(results_df = cached_data, from_cache = TRUE))
      }

      # Perform computation
      showNotification("Computing Propeller test results...", type = "message", duration = 3)

      tryCatch({
        # Set cell type grouping based on user selection
        CELL_TYPES                 <- unique(meta_df[[input$cell_type_grouping]]) %>% sort()
        meta_df[["annotated"]]     <- meta_df[[input$cell_type_grouping]]
        meta_df[["subject_id"]]    <- gsub("\\D", "", meta_df$sample)
        meta_df[["timepoint_var"]] <- meta_df[[input$treatment_variable]]

        # Step 1: Calculate transformed proportions
        props <- speckle::getTransformedProps(
          clusters = meta_df$annotated,
          sample = meta_df$sample,
          transform = input$transform_method
        )

        # Step 2: Define groups and design matrix
        samples <- unique(meta_df[, c("sample", "timepoint_var", "subject_id")])

        # Get unique treatment levels
        treatment_levels <- unique(samples$timepoint_var) %>% sort()

        if(length(treatment_levels) != 2) {
          stop("Treatment variable must have exactly 2 levels")
        }

        # Create group vector
        grp <- samples$timepoint_var
        design <- model.matrix(~0 + grp)
        colnames(design) <- treatment_levels

        # Step 3: Perform differential proportion testing
        contrast <- c(-1, 1)  # comparing second level vs first level
        statistics <- speckle::propeller.ttest(
          prop.list = props,
          design = design,
          contrasts = contrast,
          robust = TRUE,
          trend = FALSE,
          sort = TRUE
        )

        # Step 4: Prepare data for volcano plot
        statistics_ordered <- tibble::rownames_to_column(statistics, "cluster")
        cluster_colors <- scales::hue_pal()(length(unique(statistics_ordered$cluster)))
        statistics_ordered <- cbind(statistics_ordered, cluster_colors)

        showNotification("Analysis completed successfully!", type = "message", duration = 3)

        return(list(
          results_df = statistics_ordered,
          from_cache = FALSE,
          treatment_levels = treatment_levels,
          cell_type_grouping = input$cell_type_grouping,
          treatment_variable = input$treatment_variable,
          transform_method = input$transform_method
        ))

      }, error = function(e) {
        showNotification(paste("Error in analysis:", e$message), type = "error", duration = 5)
        return(NULL)
      })
    })

    output$propeller_table <- DT::renderDataTable({
      results <- analysis_results()
      if(is.null(results)) {
        return(data.frame(Message = "Click 'Run Analysis' to start the analysis"))
      }
      results_df <- results$results_df

      tryCatch({
        # Automatically format all numeric columns to 3 significant figures
        numeric_cols <- sapply(results_df, is.numeric)
        results_df[numeric_cols] <- lapply(results_df[numeric_cols], function(x) signif(x, 3))

        # Format numeric columns
        if("P.Value" %in% names(results_df)) {
          results_df$P.Value <- sprintf("%.4f", results_df$P.Value)
        }
        if("PropRatio" %in% names(results_df)) {
          results_df$PropRatio <- sprintf("%.3f", results_df$PropRatio)
        }
        if("t" %in% names(results_df)) {
          results_df$t <- sprintf("%.3f", results_df$t)
        }

        # Rename columns for better display
        display_df <- results_df
        if("cluster" %in% names(display_df)) {
          names(display_df)[names(display_df) == "cluster"] <- "Cell Type"
        }
        if("P.Value" %in% names(display_df)) {
          names(display_df)[names(display_df) == "P.Value"] <- "P-value"
        }
        if("PropRatio" %in% names(display_df)) {
          names(display_df)[names(display_df) == "PropRatio"] <- "Proportion Ratio"
        }
        if("t" %in% names(display_df)) {
          names(display_df)[names(display_df) == "t"] <- "T-statistic"
        }

        # Remove color column for display
        display_df <- display_df[, !names(display_df) %in% "cluster_colors", drop = FALSE]

        return(display_df)

      }, error = function(e) {
        return(results$results_df)
      })
    }, options = list(
      pageLength = 15,
      scrollX = TRUE,
      dom = 'Bfrtip',
      buttons = c('copy', 'csv', 'excel')
    ))

    # Volcano plot
    output$volcano_plot <- renderPlot({
      results <- analysis_results()
      if(is.null(results)) {
        plot.new()
        text(0.5, 0.5, "Click 'Run Analysis' to generate plot", cex = 1.5, col = "blue", adj = 0.5)
        return()
      }

      # Get plot control parameters
      params <- plot_params()
      results_df <- results$results_df

      # Create volcano plot data
      plot_data <- results_df %>%
        mutate(
          neg_log10_p = -log10(P.Value),
          log2_ratio = log2(PropRatio),
          significant = P.Value < 0.05
        )

      # Build title
      comparison_text <- if(!is.null(results$treatment_levels)) {
        paste0(results$treatment_levels[2], " vs ", results$treatment_levels[1])
      } else {
        "Comparison"
      }

      # Build X-axis label
      x_label <- paste0("log2(Proportion Ratio) - ", comparison_text)

      # Create base plot
      p <- ggplot(plot_data, aes(x = log2_ratio, y = neg_log10_p)) +
        geom_point(aes(color = significant), size = 3, alpha = 0.7) +
        scale_color_manual(
          values = c("FALSE" = "gray", "TRUE" = "red"),
          labels = c("FALSE" = "Not Significant", "TRUE" = "Significant (p < 0.05)")
        ) +
        geom_hline(yintercept = -log10(0.05), linetype = "dashed", color = "blue", alpha = 0.8) +
        geom_vline(xintercept = 0, linetype = "dashed", color = "gray", alpha = 0.8) +
        labs(
          title = "Propeller's T-Test Results",
          subtitle = paste0("Comparison: ", comparison_text, " | Cell Type: ", results$cell_type_grouping, " | Transform: ", results$transform_method),
          x = x_label,
          y = "-log10(P-value)",
          color = "Significance"
        ) +
        theme_minimal() +
        theme(
          plot.title = element_text(size = params$title_size, face = "bold"),
          plot.subtitle = element_text(size = params$title_size - 2, color = "darkblue"),
          axis.title.x = element_text(size = params$axis_title_size),
          axis.title.y = element_text(size = params$axis_title_size),
          axis.text.x = element_text(size = params$axis_text_size),
          axis.text.y = element_text(size = params$axis_text_size),
          legend.position = params$legend_position,
          legend.title = element_text(size = params$legend_title_size),
          legend.text = element_text(size = params$legend_text_size),
          panel.grid.minor = element_blank()
        )

      # Add labels for significant points
      if(any(plot_data$significant)) {
        p <- p + geom_text_repel(
          data = filter(plot_data, significant),
          aes(label = cluster),
          size = params$axis_text_size * 0.3,
          max.overlaps = 10,
          box.padding = 0.5,
          point.padding = 0.3
        )
      }

      # Add annotation explaining positive/negative values
      if(!is.null(results$treatment_levels)) {
        p <- p + annotate("text",
                         x = Inf, y = Inf,
                         label = paste0("Positive: ↑ in ", results$treatment_levels[2], "\nNegative: ↑ in ", results$treatment_levels[1]),
                         hjust = 1.1, vjust = 1.1,
                         size = params$axis_text_size * 0.3,
                         color = "black",
                         fontface = "italic")
      }

      return(p)
    })
  })
}