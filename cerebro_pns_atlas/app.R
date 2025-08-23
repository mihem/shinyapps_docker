## load packages -------------------------------------------------------------##
#library(shinymanager)
library(dplyr)
library(DT)
library(plotly)
library(shiny)
library(shinydashboard)
library(shinyWidgets)

custom_welcome_message <- '<h2 style="text-align: center; margin-top: 0px"><strong>Single nuclei sural nerve atlas</strong></h3>
<br>
  <p style="margin-left: 10px;">This data set belongs to the publication <a href = "https://doi.org/10.1038/s41467-025-62964-8">Multi-omic characterization of human sural nerves across polyneuropathies</a> by Heming et al., <em> Nature Communications </em> 2025. <br> It contains over 365,000 nuclei of 33 polyneuropathy patients and 4 controls from sural nerves. To interactively explore the spatial transcriptomics data, raw data, code and more please refer to  the accompanying webpage <a href = "https://pns-atlas.mzhlab.com"> pns-atlas.mzhlab.com </a> and <a href = "https://doi.org/10.1038/s41467-025-62964-8"> our publication </a>. <br> Please contact us at <a href = "https://www.mheming.com"> mheming.com </a> if you have any questions.</p>
<br>' 

## set parameters ------------------------------------------------------------##
Cerebro.options <<- list(
  "mode" = "closed",
#  "crb_file_to_load" = "extdata/v1.4/sc_merge_cerebro.crb",
  "crb_file_to_load" = "extdata/v1.4/sc_merge_cerebro_h5.crb",
   "expression_matrix_mode" = "h5",
  "expression_matrix_h5" = "extdata/v1.4/sc_merge_cerebro.h5",
  # "expression_matrix_mode" = "BPCells",
  # "expression_matrix_BPCells" = "extdata/v1.4/matrix_cerebro/",
  "cerebro_root" = ".",
  "welcome_message" = custom_welcome_message,
  "overview_default_point_size" = 1,
  "gene_expression_default_point_size" = 2,
  "overview_default_point_opacity" = 0.3,
  "gene_expression_default_point_opacity" = 0.5,
  "overview_default_percentage_cells_to_show" = 100,
  "gene_expression_default_percentage_cells_to_show" = 20,
  "projections_show_hover_info" = FALSE
)

## shiny_options <- list(
##   maxRequestSize = 800 * 1024^4,
##   port = 1337
## )

## load server and UI functions ----------------------------------------------##
source(glue::glue("{Cerebro.options$cerebro_root}/shiny/v1.4/shiny_UI.R"))
source(glue::glue("{Cerebro.options$cerebro_root}/shiny/v1.4/shiny_server.R"))

## launch app ----------------------------------------------------------------##
shiny::shinyApp(
  ui = ui,
  server = server
  #  options = shiny_options
)

