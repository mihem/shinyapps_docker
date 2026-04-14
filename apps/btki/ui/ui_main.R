# R/app_ui.R
# Refactored UI definition

library(shiny)           # Prepare for textOutput/icon in header
library(shinydashboard)
library(shinyjs)

# Ensure global.R is loaded before modules
if (!exists("cell_type_markers")) {
  source("utils/global.R")
}

source("modules/pbmc_modules.R")
source("modules/pbmc_modules_adt.R")

source("modules/sample_summary.R")
source("modules/qc_plots.R")

source("modules/pbmc_umap.R")
source("modules/featureplot.R")
source("modules/pbmc_marker_heatmap.R")
source("modules/pbmc_cell_composition_boxplot.R")
source("modules/pbmc_pseudo_bulk_per_celltype.R")
source("modules/pbmc_adt_rna_cell_type_corr_viz.R")

source("modules/csf_featureplot.R")
source("modules/csf_marker_heatmap.R")

source("modules/wilcoxon.R")
source("modules/propeller.R")
source("modules/paired_ttest.R")
source("modules/de_analysis.R")

source("modules/adt_gene_pair.R")

source("modules/plot_controls.R")

# Load UI components
source("ui/ui_sidebar.R")
source("ui/ui_body.R")

# Main UI function
app_ui <- function() {
    tagList(
      tags$head(
        tags$link(rel = "shortcut icon", href = "shatuzi2.svg"),
        tags$link(rel = "icon", type = "image/svg+xml", href = "shatuzi2.svg?v=1"),
        tags$link(rel = "icon", type = "image/png", href = "shatuzi2.png") # Optional fallback
      ),

    dashboardPage(
      # Page header
      dashboardHeader(
        title = "Multi-omics Analysis Dashboard",
        titleWidth = 350,

        # Username
        tags$li(
          class = "dropdown",
          # Remove display:flex from li, use line-height on internal elements instead
          tags$span(
            style = "padding: 0 12px; color: #fff; display: inline-block; line-height: 50px;",
            shiny::icon("user"),
            " ",
            shiny::textOutput("header_username", container = shiny::span)
          )
        ),

        # Logout button
        tags$li(
          class = "dropdown",
          shiny::actionLink(
            inputId = "btn_logout",
            label   = NULL,
            icon    = shiny::icon("sign-out"),
            title   = "Logout",
            # Key: use line-height=50px to achieve vertical centering in navigation bar
            style   = "color:#fff; display:inline-block; padding: 0 12px; line-height: 50px;"
          )
        )
      ),

      # Sidebar
      sidebar_ui,

      # Main content
      body_ui,

      # Skin theme
      skin = "blue"
    ),
    includeScript("www/tabulator.js"),
    includeScript("www/js/simple_timeout.js")  # Simple timeout management
  )
}

# Export function
get_app_ui <- function() {
  app_ui
}