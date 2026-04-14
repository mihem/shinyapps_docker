# R/data_registry.R
# Data Resource Registry - Unified management of all data dependencies

# Three resource types:

# Blocking resources: Small files required for first screen, loaded synchronously
# Async resources: Large files, loaded asynchronously in background
# Cached resources: Pre-computed results with fallback mechanism

library(qs)

#' Data Resources Registry
#'
#' Central configuration registry for all data resources used in the Shiny application.
#' This module defines a comprehensive list of data sources with their properties,
#' loading strategies, and dependency relationships.
#'
#' @details
#' The registry categorizes resources into:
#' - Blocking resources: Small files loaded synchronously for immediate UI display
#' - Async resources: Large files loaded asynchronously in background
#' - Cached resources: Pre-computed results with fallback to raw computation
#'
#' Each resource configuration includes:
#' - path: File system path to the data file
#' - type: Category of data (metadata, expression, etc.)
#' - size_mb: Estimated file size in megabytes
#' - blocking: Whether to load synchronously (TRUE) or asynchronously (FALSE)
#' - priority: Loading order priority (lower numbers = higher priority)
#' - concurrent: Whether resource can be loaded concurrently with others
#' - description: Human-readable description
#' - load_fn: Function to load the resource from file
#' - fallback: Optional fallback resources if primary fails
#' - skip_if_exists: Optional path to check; if file exists, skip loading this resource
#'
#' Global variables used:
#' - qs::qread: Primary data loading function for .qs files
#'
#' @examples
#' # Get all blocking resources
#' blocking <- get_blocking_resources()
#'
#' # Get resources sorted by priority
#' sorted <- get_resources_by_priority(blocking = TRUE)
#'
#' # Validate all resource paths
#' missing <- validate_data_resources()
#'
# Data resource configuration
data_resources <- list(
  # ========== First-screen blocking resources (small files, synchronous loading) ==========
  # csf_metadata_raw = list(
  #   path = "data/shinyapp_csf_10_S06_metadata_list_raw.qs",
  #   type = "metadata",
  #   size_mb = 1,
  #   blocking = TRUE,
  #   priority = 1,
  #   concurrent = FALSE,
  #   description = "CSF sample summary metadata",
  #   load_fn = function(path) {
  #     if (!requireNamespace("qs", quietly = TRUE)) {
  #       library(qs)
  #     }
  #     qs::qread(path)
  #   }
  # ),
  # csf_metadata_filtered = list(
  #   path = "data/shinyapp_csf_11_S06_metadata_list_filtered.qs",
  #   type = "metadata",
  #   size_mb = 1,
  #   blocking = TRUE,
  #   priority = 1,
  #   concurrent = FALSE,
  #   description = "CSF sample summary metadata",
  #   load_fn = function(path) {
  #     if (!requireNamespace("qs", quietly = TRUE)) {
  #       library(qs)
  #     }
  #     qs::qread(path)
  #   }
  # ),

  csf_metadata_2_in_1 = list(
    path = "data/shinyapp_csf_11_metadata_two_in_one.qs",
    type = "metadata",
    size_mb = 50,
    blocking = TRUE,
    priority = 1,
    concurrent = FALSE,
    description = "CSF Sample Metadata",
    load_fn = function(path) {
      qs::qread(path)
    }
  ),

  pbmc_metadata_3_in_1 = list(
    path = "data/shinyapp_pbmc_10_metadata_three_in_one.qs",
    type = "metadata",
    size_mb = 600,
    blocking = FALSE,
    priority = 2,
    concurrent = FALSE,
    description = "PBMC Sample Metadata",
    load_fn = function(path) {
      qs::qread(path)
    }
  ),

  # pbmc_metadata_summary = list(
  #   path = "data/shinyapp_pbmc_10_metadata.qs",
  #   type = "metadata",
  #   size_mb = 1,
  #   blocking = TRUE,
  #   priority = 1,
  #   concurrent = FALSE,
  #   description = "PBMC sample summary metadata",
  #   load_fn = function(path) {
  #     qs::qread(path)
  #   }
  # ),

  # pbmc_metadata_cell = list(
  #   path = "data/shinyapp_pbmc_10_metadata_cell_raw.qs",
  #   type = "metadata",
  #   size_mb = 2,
  #   blocking = TRUE,
  #   priority = 1,
  #   concurrent = FALSE,
  #   description = "PBMC cell-level raw metadata",
  #   load_fn = function(path) {
  #     qs::qread(path)
  #   }
  # ),

  # pbmc_metadata_cell_filtered = list(
  #   path = "data/shinyapp_pbmc_10_metadata_cell.qs",
  #   type = "metadata",
  #   size_mb = 2,
  #   blocking = TRUE,
  #   priority = 1,
  #   concurrent = FALSE,
  #   description = "PBMC cell-level filtered metadata",
  #   load_fn = function(path) {
  #     qs::qread(path)
  #   }
  # ),

  adt_features_slim = list(
    path = "data/shinyapp_pbmc_41_S02_adt_features_df_slim.qs",
    type = "features",
    size_mb = 5,
    blocking = FALSE,
    priority = 2,
    concurrent = FALSE,
    description = "ADT feature dataframe (slim version)",
    load_fn = function(path) {
      qs::qread(path)
    }
  ),

  adt_correction_stats = list(
    path = "data/shinyapp_pbmc_40_S6_adt_correction_stats.qs",
    type = "stats",
    size_mb = 3,
    blocking = FALSE,
    priority = 2,
    concurrent = FALSE,
    description = "ADT correction statistics plot",
    load_fn = function(path) {
      qs::qread(path)
    }
  ),

  adt_rna_correlation = list(
    path = "data/shinyapp_pbmc_41_S04_adt_rna_correlation.qs",
    type = "correlation",
    size_mb = 8,
    blocking = FALSE,
    priority = 2,
    concurrent = FALSE,
    description = "ADT-RNA cell type correlation data",
    load_fn = function(path) {
      qs::qread(path)
    }
  ),

  # ========== High-priority async resources (UMAP and core visualizations) ==========
  csf_umap_plot_data = list(
    path = "data/shinyapp_csf_20_S09_4_STACAS_plot_df.qs",
    type = "embedding",
    size_mb = 15,
    blocking = FALSE,
    priority = 10,
    concurrent = TRUE,
    description = "CSF UMAP dimension reduction coordinate data",
    load_fn = function(path) {
      qs::qread(path)
    }
  ),

  pbmc_umap_plot_data = list(
    path = "data/shinyapp_pbmc_21_S07_STACAS_plot_df.qs",
    type = "embedding",
    size_mb = 15,
    blocking = FALSE,
    priority = 10,
    concurrent = TRUE,
    description = "PBMC UMAP dimension reduction coordinate data",
    load_fn = function(path) {
      qs::qread(path)
    }
  ),

  csf_expression_data = list(
    path = "data/shinyapp_csf_20_S09_4_STACAS_rna_data_expr.qs",
    type = "expression",
    size_mb = 500,
    blocking = FALSE,
    priority = 10,
    concurrent = TRUE,
    description = "CSF RNA expression data",
    load_fn = function(path) {
      qs::qread(path)
    }
  ),

  # pbmc_expression_data = list(
  #   path = "data/shinyapp_pbmc_21_S07_STACAS_rna_data_expr.qs",
  #   type = "expression",
  #   size_mb = 50,
  #   blocking = FALSE,
  #   priority = 10,
  #   concurrent = TRUE,
  #   description = "PBMC RNA expression data",
  #   load_fn = function(path) {
  #     qs::qread(path)
  #   }
  # ),

  csf_celltype_marker_results = list(
    path = "data/shinyapp_csf_23_S2_heatmap_celltype_deg.qs",
    type = "deg_table",
    size_mb = 8,
    blocking = FALSE,
    priority = 20,
    concurrent = TRUE,
    description = "CSF Cell Type differential expression gene analysis results",
    # skip_if_exists = "data/cached_csf_heatmap_data.qs",
    load_fn = function(path) {
      qs::qread(path)
    }
  ),

  pbmc_celltype_marker_results = list(
    path = "data/shinyapp_pbmc_23_S2_deg_celltype_heatmap.qs",
    type = "deg_table",
    size_mb = 8,
    blocking = FALSE,
    priority = 20,
    concurrent = TRUE,
    description = "PBMC Cell Type differential expression gene analysis results",
    # skip_if_exists = "data/cached_pbmc_heatmap_data.qs",
    load_fn = function(path) {
      qs::qread(path)
    }
  ),

  # ========== Medium-priority async resources ==========
  csf_expression_scaled = list(
    path = "data/shinyapp_csf_20_S09_4_STACAS_integrated_scaledata_expr.qs",
    type = "expression_matrix",
    size_mb = 120,
    blocking = FALSE,
    priority = 50,
    concurrent = FALSE,  # Large file, avoid concurrency
    description = "CSF normalized integrated expression matrix",
    skip_if_exists = "data/cached_csf_heatmap_data.qs",
    load_fn = function(path) {
      qs::qread(path)
    }
  ),

  # pbmc_expression_scaled = list(
  #   path = "data/shinyapp_pbmc_21_S07_STACAS_integrated_scaledata_expr.qs",
  #   type = "expression_matrix",
  #   size_mb = 120,
  #   blocking = FALSE,
  #   priority = 50,
  #   concurrent = FALSE,  # Large file, avoid concurrency
  #   description = "Normalized integrated expression matrix",
  #   skip_if_exists = "data/cached_pbmc_heatmap_data.qs",
  #   load_fn = function(path) {
  #     qs::qread(path)
  #   }
  # ),

  heatmap_metadata_csf = list(
    path = "data/shinyapp_csf_23_S2_heatmap_metadata_annotated_treatment_hour.qs",
    type = "metadata",
    size_mb = 10,
    blocking = FALSE,
    priority = 40,
    concurrent = TRUE,
    description = "CSF heatmap metadata",
    skip_if_exists = "data/cached_csf_heatmap_data.qs",
    load_fn = function(path) {
      qs::qread(path)
    }
  ),

  # heatmap_metadata_pbmc = list(
  #   path = "data/shinyapp_pbmc_23_S2_metadata_annotated_timepoint_treatment.qs",
  #   type = "metadata",
  #   size_mb = 10,
  #   blocking = FALSE,
  #   priority = 40,
  #   concurrent = TRUE,
  #   description = "Heatmap metadata",
  #   skip_if_exists = "data/cached_pbmc_heatmap_data.qs",
  #   load_fn = function(path) {
  #     qs::qread(path)
  #   }
  # ),

  seurat_meta_csf = list(
    path = "data/shinyapp_csf_20_S09_4_STACAS_metadata.qs",
    type = "metadata",
    size_mb = 5,
    blocking = FALSE,
    priority = 80,
    concurrent = FALSE,  # Large file, process separately
    description = "Complete CSF Seurat metadata dataframe",
    load_fn = function(path) {
      qs::qread(path)
    }
  ),

  seurat_meta_pbmc = list(
    path = "data/shinyapp_pbmc_21_S07_4_STACAS_metadata.qs",
    type = "metadata",
    size_mb = 30,
    blocking = FALSE,
    priority = 80,
    concurrent = FALSE,  # Large file, process separately
    description = "Complete PBMC Seurat metadata dataframe",
    load_fn = function(path) {
      qs::qread(path)
    }
  ),

  # seurat_object_csf = list(
  #   path = "data/20_csf_S08_1_seurat_standard_pipeline_STACAS_final.qs",
  #   type = "seurat_object",
  #   size_mb = 200,
  #   blocking = FALSE,
  #   priority = 80,
  #   concurrent = FALSE,  # Large file, process separately
  #   description = "Complete CSF Seurat object",
  #   skip_if_exists = "data/cached_csf_cell_composition_table.qs",
  #   load_fn = function(path) {
  #     qs::qread(path)
  #   }
  # ),

  # seurat_object_pbmc = list(
  #   path = "data/20_pbmc_S07_seurat_integrated_STACAS_standard_pipeline.qs",
  #   type = "seurat_object",
  #   size_mb = 200,
  #   blocking = FALSE,
  #   priority = 80,
  #   concurrent = FALSE,  # Large file, process separately
  #   description = "Complete PBMC Seurat object",
  #   skip_if_exists = "data/cached_pbmc_cell_composition_table.qs",
  #   load_fn = function(path) {
  #     qs::qread(path)
  #   }
  # ),

  de_result_list_csf = list(
    path = "data/shinyapp_csf_31_10_findmarker_results.qs",
    type = "metadata",
    size_mb = 1,
    blocking = FALSE,
    priority = 80,
    concurrent = FALSE,  # Large file, process separately
    description = "CSF cell type differential expression analysis result list",
    # skip_if_exists = "data/cached_pbmc_cell_composition_table.qs",
    load_fn = function(path) {
      qs::qread(path)
    }
  ),

  de_result_list_pbmc = list(
    path = "data/shinyapp_pbmc_30_06_findmarker_results.qs",
    type = "metadata",
    size_mb = 1,
    blocking = FALSE,
    priority = 80,
    concurrent = FALSE,  # Large file, process separately
    description = "PBMC cell type differential expression analysis result list",
    # skip_if_exists = "data/cached_pbmc_cell_composition_table.qs",
    load_fn = function(path) {
      qs::qread(path)
    }
  ),

  pseudo_bulk_result_list_pbmc = list(
    path = "data/shinyapp_pbmc_30_06_pseudo_bulk_result_list.qs",
    type = "metadata",
    size_mb = 20,
    blocking = FALSE,
    priority = 80,
    concurrent = FALSE,  # Large file, process separately
    description = "PBMC cell type pseudo-bulk analysis result list",
    load_fn = function(path) {
      qs::qread(path)
    }
  ),

  adt_gene_pair_df_pbmc = list(
    path = "data/shinyapp_pbmc_40_S1_antibody_isotype_pairs.xlsx",
    type = "metadata",
    size_mb = 1,
    blocking = FALSE,
    priority = 90,
    concurrent = TRUE,
    description = "PBMC ADT-gene pairing dataframe",
    load_fn = function(path) {
      readxl::read_xlsx(path)
    }
  ),

  # ========== Cached files (prioritized over raw computation) ==========
  cached_csf_heatmap = list(
    path = "data/cached_csf_heatmap_data.qs",
    type = "cached_plot_data",
    size_mb = 25,
    blocking = FALSE,
    priority = 30,
    concurrent = TRUE,
    description = "Cached CSF heatmap data",
    fallback = c("csf_expression_scaled", "csf_heatmap_metadata"),
    load_fn = function(path) {
      if(file.exists(path)) qs::qread(path) else NULL
    }
  ),

  cached_pbmc_heatmap = list(
    path = "data/cached_pbmc_heatmap_data.qs",
    type = "cached_plot_data",
    size_mb = 25,
    blocking = FALSE,
    priority = 30,
    concurrent = TRUE,
    description = "Cached PBMC heatmap data",
    fallback = c("pbmc_expression_scaled", "pbmc_heatmap_metadata"),
    load_fn = function(path) {
      if(file.exists(path)) qs::qread(path) else NULL
    }
  ),

  # cached_csf_composition_table = list(
  #   path = "data/cached_csf_cell_composition_table.qs",
  #   type = "cached_analysis",
  #   size_mb = 5,
  #   blocking = FALSE,
  #   priority = 60,
  #   concurrent = TRUE,
  #   description = "Cached CSF cell composition table",
  #   fallback = "seurat_object",
  #   load_fn = function(path) {
  #     if(file.exists(path)) qs::qread(path) else NULL
  #   }
  # ),

  # cached_pbmc_composition_table = list(
  #   path = "data/cached_pbmc_cell_composition_table.qs",
  #   type = "cached_analysis",
  #   size_mb = 5,
  #   blocking = FALSE,
  #   priority = 60,
  #   concurrent = TRUE,
  #   description = "Cached PBMC cell composition table",
  #   fallback = "seurat_object",
  #   load_fn = function(path) {
  #     if(file.exists(path)) qs::qread(path) else NULL
  #   }
  # ),

  # cached_csf_composition_boxplot = list(
  #   path = "data/cached_csf_cell_composition_boxplot.qs",
  #   type = "cached_analysis",
  #   size_mb = 8,
  #   blocking = FALSE,
  #   priority = 60,
  #   concurrent = TRUE,
  #   description = "Cached CSF cell composition boxplot",
  #   fallback = "seurat_object",
  #   load_fn = function(path) {
  #     if(file.exists(path)) qs::qread(path) else NULL
  #   }
  # ),

  # cached_pbmc_composition_boxplot = list(
  #   path = "data/cached_pbmc_cell_composition_boxplot.qs",
  #   type = "cached_analysis",
  #   size_mb = 8,
  #   blocking = FALSE,
  #   priority = 60,
  #   concurrent = TRUE,
  #   description = "Cached PBMC cell composition boxplot",
  #   fallback = "seurat_object",
  #   load_fn = function(path) {
  #     if(file.exists(path)) qs::qread(path) else NULL
  #   }
  # ),

  cached_csf_wilcoxon = list(
    path = "data/cached_csf_wilcoxon_results_df.qs",
    type = "cached_analysis",
    size_mb = 12,
    blocking = FALSE,
    priority = 70,
    concurrent = TRUE,
    description = "Cached CSF Wilcoxon test results",
    fallback = "seurat_object_csf",
    load_fn = function(path) {
      if(file.exists(path)) qs::qread(path) else NULL
    }
  ),

  cached_pbmc_wilcoxon = list(
    path = "data/cached_pbmc_wilcoxon_results_df.qs",
    type = "cached_analysis",
    size_mb = 12,
    blocking = FALSE,
    priority = 70,
    concurrent = TRUE,
    description = "Cached PBMC Wilcoxon test results",
    fallback = "seurat_object_pbmc",
    load_fn = function(path) {
      if(file.exists(path)) qs::qread(path) else NULL
    }
  ),

  cached_propeller = list(
    path = "data/cached_pbmc_propeller_statistics_ordered.qs",
    type = "cached_analysis",
    size_mb = 6,
    blocking = FALSE,
    priority = 70,
    concurrent = TRUE,
    description = "Cached Propeller statistics results",
    fallback = "seurat_object",
    load_fn = function(path) {
      if (!requireNamespace("qs", quietly = TRUE)) {
        library(qs)
      }
      if(file.exists(path)) qs::qread(path) else NULL
    }
  ),

  cached_paired_ttest = list(
    path = "data/cached_pbmc_paired_ttest.qs",
    type = "cached_analysis",
    size_mb = 4,
    blocking = FALSE,
    priority = 70,
    concurrent = TRUE,
    description = "Cached paired t-test results",
    fallback = "seurat_object",
    load_fn = function(path) {
      if (!requireNamespace("qs", quietly = TRUE)) {
        library(qs)
      }
      if(file.exists(path)) qs::qread(path) else NULL
    }
  ),

  cached_de_analysis = list(
    path = "data/cached_pbmc_de_analysis.qs",
    type = "cached_analysis",
    size_mb = 15,
    blocking = FALSE,
    priority = 70,
    concurrent = TRUE,
    description = "Cached differential expression analysis",
    fallback = "seurat_object",
    load_fn = function(path) {
      if (!requireNamespace("qs", quietly = TRUE)) {
        library(qs)
      }
      if(file.exists(path)) qs::qread(path) else NULL
    }
  ),

  cached_pseudo_bulk = list(
    path = "data/cached_pbmc_pseudo_bulk.qs",
    type = "cached_analysis",
    size_mb = 20,
    blocking = FALSE,
    priority = 70,
    concurrent = TRUE,
    description = "Cached pseudo-bulk analysis",
    fallback = "seurat_object",
    load_fn = function(path) {
      if (!requireNamespace("qs", quietly = TRUE)) {
        library(qs)
      }
      if(file.exists(path)) qs::qread(path) else NULL
    }
  )
)

#' Get Blocking Resources
#'
#' Filters and returns only the resources marked as blocking (synchronous loading).
#' These are typically small files that need to be loaded immediately for the UI.
#'
#' @return Named list. Resources with blocking = TRUE.
#'
#' Global variables used:
#' - data_resources: The main resource registry
#'
# Utility functions
# Function: Get synchronous loading resources
# Return value: Blocking resource list
# Global variables: data_resources
get_blocking_resources <- function() {
  Filter(function(res) res$blocking, data_resources)
}

#' Get Asynchronous Resources
#'
#' Filters and returns only the resources marked as non-blocking (asynchronous loading).
#' These are typically larger files loaded in the background.
#' Resources with skip_if_exists condition will be excluded if the specified file exists.
#'
#' @return Named list. Resources with blocking = FALSE that should be loaded.
#'
#' Global variables used:
#' - data_resources: The main resource registry
#'
# Function: Get asynchronous loading resources
# Return value: Non-blocking resource list (filtered out resources with skip_if_exists condition met)
# Global variables: data_resources
get_async_resources <- function() {
  async_resources <- Filter(function(res) !res$blocking, data_resources)

  # Filter out resources with skip_if_exists condition met
  Filter(function(res) {
    if (!is.null(res$skip_if_exists) && file.exists(res$skip_if_exists)) {
      return(FALSE)  # Skip this resource
    }
    return(TRUE)
  }, async_resources)
}

#' Get Resources Sorted by Priority
#'
#' Returns resources sorted by their priority field, optionally filtered
#' by blocking status. Lower priority numbers indicate higher importance.
#'
#' @param blocking Logical. If TRUE, return only blocking resources.
#'   If FALSE, return only async resources.
#'
#' @return Named list. Resources sorted by priority (ascending order).
#'
#' Global variables used:
#' - get_blocking_resources: Function to get blocking resources
#' - get_async_resources: Function to get async resources
#'
# Function: Sort resources by priority
# Parameters: blocking status filter
# Return value: Sorted resource list
# Global variables: Dependent functions
get_resources_by_priority <- function(blocking = FALSE) {
  resources <- if(blocking) get_blocking_resources() else get_async_resources()
  resources[order(sapply(resources, function(x) x$priority))]
}

#' Validate Data Resource Paths
#'
#' Checks if all registered data files exist on the file system.
#' Reports missing files that don't have fallback alternatives.
#'
#' @return Character vector. Names and paths of missing files (invisibly).
#'   Also issues warnings for missing files.
#'
#' Global variables used:
#' - data_resources: The main resource registry
#'
#' @details
#' Files with fallback alternatives are not reported as missing since
#' the system can use alternative resources for computation.
#'
# Validate resource paths
# Function: Validate data file paths
# Return value: Missing file list
# Details: Fallback mechanism
# Global variables: data_resources
validate_data_resources <- function() {
  missing <- c()
  for(name in names(data_resources)) {
    res <- data_resources[[name]]
    if(!file.exists(res$path)) {
      if(is.null(res$fallback)) {
        missing <- c(missing, paste0(name, ": ", res$path))
      }
    }
  }
  if(length(missing) > 0) {
    warning("Missing data files:\n", paste(missing, collapse = "\n"))
  }
  invisible(missing)
}