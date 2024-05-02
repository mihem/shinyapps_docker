## server.R

library(shiny)
library(caret)
library(glmnet)
shiny.model <- readRDS("ns_shiny_noplasma_csf.rds")
shinyServer <- function(input, output){
        output$ns <- renderText({
    pred.ns <- predict(shiny.model, new = data.frame(ocb_csf = as.numeric(input$OCB), disruption_csf = as.numeric(input$disruption), plasmacells_pct_blood = input$blood_plasma, cd4cellshladr_pct_csf = input$hladrcd4, cd4cd8ratio_csf = input$cd4cd8ratio), type = "prob")
  paste("Predicted probability for neurosarcoidosis:", round(pred.ns[2],3)*100, "%")
  })
        output$ms <- renderText({
            pred.ms <- predict(shiny.model, new = data.frame(ocb_csf = as.numeric(input$OCB), disruption_csf = as.numeric(input$disruption), plasmacells_pct_blood = input$blood_plasma, cd4cellshladr_pct_csf = input$hladrcd4, cd4cd8ratio_csf = input$cd4cd8ratio), type = "prob")
paste("Predicted probability for multiple sclerosis:", round(pred.ms[1],3)*100,"%")
        })
}

