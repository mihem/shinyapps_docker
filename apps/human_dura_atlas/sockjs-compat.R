# Shiny Server's SockJS transport cannot preserve raw WebSocket binary frames.
# Use a JSON/base64 envelope only at the deployment boundary. The browser
# restores Shiny's original binary frame before its normal handler sees it.
cerebroSockjsUi <- function(ui) {
  shiny::tagList(shiny::tags$head(shiny::includeScript('sockjs-compat.js')),ui)
}
cerebroSockjsServer <- function(original) {
  force(original)
  function(input,output,session) {
    was_locked <- bindingIsLocked('sendBinaryMessage',session)
    if(was_locked) unlockBinding('sendBinaryMessage',session)
    session$sendBinaryMessage <- function(type,message) {
      stopifnot(is.character(type),length(type)==1L,is.raw(message))
      session$sendCustomMessage('cerebro_sockjs_binary',list(
        type=type, data=base64enc::base64encode(message)
      ))
    }
    if(was_locked) lockBinding('sendBinaryMessage',session)
    original(input,output,session)
  }
}
