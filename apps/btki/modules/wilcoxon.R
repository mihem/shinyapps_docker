# UI for Wilcoxon Signed-Rank Test Results
wilcoxon_UI <- function(id) {
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
          if (w === lastW && h === lastH) return; // 尺寸未变化，不发送
          lastW = w; lastH = h;
          // console.log('Sending window size:', w, 'x', h);
          Shiny.setInputValue(nsId, {width:w, height:h}, {priority:'event'});
        }

        function debouncedSend(){
          if (timer) clearTimeout(timer);
          timer = setTimeout(send, 250); // 防抖 250ms
        }

        $(document).on('shiny:connected', function(){
          // console.log('Shiny connected, sending initial window size');
          send();            // 初始发送
          $(window).on('resize.'+nsId, debouncedSend);
        });

        // 可选：在 Shiny 会话结束时解绑
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
        div(
          id = ns("plot_btn_wrapper"),
          style = "position: relative;",
          actionButton(
            ns("run_analysis"),
            HTML('<i class="fa fa-hourglass"></i> Preparing...'),  # 改为静态的沙漏图标
            class = "btn btn-secondary",
            disabled = TRUE,
            style = "opacity: 0.6; cursor: not-allowed; min-width: 120px;"
          )
        ),
        # 添加警告信息显示区域
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
        # title = "Wilcoxon Analysis Results",
        status = "primary",
        solidHeader = TRUE,
        width = NULL,
        # height = "700px",
        tabsetPanel(
          id = ns("results_tabs"),
          tabPanel(
            title = "Results Table",
            icon = icon("table"),
            br(),
            DT::dataTableOutput(ns("wilcoxon_table"))
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

wilcoxon_Server <- function(id, meta_df, cached_data, tissue = "PBMC") {
  moduleServer(id, function(input, output, session) {
    req(nrow(meta_df) > 0 && ncol(meta_df) > 0)
    ns <- session$ns

    # === 1. Window Size Listener ===
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

    # 2. Check Data Availability - Simplified Logic
    data_available <- reactive({
      req(meta_df)

      # Check if required columns exist
      has_cell_types <- any(c("celltype_merged.l1", "celltype_merged.l2") %in% names(meta_df))
      has_treatments <- any(c("treatment", "timepoint") %in% names(meta_df))

      return(has_cell_types && has_treatments)
    })

    # 3. Update Selector Options
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
          ns("`run_analysis`"),
          label = HTML('<i class="fa fa-exclamation-triangle"></i> Data Error'),  # 显示错误状态
          class = "btn btn-secondary",
          # disabled = TRUE,
          style = "opacity: 0.6; cursor: not-allowed; min-width: 120px;"
        )
        # shinyjs::disable(ns("run_analysis"))
      } else {
        # cat("Updated select inputs with available options\n")

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

    # Generate Warning Message
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

    # Modify analysis logic - Remove complex checks
    analysis_results <- eventReactive(input$run_analysis, {

      # Basic checks
      req(meta_df, input$cell_type_grouping, input$treatment_variable)

      # Show progress notification
      showNotification("Starting Wilcoxon analysis...", type = "message", duration = 2)

      # Check cache
      cache_file <- sprintf("data/cached_%s_wilcoxon_results_df.qs", tolower(tissue))

      if (!is.null(cached_data) &&
          input$cell_type_grouping == "celltype_merged.l2" &&
          input$treatment_variable == "timepoint") {

        showNotification("Using cached results", type = "message", duration = 2)
        return(list(results_df = cached_data, from_cache = TRUE))
      }

      # 进行计算
      showNotification("Computing Wilcoxon test results...", type = "message", duration = 3)

      tryCatch({
        # 根据用户选择设置细胞类型分组
        CELL_TYPES <- unique(meta_df[[input$cell_type_grouping]]) %>% sort()
        meta_df[["annotated"]] <- meta_df[[input$cell_type_grouping]]
        # meta_df[["subject_id"]] <- gsub("PBMC_(\\d+)_(Pre|Post).*", "\\1", meta_df$sample)
        meta_df[["subject_id"]] <- gsub("\\D", "", meta_df$sample)
        meta_df[["timepoint_var"]] <- meta_df[[input$treatment_variable]]

        CELL_TYPE_COUNTS <- meta_df %>%
          dplyr::select(subject_id, sample, annotated, timepoint_var) %>%
          group_by(subject_id, sample, annotated, timepoint_var) %>%
          summarise(cell_number = n(), .groups = "drop") %>%
          group_by(sample) %>%
          mutate(total_cell_number = sum(cell_number)) %>%
          mutate(percent = cell_number / total_cell_number * 100) %>%
          ungroup()

        # Convert to wide format
        wide_data <- CELL_TYPE_COUNTS %>% as.data.frame() %>%
          dplyr::select(subject_id, timepoint_var, annotated, percent) %>%
          pivot_wider(names_from = timepoint_var, values_from = percent, values_fill = 0)


        # Perform Wilcoxon test
        results <- list()
        timepoint_cols <- setdiff(names(wide_data), c("subject_id", "annotated"))

        if(length(timepoint_cols) < 2) {
          stop("Need at least 2 timepoints for comparison")
        }

        timepoint1 <- timepoint_cols[1]
        timepoint2 <- timepoint_cols[2]

        for (ct in unique(wide_data$annotated)) {
          subset_data <- wide_data %>% filter(annotated == ct)
          if (nrow(subset_data) < 2) {
            cat(paste0(ct, " cells were found in too few samples.\n"))
          } else {
            test_result <- wilcox.test(subset_data[[timepoint2]], subset_data[[timepoint1]], paired = TRUE)
            mean_diff <- mean(subset_data[[timepoint2]] - subset_data[[timepoint1]], na.rm = TRUE)
            results[[ct]] <- data.frame(
              cell_type = ct,
              p_value = test_result$p.value,
              statistic = as.numeric(test_result$statistic),
              mean_diff = mean_diff
            )
          }
        }

        results_df <- map_dfr(results, ~.x, .id = "cell_type_group") %>%
          dplyr::select(cell_type, p_value, statistic, mean_diff) %>%
          arrange(p_value) %>%
          mutate(significance = ifelse(p_value < 0.05, "*", ""))

        showNotification("Analysis completed successfully!", type = "message", duration = 3)

        return(list(
          results_df = results_df,
          from_cache = FALSE,
          timepoint1 = timepoint1,
          timepoint2 = timepoint2,
          cell_type_grouping = input$cell_type_grouping,
          treatment_variable = input$treatment_variable
        ))

      }, error = function(e) {
        showNotification(paste("Error in analysis:", e$message), type = "error", duration = 5)
        return(NULL)
      })
    })

    output$wilcoxon_table <- DT::renderDataTable({
      results <- analysis_results()
      if(is.null(results)) {
        return(data.frame(Message = "Click 'Run Analysis' to start the analysis"))
      }
      results_df <- results$results_df

      tryCatch({
        # Step 1: Format numeric values
        results_df$p_value   <- sprintf("%.4f", results_df$p_value)
        results_df$mean_diff <- sprintf("%.3f", results_df$mean_diff)
        results_df$statistic <- sprintf("%.1f", results_df$statistic)

        # Step 2: Rename columns
        names(results_df)[names(results_df) == "cell_type"] <- "Cell Type"
        names(results_df)[names(results_df) == "p_value"  ] <- "P-value"
        names(results_df)[names(results_df) == "statistic"] <- "Test Statistic"
        names(results_df)[names(results_df) == "mean_diff"] <- "Mean Difference"

        # If there is a significance column, rename it as well
        if("significance" %in% names(results_df)) {
          names(results_df)[names(results_df) == "significance"] <- "Significance"
        }

        return(results_df)

      }, error = function(e) {
        return(results$results_df)
      })
    }, options = list(
      pageLength = 15,
      scrollX = TRUE,
      dom = 'Bfrtip',
      buttons = c('copy', 'csv', 'excel')
    ))

    # Simplified volcano plot
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

      # Create volcano plot
      plot_data <- results_df %>%
        mutate(
          neg_log10_p = -log10(p_value),
          significant = p_value < 0.05
        )

      # Construct more detailed title and subtitle
      comparison_text <- if(!is.null(results$timepoint1) && !is.null(results$timepoint2)) {
        paste0(results$timepoint2, " vs ", results$timepoint1)
      } else {
        "Comparison"
      }

      # Construct X-axis label, clearly indicating comparison direction
      x_label <- if(!is.null(results$timepoint1) && !is.null(results$timepoint2)) {
        paste0("Mean Difference (%) - ", results$timepoint2, " minus ", results$timepoint1)
      } else {
        "Mean Difference (%)"
      }

      # Create base plot
      p <- ggplot(plot_data, aes(x = mean_diff, y = neg_log10_p)) +
        geom_point(aes(color = significant), size = 3, alpha = 0.7) +
        scale_color_manual(
          values = c("FALSE" = "gray", "TRUE" = "red"),
          labels = c("FALSE" = "Not Significant", "TRUE" = "Significant (p < 0.05)")
        ) +
        geom_hline(yintercept = -log10(0.05), linetype = "dashed", color = "blue", alpha = 0.8) +
        geom_vline(xintercept = 0, linetype = "dashed", color = "gray", alpha = 0.8) +
        labs(
          title = paste("Wilcoxon Signed-Rank Test Results"),
          subtitle = paste0("Comparison: ", comparison_text, " | Cell Type: ", results$cell_type_grouping),
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
          aes(label = cell_type),
          size = params$axis_text_size * 0.3,  # Adjust label size based on axis text size
          max.overlaps = 10,
          box.padding = 0.5,
          point.padding = 0.3
        )
      }

      # Add annotation explaining the meaning of positive and negative values
      if(!is.null(results$timepoint1) && !is.null(results$timepoint2)) {
        p <- p + annotate("text",
                         x = Inf, y = Inf,
                         label = paste0("Positive: ↑ in ", results$timepoint2, "\nNegative: ↑ in ", results$timepoint1),
                         hjust = 1.1, vjust = 1.1,
                         size = params$axis_text_size * 0.3,  # 根据轴文字大小调整注释大小
                         color = "black",
                         fontface = "italic")
      }

      return(p)
    })
  })
}
