# 防御式 PBMC QC Plots Module
pbmc_qc_plots_UI <- function(id) {
  ns <- NS(id)
  fluidRow(
    column(
      width = 3,
      box(
        title = "Sample Selection",
        status = "primary",
        solidHeader = TRUE,
        width = NULL,
        selectInput(ns("sample_select"), "Samples Select", choices = NULL),
        div(
          style = "text-align:center;margin-top:10px;",
          actionButton(ns("prev_sample"), "Previous sample"),
          actionButton(ns("next_sample"), "Next sample")
        )
      ),
      box(
        title = "Plot Controls",
        status = "primary",
        solidHeader = TRUE,
        width = NULL,
        collapsible = TRUE,
        plot_controls_UI(ns("plot_controls"))
      )
    ),
    column(
      width = 9,
      box(
        title = "PBMC QC Plots",
        status = "primary",
        solidHeader = TRUE,
        width = NULL,
        tabsetPanel(
          id = ns("tabs"),
          tabPanel(
            "RNA QC",
            shinycssloaders::withSpinner(
              plotOutput(ns("rna_qc_plot"), height = "500px"),
              type = 6, color = "#0d6efd"
            )
          ),
          tabPanel(
            "ADT QC",
            shinycssloaders::withSpinner(
              plotOutput(ns("adt_qc_plot"), height = "500px"),
              type = 6, color = "#0d6efd"
            )
          )
        )
      )
    )
  )
}


# server ----
pbmc_qc_plots_Server <- function(id, metadata, metadata_cell) {
  stopifnot(is.list(metadata), is.list(metadata_cell))

  cat("===> [调试] sample_summary_Server 开始执行, id =", id, "\n")

  # 数据验证和调试信息
  cat("===> [调试] 检查传入数据类型...\n")
  cat("     metadata 类型:", class(metadata), "长度:", length(metadata), "\n")
  cat("     metadata_cell 类型:", class(metadata_cell), "长度:", length(metadata_cell), "\n")

  # 检查数据内容
  if (length(metadata) > 0) {
    cat("     metadata 样本名:", paste(names(metadata), collapse = ", "), "\n")
    if (nrow(metadata[[1]]) > 0) {
      cat("     第一个样本的行数:", nrow(metadata[[1]]), "列数:", ncol(metadata[[1]]), "\n")
      cat("     前几列名:", paste(head(colnames(metadata[[1]]), 5), collapse = ", "), "\n")
    }
  }
  if (length(metadata_cell) > 0) {
    cat("     metadata_cell 样本名:", paste(names(metadata_cell), collapse = ", "), "\n")
    if (nrow(metadata_cell[[1]]) > 0) {
      cat("     第一个样本的行数:", nrow(metadata_cell[[1]]), "列数:", ncol(metadata_cell[[1]]), "\n")
      cat("     前几列名:", paste(head(colnames(metadata_cell[[1]]), 5), collapse = ", "), "\n")
    }
  }

  # 1. 真实项目中 metadata 其实是从别的 reactive 或者未来才赋值的对象（比如传进来的时候还没准备好），那么直接访问可能得到空或出错。你加入 print 只是让你“看到”它被访问了，并非真正“触发并保持”后续依赖。
  # 2. 正确方式：把“依赖 input 或当前样本选择的数据获取”放进 reactive()；输出（renderDT）里使用该 reactive —— Shiny 会自动建立依赖图。无需 print 强制求值。

  moduleServer(id, function(input, output, session) {
    # 样本名向量
    sample_names <- names(metadata)
    req(length(sample_names) > 0)

    # 初始化下拉
    updateSelectInput(session, "sample_select", choices = sample_names, selected = sample_names[1])

    # 当前样本 reactive
    current_sample <- reactive({
      sample <- req(input$sample_select)
      sample
    })

    # 简单列子集工具
    subset_cols <- function(df, cols) {
      if (is.null(cols)) return(df)
      keep <- intersect(cols, colnames(df))
      if (length(keep)) df[, keep, drop = FALSE] else df[ , 0, drop = FALSE]
    }

    # 三个数据 reactive：只在当前样本改变时重算
    data_meta <- reactive({
      sample <- current_sample()

      if (!sample %in% names(metadata)) {
        cat("===> [错误] 样本", sample, "不在 metadata 中!\n")
        return(data.frame())
      }

      df <- metadata[[sample]]
      result <- subset_cols(df, show_cols_meta)
      result
    })

    data_cell <- reactive({
      sample <- current_sample()

      if (!sample %in% names(metadata_cell)) {
        cat("===> [错误] 样本", sample, "不在 metadata_cell 中!\n")
        return(data.frame())
      }

      df <- metadata_cell[[sample]]
      result <- subset_cols(df, show_cols_cell)
      result
    })

    # Initialize plot controls
    plot_params <- plot_controls_Server("plot_controls")

    output$rna_qc_plot <- renderPlot({
      plot_rna_qc(
        data_cell(),
        sample_name = selected_sample(),
        title_size = plot_params()$title_size,
        axis_text_size = plot_params()$axis_text_size,
        axis_title_size = plot_params()$axis_title_size,
        legend_text_size = plot_params()$legend_text_size,
        legend_title_size = plot_params()$legend_title_size,
        legend_position = plot_params()$legend_position
      )
    })

    output$adt_qc_plot <- renderPlot({
      plot_adt_qc(
        data_meta(),
        data_cell(),
        sample_name = selected_sample(),
        title_size  = plot_params()$title_size,
        axis_text_size = plot_params()$axis_text_size,
        axis_title_size = plot_params()$axis_title_size,
        legend_text_size = plot_params()$legend_text_size,
        legend_title_size = plot_params()$legend_title_size,
        legend_position = plot_params()$legend_position
      )
    })


    # 监听输入变化
    observeEvent(input$sample_select, {
      cat("===> [调试] 样本选择发生变化:", input$sample_select, "\n")
    }, ignoreInit = FALSE)

    # 监听tab切换
    observeEvent(input$tabs, {
      cat("===> [调试] Tab切换到:", input$tabs, "\n")
    }, ignoreInit = FALSE)

    # （可选）隐藏 tab 时挂起不渲染：保留也行，去掉也行
    outputOptions(output, "adt_qc_plot", suspendWhenHidden = TRUE)

    # # 上一 / 下一样本
    # observeEvent(input$prev_sample, {
    #   idx <- match(current_sample(), sample_names)
    #   if (!is.na(idx) && idx > 1) {
    #     updateSelectInput(session, "sample_select", selected = sample_names[idx - 1])
    #   }
    # })
    # observeEvent(input$next_sample, {
    #   idx <- match(current_sample(), sample_names)
    #   if (!is.na(idx) && idx < length(sample_names)) {
    #     updateSelectInput(session, "sample_select", selected = sample_names[idx + 1])
    #   }
    # })
  })
}