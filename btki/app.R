# ============================================================================
# Main Application Entry Point (Refactored)
# ============================================================================

# Load global configuration and functions
source("utils/global.R")
source("utils/utils.R")
source("utils/find_grid_combinations.R")

# Enable auto-reload feature (development mode)
options(shiny.autoreload = TRUE)
options(width = as.integer(Sys.getenv("COLUMNS", 200)))

# Load new refactored architecture
source("R/run_app.R")

# Set port
port <- 3838

# Run application
# Development mode: with debug information
# run_app_dev_verbose(port = port)

# # Development mode: without debug information
# run_app_dev_no_auth(port = port)  # Skip authentication for easier debugging

# Production mode:
run_app_production(port = port, host = "0.0.0.0")
