# ============================================================================
# Main Body UI
# ============================================================================

body_ui <- dashboardBody(
  tabItems(

    tabItem(
      tabName = "pbmc_sample_summary",
      sample_summary_UI("pbmc_sample_summary")
    ),

    # PBMC Data Load Tabs
    tabItem(
      tabName = "pbmc_qc_plots",
      qc_plots_UI("pbmc_qc_plots")
    ),

    # pbmc UMAP Tabs
    tabItem(
      tabName = "pbmc_umap",
      umap_UI("pbmc_umap")
    ),

    # pbmc Featureplot Tabs
    tabItem(
      tabName = "pbmc_featureplot",
      featureplot_UI("pbmc_featureplot")
    ),

    tabItem(
      tabName = "pbmc_celltype_marker_table",
      celltype_marker_table_UI("pbmc_celltype_marker_table")
    ),

    tabItem(
      tabName = "pbmc_celltype_marker_heatmap",
      marker_heatmap_UI("pbmc_celltype_marker_heatmap")
    ),

    tabItem(
      tabName = "pbmc_cell_composition_table",
      cell_composition_table_UI("pbmc_cell_composition_table")
    ),
    tabItem(
      tabName = "pbmc_cell_composition_boxplot",
      cell_composition_boxplot_UI("pbmc_cell_composition_boxplot")
    ),
    tabItem(
      tabName = "pbmc_wilcoxon",
      wilcoxon_UI("pbmc_wilcoxon")
    ),
    tabItem(
      tabName = "pbmc_propeller",
      propeller_UI("pbmc_propeller")
    ),
    tabItem(
      tabName = "pbmc_paired_ttest",
      paired_ttest_UI("pbmc_paired_ttest")
    ),
    tabItem(
      tabName = "pbmc_de_analysis",
      de_analysis_UI("pbmc_de_analysis")
    ),
    tabItem(
      tabName = "pbmc_pseudo_bulk",
      pseudo_bulk_UI("pbmc_pseudo_bulk")
    ),
    tabItem(
      tabName = "pbmc_adt_gene_pair",
      pbmc_adt_gene_pair_UI("pbmc_adt_gene_pair")
    ),

    tabItem(
      tabName = "pbmc_adt_feature_density",
      pbmc_correction_check_UI("pbmc_adt_feature_density")
    ),
    tabItem(
      tabName = "pbmc_adt_rna_cell_type_corr_viz",
      pbmc_adt_rna_cell_type_corr_viz_UI("pbmc_adt_rna_cell_type_corr_viz")
    ),

    # tabItem(
    #   tabName = "pbmc_clustering",
    #   pbmc_clustering_UI("pbmc_clustering")
    # ),

    # # PBMC Analysis Tabs
    # tabItem(
    #   tabName = "pbmc_de",
    #   pbmc_de_UI("pbmc_de")
    # ),

    # tabItem(
    #   tabName = "pbmc_proportion",
    #   pbmc_proportion_UI("pbmc_proportion")
    # ),

    # tabItem(
    #   tabName = "pbmc_pathway",
    #   pbmc_pathway_UI("pbmc_pathway")
    # ),

    # CSF Data Load Tabs
    tabItem(
      tabName = "csf_qc_plots",
      qc_plots_UI("csf_qc_plots")
    ),

    tabItem(
      tabName = "csf_sample_summary",
      sample_summary_UI("csf_sample_summary")
    ),

    # CSF Integration Tabs
    tabItem(
      tabName = "csf_umap",
      umap_UI("csf_umap")
    ),

    tabItem(
      tabName = "csf_featureplot",
      csf_featureplot_UI("csf_featureplot")
    ),

    tabItem(
      tabName = "csf_celltype_marker_table",
      celltype_marker_table_UI("csf_celltype_marker_table")
    ),
    tabItem(
      tabName = "csf_celltype_marker_heatmap",
      csf_marker_heatmap_UI("csf_celltype_marker_heatmap")
    ),
    tabItem(
      tabName = "csf_cell_composition_table",
      cell_composition_table_UI("csf_cell_composition_table")
    ),
    tabItem(
      tabName = "csf_cell_composition_boxplot",
      cell_composition_boxplot_UI("csf_cell_composition_boxplot")
    ),
    tabItem(
      tabName = "csf_wilcoxon",
      wilcoxon_UI("csf_wilcoxon")
    ),
    tabItem(
      tabName = "csf_propeller",
      propeller_UI("csf_propeller")
    ),
    tabItem(
      tabName = "csf_paired_ttest",
      paired_ttest_UI("csf_paired_ttest")
    ),
    tabItem(
      tabName = "csf_de_analysis",
      de_analysis_UI("csf_de_analysis")
    )
  )
)