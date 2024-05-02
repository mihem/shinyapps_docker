## ui.R 

library(shiny)

shinyUI <- fluidPage(
      sidebarLayout(
    sidebarPanel(
        helpText("Enter you patient's data here:"),
        radioButtons("OCB", "Oligoclonal bands present in CSF?",
                     choices = list("No" = 0,
                                    "Yes" =1),
                     selected = 1),
    radioButtons("disruption", "Blood-brain barrier disruption?",
                     choices = list("No" = 0,
                                    "Yes" =1),
                     selected = 0),
       sliderInput("hladrcd4", label = "% HLA-DR+ CD4+ cells (CSF):",
                min = 0, max = 100, value = 10, step = 0.1),
        sliderInput("cd4cd8ratio", label = "CD4/CD8 ratio (CSF):",
                min = 0, max = 20, value = 5, step = 0.1),
        sliderInput("blood_plasma", label = "% Plasma cells (blood):",
                min = 0, max = 5, value = 0.05, step = 0.01)
    ),
    mainPanel(h1("Differentiating neurosarcoidosis from multiple sclerosis", align = "center"), br(),
              ("This app is designed to support distinguishing neurosarcoidosis from multiple sclerosis in clinical difficult cases based on flow cytometry of blood and CSF. Simply fill in the parameters of your patient with suspected neurosarcoidosis (NS) or multiple sclerosis (MS) on the left. A penalized logistic regression model will then predict the probability of the presence of NS and MS in live mode. "), br(),br(),
              h4(textOutput("ns")),
              h4(textOutput("ms")), br(),
              em("Note: this model is experimental and has not been approved for clinical use. Based on a small cohort its sensitivity is 94-100% and its specificity is 67-69% (MS defined as positives, NS defined as negatives). More information can be found in the following paper: Heming et al.")
    )
    )
)
