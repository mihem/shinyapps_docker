# PBMC UMAP Module - Refactored Version
# 精简到 ~200 行，保持所有功能

source("modules/plot_controls.R")

# ============================================================================
# UI
# ============================================================================
umap_UI <- function(id) {
  ns <- NS(id)

  fluidRow(
    column(
      width = 3,
      box(
        title = "Settings",
        status = "primary",
        solidHeader = TRUE,
        width = NULL,
        selectInput(ns("annotation"), "Annotation", choices = NULL),
        selectInput(ns("split_by"), "Split By", choices = c("None")),
        actionButton(ns("plot_btn"), "Plot", class = "btn-primary btn-block"),
        hr(),
        plot_controls_UI(ns("controls")),
        checkboxInput(ns("show_labels"), "Show Labels", FALSE)
      )
    ),
    column(
      width = 9,
      box(
        status = "primary",
        solidHeader = TRUE,
        width = NULL,
        shinycssloaders::withSpinner(
          plotOutput(ns("plot"), height = "700px"),
          type = 6, color = "#0d6efd"
        )
      )
    )
  )
}

# ============================================================================
# Server
# ============================================================================
umap_Server <- function(id, umap_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # ---- 初始化选择框 ----
    observe({
      cols <- colnames(umap_data)

      # 注释列选项
      anno_opts <- intersect(
        c("celltype_merged.l1", "celltype_merged.l2", "treatment", "timepoint", "sample"),
        cols
      )
      if (length(anno_opts) == 0) anno_opts <- cols

      # 分组列选项
      split_opts <- c("None", intersect(
        c("timepoint", "treatment", "sample", "celltype_merged.l1"),
        cols
      ))

      updateSelectInput(session, "annotation", choices = anno_opts, selected = anno_opts[1])
      updateSelectInput(session, "split_by", choices = split_opts, selected = "None")
    })

    # ---- 绘图参数 ----
    params <- plot_controls_Server("controls", default_params = list(
      title_size = 16,
      axis_title_size = 14,
      axis_text_size = 12,
      legend_title_size = 12,
      legend_text_size = 10,
      legend_position = "top"
    ))

    # ---- 绘图逻辑 ----
    output$plot <- renderPlot({
      # 只在点击按钮时触发
      input$plot_btn

      isolate({
        req(input$annotation)

        # 验证列存在
        validate(
          need(input$annotation %in% colnames(umap_data), "Invalid annotation column"),
          need(input$split_by == "None" || input$split_by %in% colnames(umap_data), "Invalid split column")
        )

        # 绘图参数
        p_params <- params()
        split_col <- if (input$split_by == "None") NULL else input$split_by

        # 构建图形
        p <- ggplot(umap_data, aes(umap_1, umap_2, color = .data[[input$annotation]])) +
          geom_point(alpha = 0.6, size = 1) +
          labs(
            title = paste("UMAP -", input$annotation),
            x = "UMAP 1",
            y = "UMAP 2",
            color = gsub("_", " ", input$annotation)
          ) +
          theme_minimal() +
          theme(
            text = element_text(size = p_params$axis_text_size),
            plot.title = element_text(size = p_params$title_size),
            axis.title = element_text(size = p_params$axis_title_size),
            legend.text = element_text(size = p_params$legend_text_size),
            legend.title = element_text(size = p_params$legend_title_size),
            legend.position = p_params$legend_position
          ) +
          coord_fixed(ratio = 1)

        # 颜色比例
        n_cats <- length(unique(umap_data[[input$annotation]]))
        p <- p + if (n_cats <= 9) {
          scale_color_brewer(palette = "Set1")
        } else if (n_cats <= 12) {
          scale_color_brewer(palette = "Set3")
        } else {
          scale_color_viridis_d(option = "plasma")
        }

        # 分面
        if (!is.null(split_col)) {
          p <- p + facet_wrap(~ .data[[split_col]], ncol = 2)
        }

        # 标签
        if (input$show_labels) {
          p <- p + ggrepel::geom_text_repel(
            aes(label = .data[[input$annotation]]),
            size = 3, max.overlaps = 10
          )
        }

        print(p)
      })
    })
  })
}
