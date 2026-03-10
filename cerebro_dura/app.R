#==============================================================================
# Cerebro Shiny App - 静态登录页优化版
# 用户打开页面立即显示静态登录表单，Shiny 在后台加载
# 登录验证通过后无缝切换到主应用，无需跳转
#==============================================================================

library(dplyr)
library(DT)
library(plotly)
library(shiny)
library(shinydashboard)
library(shinyWidgets)



# 定义结果保存目录
cerebro_root <- "."

## 加载配置
if (file.exists("cerebro_config.rds")) {
  Cerebro.options <<- readRDS("cerebro_config.rds")
} else {
  stop("cerebro_config.rds not found!")
}

# 兼容旧代码：如果有 colors 选项，设置为全局变量
if (!is.null(Cerebro.options$colors)) {
  colors <- Cerebro.options$colors
}

shiny_options <- list(
  maxRequestSize = 10000 * 1024^2,
  port = 3838,
  host = "127.0.0.1",
  launch.browser = TRUE,
  quiet = FALSE,
  display.mode = "normal"
)

## Expose data directory for spatial images
shiny::addResourcePath("data", file.path(cerebro_root, "data"))

## 加载服务器和界面函数
source(file.path(cerebro_root, "shiny/shiny_UI.R"))
source(file.path(cerebro_root, "shiny/shiny_server.R"))

# Authentication setup
library(shinymanager)

credentials_path <- file.path(cerebro_root, "credentials.sqlite")
auth_passphrase <- "123123"

# Check if credentials database exists
if (!file.exists(credentials_path)) {
  stop("Credentials database not found: ", credentials_path)
}

# Initialize credentials check
check_credentials <- shinymanager::check_credentials(
  credentials_path,
  passphrase = auth_passphrase
)

## Start Shiny App
# Wrap UI with secure_app
secure_ui <- shinymanager::secure_app(ui)
shiny::shinyApp(
  ui = secure_ui,
  server = function(input, output, session) {
  res_auth <- shinymanager::secure_server(check_credentials = check_credentials)
  server(input, output, session)
},
  options = shiny_options
)
