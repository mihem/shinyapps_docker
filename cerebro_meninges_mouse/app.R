## load packages -------------------------------------------------------------##
#library(shinymanager)
library(dplyr)
library(DT)
library(plotly)
library(shiny)
library(shinydashboard)
library(shinyWidgets)

custom_welcome_message <- '<h2 style="text-align: center; margin-top: 0px"><strong>Single-cell atlas of the dura from mice </strong></h3>
<br>
  <p style="margin-left: 10px;">This data set belongs to the publication <a href = "https://doi.org/10.1038/s41593-021-00880-y">  B cells and their progenitors reside in homeostatic meninges </a> by Schafflick et al., <em> Nature Neuroscience </em> 2021. <br>. It contains single cell RNA-sequencing data of tissue-resdient leukocytes from the dura of C57BL/6 mice (un-immunized vs. experimental autoimmune encephalomyelitis). For more details please refer to <a href = "https://doi.org/10.1038/s41593-021-00880-y"> our publication </a>.<br> The sequencing raw data can be found at <a href =  "https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE165153"> GEO GSE165153</a>.<br> Please contact us at <a href = "https://www.mheming.com"> mheming.com </a> if you have any questions.</p>
<br>'

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
