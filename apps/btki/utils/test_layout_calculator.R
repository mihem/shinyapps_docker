# ============================================================================
# 测试 UMAP 布局计算器
# ============================================================================

source("utils/plot_layout_calculator.R")

# ============================================================================
# 测试场景
# ============================================================================

# cat("\n========== 测试场景 1: 单个 UMAP ==========\n")
# layout1 <- get_umap_layout(
#   n_plots = 1,
#   window_width = 1920,
#   window_height = 1080,
#   min_size = 350
# )
# print(layout1)

# cat("\n========== 测试场景 2: 4 个 UMAP (可容纳) ==========\n")
# layout2 <- get_umap_layout(
#   n_plots = 4,
#   window_width = 1920,
#   window_height = 1080,
#   min_size = 350
# )
# print(layout2)

# cat("\n========== 测试场景 3: 12 个 UMAP (小窗口，需要滚动) ==========\n")
# layout3 <- get_umap_layout(
#   n_plots = 12,
#   window_width = 1366,
#   window_height = 768,
#   min_size = 350
# )
# print(layout3)

# cat("\n========== 测试场景 4: 24 个 UMAP (需要滚动) ==========\n")
# layout4 <- get_umap_layout(
#   n_plots = 24,
#   window_width = 1920,
#   window_height = 1080,
#   min_size = 350
# )
# print(layout4)

# # ============================================================================
# # 详细测试：不同组合
# # ============================================================================

# cat("\n========== 详细测试：不同布局方案 ==========\n")

# test_cases <- expand.grid(
#   n_plots = c(1, 2, 4, 6, 9, 12, 16, 20, 24),
#   width = c(1366, 1920, 2560),
#   height = c(768, 1080, 1440)
# )

# results <- data.frame()

# for (i in 1:nrow(test_cases)) {
#   layout <- get_umap_layout(
#     n_plots = test_cases$n_plots[i],
#     window_width = test_cases$width[i],
#     window_height = test_cases$height[i],
#     min_size = 350
#   )

#   results <- rbind(results, data.frame(
#     n_plots = test_cases$n_plots[i],
#     window = paste0(test_cases$width[i], "x", test_cases$height[i]),
#     ncol = layout$ncol,
#     nrow = layout$nrow,
#     plot_height = round(layout$plot_height),
#     feasible = layout$is_feasible,
#     use_scroll = layout$use_scroll %||% FALSE
#   ))
# }

# cat("\n布局测试结果：\n")
# print(results, row.names = FALSE)

# # 统计
# cat("\n========== 统计 ==========\n")
# cat("可行方案数量:", sum(results$feasible), "/", nrow(results), "\n")
# cat("需要滚动的方案:", sum(results$use_scroll), "/", nrow(results), "\n")
# cat("完美方案（无需滚动）:", sum(results$feasible & !results$use_scroll), "/", nrow(results), "\n")



cat("\n========== 测试场景 3: 1 个 UMAP (小窗口，需要滚动) ==========\n")
layout3 <- get_umap_layout(
  n_plots = 16,
  window_width = 676,
  window_height = 777,
  min_size = 350
)
print(layout3)



# calculate_plot_layout(
#   n_plots = 16,
#   available_width = 1218,
#   available_height = 1167,
#   min_size = 350
# )