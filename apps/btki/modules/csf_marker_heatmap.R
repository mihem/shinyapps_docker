# Source plot controls
source("modules/plot_controls.R")

# PBMC Marker Heatmap Module
csf_marker_heatmap_UI <- function(id) {
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

        // Optional: unbind on Shiny session disconnect
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
          choices = c(0.05),
          selected = 0.05
        ),
        selectInput(
          ns("topn"),
          label = "Top N Genes per Cluster",
          choices = c(10),
          selected = 10
        ),
        selectInput(
          ns("cell_number_limit"),
          label = "Cells Number Per Cluster",
          choices = c("NO Limit"),
          selected = "NO Limit"
        ),
        div(
          actionButton(
            ns("generate_heatmap"),
            label = "Generate Heatmap",
            # class = "btn btn-primary",
            style = "margin-top: 10px; font-size: 14px; padding: 5px 10px;"  # Adjust font and padding
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
        uiOutput(ns("heatmap_ui"))
      )
    )
  )
}

csf_marker_heatmap_Server <- function(id, DEG, metadata, expr, cached_data, tissue) {
  moduleServer(id, function(input, output, session) {

    plot_params <- plot_controls_Server("plot_controls")

    window_size <- reactive({
      req(input$window_size)
      input$window_size
    })

    heatmap_data <- eventReactive(input$generate_heatmap, {
      showNotification("Calculating heatmap data...", duration = NULL, id = "heatmap_notify", type = "message")

      if (is.null(cached_data)) {

        cached_file <- glue::glue("data/cached_{tolower(tissue)}_heatmap_data.qs")

        if (input$cell_number_limit == "NO Limit") {
          cell_number_limit <- NULL
        } else {
          cell_number_limit <- as.integer(input$cell_number_limit)
        }

        result <- heatmap_data_func(
          metadata = metadata,
          expr = expr,
          markers_df = DEG %>% filter(p_val_adj < input$p_value_threshold),
          n = input$topn,
          cell_number_limit = cell_number_limit,
          sort_var = "annotated",
          anno_vars = c("treatment", "timepoint")
        )

        qsave(result, file = cached_file)
      } else {
        result <- cached_data
      }

      removeNotification(id = "heatmap_notify")
      return(result)
    })

    output$heatmap_ui <- renderUI({
      ns <- session$ns
      box_width <- window_size()$width
      box_height <- window_size()$height - 90

      # Place spinner on plotOutput
      shinycssloaders::withSpinner(
        plotOutput(ns("heatmap_plot"), height = paste0(box_height-50, "px")),
        type = 6,
        color = "#0d6efd"
      )
    })


    output$heatmap_plot <- renderPlot({
      req(heatmap_data())
      heatmap_data <- heatmap_data()

      plot_data       <- heatmap_data$plot_data
      col_annotation  <- heatmap_data$col_annotation
      row_annotation  <- heatmap_data$row_annotation
      row_anno_df     <- heatmap_data$row_anno_df
      col_anno_df     <- heatmap_data$col_anno_df
      sort_var        <- heatmap_data$sort_var


      column_split_param <- col_anno_df[[sort_var]]


      Heatmap(
        plot_data,
        name = "Expression",
        col = colorRamp2(c(min(plot_data), 0, max(plot_data)), c("blue", "white", "red")),
        cluster_rows = FALSE,
        cluster_columns = FALSE,
        show_row_names = input$show_labels,
        show_column_names = FALSE,
        row_names_gp = gpar(fontsize = plot_params()$axis_text_size),
        column_title = NULL,
        row_title = NULL,
        top_annotation = col_annotation,   # May be NULL
        left_annotation = row_annotation,
        row_split = row_anno_df$Gene_Cluster,
        column_split = column_split_param,  # Flexible setting
        heatmap_legend_param = list(
          title = "Expression",
          title_gp = gpar(fontsize = plot_params()$legend_title_size),
          labels_gp = gpar(fontsize = plot_params()$legend_text_size)
        )
      )
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

  # 1. Maximum cells per cell type group
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
  cat("===> [Debug] Sort columns:", paste(available_cols, collapse = ", "), "\n")

  # Use dynamic sorting
  metadata_sorted <- metadata %>%
    arrange(across(all_of(available_cols)))

  # 3. Get sorted cell names
  cells_sorted <- metadata_sorted$cell_name

  # 4. Extract expression matrix & sort by columns
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
    cat("===> [Debug] Color configuration complete", length(annotation_colors[[anno]]), "\n")
  }

  # === Dynamically create column annotation ===
  if (ncol(col_anno_df) > 0) {
    # Build HeatmapAnnotation parameters
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
    # If no annotation columns exist, create empty annotation
    col_annotation <- NULL
    cat("===> [Warning] No available column annotations\n")
  }

  # Create row annotation
  row_annotation <- rowAnnotation(
    Gene_Cluster = row_anno_df$Gene_Cluster,
    col          = list(Gene_Cluster = annotation_colors[[sort_var]]),  # Use same colors
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

  cat("===> [Debug] Heatmap data preparation complete, dimensions:",
      nrow(plot_data), "x", ncol(plot_data), "\n")
  if (!is.null(cached_file)) {
    qsave(result, file = cached_file, nthreads = 4)
  }

  return(result)
}