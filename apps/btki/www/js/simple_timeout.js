// 简单的会话超时管理
// 30分钟无操作后弹出倒计时通知

(function() {
  var IDLE_TIMEOUT = 0.5 * 60 * 1000;  // 30秒钟无操作
  var COUNTDOWN_TIME = 2 * 60 * 1000; // 2分钟倒计时

  var idleTimer = null;
  var countdownTimer = null;
  var countdownInterval = null;
  var remainingSeconds = 0;
  var notificationElement = null;  // 保存通知元素引用

  // 重置空闲计时器
  function resetIdleTimer() {
    // 如果已经在倒计时，不重置
    if (countdownTimer) return;

    clearTimeout(idleTimer);
    idleTimer = setTimeout(showWarning, IDLE_TIMEOUT);
  }

  // 显示警告通知
  function showWarning() {
    remainingSeconds = Math.floor(COUNTDOWN_TIME / 1000);

    // 只通知服务器一次，显示通知
    Shiny.setInputValue('session_timeout_warning', {
      remaining: remainingSeconds,
      show: true
    }, {priority: 'event'});

    // 等待通知元素被创建
    setTimeout(function() {
      findNotificationElement();
      startCountdown();
    }, 100);
  }

  // 查找通知元素
  function findNotificationElement() {
    // 查找最新的警告通知
    var notifications = $('.shiny-notification-warning');
    if (notifications.length > 0) {
      notificationElement = notifications.last();
    }
  }

  // 开始倒计时
  function startCountdown() {
    updateNotificationText();
    countdownInterval = setInterval(function() {
      remainingSeconds--;
      if (remainingSeconds <= 0) {
        clearInterval(countdownInterval);
        disconnect();
      } else {
        updateNotificationText();
      }
    }, 1000);

    // 设置最终断开连接的计时器
    countdownTimer = setTimeout(disconnect, COUNTDOWN_TIME);
  }

  // 更新通知文本（仅前端DOM操作，不触发服务器）
  function updateNotificationText() {
    var minutes = Math.floor(remainingSeconds / 60);
    var seconds = remainingSeconds % 60;
    var timeStr = minutes + 'min ' + seconds + 's';
    var message = 'Due to inactivity, the system will automatically disconnect and clean up memory in ' + timeStr + '. Click anywhere to continue using.';

    // 直接更新DOM，避免闪烁
    if (notificationElement && notificationElement.length > 0) {
      notificationElement.find('.shiny-notification-content').text(message);
    }
  }

  // 断开连接
  function disconnect() {
    clearInterval(countdownInterval);
    Shiny.setInputValue('session_timeout_disconnect', true, {priority: 'event'});
  }

  // 用户活动，取消倒计时
  function cancelWarning() {
    if (countdownTimer) {
      clearTimeout(countdownTimer);
      clearInterval(countdownInterval);
      countdownTimer = null;
      countdownInterval = null;
      notificationElement = null;  // 清空引用

      // 通知服务器取消警告
      Shiny.setInputValue('session_timeout_cancel', true, {priority: 'event'});

      // 重新开始空闲计时
      resetIdleTimer();
    }
  }

  // 监听用户活动
  $(document).on('mousemove keydown click scroll touchstart', function() {
    if (countdownTimer) {
      cancelWarning();
    } else {
      resetIdleTimer();
    }
  });

  // 页面加载完成后启动
  $(document).on('shiny:connected', function() {
    console.log('Session timeout manager initialized: 30 seconds idle, 2 mins countdown');
    resetIdleTimer();
  });
})();
