# UI for Differential Expression Analysis
de_analysis_UI <- function(id) {
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
          if (w === lastW && h === lastH) return;
          lastW = w; lastH = h;
          // console.log('Sending window size:', w, 'x', h);
          Shiny.setInputValue(nsId, {width:w, height:h}, {priority:'event'});
        }

        function debouncedSend(){
          if (timer) clearTimeout(timer);
          timer = setTimeout(send, 250);
        }

        $(document).on('shiny:connected', function(){
          // console.log('Shiny connected, sending initial window size');
          send();
          $(window).on('resize.'+nsId, debouncedSend);
        });

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
          ns("cell_annotation_level"),
          "Select Cell Annotation Level:",
          choices = NULL,
          selected = NULL
        ),
        selectInput(
          ns("cell_type"),
          "Select Cell Type:",
          choices = NULL,
          selected = NULL
        ),
        numericInput(
          ns("fc_cutoff"),
          "Log2 Fold Change Cutoff:",
          value = 0.5,
          min = 0,
          max = 5,
          step = 0.1
        ),
        numericInput(
          ns("pvalue_cutoff"),
          "Adjusted P-value Cutoff:",
          value = 0.05,
          min = 0.001,
          max = 0.1,
          step = 0.001
        ),
        numericInput(
          ns("top_genes_count"),
          "Number of Top Genes to Label:",
          value = 10,
          min = 5,
          max = 50,
          step = 5
        ),
        # Dynamic UI to display comparison info
        uiOutput(ns("comparison_info")),
        div(
          id = ns("plot_btn_wrapper"),
          style = "position: relative;",
          actionButton(
            ns("update_plot"),
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
            DT::dataTableOutput(ns("de_table"))
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

# Server for Differential Expression Analysis
de_analysis_Server <- function(id, de_result_list, comparison_groups = c("Post", "Pre")) {
  moduleServer(id, function(input, output, session) {
    req(!is.null(de_result_list) && length(de_result_list) > 0)
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
      req(de_result_list)

      # Check if data structure is correct
      has_annotation_levels <- length(names(de_result_list)) > 0
      has_cell_types <- FALSE

      if (has_annotation_levels) {
        # Check if at least one annotation level has cell types
        for (level in names(de_result_list)) {
          if (length(names(de_result_list[[level]])) > 0) {
            has_cell_types <- TRUE
            break
          }
        }
      }

      return(has_annotation_levels && has_cell_types)
    })

    # 3. Update first dropdown - Cell Annotation Level
    observe({
      req(de_result_list)

      annotation_levels <- names(de_result_list)

      if(length(annotation_levels) > 0) {
        updateSelectInput(
          session = session,
          inputId = "cell_annotation_level",
          choices = annotation_levels,
          selected = annotation_levels[1]
        )
      }
    })

    # 4. Update second dropdown - Cell Type (based on first dropdown selection)
    observe({
      req(input$cell_annotation_level, de_result_list)

      if (input$cell_annotation_level %in% names(de_result_list)) {
        cell_types <- names(de_result_list[[input$cell_annotation_level]])

        if(length(cell_types) > 0) {
          updateSelectInput(
            session = session,
            inputId = "cell_type",
            choices = cell_types,
            selected = cell_types[1]
          )
        }
      }
    })

    # 5. Update button status
    observe({
      if (data_available() &&
          !is.null(input$cell_annotation_level) &&
          !is.null(input$cell_type)) {

        # Use JavaScript to directly update button status
        shinyjs::runjs(sprintf("
          var btn = $('#%s');
          btn.html('<i class=\"fa fa-refresh\"></i> Update Plot');
          btn.removeClass('btn-secondary disabled').addClass('btn-primary');
          btn.css({'opacity': '1', 'cursor': 'pointer'});
          btn.prop('disabled', false);
          ", ns("update_plot")))
        shinyjs::enable(ns("update_plot"))
      } else {
        updateActionButton(
          session,
          "update_plot",
          label = HTML('<i class="fa fa-exclamation-triangle"></i> Data Error'),
          class = "btn btn-secondary",
          # disabled = TRUE,
          style = "opacity: 0.6; cursor: not-allowed; min-width: 120px;"
        )
        # shinyjs::disable(ns("update_plot"))
      }
    })

    # Add comparison info dynamic UI on server side
    output$comparison_info <- renderUI({
      div(
        style = "margin: 15px 0; padding: 10px; background-color: #f8f9fa; border-left: 4px solid #007bff; border-radius: 4px;",
        h5(
          style = "margin: 0 0 5px 0; color: #007bff; font-weight: bold;",
          icon("balance-scale"), " Comparison"
        ),
        p(
          style = "margin: 0; font-size: 14px; color: #495057;",
          HTML(sprintf(
            "<strong>%s</strong> vs <strong>%s</strong><br><small class='text-muted'>Positive log2FC: higher in %s</small>",
            comparison_groups[1], comparison_groups[2], comparison_groups[1]
          ))
        )
      )
    })

    # Generate warning message
    output$warning_message <- renderUI({
      if(data_available()) {
        div(
          class = "alert alert-success",
          style = "margin-top: 15px;",
          p(icon("check"), strong("Ready for analysis!"), "Select cell annotation level and cell type.")
        )
      } else {
        div(
          class = "alert alert-warning",
          style = "margin-top: 15px;",
          h5(icon("exclamation-triangle"), "Analysis Unavailable"),
          p("No differential expression data available.")
        )
      }
    })

    # 6. Get currently selected data
    current_data <- reactive({
      req(input$cell_annotation_level, input$cell_type, de_result_list)

      if (input$cell_annotation_level %in% names(de_result_list) &&
          input$cell_type %in% names(de_result_list[[input$cell_annotation_level]])) {

        data <- de_result_list[[input$cell_annotation_level]][[input$cell_type]]

        # Ensure data has correct columns
        required_cols <- c("p_val", "avg_log2FC", "pct.1", "pct.2", "p_val_adj", "genes")
        if (all(required_cols %in% names(data))) {
          return(data)
        }
      }

      return(NULL)
    })

    # 7. Process data for display
    processed_data <- eventReactive(input$update_plot, {
      req(current_data())

      data <- current_data()

      # Recalculate significance
      data <- data %>%
        mutate(
          significant = ifelse(
            abs(avg_log2FC) > input$fc_cutoff & p_val_adj < input$pvalue_cutoff,
            "Significant",
            "Not significant"
          ),
          genes = if("genes" %in% names(.)) genes else rownames(.)
        )

      # Get top genes
      top_genes <- data %>%
        filter(p_val_adj < input$pvalue_cutoff, abs(avg_log2FC) > input$fc_cutoff) %>%
        arrange(p_val_adj) %>%
        slice_head(n = input$top_genes_count) %>%
        pull(genes)

      return(list(data = data, top_genes = top_genes))

    }, ignoreNULL = FALSE)

    # 8. Render table
    output$de_table <- DT::renderDataTable({
      result <- processed_data()
      if(is.null(result)) {
        return(data.frame(Message = "Select cell annotation level and cell type, then click 'Update Plot'"))
      }

      data <- result$data

      # Format numeric columns
      display_data <- data %>%
        mutate(
          p_val = sprintf("%.2e", p_val),
          avg_log2FC = sprintf("%.3f", avg_log2FC),
          pct.1 = sprintf("%.3f", pct.1),
          pct.2 = sprintf("%.3f", pct.2),
          p_val_adj = sprintf("%.2e", p_val_adj)
        )

      # Rename columns
      names(display_data)[names(display_data) == "p_val"] <- "P-value"
      names(display_data)[names(display_data) == "avg_log2FC"] <- "Log2 Fold Change"
      names(display_data)[names(display_data) == "pct.1"] <- "Pct.1"
      names(display_data)[names(display_data) == "pct.2"] <- "Pct.2"
      names(display_data)[names(display_data) == "p_val_adj"] <- "Adjusted P-value"
      names(display_data)[names(display_data) == "significant"] <- "Significance"
      names(display_data)[names(display_data) == "genes"] <- "Gene"

      DT::datatable(
        display_data,
        options = list(
          pageLength = 15,
          scrollX = TRUE,
          dom = 'Bfrtip',
          buttons = c('copy', 'csv', 'excel')
        ),
        extensions = 'Buttons',
        rownames = FALSE
      )
    })

    # 9. Render volcano plot
    output$volcano_plot <- renderPlot({
      result <- processed_data()
      if(is.null(result)) {
        plot.new()
        text(0.5, 0.5, "Select parameters and click 'Update Plot'", cex = 1.5, col = "blue", adj = 0.5)
        return()
      }

      # Get plot control parameters
      params <- plot_params()
      data <- result$data
      top_genes <- result$top_genes

      # Build subtitle info
      comparison_text <- paste0(comparison_groups[1], " vs ", comparison_groups[2])
      subtitle_text <- paste0(
        'Comparison: ', comparison_text, ' | ',
        'FC cutoff: ±', input$fc_cutoff, ', P cutoff: ', input$pvalue_cutoff
      )

      # Create volcano plot
      tryCatch({
        # Use EnhancedVolcano if available
        if (requireNamespace("EnhancedVolcano", quietly = TRUE)) {
          p <- EnhancedVolcano::EnhancedVolcano(
            data,
            lab = data$genes,
            selectLab = top_genes,
            x = 'avg_log2FC',
            y = 'p_val_adj',
            title = paste0('DEGs for ', input$cell_type, ' (', input$cell_annotation_level, ')'),
            subtitle = subtitle_text,
            xlab = bquote(~Log[2]~ 'fold change (' ~ .(comparison_groups[1]) ~ ' vs ' ~ .(comparison_groups[2]) ~ ')'),
            pCutoff = input$pvalue_cutoff,
            FCcutoff = input$fc_cutoff,
            cutoffLineType = 'twodash',
            cutoffLineWidth = 0.8,
            pointSize = 2.0,
            labSize = params$axis_text_size * 0.3,
            colAlpha = 0.7,
            legendLabels = c('Not sig.', 'Log2 FC', 'P-value', 'P-value & Log2 FC'),
            legendPosition = params$legend_position,
            legendLabSize = params$legend_text_size,
            legendIconSize = 5.0,
            gridlines.minor = FALSE,
            titleLabSize = params$title_size,
            subtitleLabSize = params$title_size - 2,
            axisLabSize = params$axis_title_size,
            captionLabSize = params$axis_text_size,
            # Add explanation annotation
            caption = paste0("Positive values: higher in ", comparison_groups[1],
                            " | Negative values: higher in ", comparison_groups[2])
          )

          return(p)

        } else {
          # Fallback ggplot2 version
          plot_data <- data %>%
            mutate(
              neg_log10_p = -log10(p_val_adj),
              significant_cat = case_when(
                abs(avg_log2FC) > input$fc_cutoff & p_val_adj < input$pvalue_cutoff ~ "Both",
                abs(avg_log2FC) > input$fc_cutoff ~ "FC only",
                p_val_adj < input$pvalue_cutoff ~ "P-value only",
                TRUE ~ "Not significant"
              )
            )

          p <- ggplot(plot_data, aes(x = avg_log2FC, y = neg_log10_p)) +
            geom_point(aes(color = significant_cat), size = 2, alpha = 0.7) +
            scale_color_manual(
              values = c(
                "Both" = "red",
                "FC only" = "orange",
                "P-value only" = "blue",
                "Not significant" = "gray"
              )
            ) +
            geom_hline(yintercept = -log10(input$pvalue_cutoff), linetype = "dashed", color = "red") +
            geom_vline(xintercept = c(-input$fc_cutoff, input$fc_cutoff), linetype = "dashed", color = "red") +
            labs(
              title = paste0('DEGs for ', input$cell_type, ' (', input$cell_annotation_level, ')'),
              subtitle = subtitle_text,
              x = paste0("Log2 Fold Change (", comparison_groups[1], " vs ", comparison_groups[2], ")"),
              y = "-log10(Adjusted P-value)",
              color = "Significance",
              caption = paste0("Positive values: ↑ in ", comparison_groups[1],
                              " | Negative values: ↑ in ", comparison_groups[2])
            ) +
            theme_minimal() +
            theme(
              plot.title = element_text(size = params$title_size, face = "bold"),
              plot.subtitle = element_text(size = params$title_size - 2, color = "darkblue"),
              axis.title = element_text(size = params$axis_title_size),
              axis.text = element_text(size = params$axis_text_size),
              legend.position = params$legend_position,
              legend.title = element_text(size = params$legend_title_size),
              legend.text = element_text(size = params$legend_text_size),
              plot.caption = element_text(size = params$axis_text_size - 1,
                                        color = "darkgray",
                                        style = "italic",
                                        hjust = 0.5)
            )

          # Add top gene labels
          if(length(top_genes) > 0) {
            top_data <- plot_data %>% filter(genes %in% top_genes)
            p <- p + geom_text_repel(
              data = top_data,
              aes(label = genes),
              size = params$axis_text_size * 0.3,
              max.overlaps = input$top_genes_count,
              box.padding = 0.5
            )
          }

          # Add annotation text to top-right corner of plot
          p <- p + annotate("text",
                           x = Inf, y = Inf,
                           label = paste0("Positive: ↑ in ", comparison_groups[1],
                                         "\nNegative: ↑ in ", comparison_groups[2]),
                           hjust = 1.1, vjust = 1.1,
                           size = params$axis_text_size * 0.3,
                           color = "black",
                           fontface = "italic")

          return(p)
        }

      }, error = function(e) {
        plot.new()
        text(0.5, 0.5, paste("Error creating plot:", e$message), cex = 1.2, col = "red", adj = 0.5)
      })
    }, height = function() {
      # # Use plot control height setting
      # params <- plot_params()
      return(600)
    })
  })
}