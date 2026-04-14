plot_controls_UI <- function(id) {
  ns <- NS(id)
  tagList(
    shinyjs::useShinyjs(),
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

    # h4("Facet Settings"),
    # 动态显示 facet columns 滑块
    conditionalPanel(
      condition = "output.show_facet_ncol_controls",
      ns = ns,
      h4("Layout Settings"),
      sliderInput(
        ns("facet_ncol"),
        label = "Facet Columns:",
        min = 1,
        max = 8,
        value = 2,
        step = 1,
        ticks = TRUE
      )
    ),
    # # Plot Size 控件，仅在参数齐全时显示
    # conditionalPanel(
    #   condition = "output.show_plot_size_controls",
    #   ns = ns,
    #   h4("Plot Size"),
    #   sliderInput(
    #     ns("plot_size"),
    #     label = "Plot Size (px):",
    #     min = 150, # 仅占位，实际由服务器端动态更新
    #     max = 450,
    #     value = 300,
    #     step = 10,
    #     ticks = TRUE
    #   )
    # ),
    conditionalPanel(
      condition = "output.show_plot_size_controls",
      ns = ns,
      h4("Plot Size"),
      sliderTextInput(
        ns("plot_size"),
        label = "Plot Per Row:",
        choices = c(1, 2, 3, 4),
        selected = 2,
        grid = TRUE
      )
    ),

    h4("Legend Settings"),

    checkboxInput(ns("show_legend"), "Show Legend", TRUE),

    # 动态显示 Legend Point Size 滑块
    conditionalPanel(
      condition = "output.show_legend_point_size_controls",
      ns = ns,
      h4("Layout Settings"),
      sliderInput(
        ns("legend_point_size"),
        label = "Legend Point Size:",
        min = 1,
        max = 8,
        value = 1,
        step = 1,
        ticks = TRUE
      )
    ),

    selectInput(
      ns("legend_position"),
      "Legend Position",
      choices = c("right", "left", "top", "bottom"),
      selected = "bottom"
    ),

    h4("Font Settings"),
    sliderInput(ns("title_size"),        "Title Size",        5, 20, 15, 1),
    sliderInput(ns("axis_text_size"),    "Axis Text Size",    5, 20, 10, 1),
    sliderInput(ns("axis_title_size"),   "Axis Title Size",   5, 20, 12, 1),
    sliderInput(ns("legend_text_size"),  "Legend Text Size",  5, 20, 10, 1),
    sliderInput(ns("legend_title_size"), "Legend Title Size", 5, 20, 10, 1),

    h4("Export Options"),
    downloadButton(ns("download_plot"), "Download Plot", class = "btn-primary")
  )
}

plot_controls_Server <- function(id, default_params = list(), window_size = NULL, group_count = NULL) {
  moduleServer(id, function(input, output, session) {
      window_size <- reactive({
        if (is.null(input$window_size)) {
          return(list(width = 1200, height = 800))  # 默认值
        }
        input$window_size
      })

      if (!is.null(default_params$facet_ncol)) {
        # 控制是否显示 facet controls
        output$show_facet_ncol_controls <- reactive({
          is.null(default_params$facet_ncol)
        })
        outputOptions(output, "show_facet_ncol_controls", suspendWhenHidden = FALSE)
      }

      if (!is.null(default_params$legend_point_size)) {
        output$show_legend_point_size_controls <- reactive({
          !is.null(default_params$legend_point_size)
        })
        outputOptions(output, "show_legend_point_size_controls", suspendWhenHidden = FALSE)
      }

      # 控制是否显示 plot_size 控件
      output$show_plot_size_controls <- reactive({
        !is.null(default_params$show_plot_size)
      })
      outputOptions(output, "show_plot_size_controls", suspendWhenHidden = FALSE)


      gc <- if (is.null(group_count)) reactive(NULL) else group_count

      # 统一计算的 reactive：供本模块内其他位置复用
      grid_combinations_r <- reactive({
        n <- gc()
        if (is.null(n) || is.na(n) || n <= 0) n <- 1

        find_grid_combinations(
          plot_num = n,
          screen_w = (window_size()$width - 250) / 12 * 9 - 15*2 - 10*2,
          screen_h = window_size()$height - 65,
          plot_size_min = 300
        )
      })

    # 根据 grid_combinations 变化，动态更新控件
    observeEvent(grid_combinations_r(), {
      grid_combinations <- grid_combinations_r()

      # 检查数据是否有效
      if (is.null(grid_combinations) || nrow(grid_combinations) == 0) {
        return()
      }
      if (nrow(grid_combinations) == 1) {
        # shinyjs::disable("plot_size")
      } else {
        shinyWidgets::updateSliderTextInput(
          session, "plot_size",
          choices = as.character(sort(unique(grid_combinations$ncol))),
          selected = as.character(grid_combinations[1, "ncol"])
        )
        shinyjs::enable("plot_size")
      }
    }, ignoreNULL = TRUE)


    # 初始化默认值
    observe({
      updateSliderInput(session, "title_size",        value = default_params$title_size %||% 15)
      updateSliderInput(session, "axis_text_size",    value = default_params$axis_text_size %||% 10)
      updateSliderInput(session, "axis_title_size",   value = default_params$axis_title_size %||% 12)
      updateSliderInput(session, "legend_text_size",  value = default_params$legend_text_size %||% 10)
      updateSliderInput(session, "legend_title_size", value = default_params$legend_title_size %||% 10)
      updateSelectInput(session, "legend_position",   selected = default_params$legend_position %||% "bottom")
      updateCheckboxInput(session, "show_legend",     value = default_params$show_legend %||% TRUE)
    })

    # 监听 show_legend 的变化
    observeEvent(input$show_legend, {
      if (isTRUE(input$show_legend)) {
        shinyjs::enable(session$ns("legend_position"))
      } else {
        # shinyjs::disable(session$ns("legend_position"))
      }
    }, ignoreNULL = TRUE)

    # 返回绘图参数
    plot_params <- reactive({
      grid_combinations <- grid_combinations_r()

      # 安全检查
      if (is.null(grid_combinations) || nrow(grid_combinations) == 0) {
        # 返回默认参数
        return(list(
          title_size        = input$title_size %||% 15,
          axis_text_size    = input$axis_text_size %||% 10,
          axis_title_size   = input$axis_title_size %||% 12,
          legend_text_size  = input$legend_text_size %||% 10,
          legend_title_size = input$legend_title_size %||% 10,
          legend_position   = if (isTRUE(input$show_legend)) input$legend_position else "none",
          screen_height     = window_size()$height - 80,
          plot_ncol         = 1
        ))
      }

      # 获取选中的行
      plot_size_selected <- as.numeric(input$plot_size %||% grid_combinations[1, "ncol"])
      row_selected <- grid_combinations %>%
        dplyr::filter(ncol == plot_size_selected)

      # 如果没有匹配的行，使用第一行
      if (nrow(row_selected) == 0) {
        row_selected <- grid_combinations[1, ]
      }

      # 安全获取值
      nrow_val    <- row_selected$nrow[1] %||% 1
      ncol_val    <- row_selected$ncol[1] %||% 1
      plot_size   <- row_selected$plot_size[1] %||% 300
      actuall_h   <- row_selected$actuall_h[1] %||% (window_size()$height - 80)

      # 计算页面高度
      if (nrow_val == 1) {
        page_height <- actuall_h
      } else {
        page_height <- max(actuall_h + 150, window_size()$height - 80)
      }

      params_list <- list(
        title_size        = input$title_size,
        axis_text_size    = input$axis_text_size,
        axis_title_size   = input$axis_title_size,
        legend_text_size  = input$legend_text_size,
        legend_title_size = input$legend_title_size,
        legend_position   = if (isTRUE(input$show_legend)) input$legend_position else "none",
        screen_height     = page_height,
        plot_ncol         = ncol_val
      )

      if (!is.null(default_params$facet_ncol)) {
        params_list$facet_ncol <- input$facet_ncol %||% 2
      }
      if (!is.null(default_params$legend_point_size)) {
        params_list$legend_point_size <- input$legend_point_size %||% 4
      }
      if (!is.null(default_params$show_plot_size)) {
        params_list$plot_size <- plot_size
      }

      params_list
    })

    # Download功能
    output$download_plot <- downloadHandler(
      filename = function() paste0("plot_", Sys.Date(), ".png"),
      content = function(file) {
        png(file, width = 1200, height = 900, res = 120)
        plot.new()
        text(0.5, 0.5, "Implement plot saving logic", cex = 1.2)
        dev.off()
      }
    )

    plot_params
  })
}