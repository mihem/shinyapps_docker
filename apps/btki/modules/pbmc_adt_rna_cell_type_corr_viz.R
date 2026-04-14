# Source plot controls
source("modules/plot_controls.R")

# =============== Cell Type Visualization Module ===============
pbmc_adt_rna_cell_type_corr_viz_UI <- function(id) {
  ns <- NS(id)
  tagList(
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
        4,
        box(
          title = "Select Cell Type",
          status = "primary",
          solidHeader = TRUE,
          width = NULL,
          selectInput(
            ns("cell_type_select"),
            "Cell Type:",
            choices = c("B", "T", "NK", "Mono"),
            selected = "B"
          ),
          actionButton(
            inputId = ns("plot_btn"),
            label = "Generate Plots",
            icon  = icon("play"),
            width = "100%"
          ),
        ),
        box(
          title = "Plot Controls",
          status = "primary",
          solidHeader = TRUE,
          collapsible = TRUE,
          collapsed = TRUE,
          width = NULL,
          plot_controls_UI(ns("plot_controls"))
        ),
        uiOutput(ns("explanatory_box"))
      ),
        column(8, uiOutput(ns("plot_box"))
      )
    )
  )
}

pbmc_adt_rna_cell_type_corr_viz_Server <- function(id, data_list) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Initialize plot controls
    plot_params <- plot_controls_Server("plot_controls", default_params = list(facet_ncol = 2))

    # 监听 box 的大小
    window_size <- reactive({
      req(input$window_size)
      input$window_size
    })

    # Update cell type choices based on data_list
    observe({
      if (!is.null(data_list) && length(data_list) > 0) {
        choice_names <- names(data_list)
        if (length(choice_names) > 0) {
          updateSelectInput(session, "cell_type_select", choices = choice_names, selected = choice_names[1])
        }
      }
    })

    # Language state: "cn" or "en"
    lang <- reactiveVal("en")

    observeEvent(input$lang_toggle, {
      current_lang <- lang()
      new_lang <- if (!is.null(current_lang) && length(current_lang) > 0 && current_lang == "cn") "en" else "cn"
      lang(new_lang)
      # Update button label
      shiny::updateActionButton(
        session,
        "lang_toggle",
        label = if (new_lang == "cn") "EN" else "汉"
      )
    })

    # Render the explanation content in a box with language toggle
    output$explanatory_box <- renderUI({
      lang_val <- lang()
      box(
        title = if (!is.null(lang_val) && length(lang_val) > 0 && lang_val == "cn") "相关性热图说明" else "Heatmap Explanation",
        status = "primary",
        solidHeader = TRUE,
        width = NULL,
        div(
          style = "position:relative;",
          tags$div(
            style = "position:absolute; top:5px; right:10px; z-index:10;",
            actionButton(ns("lang_toggle"),
                        if (!is.null(lang_val) && length(lang_val) > 0 && lang_val=="cn") "EN" else "汉",
                        class = "btn-sm")
          ),
          uiOutput(ns("explanatory_content"))
        )
      )
    })

    # Explanatory content (bilingual) - 保持原有代码不变
    output$explanatory_content <- renderUI({
      lang_val <- lang()
      if (!is.null(lang_val) && length(lang_val) > 0 && lang_val == "cn") {
        div(
          tags$h4("RNA–ADT 相关性热图说明"),
          tags$p("展示在每个细胞 cluster 内，指定基因 (RNA) 与其对应抗体标签 (ADT) 的单细胞水平相关性，用于评估转录与蛋白丰度耦合程度。"),

          tags$h5("数据来源与输入"),
          tags$ul(
            tags$li("RNA：Seurat 对象中 assay = RNA, slot = data 的归一化表达。"),
            tags$li("ADT：assay = ADT, slot = data (如 CLR / DSB / 其他归一化结果)。"),
            tags$li("marker_df：包含配对列 rna, adt；可是一对一或多对多。"),
            tags$li("按 cluster_col 将细胞分组，逐组计算相关。")
          ),

          tags$h5("计算方法"),
          tags$ul(
            tags$li("默认 Spearman：对每个配对在该 cluster 的所有细胞上 rank 后再算 Pearson。"),
            tags$li("Pearson：直接基于标准化后表达。"),
            tags$li("Kendall：逐对计算，较慢。"),
            tags$li("若某一方在该 cluster 方差为 0 或缺失，则相关为 NA。")
          ),

          tags$h5("热图结构"),
          tags$ul(
            tags$li("分面 (facet)：每个 cluster 一个子图。"),
            tags$li("横轴：RNA 基因 (marker_df$rna)。"),
            tags$li("纵轴：ADT 标记 (marker_df$adt)。"),
            tags$li("颜色：相关系数 (可对称映射到 [-lim, +lim])；红=正相关，蓝=负相关，白=接近 0。"),
            tags$li("格子文字：数值或 'NA'。")
          ),

          tags$h5("如何解读"),
          tags$ul(
            tags$li("高正相关：该 cluster 中基因表达高的细胞同时具有高蛋白信号，说明转录-表面水平耦合紧密。"),
            tags$li("接近 0：单细胞波动不同步，可能受技术噪声、时滞或调控分离。"),
            tags$li("负相关：少见；需警惕命名错误、背景校正问题或真实逆向调控。"),
            tags$li("跨 cluster 对比：发现特异性（只在某类细胞高）或普遍性（所有 cluster 都高）的基因-蛋白耦合模式。"),
            tags$li("多个 ADT 与一个基因或反之：可暴露抗体特异性或交叉反应。")
          ),

          tags$h5("NA 的常见原因"),
          tags$ul(
            tags$li("该配对的基因或 ADT 不存在于对象中 (被过滤 / 命名不一致)。"),
            tags$li("该 cluster 细胞数 < min_cells_per_cluster。"),
            tags$li("特征在该 cluster 内表达无方差（全部或几乎全零）。")
          ),

          tags$h5("典型应用"),
          tags$ul(
            tags$li("验证候选 marker（转录与蛋白是否一致）。"),
            tags$li("评估抗体面板质量与特异性。"),
            tags$li("发现转录-蛋白解耦的生物学现象（例如延迟表达、储存池、再循环）。")
          ),

          tags$h5("使用与参数要点"),
          tags$ul(
            tags$li("intersect_only=TRUE：过滤掉缺失任一侧的配对。"),
            tags$li("symmetric_limits=TRUE：所有分面共用对称色标，便于跨 cluster 比较。"),
            tags$li("label_digits：控制数值标签精度。"),
            tags$li("cor_method：pearson / spearman / kendall。")
          ),

          tags$h5("注意与改进建议"),
          tags$ul(
            tags$li("高零比例会压低相关，可先过滤低表达或使用表达阈值。"),
            tags$li("ADT 需背景校正（如 CLR 或 DSB），否则虚假相关。"),
            tags$li("可追加 p 值或显著性符号（当前仅展示相关系数）。"),
            tags$li("若配对多，可增加交互式筛选或只显示 |相关| ≥ 阈值。"),
            tags$li("对批次敏感：必要时先整合或回归批次效应。")
          ),

          tags$p(
            tags$strong("一句话总结："),
            "该热图用单细胞相关系数直观展示各细胞类型内 RNA 与表面蛋白信号的耦合强弱，帮助评估 marker 可靠性与生物学特异性。"
          )
        )
      } else {
        div(
          tags$h4("RNA–ADT Correlation Heatmap"),
          tags$p("Shows, per cell cluster, the single‑cell correlation between selected genes (RNA) and their matching antibody tags (ADT), assessing transcript–protein coupling."),

          tags$h5("Data & Inputs"),
          tags$ul(
            tags$li("RNA: Seurat assay='RNA', slot='data' (normalized expression)."),
            tags$li("ADT: assay='ADT', slot='data' (e.g. CLR / DSB normalized)."),
            tags$li("marker_df: data frame with columns rna, adt (one-to-one or many-to-many)."),
            tags$li("Cells grouped by cluster_col; correlations computed within each cluster.")
          ),

          tags$h5("Computation"),
          tags$ul(
            tags$li("Default Spearman (rank then Pearson)."),
            tags$li("Pearson available; Kendall supported but slower (pairwise loop)."),
            tags$li("Zero variance or missing feature ⇒ NA.")
          ),

          tags$h5("Heatmap Layout"),
          tags$ul(
            tags$li("Facet: one panel per cluster."),
            tags$li("X axis: RNA genes (marker_df$rna)."),
            tags$li("Y axis: ADT markers (marker_df$adt)."),
            tags$li("Fill: correlation (symmetric scale if enabled): red=positive, blue=negative, white≈0."),
            tags$li("Cell label: numeric value or 'NA'.")
          ),

          tags$h5("Interpretation"),
          tags$ul(
            tags$li("High positive: cells with higher RNA also have higher protein signal (tight coupling)."),
            tags$li("Near zero: uncoupled variation (noise, delay, regulation divergence)."),
            tags$li("Negative: uncommon; check naming, background, or true inverse regulation."),
            tags$li("Cross-cluster comparison reveals specificity (restricted) vs ubiquity (all high)."),
            tags$li("Multiple ADTs per gene (or vice versa) can expose antibody specificity or cross-reactivity.")
          ),

          tags$h5("Why NA?"),
          tags$ul(
            tags$li("Feature missing in object."),
            tags$li("Cluster size < min_cells_per_cluster."),
            tags$li("No variance (all zeros / constant).")
          ),

          tags$h5("Use Cases"),
          tags$ul(
            tags$li("Validate candidate markers (transcript ↔ protein agreement)."),
            tags$li("Assess antibody panel quality / specificity."),
            tags$li("Detect transcript–protein decoupling (e.g. delays, storage, recycling).")
          ),

          tags$h5("Key Parameters"),
          tags$ul(
            tags$li("intersect_only: drop pairs with missing side."),
            tags$li("symmetric_limits: enforce shared ± range across facets."),
            tags$li("label_digits: numeric label precision."),
            tags$li("cor_method: pearson / spearman / kendall.")
          ),

          tags$h5("Notes & Tips"),
          tags$ul(
            tags$li("High zero inflation lowers correlations; consider filtering low-expression features."),
            tags$li("Ensure ADT background correction (CLR / DSB) to avoid spurious values."),
            tags$li("Optionally add p-values or significance stars (not shown here)."),
            tags$li("For many pairs, enable interactive filtering or hide low |corr| cells."),
            tags$li("Handle batch effects (integration / regression) before correlation.")
          ),

          tags$p(
            tags$strong("Summary: "),
            "Faceted heatmap visualizes within-cluster RNA–protein correlation, spotlighting marker reliability and cell-type-specific coupling."
          )
        )
      }
    })

    # ========== Add plot state management ==========

    # Store computed results and state
    computed_plot <- reactiveVal(NULL)
    loading_state <- reactiveVal(FALSE)
    current_cell_type <- reactiveVal(NULL)

    # ========== Dynamically generate right-side plot box ==========
    output$plot_box <- renderUI({
      lang_val <- lang()
      title_suffix <- if (!is.null(lang_val) && length(lang_val) > 0 && lang_val == "cn") "RNA-ADT 相关性热图" else "RNA-ADT Correlation Heatmap"

      # Remove fixed height, use dynamic calculation
      # plot_height <- input$window_size$height - 150  # Delete this line

      box(
        title = title_suffix,
        status = "primary",
        solidHeader = TRUE,
        width = NULL,
        # Add layout suggestion
        div(
          style = "margin-bottom: 10px; padding: 5px; background-color: #f8f9fa; border-radius: 4px;",
          textOutput(ns("layout_suggestion"), inline = TRUE)
        ),
        uiOutput(ns("plot_content"))
      )
    })

    # ========== Click button to generate plot ==========
    observeEvent(input$plot_btn, {
      req(input$cell_type_select)
      req(data_list)
      req(length(data_list) > 0)

      loading_state(TRUE)
      current_cell_type(input$cell_type_select)

      # Delay execution to ensure UI update
      shinyjs::delay(50, {
        tryCatch({
          # Validate that the selected cell type exists in data_list
          if (!input$cell_type_select %in% names(data_list)) {
            loading_state(FALSE)
            computed_plot(NULL)
            return()
          }

          # Extract data for the selected cell type
          selected_data <- data_list[[input$cell_type_select]]

          if (is.null(selected_data)) {
            loading_state(FALSE)
            computed_plot(NULL)
            return()
          }

          # Generate plot
          plot_result <- generate_correlation_heatmap(selected_data, plot_params())

          # Store result
          computed_plot(plot_result)
          loading_state(FALSE)

        }, error = function(e) {
          loading_state(FALSE)
          computed_plot(NULL)
          message("Plot generation error: ", e$message)
        })
      })

      # Get data and calculate cluster count
      selected_data <- data_list[[input$cell_type_select]]
      if (!is.null(selected_data) && "cluster" %in% colnames(selected_data)) {
        n_clusters <- length(unique(selected_data$cluster))

        # Send layout suggestion to UI
        output$layout_suggestion <- renderText({
          current_ncol <- plot_params()$facet_ncol %||% 2
          suggested_rows <- ceiling(n_clusters / current_ncol)
          paste("Layout suggestion:", n_clusters, "clusters with",
                current_ncol, "columns =", suggested_rows, "rows")
        })
      }
    })

    # ========== Update layout suggestion ==========
    update_layout_suggestion <- function() {
      if (!is.null(current_cell_type()) && !is.null(data_list)) {
        selected_data <- data_list[[current_cell_type()]]
        if (!is.null(selected_data) && "cluster" %in% colnames(selected_data)) {
          n_clusters <- length(unique(selected_data$cluster))
          n_rna <- length(unique(selected_data$rna))
          n_adt <- length(unique(selected_data$adt))

          # Send layout suggestion to UI
          output$layout_suggestion <- renderText({
            current_ncol <- plot_params()$facet_ncol %||% 2
            suggested_rows <- ceiling(n_clusters / current_ncol)

            # Calculate current height
            window_width <- input$window_size$width %||% 1200
            available_width <- window_width * 0.65 - 50
            estimated_height <- calculate_plot_height(available_width)

            paste(
              "Layout:", n_clusters, "clusters,", current_ncol, "columns,", suggested_rows, "rows |",
              "Heatmap size:", n_rna, "×", n_adt, "tiles |",
              "Estimated height:", round(estimated_height), "px"
            )
          })
        }
      }
    }

    # ========== Add height calculation function ==========
    calculate_plot_height <- function(available_width) {
      # Get current parameters
      params <- plot_params()
      facet_ncol <- params$facet_ncol %||% 2

      # Get cluster count of current data
      if (!is.null(current_cell_type()) && !is.null(data_list)) {
        selected_data <- data_list[[current_cell_type()]]
        if (!is.null(selected_data) && "cluster" %in% colnames(selected_data)) {
          n_clusters <- length(unique(selected_data$cluster))

          # Get RNA and ADT counts to estimate each facet's size
          n_rna <- length(unique(selected_data$rna))
          n_adt <- length(unique(selected_data$adt))

          # More precise calculation
          # Margins for each facet (title, axis labels, etc.)
          facet_title_height <- 25    # Facet title height
          axis_text_height <- 40      # X-axis text height (considering 45-degree rotation)
          axis_title_height <- 20     # Axis title height

          # Calculate each facet's width
          facet_spacing <- 20         # Facet spacing
          y_axis_space <- 80          # Y-axis label and title space

          facet_width <- (available_width - (facet_ncol - 1) * facet_spacing) / facet_ncol

          # Tile width (minus Y-axis space)
          plot_area_width <- facet_width - y_axis_space
          tile_width <- plot_area_width / n_rna

          # Due to coord_fixed(), tile height equals width
          tile_height <- tile_width

          # Net height of each facet (only plot area)
          plot_area_height <- tile_height * n_adt

          # Total height of each facet (including margins)
          facet_total_height <- plot_area_height + facet_title_height + axis_text_height

          # Calculate total rows
          n_rows <- ceiling(n_clusters / facet_ncol)

          # Total height calculation
          plot_area_total_height <- n_rows * facet_total_height + (n_rows - 1) * 15  # 15px row spacing

          # Add global element heights
          main_title_height <- 40     # Main title
          subtitle_height <- 25       # Subtitle
          legend_height <- 60         # Legend (if at bottom)
          top_bottom_margin <- 40     # Top and bottom margins

          total_height <- plot_area_total_height + main_title_height + subtitle_height +
                         legend_height + top_bottom_margin

          # Set reasonable min and max height
          min_height <- 300
          max_height <- 1500

          # Ensure height is within reasonable range
          final_height <- max(min_height, min(total_height, max_height))

          return(round(final_height))
        }
      }

      # Default height
      return(400)
    }

    # ========== Dynamic content display ==========
    output$plot_content <- renderUI({
      # Get window size
      window_width <- input$window_size$width %||% 1200
      window_height <- input$window_size$height %||% 800

      # Calculate available width (considering left panel and margins)
      available_width <- window_width * 0.65 - 50  # Right column occupies 65%, minus margins

      # Dynamically calculate height
      plot_height <- calculate_plot_height(available_width)

      if (input$plot_btn == 0) {
        # Initial state: show prompt
        return(
          div(
            style = paste0("height: 400px; display: flex; align-items: center; justify-content: center;"),
            div(
              style = "text-align: center; color: #6c757d;",
              icon("chart-area", style = "font-size: 48px; margin-bottom: 20px;"),
              h4("Select cell type and click 'Generate Plots'"),
              p("Choose a cell type from the dropdown and click the generate button to view the RNA-ADT correlation heatmap.")
            )
          )
        )
      }

      if (loading_state()) {
        # 加载状态：显示加载器
        return(
          div(
            style = paste0("height: ", plot_height, "px; display: flex; align-items: center; justify-content: center;"),
            div(
              style = "text-align: center;",
              div(
                class = "spinner-border text-primary",
                role = "status",
                style = "width: 3rem; height: 3rem;"
              ),
              h4("Generating correlation heatmap...", style = "margin-top: 20px; color: #6c757d;")
            )
          )
        )
      }

      # 显示图表 - 使用 shinycssloaders 的 spinner
      shinycssloaders::withSpinner(
        plotOutput(ns("rna_adt_corr_heatmap"), height = paste0(plot_height, "px")),
        type = 6,
        color = "#0d6efd",
        size = 1
      )
    })

    # ========== Extract plot generation function ==========
    generate_correlation_heatmap <- function(selected_data, params) {
      # Color scale range
      symmetric_limits <- TRUE
      midpoint <- 0
      cor_method <- "spearman"
      title <- "RNA–ADT Marker Correlation by Cluster"

      # Get facet_ncol from params, use default if not available
      facet_ncol <- if (!is.null(params) && !is.null(params$facet_ncol)) {
        params$facet_ncol
      } else {
        2  # Default value
      }

      palette_low <- "blue"
      palette_mid <- "white"
      palette_high <- "red"
      label_digits <- 2

      cor_vals <- selected_data$cor
      if (all(is.na(cor_vals))) {
        warning("All correlation coefficients are NA, possibly due to missing data or zero variance.")
        cor_min <- -1
        cor_max <- 1
      } else {
        cor_min <- min(cor_vals, na.rm = TRUE)
        cor_max <- max(cor_vals, na.rm = TRUE)
        if (symmetric_limits) {
          lim <- max(abs(c(cor_min, cor_max)))
          cor_min <- -lim
          cor_max <-  lim
        }
      }

      # Ensure required columns exist
      if (!"cluster" %in% colnames(selected_data)) {
        stop("The 'cluster' column is missing in the data.")
      }
      selected_data$cluster <- as.character(selected_data$cluster)

      if (!all(c("rna", "adt", "cor") %in% colnames(selected_data))) {
        stop("The data must contain 'rna', 'adt', and 'cor' columns.")
      }

      # Get unique cluster count for intelligent layout suggestion
      n_clusters <- length(unique(selected_data$cluster))

      # Auto-adjust if user-selected column count exceeds actual cluster count
      if (facet_ncol > n_clusters) {
        facet_ncol <- n_clusters
      }

      # Generate heatmap
      p <- ggplot(selected_data, aes(x = rna, y = adt, fill = cor)) +
        geom_tile(color = "black", linewidth = 0.3, na.rm = FALSE) +
        scale_fill_gradient2(
          low = palette_low, mid = palette_mid, high = palette_high,
          midpoint = midpoint, limits = c(cor_min, cor_max),
          name = paste0(cor_method, " corr")
        ) +
        coord_fixed() +
        geom_text(aes(label = ifelse(is.na(cor), "NA", round(cor, label_digits))),
                  size = 3) +
        facet_wrap(~ cluster, ncol = facet_ncol) +
        theme_minimal(base_size = 12) +
        theme(
          axis.text.x = element_text(angle = 45, hjust = 1),
          panel.grid = element_blank(),
          strip.text = element_text(face = "bold"),
          panel.border = element_rect(color = "grey70", fill = NA, linewidth = 0.7)
        ) +
        labs(
          x = "RNA",
          y = "ADT",
          title = title,
          subtitle = paste("Facet layout:", facet_ncol, "columns,",
                          ceiling(n_clusters / facet_ncol), "rows")
        )

      # Apply plot controls parameters
      if (!is.null(params) && length(params) > 0) {
        # Ensure all parameters exist, provide default values
        axis_text_size <- params$axis_text_size %||% 12
        axis_title_size <- params$axis_title_size %||% 14
        legend_text_size <- params$legend_text_size %||% 12
        legend_title_size <- params$legend_title_size %||% 12
        title_size <- params$title_size %||% 16
        legend_position <- params$legend_position %||% "right"

        p <- p + theme(
          text = element_text(size = axis_text_size),
          axis.text = element_text(size = axis_text_size),
          axis.title = element_text(size = axis_title_size),
          legend.text = element_text(size = legend_text_size),
          legend.title = element_text(size = legend_title_size),
          strip.text = element_text(size = axis_text_size, face = "bold"),
          plot.title = element_text(size = title_size),
          plot.subtitle = element_text(size = axis_text_size - 1, color = "gray60"),
          legend.position = legend_position
        )
      }

      return(p)
    }

    # ========== Listen to parameter changes and redraw plot ==========
    observeEvent(plot_params(), {
      # Only redraw if plot has already been generated
      if (!is.null(computed_plot()) && !is.null(current_cell_type())) {
        loading_state(TRUE)

        shinyjs::delay(50, {
          tryCatch({
            selected_data <- data_list[[current_cell_type()]]

            if (!is.null(selected_data)) {
              # Regenerate plot
              plot_result <- generate_correlation_heatmap(selected_data, plot_params())
              computed_plot(plot_result)

              # Update layout suggestion
              update_layout_suggestion()
            }

            loading_state(FALSE)

          }, error = function(e) {
            loading_state(FALSE)
            message("Plot update error: ", e$message)
          })
        })
      }
    }, ignoreInit = TRUE)

    # ========== Listen to window size changes ==========
    observeEvent(input$window_size, {
      # Only update layout suggestion if plot has already been generated
      if (!is.null(computed_plot()) && !is.null(current_cell_type())) {
        update_layout_suggestion()
      }
    }, ignoreInit = TRUE)

    # ========== Modify dynamic content display to ensure spinner works ==========
    output$plot_content <- renderUI({
      # Get window size
      window_width <- input$window_size$width %||% 1200
      window_height <- input$window_size$height %||% 800

      # Calculate available width (considering left panel and margins)
      available_width <- window_width * 0.65 - 50  # Right column occupies 65%, minus margins

      # Dynamically calculate height
      plot_height <- calculate_plot_height(available_width)

      if (input$plot_btn == 0) {
        # Initial state: show prompt
        return(
          div(
            style = paste0("height: 400px; display: flex; align-items: center; justify-content: center;"),
            div(
              style = "text-align: center; color: #6c757d;",
              icon("chart-area", style = "font-size: 48px; margin-bottom: 20px;"),
              h4("Select cell type and click 'Generate Plots'"),
              p("Choose a cell type from the dropdown and click the generate button to view the RNA-ADT correlation heatmap.")
            )
          )
        )
      }

      if (loading_state()) {
        # Loading state: show loader
        return(
          div(
            style = paste0("height: ", plot_height, "px; display: flex; align-items: center; justify-content: center;"),
            div(
              style = "text-align: center;",
              div(
                class = "spinner-border text-primary",
                role = "status",
                style = "width: 3rem; height: 3rem;"
              ),
              h4("Generating correlation heatmap...", style = "margin-top: 20px; color: #6c757d;")
            )
          )
        )
      }

      # Display plot - use shinycssloaders spinner
      shinycssloaders::withSpinner(
        plotOutput(ns("rna_adt_corr_heatmap"), height = paste0(plot_height, "px")),
        type = 6,
        color = "#0d6efd",
        size = 1
      )
    })

    # ========== Modify plot rendering function to ensure spinner works properly ==========
    output$rna_adt_corr_heatmap <- renderPlot({
      # Only render when there's a computed result
      plot_result <- computed_plot()
      req(plot_result)

      # Small delay to ensure spinner is displayed
      Sys.sleep(0.1)

      return(plot_result)
    })
  })
}
