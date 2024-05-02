## server.R

library(shiny)
library(caret)
library(glmnet)
shiny.model <- readRDS("ns_shiny.rds")
shinyServer <- function(input, output){
        output$ns <- renderText({
    pred.ns <- predict(shiny.model, new = data.frame(ocb = as.numeric(input$OCB), disruption = as.numeric(input$disruption), plasmacells_blood = input$blood_plasma, cd4cellshladr_csf = input$hladrcd4, plasmacells_csf = input$csf_plasma, cd4cd8ratio_csf = input$cd4cd8ratio), type = "prob")
  paste("Predicted probability for neurosarcoidosis:", round(pred.ns[2],3)*100, "%")
  })
        output$ms <- renderText({
            pred.ms <- predict(shiny.model, new = data.frame(ocb = as.numeric(input$OCB), disruption = as.numeric(input$disruption), plasmacells_blood = input$blood_plasma, cd4cellshladr_csf = input$hladrcd4, plasmacells_csf = input$csf_plasma, cd4cd8ratio_csf = input$cd4cd8ratio), type = "prob")
paste("Predicted probability for multiple sclerosis:", round(pred.ms[1],3)*100,"%")
        })
}
