# 重构架构迁移指南

## 新架构概览

### 文件结构变化

```
旧结构 -> 新结构
====================================
app.R                  -> app.R (简化，仅调用run_app)
server/server_main.R   -> R/app_server.R (大幅简化)
ui/ui_main.R          -> R/app_ui.R (清理)
(无)                  -> R/data_registry.R (新增)
(无)                  -> R/async_loader.R (新增)
(无)                  -> R/module_specs.R (新增)
(无)                  -> R/orchestrator.R (新增)
(无)                  -> R/run_app.R (新增)
(无)                  -> R/utils_cache.R (新增)
```

### 核心改进

#### 1. 数据管理 (data_registry.R)
- ✅ **集中化**: 所有数据资源在一个地方定义
- ✅ **元数据**: 每个资源包含路径、大小、优先级、描述等
- ✅ **依赖关系**: 缓存文件与原始文件的fallback关系
- ✅ **验证机制**: 自动检查文件是否存在

#### 2. 异步加载 (async_loader.R)
- ✅ **并发控制**: 限制同时加载的大文件数量
- ✅ **优先级队列**: 按重要性排序加载
- ✅ **进度跟踪**: 详细的加载状态和统计
- ✅ **错误处理**: 优雅的失败处理和重试机制

#### 3. 模块规格 (module_specs.R)
- ✅ **声明式配置**: 每个模块明确声明依赖资源
- ✅ **类型区分**: immediate(立即) vs lazy(延迟) 模块
- ✅ **ready函数**: 自定义的准备检查逻辑
- ✅ **可选资源**: 支持缓存优先、fallback逻辑

#### 4. 编排器 (orchestrator.R)
- ✅ **智能调度**: 自动检测资源就绪并初始化模块
- ✅ **tab监听**: 基于用户导航触发模块加载
- ✅ **状态管理**: 跟踪哪些模块已初始化
- ✅ **轮询机制**: 定期检查待处理模块

## 从旧代码迁移

### 原server_main.R问题
```r
# ❌ 旧方式: 所有逻辑混在一起
server <- function(input, output, session) {
  # 655行代码！包含：
  # - 同步数据加载
  # - 异步数据加载
  # - 模块初始化
  # - 状态管理
  # - UI逻辑
  # - 错误处理
}
```

### 新架构分解
```r
# ✅ 新方式: 清晰分层
app_server <- function(input, output, session) {
  # 1. 初始化系统 (5行)
  # 2. 同步加载首屏资源 (10行)
  # 3. 启动异步加载 (3行)
  # 4. 设置编排器 (2行)
  # 5. 初始化首屏模块 (2行)
  # 6. 状态输出 (10行)
  # 总计约40行！
}
```

## 性能优化效果

### 首屏加载优化
- **旧方式**: 所有futures同时启动，IO竞争严重
- **新方式**:
  - 首屏阻塞资源同步加载（快速）
  - 大文件按优先级异步加载
  - 并发数限制，避免资源竞争

### 内存管理
- **旧方式**: 所有数据存在全局reactiveValues中
- **新方式**:
  - 异步加载器独立的结果环境
  - 支持磁盘缓存减少内存占用
  - 可配置的缓存策略

### 模块初始化
- **旧方式**: 655行代码中散布着模块初始化逻辑
- **新方式**:
  - 声明式模块规格
  - 自动依赖检查
  - 智能延迟初始化

## 使用新架构

### 运行应用
```r
# 开发模式（带调试）
source("R/run_app.R")
run_app_dev(port = 14242)

# 生产模式
run_app_production(port = 3838, host = "0.0.0.0")
```

### 添加新数据源
```r
# 在 R/data_registry.R 中添加
new_data = list(
  path = "data/new_analysis.qs",
  type = "analysis_result",
  size_mb = 15,
  blocking = FALSE,
  priority = 40,
  concurrent = TRUE,
  description = "新分析结果",
  load_fn = function(path) qread(path)
)
```

### 添加新模块
```r
# 在 R/module_specs.R 中添加
new_module = list(
  type = "lazy",
  resources = c("new_data"),
  tab_name = "new_analysis",
  ready_fn = function(loader) loader$is_loaded("new_data"),
  init_fn = function(id, resources) {
    new_analysis_Server(id, data = resources$new_data)
  }
)
```

## 向后兼容

### 渐进式迁移
1. **阶段1**: 新架构与旧代码并行运行
2. **阶段2**: 逐个模块迁移到新架构
3. **阶段3**: 完全移除旧代码

### 切换方式
```r
# app.R 中选择运行方式
USE_NEW_ARCHITECTURE <- TRUE

if (USE_NEW_ARCHITECTURE) {
  source("R/run_app.R")
  run_app_dev(port = 14242)
} else {
  # 旧方式
  source("ui/ui_main.R")
  source("server/server_main.R")
  shinyApp(ui = ui, server = server, options = list(port = 14242))
}
```

## 调试和监控

### 状态监控
- 实时查看加载进度
- 模块初始化状态
- 资源使用统计
- 错误日志

### 调试模式
```r
# 启用详细日志
options(shiny.debug = TRUE)
run_app_dev()  # 自动启用调试功能
```

## 后续扩展计划

1. **HDF5支持**: 大矩阵数据的内存高效加载
2. **分布式缓存**: 多用户会话间的缓存共享
3. **模块热重载**: 开发时无需重启应用
4. **性能分析**: 内置的性能监控面板
5. **配置外部化**: YAML/JSON配置文件支持
