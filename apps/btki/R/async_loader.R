# R/async_loader.R
# 通用异步数据加载调度器

library(future)
library(promises)

#' Create Async Data Loader
#'
#' Creates an asynchronous data loading scheduler with concurrent control,
#' progress tracking, and error handling capabilities.
#'
#' @param max_concurrent Integer. Maximum number of concurrent loading tasks.
#'   Default is 2.
#' @param progress_callback Function or NULL. Optional callback function for
#'   progress updates. Should accept (completed, total) parameters.
#' @param verbose Logical. Whether to print loading messages. Default is TRUE.
#'
#' @return List containing the async loader API functions:
#'   - submit: Submit a single resource loading task
#'   - submit_batch: Submit multiple resources with priority ordering
#'   - get: Retrieve loaded resource data
#'   - is_loaded: Check if resource is loaded
#'   - is_loading: Check if resource is currently loading
#'   - is_failed: Check if resource loading failed
#'   - get_status: Get loading status summary
#'   - get_stats: Get detailed loading statistics
#'   - reset: Reset loader state
#'   - set_progress_callback: Set progress callback function
#'
#' @details
#' The loader manages internal state including:
#' - queue: List of pending tasks
#' - active: List of currently executing tasks
#' - completed: List of successfully completed tasks
#' - failed: List of failed tasks
#' - results_env: Environment storing loaded data
#'
#' Global variables used: None (self-contained)
#'
#' @examples
#' loader <- create_async_loader(max_concurrent = 3)
#' loader$submit("data1", list(path = "file.qs", load_fn = qread))
#'
# 创建异步加载器
create_async_loader <- function(max_concurrent = 2, progress_callback = NULL, verbose = TRUE) {

  # 内部状态
  state <- list(
    queue = list(),           # 等待队列
    active = list(),          # 正在执行的任务
    completed = list(),       # 已完成的资源
    failed = list(),          # 失败的任务
    max_concurrent = max_concurrent,
    progress_callback = progress_callback,
    verbose = verbose         # 是否显示详细日志
  )

  # 结果存储环境
  results_env <- new.env(parent = emptyenv())

  #' Compute Label Width for Alignment
  #'
  #' Calculates the maximum character width among a vector of labels
  #' for consistent log message alignment.
  #'
  #' @param labels Character vector. Labels to measure.
  #'
  #' @return Integer. Maximum character width.
  #'
  #' Global variables used: None
  #'
  # 计算标签宽度（用于对齐日志）
  compute_label_width <- function(labels) {
    max(vapply(labels, nchar, integer(1), type = "width"))
  }

  #' Pad Label for Alignment
  #'
  #' Pads a label string to a specified width with trailing spaces
  #' for consistent formatting in log messages.
  #'
  #' @param label Character. Label to pad.
  #' @param width Integer. Target width for padding.
  #'
  #' @return Character. Padded label string.
  #'
  #' Global variables used: None
  #'
  # 格式化日志标签
  pad_label <- function(label, width) {
    w <- nchar(label, type = "width")
    if (w < width) paste0(label, strrep(" ", width - w)) else label
  }

  #' Run Next Queued Task
  #'
  #' Internal function that processes the next task in the queue if
  #' concurrency limits allow. Handles task execution, promise chaining,
  #' and recursive queue processing.
  #'
  #' @return NULL (called for side effects)
  #'
  #' Global variables used:
  #' - state: Loader state object (queue, active, completed, failed)
  #' - results_env: Environment for storing loaded data
  #'
  #' External dependencies:
  #' - future::future: For async task execution
  #' - %...>%: Promise chaining operator
  #'
  # 运行下一个任务
  run_next <- function(session = NULL) {
    # 检查是否可以启动新任务
    if (length(state$active) >= state$max_concurrent || length(state$queue) == 0) {
      return()
    }

    # 取出下一个任务
    job <- state$queue[[1]]
    state$queue <<- state$queue[-1]
    state$active[[job$name]] <<- job

    # 日志
    if (state$verbose) {
      padded_label <- pad_label(job$description, job$label_width %||% nchar(job$description))
      # message("[ASYNC START ] ", padded_label, " -> ", job$resource_config$path)
      message(
        lemon_yellow_bold("[ASYNC START] "),
        padded_label,
        blue(" -> "),
        magenta(job$resource_config$path)
      )
    }

    if (!is.null(session)) {
      shiny::showNotification(
        paste0("Async loading: ", job$description),
        type = "warning", session = session, duration = 5
      )
    }

    # 创建异步任务
    future_obj <- tryCatch({
      future::future({
        start_time <- Sys.time()
        tryCatch({
          result <- job$resource_config$load_fn(job$resource_config$path)
          list(
            success = TRUE,
            data = result,
            load_time = as.numeric(difftime(Sys.time(), start_time, units = "secs"))
          )
        }, error = function(e) {
          list(
            success = FALSE,
            error = conditionMessage(e),
            load_time = as.numeric(difftime(Sys.time(), start_time, units = "secs"))
          )
        })
      })
    }, error = function(e) {
      # Future创建失败，直接处理
      state$active[[job$name]] <<- NULL
      state$failed[[job$name]] <<- paste("Future creation failed:", conditionMessage(e))
      if (state$verbose) {
        warning(sprintf("[ASYNC FAILED] %s -> Future creation failed: %s", padded_label, conditionMessage(e)), call. = FALSE)
      }

      if (!is.null(job$on_error)) {
        job$on_error(conditionMessage(e))
      }

      # 继续处理队列
      run_next()
      return(NULL)  # 返回NULL表示没有future对象
    })

    # 如果future创建失败，直接返回
    if (is.null(future_obj)) {
      return()
    }

    # 处理完成
    future_obj %...>% (function(result) {
      # 从活跃队列移除
      state$active[[job$name]] <<- NULL

      if (result$success) {
        # 成功
        assign(job$name, result$data, envir = results_env)
        state$completed[[job$name]] <<- list(
          load_time = result$load_time,
          size_info = object.size(result$data)
        )

        if (state$verbose) {
          message(
            green_bold("[ASYNC LOADED] "),
            padded_label,
            blue$italic(  # 时间部分用蓝色斜体
              sprintf(" (%.2fs", result$load_time)
            ),
            magenta(  # 内存部分用紫色
              sprintf(", %.1fMB)", as.numeric(object.size(result$data)) / 1024^2)
            )
          )
        }

        # 调用成功回调
        if (!is.null(job$on_success)) {
          job$on_success(result$data)
        }
      } else {
        # 失败
        state$failed[[job$name]] <<- result$error

        # 完整的错误消息
        if (state$verbose) {
          full_error_msg <- sprintf("[ASYNC ERROR ] %s -> %s", padded_label, result$error)
          warning(full_error_msg, call. = FALSE)
        }

        # 调用失败回调
        if (!is.null(job$on_error)) {
          job$on_error(result$error)
        }
      }

      # 更新进度
      if (!is.null(state$progress_callback)) {
        total_jobs <- length(state$completed) + length(state$failed) +
                     length(state$active) + length(state$queue)
        completed_jobs <- length(state$completed) + length(state$failed)
        state$progress_callback(completed_jobs, total_jobs)
      }

      # 继续处理队列
      run_next()
    }) %...!% (function(e) {
      # Promise失败处理
      state$active[[job$name]] <<- NULL
      state$failed[[job$name]] <<- conditionMessage(e)

      # 完整的错误消息
      if (state$verbose) {
        full_error_msg <- sprintf("[ASYNC FAILED] %s -> %s", padded_label, conditionMessage(e))
        warning(full_error_msg, call. = FALSE)
      }

      if (!is.null(job$on_error)) {
        job$on_error(conditionMessage(e))
      }

      # 继续处理队列
      run_next()
    })

    # 递归启动更多任务（在并发限制内）
    run_next()
  }

  # 返回加载器API
  loader_api <- list(
    #' Submit Single Resource Loading Task
    #'
    #' Submits a single resource for asynchronous loading. The task is added
    #' to the queue and will be processed when concurrency limits allow.
    #'
    #' @param resource_name Character. Unique identifier for the resource.
    #' @param resource_config List. Configuration containing path, load_fn, etc.
    #' @param description Character or NULL. Human-readable description.
    #' @param on_success Function or NULL. Callback for successful loading.
    #' @param on_error Function or NULL. Callback for loading errors.
    #' @param label_width Integer or NULL. Width for log label padding.
    #'
    #' @return Character. The resource name (invisibly).
    #'
    #' Global variables used:
    #' - state: Loader state object (queue, active, completed, failed)
    #'
    # 提交单个资源加载任务
    submit = function(resource_name, resource_config, description = NULL,
                     on_success = NULL, on_error = NULL, label_width = NULL, session = NULL) {

      job <- list(
        name = resource_name,
        resource_config = resource_config,
        description = description %||% resource_config$description %||% resource_name,
        on_success = on_success,
        on_error = on_error,
        label_width = label_width,
        submitted_at = Sys.time()
      )

      # 添加到队列
      state$queue <<- append(state$queue, list(job))

      # 尝试立即开始
      run_next(session = session)

      invisible(resource_name)
    },

    #' Submit Batch of Resources with Priority Ordering
    #'
    #' Submits multiple resources for loading, automatically sorted by
    #' priority. Calculates optimal label width for consistent formatting.
    #'
    #' @param resource_list Named list. Resources to load, each containing
    #'   priority field for sorting.
    #' @param label_width Integer or NULL. Override automatic label width
    #'   calculation.
    #'
    #' @return Character vector. Names of submitted resources (invisibly).
    #'
    #' Global variables used:
    #' - submit: The submit function from parent scope
    #'
    # 批量提交（按优先级排序）
    submit_batch = function(resource_list, label_width = NULL, session = NULL) {
      if (is.null(label_width)) {
        descriptions <- sapply(resource_list, function(x) x$description %||% "")
        label_width <- compute_label_width(descriptions)
      }

      # 按优先级排序
      sorted_resources <- resource_list[order(sapply(resource_list, function(x) x$priority))]

      for (name in names(sorted_resources)) {
        res <- sorted_resources[[name]]
        loader_api$submit(name, res, res$description, label_width = label_width, session = session)
      }

      invisible(names(sorted_resources))
    },

    #' Get Loaded Resource Data
    #'
    #' Retrieves data for a loaded resource by name. Returns NULL if
    #' resource is not yet loaded or does not exist.
    #'
    #' @param resource_name Character. Name of the resource to retrieve.
    #'
    #' @return Any. The loaded resource data, or NULL if not available.
    #'
    #' Global variables used:
    #' - results_env: Environment containing loaded resource data
    #'
    # 获取已加载的资源
    get = function(resource_name) {
      if (exists(resource_name, envir = results_env)) {
        get(resource_name, envir = results_env)
      } else {
        NULL
      }
    },

    #' Check if Resource is Loaded
    #'
    #' Tests whether a resource has been successfully loaded and is
    #' available in the results environment.
    #'
    #' @param resource_name Character. Name of the resource to check.
    #'
    #' @return Logical. TRUE if resource is loaded, FALSE otherwise.
    #'
    #' Global variables used:
    #' - results_env: Environment containing loaded resource data
    #'
    # 检查资源是否已加载
    is_loaded = function(resource_name) {
      exists(resource_name, envir = results_env)
    },

    #' Check if Resource is Currently Loading
    #'
    #' Tests whether a resource is currently being processed (in active queue).
    #'
    #' @param resource_name Character. Name of the resource to check.
    #'
    #' @return Logical. TRUE if resource is loading, FALSE otherwise.
    #'
    #' Global variables used:
    #' - state: Loader state object (active tasks list)
    #'
    # 检查资源是否正在加载
    is_loading = function(resource_name) {
      resource_name %in% names(state$active)
    },

    #' Check if Resource Loading Failed
    #'
    #' Tests whether a resource loading attempt failed and is in the
    #' failed tasks list.
    #'
    #' @param resource_name Character. Name of the resource to check.
    #'
    #' @return Logical. TRUE if resource failed to load, FALSE otherwise.
    #'
    #' Global variables used:
    #' - state: Loader state object (failed tasks list)
    #'
    # 检查资源是否失败
    is_failed = function(resource_name) {
      resource_name %in% names(state$failed)
    },

    #' Get Loading Status Summary
    #'
    #' Returns a comprehensive summary of the loader's current state,
    #' including counts and names of resources in each state.
    #'
    #' @return List containing:
    #'   - completed: Names of completed resources
    #'   - active: Names of currently loading resources
    #'   - queued: Names of queued resources
    #'   - failed: Names of failed resources
    #'   - total_*: Counts for each category
    #'
    #' Global variables used:
    #' - state: Complete loader state object
    #'
    # 获取加载状态摘要
    get_status = function() {
      list(
        completed = names(state$completed),
        active = names(state$active),
        queued = sapply(state$queue, function(x) x$name),
        failed = names(state$failed),
        total_completed = length(state$completed),
        total_failed = length(state$failed),
        total_active = length(state$active),
        total_queued = length(state$queue)
      )
    },

    #' Get Detailed Loading Statistics
    #'
    #' Calculates and returns detailed performance statistics including
    #' loading times, memory usage, and success/failure counts.
    #'
    #' @return List containing:
    #'   - total_load_time: Sum of all loading times
    #'   - average_load_time: Mean loading time
    #'   - total_memory_mb: Total memory usage in MB
    #'   - resources_loaded: Count of successfully loaded resources
    #'   - resources_failed: Count of failed resources
    #'
    #' Global variables used:
    #' - state: Loader state object (completed, failed lists)
    #'
    # 获取详细统计
    get_stats = function() {
      completed_stats <- state$completed
      if (length(completed_stats) > 0) {
        total_time <- sum(sapply(completed_stats, function(x) x$load_time))
        avg_time <- mean(sapply(completed_stats, function(x) x$load_time))
        total_size <- sum(sapply(completed_stats, function(x) as.numeric(x$size_info)))
      } else {
        total_time <- avg_time <- total_size <- 0
      }

      list(
        total_load_time = total_time,
        average_load_time = avg_time,
        total_memory_mb = total_size / 1024^2,
        resources_loaded = length(completed_stats),
        resources_failed = length(state$failed)
      )
    },

    #' Reset Loader State
    #'
    #' Completely resets the loader state, clearing all queues, active tasks,
    #' and loaded data. Use with caution as this destroys all loaded resources.
    #'
    #' @return Logical. TRUE (invisibly) indicating successful reset.
    #'
    #' Global variables used:
    #' - state: Complete loader state object (all components)
    #' - results_env: Environment containing loaded data
    #'
    # 重置加载器（清空所有状态）
    reset = function() {
      state$queue <<- list()
      state$active <<- list()
      state$completed <<- list()
      state$failed <<- list()
      rm(list = ls(envir = results_env), envir = results_env)
      invisible(TRUE)
    },

    #' Set Progress Callback Function
    #'
    #' Updates the progress callback function used to report loading progress.
    #' The callback will be called with (completed, total) parameters.
    #'
    #' @param callback Function. Callback function accepting (completed, total)
    #'   parameters, or NULL to disable progress reporting.
    #'
    #' @return NULL (called for side effects)
    #'
    #' Global variables used:
    #' - state: Loader state object (progress_callback field)
    #'
    # 设置进度回调
    set_progress_callback = function(callback) {
      state$progress_callback <<- callback
    }
  )

  # 返回API对象
  return(loader_api)
}

#' Create Default Async Loader
#'
#' Convenience function that creates an async loader with sensible defaults:
#' - Concurrency based on CPU cores minus 1
#' - Built-in progress callback that logs to console
#'
#' @param verbose Logical. Whether to show detailed loading messages. Default is FALSE for cleaner output.
#' @param cores Integer or NULL. Number of concurrent loading tasks. Default is NULL, which sets
#'   concurrency to max(1, parallel::detectCores() - 1).
#' @param session Shiny session object or NULL. Optional Shiny session for sending notifications.
#'
#' @return List. Async loader API object with default configuration.
#'
#' @details
#' The default loader uses:
#' - max_concurrent = max(1, parallel::detectCores() - 1)
#' - progress_callback that prints formatted progress messages
#'
#' Global variables used:
#' - parallel::detectCores(): System function to detect CPU cores
#'
#' @examples
#' loader <- create_default_loader()
#' # Uses optimal concurrency for your system with quiet loading
#'
#' loader_verbose <- create_default_loader(verbose = TRUE)
#' # Shows detailed loading messages
#'
#' loader_shiny <- create_default_loader(session = shiny::getDefaultReactiveDomain())
#' # Sends progress notifications in a Shiny app
#'
# 便利函数：创建带默认设置的加载器
create_default_loader <- function(verbose = FALSE, cores = 3, session = NULL, async_loader_started_id = "async_loader_started") {
  # cores: 用户自定义并发核心数，默认自动检测
  if (is.null(cores)) {
    max_concurrent <- max(1, parallel::detectCores() - 1)
  } else {
    max_concurrent <- max(1, as.integer(cores))
  }
  create_async_loader(
    max_concurrent = max_concurrent,
    progress_callback = function(completed, total) {
      if (total > 0) {
        progress_message <- sprintf("Loading resources: %d/%d loaded (%.1f%%).",
                                    completed, total, 100 * completed / total)
        if (verbose) {
          message(progress_message)
        }
        if (!is.null(session)) {
          shiny::showNotification(progress_message, type = "message", session = session, duration = 1)
        }

        if (completed == total) {
          final_message <- "All resources loaded."
          if (verbose) {
            message(final_message)
          }
          if (!is.null(session)) {
            shiny::showNotification(final_message, type = "message", session = session, duration = 10)
            shiny::removeNotification(id = async_loader_started_id)
          }
        }
      }
    },
    verbose = verbose
  )
}