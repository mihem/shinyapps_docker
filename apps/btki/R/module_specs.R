# R/module_specs.R
# Module specification definitions - Declare resource dependencies and initialization logic for each module

#' Load Module Specifications
#'
#' Returns the module specifications for the application. This function encapsulates
#' the module configuration and can be used for dependency injection.
#'
#' @return List. Module specifications with each module containing type, resources,
#'   description, init_fn, and optional tab_name, poll_ms, optional_resources, ready_fn.
#'
#' Load module specification configuration for dependency injection
#'
load_module_specs <- function() {
  return(
    list(
      # ========== First screen modules (immediate initialization) ==========
      csf_sample_summary = list(
        type = "immediate",
        # resources = c("csf_metadata_filtered", "csf_metadata_raw"),
        resources = c("csf_metadata_2_in_1"),
        description = "CSF sample summary module",
        init_fn = function(id, resources) {
          sample_summary_Server(
            id,
            metadata_cell          = resources$csf_metadata_2_in_1$csf_metadata_raw,
            metadata_cell_filtered = resources$csf_metadata_2_in_1$csf_metadata_filtered
          )
        }
      ),

      csf_qc_plots = list(
        type = "immediate",
        # resources = c("csf_metadata_filtered"),
        resources = c("csf_metadata_2_in_1"),
        description = "CSF QC plots module",
        init_fn = function(id, resources) {
          qc_plots_Server(
            id,
            metadata_cell = resources$csf_metadata_2_in_1$csf_metadata_filtered
          )
        }
      ),

      pbmc_sample_summary = list(
        tab_name = "pbmc_sample_summary",
        type = "lazy",
        # resources = c("pbmc_metadata_summary", "pbmc_metadata_cell", "pbmc_metadata_cell_filtered"),
        resources = c("pbmc_metadata_3_in_1"),
        poll_ms = 200,
        description = "PBMC sample summary module",
        ready_fn = function(loader) {
          has_meta <- loader$is_loaded("pbmc_metadata_3_in_1")
          has_meta
        },
        init_fn = function(id, resources) {
          sample_summary_Server(
            id,
            metadata               = resources$pbmc_metadata_3_in_1$pbmc_metadata_summary,
            metadata_cell          = resources$pbmc_metadata_3_in_1$pbmc_metadata_cell,
            metadata_cell_filtered = resources$pbmc_metadata_3_in_1$pbmc_metadata_cell_filtered
          )
        }
      ),

      pbmc_qc_plots = list(
        tab_name = "pbmc_qc_plots",
        type = "lazy",
        # resources = c("pbmc_metadata_summary", "pbmc_metadata_cell", "pbmc_metadata_cell_filtered"),
        resources = c("pbmc_metadata_3_in_1"),
        poll_ms = 200,
        description = "PBMC QC plots module",
        ready_fn = function(loader) {
          has_summary <-  loader$is_loaded("pbmc_metadata_3_in_1") &&
                            !is.null(loader$get("pbmc_metadata_3_in_1")$pbmc_metadata_summary)
          has_cell    <-  loader$is_loaded("pbmc_metadata_3_in_1") &&
                            !is.null(loader$get("pbmc_metadata_3_in_1")$pbmc_metadata_cell)
          has_summary && has_cell
        },
        init_fn = function(id, resources) {
          qc_plots_Server(
            id,
            metadata      = resources$pbmc_metadata_3_in_1$pbmc_metadata_summary,
            metadata_cell = resources$pbmc_metadata_3_in_1$pbmc_metadata_cell
          )
        }
      ),

      pbmc_adt_gene_pair = list(
        tab_name = "pbmc_adt_gene_pair",
        type = "lazy",
        resources = c("adt_gene_pair_df_pbmc"),  # No external resource dependencies
        poll_ms = 200,
        description = "ADT-gene pairing module in PBMC samples",
        ready_fn = function(loader) {
          loader$is_loaded("adt_gene_pair_df_pbmc")
        },
        init_fn = function(id, resources) {
          pbmc_adt_gene_pair_Server(id, isotype_pairs = resources$adt_gene_pair_df_pbmc)
        }
      ),

      pbmc_adt_rna_cell_type_corr_viz = list(
        tab_name = "pbmc_adt_rna_cell_type_corr_viz",
        type = "lazy",
        resources = c("adt_rna_correlation"),
        poll_ms = 200,
        description = "ADT-RNA cell type correlation visualization",
        ready_fn = function(loader) {
          loader$is_loaded("adt_rna_correlation")
        },
        init_fn = function(id, resources) {
          pbmc_adt_rna_cell_type_corr_viz_Server(id, resources$adt_rna_correlation)
        }
      ),

      # ========== Lazy loading modules (on-demand initialization) ==========
      csf_umap = list(
        type = "lazy",
        resources = c("csf_umap_plot_data"),
        tab_name = "csf_umap",
        poll_ms = 200,
        description = "CSF UMAP visualization module",
        ready_fn = function(loader) {
          loader$is_loaded("csf_umap_plot_data")
        },
        init_fn = function(id, resources) {
          umap_Server(id, umap_data = resources$csf_umap_plot_data)
        }
      ),

      pbmc_umap = list(
        type = "lazy",
        resources = c("pbmc_umap_plot_data"),
        tab_name = "pbmc_umap",
        poll_ms = 200,
        description = "PBMC UMAP visualization module",
        ready_fn = function(loader) {
          loader$is_loaded("pbmc_umap_plot_data")
        },
        init_fn = function(id, resources) {
          umap_Server(id, umap_data = resources$pbmc_umap_plot_data)
        }
      ),

      csf_featureplot = list(
        type = "lazy",
        resources = c("csf_umap_plot_data", "csf_expression_data"),
        tab_name  = "csf_featureplot",
        poll_ms   = 200,
        description = "CSF feature plot module",
        ready_fn = function(loader) {
          loader$is_loaded("csf_umap_plot_data") && loader$is_loaded("csf_expression_data")
        },
        init_fn = function(id, resources) {
          csf_featureplot_Server(
            id,
            umap_data = resources$csf_umap_plot_data,
            expr_df   = resources$csf_expression_data
          )
        }
      ),

      pbmc_featureplot = list(
        type = "lazy",
        # resources = c("pbmc_umap_plot_data", "pbmc_expression_data"),
        tab_name = "pbmc_featureplot",
        poll_ms = 200,
        description = "PBMC feature plot module",
        ready_fn = function(loader) {
          # loader$is_loaded("pbmc_umap_plot_data") && loader$is_loaded("pbmc_expression_data")
          return(TRUE)  # Always return TRUE, lazy loading logic handled inside module
        },
        init_fn = function(id, resources) {
          featureplot_Server(
            id
          )
          # featureplot_Server(
          #   id,
          #   umap_data = resources$pbmc_umap_plot_data,
          #   expr_df = resources$pbmc_expression_data
          # )
        }
      ),

      csf_celltype_marker_table = list(
        tab_name = "csf_celltype_marker_table",
        type = "lazy",
        resources = c("csf_celltype_marker_results"),
        poll_ms = 200,
        description = "CSF cell type marker gene table",
        ready_fn = function(loader) {
          loader$is_loaded("csf_celltype_marker_results")
        },
        init_fn = function(id, resources) {
          celltype_marker_table_Server(
            id,
            DEG = resources$csf_celltype_marker_results,
            cluster = "cluster"
          )
        }
      ),

      pbmc_celltype_marker_table = list(
        tab_name = "pbmc_celltype_marker_table",
        type = "lazy",
        resources = c("pbmc_celltype_marker_results"),
        poll_ms = 200,
        description = "PBMC cell type marker gene table",
        ready_fn = function(loader) {
          loader$is_loaded("pbmc_celltype_marker_results")
        },
        init_fn = function(id, resources) {
          celltype_marker_table_Server(
            id,
            DEG = resources$pbmc_celltype_marker_results,
            cluster = "cluster"
          )
        }
      ),

      csf_celltype_marker_heatmap = list(
        tab_name = "csf_celltype_marker_heatmap",
        type = "lazy",
        resources = c(),  # No mandatory dependencies, dynamically determined based on cache status
        optional_resources = list(
          cached   = "cached_csf_heatmap",
          fallback = c("csf_celltype_marker_results", "csf_expression_scaled", "heatmap_metadata_csf")
        ),
        poll_ms = 300,
        description = "CSF cell type marker gene heatmap module",
        ready_fn = function(loader) {
          # Check if cache exists and is loaded
          cache_exists <- file.exists("data/cached_csf_heatmap_data.qs")
          has_cached   <- loader$is_loaded("cached_csf_heatmap") && !is.null(loader$get("cached_csf_heatmap"))

          if (cache_exists && has_cached) {
            return(TRUE)  # Cache exists and is loaded, ready to initialize
          } else if (!cache_exists) {
            # Cache doesn't exist, check fallback resources
            has_fallback <- loader$is_loaded("csf_celltype_marker_results") &&
                            loader$is_loaded("csf_expression_scaled")       &&
                            loader$is_loaded("heatmap_metadata_csf")
            return(has_fallback)
          }

          return(FALSE)
        },
        init_fn = function(id, resources) {
          # Check if cache exists
          cache_exists <- file.exists("data/cached_csf_heatmap_data.qs")
          has_cached   <- !is.null(resources$cached_csf_heatmap)

          if (cache_exists && has_cached) {
            # Cache exists, use only cached data
            csf_marker_heatmap_Server(
              id,
              DEG          = NULL,
              metadata     = NULL,
              expr         = NULL,
              cached_data = resources$cached_csf_heatmap,
              tissue = "CSF"
            )
          } else {
            # Cache doesn't exist, use fallback resources
            csf_marker_heatmap_Server(
              id,
              DEG          = resources$csf_celltype_marker_results,
              expr         = resources$csf_expression_scaled,
              metadata     = resources$heatmap_metadata_csf,
              cached_data = NULL,
              tissue = "CSF"
            )
          }
        }
      ),

      pbmc_celltype_marker_heatmap = list(
        tab_name = "pbmc_celltype_marker_heatmap",
        type = "lazy",
        resources = c(),  # No mandatory dependencies, dynamically determined based on cache status
        # optional_resources = list(
        #   cached = "cached_pbmc_heatmap",
        #   fallback = c("pbmc_celltype_marker_results", "pbmc_expression_scaled", "heatmap_metadata_pbmc")
        # ),
        poll_ms = 300,
        description = "PBMC cell type marker gene heatmap module",
        ready_fn = function(loader) {
          # # Check if cache exists and is loaded
          # cache_exists <- file.exists("data/cached_pbmc_heatmap_data.qs")
          # has_cached <- loader$is_loaded("cached_pbmc_heatmap") && !is.null(loader$get("cached_pbmc_heatmap"))

          # if (cache_exists && has_cached) {
          #   return(TRUE)  # Cache exists and is loaded, ready to initialize
          # } else if (!cache_exists) {
          #   # Cache doesn't exist, check fallback resources
          #   has_fallback <- loader$is_loaded("pbmc_celltype_marker_results") &&
          #                   loader$is_loaded("pbmc_expression_scaled")       &&
          #                   loader$is_loaded("heatmap_metadata_pbmc")
          #   return(has_fallback)
          # }

          # return(FALSE)
          return(TRUE)  # Temporarily always return TRUE, use empty initialization
        },
        init_fn = function(id, resources) {
          # # Check if cache exists
          # cache_exists <- file.exists("data/cached_pbmc_heatmap_data.qs")
          # has_cached <- !is.null(resources$cached_pbmc_heatmap)

          # if (cache_exists && has_cached) {
          #   # Cache exists, use only cached data
          #   marker_heatmap_Server(
          #     id,
          #     DEG          = NULL,
          #     metadata     = NULL,
          #     expr         = NULL,
          #     cached_data = resources$cached_pbmc_heatmap,
          #     tissue = "PBMC"
          #   )
          # } else {
          #   # Cache doesn't exist, use fallback resources
          #   marker_heatmap_Server(
          #     id,
          #     DEG          = resources$pbmc_celltype_marker_results,
          #     expr         = resources$pbmc_expression_scaled,
          #     metadata     = resources$heatmap_metadata_pbmc,
          #     cached_data = NULL,
          #     tissue = "PBMC"
          #   )
          # }

          marker_heatmap_Server(
            id,
            DEG          = NULL,
            expr         = NULL,
            metadata     = NULL,
            cached_data  = NULL,
            tissue = "PBMC"
          )
        }
      ),

      csf_cell_composition_table = list(
        tab_name = "csf_cell_composition_table",
        type = "lazy",
        resources = c("seurat_meta_csf"),
        poll_ms = 200,
        description = "CSF cell composition table module",
        ready_fn = function(loader) {
          has_seurat_meta <- loader$is_loaded("seurat_meta_csf")
          has_seurat_meta
        },
        init_fn = function(id, resources) {
          cell_composition_table_Server(
            id,
            meta_df = resources$seurat_meta_csf,
            cached_data = NULL,
            features = c("celltype_merged.l2", "sample", "treatment", "treatment_hour"),
            tissue = "CSF"
          )
        }
      ),

      pbmc_cell_composition_table = list(
        tab_name = "pbmc_cell_composition_table",
        type = "lazy",
        resources = c("seurat_meta_pbmc"),
        poll_ms = 200,
        description = "PBMC cell composition table module",
        ready_fn = function(loader) {
          has_seurat_meta <- loader$is_loaded("seurat_meta_pbmc")
          has_seurat_meta
        },
        init_fn = function(id, resources) {
          cell_composition_table_Server(
            id,
            meta_df = resources$seurat_meta_pbmc,
            cached_data = NULL,
            features = c("celltype_merged.l2", "sample", "treatment", "treatment_hour", "timepoint"),
            tissue = "PBMC"
          )
        }
      ),

      csf_cell_composition_boxplot = list(
        tab_name = "csf_cell_composition_boxplot",
        type = "lazy",
        resources = c("seurat_meta_csf"),
        poll_ms = 200,
        description = "CSF cell composition boxplot module",
        ready_fn = function(loader) {
          has_seurat_meta <- loader$is_loaded("seurat_meta_csf")
          has_seurat_meta
        },
        init_fn = function(id, resources) {
          cell_composition_boxplot_Server(
            id,
            meta_df = resources$seurat_meta_csf,
            tissue = "CSF"
          )
        }
      ),

      pbmc_cell_composition_boxplot = list(
        tab_name = "pbmc_cell_composition_boxplot",
        type = "lazy",
        resources = c("seurat_meta_pbmc"),
        poll_ms = 200,
        description = "Cell composition boxplot module",
        ready_fn = function(loader) {
          has_seurat_meta <- loader$is_loaded("seurat_meta_pbmc")
          has_seurat_meta
        },
        init_fn = function(id, resources) {
          cell_composition_boxplot_Server(
            id,
            meta_df = resources$seurat_meta_pbmc,
            tissue = "PBMC"
          )
        }
      ),

      csf_wilcoxon = list(
        tab_name = "csf_wilcoxon",
        type = "lazy",
        resources = c("seurat_meta_csf"),
        optional_resources = list(
          # cached = "cached_csf_wilcoxon",
          # fallback = "seurat_meta_csf"
        ),
        poll_ms = 200,
        description = "CSF Wilcoxon test module",
        ready_fn = function(loader) {
          has_cached <- loader$is_loaded("cached_csf_wilcoxon") && !is.null(loader$get("cached_csf_wilcoxon"))
          has_seurat_meta <- loader$is_loaded("seurat_meta_csf")
          has_cached || has_seurat_meta
        },
        init_fn = function(id, resources) {
          wilcoxon_Server(
          id,
          meta_df = resources$seurat_meta_csf,
          cached_data = resources$cached_csf_wilcoxon,
          tissue = "CSF"
          )
        }
      ),

      pbmc_wilcoxon = list(
        tab_name = "pbmc_wilcoxon",
        type = "lazy",
        resources = c("seurat_meta_pbmc"),
        poll_ms = 200,
        description = "PBMC Wilcoxon test module",
        ready_fn = function(loader) {
          has_cached <- loader$is_loaded("cached_pbmc_wilcoxon") && !is.null(loader$get("cached_pbmc_wilcoxon"))
          has_seurat_meta <- loader$is_loaded("seurat_meta_pbmc")
          has_cached || has_seurat_meta
        },
        init_fn = function(id, resources) {
          wilcoxon_Server(
            id,
            meta_df      = resources$seurat_meta_pbmc,
            cached_data = resources$cached_pbmc_wilcoxon,
            tissue = "PBMC"
          )
        }
      ),

      csf_propeller = list(
        type = "lazy",
        resources = c("seurat_meta_csf"),
        optional_resources = list(
          # cached = "cached_propeller",
          # fallback = "seurat_meta_csf"
        ),
        tab_name = "csf_propeller",
        poll_ms = 200,
        description = "CSF Propeller analysis module",
        ready_fn = function(loader) {
          has_cached <- loader$is_loaded("cached_propeller") && !is.null(loader$get("cached_propeller"))
          has_seurat_meta <- loader$is_loaded("seurat_meta_csf")
          has_cached || has_seurat_meta
        },
        init_fn = function(id, resources) {
          propeller_Server(
            id,
            meta_df = resources$seurat_meta_csf,
            cached_data = resources$cached_propeller
          )
        }
      ),

      pbmc_propeller = list(
        type = "lazy",
        resources = c("seurat_meta_pbmc"),
        optional_resources = list(
          # cached = "cached_propeller",
          # fallback = "seurat_meta_pbmc"
        ),
        tab_name = "pbmc_propeller",
        poll_ms = 200,
        description = "PBMC Propeller analysis module",
        ready_fn = function(loader) {
          has_cached <- loader$is_loaded("cached_propeller") && !is.null(loader$get("cached_propeller"))
          has_seurat_meta <- loader$is_loaded("seurat_meta_pbmc")
          has_cached || has_seurat_meta
        },
        init_fn = function(id, resources) {
          propeller_Server(
            id,
            meta_df = resources$seurat_meta_pbmc,
            cached_data = resources$cached_propeller
          )
        }
      ),

      csf_paired_ttest = list(
        type = "lazy",
        resources = c("seurat_meta_csf"),
        optional_resources = list(
          # cached = "cached_paired_ttest",
          # fallback = "seurat_meta_csf"
        ),
        tab_name = "csf_paired_ttest",
        poll_ms = 200,
        description = "CSF paired t-test module",
        ready_fn = function(loader) {
          has_cached <- loader$is_loaded("cached_paired_ttest") && !is.null(loader$get("cached_paired_ttest"))
          has_seurat_meta <- loader$is_loaded("seurat_meta_csf")
          has_cached || has_seurat_meta
        },
        init_fn = function(id, resources) {
          paired_ttest_Server(
            id,
            meta_df = resources$seurat_meta_csf,
            cached_data = resources$cached_paired_ttest
          )
        }
      ),

      pbmc_paired_ttest = list(
        type = "lazy",
        resources = c("seurat_meta_pbmc"),
        optional_resources = list(
          # cached = "cached_paired_ttest",
          # fallback = "seurat_meta_pbmc"
        ),
        tab_name = "pbmc_paired_ttest",
        poll_ms = 200,
        description = "PBMC paired t-test module",
        ready_fn = function(loader) {
          has_cached <- loader$is_loaded("cached_paired_ttest") && !is.null(loader$get("cached_paired_ttest"))
          has_seurat_meta <- loader$is_loaded("seurat_meta_pbmc")
          has_cached || has_seurat_meta
        },
        init_fn = function(id, resources) {
          paired_ttest_Server(
            id,
            meta_df = resources$seurat_meta_pbmc,
            cached_data = resources$cached_paired_ttest
          )
        }
      ),

      csf_de_analysis = list(
        tab_name = "csf_de_analysis",
        type = "lazy",
        resources = c("de_result_list_csf"),
        optional_resources = NULL,
        poll_ms = 200,
        description = "CSF differential expression analysis module",
        ready_fn = function(loader) {
          has_cached <- loader$is_loaded("cached_de_analysis") && !is.null(loader$get("cached_de_analysis"))
          has_seurat_de_result_list <- loader$is_loaded("de_result_list_csf")
          has_cached || has_seurat_de_result_list
        },
        init_fn = function(id, resources) {
          de_analysis_Server(
            id,
            de_result_list = resources$de_result_list_csf,
            comparison_groups = c("BTKi", "Placebo")
          )
        }
      ),

      pbmc_de_analysis = list(
        tab_name = "pbmc_de_analysis",
        type = "lazy",
        resources = c("de_result_list_pbmc"),
        optional_resources = NULL,
        poll_ms = 200,
        description = "PBMC differential expression analysis module",
        ready_fn = function(loader) {
          has_cached <- loader$is_loaded("cached_de_analysis") && !is.null(loader$get("cached_de_analysis"))
          has_seurat_de_result_list <- loader$is_loaded("de_result_list_pbmc")
          has_cached || has_seurat_de_result_list
        },
        init_fn = function(id, resources) {
          de_analysis_Server(
            id,
            de_result_list = resources$de_result_list_pbmc,
            comparison_groups = c("Post", "Pre")
          )
        }
      ),

      pbmc_pseudo_bulk = list(
        tab_name = "pbmc_pseudo_bulk",
        type = "lazy",
        resources = c("pseudo_bulk_result_list_pbmc", "seurat_meta_pbmc"),
        optional_resources = list(
          # cached = "cached_pseudo_bulk",
          # fallback = "pseudo_bulk_result_list_pbmc"
        ),
        poll_ms = 200,
        description = "PBMC Pseudo-bulk analysis module",
        ready_fn = function(loader) {
          has_cached <- loader$is_loaded("cached_pseudo_bulk") && !is.null(loader$get("cached_pseudo_bulk"))
          has_seurat_pseudo_bulk_result_list <- loader$is_loaded("pseudo_bulk_result_list_pbmc")
          has_cached || has_seurat_pseudo_bulk_result_list
        },
        init_fn = function(id, resources) {
          pseudo_bulk_Server(
            id,
            meta_df                 = resources$seurat_meta_pbmc,
            pseudo_bulk_result_list = resources$pseudo_bulk_result_list_pbmc
          )
        }
      ),

      pbmc_adt_feature_density = list(
        type = "lazy",
        resources = c("adt_features_slim", "adt_correction_stats"),
        tab_name = "pbmc_adt_feature_density",
        poll_ms = 200,
        description = "ADT feature density module",
        ready_fn = function(loader) {
          loader$is_loaded("adt_features_slim") && loader$is_loaded("adt_correction_stats")
        },
        init_fn = function(id, resources) {
          pbmc_correction_check_Server(
            id,
            adt_features_list = resources$adt_features_slim,
            adt_correction_stats_plots = resources$adt_correction_stats
          )
        }
      )
    )
  )
}

# Utility functions
get_immediate_modules <- function() {
  Filter(function(spec) spec$type == "immediate", module_specs)
}

get_lazy_modules <- function(module_specs = load_module_specs()) {
  Filter(function(spec) spec$type == "lazy", module_specs)
}

get_module_by_tab <- function(tab_name, module_specs = load_module_specs()) {
  for (name in names(module_specs)) {
    spec <- module_specs[[name]]
    if (!is.null(spec$tab_name) && spec$tab_name == tab_name) {
      return(list(name = name, spec = spec))
    }
  }
  NULL
}

# Get all resource dependencies of a module (including optional resources)
get_module_all_resources <- function(spec) {
  all_resources <- spec$resources
  if (!is.null(spec$optional_resources)) {
    all_resources <- c(all_resources, unlist(spec$optional_resources))
  }
  unique(all_resources)
}

# Check if module resources are ready
is_module_ready <- function(spec, loader) {
  if (!is.null(spec$ready_fn)) {
    spec$ready_fn(loader)
  } else {
    # Default check: all required resources are loaded
    all(sapply(spec$resources, loader$is_loaded))
  }
}
