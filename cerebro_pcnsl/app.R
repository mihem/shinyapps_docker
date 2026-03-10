## load packages -------------------------------------------------------------##
#library(shinymanager)
library(dplyr)
library(DT)
library(plotly)
library(shiny)
library(shinydashboard)
library(shinyWidgets)

custom_welcome_message <- '<h2 style="text-align: center; margin-top: 0px"><strong>Intratumor heterogeneity and T cell exhaustion in primary CNS B cell lymphomas</strong></h3>
<br>
  <p style="margin-left: 10px;">This data set belongs to the publication <a href = "https://genomemedicine.biomedcentral.com/articles/10.1186/s13073-022-01110-1"> Intratumor heterogeneity and T cell exhaustion in primary CNS cell lymphomas </a> by Heming et al., <em> Genome Medicine </em> 2022. <br> It contains single cell RNA-sequencing data of biopsy fluid, blood and CSF from patients with primary CNS B cell lymphoma. For more details please refer to <a href = "https://genomemedicine.biomedcentral.com/articles/10.1186/s13073-022-01110-1"> our publication </a>.<br> The sequencing raw data can be found at <a href = "https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE203552"> GEO GSE203552</a>.<br> Please contact us at <a href = "https://www.mheming.com"> mheming.com </a> if you have any questions.</p>
<br>'

## set parameters ------------------------------------------------------------##
Cerebro.options <<- list(
  "mode" = "closed",
#  "crb_file_to_load" = "extdata/v1.4/sc_merge_cerebro.crb",
  "crb_file_to_load" = "extdata/v1.4/sc_merge_cerebro_h5.crb",
  "expression_matrix_h5" = "extdata/v1.4/sc_merge_cerebro.h5",
  "cerebro_root" = ".",
  "welcome_message" = custom_welcome_message,
  "projections_default_point_size" = 3,
  "projections_default_point_opacity" = 0.3,
  "projections_default_percentage_cells_to_show" = 100,
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
