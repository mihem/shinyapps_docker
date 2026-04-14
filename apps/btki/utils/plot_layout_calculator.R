# ============================================================================
# Plot Layout Calculator
# For calculating optimal row/column layout and dimensions for multi-panel plots
# ============================================================================

#' Calculate optimal layout for multi-panel plots
#'
#' @param n_plots Number of plots
#' @param available_width Available width (pixels)
#' @param available_height Available height (pixels)
#' @param min_size Minimum size for a single plot (pixels), default 350
#' @param aspect_ratio Aspect ratio, default 1 (square)
#' @param gap Gap between plots (pixels), default 10
#'
#' @return List containing:
#'   - ncol: Number of columns
#'   - nrow: Number of rows
#'   - plot_width: Width of a single plot
#'   - plot_height: Height of a single plot
#'   - total_height: Total height
#'   - is_feasible: Whether it's feasible (TRUE/FALSE)
#'   - strategy: Recommended strategy
#'   - min_required_height: Minimum required height if not feasible
#'
calculate_plot_layout <- function(n_plots,
                                  available_width,
                                  available_height,
                                  min_size = 350,
                                  aspect_ratio = 1,
                                  gap = 0) {

  # 输入验证
  if (n_plots <= 0) {
    stop("n_plots must be positive")
  }
  if (available_width <= 0 || available_height <= 0) {
    stop("Available dimensions must be positive")
  }

  print(sprintf("Calculate layout: %d plots, available space %.0f x %.0f px", n_plots, available_width, available_height))

  # Special case: only 1 plot
  if (n_plots == 1) {
    plot_size <- min(available_width, available_height)

    print(sprintf("Single plot available size: %.0f x %.0f px", plot_size, plot_size))

    if (plot_size < min_size) {
      return(list(
        ncol = 1,
        nrow = 1,
        plot_width = min_size,
        plot_height = min_size,
        total_height = min_size,
        umap_size = min_size,
        is_feasible = FALSE,
        strategy = "increase_height",
        min_required_height = min_size,
        message = sprintf("Requires at least %dpx height, current only %.0fpx", min_size, available_height)
      ))
    }

    return(list(
      ncol = 1,
      nrow = 1,
      plot_width = plot_size,
      plot_height = plot_size,
      total_height = plot_size,
      umap_size = plot_size,
      is_feasible = TRUE,
      strategy = "single_plot",
      message = sprintf("Single plot layout: %.0f x %.0f px", plot_size, plot_size)
    ))
  }

  # Multiple plots: try all possible row/column combinations
  best_layout <- NULL
  max_plot_size <- 0

  # Try different number of columns (from 1 to n_plots)
  for (ncol in 1:n_plots) {
    nrow <- ceiling(n_plots / ncol)

    # Calculate available width and height for each plot
    plot_width <- (available_width - (ncol - 1) * gap) / ncol
    plot_height <- (available_height - (nrow - 1) * gap) / nrow

    # Maintain aspect ratio (square)
    plot_size <- min(plot_width, plot_height)

    print(sprintf("Try layout: %d cols x %d rows, each plot %.0f x %.0f px", ncol, nrow, plot_size, plot_size))

    # Record the maximum feasible size
    if (plot_size > max_plot_size) {
      max_plot_size <- plot_size
      best_layout <- list(
        ncol = ncol,
        nrow = nrow,
        plot_width = plot_size,
        plot_height = plot_size,
        umap_size = plot_size,
        total_height = nrow * plot_size + (nrow - 1) * gap
      )
    }
  }

  # Check if best layout meets minimum size requirement
  if (max_plot_size >= min_size) {
    best_layout$is_feasible <- TRUE
    best_layout$strategy <- "grid_layout"
    best_layout$message <- sprintf(
      "Grid layout: %d rows × %d cols, each plot %.0f x %.0f px",
      best_layout$nrow, best_layout$ncol,
      best_layout$plot_width, best_layout$plot_height
    )
    return(best_layout)
  }

  print(sprintf("Best layout size insufficient: %.0fpx (minimum required %dpx)", max_plot_size, min_size))

  # If all layouts don't meet min_size, calculate minimum required height
  # Strategy: prefer 2-3 column layouts (most common)
  preferred_ncol <- min(3, ceiling(sqrt(n_plots)))
  nrow_needed    <- ceiling(n_plots / preferred_ncol)
  preferred_size <- (available_width - (preferred_ncol - 1) * gap) / preferred_ncol

  print(sprintf("Recommended layout: %d cols x %d rows, each plot max %.0f px", preferred_ncol, nrow_needed, preferred_size))

  # Calculate total height required to guarantee min_size per plot
  min_required_height <- nrow_needed * preferred_size + (nrow_needed - 1) * gap

  # Provide multiple strategies
  strategies <- list()

  # Strategy 1: Increase height
  strategies$increase_height <- list(
    ncol = preferred_ncol,
    nrow = nrow_needed,
    plot_width = min_size,
    plot_height = min_size,
    total_height = min_required_height,
    umap_size = preferred_size,
    message = sprintf("Increase container height to %.0fpx (current %.0fpx)",
                      min_required_height, available_height)
  )

  # Strategy 2: Pagination
  plots_per_page <- floor(available_height / (min_size + gap)) * preferred_ncol
  if (plots_per_page < 1) plots_per_page <- 1
  n_pages <- ceiling(n_plots / plots_per_page)

  strategies$pagination <- list(
    plots_per_page = plots_per_page,
    n_pages = n_pages,
    message = sprintf("Display in %d pages, %d plots per page", n_pages, plots_per_page)
  )

  # Strategy 3: Accept smaller size (fallback)
  strategies$accept_smaller <- list(
    ncol = best_layout$ncol,
    nrow = best_layout$nrow,
    plot_width = best_layout$plot_width,
    plot_height = best_layout$plot_height,
    total_height = best_layout$total_height,
    umap_size = min_size,
    message = sprintf("Accept smaller size %.0f x %.0f px (minimum required %d px)",
                      best_layout$plot_width,
                      best_layout$plot_height,
                      min_size)
  )

  # Return recommended strategy (default: increase height)
  result <- strategies$increase_height
  result$is_feasible <- FALSE
  result$strategy <- "increase_height"
  result$min_required_height <- min_required_height
  result$alternative_strategies <- strategies
  result$warning <- sprintf(
    "Current available height insufficient! Requires %.0fpx, current %.0fpx. Options:\n1. Increase height\n2. Pagination\n3. Use scrollbar\n4. Accept smaller size",
    min_required_height, available_height
  )

  return(result)
}


#' Simplified version: only return necessary layout parameters (for Shiny)
#'
#' @param n_plots Number of plots
#' @param window_width Window width
#' @param window_height Window height
#' @param sidebar_width Sidebar width, default 250
#' @param header_height Header height, default 90
#' @param min_size Minimum size, default 350
#'
#' @return List containing ncol, nrow, plot_height, total_height, message
#'
get_umap_layout <- function(n_plots,
                           window_width,
                           window_height,
                           sidebar_width = 250,
                           header_height = 90,
                           min_size = 350) {

  # Call main function
  layout <- calculate_plot_layout(
    n_plots = n_plots,
    available_width = window_width,
    available_height = window_height,
    min_size = min_size,
    aspect_ratio = 1,
    gap = 0
  )

  # # If not feasible, use scrollbar strategy
  # if (!layout$is_feasible) {
  #   cat("===> [Layout Warning]", layout$message, "\n")
  #   cat("===> [Layout Strategy] Use scrollbar\n")

  #   # Use scrollbar strategy
  #   scroll_layout <- layout$alternative_strategies$scrollable

  #   return(list(
  #     ncol = scroll_layout$ncol,
  #     nrow = scroll_layout$nrow,
  #     plot_height = scroll_layout$total_height,
  #     total_height = scroll_layout$total_height,
  #     is_feasible = FALSE,
  #     use_scroll = TRUE,
  #     message = scroll_layout$message
  #   ))
  # }

  # Feasible solution
  cat("===> [Layout Info]", layout$message, "\n")

  return(list(
    ncol = layout$ncol,
    nrow = layout$nrow,
    plot_height = layout$total_height,
    total_height = layout$total_height,
    umap_size = layout$umap_size,
    is_feasible = TRUE,
    use_scroll = FALSE,
    message = layout$message
  ))
}
