source("utils/global.R")

# ===== 定义热图数据生成函数 =====
heatmap_data_func <- function(metadata, expr, markers_df,
                              hm_colors = c("#4575b4","white","#d73027"),
                              hm_limit = c(-2, 0, 2),
                              cell_number_limit = NULL,
                              n = 8,
                              sort_var = "annotated",  # 默认按 annotated 排序
                              anno_vars = c("treatment", "timepoint"),
                              cached_file = NULL) {
  metadata$cell_name <- rownames(metadata)
  genes_all <- rownames(expr)

  # filter out every row that contains a duplicate name in the column "gene"
  markers_df <- markers_df[!duplicated(markers_df$gene),]

  # 按细胞数量排序，重新组织基因顺序
  # 1. 统计每种细胞类型的数量
  celltypes_sorted <- metadata[, sort_var] %>%
    table() %>%
    sort(decreasing = TRUE) %>%
    names()

  # 2. 重新设置 annotated 为 factor，levels 按数量排序
  metadata[[sort_var]]<- factor(metadata[[sort_var]], levels = celltypes_sorted)
  # 3. 根据 celltypes_sorted 给 markers_df 排序
  markers_df <- markers_df %>%
    filter(.data$gene %in% genes_all) %>%
    arrange(desc(.data$avg_log2FC)) %>%
    group_by(.data$cluster) %>%
    filter(row_number() <= n) %>%
    mutate(cluster = factor(cluster, levels = celltypes_sorted)) %>%
    arrange(cluster)

  markers_df <- markers_df[!duplicated(markers_df$gene),]

  # 1.每个 细胞类型组最多 500 个细胞
  if (!is.null(cell_number_limit)) {
    set.seed(123)  # 保证可重复
    metadata <- metadata %>%
      group_by(!!!syms(sort_var)) %>%
      slice_sample(n = cell_number_limit) %>%
      ungroup()
  }

  # 2. 灵活排序，只按存在的列排序
  # 检查可用的排序列
  available_cols <- sort_var
  for (anno in anno_vars) {
    if (anno %in% colnames(metadata)) {
      available_cols <- c(available_cols, anno)
    }
  }
  cat("===> [调试] 排序列:", paste(available_cols, collapse = ", "), "\n")

  # 使用动态排序
  metadata_sorted <- metadata %>%
    arrange(across(all_of(available_cols)))

  # 3. 获取排序后的细胞名称
  cells_sorted <- metadata_sorted$cell_name

  # 4. 提取表达矩阵 & 按列排序
  plot_data <- expr[markers_df$gene, cells_sorted, drop = FALSE]


  # 准备列注释数据 - 只包含存在的列
  col_anno_df <- metadata_sorted[, available_cols, drop = FALSE]


  # 准备行注释数据（基因所属的细胞类型）
  row_anno_df <- data.frame(
    Gene_Cluster = markers_df$cluster,
    row.names    = markers_df$gene
  )

  # === 动态创建颜色配置 ===
  annotation_colors <- list()

  color_schemes <- list(
    scales::hue_pal()(length(celltypes_sorted)),
    c("blue", "purple", "cyan", "pink"),
    c("red", "orange", "yellow", "green")
  )

  for (i in 1:length(available_cols)) {
    anno               <- available_cols[i]
    unique_annos       <- unique(col_anno_df[[anno]])
    anno_colors        <- color_schemes[[i]][1:length(unique_annos)]
    names(anno_colors) <- unique_annos
    annotation_colors[[anno]] <- anno_colors
    cat("===> [调试]  颜色配置完成", length(annotation_colors[[anno]]), "\n")
  }

  # === 动态创建列注释 ===
  if (ncol(col_anno_df) > 0) {
    # 构建 HeatmapAnnotation 的参数
    annotation_params <- list()
    legend_params     <- list()

    for (col_name in colnames(col_anno_df)) {
      annotation_params[[col_name]] <- col_anno_df[[col_name]]
      legend_params[[col_name]] <- list(
        title    = col_name,
        title_gp = grid::gpar(fontsize = 12)
      )
    }

    # 创建列注释
    col_annotation <- do.call(ComplexHeatmap::HeatmapAnnotation, c(
      annotation_params,
      list(
        col                     = annotation_colors,
        annotation_name_gp      = grid::gpar(fontsize = 10),
        annotation_legend_param = legend_params
      )
    ))
  } else {
    # 如果没有任何注释列，创建空的注释
    col_annotation <- NULL
    cat("===> [警告] 没有可用的列注释\n")
  }

  # 创建行注释
  row_annotation <- rowAnnotation(
    Gene_Cluster = row_anno_df$Gene_Cluster,
    col          = list(Gene_Cluster = annotation_colors[[sort_var]]),  # 使用相同的颜色
    annotation_name_gp = grid::gpar(fontsize = 10),
    annotation_legend_param = list(
      Gene_Cluster = list(title = "Gene Cluster", title_gp = gpar(fontsize = 12))
    ),
    width = unit(0.5, "cm")
  )

  # 返回数据
  result <- list(
    plot_data = plot_data,
    col_annotation = col_annotation,
    row_annotation = row_annotation,
    row_anno_df = row_anno_df,
    col_anno_df = col_anno_df,
    sort_var = sort_var
  )

  cat("===> [调试] 热图数据准备完成，维度:",
      nrow(plot_data), "x", ncol(plot_data), "\n")
  if (!is.null(cached_file)) {
    qsave(result, file = cached_file, nthreads = 4)
  }

  return(result)
}


# ===== 加载数据 =====
DEG      <- qread("data/shinyapp_pbmc_23_S2_deg_celltype_heatmap.qs")
metadata <- qread("data/shinyapp_pbmc_23_S2_metadata_annotated_timepoint_treatment.qs")
expr     <- qread("data/shinyapp_pbmc_21_S07_STACAS_integrated_scaledata_expr.qs")


# selectInput(
#     ns("p_value_threshold"),
#     label = "P-value Threshold",
#     choices = c(0.001, 0.01, 0.05),
#     selected = 0.05
# ),
# selectInput(
#     ns("topn"),
#     label = "Top N Genes per Cluster",
#     choices = c(5, 10, 15, 20, 25, 30),
#     selected = 10
# ),
# selectInput(
#     ns("cell_number_limit"),
#     label = "Cells Number Per Cluster",
#     choices = c(100, 200, 300, 400, 500, "NO Limit"),
#     selected = 400
# ),

# ===== 批量生成所有参数组合的缓存文件 =====

# 创建临时目录
temp_dir <- "data/pbmc_marker_heatmap_cache"
if (!dir.exists(temp_dir)) {
  dir.create(temp_dir, recursive = TRUE)
  cat("===> [INFO] 创建目录:", temp_dir, "\n")
}

# 定义所有参数选项
p_value_thresholds <- c(0.001, 0.01, 0.05)
topn_choices       <- c(5, 10, 15, 20, 25, 30)
# 使用列表来存储，可以包含 NULL
cell_number_limits <- list(100, 200, 300, 400, 500, 1000, NULL)  # NULL 表示 "NO Limit"

# 生成所有参数组合
param_combinations <- expand.grid(
  p_value    = p_value_thresholds,
  topn       = topn_choices,
  cell_limit = seq_along(cell_number_limits),  # 使用索引
  stringsAsFactors = FALSE
)

cat("===> [INFO] 总共", nrow(param_combinations), "种参数组合\n")
cat("===> [INFO] 开始生成缓存文件...\n\n")

# 记录执行时间和结果
start_time <- Sys.time()
results_log <- data.frame(
  combination = integer(),
  p_value = numeric(),
  topn = integer(),
  cell_limit = character(),
  file_path = character(),
  file_size_mb = numeric(),
  status = character(),
  error_msg = character(),
  stringsAsFactors = FALSE
)

# 遍历所有组合
for (i in 1:nrow(param_combinations)) {
  p_val <- param_combinations$p_value[i]
  topn <- param_combinations$topn[i]
  cell_limit_idx <- param_combinations$cell_limit[i]
  cell_limit <- cell_number_limits[[cell_limit_idx]]

  # 生成文件名
  cell_limit_str <- ifelse(is.null(cell_limit), "NoLimit", as.character(cell_limit))
  cache_file <- file.path(
    temp_dir,
    sprintf("heatmap_pval%.3f_top%d_cells%s.qs", p_val, topn, cell_limit_str)
  )

  cat(sprintf("[%d/%d] 处理: p_val=%.3f, topn=%d, cell_limit=%s\n",
              i, nrow(param_combinations), p_val, topn, cell_limit_str))

  tryCatch({
    # 过滤差异基因
    markers_filtered <- DEG %>% filter(p_val_adj <  .env$p_val)

    if (nrow(markers_filtered) == 0) {
      warning(sprintf("没有基因满足 p_val < %.3f 的条件，跳过", p_val))
      results_log <- rbind(results_log, data.frame(
        combination = i,
        p_value = p_val,
        topn = topn,
        cell_limit = cell_limit_str,
        file_path = cache_file,
        file_size_mb = 0,
        status = "skipped",
        error_msg = "No genes pass p-value threshold"
      ))
      next
    }

    # 生成热图数据
    result <- heatmap_data_func(
      metadata = metadata,
      expr = expr,
      markers_df = markers_filtered,
      n = topn,
      cell_number_limit = cell_limit,
      sort_var = "annotated",
      anno_vars = c("treatment", "timepoint"),
      cached_file = cache_file
    )

    # 获取文件大小
    file_size <- file.info(cache_file)$size / (1024 * 1024)  # MB

    cat(sprintf("  ✓ 成功生成: %s (%.2f MB)\n\n", basename(cache_file), file_size))

    results_log <- rbind(results_log, data.frame(
      combination = i,
      p_value = p_val,
      topn = topn,
      cell_limit = cell_limit_str,
      file_path = cache_file,
      file_size_mb = round(file_size, 2),
      status = "success",
      error_msg = ""
    ))

  }, error = function(e) {
    cat(sprintf("  ✗ 错误: %s\n\n", e$message))
    results_log <<- rbind(results_log, data.frame(
      combination = i,
      p_value = p_val,
      topn = topn,
      cell_limit = cell_limit_str,
      file_path = cache_file,
      file_size_mb = 0,
      status = "error",
      error_msg = e$message
    ))
  })
}

end_time <- Sys.time()
elapsed_time <- difftime(end_time, start_time, units = "mins")

# 保存执行日志
log_file <- file.path(temp_dir, "cache_generation_log.csv")
write.csv(results_log, log_file, row.names = FALSE)

# 打印总结
cat(strrep("=", 60), "\n")
cat("===> 缓存生成完成！\n")
cat("===> 总耗时:", round(elapsed_time, 2), "分钟\n")
cat("===> 成功:", sum(results_log$status == "success"), "个\n")
cat("===> 跳过:", sum(results_log$status == "skipped"), "个\n")
cat("===> 失败:", sum(results_log$status == "error"), "个\n")
cat("===> 总文件大小:", round(sum(results_log$file_size_mb), 2), "MB\n")
cat("===> 日志文件:", log_file, "\n")
cat(strrep("=", 60), "\n")

# 显示失败的组合（如果有）
if (sum(results_log$status == "error") > 0) {
  cat("\n失败的组合:\n")
  print(results_log[results_log$status == "error", c("p_value", "topn", "cell_limit", "error_msg")])
}



heatmap_data <- qread("data/temp/heatmap_pval0.001_top10_cells100.qs")

plot_data       <- heatmap_data$plot_data
col_annotation  <- heatmap_data$col_annotation
row_annotation  <- heatmap_data$row_annotation
row_anno_df     <- heatmap_data$row_anno_df
col_anno_df     <- heatmap_data$col_anno_df
sort_var        <- heatmap_data$sort_var


column_split_param <- col_anno_df[[sort_var]]


Heatmap(
  plot_data,
  name = "Expression",
  col = colorRamp2(c(min(plot_data), 0, max(plot_data)), c("blue", "white", "red")),
  cluster_rows = FALSE,
  cluster_columns = FALSE,
  show_column_names = FALSE,
  column_title = NULL,
  row_title = NULL,
  top_annotation = col_annotation,   # 可能为 NULL
  left_annotation = row_annotation,
  row_split = row_anno_df$Gene_Cluster,
  column_split = column_split_param
)




