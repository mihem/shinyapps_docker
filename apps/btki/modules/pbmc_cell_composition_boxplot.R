# ----------------------------------
# UI
# ----------------------------------
cell_composition_boxplot_UI <- function(id) {
  ns <- NS(id)

  fluidRow(
    useShinyjs(),  # 启用 shinyjs
    tags$script(HTML(sprintf("
      (function(){
        var nsId = '%s';
        var lastW = -1, lastH = -1;
        var timer = null;

        function send(){
          var w = window.innerWidth;
          var h = window.innerHeight;
          if (w === lastW && h === lastH) return; // 尺寸未变化，不发送
          lastW = w; lastH = h;
          Shiny.setInputValue(nsId, {width:w, height:h}, {priority:'event'});
        }

        function debouncedSend(){
          if (timer) clearTimeout(timer);
          timer = setTimeout(send, 250); // 防抖 250ms
        }

        $(document).on('shiny:connected', function(){
          send();            // 初始发送
          $(window).on('resize.'+nsId, debouncedSend);
        });

        // 可选：在 Shiny 会话结束时解绑
        $(document).on('shiny:disconnected', function(){
          $(window).off('resize.'+nsId);
        });
      })();
    ", ns("window_size")))),
    column(
      width = 3,
      box(
        title = "Annotation Selection",
        status = "primary",
        solidHeader = TRUE,
        width = NULL,
        # 🔥 修改：移除硬编码的选择项，让Server端动态更新
        selectInput(
          inputId = ns("which_plot"),
          label = "Select grouping variable",
          choices = c("Loading..." = "loading"),  # 占位符
          selected = "loading"
        ),
        actionButton(
          inputId = ns("plot_btn"),
          label = "Plot",
          icon  = icon("play"),
          width = "100%"
        ),
        div(
          style = "margin-top:6px; font-size:12px; color:#666;",
          textOutput(ns("calc_status"))
        )
      ),
      box(
        title = "Plot Controls",
        status = "primary",
        solidHeader = TRUE,
        collapsible = TRUE,
        collapsed = FALSE,
        width = NULL,
        plot_controls_UI(ns("plot_controls"))
      )
    ),
    # Plot Panel
    column(
      width = 9,
      box(
        title = "Cell Composition",
        status = "primary",
        solidHeader = TRUE,
        width = NULL,
        # 动态高度的占位 UI
        uiOutput(ns("boxplot_ui"))
      )
    )
  )
}

# ----------------------------------
# Server
# ----------------------------------
cell_composition_boxplot_Server <- function(id, cached_data, tissue = "PBMC",
                                            meta_df = NULL,
                                            features = c("celltype_merged.l2", "sample", "treatment", "treatment_hour", "timepoint")) {
  moduleServer(id, function(input, output, session) {

    # 监听 box 的大小
    window_size <- reactive({
      req(input$window_size)
      input$window_size
    })

    # 🔥 检查可用的 features 列
    available_features <- intersect(features, colnames(meta_df))
    missing_features   <- setdiff(features, available_features)

    # 必需列检查
    required_features <- c("celltype_merged.l2", "sample")
    missing_required <- setdiff(required_features, available_features)

    if (length(missing_required) > 0) {
      stop(paste("Error: Required column is missing:", paste(missing_required, collapse = ", ")))
    }

    CELL_TYPES              <- unique(meta_df$celltype_merged.l2) %>% sort()
    meta_df[["annotated"]]  <- meta_df$celltype_merged.l2

    # 🔥 动态构建 select 语句，只选择存在的列
    select_cols <- c("subject_id", "sample", "annotated")

    # 添加可选的特征列
    if ("treatment" %in% available_features) {
      select_cols <- c(select_cols, "treatment")
    }
    if ("treatment_hour" %in% available_features) {
      select_cols <- c(select_cols, "treatment_hour")
    }
    if ("timepoint" %in% available_features) {
      select_cols <- c(select_cols, "timepoint")
    }

    # 🔥 动态构建 group_by 语句
    group_cols <- select_cols  # 使用所有可用的列进行分组

    CELL_TYPE_COUNTS <- meta_df %>%
      dplyr::select(all_of(select_cols)) %>%  # 使用 all_of() 确保安全选择
      group_by(across(all_of(group_cols))) %>%
      summarise(cell_number = n(), .groups = "drop") %>%
      group_by(sample) %>%
      mutate(total_cell_number = sum(cell_number)) %>%
      mutate(percent = cell_number / total_cell_number * 100) %>%
      ungroup()

    qsave(CELL_TYPE_COUNTS, file = paste0("data/cached_", tolower(tissue), "_composition_boxplot.qs"), nthreads = 4)

    CELL_TYPE_COUNTS_SPLIT <- CELL_TYPE_COUNTS |>
      dplyr::arrange(annotated) |>
      dplyr::group_by(annotated) |>
      dplyr::group_split() |>
      stats::setNames(CELL_TYPES)

    # 🔥 根据可用列动态更新 selectInput 的选择项
    available_choices <- list()
    if ("treatment" %in% available_features) {
      available_choices[["Treatment"]] <- "treatment"
    }
    if ("treatment_hour" %in% available_features) {
      available_choices[["Treatment Hour"]] <- "treatment_hour"
    }
    if ("timepoint" %in% available_features) {
      available_choices[["Timepoint"]] <- "timepoint"
    }

    # 如果没有可用的分组变量，添加默认选项
    if (length(available_choices) == 0) {
      available_choices <- list("No grouping available" = "none")
    }

    # 🔥 动态更新 selectInput
    observe({
      updateSelectInput(
        session = session,
        inputId = "which_plot",
        choices = available_choices,
        selected = if (length(available_choices) > 0) available_choices[[1]] else "none"
      )
    })

    # 2) Plot 控件参数
    plot_params <- plot_controls_Server("plot_controls")

    # 3) 计算与绘图分离：
    precomputed_plots <- reactiveVal(NULL)

    #    (b) 监听下拉框变化 -> 立即计算
    observeEvent(input$which_plot, {
      req(input$which_plot)

      # 🔥 检查是否有有效的分组变量
      if (input$which_plot == "none") {
        output$calc_status <- renderText("No valid grouping variables available.")
        precomputed_plots(list())
        return()
      }

      output$calc_status <- renderText("Computing graph object...")

      # 这里做图对象生成
      x_var_sel <- input$which_plot
      x_lab_map <- c(
        treatment      = "Treatment",
        treatment_hour = "Treatment Hour",
        timepoint      = "Timepoint"
      )

      # 🔥 检查选中的变量是否在数据中存在
      if (length(CELL_TYPE_COUNTS_SPLIT) > 0) {
        sample_data <- CELL_TYPE_COUNTS_SPLIT[[1]]
        if (!x_var_sel %in% colnames(sample_data)) {
          output$calc_status <- renderText(paste("Variable", x_var_sel, "not found in data."))
          precomputed_plots(list())
          return()
        }
      }

      # 尝试生成图对象
      plots <- tryCatch({
        suppressWarnings(
          GenerateBoxplots(
            plot_data       = CELL_TYPE_COUNTS_SPLIT,
            pdf_file        = NULL,
            x_var           = x_var_sel,
            x_lab           = x_lab_map[[x_var_sel]],
            rows            = 3,
            cols            = 6,
            width           = 16,
            height          = 10,
            title_size      = plot_params()$title_size,
            axis_text_size  = plot_params()$axis_text_size,
            legend_position = plot_params()$legend_position
          ) %>% invisible()
        )
      }, error = function(e) {
        message("GenerateBoxplots error: ", e$message)
        return(list())
      })

      precomputed_plots(plots)

      # 清空之前的绘图输出（等待用户点 Plot）
      output$composition_plot <- renderPlot({})
      output$calc_status <- renderText(
        paste0("Prepared: ", length(plots), " panels. Click the Plot button to render.")
      )

      # 清空图片后的 UI 更新 - 使用固定高度
      output$boxplot_ui <- renderUI({
        ns <- session$ns
        # 直接使用窗口高度，不计算动态高度
        plot_height <- window_size()$height - 150

        shinycssloaders::withSpinner(
          plotOutput(ns("composition_plot"), height = paste0(plot_height, "px")),
          type = 4,
          color = "#3c8dbc",
          color.background = "#FFFFFF"
        )
      })
    }, ignoreNULL = FALSE)  # 初次也触发

    # 4) 点击按钮才真正绘图
    observeEvent(input$plot_btn, {
      plots <- precomputed_plots()
      if (is.null(plots) || length(plots) == 0) {
        output$calc_status <- renderText("There are no drawables (list is empty).")
        return()
      }

      output$calc_status <- renderText(
        paste0("Drawing completed (", length(plots), " panels).")
      )

      # 绘图时才计算动态高度并更新 UI
      n_plots <- length(plots)
      ncol_display <- 4
      nrow <- ceiling(n_plots / ncol_display)
      actual_plot_height <- ifelse(n_plots == 0, 200, nrow * 300)

      # 更新 UI 为实际需要的高度
      output$boxplot_ui <- renderUI({
        ns <- session$ns
        shinycssloaders::withSpinner(
          plotOutput(ns("composition_plot"), height = paste0(actual_plot_height, "px")),
          type = 4,
          color = "#3c8dbc",
          color.background = "#FFFFFF"
        )
      })

      # 渲染图表
      output$composition_plot <- renderPlot({
        suppressWarnings(
          cowplot::plot_grid(plotlist = plots, ncol = 4)
        )
      })
    })

    # 可选：当 plot 控件改变时重新计算
    observeEvent(plot_params(), {
      req(input$which_plot)
      req(input$which_plot != "none")

      isolate({
        x_var_sel <- input$which_plot
        x_lab_map <- c(
          treatment="Treatment",
          treatment_hour="Treatment Hour",
          timepoint="Timepoint"
        )
        plots <- tryCatch({
          suppressWarnings(
            GenerateBoxplots(
              plot_data       = CELL_TYPE_COUNTS_SPLIT,
              pdf_file        = NULL,
              x_var           = x_var_sel,
              x_lab           = x_lab_map[[x_var_sel]],
              rows            = 3,
              cols            = 6,
              width           = 16,
              height          = 10,
              title_size      = plot_params()$title_size,
              axis_text_size  = plot_params()$axis_text_size,
              legend_position = plot_params()$legend_position
            ) %>% invisible()
          )
        }, error = function(e) {
          message("GenerateBoxplots error (recalc): ", e$message)
          return(list())
        })
        precomputed_plots(plots)
        output$calc_status <- renderText(
          paste0("Parameter change: Recalculated ", length(plots), " panels. Click the Plot button to render.")
        )
      })
    })
  })
}
