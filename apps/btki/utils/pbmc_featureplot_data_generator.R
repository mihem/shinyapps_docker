source("utils/global.R")






expr_df <- qread("data/shinyapp_pbmc_21_S07_STACAS_rna_data_expr.qs")
umap_data <- qread("data/shinyapp_pbmc_21_S07_STACAS_plot_df.qs")

# ===== 批量生成所有参数组合的缓存文件 =====

# 创建临时目录
temp_dir <- "data/pbmc_feature_plot_cache"
if (!dir.exists(temp_dir)) {
  dir.create(temp_dir, recursive = TRUE)
  cat("===> [INFO] 创建目录:", temp_dir, "\n")
}

# 细胞总数
n_total <- nrow(umap_data)

qsave(n_total, file.path(temp_dir, "total_cell_number.qs"))




nearest100 <- function(x) {
  if (n_total < 100) return(n_total)               # 总数不足 100 直接用全部
  y <- round(x / 100) * 100
  y <- max(100, min(y, n_total))
  y
}
sizes_raw <- c(n_total/20, n_total/5)
sizes <- vapply(sizes_raw, nearest100, numeric(1))
sizes <- unique(sizes)

print(sizes)


for(szie in sizes){
  set.seed(123)
  message("Generating featureplot data for size = ", szie)
  size <- as.integer(szie)


  sampled_umap_data <- umap_data[sample.int(n_total, size), c("cell", "umap_1", "umap_2", "celltype_merged.l1"), drop = FALSE]

  sampled_expr_df <- expr_df[, sampled_umap_data$cell, drop = FALSE]

  save_path <- file.path(temp_dir, glue::glue("featureplot_data_{size}_cell.qs"))
  qsave(
    list(
      expr_df = sampled_expr_df,
      umap_data = sampled_umap_data
    ),
    save_path
  )
}