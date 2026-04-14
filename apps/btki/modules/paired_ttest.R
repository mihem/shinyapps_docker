# UI for Paired T-Test with Effect Size
paired_ttest_UI <- function(id) {
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
          if (w === lastW && h === lastH) return; // No change in size, don't send
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

        // Optional: Unbind when Shiny session ends
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
          ns("effect_size_method"),
          "Select Effect Size Method:",
          choices = c("cohen.d", "hedges.g", "glass.delta"),
          selected = "cohen.d"
        ),
        selectInput(
          ns("p_adjust_method"),
          "P-value Adjustment Method:",
          choices = c("fdr", "bonferroni", "holm", "hochberg", "none"),
          selected = "fdr"
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
            DT::dataTableOutput(ns("paired_ttest_table"))
          ),
          tabPanel(
            title = "Effect Size Plot",
            icon = icon("fas fa-chart-scatter"),
            br(),
            plotOutput(ns("volcano_plot"), height = "600px")
          )
        )
      )
    )
  )
}

# Server for Paired T-Test with Effect Size
paired_ttest_Server <- function(id, meta_df, cached_data, tissue = "PBMC") {
  moduleServer(id, function(input, output, session) {
    req(nrow(meta_df) > 0 && ncol(meta_df) > 0)
    ns <- session$ns

    # === 1. Window size listener ===
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
      req(meta_df, input$cell_type_grouping, input$treatment_variable, input$effect_size_method, input$p_adjust_method)

      # Show progress notification
      showNotification("Starting Paired T-Test analysis...", type = "message", duration = 2)

      # Check cache
      cache_file <- sprintf("data/cached_%s_paired_ttest.qs", tolower(tissue))

      if (!is.null(cached_data) &&
          input$cell_type_grouping == "celltype_merged.l2" &&
          input$treatment_variable == "timepoint" &&
          input$effect_size_method == "cohen.d" &&
          input$p_adjust_method == "fdr") {

        showNotification("Using cached results", type = "message", duration = 2)
        return(list(results_df = cached_data, from_cache = TRUE))
      }

      # Perform computation
      showNotification("Computing Paired T-Test results...", type = "message", duration = 3)

      tryCatch({
        # Set cell type grouping based on user selection
        CELL_TYPES <- unique(meta_df[[input$cell_type_grouping]]) %>% sort()
        meta_df[["annotated"]] <- meta_df[[input$cell_type_grouping]]
        meta_df[["subject_id"]] <- gsub("\\D", "", meta_df$sample)
        meta_df[["timepoint_var"]] <- meta_df[[input$treatment_variable]]

        # Get treatment levels
        treatment_levels <- unique(meta_df$timepoint_var) %>% sort()
        if(length(treatment_levels) != 2) {
          stop("Treatment variable must have exactly 2 levels")
        }

        # Check if sample sizes are equal
        sample_counts <- sapply(treatment_levels, function(t) sum(meta_df[["timepoint_var"]] == t))
        if (all(sample_counts == sample_counts[1])) {
          paired_mode <- TRUE
            showNotification("Equal sample sizes: Computing Paired T-Test results...", type = "message", duration = 88)
        } else {
          paired_mode <- FALSE
          showNotification("Unequal sample sizes: Computing Unpaired T-Test results...", type = "warning", duration = 88)
        }

        # Calculate proportions
        proportion_df <- meta_df %>%
          group_by(sample, timepoint_var, annotated) %>%
          summarise(count = n(), .groups = "drop") %>%
          group_by(sample) %>%
          mutate(percentage = count / sum(count) * 100) %>%
          ungroup() %>%
          dplyr::select(-count) %>%
          tidyr::pivot_wider(names_from = annotated, values_from = percentage, values_fill = 0)

        # Perform paired t-tests
        paired_test_results <- list()
        for (cell_type in CELL_TYPES) {
          if(cell_type %in% names(proportion_df)) {
            group1_data <- proportion_df[proportion_df$timepoint_var == treatment_levels[1], cell_type][[1]]
            group2_data <- proportion_df[proportion_df$timepoint_var == treatment_levels[2], cell_type][[1]]

            if(length(group1_data) > 0 && length(group2_data) > 0) {
              test_result <- t.test(group2_data, group1_data, paired = paired_mode)
              paired_test_results[[cell_type]] <- test_result
            }
          }
        }

        # Organize results
        paired_results_df <- data.frame(
          cell_type = names(paired_test_results),
          p_value = sapply(paired_test_results, function(x) x$p.value),
          mean_diff = sapply(paired_test_results, function(x) x$estimate),
          ci_lower = sapply(paired_test_results, function(x) x$conf.int[1]),
          ci_upper = sapply(paired_test_results, function(x) x$conf.int[2]),
          stringsAsFactors = FALSE
        )
        paired_results_df$p_adj <- p.adjust(paired_results_df$p_value, method = input$p_adjust_method)

        # Calculate effect sizes
        effect_sizes <- list()
        for (cell_type in names(paired_test_results)) {
          if(cell_type %in% names(proportion_df)) {
            group1_data <- proportion_df[proportion_df$timepoint_var == treatment_levels[1], cell_type][[1]]
            group2_data <- proportion_df[proportion_df$timepoint_var == treatment_levels[2], cell_type][[1]]

            if(length(group1_data) > 0 && length(group2_data) > 0) {
              effect_size_func <- switch(input$effect_size_method,
                "cohen.d" = effsize::cohen.d,
                "hedges.g" = effsize::cohen.d,  # hedges.g is a variant of cohen.d
                "glass.delta" = effsize::cohen.d
              )

              effect_result <- effect_size_func(group2_data, group1_data, paired = paired_mode)
              effect_sizes[[cell_type]] <- effect_result$estimate
            }
          }
        }

        effect_size_df <- data.frame(
          cell_type = names(effect_sizes),
          effect_size = unlist(effect_sizes),
          stringsAsFactors = FALSE
        )

        # Determine effect size magnitude
        effect_size_df$magnitude <- cut(abs(effect_size_df$effect_size),
                                        breaks = c(0, 0.2, 0.5, 0.8, Inf),
                                        labels = c("Negligible", "Small", "Medium", "Large"))

        # Combine results
        combined_df <- merge(effect_size_df, paired_results_df, by = "cell_type")

        showNotification("Analysis completed successfully!", type = "message", duration = 3)

        return(list(
          results_df = combined_df,
          from_cache = FALSE,
          treatment_levels = treatment_levels,
          cell_type_grouping = input$cell_type_grouping,
          treatment_variable = input$treatment_variable,
          effect_size_method = input$effect_size_method,
          p_adjust_method = input$p_adjust_method
        ))

      }, error = function(e) {
        showNotification(paste("Error in analysis:", e$message), type = "error", duration = 5)
        return(NULL)
      })
    })

    output$paired_ttest_table <- DT::renderDataTable({
      results <- analysis_results()
      if(is.null(results)) {
        return(data.frame(Message = "Click 'Run Analysis' to start the analysis"))
      }
      results_df <- results$results_df

      # Automatically format all numeric columns to 3 significant figures
      numeric_cols <- sapply(results_df, is.numeric)
      results_df[numeric_cols] <- lapply(results_df[numeric_cols], function(x) signif(x, 3))

      # Rename columns for better display
      names(results_df)[names(results_df) == "cell_type"]   <- "Cell Type"
      names(results_df)[names(results_df) == "p_value"]     <- "P-value"
      names(results_df)[names(results_df) == "p_adj"]       <- "Adjusted P-value"
      names(results_df)[names(results_df) == "mean_diff"]   <- "Mean Difference"
      names(results_df)[names(results_df) == "ci_lower"]    <- "CI Lower"
      names(results_df)[names(results_df) == "ci_upper"]    <- "CI Upper"
      names(results_df)[names(results_df) == "effect_size"] <- "Effect Size"
      names(results_df)[names(results_df) == "magnitude"]   <- "Effect Magnitude"

      DT::datatable(
        results_df,
        options = list(
          pageLength = 15,
          lengthMenu = c(5, 10, 20),
          searchDelay = 500,
          processing = TRUE,
          dom = "Bfrtip",
          scrollX = TRUE,          # Enable horizontal scrolling
          # scrollCollapse = TRUE,
          responsive = TRUE,       # Enable responsive
          autoWidth = FALSE,       # Disable auto width
          fixedColumns = TRUE,     # Optional: Fix left columns
          buttons = c('copy', 'csv', 'excel')
        ),
        rownames = TRUE,
        class = "display compact nowrap cell-border"  # Add more CSS classes
      )
    })

    # Effect size plot (similar to volcano plot but with effect size)
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

      # Create effect size plot data
      plot_data <- results_df %>%
        mutate(
          neg_log10_p = -log10(p_adj),
          significant = p_adj < 0.05,
          effect_large = abs(effect_size) >= 0.8
        )

      # Build title
      comparison_text <- if(!is.null(results$treatment_levels)) {
        paste0(results$treatment_levels[2], " vs ", results$treatment_levels[1])
      } else {
        "Comparison"
      }

      # Build X-axis label
      x_label <- paste0("Effect Size (", tools::toTitleCase(results$effect_size_method), ")")

      # Create base plot
      p <- ggplot(plot_data, aes(x = effect_size, y = neg_log10_p)) +
        geom_point(aes(color = significant, size = abs(effect_size)), alpha = 0.7) +
        scale_color_manual(
          values = c("FALSE" = "gray", "TRUE" = "red"),
          labels = c("FALSE" = "Not Significant", "TRUE" = "Significant (p < 0.05)")
        ) +
        scale_size_continuous(
          name = "Effect Size Magnitude",
          range = c(2, 6),
          breaks = c(0.2, 0.5, 0.8),
          labels = c("Small", "Medium", "Large")
        ) +
        geom_hline(yintercept = -log10(0.05), linetype = "dashed", color = "blue", alpha = 0.8) +
        geom_vline(xintercept = c(-0.2, 0.2), linetype = "dashed", color = "orange", alpha = 0.8) +
        geom_vline(xintercept = 0, linetype = "dashed", color = "gray", alpha = 0.8) +
        labs(
          title = "Paired T-Test Results with Effect Size",
          subtitle = paste0("Comparison: ", comparison_text, " | Cell Type: ", results$cell_type_grouping, " | Method: ", results$p_adjust_method, " adjustment"),
          x = x_label,
          y = paste0("-log10(Adjusted P-value - ", results$p_adjust_method, ")"),
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
          aes(label = cell_type),
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
                          label = paste0("Positive: ↑ in ", results$treatment_levels[2], "\nNegative: ↑ in ",  results$treatment_levels[1]),
                          hjust = 1.1, vjust = 1.1,
                          size = params$axis_text_size * 0.3,
                          color = "black",
                          fontface = "italic")
      }

      # Add effect size reference line explanation
      p <- p + annotate("text",
                        x = -Inf, y = Inf,
                        label = "Effect Size Guidelines:\n|d| < 0.2: Negligible\n|d| ≥ 0.2: Small\n|d| ≥ 0.5: Medium\n|d| ≥ 0.8:  Large",
                        hjust = -0.1, vjust = 1.1,
                        size = params$axis_text_size * 0.25,
                        color = "darkgreen",
                        fontface = "italic")

      return(p)
    })
  })
}