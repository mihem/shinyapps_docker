# ============================================================================
# PBMC ADT Analysis Modules
# ============================================================================

# Source plot controls
source("modules/plot_controls.R")

# =============== Feature Density Plot UI ===============
pbmc_correction_check_UI <- function(id) {
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
          title = "Select Feature",
          status = "primary",
          solidHeader = TRUE,
          width = NULL,
          selectInput(ns("adt_nor_method_select"), "Normalization Method:",
                      choices = list("DSB" = list(`DSB Global` = "ADT_global", `DSB Per Isotype` = "ADT_isotype"),
                                      "CLR" = list("CLR" = "ADT_CLS")),
                      selected = "ADT_global"),

          selectInput(ns("adt_nor_figure_select"), "Normalization Effect:",
                      choices =list(
                          `Single Distribution` = "adt_single_distribution",
                          `Dot Plot`            = "adt_dot_plot",
                          `Pearson Correlation` = "adt_pearson_correlation",
                          `Mean Expression`     = "adt_mean_expression",
                          `Detection Rate`      = "adt_detection_rate"),
                      selected = "adt_pearson_correlation"),
          selectInput(ns("adt_nor_grouping_select"), "Grouping:",
            choices = list(Timepoint = "timepoint", Sample = "sample", `Treatment Hour` = "treatment_hour"),
            selected = "timepoint"),
          conditionalPanel(
            condition = sprintf("input['%s'] == 'adt_single_distribution' || input['%s'] == 'adt_dot_plot'",
                    ns("adt_nor_figure_select"), ns("adt_nor_figure_select")),
            selectizeInput(
              ns("feature_select"),
              "Feature:",
              choices = NULL,
              multiple = TRUE,
              options = list(plugins = list("remove_button"), placeholder = "Select ADT(s)")
            )
          ),
          conditionalPanel(
            condition = sprintf("input['%s'] == 'adt_single_distribution' || input['%s'] == 'adt_dot_plot'",
                    ns("adt_nor_figure_select"), ns("adt_nor_figure_select")),
            # verbatimTextOutput(ns("selected_features_text"), placeholder = TRUE),
            actionButton(ns("feature_plot"), "Plot")
          )
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

# =============== Feature Density Plot Server ===============
pbmc_correction_check_Server <- function(id, adt_features_list, adt_correction_stats_plots) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Initialize plot controls
    plot_params <- plot_controls_Server("plot_controls")

    # 监听 box 的大小
    window_size <- reactive({
      req(input$window_size)
      input$window_size
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

    observe({
      updateSelectizeInput(session, "feature_select", choices = rownames(adt_features_list[[1]]$data))
    })
    output$selected_features_text <- renderPrint({
      input$feature_select   # 这是一个字符向量
    })


    # ================= 动态标题映射 =================
    label_map_en <- c(
      adt_single_distribution = "Single Distribution",
      adt_dot_plot           = "Ridge Plot",
      adt_pearson_correlation = "Pearson Correlation",
      adt_mean_expression     = "Mean Expression",
      adt_detection_rate      = "Detection Rate"
    )
    label_map_cn <- c(
      adt_single_distribution = "单特征分布",
      adt_dot_plot            = "均值点图",
      adt_pearson_correlation = "皮尔逊相关",
      adt_mean_expression     = "均值表达",
      adt_detection_rate      = "检出率"
    )

    current_effect_label <- reactive({
      code <- input$adt_nor_figure_select
      lang_val <- lang()
      if (!is.null(lang_val) && length(lang_val) > 0 && lang_val == "cn") {
        lbl <- label_map_cn[code]
      } else {
        lbl <- label_map_en[code]
      }
      if (is.na(lbl)) code else lbl
    })

    # ========== 左侧说明 box 动态生成 ==========
    output$explanatory_box <- renderUI({
      lang_val <- lang()
      box(
        title = current_effect_label(),
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

    # ========== 右侧图形 box 动态生成 ==========
    output$plot_box <- renderUI({
      lang_val <- lang()

      # 安全检查输入值
      figure_select <- input$adt_nor_figure_select
      if (is.null(figure_select) || length(figure_select) == 0) {
        figure_select <- "adt_single_distribution"  # 默认值
      }

      title_suffix <- if (figure_select == "adt_single_distribution") {
        if (!is.null(lang_val) && length(lang_val) > 0 && lang_val=="cn") "密度图" else "Density Plot"
      } else {
        if (!is.null(lang_val) && length(lang_val) > 0 && lang_val=="cn") "效果图" else "Plot"
      }

      if (figure_select == "adt_pearson_correlation") {
        plot_height <- 1800
      } else {
        plot_height <- input$window_size$height - 150
      }
      box(
        title = paste0(current_effect_label(), " - ", title_suffix),
        status = "primary",
        solidHeader = TRUE,
        width = NULL,
        shinycssloaders::withSpinner(plotOutput(ns("density_plot"),  height = paste0(plot_height, "px")), type = 6, color = "#0d6efd")  # ✅ 用 ns()
      )
    })

    # 根据选择返回需要展示的 ggplot：
    # 1) adt_nor_figure_select == adt_single_distribution -> 动态密度图
    # 2) 其它 -> 直接从预计算对象 adt_correction_stats_plots 中取出
    a_ggplot <- reactive({
      req(input$adt_nor_method_select, input$adt_nor_figure_select)

      print("Selected normalization method:")
      print(input$adt_nor_method_select)
      print("Selected normalization effect:")
      print(input$adt_nor_figure_select)

      # 情况 1：单分布密度（需要特征选择）
      if (input$adt_nor_figure_select == "adt_single_distribution") {
        req(input$feature_select)  # 只有这个模式才要求 feature_select
        adt_features_df <- adt_features_list[[ input$adt_nor_method_select ]]
        validate(need(!is.null(adt_features_df), "所选归一化方法的数据不存在"))
        adts <- input$feature_select
        validate(need(adts %in% rownames(adt_features_df$data), "所选 Feature 不在数据中"))

        grouping <- input$adt_nor_grouping_select
        validate(need(grouping %in% names(adt_features_df), glue::glue("所选 {grouping} 分组不在数据 {names(adt_features_df)} 中")))

        val    <- adt_features_df$data[adts, , drop = FALSE] # 即使一个adt, 禁止降维
        sample <- adt_features_df[[grouping]]
        df <- cbind(data.frame(t(val)), sample = sample)

        df_long <- df |>
          # 如果有行名是细胞 ID，保留一下
          tibble::rownames_to_column(var = "cell") |>
          pivot_longer(
            cols = !c(cell, sample),     # 除 cell 和 sample 以外的都是特征
            names_to = "feature",
            values_to = "value"
          )

        p <- ggplot(df_long, aes(x = value, colour = sample)) +
          geom_density(adjust = 1) +
          facet_wrap(~ feature, scales = "free_x") +
          theme_bw() +
          theme(strip.text = element_text(size = 10)) +
          labs(x = "Expression (normalized)", y = "Density", colour = "Group")

        # 应用 plot controls 参数
        if (!is.null(plot_params()) && length(plot_params()) > 0) {
          p <- p + theme(
            text = element_text(size = plot_params()$axis_text_size),
            axis.text = element_text(size = plot_params()$axis_text_size),
            axis.title = element_text(size = plot_params()$axis_title_size),
            legend.text = element_text(size = plot_params()$legend_text_size),
            legend.title = element_text(size = plot_params()$legend_title_size),
            strip.text = element_text(size = plot_params()$axis_text_size),
            legend.position = plot_params()$legend_position
          )
        }

        return(p)
      } else if (input$adt_nor_figure_select == "adt_dot_plot") {
        req(input$feature_select)
        adt_features <- adt_features_list[[ input$adt_nor_method_select ]]
        validate(need(!is.null(adt_features), "所选归一化方法的数据不存在"))
        adts <- input$feature_select
        validate(need(adts %in% rownames(adt_features$data), "所选 Feature 不在数据中"))

        grouping <- input$adt_nor_grouping_select
        validate(need(grouping %in% names(adt_features), glue::glue("所选 {grouping} 分组不在数据 {names(adt_features)} 中")))

        # 1. 取表达矩阵
        expr_mat <- adt_features$data[adts, , drop = FALSE] # 即使一个adt, 禁止降维
        # 2. 取分组（cluster）
        clusters <- adt_features[[input$adt_nor_grouping_select]]
        # 3. 整理为长表
        expr_df <- as.data.frame(t(expr_mat))              # 现在行是细胞，列是 feature
        expr_df$cell <- rownames(expr_df)
        expr_df$cluster <- clusters

        long_df <- expr_df |>
          pivot_longer(
            cols = all_of(adts),
            names_to = "feature",
            values_to = "value"
          )

        # 4. 计算每个 (cluster, feature) 的百分比表达与平均表达
        stats_df <- long_df |>
          group_by(cluster, feature) |>
          summarise(
            pct.exp = mean(value > 0) * 100,   # 百分比
            avg.exp = mean(value),             # 含 0 的平均表达（与 Seurat DotPlot 一致）
            .groups = "drop"
          )
        # 5. 按 feature 做 Z-score（颜色用）
        stats_df <- stats_df |>
          group_by(feature) |>
          mutate(
            avg.exp.scaled = as.numeric(scale(avg.exp))
          ) |>
          ungroup()

        # 6. 因子顺序（保持与输入的 adts 顺序；cluster 按出现顺序或自定义）
        stats_df$feature <- factor(stats_df$feature, levels = adts)
        stats_df$cluster <- factor(stats_df$cluster, levels = unique(clusters))
        # 7. 画图
        # 计算当前数据实际范围
        pct_min  <- min(stats_df$pct.exp, na.rm = TRUE)
        pct_max  <- max(stats_df$pct.exp, na.rm = TRUE)

        col_min  <- min(stats_df$avg.exp.scaled, na.rm = TRUE)
        col_max  <- max(stats_df$avg.exp.scaled, na.rm = TRUE)
        # 可选：如果想让 0（Z-score 的中心）处于颜色梯度中点，构造 values
        # 确保 col_min < 0 < col_max（常见），否则自动按两端
        library(scales)
        col_values <- if (col_min < 0 && col_max > 0) {
          rescale(c(col_min, 0, col_max), from = c(col_min, col_max))
        } else {
          c(0, 1)  # 退化情况
        }

        p <- ggplot(stats_df, aes(x = feature, y = cluster)) +
          geom_point(aes(size = pct.exp, color = avg.exp.scaled)) +
          scale_size(
            range  = c(0.5, 10),                    # 你可以调整最小/最大点的像素
            limits = c(pct_min, pct_max),        # 限定为当前数据最小和最大
            breaks = pretty(c(pct_min, pct_max), n = 4)  # 让图例更贴近实际
          ) +
          scale_color_gradientn(
            colours = c("#f3d3e7", "#f47983"),
            limits  = c(col_min, col_max),       # 用实际最小/最大
            # values  = col_values,                # 保证 0 居中（如果存在）
            name    = "Scaled\nAvg Exp",
            oob     = scales::squish                     # 超出范围的（理论上不会）压缩
          ) +
          guides(
            size = guide_legend(
              title = "% Exp",
              override.aes = list(color = "grey50")
            )
          ) +
          labs(
            x = NULL, y = NULL,
            title = "ADT DotPlot (ggplot 复刻)",
            # subtitle = paste0("Assay = ", input$adt_nor_assay_select, "\n Group = ", input$adt_nor_grouping_select)
          ) +
          theme_bw(base_size = 12) +
          theme(
            panel.grid.major = element_line(color = "grey90"),
            panel.grid.minor = element_blank(),
            axis.text.x = element_text(angle = 45, hjust = 1),
            plot.title  = element_text(face = "bold")
          )

        # 应用 plot controls 参数
        if (!is.null(plot_params()) && length(plot_params()) > 0) {
          p <- p + theme(
            text = element_text(size = plot_params()$axis_text_size),
            axis.text = element_text(size = plot_params()$axis_text_size),
            axis.title = element_text(size = plot_params()$axis_title_size),
            legend.text = element_text(size = plot_params()$legend_text_size),
            legend.title = element_text(size = plot_params()$legend_title_size),
            plot.title = element_text(size = plot_params()$title_size, face = "bold"),
            legend.position = plot_params()$legend_position
          )
        }

        return(p)
      }

      # 情况 2：其它统计/效果展示 —— 从预计算列表取
      figs_group <- adt_correction_stats_plots[[ input$adt_nor_method_select ]][[ input$adt_nor_figure_select ]]
      validate(need(!is.null(figs_group), "该效果指标尚无预生成图"))

      # 若直接是 ggplot 对象
      if (inherits(figs_group, "gg")) {
        return(figs_group)
      }
    })

    # Explanatory content (bilingual)
    output$explanatory_content <- renderUI({
      lang_val <- lang()

      # 安全检查输入值
      figure_select <- input$adt_nor_figure_select
      if (is.null(figure_select) || length(figure_select) == 0) {
        figure_select <- "adt_single_distribution"  # 默认值
      }

      if (!is.null(lang_val) && length(lang_val) > 0 && lang_val == "cn") {
        if (figure_select == "adt_single_distribution") {
          div(
            tags$h4("一、什么时候会看到明显双峰"),
            tags$p("典型的“谱系/分化”或“互斥表达”标记更容易双峰："),
            tags$ul(
              tags$li("CD3（T 细胞 vs 非 T）"),
              tags$li("CD19 或 CD20（B vs 非 B）"),
              tags$li("CD14 / LST1（经典单核 vs 非单核）"),
              tags$li("CD56（NK vs 非 NK）"),
              tags$li("CD16（某些髓系/ NK 亚群）"),
              tags$li("CD4 / CD8（在包含足够 T 细胞，并且 panel 质量好时，常见分离）")
            ),
            tags$p("这些 marker 在总体细胞混合（PBMC 等）时，阴性群体多为“真正缺失表达”的细胞，阳性群体表达显著高，背景被 DSB 拉到一个更紧的低值附近，于是出现清晰“双峰”或至少“低峰 + 高肩”。"),

            tags$h4("二、什么时候不会出现双峰（单峰或连续分布完全正常）"),
            tags$ul(
              tags$li("连续生物梯度类：HLA-DR、CD38、CD69、PD-1、CD25 等激活或状态标记，往往是一个右偏分布或宽单峰。"),
              tags$li("几乎所有细胞都表达的泛分子：CD45、β2M、CD44（很多组织），可能是单峰，只有轻微尾部。"),
              tags$li("表达水平普遍很低：信噪差 → 可能接近单峰或“背景峰 + 模糊尾部”难区分。"),
              tags$li("你的样本组成单一（例如只富集了 T 细胞）：CD3 会接近全阳性单峰；CD19 可能全阴性单峰。"),
              tags$li("细胞数不足：阳性群只有几十个细胞，密度曲线会只表现为肩或小凸起。"),
              tags$li("抗体验证不佳 / 非特异性高：会让阴性群膨胀，削弱双峰。")
            ),

              tags$h4("三、判断 DSB 是否“成功”的更客观指标（不要只盯是否双峰）"),
            tags$ul(
              tags$li("Isotype 控制的分布：应大致居中（均值接近 0）且方差较小、近似单峰正态。"),
              tags$li("明显阴性/阳性标记（如 CD19 在 PBMC）阴性群更集中，阳性群与阴性群均值差更大（可量化 Cohen’s d 或 AUC）。"),
              tags$li("不同样本之间同一 isotype 的均值/方差更接近（批次偏移减小）。"),
              tags$li("阳性 marker 与对应 RNA（若存在可比基因，例如 CD3D, MS4A1, LST1）的相关性（Spearman）略有提升或保持稳定。"),
              tags$li("使用矫正后的 ADT 做 PCA / UMAP（或 WNN）时，经典群体分离更清晰。")
            )
          )
        } else if (figure_select == "adt_dot_plot") {
          div(
            tags$h4("四、ADT DotPlot（聚合表达概览）怎么读"),
            tags$p("这个图复刻了 Seurat::DotPlot(assay = adt_assay, group.by = cluster_col) 的核心含义：每个点对应 (Cluster × Marker) 的聚合统计，帮助快速扫视哪些群体表达哪些抗体标记，以及表达比例与强度差异。"),

            tags$h4("1. 点大小（size = pct.exp）"),
            tags$ul(
              tags$li("表示该 cluster 内，表达值 > 0 的细胞百分比（%Expressed）。"),
              tags$li("越大说明越多细胞为“检测到”状态；不是强度，而是“至少有信号”的细胞占比。"),
              tags$li("在非常低表达/高噪声 marker 上，点可能很小（或根本接近 0），即大多数细胞都在背景附近。"),
              tags$li("不同 cluster 的细胞数差别大会影响对小点的可靠性：绝对细胞数太少（例如 <50）时，5% 与 15% 的统计抖动可能很大。"),
              tags$li("若你后续做了截尾 (winsorize) 或过滤零值策略，请在说明里同步更新含义。")
            ),

            tags$h4("2. 点颜色（color = avg.exp.scaled 或 avg.exp）"),
            tags$ul(
              tags$li("当前版本使用灰色 → 暗红色连续梯度：越红表示平均表达强度越高。"),
              tags$li("如果用的是 avg.exp.scaled：对每个 marker 跨所有 cluster 做 Z-score（均值 0，标准差 1），突出“相对高低”而非绝对量级。"),
              tags$li("Z-score 下：0 附近（浅灰）= 该 marker 在该 cluster 属于中等水平；正值越大越红；负值（如果存在）会趋向更浅灰。"),
              tags$li("如果改成 avg.exp（未标准化）：颜色体现绝对平均表达，但不同 marker 之间因本底/亲和力差异，动态范围不可直接比较。"),
              tags$li("高 pct.exp + 高颜色：典型“广泛且强”表达；低 pct.exp + 高颜色：少量细胞强表达（可能是稀有亚群）；高 pct.exp + 低颜色：普遍低度表达或背景抬高。")
            ),

            tags$h4("3. 与原始分布 / 双峰的关系"),
            tags$ul(
              tags$li("DotPlot 是聚合视图，不展示单细胞分布形态；是否双峰需要配合密度图 / Ridge / Histogram / Violin 检查。"),
              tags$li("一个 marker 在 DotPlot 上显示为中等大小 + 中等颜色，可能来自：(a) 所有细胞低水平表达；或 (b) 一半阴性、一半阳性且阳性强度高——两者需要看原始分布区分。"),
              tags$li("因此 DotPlot 用于“横向扫描”候选差异，再回到分布图做精细判读。")
            ),

            tags$h4("4. 读图策略与典型解读"),
            tags$ul(
              tags$li("优先寻找：某列（marker）在少数 cluster 显著更红且点也较大 → 高特异群体标记。"),
              tags$li("同一免疫谱系的多个 marker 在同一 cluster 同时“红且大” → 该 cluster 的注释可信度提升（协同证据）。"),
              tags$li("点普遍偏小但某些 cluster 仍有较高颜色 → 可能存在少量强表达细胞，考虑是否是稀有亚群或双tsne聚合误差。"),
              tags$li("几乎所有 cluster 都大且偏红 → 泛表达标记（例如 CD45），区分度有限，可在面板展示中下调其权重。"),
              tags$li("Isotype 或阴性对照若出现明显大红点 → 需要回溯背景矫正或抗体特异性。")
            ),

            tags$h4("5. 排序与可视化细节（可在代码中微调）"),
            tags$ul(
              tags$li("feature 顺序：当前按输入 panel_core，若要按某一特征（如总平均表达）排序，可在构造 stats_df 后重排因子。"),
              tags$li("cluster 顺序：可以按层次聚类（对 avg.exp.scaled 做距离）或手动生物学顺序，提高可读性。"),
              tags$li("点大小范围(range = c(1,8)) 可根据屏幕密度调整，避免过饱和或过稀疏。"),
              tags$li("若存在极端高表达导致其它颜色被压缩，可对 avg.exp 做分位数截尾后再 scale。"),
              tags$li("当加入新样本或做子集分析时，应重新计算 pct.exp 与 scaling，避免旧 limits 误导。")
            ),

            tags$h4("6. 常见误读与注意事项"),
            tags$ul(
              tags$li("“颜色浅 = 不表达”不一定：可能只是低于该 marker 的全局均值（Z-score 负），但仍高于背景。"),
              tags$li("“点小 = 不可靠”不等于“无生物学意义”：稀有细胞群真实存在时也会出现，但需结合绝对细胞数与 QC。"),
              tags$li("跨 marker 直接比较颜色强度（在使用 scaled 值时）只代表“各自在本 marker 的排名”，不能断言 A 比 B 绝对表达更高。"),
              tags$li("如果背景矫正后仍有 isotype 形成明显结构，优先排查批次/去噪流程，而不是直接解读为真实信号。")
            ),

            tags$h4("7. 可扩展思路"),
            tags$ul(
              tags$li("增加 split.by（如样本、批次）分面对比批次一致性。"),
              tags$li("添加 tooltip（plotly::ggplotly）查看数值：pct.exp、平均表达、细胞数。"),
              tags$li("计算并显示每个 (marker, cluster) 的 AUC 或 logFC，辅助判断是否纳入注释报告。"),
              tags$li("与 RNA 同名基因做并列 DotPlot（ADT vs RNA）评估蛋白 vs 转录本一致性。")
            ),
            tags$h4("8. 总结"),
            tags$p(
              "DotPlot 提供“群体 × 标记”的快速热力概览：点大小 = 参与度（占比），点颜色 = 强度（相对或绝对）。它不替代单细胞分布图，"
            ),
            tags$p(
              "应与密度/双峰判读、isotype 控制、相关性分析联合使用，形成对 ADT 信号质量及生物学注释的多维证据链。"
            )
          )
        } else if (figure_select == "adt_pearson_correlation") {
          div(
            tags$h4("图形结构"),
            tags$p("每根横向柱子 = 1 个抗体 (ADT feature)。x 轴为 Pearson 相关系数（矫正前 vs 矫正后表达向量），按相关系数从高到低自上而下排序。"),

            tags$h4("它在量化什么"),
            tags$p("衡量矫正后是否保留每个抗体在细胞间的相对表达模式：相关高 = 仅做尺度/线性微调；相关中等 = 分布被一定幅度重塑（常见：背景被压、低表达群更集中）；相关很低 = 该特征被大幅改变，需要核查。"),

            tags$h4("相关系数区间快速解读"),
            tags$ul(
              tags$li("≥ 0.85：整体排序几乎未变，矫正很温和。"),
              tags$li("0.5–0.85：模式有改动，需结合是否提升信噪。"),
              tags$li("0.3–0.5：显著重塑，关注这些特征的生物学合理性。"),
              tags$li("< 0.3 或 NA：可能高背景/低质量 / 过度矫正 / 极低表达。")
            ),

            tags$h4("优先关注点"),
            tags$ul(
              tags$li("列表底部相关性最低的一小撮：是否为已知问题抗体、同型对照、或高背景标签。"),
              tags$li("关键 lineage / 功能 marker（CD3, CD4, CD8, CD19, CD14, CD56, HLA-DR 等）不应集体跌入低相关。"),
              tags$li("整体分布：是否出现“几乎都很高”或“整体被压低”两种极端。"),
              tags$li("相关显著下降的特征是否同时伴随更清晰的阴 / 阳性分离（避免把真实信号一并抹平）。")
            ),

            tags$h4("解读整体形态"),
            tags$ul(
              tags$li("大多数 > 0.85：矫正保守，需再看 isotype、密度图确认是否真正去背景。"),
              tags$li("大量集中 0.4–0.6 且信噪未提升：可能“信号 + 背景”一起被扰动。"),
              tags$li("重要 marker 也 < 0.5：疑似过度矫正或抗体质量 / 批次问题。"),
              tags$li("少数低质量 / 高背景抗体落入中低相关，其余高：典型“理想”模式。")
            ),

            tags$h4("出现异常时可快速核查"),
            tags$ul(
              tags$li("查看该抗体的原始 vs 矫正密度曲线：是否仅背景收紧而阳性峰保留。"),
              tags$li("检查同型对照分布是否居中且方差缩小。"),
              tags$li("对比对应 RNA（若有，可算 Spearman）是否无异常下降。"),
              tags$li("在降维 / 群体标注中，经典群体是否仍清晰。")
            ),

            tags$p(style = "color:#555;font-size:12px;",
                  "提示：单独的低相关并非一定“坏”，需结合原始分布、同型对照与生物学知识综合判断。")
          )
        } else if (figure_select == "adt_mean_expression") {
          div(
            tags$h4("图形结构"),
            tags$p(
              "每个点 = 1 个抗体 (ADT feature)。x 轴：矫正前（已应用 pre_transform，如 log1p）跨细胞均值；",
              "y 轴：矫正后跨细胞均值；颜色 = |均值差|，值越大颜色越亮；虚线 y = x 表示均值未变；标注文字 = 绝对均值变化最大的前 n_top_labels 个抗体。"
              ),

              tags$h4("它在量化什么"),
              tags$ul(
                tags$li("是否存在整体（系统性）均值下调或上调趋势。"),
                tags$li("哪些特征均值被大幅改变，需人工核查（高背景 / 低质量 / 过度矫正风险）。")
              ),

              tags$h4("你应该关注"),
              tags$ul(
                tags$li("被标注的最大变化点：是否为预期高背景（IgG / 非特异标签）而非关键生物 marker。"),
                tags$li("高表达、核心 lineage / 功能 marker（CD3, CD19, CD14, HLA-DR 等）是否被压到接近噪音。"),
                tags$li("低表达区（左下）被下调：可能是背景清除，通常合理。"),
                tags$li("整体点云是否仍沿近似线性关系，而非明显弯曲或分段。")
              ),

              tags$h4("典型模式"),
              tags$ul(
                tags$li("“好”模式：点整体略落在对角线下方（去掉正偏背景），主要生物 marker 相对次序保持；最大变化多为已知背景 / 冗余抗体。"),
                tags$li("“潜在问题”：高表达 marker 被整体压缩到狭窄带；或曲线弯折（丰度段被不均衡扭曲）；或大量真实 marker 被标注。")
              ),

              tags$h4("进一步利用"),
              tags$ul(
                tags$li("计算削减比例 r = (raw_mean - corrected_mean) / raw_mean 的分布：评估全局削减强度。"),
                tags$li("与 ambient_profile（若已构建）比较：最大下调集合是否富集于 ambient 高丰度分子（若是 → 支持矫正有效）。"),
                tags$li("对比 isotype 均值：应整体更接近 0 且变化幅度合理。")
              ),

              tags$h4("可加的快速量化指标"),
              tags$ul(
                tags$li("全体 r 中位数（全局削减率）。"),
                tags$li("被标注特征中，属于已知高背景的比例。"),
                tags$li("关键 marker（预定义白名单）平均 r 与全体 r 的差值（避免“核心信息”过度削弱）。"),
                tags$li("拟合 y ~ x 线性模型的 R²（非线性扭曲时下降）。")
              ),

              tags$h4("出现异常时核查"),
              tags$ul(
                tags$li("查看异常点原始 vs 矫正密度曲线：是真背景收缩还是信号坍塌。"),
                tags$li("核对该抗体批次 / 文库是否有已知问题。"),
                tags$li("与 RNA（可比基因）相关性是否异常下降。")
              ),

              tags$p(style="color:#555;font-size:12px;",
                    "提示：均值大幅下降并不自动代表错误，需结合：背景成分、密度形状、isotype、下游聚类分离度一起判断。")
            )
        } else if (figure_select == "adt_detection_rate") {
          div(
            tags$h4("图形结构"),
            tags$p(
              "每条灰色连线代表 1 个抗体 (ADT feature) 在矫正前后检测率（非零比例）的变化：",
              "左端点 = Before 非零比例，右端点 = After 非零比例。"
            ),
            tags$p(
              "红色大点：各侧（Before / After）所有特征检测率的中位数；",
              "y 轴：检测率 (非零比例)；x 轴：阶段 (Before / After)。"
            ),

            tags$h4("它在量化什么"),
            tags$ul(
              tags$li("背景去除是否有效：背景主导的低水平“假阳性”应在 After 变成 0 → 检测率下降。"),
              tags$li("是否过度：真正应在多数细胞稳定表达的 marker 检测率不应被大幅拉低。")
            ),

            tags$h4("你应该关注"),
            tags$ul(
              tags$li("整体中位数：应轻度下降或保持，过猛下跌需警惕。"),
              tags$li("下降幅度特别大的特征（可按 Δdetect 排序后列出 Top N）。"),
              tags$li("是否有一批特征检测率反而上升：可能由归一化 / 阈值细节导致，需要确认合理性。"),
              tags$li("高表达、生物学确定的 marker（CD45, CD3, CD19, CD14, HLA-DR 等）检测率是否保持。")
            ),

            tags$h4("典型模式"),
            tags$ul(
              tags$li("“好”模式：中位数轻微下降；主要下降来自原本低均值 / 高噪音特征；核心高表达 marker 几乎不变。"),
              tags$li("“潜在问题”：中位数大幅下降（例如 0.7 → 0.3）；多数特征同步下滑；核心 marker 也显著下降；或曲线呈普遍平行下移。")
            ),

            tags$h4("可衍生的定量指标"),
            tags$ul(
              tags$li("Δdetect = detect_after - detect_before（向量），查看其分布（密度 / 箱线）。"),
              tags$li("过度下降计数：#(Δdetect < -0.2 且 raw_mean > mean_threshold)。"),
              tags$li("中位 Δdetect（整体位移）。"),
              tags$li("高表达 marker（白名单）集合的平均 Δdetect 与全体平均 Δdetect 之差。"),
              tags$li("下降显著特征集合是否富集于已知高背景 / 低质量抗体列表（富集检验）。")
            ),

            tags$h4("出现异常时快速核查"),
            tags$ul(
              tags$li("抽查大幅下降的高表达 marker：查看其 Before / After 分布密度是否被整体压扁。"),
              tags$li("对比同型对照：是否更集中接近 0（合理）而不是一起被夸大。"),
              tags$li("检查下游聚类/UMAP：经典群体是否因广泛零化而混合。"),
              tags$li("核对参数：是否使用了过低的阈值或过强的全局缩放。")
            ),

            tags$p(style="color:#555;font-size:12px;",
                  "提示：适度下降（尤其集中在低信噪特征）通常是期望的；核心高表达 marker 的大幅检测率流失才是真正需要优先调查的信号。")
          )
        }
      } else {
        if (figure_select == "adt_single_distribution") {
          div(
            tags$h4("1. When do you typically see a clear bimodal distribution?"),
            tags$p("Canonical lineage / mutually exclusive markers are most likely to be bimodal:"),
            tags$ul(
              tags$li("CD3 (T cells vs non‑T)"),
              tags$li("CD19 or CD20 (B vs non‑B)"),
              tags$li("CD14 / LST1 (classical monocytes vs others)"),
              tags$li("CD56 (NK vs non‑NK)"),
              tags$li("CD16 (some myeloid / NK subsets)"),
              tags$li("CD4 / CD8 (often clean separation if enough T cells and good panel quality)")
            ),
            tags$p("In mixed populations (e.g. PBMC), the negative group truly lacks expression while the positive group is clearly elevated. DSB shrinks background toward a tight low-value mode, yielding a distinct 'double peak' or at least a 'low peak + high shoulder'."),

            tags$h4("2. When is bimodality NOT expected (a single or continuous distribution is perfectly normal)"),
            tags$ul(
              tags$li("Continuous biological gradients: HLA‑DR, CD38, CD69, PD‑1, CD25 and other activation/state markers often show a right‑skewed or broad single peak."),
              tags$li("Almost universally expressed molecules: CD45, β2M, CD44 (many tissues) may be unimodal with only a slight tail."),
              tags$li("Generally low expression levels: low SNR → may look like a single peak or 'background peak + vague tail'."),
              tags$li("Purified / compositionally narrow samples (e.g. T cell–enriched): CD3 ≈ all positive (single peak); CD19 ≈ all negative (single peak)."),
              tags$li("Too few cells in the positive subset: only a shoulder or small bump appears in the density curve."),
              tags$li("Poor antibody validation / high non‑specific binding: inflates the negative population and erodes bimodality.")
            ),

            tags$h4("3. More objective indicators of DSB 'success' (do not rely only on bimodality)"),
            tags$ul(
              tags$li("Isotype control distributions: roughly centered (mean ~0) with small variance and near‑normal unimodal shape."),
              tags$li("Clear negative/positive markers (e.g. CD19 in PBMC): negatives become tighter; mean difference between neg/pos increases (quantify via Cohen's d or AUC)."),
              tags$li("Across samples the same isotype shows more similar mean/variance (reduced batch shift)."),
              tags$li("Correlation (Spearman) between positive markers and corresponding RNA (e.g. CD3D, MS4A1, LST1) is mildly improved or at least maintained."),
              tags$li("Using corrected ADT in PCA / UMAP (or WNN) yields sharper separation of canonical cell populations.")
            )
          )
        } else if (figure_select == "adt_dot_plot") {
          div(
            tags$h4("IV. ADT DotPlot (Aggregated Expression Overview) – How to Read"),
            tags$p("This plot reproduces the core meaning of Seurat::DotPlot(assay = adt_assay, group.by = cluster_col): each dot is an aggregated (Cluster × Marker) statistic, letting you quickly scan which cell groups express which antibody markers, and how broadly (percentage) and how strongly (average intensity)."),

            tags$h4("1. Dot Size (size = pct.exp)"),
            tags$ul(
              tags$li("Represents the percentage of cells in that cluster with expression value > 0 (%Expressed)."),
              tags$li("Larger = more cells are 'detectably' expressing the marker; NOT intensity, just participation."),
              tags$li("Very small dots (near zero) indicate that most cells sit at background for that marker."),
              tags$li("Beware small absolute cell counts: if a cluster has few cells (e.g. <50), differences like 5% vs 15% may be noisy."),
              tags$li("If you later change the definition of 'expressed' (e.g. thresholding, denoising, winsorizing), update the caption accordingly.")
            ),

            tags$h4("2. Dot Color (color = avg.exp.scaled or avg.exp)"),
            tags$ul(
              tags$li("Current version uses a grey → dark red continuous gradient: deeper red = higher mean expression."),
              tags$li("If using avg.exp.scaled: per marker Z-score across clusters (mean 0, sd 1) emphasizes relative high/low patterns."),
              tags$li("Under Z-score: near 0 (light grey) = typical level for that marker; increasingly red = above-average; negative values (if present) trend lighter."),
              tags$li("If switching to raw avg.exp (unscaled): color reflects absolute averages, but dynamic ranges differ between markers (cannot compare intensities across markers directly)."),
              tags$li("Interpretation combos: high pct.exp + high color = broad & strong; low pct.exp + high color = few but strongly expressing cells (potential rare subset); high pct.exp + low color = widespread low-level/background expression.")
            ),

            tags$h4("3. Relation to Underlying Distributions / Bimodality"),
            tags$ul(
              tags$li("DotPlot is an aggregated view; it does not show single-cell shape (bimodal vs unimodal). Use density/ridge/histogram/violin plots to confirm bimodality."),
              tags$li("A medium-sized, medium-colored dot could mean: (a) everyone is low-level expressing OR (b) half negative / half strongly positive. Only raw distributions can distinguish."),
              tags$li("Use DotPlot for broad screening; return to distribution plots for mechanistic interpretation (lineage exclusion, activation gradients, etc.).")
            ),

            tags$h4("4. Reading Strategy & Typical Patterns"),
            tags$ul(
              tags$li("Look for marker columns where only a few clusters are notably red and reasonably large → candidate lineage / subset markers."),
              tags$li("Multiple canonical markers of the same lineage all red & large in the same cluster → high confidence annotation (convergent evidence)."),
              tags$li("Small size but strong color → small fraction of high expressers (rare subset or potential technical artifact requiring validation)."),
              tags$li("Nearly all clusters large and reddish → ubiquitous marker (e.g., CD45); low discriminatory value."),
              tags$li("If an isotype or known negative control shows distinct large red dots → revisit background correction or antibody specificity.")
            ),

            tags$h4("5. Ordering & Visual Refinements (Adjustable in Code)"),
            tags$ul(
              tags$li("Feature order: currently the input panel_core; can reorder by overall mean, variance, or hierarchical clustering."),
              tags$li("Cluster order: reorder by hierarchical clustering on the avg.exp.scaled matrix or by biological lineage progression to improve readability."),
              tags$li("Point size range (e.g., range = c(1,8)) can be tuned to avoid saturation or overly tiny dots."),
              tags$li("If an extreme high-expression cluster compresses the color scale, consider quantile clipping then scaling."),
              tags$li("Whenever adding new samples or subsetting, recompute pct.exp and scaling—do not reuse stale limits.")
            ),

            tags$h4("6. Common Misinterpretations & Caveats"),
            tags$ul(
              tags$li("\"Light color = no expression\" is not necessarily true: it can be below that marker's mean (negative Z) yet still above technical background."),
              tags$li("\"Small dot = unimportant\" is not guaranteed: rare but biologically meaningful populations may appear small; check absolute counts."),
              tags$li("Comparing colors across different markers under scaled values ranks clusters within each marker, not marker-to-marker absolute strength."),
              tags$li("If background-corrected isotypes still form structured patterns, prioritize QC / batch review over biological interpretation.")
            ),

            tags$h4("7. Extension Ideas"),
            tags$ul(
              tags$li("Add split.by (sample, batch) panels to assess batch consistency."),
              tags$li("Add interactive tooltips (plotly::ggplotly) showing pct.exp, avg expression, and cell counts."),
              tags$li("Compute auxiliary metrics (AUC, logFC, Cohen's d) per (marker, cluster) to rank marker specificity."),
              tags$li("Create paired ADT vs RNA DotPlots for concordance assessment (e.g., CD3D, MS4A1, LST1).")
            ),

            tags$h4("8. Summary"),
            tags$p(
              "The DotPlot supplies a rapid 'cluster × marker' heatmap of participation (size) and intensity (color). It is not a replacement for single-cell distribution plots."
            ),
            tags$p(
              "Combine it with density/bimodality checks, isotype controls, cross-modality correlations, and dimensional reduction performance to build a multi-evidence assessment of ADT data quality and biological annotation."
            )
          )
        } else if (figure_select == "adt_pearson_correlation") {
          div(
            tags$h4("Figure structure"),
            tags$p("Each horizontal bar = 1 antibody (ADT feature). The x-axis is the Pearson correlation coefficient (pre-correction vs post-correction expression vectors), ordered from top to bottom by decreasing correlation."),

            tags$h4("What it quantifies"),
            tags$p("Assesses whether the relative expression pattern of each antibody across cells is preserved after correction: high correlation = only scale/linear fine-tuning; moderate correlation = distribution reshaped to some extent (common: background suppressed, low-expression group becomes more compact); very low correlation = feature heavily altered and needs inspection."),

            tags$h4("Quick interpretation of correlation intervals"),
            tags$ul(
              tags$li("≥ 0.85: Overall ranking hardly changed; correction is mild."),
              tags$li("0.5–0.85: Pattern altered; check whether signal-to-noise improved."),
              tags$li("0.3–0.5: Marked reshaping; examine biological plausibility of these features."),
              tags$li("< 0.3 or NA: Possibly high background / low quality / over-correction / extremely low expression.")
            ),

            tags$h4("Priority points to inspect"),
            tags$ul(
              tags$li("Small subset at the bottom with the lowest correlations: are they known problematic antibodies, isotype controls, or high-background tags."),
              tags$li("Key lineage / functional markers (CD3, CD4, CD8, CD19, CD14, CD56, HLA-DR, etc.) should not collectively fall into low correlation."),
              tags$li("Overall distribution: do you see one of two extremes—'almost all very high' or 'overall suppressed'."),
              tags$li("Do features with markedly decreased correlation also show clearer negative/positive separation (avoid flattening genuine signal).")
            ),

            tags$h4("Interpreting overall shape"),
            tags$ul(
              tags$li("Most > 0.85: Correction is conservative; further check isotypes and density plots to confirm true background removal."),
              tags$li("Many clustered at 0.4–0.6 with no S/N improvement: may indicate both 'signal + background' were disturbed together."),
              tags$li("Important markers also < 0.5: suspect over-correction or antibody quality / batch issues."),
              tags$li("A few low-quality / high-background antibodies in mid-low correlation, the rest high: typical 'ideal' pattern.")
            ),

            tags$h4("Quick checks when anomalies appear"),
            tags$ul(
              tags$li("Inspect raw vs corrected density curves for that antibody: is only the background tightened while the positive peak is preserved."),
              tags$li("Check whether isotype control distributions are centered with reduced variance."),
              tags$li("Compare corresponding RNA (if available, compute Spearman) to ensure no abnormal drop."),
              tags$li("In dimensionality reduction / cluster annotation, are classical populations still clear.")
            ),

            tags$p(style = "color:#555;font-size:12px;",
                  "Note: A single low correlation is not necessarily 'bad'; integrate raw distribution, isotype controls, and biological knowledge for judgment.")
          )
        } else if (figure_select == "adt_mean_expression") {
          div(
            tags$h4("Figure structure"),
            tags$p(
              "Each point = 1 antibody (ADT feature). x-axis: pre-correction (after pre_transform, e.g. log1p) mean across cells; ",
              "y-axis: post-correction mean across cells; color = |mean difference|, the larger the value the brighter the color; dashed line y = x indicates mean unchanged; text labels = top n_top_labels antibodies with the largest absolute mean change."
            ),

            tags$h4("What it quantifies"),
            tags$ul(
              tags$li("Whether there is an overall (systematic) downward or upward shift in means."),
              tags$li("Which features have means changed drastically and need manual inspection (high background / low quality / over-correction risk).")
            ),

            tags$h4("You should pay attention to"),
            tags$ul(
              tags$li("The labeled largest-change points: are they expected high background (IgG / non-specific tags) rather than key biological markers."),
              tags$li("Whether high-expression, core lineage / functional markers (CD3, CD19, CD14, HLA-DR, etc.) are suppressed close to noise."),
              tags$li("Downward shifts in the low-expression region (lower left): may be background removal, often reasonable."),
              tags$li("Whether the overall point cloud still follows an approximately linear relationship rather than obvious curvature or segmentation.")
            ),

            tags$h4("Typical patterns"),
            tags$ul(
              tags$li("\"Good\" pattern: points overall slightly fall below the diagonal (removing positively biased background), main biological markers preserve relative ordering; largest changes mostly known background / redundant antibodies."),
              tags$li("\"Potential issue\": high-expression markers are collectively compressed into a narrow band; or the curve bends (abundance ranges unequally distorted); or many true markers are labeled.")
            ),

            tags$h4("Further utilization"),
            tags$ul(
              tags$li("Compute reduction ratio r = (raw_mean - corrected_mean) / raw_mean distribution: assess global reduction strength."),
              tags$li("Compare with ambient_profile (if constructed): is the most down-regulated set enriched for ambient high-abundance molecules (if yes → supports effective correction)."),
              tags$li("Compare isotype means: they should overall be closer to 0 with a reasonable magnitude of change.")
            ),

            tags$h4("Optional quick quantitative metrics"),
            tags$ul(
              tags$li("Median of all r (global reduction rate)."),
              tags$li("Proportion of labeled features that are known high background."),
              tags$li("Difference between average r of key markers (predefined whitelist) and overall r (to avoid excessive weakening of \"core information\")."),
              tags$li("R² of fitting y ~ x linear model (drops under nonlinear distortion).")
            ),

            tags$h4("Checks when anomalies appear"),
            tags$ul(
              tags$li("Inspect raw vs corrected density curves for anomalous points: is it true background contraction or signal collapse."),
              tags$li("Verify whether the antibody batch / library has known issues."),
              tags$li("Check whether correlation with RNA (comparable gene) drops abnormally.")
            ),

            tags$p(style = "color:#555;font-size:12px;",
                  "Note: A large mean decrease does not automatically indicate error; judge in combination with: background components, density shape, isotype, and downstream clustering separability.")
          )
        } else if (figure_select == "adt_detection_rate") {
          div(
            tags$h4("Figure structure"),
            tags$p(
              "Each gray line represents 1 antibody (ADT feature) change in detection rate (non-zero proportion) before vs after correction: ",
              "left endpoint = Before non-zero proportion, right endpoint = After non-zero proportion."
            ),
            tags$p(
              "Red large points: the median detection rate of all features on each side (Before / After);",
              " y-axis: detection rate (non-zero proportion); x-axis: stage (Before / After)."
            ),

            tags$h4("What it quantifies"),
            tags$ul(
              tags$li("Whether background removal is effective: low-level background-driven 'false positives' should become 0 After → detection rate decreases."),
              tags$li("Whether it is overdone: markers that should be stably expressed in most cells should not have their detection rate drastically reduced.")
            ),

            tags$h4("You should pay attention to"),
            tags$ul(
              tags$li("Overall median: should mildly decrease or stay similar; a sharp drop warrants caution."),
              tags$li("Features with especially large decreases (can sort by Δdetect and list Top N)."),
              tags$li("Whether there is a group of features whose detection rate instead increases: may be caused by normalization / threshold details, need to confirm reasonableness."),
              tags$li("Whether high-expression, biologically established markers (CD45, CD3, CD19, CD14, HLA-DR, etc.) maintain their detection rates.")
            ),

            tags$h4("Typical patterns"),
            tags$ul(
              tags$li("\"Good\" pattern: median slightly decreases; major decreases come from originally low-mean / high-noise features; core high-expression markers nearly unchanged."),
              tags$li("\"Potential issue\": median drops sharply (e.g. 0.7 → 0.3); most features decline simultaneously; core markers also markedly decrease; or lines show a general parallel downward shift.")
            ),

            tags$h4("Derivable quantitative metrics"),
            tags$ul(
              tags$li("Δdetect = detect_after - detect_before (vector), examine its distribution (density / boxplot)."),
              tags$li("Over-decrease count: #(Δdetect < -0.2 and raw_mean > mean_threshold)."),
              tags$li("Median Δdetect (overall shift)."),
              tags$li("Difference between average Δdetect of high-expression markers (whitelist) and overall average Δdetect."),
              tags$li("Whether the set of features with significant decreases is enriched for the known high-background / low-quality antibody list (enrichment test).")
            ),

            tags$h4("Quick checks when anomalies appear"),
            tags$ul(
              tags$li("Spot check high-expression markers with large decreases: inspect their Before / After density distributions to see if they were globally flattened."),
              tags$li("Compare isotype controls: are they more concentrated near 0 (reasonable) rather than inflated together."),
              tags$li("Check downstream clustering / UMAP: are classical populations mixing due to widespread zeroing."),
              tags$li("Verify parameters: was an excessively low threshold or overly strong global scaling used.")
            ),

            tags$p(style="color:#555;font-size:12px;",
                  "Note: Moderate decreases (especially concentrated in low SNR features) are usually expected; large detection rate loss of core high-expression markers is the signal that truly needs priority investigation.")
          )
        }
      }
    })

    # Density plot
    output$density_plot <- renderPlot({
      req(a_ggplot())
      a_ggplot()
    })
  })
}

