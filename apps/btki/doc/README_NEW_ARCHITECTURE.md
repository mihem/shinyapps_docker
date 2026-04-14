# 重构后的Shiny应用架构

## 🚀 快速开始

### 运行应用

```r
# 开发模式（推荐）
source("R/run_app.R")
run_app_dev(port = 14242)

# 生产模式
run_app_production(port = 3838, host = "0.0.0.0")

# 或者直接运行 app.R
source("app.R")
```

### 测试新架构

```r
# 运行基础测试
source("test/test_new_architecture.R")
```

## 📁 新架构文件结构

```
R/
├── data_registry.R     # 数据资源注册表
├── async_loader.R      # 异步加载调度器
├── module_specs.R      # 模块规格定义
├── orchestrator.R      # 模块编排器
├── app_server.R        # 精简的server逻辑
├── app_ui.R           # UI定义
├── run_app.R          # 应用启动函数
└── utils_cache.R      # 缓存工具

modules/              # 业务模块（保持不变）
ui/                   # UI组件（保持不变）
data/                 # 数据文件（保持不变）
test/                 # 测试脚本
```

## 🔧 核心组件

### 1. 数据注册表 (data_registry.R)

集中管理所有数据资源的配置：

```r
# 添加新数据源
data_resources$new_analysis <- list(
  path = "data/new_analysis.qs",
  type = "analysis_result",
  size_mb = 20,
  blocking = FALSE,        # 非阻塞（异步加载）
  priority = 30,          # 优先级（数字越小越优先）
  concurrent = TRUE,      # 可以并发加载
  description = "新分析结果",
  load_fn = function(path) qread(path)
)
```

### 2. 异步加载器 (async_loader.R)

智能的异步数据加载系统：

```r
# 创建加载器
loader <- create_async_loader(max_concurrent = 2)

# 批量提交异步任务
async_resources <- get_async_resources()
loader$submit_batch(async_resources)

# 检查加载状态
loader$is_loaded("umap_plot_data")
data <- loader$get("umap_plot_data")
```

### 3. 模块规格 (module_specs.R)

声明式的模块配置：

```r
# 添加新模块
module_specs$new_module <- list(
  type = "lazy",                    # 延迟加载
  resources = c("new_analysis"),    # 依赖的数据资源
  tab_name = "new_analysis",        # 对应的tab名称
  description = "新分析模块",
  ready_fn = function(loader) {     # 自定义准备检查
    loader$is_loaded("new_analysis")
  },
  init_fn = function(id, resources) {  # 初始化函数
    new_analysis_Server(id, data = resources$new_analysis)
  }
)
```

### 4. 编排器 (orchestrator.R)

自动协调数据加载和模块初始化：

```r
# 在server中设置
orchestrator <- setup_orchestrator(session, async_loader)

# 自动处理：
# - 监听tab切换
# - 检查资源是否就绪
# - 初始化准备好的模块
# - 提供状态报告
```

## 📊 性能优化特性

### 首屏加载优化
- **阻塞资源**：小文件同步加载，确保首屏快速显示
- **异步资源**：大文件按优先级后台加载
- **并发控制**：避免IO竞争，提升整体性能

### 内存管理
- **按需加载**：只在需要时才加载模块
- **缓存策略**：支持内存和磁盘缓存
- **资源释放**：会话结束时自动清理

### 智能调度
- **优先级队列**：重要资源优先加载
- **依赖检查**：自动等待依赖资源就绪
- **错误恢复**：优雅处理加载失败

## 🔍 监控和调试

### 实时状态监控

应用会显示详细的加载状态：

```
模块: 8/15 已初始化, 3 待处理 | 资源: 12 已加载, 2 加载中, 1 队列中, 0 失败
```

### 调试模式

```r
# 启用详细调试日志
run_app_dev()  # 自动启用调试模式

# 查看详细统计
loader$get_stats()
orchestrator$get_state()
```

### 日志输出示例

```
[APP SERVER] 初始化异步加载系统...
[SYNC LOADED ] PBMC样本汇总元数据              (0.12s)
[SYNC LOADED ] PBMC细胞级原始元数据            (0.08s)
[ASYNC START ] UMAP降维坐标数据 -> data/20_S08_shiny_app_STACAS_plot_df.qs
[ASYNC LOADED] UMAP降维坐标数据 (2.31s, 15.2MB)
[ORCHESTRATOR] 延迟初始化模块: PBMC UMAP可视化模块
```

## 🔧 自定义和扩展

### 添加新的数据类型

```r
# 1. 在 data_registry.R 中定义
# 2. 指定加载函数
# 3. 设置优先级和并发策略
```

### 添加新的分析模块

```r
# 1. 在 modules/ 中创建模块文件
# 2. 在 module_specs.R 中注册
# 3. 指定资源依赖
```

### 自定义缓存策略

```r
# 使用 utils_cache.R 中的工具
cached_loader <- create_cached_loader(
  load_fn = qread,
  cache_key_fn = function(path) digest::digest(path),
  use_disk_cache = TRUE
)
```

## 🚀 迁移指南

### 从旧架构迁移

1. **保留兼容性**：旧代码仍可运行
2. **渐进迁移**：逐个模块迁移到新架构
3. **并行测试**：新旧架构可同时测试

```r
# app.R 中切换
USE_NEW_ARCHITECTURE <- TRUE  # 设为 FALSE 使用旧架构
```

### 模块迁移步骤

1. 将模块的数据加载逻辑移到 `data_registry.R`
2. 在 `module_specs.R` 中定义模块规格
3. 简化模块的server函数，移除数据加载代码
4. 测试模块在新架构下的运行

## 🎯 后续计划

- [ ] **HDF5支持**：大矩阵数据的高效加载
- [ ] **分布式缓存**：多用户会话间共享缓存
- [ ] **配置外部化**：YAML配置文件支持
- [ ] **性能监控**：内置性能分析面板
- [ ] **模块热重载**：开发时无需重启应用

## 🆘 故障排除

### 常见问题

1. **模块未初始化**：检查资源是否正确加载
2. **加载速度慢**：调整并发数和优先级
3. **内存占用高**：启用磁盘缓存

### 调试命令

```r
# 检查资源状态
loader$get_status()

# 检查模块状态
orchestrator$generate_status_report()

# 重置状态
loader$reset()
orchestrator$reset()
```
