# Source plot controls
source("modules/plot_controls.R")

# Disable ComplexHeatmap automatic rasterization messages
# Keep use_raster automatically enabled (improves large matrix drawing performance), but don't display messages
ht_opt$message <- FALSE

# PBMC Marker Heatmap Module
marker_heatmap_UI <- function(id) {
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
        title = "Heatmap Controls",
        status = "primary",
        solidHeader = TRUE,
        width = NULL,
        selectInput(
          ns("p_value_threshold"),
          label = "P-value Threshold",
          choices = c(0.001, 0.01, 0.05),
          selected = 0.05
        ),
        selectInput(
          ns("topn"),
          label = "Top N Genes per Cluster",
          choices = c(5, 10, 15, 20, 25, 30),
          selected = 10
        ),
        selectInput(
          ns("cell_number_limit"),
          label = "Cells Number Per Cluster",
          choices = c("100" = 100, "200" = 200, "300" = 300, "400" = 400, "500" = 500, "1000" = 1000 #, "NO Limit" = "NoLimit"
          ),
          selected = 400
        ),
        div(
          actionButton(
            ns("generate_heatmap"),
            label = "Generate Heatmap",
            # class = "btn btn-primary",
            style = "margin-top: 10px; font-size: 14px; padding: 5px 10px;"  # Adjust font size and padding
          )
        )
      ),
      box(
        title = "Plot Controls",
        status = "primary",
        solidHeader = TRUE,
        collapsible = TRUE,
        collapsed = TRUE,
        width = NULL,
        plot_controls_UI(ns("plot_controls")),
        checkboxInput(
          ns("show_labels"),
          label = "Show Labels",
          value = FALSE
        )
      )
    ),
    column(
      width = 9,
      box(
        id = ns("heatmap_box"),
        # title = "Marker Heatmap",
        status = "primary",
        solidHeader = TRUE,
        width = NULL,
        uiOutput(ns("heatmap_ui"))  # Remove spinner here
      )
    )
  )
}

marker_heatmap_Server <- function(id, DEG, metadata, expr, cached_data, tissue) {
  moduleServer(id, function(input, output, session) {
    # Get control parameters
    plot_params <- plot_controls_Server("plot_controls")

    # Monitor box size
    window_size <- reactive({
      req(input$window_size)
      input$window_size
    })

    heatmap_data <- eventReactive(input$generate_heatmap, {
      showNotification("Calculating heatmap data...", duration = NULL, id = "heatmap_notify", type = "message")

      cache_file <- file.path(
        glue::glue("data/{tolower(tissue)}_marker_heatmap_cache"),
        sprintf("heatmap_pval%.3f_top%d_cells%s.qs",
                as.numeric(input$p_value_threshold),
                as.integer(input$topn),
                ifelse(input$cell_number_limit == "NoLimit", "NoLimit", input$cell_number_limit)
        )
      )

      print(glue::glue("Loading cached {tissue} heatmap data from: {basename(cache_file)}"))

      # Record start time
      start_time <- Sys.time()

      result <- qread(
        file = cache_file,
        nthreads = 4
      )

      # Calculate read time
      end_time <- Sys.time()
      load_time <- as.numeric(difftime(end_time, start_time, units = "secs"))
      file_size <- file.info(cache_file)$size / (1024 * 1024)  # MB

      # Display loading information
      msg <- sprintf("✓ Loaded in %.2f seconds (File size: %.2f MB, Speed: %.2f MB/s)",
                     load_time, file_size, file_size / load_time)
      print(msg)
      showNotification(msg, duration = 3, type = "message")

      removeNotification(id = "heatmap_notify")
      return(result)
    })

    # Dynamically generate heatmap box
    output$heatmap_ui <- renderUI({
      ns <- session$ns
      box_width  <- window_size()$width
      box_height <- window_size()$height - 90

      # Put spinner on plotOutput
      shinycssloaders::withSpinner(
        plotOutput(ns("heatmap_plot"), height = paste0(box_height-50, "px")),
        type = 6,
        color = "#0d6efd"
      )
    })


    output$heatmap_plot <- renderPlot({
      req(heatmap_data())

      # Record plot start time
      plot_start_time <- Sys.time()
      print("===> [INFO] Starting to draw heatmap...")

      heatmap_data <- heatmap_data()

      # Use data directly, no intermediate variables needed
      column_split_param <- heatmap_data$col_anno_df[[heatmap_data$sort_var]]

      # Draw heatmap
      hm <- Heatmap(
        heatmap_data$plot_data,
        name = "Expression",
        col = colorRamp2(
          c(min(heatmap_data$plot_data), 0, max(heatmap_data$plot_data)),
          c("blue", "white", "red")
        ),
        cluster_rows = FALSE,
        cluster_columns = FALSE,
        show_row_names = input$show_labels,
        show_column_names = FALSE,
        row_names_gp = gpar(fontsize = plot_params()$axis_text_size),
        column_title = NULL,
        row_title = NULL,
        top_annotation = heatmap_data$col_annotation,
        left_annotation = heatmap_data$row_annotation,
        row_split = heatmap_data$row_anno_df$Gene_Cluster,
        column_split = column_split_param,
        heatmap_legend_param = list(
          title = "Expression",
          title_gp = gpar(fontsize = plot_params()$legend_title_size),
          labels_gp = gpar(fontsize = plot_params()$legend_text_size)
        )
      )

      # Calculate plot time
      plot_end_time <- Sys.time()
      plot_time <- as.numeric(difftime(plot_end_time, plot_start_time, units = "secs"))

      # Display plot information
      msg <- sprintf("✓ Heatmap rendered in %.2f seconds (Dimensions: %d genes × %d cells)",
                     plot_time,
                     nrow(heatmap_data$plot_data),
                     ncol(heatmap_data$plot_data))
      print(msg)

      # Return heatmap object
      return(hm)
    })
  })
}

heatmap_data_func <- function(metadata, expr, markers_df,
                              hm_colors = c("#4575b4","white","#d73027"),
                              hm_limit = c(-2, 0, 2),
                              cell_number_limit = NULL,
                              n = 8,
                              sort_var = "annotated",  # Default sort by annotated
                              anno_vars = c("treatment", "timepoint"),
                              cached_file = NULL) {
  metadata$cell_name <- rownames(metadata)
  genes_all <- rownames(expr)

  # filter out every row that contains a duplicate name in the column "gene"
  markers_df <- markers_df[!duplicated(markers_df$gene),]

  # Sort by cell count, reorganize gene order
  # 1. Count each cell type
  celltypes_sorted <- metadata[, sort_var] %>%
    table() %>%
    sort(decreasing = TRUE) %>%
    names()

  # 2. Reset annotated as factor, levels sorted by count
  metadata[[sort_var]]<- factor(metadata[[sort_var]], levels = celltypes_sorted)
  # 3. Sort markers_df according to celltypes_sorted
  markers_df <- markers_df %>%
    filter(.data$gene %in% genes_all) %>%
    arrange(desc(.data$avg_log2FC)) %>%
    group_by(.data$cluster) %>%
    filter(row_number() <= n) %>%
    mutate(cluster = factor(cluster, levels = celltypes_sorted)) %>%
    arrange(cluster)

  markers_df <- markers_df[!duplicated(markers_df$gene),]

  # 1. Maximum 500 cells per cell type group
  if (!is.null(cell_number_limit)) {
    set.seed(123)  # Ensure reproducibility
    metadata <- metadata %>%
      group_by(!!!syms(sort_var)) %>%
      slice_sample(n = cell_number_limit) %>%
      ungroup()
  }

  # 2. Flexible sorting, only sort by existing columns
  # Check available sort columns
  available_cols <- sort_var
  for (anno in anno_vars) {
    if (anno %in% colnames(metadata)) {
      available_cols <- c(available_cols, anno)
    }
  }
  cat("===> [DEBUG] Sort columns:", paste(available_cols, collapse = ", "), "\n")

  # Use dynamic sorting
  metadata_sorted <- metadata %>%
    arrange(across(all_of(available_cols)))

  # 3. Get sorted cell names
  cells_sorted <- metadata_sorted$cell_name

  # 4. Extract expression matrix & sort by column
  plot_data <- expr[markers_df$gene, cells_sorted, drop = FALSE]


  # Prepare column annotation data - only include existing columns
  col_anno_df <- metadata_sorted[, available_cols, drop = FALSE]


  # Prepare row annotation data (cell type to which gene belongs)
  row_anno_df <- data.frame(
    Gene_Cluster = markers_df$cluster,
    row.names    = markers_df$gene
  )

  # === Dynamically create color configuration ===
  annotation_colors <- list()

  color_schemes <- list(
    scales::hue_pal()(length(celltypes_sorted)),
    c("blue", "purple", "cyan", "pink"),
    c("red", "orange", "yellow", "green")
  )

  for (i in 1:length(available_cols)) {
    anno               <- available_cols[i]
    unique_annos       <- unique(col_anno_df[[anno]])
    anno_colors        <- color_schemes[[i]][1:length(unique_annos)]
    names(anno_colors) <- unique_annos
    annotation_colors[[anno]] <- anno_colors
    cat("===> [DEBUG] Color configuration completed", length(annotation_colors[[anno]]), "\n")
  }

  # === Dynamically create column annotation ===
  if (ncol(col_anno_df) > 0) {
    # Build parameters for HeatmapAnnotation
    annotation_params <- list()
    legend_params     <- list()

    for (col_name in colnames(col_anno_df)) {
      annotation_params[[col_name]] <- col_anno_df[[col_name]]
      legend_params[[col_name]] <- list(
        title    = col_name,
        title_gp = grid::gpar(fontsize = 12)
      )
    }

    # Create column annotation
    col_annotation <- do.call(ComplexHeatmap::HeatmapAnnotation, c(
      annotation_params,
      list(
        col                     = annotation_colors,
        annotation_name_gp      = grid::gpar(fontsize = 10),
        annotation_legend_param = legend_params
      )
    ))
  } else {
    # If no annotation columns, create empty annotation
    col_annotation <- NULL
    cat("===> [WARNING] No available column annotations\n")
  }

  # Create row annotation
  row_annotation <- rowAnnotation(
    Gene_Cluster = row_anno_df$Gene_Cluster,
    col          = list(Gene_Cluster = annotation_colors[[sort_var]]),  # Use same color
    annotation_name_gp = grid::gpar(fontsize = 10),
    annotation_legend_param = list(
      Gene_Cluster = list(title = "Gene Cluster", title_gp = gpar(fontsize = 12))
    ),
    width = unit(0.5, "cm")
  )

  # Return data
  result <- list(
    plot_data = plot_data,
    col_annotation = col_annotation,
    row_annotation = row_annotation,
    row_anno_df = row_anno_df,
    col_anno_df = col_anno_df,
    sort_var = sort_var
  )

  cat("===> [DEBUG] Heatmap data preparation completed, dimensions:",
      nrow(plot_data), "x", ncol(plot_data), "\n")
  if (!is.null(cached_file)) {
    qsave(result, file = cached_file, nthreads = 4)
  }

  return(result)
}