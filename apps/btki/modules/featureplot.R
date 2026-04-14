# Source plot controls
source("modules/plot_controls.R")

# PBMC Feature Plot Module
featureplot_UI <- function(id) {
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
          if (w === lastW && h === lastH) return; // No change in size, don't send
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

        // Optional: Unbind when Shiny session ends
        $(document).on('shiny:disconnected', function(){
          $(window).off('resize.'+nsId);
        });
      })();
    ", ns("window_size")))),
    column(
      width = 3,
      box(
        title = "Annotation Selection",
        status = "primary",
        solidHeader = TRUE,
        width = NULL,
        textAreaInput(
          ns("gene_input"),
          label = "Enter Genes (comma-separated):",
          placeholder = "e.g., CD3D, CD4, IL7R",
          value = "CD3D, CD4, IL7R",  # Set default value
          rows = 3  # Set initial height
        ),
        # Add button group
        tags$div(
          id = ns("button_group"),  # Add a container ID
          style = "margin-top: 10px;",
          lapply(names(cell_type_markers), function(cell_type) {
            actionButton(
              ns(paste0("btn_", gsub(" ", "_", cell_type))),  # Button ID
              label = cell_type,  # Button text
              class = "btn btn-xs btn-outline-primary",  # Default button style
              style = "margin-right: 5px; margin-bottom: 5px; font-size: 12px; padding: 3px 8px;"  # Adjust font and padding
            )
          })
        ),
        uiOutput(ns("sampling_ui")),  # ← New: Sampling control UI
        actionButton(
          ns("submit_genes"),
          label = "Submit",  # Button label
          class = "btn btn-sm btn-success",  # Submit button style
          style = "margin-top: 10px; font-size: 14px; padding: 5px 10px;"  # Adjust font and padding
        )
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

    # Main Plot Area
    column(
      width = 9,
      box(
        # title = "Feature Plot",
        status = "primary",
        solidHeader = TRUE,
        width = NULL,
        uiOutput(ns("featureplot_ui"))  # Dynamically generate plotOutput
      )
    )
  )
}

featureplot_Server <- function(id) {
# featureplot_Server <- function(id, umap_data, expr_df) {
  moduleServer(id, function(input, output, session) {

    ns <- session$ns

    window_size <- reactive({
      if (is.null(input$window_size)) {
        return(list(width = 1200, height = 800))  # Default value
      }
      input$window_size
    })

    plot_params <- plot_controls_Server("plot_controls", default_params = list(
      title_size        = 12,
      # axis_text_size    = 10,
      axis_title_size   = 8,
      legend_text_size  = 8,
      legend_title_size = 8,
      # legend_position   = "right",
      legend_point_size = 1,
      show_legend       = TRUE
    ))

    # Total cell count
    n_total <- qread(file.path("data/pbmc_feature_plot_cache", "total_cell_number.qs"))

    # Dynamic sampling UI
    output$sampling_ui <- renderUI({
      req(n_total)
      nearest100 <- function(x) {
        if (n_total < 100) return(n_total)               # If total < 100, use all
        y <- round(x / 100) * 100
        y <- max(100, min(y, n_total))
        y
      }
      sizes_raw <- c(n_total/20, n_total/5)
      sizes <- vapply(sizes_raw, nearest100, numeric(1))
      sizes <- unique(sizes)
      lbl <- paste0(sizes, " cells (≈", round(sizes / n_total * 100, 1), "%)")
      choices <- stats::setNames(as.list(sizes), lbl)
      div(
        selectInput(
          ns("sample_cells"),
          label = sprintf("Sampled cell count (Total: %s)", format(n_total, big.mark=",")),
          choices = choices,
          selected = min(sizes)
        )
      )
    })

    # Initialize first button as selected
    observe({
      shinyjs::addClass(selector = paste0("#", session$ns("btn_CD4_T_cells")), class = "btn-primary")
      shinyjs::removeClass(selector = paste0("#", session$ns("btn_CD4_T_cells")), class = "btn-outline-primary")
    })

    # Add event listener for each button
    lapply(names(cell_type_markers), function(cell_type) {
      observeEvent(input[[paste0("btn_", gsub(" ", "_", cell_type))]], {
        # Reset all buttons to unselected state
        lapply(names(cell_type_markers), function(ct) {
          shinyjs::removeClass(selector = paste0("#", session$ns(paste0("btn_", gsub(" ", "_", ct)))), class = "btn-primary")
          shinyjs::addClass(selector = paste0("#", session$ns(paste0("btn_", gsub(" ", "_", ct)))), class = "btn-outline-primary")
        })

        # Set current button as selected
        shinyjs::addClass(selector = paste0("#", session$ns(paste0("btn_", gsub(" ", "_", cell_type)))), class = "btn-primary")
        shinyjs::removeClass(selector = paste0("#", session$ns(paste0("btn_", gsub(" ", "_", cell_type)))), class = "btn-outline-primary")

        # Update input box content
        updateTextAreaInput(
          session,
          "gene_input",
          value = paste(cell_type_markers[[cell_type]], collapse = ", ")  # Fill gene list
        )
      })
    })

    # Process user input gene list
    selected_genes <- eventReactive(input$submit_genes, {
      # Remove spaces and split string
      genes <- strsplit(input$gene_input, ",")[[1]]
      genes <- trimws(genes)  # Remove leading/trailing spaces
      genes <- genes[genes != ""]  # Remove empty strings

      # # Check if genes are in expression data
      # valid_genes <- genes[genes %in% rownames(expr_df)]
      # if (length(valid_genes) == 0) {
      #   showNotification("No valid genes found in the expression data.", type = "error")
      # }
      # valid_genes
      genes
    })

    # Dynamic column count: based on window width
    tile_base <- 350
    tile_gap  <- 40   # Estimate (legend + padding) for conservative column calculation, adjustable
    ncol_dynamic_raw <- reactive({
      req(input$window_size)
      w <- input$window_size$width
      if (is.null(w) || is.na(w)) return(2)
      # Right box occupies 9/12 total width, but here we get window width -> can estimate right area ~ w * 0.70
      avail <- w * 0.70
      max_cols <- max(1, floor(avail / (tile_base + tile_gap)))
      # Limit upper bound (e.g., 5) to avoid legend being too cramped
      max(1, min(max_cols, 5))
    })

    ncol_dynamic <- debounce(ncol_dynamic_raw, 200)

    # Dynamic UI: Set plot height dynamically based on gene count
    output$featureplot_ui <- renderUI({
      ns <- session$ns
      genes <- selected_genes()
      total_plots <- length(genes) + 1
      ncol <- ncol_dynamic()
      nrow <- ceiling(total_plots / ncol)
      plot_height <- nrow * 400

      shinycssloaders::withSpinner(
        plotOutput(ns("featureplot_plot"), height = paste0(plot_height, "px")),
        type = 6,
        color = "#0d6efd"
      )
    })

    # Store cached raw data (UMAP + expression matrix)
    cached_raw_data <- reactiveVal(NULL)

    # Store processed plot data (merged UMAP and gene expression)
    plot_ready_data <- reactiveVal(NULL)

    # 1. Load raw data when user switches sampling size
    observeEvent(input$sample_cells, {
      cat("Selected sample size:", input$sample_cells, "\n")
      catched_data <- qread(
        file.path("data/pbmc_feature_plot_cache",
                  glue::glue("featureplot_data_{as.integer(input$sample_cells)}_cell.qs"))
      )

      # Store raw data
      cached_raw_data(list(
        umap_data = catched_data$umap_data,
        expr_df = catched_data$expr_df
      ))
      rm(catched_data); gc(verbose = FALSE)

      cat("Cached raw data updated with", nrow(cached_raw_data()$umap_data), "cells\n")
    })

    # 2. Prepare plot data when user submits genes or switches sampling
    observeEvent(list(selected_genes(), cached_raw_data()), {
      genes <- selected_genes()
      cached_data <- cached_raw_data()

      # Validate data availability
      if (length(genes) == 0 || is.null(cached_data)) {
        plot_ready_data(NULL)
        return()
      }

      cat("Preparing plot data for", length(genes), "genes\n")

      current_umap <- cached_data$umap_data
      current_expr_df <- cached_data$expr_df
      cat("Using cached data with", nrow(current_umap), "cells\n")

      # Cell order needed
      cells_needed <- current_umap$cell

      # Validate expression matrix contains all sampled cells
      missing_cells <- setdiff(cells_needed, colnames(current_expr_df))
      if (length(missing_cells) > 0) {
        showNotification(sprintf("Expression matrix missing %d sampled cells", length(missing_cells)), type = "error")
        plot_ready_data(NULL)
        return()
      }

      # Extract gene expression by current_umap cell order (rows=genes, cols=cells)
      expr_filtered <- current_expr_df[genes, cells_needed, drop = FALSE]
      if (nrow(expr_filtered) == 0) {
        showNotification("No expression data for genes.", type = "error")
        plot_ready_data(NULL)
        return()
      }

      # Transpose to (rows=cells, cols=genes), row names remain as cells
      expr_mat <- t(as.matrix(expr_filtered))

      # Ensure order consistency (defensive)
      if (!identical(rownames(expr_mat), cells_needed)) {
        expr_mat <- expr_mat[cells_needed, , drop = FALSE]
      }

      # Direct column binding, no join needed (cbind aligns by row order)
      umap_data_with_expr <- cbind(
        current_umap,
        as.data.frame(expr_mat, check.names = FALSE)  # Avoid escaping gene names
      )

      # Store prepared data
      plot_ready_data(umap_data_with_expr)

      # Clean up temporary objects
      rm(expr_filtered, expr_mat); gc(verbose = FALSE)

      cat("Plot data ready:", nrow(umap_data_with_expr), "cells x", ncol(umap_data_with_expr), "columns\n")
    })

    # 3. Feature Plot - Pure plotting logic
    output$featureplot_plot <- renderPlot({
      # Get prepared data
      umap_data_with_expr <- plot_ready_data()

      # Validate data
      validate(
        need(!is.null(umap_data_with_expr), "Please submit genes to generate plots."),
        need(nrow(umap_data_with_expr) > 0, "No data available for plotting.")
      )

      genes <- selected_genes()
      validate(need(length(genes) > 0, "Please enter valid genes."))

      cat("Rendering", length(genes) + 1, "plots with", nrow(umap_data_with_expr), "cells\n")

      plots <- list()

      # Cell Type plot
      if ("celltype_merged.l1" %in% colnames(umap_data_with_expr)) {

        # Define color scale function
        get_color_scale <- function(num_categories) {
          if (num_categories <= 9) {
            scale_color_brewer(palette = "Set1")
          } else if (num_categories <= 12) {
            scale_color_brewer(palette = "Set3")
          } else if (num_categories <= 20) {
            scale_color_viridis_d(option = "plasma")
          } else {
            custom_colors <- colorRampPalette(
              c("#1f78b4", "#33a02c", "#e31a1c", "#ff7f00", "#6a3d9a", "#b15928")
            )(num_categories)
            scale_color_manual(values = custom_colors)
          }
        }

        umap_data_with_expr$celltype_merged.l1 <- as.factor(umap_data_with_expr$celltype_merged.l1)
        num_categories <- length(unique(umap_data_with_expr$celltype_merged.l1))

        p_celltype <- ggplot(
          umap_data_with_expr,
          aes(x = umap_1, y = umap_2, color = celltype_merged.l1)) +
          geom_point(alpha = 0.6, size = 1) +
          get_color_scale(num_categories) +
          labs(title = "Cell Type L1", x = "UMAP 1", y = "UMAP 2", color = "Cell Type") +
          theme_minimal() +
          theme(
            text = element_text(size = plot_params()$axis_text_size),
            plot.title = element_text(size = plot_params()$title_size),
            axis.title = element_text(size = plot_params()$axis_title_size),
            legend.text = element_text(size = plot_params()$legend_text_size),
            legend.title = element_text(size = plot_params()$legend_title_size),
            legend.position = plot_params()$legend_position,
            legend.key.size = unit(0.7, "lines")) +
          guides(color = guide_legend(override.aes = list(size = plot_params()$legend_point_size))) +
          coord_fixed(ratio = 1)
        plots[["celltype_merged.l1"]] <- p_celltype
      } else {
        showNotification("Column 'celltype_merged.l1' not found in UMAP data.", type = "error")
      }

      # Gene expression plots
      for (gene in genes) {
        if (!gene %in% colnames(umap_data_with_expr)) {
          showNotification(paste("Gene", gene, "not found in joined data.", sep=" "), type = "error")
          next
        }
        p <- ggplot(
          umap_data_with_expr,
          aes(x = umap_1, y = umap_2, color = .data[[gene]])
        ) +
          geom_point(alpha = 0.6, size = 1) +
          scale_color_viridis_c(option = "plasma") +
          labs(title = gene, x = "UMAP 1", y = "UMAP 2", color = "Expression") +
          theme_minimal() +
          theme(
            text = element_text(size = plot_params()$axis_text_size),
            plot.title = element_text(size = plot_params()$title_size),
            axis.title = element_text(size = plot_params()$axis_title_size),
            legend.text = element_text(size = plot_params()$legend_text_size),
            legend.title = element_text(size = plot_params()$legend_title_size),
            legend.position = plot_params()$legend_position
          ) +
          coord_fixed(ratio = 1)
        plots[[gene]] <- p
      }

      if (length(plots) == 1) return(plots[[1]])
      cowplot::plot_grid(plotlist = plots, ncol = ncol_dynamic())
    }, res = 96)
  })
}