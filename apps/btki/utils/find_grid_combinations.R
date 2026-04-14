#' Find suitable multi-plot grid layout (row/column combinations)
#'
#' @description
#' For a given total number of plots (`plot_num`), under the constraints of screen dimensions (`screen_w`, `screen_h`)
#' and minimum plot size (`plot_size_min`), calculate a series of feasible grid layout options.
#' Sort candidates based on:
#' 1. Maximum available size for single plot (`size_max`, determined by the minimum of height and width constraints)
#' 2. Closeness of layout aspect ratio to screen aspect ratio (`ratio_diff`)
#'
#' If no layout can "fit on one page" while meeting minimum size requirements, attempt to reduce columns, increase rows,
#' and calculate required additional screen height (expansion height solutions `expansions`).
#'
#' @param plot_num integer. Number of plots to display (>=1).
#' @param screen_w numeric. Screen width (pixels), default 1920.
#' @param screen_h numeric. Screen height (pixels), default 1080.
#' @param plot_size_min numeric. Minimum required edge length for single plot (pixels, assuming approximately square), default 350.
#' @param prefer "size" or "ratio". Priority sorting strategy when multiple qualifying options exist:
#'   - "size": Prioritize larger single plot size
#'   - "ratio": Prioritize aspect ratio closer to screen
#' @param return_all_logical logical. Whether to return all layouts (including those not meeting minimum size). Default TRUE.
#'
#' @return A list:
#' \describe{
#'   \item{layouts}{data.frame. Candidate layouts and metrics.}
#'   \item{best}{data.frame (1 row or 0 rows). Preferred solution (if one-page solution meeting conditions exists).}
#'   \item{expansions}{data.frame. When minimum size cannot be met, calculated expansion solutions requiring increased height; empty if solution exists.}
#'   \item{params}{list. Input parameters echo.}
#'   \item{message}{character. Result description.}
#' }
#'
#' @details
#' Strategy for generating candidate layouts:
#' - Iterate nrow = 1..ceiling(sqrt(plot_num))
#' - Corresponding required ncol = ceiling(plot_num / nrow)
#' - To ensure symmetry and complete potential better solutions, also add (ncol, nrow) combinations
#' - Deduplicate and calculate metrics
#'
#' `size_max` represents the maximum (approximately square) edge length achievable for a single plot
#' in this layout without exceeding screen dimensions:
#'   size_max = min( floor(screen_h / nrow), floor(screen_w / ncol) )
#'
#' If all `size_max < plot_size_min`, attempt expansion:
#' - Use the first few layouts with the closest screen aspect ratio as inspiration (current implementation uses only the first optimal ratio_diff layout)
#' - Gradually reduce columns (at least 1), recalculate minimum rows needed to accommodate all plots
#' - Calculate new single plot size from width constraint, then infer required new screen height from row count
#'
#' @examples
#' # Basic usage
#' res <- find_grid_combinations(
#'   plot_num = 17,
#'   screen_w = 1920,
#'   screen_h = 1080,
#'   plot_size_min = 300
#' )
#' res$best
#'
#' # To view expansion solutions:
#' res$expansions
#'
#' @export
find_grid_combinations1 <- function(
    plot_num,
    screen_w = 1920,
    screen_h = 1080,
    plot_size_min = 350,
    prefer = c("size", "ratio"),
    return_all_logical = TRUE
) {
  # -------- Parameter validation --------
  stopifnot(
    length(plot_num) == 1L,
    is.numeric(plot_num),
    plot_num >= 1,
    is.numeric(screen_w), screen_w > 0,
    is.numeric(screen_h), screen_h > 0,
    is.numeric(plot_size_min), plot_size_min > 0
  )
  prefer <- match.arg(prefer)

  # -------- Generate candidate (row, column) combinations --------
  max_nrow <- ceiling(sqrt(plot_num))
  base <- lapply(1:max_nrow, function(nr) {
    nc <- ceiling(plot_num / nr)
    list(
      c(nrow = nr, ncol = nc),
      c(nrow = nc, ncol = nr) # Symmetric combination
    )
  })
  combos <- do.call(rbind, unlist(base, recursive = FALSE))
  combos <- unique(combos)               # Deduplicate
  combos <- combos[order(combos[, "nrow"], combos[, "ncol"]), , drop = FALSE]

  # -------- Calculate metrics --------
  aspect_screen <- screen_w / screen_h

  layouts <- within(as.data.frame(combos), {
    size_by_h <- floor(screen_h / nrow)
    size_by_w <- floor(screen_w / ncol)
    size_max  <- pmin(size_by_h, size_by_w)
    one_page  <- size_max >= plot_size_min
    theoretical_aspect_ratio <- ncol / nrow
    ratio_diff <- abs(theoretical_aspect_ratio - aspect_screen)
  })

  # -------- Sorting strategy --------
  # First by ratio_diff, then by size_max, then by total cells wasted (closer to plot_num is better)
  # Finally by row count (more compact) & column count
  layouts$total_slots <- with(layouts, nrow * ncol)
  layouts$unused_slots <- layouts$total_slots - plot_num
  # Basic sort (ratio closer + larger single plot + fewer unused cells + fewer rows + fewer columns)
  layouts <- layouts[order(
    layouts$ratio_diff,
    -layouts$size_max,
    layouts$unused_slots,
    layouts$nrow,
    layouts$ncol
  ), ]

  # If user specified prefer = "size", prioritize size_max, then ratio
  if (prefer == "size") {
    layouts <- layouts[order(
      -layouts$size_max,
      layouts$ratio_diff,
      layouts$unused_slots,
      layouts$nrow,
      layouts$ncol
    ), ]
  }

  # -------- Select preferred solution --------
  best <- layouts[layouts$one_page, ]
  if (nrow(best) > 0L) {
    best <- best[1, , drop = FALSE]
    message_txt <- sprintf(
      "Found one-page solution meeting minimum size: %dx%d, max single plot edge length %d pixels.",
      best$nrow, best$ncol, best$size_max
    )
    expansions <- empty_expansions_df()
  } else {
    message_txt <- "No solution meets minimum plot size requirement under current screen height constraint, will attempt to generate expanded height solutions."
    # -------- Generate expansion solutions --------
    # Select first layout with optimal ratio_diff as baseline
    seed <- layouts[order(layouts$ratio_diff), ][1, ]
    expansions <- enumerate_height_expansions(
      seed_layout = seed,
      plot_num = plot_num,
      screen_w = screen_w,
      plot_size_min = plot_size_min
    )
    best <- layouts[1, , drop = FALSE]  # Although not meeting one_page, still provide "theoretical first in sort"
  }

  # -------- Optional: do not return layouts not meeting minimum size --------
  if (!return_all_logical) {
    layouts <- layouts[layouts$one_page, ]
  }

  # -------- Return --------
  list(
    layouts = layouts,
    best    = best,
    expansions = expansions,
    params  = list(
      plot_num = plot_num,
      screen_w = screen_w,
      screen_h = screen_h,
      plot_size_min = plot_size_min,
      prefer = prefer
    ),
    message = message_txt
  )
}

# Empty expansion result template
empty_expansions_df <- function() {
  data.frame(
    nrow_new = integer(),
    ncol_new = integer(),
    total_slots = integer(),
    unused_slots = integer(),
    plot_size = numeric(),
    required_screen_h = numeric(),
    stringsAsFactors = FALSE
  )
}

# Expansion height strategy:
# Reduce columns (at least by 1), and recalculate minimum rows needed to accommodate plot_num;
# Single plot size uses width constraint: plot_size = floor(screen_w / ncol_new)
# If plot_size >= plot_size_min, then required height = plot_size * nrow_new
enumerate_height_expansions <- function(seed_layout,
                                       plot_num,
                                       screen_w,
                                       plot_size_min) {
  ncol_seed <- seed_layout$ncol
  out <- empty_expansions_df()
  if (ncol_seed <= 1) {
    return(out)
  }
  for (ncol_new in seq.int(ncol_seed - 1, 1, by = -1)) {
    nrow_new <- ceiling(plot_num / ncol_new)
    plot_size <- floor(screen_w / ncol_new)
    if (plot_size < plot_size_min) {
      # Size still not meeting requirement after reducing columns, continue reducing
      next
    }
    required_screen_h <- plot_size * nrow_new
    total_slots <- nrow_new * ncol_new
    unused_slots <- total_slots - plot_num
    out <- rbind(out, data.frame(
      nrow_new = nrow_new,
      ncol_new = ncol_new,
      total_slots = total_slots,
      unused_slots = unused_slots,
      plot_size = plot_size,
      required_screen_h = required_screen_h,
      stringsAsFactors = FALSE
    ))
  }
  # Sort: prioritize larger plot_size, fewer unused_slots, smaller required height, more columns
  if (nrow(out) > 0L) {
    out <- out[order(
      -out$plot_size,
      out$unused_slots,
      out$required_screen_h,
      -out$ncol_new
    ), ]
  }
  out
}

# # res <- find_grid_combinations(23, screen_w = 2560, screen_h = 1440, plot_size_min = 320)
# # res$message
# # res$best
# # head(res$layouts)
# # res$expansions


# # 函数说明摘要
#
# `find_grid_combinations()` 用于在限定屏幕宽高与单个图最小尺寸条件下，为要展示的 `plot_num` 个图表寻找合适的网格排布（行×列），并根据：
# 1. 单图可达到的最大尺寸（size_max）
# 2. 网格理论宽高比与屏幕宽高比的接近程度（ratio_diff）
#
# 来排序候选方案。如果所有在当前屏幕高度内的方案都不能满足最小尺寸要求，则进一步给出“需要增加屏幕高度”的扩展方案（expansions）。
#
# 返回值为一个列表：
# - `layouts`：所有候选布局及其度量
# - `best`：首选布局（满足最小尺寸的情况下）
# - `expansions`：如果现有屏幕高度不足，给出可行的(增加高度后)方案
# - `params`：传入参数回显

find_grid_combinations <- function(plot_num, screen_w=1920, screen_h=1080, plot_size_min=200) {

  # 初始化结果列表
  combinations <- list()

  # 最大可能的行数不会超过sqrt(plot_num)的上界
  max_nrow <- ceiling(sqrt(plot_num))

  for (nrow in 1:max_nrow) {
    # Calculate minimum required columns
    ncol <- ceiling(plot_num / nrow)

    # Add symmetric combination (ncol, nrow), if different
    if (nrow != ncol && nrow < ncol) {
      combinations[[length(combinations) + 1]] <- c(nrow = nrow, ncol = ncol)
    }
    combinations[[length(combinations) + 1]] <- c(nrow = ncol, ncol = nrow)
  }

  # Remove duplicate combinations (when nrow=ncol)
  combinations <- unique(do.call(rbind, combinations))

  # Sort by row count
  combinations <- combinations[order(combinations[, "nrow"]), , drop = FALSE]
  combinations <- as.data.frame(combinations)

  # Calculate plot_size for current combination
  combinations$plot_size  <- floor(screen_w / combinations$ncol / 10) * 10

  # Sort by size_max in descending order (prioritize larger display units)
  combinations <- combinations[order(-combinations[, "plot_size"]), , drop = FALSE]

  combinations$actuall_w <- combinations$plot_size * combinations$ncol
  combinations$actuall_h <- combinations$plot_size * combinations$nrow

  # Check if minimum size requirement is met
  combinations$too_small <- combinations$plot_size < plot_size_min

  # Check if can display on one page when meeting minimum plot size
  combinations$one_page <- combinations$plot_size >= plot_size_min & combinations$actuall_h <= screen_h

  combinations[, "visible_w"] <- screen_w
  combinations[, "visible_h"] <- screen_h

  # combinations <- within(combinations, {
  #   plot_size <- ifelse(ncol == 1, visible_h, plot_size)
  #   actuall_h <- ifelse(ncol == 1, visible_h, actuall_h)
  #   # Keep original value for actuall_h
  # })



  combinations[combinations$ncol == 1, "plot_size"] <- screen_h
  combinations[combinations$ncol == 1, "actuall_h"] <- screen_h * combinations[combinations$ncol == 1, "nrow"]
  combinations[combinations$nrow == 1, "actuall_h"] <- screen_h

  combinations <- combinations %>%
    arrange(too_small, desc(one_page), nrow)



  combinations
}

# find_grid_combinations <- find_grid_combinations(1, screen_w = 865, screen_h = 667, plot_size_min = 200)

# find_grid_combinations
# # all(find_grid_combinations$one_page)
