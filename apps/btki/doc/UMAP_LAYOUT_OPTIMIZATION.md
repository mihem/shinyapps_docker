# UMAP 布局优化说明

## 📐 布局算法

### 核心思想
在给定的可用空间内，智能计算多面板 UMAP 的最佳行列布局，使每个图尽可能大，同时保证最小尺寸要求。

### 算法流程

```
输入:
  - n_plots: 图的数量
  - available_width: 可用宽度 = (window_width - sidebar_width) / 12 * 9
  - available_height: 可用高度 = window_height - header_height
  - min_size: 最小尺寸要求 (默认 350px)

输出:
  - ncol, nrow: 行列布局
  - plot_height: 绘图容器高度
  - is_feasible: 是否满足最小尺寸
  - use_scroll: 是否需要滚动条
```

### 计算步骤

1. **特殊情况：单个图**
   ```r
   plot_size = min(available_width, available_height)
   如果 plot_size < min_size:
     返回 不可行 + 建议增加高度
   ```

2. **多图情况：遍历所有可能的布局**
   ```r
   for (ncol in 1:n_plots):
     nrow = ceiling(n_plots / ncol)
     plot_width = (available_width - gaps) / ncol
     plot_height = (available_height - gaps) / nrow
     plot_size = min(plot_width, plot_height)  # 保持正方形

     记录最大的 plot_size 对应的布局
   ```

3. **可行性检查**
   ```r
   如果 max_plot_size >= min_size:
     返回 可行布局
   否则:
     返回 滚动条策略（保证 min_size，允许滚动）
   ```

## 🎯 使用示例

### 在 Shiny 模块中使用

```r
source("utils/plot_layout_calculator.R")

# 计算布局
layout <- get_umap_layout(
  n_plots = 12,
  window_width = 1920,
  window_height = 1080,
  sidebar_width = 250,
  header_height = 90,
  min_size = 350
)

# 使用布局参数
output$plot_container <- renderUI({
  if (layout$use_scroll) {
    div(
      style = sprintf("overflow-y: auto; max-height: %dpx;",
                     window_height - 90),
      plotOutput("plot", height = paste0(layout$plot_height, "px"))
    )
  } else {
    plotOutput("plot", height = paste0(layout$plot_height, "px"))
  }
})

# 在 ggplot 中使用列数
p + facet_wrap(~group, ncol = layout$ncol)
```

## 📊 测试结果示例

运行 `source("utils/test_layout_calculator.R")` 查看完整测试。

### 示例输出

```
窗口: 1920x1080, 分组数: 4
  ncol: 2, nrow: 2
  每图尺寸: 750x750 px
  策略: grid_layout (无需滚动)

窗口: 1366x768, 分组数: 12
  ncol: 3, nrow: 4
  每图尺寸: 350x350 px
  策略: scrollable (使用滚动条)
  总高度: 1430 px (当前可用: 678 px)
```

## 🔧 参数调整

### 修改最小尺寸
```r
# 默认 350px
layout <- get_umap_layout(..., min_size = 400)
```

### 修改间隙
```r
# 在 calculate_plot_layout() 中修改
layout <- calculate_plot_layout(..., gap = 15)
```

### 修改宽高比
```r
# 默认 1:1（正方形），可改为矩形
layout <- calculate_plot_layout(..., aspect_ratio = 4/3)
```

## ⚡ 性能优化

### 响应式更新
- **窗口大小变化** → 自动重新计算布局
- **分组数量变化** → 自动调整行列
- **防抖处理** → 250ms 延迟，避免频繁重算

### 缓存策略
```r
layout_params <- reactive({
  # ... 计算布局
}) |> bindCache(window_size(), n_groups())
```

## 🎨 UI 交互

### 滚动提示
当需要滚动时，可以添加提示信息：

```r
if (layout$use_scroll) {
  showNotification(
    paste("总高度", layout$plot_height, "px，使用滚动条查看所有图形"),
    type = "message",
    duration = 3
  )
}
```

### 布局信息显示
```r
output$layout_info <- renderText({
  layout$message
  # 例如: "网格布局：3 行 × 4 列，每图 350x350 px"
})
```

## 🚀 优势

1. **智能布局** - 自动找到最佳行列组合
2. **响应式** - 窗口调整时实时更新
3. **容错性强** - 不满足最小尺寸时提供滚动方案
4. **灵活配置** - 可自定义最小尺寸、间隙等参数
5. **性能优化** - 防抖 + 缓存，避免过度计算

## 📝 注意事项

1. **最小尺寸** - 默认 350px 适用于大多数场景
2. **浏览器兼容性** - 使用标准 CSS，兼容性好
3. **移动端** - 小屏幕可能需要更激进的滚动策略
4. **打印** - 滚动容器可能影响打印，需要特殊处理

## 🔍 调试

启用调试信息：

```r
# 在 get_umap_layout() 中会自动输出
# ===> [布局计算] 窗口: 1920 x 1080, 分组数: 12
# ===> [布局信息] 网格布局：3 行 × 4 列，每图 350x350 px
```

关闭调试信息：注释掉 `cat()` 语句即可。
