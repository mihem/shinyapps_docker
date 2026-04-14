sidebarSection <- function(label, icon = NULL) {
  lab <- if (is.null(icon)) label else paste(icon, label)
  tags$li(class = "sidebar-section-header", lab)
}

# 改造后的 sidebar
sidebar_ui <- dashboardSidebar(
  width = 250,
  div(
    class = "custom-sidebar-wrapper",
    sidebarMenu(
      id = "main_menu",

      # CSF component
      menuItem(
        "CSF Analysis",
        tabName = "csf_main",
        icon = icon("brain"),
        startExpanded = FALSE,

        sidebarSection("DATA LOAD", icon = "📂"),
        menuSubItem("📋 Sample Summary", tabName = "csf_sample_summary"),
        menuSubItem("📊 QC Plots",       tabName = "csf_qc_plots"),

        sidebarSection("INTEGRATION", icon = "🧩"),
        menuSubItem("🗺️ UMAP",              tabName = "csf_umap"),
        menuSubItem("🗺️ Feature Plot",      tabName = "csf_featureplot"),
        menuSubItem("🧬 Cell Type Markers", tabName = "csf_celltype_marker_table"),
        menuSubItem("🔥 Marker Heatmap",    tabName = "csf_celltype_marker_heatmap"),

        sidebarSection("CELL COMPOSITION", icon = "🧪"),
        menuSubItem("📊 Composition Table",   tabName = "csf_cell_composition_table"),
        menuSubItem("📊 Composition Boxplot", tabName = "csf_cell_composition_boxplot"),
        menuSubItem("🧮 Wilcoxon Test",       tabName = "csf_wilcoxon"),
        menuSubItem("🧮 Propeller Test",      tabName = "csf_propeller"),
        menuSubItem("⚖️ Paired T-Test",       tabName = "csf_paired_ttest"),

        sidebarSection("DIFFERENTIAL EXPRESSION", icon = "🧾"),
        menuSubItem("📊 DE Analysis",          tabName = "csf_de_analysis")
      ),

      # PBMC component
      menuItem(
        "PBMC Analysis",
        tabName = "pbmc_main",
        icon = icon("dna"),
        startExpanded = FALSE,

        sidebarSection("DATA LOAD", icon = "📂"),
        menuSubItem("📋 Sample Summary",    tabName = "pbmc_sample_summary"),
        menuSubItem("📊 QC Plots",          tabName = "pbmc_qc_plots"),
        # menuSubItem("🧬 Cell Type Markers", tabName = "pbmc_celltype_marker_table"),
        # menuSubItem("🧬 BCR/TCR Analysis", tabName = "pbmc_bcr_tcr"),

        sidebarSection("INTEGRATION", icon = "🧩"),
        menuSubItem("🗺️ UMAP",              tabName = "pbmc_umap"),
        menuSubItem("🗺️ Feature Plot",      tabName = "pbmc_featureplot"),
        menuSubItem("🧬 Cell Type Markers", tabName = "pbmc_celltype_marker_table"),
        menuSubItem("🔥 Marker Heatmap",    tabName = "pbmc_celltype_marker_heatmap"),

        sidebarSection("CELL COMPOSITION", icon = "🧪"),
        menuSubItem("📊 Composition Table",   tabName = "pbmc_cell_composition_table"),
        menuSubItem("📊 Composition Boxplot", tabName = "pbmc_cell_composition_boxplot"),
        menuSubItem("🧮 Wilcoxon Test",       tabName = "pbmc_wilcoxon"),
        menuSubItem("🧮 Propeller Test",      tabName = "pbmc_propeller"),
        menuSubItem("⚖️ Paired T-Test",       tabName = "pbmc_paired_ttest"),

        sidebarSection("DIFFERENTIAL EXPRESSION", icon = "🧾"),
        menuSubItem("📊 DE Analysis",          tabName = "pbmc_de_analysis"),
        menuSubItem("🧬 Pseudo-bulk Analysis", tabName = "pbmc_pseudo_bulk"),

        sidebarSection("ADT ANALYSIS", icon = "🏷️"),
        menuSubItem("🏷️ ADT Gene Pair Table",      tabName = "pbmc_adt_gene_pair"),
        menuSubItem("📊 ADT Feature Density",      tabName = "pbmc_adt_feature_density"),
        menuSubItem("🏷️ ADT-RNA Gene Correlation", tabName = "pbmc_adt_rna_cell_type_corr_viz")

        # menuSubItem("🔗 Clustering", tabName = "pbmc_clustering"),

        # sidebarSection("ANALYSIS (LEGACY)", icon = "📈"),
        # menuSubItem("📈 Differential Expression", tabName = "pbmc_de"),
        # menuSubItem("📊 Cell Proportion",         tabName = "pbmc_proportion"),
        # menuSubItem("🛤️ Pathway Analysis",        tabName = "pbmc_pathway"),

        # sidebarSection("ANTIBODY ISOTYPE PAIRS", icon = "🧪"),
        # menuSubItem("🧪 Antibody Isotype Pairs", tabName = "pbmc_antibody_isotype")
      )
    )
  )
)