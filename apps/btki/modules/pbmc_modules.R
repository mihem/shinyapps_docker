# ============================================================================
# PBMC Analysis Modules
# ============================================================================

# Source plot controls
source("modules/plot_controls.R")

# PBMC Cell Type Marker Table Module
celltype_marker_table_UI <- function(id) {
  ns <- NS(id)

  tagList(
    tags$head(
      tags$style(HTML("
        .flexible-table-box .box-body {
          height: auto !important;
          max-height: none !important;
          overflow: visible !important;
          padding-bottom: 15px;
        }
        .flexible-table-box {
          height: auto !important;
          min-height: 200px;
        }
        .dataTables_wrapper {
          margin-bottom: 10px;
        }
      "))
    ),
    fluidRow(
      column(
        width = 12,
        box(
          status = "primary",
          solidHeader = TRUE,
          width = NULL,
          class = "flexible-table-box",
          uiOutput(ns("dynamic_tables"))
        )
      )
    )
  )
}

celltype_marker_table_Server <- function(id, DEG, cluster = NULL) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Decide whether to split data based on cluster parameter
    if (is.null(cluster)) {
      # If no cluster, display single table directly
      output$dynamic_tables <- renderUI({
        DT::dataTableOutput(ns("celltype_markers_table"))
      })

      # Render single table
      output$celltype_markers_table <- DT::renderDataTable({
        DT::datatable(
          DEG,
          options = list(
            pageLength = 10,
            lengthMenu = c(10, 25, 50, 100, 200),
            searchDelay = 500,
            processing = TRUE,
            dom = "Bfrtip",
            scrollX = TRUE,
            scrollCollapse = FALSE,
            responsive = TRUE,
            autoWidth = FALSE,
            fixedColumns = TRUE
          ),
          extensions = 'Buttons',
          rownames = TRUE,
          class = "display compact nowrap cell-border"
        )
      }, server = TRUE)

    } else {
      # If cluster exists, split data by cluster

      # Check if cluster column exists
      if (!cluster %in% colnames(DEG)) {
        output$dynamic_tables <- renderUI({
          div(
            class = "text-danger",
            style = "padding: 20px; text-align: center;",
            h4("Error: Cluster column not found"),
            p(paste("Column '", cluster, "' does not exist in the data."))
          )
        })
        return()
      }

      # Get all unique cluster values and sort
      clusters <- sort(unique(DEG[[cluster]]))

      # Split data by cluster
      DEG_split <- DEG %>%
        dplyr::arrange(!!sym(cluster)) %>%
        dplyr::group_by(!!sym(cluster)) %>%
        dplyr::group_split() %>%
        stats::setNames(clusters)

      # Dynamically generate tabs - using tabPanel approach
      output$dynamic_tables <- renderUI({
        tabs <- list()

        # Create tabPanel for each cluster
        tabs <- lapply(clusters, function(cluster_name) {
          tabPanel(
            title = cluster_name,
            value = paste0("cluster_", make.names(cluster_name)),
            shinycssloaders::withSpinner(
              DT::DTOutput(ns(paste0("table_", make.names(cluster_name)))),
              type = 6,
              color = "#0d6efd"
            )
          )
        })

        # Use do.call and tabsetPanel to create tab collection
        do.call(tabsetPanel, c(
          list(id = ns("cluster_tabs"), selected = paste0("cluster_", make.names(clusters[1]))),
          tabs
        ))
      })

      # Create corresponding table for each cluster
      lapply(clusters, function(cluster_name) {
        # Use make.names to ensure valid variable name
        table_id <- paste0("table_", make.names(cluster_name))

        output[[table_id]] <- DT::renderDataTable({
          cluster_data <- DEG_split[[cluster_name]]

          DT::datatable(
            cluster_data,
            options = list(
              pageLength = 10,
              lengthMenu = c(10, 25, 50, 100, 200),
              searchDelay = 500,
              processing = TRUE,
              dom = "Bfrtip",
              scrollX = TRUE,
              scrollCollapse = FALSE,
              responsive = TRUE,
              autoWidth = FALSE,
              fixedColumns = TRUE
            ),
            extensions = 'Buttons',
            rownames = TRUE,
            caption = paste("Markers for", cluster_name),
            class = "display compact nowrap cell-border"
          )
        })
      })
    }
  })
}

# Cell Composition Module
cell_composition_table_UI <- function(id) {
  ns <- NS(id)

  fluidRow(
    column(
      width = 12,
      box(
        title = "Cell Composition",
        status = "primary",
        solidHeader = TRUE,
        width = NULL,
        uiOutput(ns("cell_type_tabs")) # Dynamically generate tabs
      )
    )
  )
}

cell_composition_table_Server <- function(id, meta_df, cached_data, tissue = "PBMC",
                                          features = c("celltype_merged.l2", "sample", "treatment", "treatment_hour", "timepoint")) {
  moduleServer(id, function(input, output, session) {
    if (is.null(cached_data)) {

      # 🔥 Check available features columns
      available_features <- intersect(features, colnames(meta_df))
      missing_features   <- setdiff(features, available_features)

      cat("===> [DEBUG] Available feature columns:", paste(available_features, collapse = ", "), "\n")
      if (length(missing_features) > 0) {
        cat("===> [WARNING] Missing feature columns:", paste(missing_features, collapse = ", "), "\n")
      }

      # Required columns check
      required_features <- c("celltype_merged.l2", "sample")
      missing_required <- setdiff(required_features, available_features)

      if (length(missing_required) > 0) {
        stop(paste("Error: Missing required columns:", paste(missing_required, collapse = ", ")))
      }

      CELL_TYPES <- unique(meta_df$celltype_merged.l2) %>% sort()
      meta_df[["annotated"]]  <- meta_df$celltype_merged.l2
      meta_df[["subject_id"]] <- gsub("PBMC_(\\d+)_(Pre|Post).*", "\\1", meta_df$sample)

      # 🔥 Dynamically build select statement, only select existing columns
      # Build basic select columns
      select_cols <- c("subject_id", "sample", "annotated")

      # Add optional feature columns
      if ("treatment" %in% available_features) {
        select_cols <- c(select_cols, "treatment")
      }
      if ("treatment_hour" %in% available_features) {
        select_cols <- c(select_cols, "treatment_hour")
      }
      if ("timepoint" %in% available_features) {
        select_cols <- c(select_cols, "timepoint")
      }

      cat("===> [DEBUG] Final selected columns:", paste(select_cols, collapse = ", "), "\n")

      # 🔥 Dynamically build group_by statement
      group_cols <- select_cols  # Use all available columns for grouping

      CELL_TYPE_COUNTS <- meta_df %>%
        dplyr::select(all_of(select_cols)) %>%  # Use all_of() to ensure safe selection
        group_by(across(all_of(group_cols))) %>%
        summarise(cell_number = n(), .groups = "drop") %>%
        group_by(sample) %>%
        mutate(total_cell_number = sum(cell_number)) %>%
        mutate(percent = cell_number / total_cell_number * 100) %>%
        ungroup()

      # Split by cell type (for reuse by table and boxplot)
      CELL_TYPE_COUNTS_SPLIT <- CELL_TYPE_COUNTS |>
        dplyr::arrange(annotated) |>
        dplyr::group_by(annotated) |>
        dplyr::group_split() |>
        stats::setNames(CELL_TYPES)

      result <- list(CELL_TYPES = CELL_TYPES, CELL_TYPE_COUNTS_SPLIT = CELL_TYPE_COUNTS_SPLIT)
      qsave(result, file = paste0("data/cached_", tolower(tissue), "_cell_composition_table.qs"))

    } else {
      CELL_TYPE_COUNTS_SPLIT <- cached_data$CELL_TYPE_COUNTS_SPLIT
      CELL_TYPES             <- cached_data$CELL_TYPES
    }

    # --- Table tab set ---
    output$cell_type_tabs <- renderUI({
      ns <- session$ns

      # 🔥 Use tabPanel instead of bslib
      tabs <- lapply(CELL_TYPES, function(cell_type) {
        tabPanel(
          title = cell_type,
          value = paste0("celltype_", make.names(cell_type)),
          shinycssloaders::withSpinner(
            DT::DTOutput(ns(paste0("table_", make.names(cell_type)))),
            type = 6,
            color = "#0d6efd"
          )
        )
      })

      # Use do.call and tabsetPanel to create tab collection
      do.call(tabsetPanel, c(
        list(id = ns("cell_type_tabs"), selected = paste0("celltype_", make.names(CELL_TYPES[1]))),
        tabs
      ))
    })

    lapply(CELL_TYPES, function(cell_type) {
      # Use make.names to ensure valid variable name
      table_id <- paste0("table_", make.names(cell_type))

      output[[table_id]] <- DT::renderDataTable({
        DT::datatable(
          CELL_TYPE_COUNTS_SPLIT[[cell_type]],
          options = list(
            pageLength = 10,
            lengthMenu = c(10, 25, 50, 100, 200),
            searchDelay = 500,
            processing = TRUE,
            dom = "Bfrtip",
            scrollX = TRUE,
            scrollCollapse = FALSE,
            responsive = TRUE,
            autoWidth = FALSE,
            fixedColumns = TRUE
          ),
          extensions = 'Buttons',
          rownames = FALSE,
          caption = paste("Composition for", cell_type),
          class = "display compact nowrap cell-border"
        )
      })
    })
  })
}
