# Simple session timeout handler

timeout_handler <- function(input, output, session) {

  # Store notification ID
  notification_id <- reactiveVal(NULL)

  # Display timeout warning (shown once, frontend updates countdown itself)
  observeEvent(input$session_timeout_warning, {
    msg_data <- input$session_timeout_warning

    # Create notification only on first display
    if (isTRUE(msg_data$show)) {
      # Remove previous notification (if any)
      if (!is.null(notification_id())) {
        removeNotification(notification_id())
      }

      # Display new notification (initial message, frontend will auto-update)
      minutes <- floor(msg_data$remaining / 60)
      seconds <- msg_data$remaining %% 60
      initial_message <- sprintf(
        "Due to inactivity, the system will automatically disconnect and clean up memory in %dmin %ds. Click anywhere to continue using.",
        minutes, seconds
      )

      id <- showNotification(
        initial_message,
        duration = NULL,  # Does not auto-dismiss
        closeButton = FALSE,
        type = "warning",
        session = session
      )

      notification_id(id)
    }
  })

  # Cancel warning
  observeEvent(input$session_timeout_cancel, {
    if (!is.null(notification_id())) {
      removeNotification(notification_id())
      notification_id(NULL)
    }
  })

  # Timeout disconnect
  observeEvent(input$session_timeout_disconnect, {
    cat("Session timeout - Cleaning up and disconnecting...\n")

    # Remove notification
    if (!is.null(notification_id())) {
      removeNotification(notification_id())
    }

    # Display final notification
    showNotification(
      "Session has timed out, disconnecting...",
      duration = 3,
      type = "error",
      session = session
    )

    # Clean up memory
    gc()

    # Delay disconnect to let user see message
    later::later(function() {
      session$close()
    }, 2)
  })
}
