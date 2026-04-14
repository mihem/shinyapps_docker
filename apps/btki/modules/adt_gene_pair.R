# ============================================================================
# PBMC ADT Analysis Modules
# ============================================================================

# Source plot controls
source("modules/plot_controls.R")

# =============== Antibody Isotype Pairs UI ===============
pbmc_adt_gene_pair_UI <- function(id) {
  ns <- NS(id)
  fluidRow(
    column(12,
      box(
        title = "Antibody Isotype Pairs",
        status = "primary",
        solidHeader = TRUE,
        width = NULL,
        shinycssloaders::withSpinner(DTOutput(ns("isotype_table")), type = 6, color = "#0d6efd")
      )
    )
  )
}

# =============== Antibody Isotype Pairs Server ===============
pbmc_adt_gene_pair_Server <- function(id, isotype_pairs = NULL) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactive value to store the data
    isotype_data <- reactiveVal(NULL)

    # Initialize data
    if (!is.null(isotype_pairs)) {
      isotype_data(isotype_pairs)
    } else {
      # Only read local file when isotype_pairs is NULL
      observe({
        future::future({
          if (file.exists("data/shinyapp_pbmc_40_S1_antibody_isotype_pairs.xlsx")) {
            readxl::read_xlsx("data/shinyapp_pbmc_40_S1_antibody_isotype_pairs.xlsx")
          } else {
            NULL
          }
        }) %...>% (function(data) {
          isotype_data(data)
        }) %...!% (function(e) {
          warning("Failed to load antibody isotype pairs: ", conditionMessage(e))
          isotype_data(NULL)
        })
      })
    }

    # Render the data table
    output$isotype_table <- renderDT({
      req(isotype_data())
      datatable(
        isotype_data(),
        options = list(
          pageLength = 10,
          lengthMenu = c(10, 20, 50),
          searchDelay = 500,
          processing = TRUE,
          dom = "Bfrtip",
          scrollX = TRUE,
          lengthChange = TRUE,
          searching = TRUE,
          ordering = TRUE,
          info = TRUE,
          fixedColumns = TRUE,
          buttons = c('copy', 'csv', 'excel')
        ),
        extensions = 'Buttons',  # Must add this line
        rownames = FALSE,
        class = "display compact nowrap cell-border"
      )
    })
  })
}