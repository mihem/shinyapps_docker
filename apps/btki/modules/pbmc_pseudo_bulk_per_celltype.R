# Source plot controls
source("modules/plot_controls.R")

# UI for Pseudo-Bulk Analysis
pseudo_bulk_UI <- function(id) {
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
      width = 3,
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
          ns("cell_type_selection"),
          "Select Cell Type(s):",
          choices = NULL,
          selected = NULL,
          multiple = FALSE
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
          ns("min_count_filter"),
          "Minimum Count Filter:",
          value = 10,
          min = 1,
          max = 100,
          step = 1
        ),
        checkboxInput(
          ns("show_labels"),
          "Show Gene Labels on Plot",
          value = FALSE
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
      width = 9,
      box(
        status = "primary",
        solidHeader = TRUE,
        width = NULL,
        tabsetPanel(
          id = ns("results_tabs"),
          tabPanel(
            title = "Volcano Plots",
            icon = icon("fas fa-chart-scatter"),
            br(),
            uiOutput(ns("volcano_plots_ui"))
          ),
          tabPanel(
            title = "Results Tables",
            icon = icon("table"),
            br(),
            uiOutput(ns("results_tables_ui"))
          )
        )
      )
    )
  )
}

# Server for Pseudo-Bulk Analysis
pseudo_bulk_Server <- function(id, meta_df, pseudo_bulk_result_list, tissue = "PBMC") {
  moduleServer(id, function(input, output, session) {
    req(!is.null(pseudo_bulk_result_list) && length(pseudo_bulk_result_list) > 0)
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
        legend_position    = "bottom",
        p_cutoff          = 0.05,
        fc_cutoff         = 0.5,
        point_size        = 2.0,
        alpha             = 1.0,
        x_min             = -2,
        x_max             = 2,
        y_max             = 5
      )
    )

    # 2. Check data availability
    data_available <- reactive({
      req(pseudo_bulk_result_list)

      # Check if data structure is correct
      has_annotation_levels <- length(names(pseudo_bulk_result_list)) > 0
      has_cell_types <- FALSE

      if (has_annotation_levels) {
        # Check if at least one annotation level has cell types
        for (level in names(pseudo_bulk_result_list)) {
          if (length(names(pseudo_bulk_result_list[[level]])) > 0) {
            has_cell_types <- TRUE
            break
          }
        }
      }

      return(has_annotation_levels && has_cell_types)
    })

    # 3. Update first dropdown - Cell Annotation Level
    observe({
      req(pseudo_bulk_result_list)

      annotation_levels <- names(pseudo_bulk_result_list)

      if(length(annotation_levels) > 0) {
        updateSelectInput(
          session = session,
          inputId = "cell_annotation_level",
          choices = annotation_levels,
          selected = annotation_levels[1]
        )
      }
    })

    # 4. Update second dropdown - Cell Type Selection (based on first dropdown selection)
    observe({
      req(input$cell_annotation_level, pseudo_bulk_result_list)

      if (input$cell_annotation_level %in% names(pseudo_bulk_result_list)) {
        cell_types <- names(pseudo_bulk_result_list[[input$cell_annotation_level]])

        if(length(cell_types) > 0) {
          # Add "All cell types" option
          choices <- c("All cell types" = "all_celltype")
          celltype_choices <- setNames(cell_types, cell_types)
          choices <- c(choices, celltype_choices)

          updateSelectInput(
            session = session,
            inputId = "cell_type_selection",
            choices = choices,
            selected = "all_celltype"
          )
        }
      }
    })

    # 5. Update button state
    observe({
      if (data_available() &&
          !is.null(input$cell_annotation_level) &&
          !is.null(input$cell_type_selection)) {

        # Use JavaScript to directly update button state
        shinyjs::runjs(sprintf("
          var btn = $('#%s');
          btn.html('<i class=\"fa fa-rocket\"></i> Run Analysis!');
          btn.removeClass('btn-secondary disabled').addClass('btn-primary');
          btn.css({'opacity': '1', 'cursor': 'pointer'});
          btn.prop('disabled', false);
          ", ns("run_analysis")))
        shinyjs::enable(ns("run_analysis"))
      } else {
        updateActionButton(
          session,
          "run_analysis",
          label = HTML('<i class="fa fa-exclamation-triangle"></i> Data Error'),
          class = "btn btn-secondary",
          # disabled = TRUE,
          style = "opacity: 0.6; cursor: not-allowed; min-width: 120px;"
        )
        # shinyjs::disable(ns("run_analysis"))
      }
    })

    # Generate warning message
    output$warning_message <- renderUI({
      if(data_available()) {
        div(
          class = "alert alert-success",
          style = "margin-top: 15px;",
          p(icon("check"), strong("Ready for analysis!"), "Select cell annotation level and cell type(s).")
        )
      } else {
        div(
          class = "alert alert-warning",
          style = "margin-top: 15px;",
          h5(icon("exclamation-triangle"), "Analysis Unavailable"),
          p("No pseudo-bulk analysis data available.")
        )
      }
    })

    # 6. Analysis logic - Process cached data or perform new DESeq2 analysis
    analysis_results <- eventReactive(input$run_analysis, {
      req(input$cell_annotation_level, input$cell_type_selection, pseudo_bulk_result_list)

      # Generate cache key
      cache_key <- paste(
        input$cell_annotation_level,
        input$cell_type_selection,
        input$fc_cutoff,
        input$pvalue_cutoff,
        input$min_count_filter,
        sep = "_"
      )

      cache_file <- file.path("data", paste0("cached_pbmc_pseudo_bulk_cache_", cache_key, ".qs"))

      # Check if cache exists
      if (file.exists(cache_file)) {
        showNotification("Loading cached results...", type = "message", duration = 200)

        tryCatch({
          cached_results <- readRDS(cache_file)
          showNotification("Cached results loaded successfully!", type = "message", duration = 300)
          return(cached_results)
        }, error = function(e) {
          showNotification("Failed to load cache, running fresh analysis...", type = "warning", duration = 300)
        })
      }

      # If no cache or cache loading failed, perform new analysis
      showNotification("Starting Pseudo-bulk DESeq2 analysis...", type = "message", duration = 200)

      tryCatch({
        # Step 1: Generate pseudo-bulk matrix
        pseudo_bulk_data <- pseudo_bulk_result_list[[input$cell_annotation_level]]

        # Step 2: Construct metadata
        colnames_rna <- colnames(pseudo_bulk_data$RNA)
        meta <- data.frame(
          colname   = colnames_rna,
          annotated = sapply(strsplit(colnames_rna, "_"), `[`, 1),
          sample    = sapply(strsplit(colnames_rna, "_"), `[`, 2),
          timepoint = sapply(strsplit(colnames_rna, "_"), `[`, 3)
        )

        print(head(meta))

        # Step 3: Analyze by cell type
        results_list <- list()

        for (ct in unique(meta$annotated)) {
          tryCatch({
            cols_ct   <- meta$colname[meta$annotated == ct]
            counts_ct <- pseudo_bulk_data$RNA[, cols_ct, drop = FALSE]
            meta_ct   <- meta[meta$annotated == ct, ]

            rownames(meta_ct) <- meta_ct$colname
            counts_ct         <- counts_ct[, rownames(meta_ct), drop = FALSE]

            if (nrow(meta_ct) < 2 || length(unique(meta_ct$timepoint)) < 2) {
              message(paste("Skipping cell type", ct, "insufficient sample size"))
              next
            }

            dds <- DESeq2::DESeqDataSetFromMatrix(
              countData = counts_ct,
              colData   = meta_ct,
              design    = ~ sample + timepoint
            )
            keep <- rowSums(counts(dds) >= input$min_count_filter) >= 3
            dds <- dds[keep, ]

            dds <- DESeq(dds)
            res <- results(dds, contrast = c("timepoint", "Post", "Pre"))

            res <- res %>%
              as.data.frame() %>%
              rownames_to_column(var = "genes") %>%
              mutate(
                cell_type = ct,
                significance = ifelse(abs(log2FoldChange) > input$fc_cutoff & padj < input$pvalue_cutoff, "Significant", "Not significant")
              )

            # Automatically format all numeric columns to 3 significant figures
            numeric_cols <- sapply(res, is.numeric)
            res[numeric_cols] <- lapply(res[numeric_cols], function(x) signif(x, 3))

            top_genes <- res %>%
              filter(padj < input$pvalue_cutoff, abs(log2FoldChange) > input$fc_cutoff) %>%
              mutate(direction = ifelse(log2FoldChange > input$fc_cutoff, "up", "down")) %>%
              group_by(direction) %>%
              arrange(desc(abs(log2FoldChange))) %>%
              slice_head(n = 5) %>%
              pull(genes)

            keyvals <- ifelse(res$log2FoldChange < -input$fc_cutoff & res$padj < input$pvalue_cutoff,
                              'royalblue',
                              ifelse(res$log2FoldChange > input$fc_cutoff & res$padj < input$pvalue_cutoff, 'gold', 'black'))
            keyvals[is.na(keyvals)] <- 'black'
            names(keyvals)[keyvals == 'gold'] <- 'high in Post'
            names(keyvals)[keyvals == 'black'] <- 'mid'
            names(keyvals)[keyvals == 'royalblue'] <- 'low in Post'

            results_list[[ct]] <- list(
              result    = res,
              top_genes = top_genes,
              keyvals   = keyvals,
              celltype = ct
            )
          }, error = function(e) {
            message(paste("Analysis failed for cell type", ct, ":", e$message))
          })
        }

        # Determine which cell types to analyze based on selection
        if (input$cell_type_selection == "all_celltype") {
          celltypes_to_analyze <- names(pseudo_bulk_data)
        } else {
          celltypes_to_analyze <- input$cell_type_selection
        }

        if (length(results_list) == 0) {
          stop("No results available for the selected cell type(s)")
        }

        # Prepare results to cache
        analysis_result <- list(
          results_list           = results_list,
          cell_annotation_level  = input$cell_annotation_level,
          cell_type_selection    = input$cell_type_selection,
          fc_cutoff              = input$fc_cutoff,
          pvalue_cutoff          = input$pvalue_cutoff,
          min_count_filter       = input$min_count_filter,
          show_labels            = input$show_labels,
          cache_timestamp        = Sys.time()
        )

        # Save to cache
        tryCatch({
          # Ensure data directory exists
          if (!dir.exists("data")) {
            dir.create("data", recursive = TRUE)
          }

          saveRDS(analysis_result, cache_file)
          showNotification("Analysis completed and cached successfully!", type = "message", duration = 300)
        }, error = function(e) {
          showNotification("Analysis completed but caching failed", type = "warning", duration = 300)
          message("Cache save error: ", e$message)
        })

        return(analysis_result)

      }, error = function(e) {
        showNotification(paste("Error in analysis:", e$message), type = "error", duration = 500)
        return(NULL)
      })
    })

    # 7. Storage state management
    computed_plots <- reactiveVal(NULL)
    loading_state <- reactiveVal(FALSE)

    # 8. Monitor parameter changes and redraw plots
    observeEvent({
      plot_params()
      input$show_labels
    }, {
      # Only redraw if plots have already been generated
      results <- analysis_results()
      if (!is.null(results) && !is.null(computed_plots())) {

        loading_state(TRUE)

        shinyjs::delay(150, {
          tryCatch({
            plot_list <- list()

            for (ct in names(results$results_list)) {
              result_data <- results$results_list[[ct]]
              res         <- result_data$result
              top_genes   <- result_data$top_genes
              keyvals     <- result_data$keyvals

              params <- plot_params()
              p <- create_volcano_plot(res, top_genes, keyvals, ct, params, input$show_labels)
              plot_list[[ct]] <- p
            }

            computed_plots(plot_list)
            loading_state(FALSE)

          }, error = function(e) {
            loading_state(FALSE)
            message("Plot update error: ", e$message)
          })
        })
      }
    }, ignoreInit = TRUE)

    # 9. Volcano plot UI
    output$volcano_plots_ui <- renderUI({
      results <- analysis_results()

      if(is.null(results)) {
        return(
          div(
            style = "text-align: center; padding: 50px; color: #6c757d;",
            icon("chart-line", style = "font-size: 48px; margin-bottom: 20px;"),
            h4("Select parameters and click 'Run Analysis!'"),
            p("Choose cell annotation level and cell type(s) to generate volcano plots.")
          )
        )
      }

      # Calculate expected height
      expected_plots_count <- length(results$results_list)
      if (expected_plots_count == 0) {
        return(
          div(
            style = "text-align: center; padding: 50px; color: #dc3545;",
            icon("exclamation-triangle", style = "font-size: 48px; margin-bottom: 20px;"),
            h4("No plots available"),
            p("The selected cell type(s) may not have sufficient data for analysis.")
          )
        )
      }

      plot_size <- 500
      box_width <- window_size()$width * 0.9  # Consider padding
      num_plots_per_row <- max(1, floor(box_width / plot_size))
      num_rows <- ceiling(expected_plots_count / num_plots_per_row)
      box_height <- num_rows * plot_size

      # Show different content based on loading state
      if (loading_state()) {
        div(
          style = paste0("height: ", box_height, "px; display: flex; align-items: center; justify-content: center;"),
          div(
            style = "text-align: center;",
            div(
              class = "spinner-border text-primary",
              role = "status",
              style = "width: 3rem; height: 3rem;"
            ),
            h4("Updating volcano plots...", style = "margin-top: 20px; color: #6c757d;")
          )
        )
      } else {
        # Generate plots
        plot_list <- list()

        for (ct in names(results$results_list)) {
          result_data <- results$results_list[[ct]]
          res <- result_data$result
          top_genes <- result_data$top_genes
          keyvals <- result_data$keyvals

          params <- plot_params()
          p <- create_volcano_plot(res, top_genes, keyvals, ct, params, input$show_labels)
          plot_list[[ct]] <- p
        }

        computed_plots(plot_list)

        plotOutput(ns("volcano_combined_plot"), height = paste0(box_height, "px"))
      }
    })

    # 10. Render combined plot
    output$volcano_combined_plot <- renderPlot({
      plots <- computed_plots()
      req(plots)

      if (length(plots) > 0) {
        plot_size <- 350
        box_width <- window_size()$width * 0.9
        num_plots_per_row <- max(1, floor(box_width / plot_size))

        p <- ggpubr::ggarrange(
          plotlist = plots,
          ncol = num_plots_per_row,
          nrow = ceiling(length(plots) / num_plots_per_row)
        )

        title_text <- paste0("Pseudo-bulk DESeq2 Analysis: ",
                            input$cell_annotation_level, " - ",
                            if(input$cell_type_selection == "all_celltype") "All Cell Types" else input$cell_type_selection)

        annotate_figure(p, top = text_grob(title_text, size = 16))
      }
    })

    # 11. Results table UI
    output$results_tables_ui <- renderUI({
      results <- analysis_results()
      req(results)

      ns <- session$ns
      celltypes_to_show <- names(results$results_list)

      if (length(celltypes_to_show) == 0) {
        return(
          div(
            style = "text-align: center; padding: 50px; color: #6c757d;",
            h4("No results available"),
            p("Run the analysis first to see results tables.")
          )
        )
      }

      tabsetPanel(
        id = ns("results_table_tabs"),
        !!!lapply(celltypes_to_show, function(ct) {
          tabPanel(
            title = ct,
            br(),
            DT::dataTableOutput(ns(paste0("results_table_", ct)))
          )
        })
      )
    })

    # 12. Render results tables
    observe({
      results <- analysis_results()
      req(results)

      for (ct in names(results$results_list)) {
        local({
          ct_local <- ct
          output[[paste0("results_table_", ct_local)]] <- DT::renderDataTable({

            result_data <- results$results_list[[ct_local]]$result

            # Format numeric columns
            display_data <- result_data %>%
              mutate(
                pvalue = sprintf("%.2e", pvalue %||% 0),
                padj = sprintf("%.2e", padj),
                log2FoldChange = sprintf("%.3f", log2FoldChange),
                baseMean = sprintf("%.1f", baseMean %||% 0)
              )

            # Rename columns
            names(display_data)[names(display_data) == "genes"]          <- "Gene"
            names(display_data)[names(display_data) == "log2FoldChange"] <- "Log2 Fold Change"
            names(display_data)[names(display_data) == "padj"]           <- "Adjusted P-value"
            names(display_data)[names(display_data) == "pvalue"]         <- "P-value"
            names(display_data)[names(display_data) == "baseMean"]       <- "Base Mean"
            names(display_data)[names(display_data) == "significance"]   <- "Significance"

            DT::datatable(
              display_data,
              options = list(
                pageLength = 20,
                lengthMenu = c(20, 50, 100),
                scrollX = TRUE,
                dom = 'Bfrtip',
                buttons = c('copy', 'csv', 'excel')
              ),
              extensions = 'Buttons',
              rownames = FALSE,
              class = "display compact nowrap cell-border"  # Add more CSS classes
            )
          })
        })
      }
    })
  })
}

# Extract plot function (keep consistent with original code)
create_volcano_plot <- function(res, top_genes, keyvals, ct, params, show_labels) {
  # Add parameter validation and default values
  if (is.null(params)) {
    params <- list(
      p_cutoff = 0.05,
      fc_cutoff = 0.5,
      point_size = 2.0,
      label_size = 4.0,
      alpha = 1.0,
      x_min = -2,
      x_max = 2,
      y_max = 5,
      legend_position = "bottom"
    )
  }

  # Ensure all parameters have default values
  params$p_cutoff         <- if (is.null(params$p_cutoff) || is.na(params$p_cutoff)) 0.05 else params$p_cutoff
  params$fc_cutoff        <- if (is.null(params$fc_cutoff) || is.na(params$fc_cutoff)) 0.5 else params$fc_cutoff
  params$point_size       <- if (is.null(params$point_size) || is.na(params$point_size)) 2.0 else params$point_size
  params$alpha            <- if (is.null(params$alpha) || is.na(params$alpha)) 1.0 else params$alpha
  params$x_min            <- if (is.null(params$x_min) || is.na(params$x_min)) -2 else params$x_min
  params$x_max            <- if (is.null(params$x_max) || is.na(params$x_max)) 2 else params$x_max
  params$y_max            <- if (is.null(params$y_max) || is.na(params$y_max)) 5 else params$y_max
  params$legend_position  <- if (is.null(params$legend_position)) "bottom" else params$legend_position
  params$legend_text_size <- if (is.null(params$legend_text_size)) 10 else params$legend_text_size
  params$axis_text_size   <- if (is.null(params$axis_text_size)) 12 else params$axis_text_size

  select_lab <- if (show_labels %||% FALSE) top_genes else NULL

  p <- EnhancedVolcano(res,
                  lab = res$genes,
                  selectLab = select_lab,
                  x = 'log2FoldChange',
                  y = 'padj',
                  xlab = bquote(~Log[2]~ 'fold change'),
                  title = ct,
                  colCustom = keyvals,
                  pCutoff = params$p_cutoff,
                  FCcutoff = params$fc_cutoff,
                  cutoffLineType = 'twodash',
                  cutoffLineWidth = 0,
                  axisLabSize = params$axis_text_size,
                  # pointSize = params$point_size,
                  # labSize = params$legend_text_size,
                  pointSize = 2.0,
                  labSize = 4.0,
                  colAlpha = params$alpha,
                  caption = "",
                  subtitle = "",
                  legendLabels = c('Not sig.','Log (base 2) FC','p-value', 'p-value & Log (base 2) FC'),
                  legendPosition = params$legend_position,
                  legendLabSize = params$legend_text_size,
                  legendIconSize = 5.0,
                  gridlines.minor = FALSE,
                  xlim = c(params$x_min, params$x_max),
                  ylim = c(0, params$y_max)) +
    theme(
      legend.position = params$legend_position,
      legend.direction = "horizontal",
      legend.box = "horizontal"
    )

  return(p)
}