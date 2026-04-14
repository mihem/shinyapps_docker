# ============================================================================
# CSF Analysis Modules
# ============================================================================

# Source plot controls
source("modules/plot_controls.R")

# CSF QC Plots Module
csf_qc_plots_UI <- function(id) {
  ns <- NS(id)

  fluidRow(
    # Plot Controls Panel
    column(
      width = 3,
      box(
        title = "Plot Controls",
        status = "primary",
        solidHeader = TRUE,
        collapsible = TRUE,
        collapsed = TRUE,
        width = NULL,
        plot_controls_UI(ns("plot_controls"))
      )
    ),

    # Main Plot Area
    column(
      width = 9,
      box(
        title = "CSF QC Plots",
        status = "primary",
        solidHeader = TRUE,
        width = NULL,
        height = "600px",

        tabsetPanel(
          id = ns("qc_tabs"),
          tabPanel(
            "Before QC",
            plotlyOutput(ns("before_qc_plot"), height = "500px")
          ),
          tabPanel(
            "After QC",
            plotlyOutput(ns("after_qc_plot"), height = "500px")
          )
        )
      )
    )
  )
}

csf_qc_plots_Server <- function(id) {
  moduleServer(id, function(input, output, session) {

    # Initialize plot controls
    plot_params <- plot_controls_Server("plot_controls")

    # Load CSF QC data
    qc_data <- reactive({
      # Load CSF QC data from saved files
      list(
        before_qc = NULL,  # Load before QC data
        after_qc = NULL    # Load after QC data
      )
    }) %>% bindCache()

    # Before QC Plot
    output$before_qc_plot <- renderPlotly({
      req(qc_data())

      # Create before QC plot
      p <- ggplot(qc_data()$before_qc, aes(x = nFeature_RNA, y = nCount_RNA, color = sample)) +
        geom_point(alpha = 0.6) +
        scale_color_manual(values = plot_params()$color_scheme) +
        labs(
          title = "CSF Quality Control - Before Filtering",
          x = "Number of Features",
          y = "Number of Counts"
        ) +
        theme_minimal() +
        theme(
          text = element_text(size = plot_params()$font_size),
          plot.title = element_text(size = plot_params()$title_size),
          legend.position = plot_params()$legend_position
        )

      ggplotly(p, width = plot_params()$width, height = plot_params()$height)
    }) %>% bindCache(plot_params(), qc_data()) %>% bindEvent(plot_params(), ignoreNULL = FALSE)

    # After QC Plot
    output$after_qc_plot <- renderPlotly({
      req(qc_data())

      # Create after QC plot
      p <- ggplot(qc_data()$after_qc, aes(x = nFeature_RNA, y = nCount_RNA, color = sample)) +
        geom_point(alpha = 0.6) +
        scale_color_manual(values = plot_params()$color_scheme) +
        labs(
          title = "CSF Quality Control - After Filtering",
          x = "Number of Features",
          y = "Number of Counts"
        ) +
        theme_minimal() +
        theme(
          text = element_text(size = plot_params()$font_size),
          plot.title = element_text(size = plot_params()$title_size),
          legend.position = plot_params()$legend_position
        )

      ggplotly(p, width = plot_params()$width, height = plot_params()$height)
    }) %>% bindCache(plot_params(), qc_data()) %>% bindEvent(plot_params(), ignoreNULL = FALSE)
  })
}

# CSF Sample Summary Module
csf_sample_summary_UI <- function(id) {
  ns <- NS(id)

  fluidRow(
    # Controls Panel
    column(
      width = 3,
      box(
        title = "Display Controls",
        status = "primary",
        solidHeader = TRUE,
        width = NULL,

        selectInput(
          ns("summary_type"),
          "Summary Type:",
          choices = list(
            "Sample Overview" = "overview",
            "Cell Counts" = "cell_counts",
            "QC Metrics" = "qc_metrics",
            "Integration Stats" = "integration"
          ),
          selected = "overview"
        ),

        checkboxGroupInput(
          ns("samples"),
          "Select Samples:",
          choices = NULL,
          selected = NULL
        ),

        plot_controls_UI(ns("plot_controls"))
      )
    ),

    # Main Display Area
    column(
      width = 9,
      box(
        title = "CSF Sample Summary",
        status = "primary",
        solidHeader = TRUE,
        width = NULL,

        tabsetPanel(
          id = ns("summary_tabs"),
          tabPanel(
            "Summary Table",
            DT::dataTableOutput(ns("summary_table"))
          ),
          tabPanel(
            "Summary Plot",
            plotlyOutput(ns("summary_plot"), height = "500px")
          )
        )
      )
    )
  )
}

csf_sample_summary_Server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Initialize plot controls
    plot_params <- plot_controls_Server("plot_controls")

    # Load CSF sample data
    sample_data <- reactive({
      # Load CSF sample summary data
      # This should load from your CSF results files
      data.frame(
        Sample = c("CSF_001", "CSF_002", "CSF_003"),
        Treatment = c("BTKi", "Placebo", "BTKi"),
        Timepoint = c("Pre", "Post", "Pre"),
        Total_Cells = c(1500, 1200, 1800),
        Genes_Detected = c(12000, 11500, 13000),
        Mitochondrial_Percent = c(15.2, 18.5, 12.8),
        stringsAsFactors = FALSE
      )
    }) %>% bindCache()

    # Update sample choices
    observe({
      req(sample_data())
      choices <- setNames(sample_data()$Sample, sample_data()$Sample)
      updateCheckboxGroupInput(
        session, "samples",
        choices = choices,
        selected = choices
      )
    })

    # Filtered data based on selections
    filtered_data <- reactive({
      req(sample_data(), input$samples)
      sample_data()[sample_data()$Sample %in% input$samples, ]
    }) %>% bindCache(sample_data(), input$samples)

    # Summary table
    output$summary_table <- DT::renderDataTable({
      req(filtered_data())

      if (input$summary_type == "overview") {
        filtered_data()
      } else if (input$summary_type == "cell_counts") {
        filtered_data()[, c("Sample", "Treatment", "Timepoint", "Total_Cells")]
      } else if (input$summary_type == "qc_metrics") {
        filtered_data()[, c("Sample", "Genes_Detected", "Mitochondrial_Percent")]
      } else {
        filtered_data()
      }
    }, options = list(pageLength = 10, scrollX = TRUE))

    # Summary plot
    output$summary_plot <- renderPlotly({
      req(filtered_data(), plot_params())

      if (input$summary_type == "cell_counts") {
        p <- ggplot(filtered_data(), aes(x = Sample, y = Total_Cells, fill = Treatment)) +
          geom_bar(stat = "identity", position = "dodge") +
          scale_fill_viridis_d() +
          labs(
            title = "Total Cell Counts by Sample",
            x = "Sample",
            y = "Total Cells"
          )
      } else if (input$summary_type == "qc_metrics") {
        p <- ggplot(filtered_data(), aes(x = Sample, y = Mitochondrial_Percent, color = Treatment)) +
          geom_point(size = 4) +
          scale_color_viridis_d() +
          labs(
            title = "Mitochondrial Gene Percentage",
            x = "Sample",
            y = "Mitochondrial %"
          )
      } else {
        p <- ggplot(filtered_data(), aes(x = Treatment, y = Total_Cells, fill = Timepoint)) +
          geom_boxplot() +
          scale_fill_viridis_d() +
          labs(
            title = "Cell Count Distribution",
            x = "Treatment",
            y = "Total Cells"
          )
      }

      p <- p +
        theme_minimal() +
        theme(
          text = element_text(size = plot_params()$font_size),
          plot.title = element_text(size = plot_params()$title_size),
          legend.position = plot_params()$legend_position
        )

      ggplotly(p, width = plot_params()$width, height = plot_params()$height)
    }) %>% bindCache(filtered_data(), plot_params(), input$summary_type) %>%
      bindEvent(filtered_data(), plot_params(), input$summary_type, ignoreNULL = FALSE)
  })
}

# CSF BCR/TCR Analysis Module
csf_bcr_tcr_UI <- function(id) {
  ns <- NS(id)

  fluidRow(
    # Controls Panel
    column(
      width = 3,
      box(
        title = "Analysis Controls",
        status = "primary",
        solidHeader = TRUE,
        width = NULL,

        selectInput(
          ns("analysis_type"),
          "Analysis Type:",
          choices = list(
            "BCR Analysis" = "bcr",
            "TCR Analysis" = "tcr",
            "Combined Analysis" = "combined"
          ),
          selected = "bcr"
        ),

        selectInput(
          ns("plot_type"),
          "Plot Type:",
          choices = list(
            "Clonotype Frequency" = "frequency",
            "Diversity Index" = "diversity",
            "V Gene Usage" = "v_gene",
            "CDR3 Length" = "cdr3_length"
          ),
          selected = "frequency"
        ),

        plot_controls_UI(ns("plot_controls"))
      )
    ),

    # Main Plot Area
    column(
      width = 9,
      box(
        title = "CSF BCR/TCR Analysis",
        status = "primary",
        solidHeader = TRUE,
        width = NULL,

        tabsetPanel(
          id = ns("bcr_tcr_tabs"),
          tabPanel(
            "Analysis Plot",
            plotlyOutput(ns("analysis_plot"), height = "500px")
          ),
          tabPanel(
            "Summary Statistics",
            DT::dataTableOutput(ns("stats_table"))
          )
        )
      )
    )
  )
}

csf_bcr_tcr_Server <- function(id) {
  moduleServer(id, function(input, output, session) {

    # Initialize plot controls
    plot_params <- plot_controls_Server("plot_controls")

    # Load BCR/TCR data
    bcr_tcr_data <- reactive({
      # Load CSF BCR/TCR data from saved files
      list(
        bcr = NULL,  # Load BCR data
        tcr = NULL   # Load TCR data
      )
    }) %>% bindCache()

    # Analysis plot
    output$analysis_plot <- renderPlotly({
      req(bcr_tcr_data(), plot_params())

      # Create placeholder plot
      p <- ggplot(data.frame(x = 1:10, y = rnorm(10)), aes(x = x, y = y)) +
        geom_point() +
        labs(
          title = paste("CSF", toupper(input$analysis_type), "Analysis -", input$plot_type),
          x = "X Axis",
          y = "Y Axis"
        ) +
        theme_minimal() +
        theme(
          text = element_text(size = plot_params()$font_size),
          plot.title = element_text(size = plot_params()$title_size),
          legend.position = plot_params()$legend_position
        )

      ggplotly(p, width = plot_params()$width, height = plot_params()$height)
    }) %>% bindCache(plot_params(), input$analysis_type, input$plot_type) %>%
      bindEvent(plot_params(), input$analysis_type, input$plot_type, ignoreNULL = FALSE)

    # Statistics table
    output$stats_table <- DT::renderDataTable({
      # Create placeholder statistics table
      data.frame(
        Metric = c("Total Clonotypes", "Unique CDR3s", "Diversity Index"),
        Value = c(150, 120, 2.5),
        stringsAsFactors = FALSE
      )
    }, options = list(pageLength = 10, scrollX = TRUE))
  })
}

# CSF UMAP Module
csf_umap_UI <- function(id) {
  ns <- NS(id)

  fluidRow(
    # Controls Panel
    column(
      width = 3,
      box(
        title = "UMAP Controls",
        status = "primary",
        solidHeader = TRUE,
        width = NULL,

        selectInput(
          ns("color_by"),
          "Color By:",
          choices = list(
            "Cell Type L1" = "celltype_l1",
            "Cell Type L2" = "celltype_l2",
            "Sample" = "sample",
            "Treatment" = "treatment",
            "Timepoint" = "timepoint"
          ),
          selected = "celltype_l1"
        ),

        selectInput(
          ns("split_by"),
          "Split By:",
          choices = list(
            "None" = "none",
            "Sample" = "sample",
            "Treatment" = "treatment",
            "Timepoint" = "timepoint"
          ),
          selected = "none"
        ),

        plot_controls_UI(ns("plot_controls"))
      )
    ),

    # Main Plot Area
    column(
      width = 9,
      box(
        title = "CSF UMAP Visualization",
        status = "primary",
        solidHeader = TRUE,
        width = NULL,

        plotlyOutput(ns("umap_plot"), height = "600px")
      )
    )
  )
}

csf_umap_Server <- function(id) {
  moduleServer(id, function(input, output, session) {

    # Initialize plot controls
    plot_params <- plot_controls_Server("plot_controls")

    # Load UMAP data
    umap_data <- reactive({
      # Load CSF UMAP data from saved files
      # This should load your integrated CSF Seurat object
      NULL
    }) %>% bindCache()

    # UMAP plot
    output$umap_plot <- renderPlotly({
      req(umap_data(), plot_params())

      # Create placeholder UMAP plot
      set.seed(123)
      plot_data <- data.frame(
        UMAP_1 = rnorm(1000),
        UMAP_2 = rnorm(1000),
        celltype_l1 = sample(c("T cells", "B cells", "Monocytes", "NK cells"), 1000, replace = TRUE),
        sample = sample(c("CSF_001", "CSF_002", "CSF_003"), 1000, replace = TRUE),
        stringsAsFactors = FALSE
      )

      p <- ggplot(plot_data, aes(x = UMAP_1, y = UMAP_2, color = get(input$color_by))) +
        geom_point(alpha = 0.6, size = 0.5) +
        scale_color_viridis_d(name = input$color_by) +
        labs(
          title = "CSF UMAP Visualization",
          x = "UMAP 1",
          y = "UMAP 2"
        ) +
        theme_minimal() +
        theme(
          text = element_text(size = plot_params()$font_size),
          plot.title = element_text(size = plot_params()$title_size),
          legend.position = plot_params()$legend_position
        )

      if (input$split_by != "none") {
        p <- p + facet_wrap(~ get(input$split_by))
      }

      ggplotly(p, width = plot_params()$width, height = plot_params()$height)
    }) %>% bindCache(plot_params(), input$color_by, input$split_by) %>%
      bindEvent(plot_params(), input$color_by, input$split_by, ignoreNULL = FALSE)
  })
}