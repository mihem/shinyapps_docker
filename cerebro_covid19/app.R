## load packages -------------------------------------------------------------##
library(dplyr)
library(DT)
library(plotly)
library(shiny)
library(shinydashboard)
library(shinyWidgets)

custom_welcome_message <- '<h2 style="text-align: center; margin-top: 0px"><strong>Single-cell atlas of cerebrospinal fluid in Neuro-COVID and controls</strong></h3>
<br>
  <p style="margin-left: 10px;">This data set belongs to the publication <a href = "https://doi.org/10.1016/j.immuni.2020.12.011">  Neurological Manifestations of COVID-19 Feature T Cell Exhaustion and Dedifferentiated Monocytes in Cerebrospinal Fluid </a> by Heming et al., <em> Immunity </em> 2021.<br> It contains single cell RNA-sequencing data of CSF from Neuro-COVID patients and control patients with viral encephalitis (VE), idiopathic intracranial hypertension (IIH) and multiple sclerosis (MS). For more details please refer to <a href = "https://doi.org/10.1016/j.immuni.2020.12.011"> our publication </a>.<br> The sequencing raw data can be found at <a href =  "https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE163005"> GEO GSES163006</a>.<br> Please contact us at <a href = "https://www.mheming.com"> mheming.com </a> if you have any questions.</p>
<br>'
## load data set -------------------------------------------------------------##
#my_data_set <- readRDS("extdata/v1.4/sc_merge_cerebro_delayed.crb")

## set parameters ------------------------------------------------------------##
Cerebro.options <<- list(
  "mode" = "closed",
  "crb_file_to_load" = "extdata/v1.4/sc_merge_cerebro_h5.crb",
  "expression_matrix_h5" = "extdata/v1.4/sc_merge_cerebro.h5",
  "cerebro_root" = ".",
  "welcome_message" = custom_welcome_message,
  "projections_default_point_size" = 2,
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
