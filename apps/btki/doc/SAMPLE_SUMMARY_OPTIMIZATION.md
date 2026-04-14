# Sample Summary 模块优化说明

## 优化目标

基于原有的 `pbmc_sample_summary` 模块，创建了优化版本的 `sample_summary` 模块，主要优化方向：

1. **数据预处理优化**
2. **模块服务器端性能优化**
3. **UI 延迟注入**（可选，在主应用中实现）

## 优化实现

### 1. 数据预处理优化

- **格式兼容性**：支持原有的 list 格式和新的统一 data.table 格式
- **Data.table 转换**：自动将数据转换为 data.table 格式，提升查询性能
- **键设置**：为 sample_id 列设置键，加速子集操作

### 2. 模块服务器端优化

#### 2.1 Module-level Cache + Memoise
```r
# Module-level cache environment
.sample_summary_cache <- new.env(parent = emptyenv())

# 使用 memoise 缓存数据子集操作
get_sample_data_cached <- memoise::memoise(function(sample_id, data_type) {
  # 数据子集逻辑
}, cache = .sample_summary_cache)
```

#### 2.2 条件渲染
```r
# 仅在对应 tab 激活时渲染 DataTable
output$metadata_table <- DT::renderDT({
  req(active_tab() == "meta_all")  # 只有当前 tab 才渲染
  build_dt(meta_all_sel(), enable_filter = TRUE)
}, server = TRUE)
```

#### 2.3 预渲染策略
```r
# 使用 onFlush + later 实现 idle 时预渲染
onFlush(function() {
  later::later(function() {
    # 在用户空闲时预加载常用 tab 数据
    next_tab <- prerender_candidates[1]
    future::future({
      # 异步预加载数据
    })
  }, delay = 0.1)
}, once = FALSE)
```

#### 2.4 响应式缓存
```r
# 使用 bindCache 缓存响应式表达式
meta_all_sel <- reactive({
  req(current_sample())
  get_sample_data_cached(current_sample(), "meta_all")
}) |> bindCache(current_sample(), cache = "session")
```

### 3. 性能优化特性

#### 3.1 缓存机制
- **Module-level cache**：模块级别的缓存环境
- **Memoise 缓存**：函数级别的结果缓存
- **Session cache**：会话级别的响应式缓存

#### 3.2 懒加载
- **条件渲染**：只渲染当前激活的 tab
- **挂起机制**：隐藏的 output 自动挂起
- **预渲染**：空闲时异步预加载常用数据

#### 3.3 数据结构优化
- **Data.table**：更高效的数据操作
- **键索引**：加速查询操作
- **内存紧凑**：减少内存占用

## 文件结构

```
modules/
├── sample_summary.R          # 优化版本模块
├── pbmc_modules.R            # 原版模块（保留）
└── ...

server/
└── server_main.R             # 添加了新模块的调用

ui/
├── ui_main.R                 # 添加了模块加载
├── ui_body.R                 # 添加了测试页面
└── ui_sidebar.R              # 添加了菜单项

# 测试文件
test_sample_summary.R         # 模块功能测试
performance_test.R            # 性能对比测试
```

## 使用方法

### 1. 在主应用中使用

```r
# 在 server_main.R 中
sample_summary_Server(
  "sample_summary_optimized",
  metadata = base_metadata,
  metadata_cell = base_metadata_cell,
  metadata_cell_filtered = base_metadata_cell_filtered,
  enable_prerender = TRUE,
  cache_enabled = TRUE
)
```

### 2. 独立测试

```r
# 运行功能测试
source("test_sample_summary.R")

# 运行性能测试
source("performance_test.R")
```

## 配置参数

### sample_summary_Server 参数

- `id`: 模块 ID
- `metadata`: 元数据（支持 list 或 data.table 格式）
- `metadata_cell`: 细胞元数据
- `metadata_cell_filtered`: 过滤后的细胞元数据
- `enable_prerender`: 是否启用预渲染（默认 TRUE）
- `cache_enabled`: 是否启用缓存（默认 TRUE）

### 预渲染配置

```r
# 可在模块文件中修改预渲染的 tab 列表
.prerender_tabs <- c("meta_all", "meta_cell")
```

## 性能期望

### 首次访问
- 可能略慢于原版（数据转换开销）
- data.table 转换是一次性成本

### 重复访问
- 显著快于原版（缓存效果）
- 样本切换响应更快
- tab 切换响应更快

### 内存使用
- data.table 格式更紧凑
- 缓存会占用一定内存
- 整体内存效率更高

## 向后兼容

- 保留原有的 `pbmc_sample_summary` 模块
- 新模块支持原有数据格式
- 渐进式迁移，可并行使用

## 下一步优化

1. **UI 延迟注入**：在主应用中实现动态 UI 加载
2. **数据预处理**：将多个 metadata 文件合并为 parquet 分区
3. **更多缓存策略**：基于使用频率的智能缓存
4. **性能监控**：添加性能指标收集

## 测试验证

通过以下方式验证优化效果：

1. **功能测试**：确保所有功能正常工作
2. **性能测试**：对比原版和优化版的性能差异
3. **内存测试**：监控内存使用情况
4. **用户体验**：测试实际使用中的响应速度

运行测试：
```bash
# 在 R 中
source("test_sample_summary.R")      # 功能测试
source("performance_test.R")         # 性能测试
```
