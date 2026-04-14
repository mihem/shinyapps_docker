# R/utils_cache.R
# Cache utility functions

library(digest)

#' Create cache key
#'
#' @param ... Parameters used to generate cache key
#' @return String cache key
create_cache_key <- function(...) {
  args <- list(...)
  digest::digest(args, algo = "md5")
}

#' Wrapper function for bindCache, provides unified cache strategy
#'
#' @param reactive_expr Reactive expression
#' @param cache_key_fn Function to generate cache key
#' @param max_size Maximum number of cache entries
#' @param max_age Maximum cache lifetime (seconds)
#'
bind_cache_with_strategy <- function(reactive_expr, cache_key_fn,
                                   max_size = 100, max_age = 3600) {

  if (requireNamespace("shiny", quietly = TRUE) &&
      exists("bindCache", envir = asNamespace("shiny"))) {

    reactive_expr %>%
      shiny::bindCache(cache_key_fn()) %>%
      shiny::bindCache(
        cache = cachem::cache_mem(
          max_size = max_size,
          max_age = max_age
        )
      )
  } else {
    # If bindCache is not available, return original reactive
    reactive_expr
  }
}

#' Disk cache manager
#'
#' @param cache_dir Cache directory
create_disk_cache_manager <- function(cache_dir = "cache") {

  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE)
  }

  list(
    # Save to disk cache
    save = function(key, data, subdir = NULL) {
      full_dir <- if (is.null(subdir)) cache_dir else file.path(cache_dir, subdir)
      if (!dir.exists(full_dir)) dir.create(full_dir, recursive = TRUE)

      file_path <- file.path(full_dir, paste0(key, ".qs"))

      tryCatch({
        qs::qsave(data, file_path)
        message("Saved to disk cache: ", file_path)
        return(TRUE)
      }, error = function(e) {
        warning("Failed to save to disk cache: ", conditionMessage(e))
        return(FALSE)
      })
    },

    # Load from disk cache
    load = function(key, subdir = NULL) {
      full_dir <- if (is.null(subdir)) cache_dir else file.path(cache_dir, subdir)
      file_path <- file.path(full_dir, paste0(key, ".qs"))

      if (file.exists(file_path)) {
        tryCatch({
          data <- qs::qread(file_path)
          message("Loaded from disk cache: ", file_path)
          return(data)
        }, error = function(e) {
          warning("Failed to load from disk cache: ", conditionMessage(e))
          return(NULL)
        })
      } else {
        return(NULL)
      }
    },

    # Check if cache exists
    exists = function(key, subdir = NULL) {
      full_dir <- if (is.null(subdir)) cache_dir else file.path(cache_dir, subdir)
      file_path <- file.path(full_dir, paste0(key, ".qs"))
      file.exists(file_path)
    },

    # Clean up expired cache
    cleanup = function(max_age_days = 7, subdir = NULL) {
      full_dir <- if (is.null(subdir)) cache_dir else file.path(cache_dir, subdir)

      if (!dir.exists(full_dir)) return(0)

      files <- list.files(full_dir, pattern = "\\.qs$", full.names = TRUE)
      cutoff_time <- Sys.time() - (max_age_days * 24 * 3600)

      removed_count <- 0
      for (file in files) {
        if (file.mtime(file) < cutoff_time) {
          unlink(file)
          removed_count <- removed_count + 1
        }
      }

      message("Cleaned up ", removed_count, " old cache files")
      return(removed_count)
    },

    # Get cache statistics
    stats = function(subdir = NULL) {
      full_dir <- if (is.null(subdir)) cache_dir else file.path(cache_dir, subdir)

      if (!dir.exists(full_dir)) {
        return(list(files = 0, total_size_mb = 0))
      }

      files <- list.files(full_dir, pattern = "\\.qs$", full.names = TRUE)
      total_size <- sum(file.size(files), na.rm = TRUE)

      list(
        files = length(files),
        total_size_mb = total_size / 1024^2,
        oldest_file = if(length(files) > 0) min(file.mtime(files)) else NULL,
        newest_file = if(length(files) > 0) max(file.mtime(files)) else NULL
      )
    }
  )
}

#' Wrapper function for memoise, used for function result caching
#'
#' @param fn Function to cache
#' @param cache_dir Disk cache directory (optional)
#' @param max_size Maximum number of memory cache entries
#'
create_memoised_function <- function(fn, cache_dir = NULL, max_size = 100) {

  if (!requireNamespace("memoise", quietly = TRUE)) {
    warning("memoise package not available, returning original function")
    return(fn)
  }

  if (is.null(cache_dir)) {
    # Memory cache only
    cache <- cachem::cache_mem(max_size = max_size)
  } else {
    # Disk cache
    if (!dir.exists(cache_dir)) dir.create(cache_dir, recursive = TRUE)
    cache <- cachem::cache_disk(cache_dir, max_size = max_size)
  }

  memoise::memoise(fn, cache = cache)
}

#' Create smart cache for data loading
#'
#' @param load_fn Original loading function
#' @param cache_key_fn Function to generate cache key
#' @param use_disk_cache Whether to use disk cache
#' @param cache_subdir Disk cache subdirectory
#'
create_cached_loader <- function(load_fn, cache_key_fn,
                                use_disk_cache = TRUE, cache_subdir = "data_cache") {

  disk_cache <- if (use_disk_cache) create_disk_cache_manager() else NULL

  function(path, ...) {
    # Generate cache key
    cache_key <- cache_key_fn(path, ...)

    # Try to load from disk cache
    if (!is.null(disk_cache)) {
      cached_data <- disk_cache$load(cache_key, cache_subdir)
      if (!is.null(cached_data)) {
        return(cached_data)
      }
    }

    # Load original data
    data <- load_fn(path, ...)

    # Save to disk cache
    if (!is.null(disk_cache)) {
      disk_cache$save(cache_key, data, cache_subdir)
    }

    return(data)
  }
}
