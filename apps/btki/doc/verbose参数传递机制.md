# verbose 参数传递机制优化

## 问题描述
之前的 `run_app.R` 中无法将 `verbose` 参数传递给 `app_server` 函数，因为 Shiny 的 `shinyApp()` 函数不支持直接传递自定义参数给 server 函数。

## 解决方案

### 使用全局选项 (options) 传递参数

通过 R 的全局选项机制 `options()` 来在 `run_app` 和 `app_server` 之间传递 `verbose` 参数。

### 实现细节

#### 1. 修改 `run_app()` 函数
```r
run_app <- function(port = NULL, host = "127.0.0.1", debug = FALSE, verbose = FALSE, ...) {
  # ... 其他代码 ...

  # 设置 verbose 模式（通过全局选项传递给 app_server）
  options(app.verbose = verbose)

  # ... 其他代码 ...
}
```

#### 2. 修改便利函数
```r
# 安静模式（默认）
run_app_dev <- function(port = NULL, host = "127.0.0.1") {
  run_app(port = port, host = host, debug = FALSE, verbose = FALSE)
}

# 详细模式
run_app_dev_verbose <- function(port = NULL, host = "127.0.0.1") {
  run_app(port = port, host = host, debug = TRUE, verbose = TRUE)
}
```

#### 3. 修改 `app_server()` 读取选项
```r
app_server <- function(input, output, session) {
  # 从全局选项获取 verbose 设置
  verbose_mode <- getOption("app.verbose", FALSE)

  # 使用 verbose_mode 创建组件
  async_loader <- create_default_loader(verbose = verbose_mode)
  orchestrator <- setup_orchestrator(..., verbose = verbose_mode)

  # ... 其他代码 ...
}
```

## 使用方式

### 默认安静模式
```r
source('app.R')           # 使用 run_app_dev()，verbose = FALSE
# 或
app <- run_app_dev()      # 明确调用，verbose = FALSE
```

### 详细调试模式
```r
# 方式1：使用便利函数
app <- run_app_dev_verbose()  # debug = TRUE, verbose = TRUE

# 方式2：直接调用
app <- run_app(debug = TRUE, verbose = TRUE)

# 方式3：只启用 verbose，不启用 debug
app <- run_app(debug = FALSE, verbose = TRUE)
```

### 自定义组合
```r
# 只启用 Shiny 调试，但保持安静的异步日志
app <- run_app(debug = TRUE, verbose = FALSE)

# 只启用详细异步日志，但不启用 Shiny 调试
app <- run_app(debug = FALSE, verbose = TRUE)
```

## 验证方法

可以通过检查全局选项来验证参数传递：
```r
# 在应用创建后检查
getOption("app.verbose")  # 应该返回 TRUE 或 FALSE
```

## 优势

1. **解耦调试选项**: `debug` 控制 Shiny 的调试功能，`verbose` 控制异步组件的日志输出
2. **灵活组合**: 可以独立控制两种调试模式
3. **向后兼容**: 现有代码无需修改
4. **清晰接口**: 函数签名明确表达了可控制的选项

## 效果对比

### verbose = FALSE（安静模式）
```
=== Multi-omics Analysis Dashboard ===
启动时间: 2025-08-30 22:10:31
工作目录: /Users/nuioi/sciebo/shiny_app
调试模式: 禁用
=====================================

Listening on http://127.0.0.1:14242
[APP SERVER] 初始化异步加载系统...
[APP SERVER] 同步加载首屏资源...
[SYNC LOADED ] PBMC 元数据样本统计               (0.02s)
[APP SERVER] 启动异步资源加载...
[APP SERVER] 初始化首屏模块...
[APP SERVER] 初始化完成
```

### verbose = TRUE（详细模式）
```
=== Multi-omics Analysis Dashboard ===
启动时间: 2025-08-30 22:10:31
工作目录: /Users/nuioi/sciebo/shiny_app
调试模式: 启用
=====================================

Listening on http://127.0.0.1:14242
[APP SERVER] 初始化异步加载系统...
[APP SERVER] 同步加载首屏资源...
[SYNC LOADED ] PBMC 元数据样本统计               (0.02s)
[APP SERVER] 启动异步资源加载...
[ASYNC START ] PBMC 完整Seurat对象               -> data/20_S07_seurat_integrated_STACAS_standard_pipeline.qs
[ASYNC START ] PBMC RNA表达矩阵                  -> data/20_S08_shiny_app_STACAS_rna_count_expr.qs
[PROGRESS] 2/14 资源已加载 (14.3%)
[ASYNC LOADED] PBMC 完整Seurat对象               (2.45s, 126.7MB)
[ASYNC LOADED] PBMC RNA表达矩阵                  (1.23s, 45.2MB)
[PROGRESS] 4/14 资源已加载 (28.6%)
[ORCHESTRATOR] 延迟初始化模块: PBMC 特征图可视化
[ORCHESTRATOR] 延迟初始化模块: PBMC 标记基因热图
... 更多详细信息 ...
[APP SERVER] 初始化完成
```

这样就解决了参数传递的问题，提供了灵活的调试控制选项！
