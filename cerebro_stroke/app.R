## load packages -------------------------------------------------------------##
#library(shinymanager)
library(dplyr)
library(DT)
library(plotly)
library(shiny)
library(shinydashboard)
library(shinyWidgets)



custom_welcome_message <- '<h2 style="text-align: center; margin-top: 0px"><strong>Single-cell atlas of leukocytes in meninges and brain of murine experimental stroke</strong></h3>
<br>
  <p style="margin-left: 10px;">This data set belongs to the publication <a href = "https://doi.org/10.1038/s41467-022-28593-1"> Stroke induces disease-specific myeloid cells in the brain parenchyma and pia </a> by Beuker et al., <em> Nature Communications </em> 2022.<br> It contains single cell RNA-sequencing data of leukocytes from brain (cns), dura and pia in sham (ctrl) and murine experimental stroke (MCAO, 24h and 72h post stroke). For more details please refer to <a href = "https://doi.org/10.1038/s41467-022-28593-1"> our publication </a>.<br> The sequencing raw data can be found at <a href =  ""> GEO GSE189432</a>.<br> Please contact us at <a href = "https://www.mheming.com"> mheming.com </a> if you have any questions.</p>'

## set parameters ------------------------------------------------------------##
Cerebro.options <<- list(
  "mode" = "closed",
  "crb_file_to_load" = "extdata/v1.4/sc_merge_cerebro_h5.crb",
  "expression_matrix_h5" = "extdata/v1.4/sc_merge_cerebro.h5",
  "cerebro_root" = ".",
  "welcome_message" = custom_welcome_message,
  "projections_default_point_size" = 3,
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
