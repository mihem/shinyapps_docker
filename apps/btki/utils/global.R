# ============================================================================
# Global Configuration and Data Loading
# ============================================================================

# Load required libraries
suppressPackageStartupMessages({
library(shiny)
library(shinydashboard)
library(shinyjs)
library(DT)
library(plotly)
library(ggplot2)
library(dplyr)
library(qs)
library(future)
library(promises)
library(viridis)
library(RColorBrewer)
library(purrr)
library(effsize)
library(Seurat)
library(EnhancedVolcano)
library(DESeq2)
library(tibble)
library(tidyr)
library(tidyverse)
library(ggpubr)
library(viridisLite)
library(ggrepel)
library(bslib)
library(ComplexHeatmap)
library(circlize)
library(shinycssloaders)
library(scales)
library(gridExtra) # For arranging multiple plots
library(shinyFeedback)
library(shinyWidgets)
library(shinymanager)
library(ggpmisc)
library(crayon)
library(jsonify)
})

# Define NULL coalescing operator (if not already defined)
if (!exists("%||%")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

# Set up future for async processing
plan(multisession, workers = 4)
# memory.limit(size = 64000)  # Set to 64 GB
options(future.availableCores.methods = "custom")
options(future.custom.cores = 4)

cell_type_markers <- list(
  "CD4 T cells" = c("CD3D", "CD4", "IL7R"),
  "CD8 T cells" = c("CD3D", "CD8A", "CD8B"),
  "Treg cells" = c("FOXP3", "IL2RA", "CTLA4"),
  "NK cells" = c("NCAM1", "NKG7", "GNLY", "KLRD1"),
  "B cells" = c("CD19", "CD79A", "MS4A1"),
  "Monocytes" = c("CD14", "LYZ", "FCGR3A"),
  "Dendritic cells" = c("FCER1A", "CST3", "ITGAX"),
  "Plasma cells" = c("MZB1", "SDC1", "JCHAIN"),
  "RBC precursors" = c("HBB", "HBA1", "HBA2"),
  "MAIT cells" = c("TRAV1-2", "KLRB1", "SLC4A10"),
  "ILC cells" = c("ID2", "IL7R", "KIT", "RORC"),
  "HSPC cells" = c("CD34", "PROM1", "AVP"),
  "PDC cells" = c("AXL", "SIGLEC6", "IL3RA", "CLEC10A")
)

# Define color and style functions
green_bold        <- bold$green
yellow_bold       <- bold$yellow
lemon_yellow_bold <- bold$yellow$bgBlack
red_bold          <- bold$red

# Global configuration
config <- list(
  # Data paths
  pbmc_data_dir = "PBMC/results",
  csf_data_dir = "CSF/00_result",

  # Plot defaults
  default_width = 800,
  default_height = 600,
  default_font_size = 12,

  # Color schemes
  color_schemes = list(
    default = c("#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd"),
    viridis = viridis::viridis(8),
    set1 = RColorBrewer::brewer.pal(8, "Set1"),
    set2 = RColorBrewer::brewer.pal(8, "Set2")
  ),

  # Performance settings
  cache_timeout = 3600,  # 1 hour
  debounce_delay = 500   # 500ms
)

# Helper functions
GenerateBoxplots <- function(plot_data, pdf_file = NULL, rows=3, cols=3, width=10, height=10,
                             x_var = "treatment_hour", x_lab = "Treatment & Hour",
                             title_size = 14, axis_text_size = 12, legend_position = "none") {
  # plot_data: Named list, each element is a data frame
  # pdf_file:  NULL -> Don't write file, return plot list directly; otherwise write to PDF and return plot list (invisible)

  if (length(plot_data) == 0) {
    warning("plot_data is empty, returning empty list")
    return(list())
  }

  # Calculate total plots and layout
  total_plots    <- length(plot_data)
  plots_per_page <- rows * cols

  # Generate all plots
  all_plots <- vector("list", total_plots)
  names(all_plots) <- names(plot_data)

  for (cluster_name in names(plot_data)) {
    df <- plot_data[[cluster_name]]
    if (nrow(df) == 0) {
      warning(sprintf("Sub-data '%s' is empty, skipping", cluster_name))
      next
    }
    p <- ggplot(df, aes(x = !!sym(x_var), y = percent, fill = !!sym(x_var))) +
      geom_boxplot(outlier.size = 0.8) +
      geom_dotplot(binaxis = 'y', stackdir = 'center', dotsize = 0.5) +
      labs(title = cluster_name, x = x_lab, y = "% of Total Cells") +
      theme_minimal() +
      theme(
        legend.position = legend_position,
        axis.text.x = element_text(angle = 45, vjust = 1, hjust = 1, size = axis_text_size),
        axis.text.y = element_text(size = axis_text_size),
        axis.title = element_text(size = axis_text_size),
        plot.title = element_text(size = title_size, hjust = 0.5)
      )
    all_plots[[cluster_name]] <- p
  }

  # If not writing PDF, return plot list directly
  if (is.null(pdf_file)) {
    return(all_plots)
  }

  # Check directory before writing PDF
  dir_path <- dirname(pdf_file)
  if (!dir.exists(dir_path)) {
    stop("The specified directory does not exist: ", dir_path)
  }

  # Open PDF device
  pdf(pdf_file, width = width, height = height)
  on.exit({
    dev.off()
  }, add = TRUE)

  num_pages <- ceiling(total_plots / plots_per_page)
  for (i in seq_len(num_pages)) {
    idx_start <- (i - 1) * plots_per_page + 1
    idx_end   <- min(i * plots_per_page, total_plots)
    page_plots <- all_plots[idx_start:idx_end]
    # Filter NULL (if there's empty data)
    page_plots <- page_plots[!vapply(page_plots, is.null, logical(1))]
    if (length(page_plots) == 0) next
    grid.arrange(grobs = page_plots, nrow = rows, ncol = cols)
  }

  invisible(all_plots)
}

#' Pad Label for Alignment
#'
#' Pads a label string to a specified width with trailing spaces
#' for consistent formatting in log messages.
#'
#' @param label Character. Label to pad.
#' @param width Integer. Target width for padding.
#'
#' @return Character. Padded label string.
#'
#' Global variables used: None
#'
# Format log label
pad_label <- function(label, width) {
  w <- nchar(label, type = "width")
  if (w < width) paste0(label, strrep(" ", width - w)) else label
}

# format_number_custom <- function(x) {
#   sapply(x, function(val) {
#     if (is.na(val)) return(NA)

#     if (val == 0 || val %% 1 == 0) {
#       # Integer or 0, return directly
#       return(as.character(as.integer(val)))
#     }

#     abs_val <- abs(val)

#     if (abs_val >= 1) {
#       # Non-zero integer part, keep at most 2 decimal places, remove trailing zeros
#       out <- formatC(val, format = "f", digits = 2)
#       out <- sub("\\.?0+$", "", out)
#       return(out)
#     } else if (abs_val >= 0.01) {
#       # Regular decimal, keep at most 2 places, remove trailing zeros
#       out <- formatC(val, format = "f", digits = 2)
#       out <- sub("\\.?0+$", "", out)
#       return(out)
#     } else {
#       # Very small value, keep until two consecutive non-zero digits appear
#       str_val <- sub("^0\\.", "", sprintf("%.20f", val))  # Remove "0.", keep 20 decimal places
#       non_zero_seq <- gregexpr("[1-9]{2,}", str_val)[[1]][1]
#       if (is.na(non_zero_seq) || non_zero_seq == -1) {
#         # No two consecutive non-zeros, keep first non-zero plus two digits
#         first_nonzero <- regexpr("[1-9]", str_val)[1]
#         cutoff <- first_nonzero + 1
#       } else {
#         cutoff <- non_zero_seq + 1
#       }
#       trimmed <- substr(str_val, 1, cutoff)
#       return(paste0("0.", trimmed))
#     }
#   }, USE.NAMES = FALSE)
# }



# # Apply function to all numeric columns
# format_dataframe_numeric <- function(df) {
#   df[] <- lapply(df, function(col) {
#     if (is.numeric(col)) {
#       format_number_custom(col)
#     } else {
#       col
#     }
#   })
#   return(df)
# }

# # Apply to all data frames in list
# process_list_of_dataframes <- function(lst) {
#   lapply(lst, format_dataframe_numeric)
# }

# library(qs)

# # Load data
# metadata <- qread("data/10_shiny_app_metadata.qs")
# metadata_cell <- qread("data/10_shiny_app_metadata_cell_raw.qs")
# metadata_cell_filtered <- qread("data/10_shiny_app_metadata_cell.qs")

# # Format data
# metadata_fmt <- process_list_of_dataframes(metadata)
# metadata_cell_fmt <- process_list_of_dataframes(metadata_cell)
# metadata_cell_filtered_fmt <- process_list_of_dataframes(metadata_cell_filtered)


# # Example: Save as new files
# qsave(metadata_fmt, "data/10_shiny_app_metadata_formatted.qs")
# qsave(metadata_cell_fmt, "data/10_shiny_app_metadata_cell_raw_formatted.qs")
# qsave(metadata_cell_filtered_fmt, "data/10_shiny_app_metadata_cell_formatted.qs")