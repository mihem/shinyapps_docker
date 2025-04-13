## load packages -------------------------------------------------------------##
#library(shinymanager)
library(dplyr)
library(DT)
library(plotly)
library(shiny)
library(shinydashboard)
library(shinyWidgets)

custom_welcome_message <- '<h3 style="text-align: center; margin-top: 0px"><strong>Single cell atlas of intraocular leukocytes in HLA-B27-positive and -negative uveitis</strong></h3>
<br>
  <p style="margin-left: 10px;">This data set belongs to the publication <a href = "https://doi.org/10.7554/elife.67396">  Intraocular dendritic cells characterize HLA-B27-associated acute anterior uveitis </a> by Kasper et al., <em> eLife </em> 2021.<br> It contains single cell RNA-sequencing data of intraocular liquid from HLA-B27-positive and -negative uveitis patients and control patients with endopthalmitis. For more details please refer to <a href = "https://doi.org/10.7554/elife.67396"> our publication </a>.<br> The sequencing raw data can be found at <a href =  "https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE178833"> GEO GSES178833</a>. <br>Please contact us at <a href = "https://www.mheming.com"> mheming.com </a> if you have any questions.</p>'


## set parameters ------------------------------------------------------------##
Cerebro.options <<- list(
  "mode" = "closed",
  "crb_file_to_load" = "extdata/v1.4/sc_merge_cerebro_h5.crb",
  "expression_matrix_h5" = "extdata/v1.4/sc_merge_cerebro.h5",
  "cerebro_root" = ".",
  "welcome_message" = custom_welcome_message,
  "projections_default_point_size" = 5,
  "projections_default_point_opacity" = 0.5,
  "projections_default_percentage_cells_to_show" = 100,
  "projections_show_hover_info" = TRUE
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
