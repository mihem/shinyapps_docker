// 小兔子行走动画逻辑
document.addEventListener('DOMContentLoaded', function() {
  // 只在登录页面显示兔子
  if (!document.querySelector('.panel-auth')) return;

  // 创建兔子元素
  const bunnyContainer = document.createElement('div');
  bunnyContainer.className = 'bunny-container';

  const bunny = document.createElement('div');
  bunny.className = 'bunny';

  const footprints = document.createElement('div');
  footprints.className = 'footprints';

  bunnyContainer.appendChild(bunny);
  bunnyContainer.appendChild(footprints);

  // 创建草地
  const grass = document.createElement('div');
  grass.className = 'grass';

  // 创建消息气泡
  const message = document.createElement('div');
  message.className = 'message';
  message.id = 'bunny-message';
  message.textContent = '你好！我能帮你登录吗？';

  // 添加到body
  document.body.appendChild(bunnyContainer);
  document.body.appendChild(grass);
  document.body.appendChild(message);

  // 初始位置
  let posX = 150;
  let posY = 100;
  let direction = 1; // 1 表示向右，-1 表示向左

  // 随机移动兔子
  function moveBunny() {
    // 随机决定移动方向（0-360度）
    const angle = Math.random() * Math.PI * 2;

    // 计算新位置
    const distance = 50 + Math.random() * 100;
    let newX = posX + Math.cos(angle) * distance;
    let newY = posY + Math.sin(angle) * distance;

    // 边界检查
    newX = Math.max(50, Math.min(window.innerWidth - 150, newX));
    newY = Math.max(80, Math.min(window.innerHeight - 200, newY));

    // 更新方向
    direction = (newX > posX) ? 1 : -1;
    bunnyContainer.style.transform = `translate(${newX}px, ${newY}px) scaleX(${direction})`;

    // 创建脚印
    createFootprint();

    // 偶尔显示消息
    if (Math.random() > 0.8) {
      showMessage();
    }

    // 更新位置
    posX = newX;
    posY = newY;

    // 设置下一次移动
    setTimeout(moveBunny, 2000 + Math.random() * 4000);
  }

  // 创建脚印
  function createFootprint() {
    const footprint = document.createElement('div');
    footprint.innerHTML = '🐾';
    footprint.classList.add('footprint');

    // 位置偏移
    const offsetX = (direction > 0) ? -25 : 25;
    footprint.style.left = `${offsetX}px`;

    footprints.appendChild(footprint);

    // 清除旧脚印
    setTimeout(() => {
      footprint.remove();
    }, 2000);
  }

  // 显示消息
  function showMessage() {
    const messages = [
      "你好！需要帮助登录吗？",
      "今天真是美好的一天！",
      "你的密码安全吗？",
      "不要忘记定期更改密码！",
      "让我带你参观系统吧！",
      "安全第一！",
      "探索数据的世界..."
    ];

    message.textContent = messages[Math.floor(Math.random() * messages.length)];
    message.style.opacity = "1";

    setTimeout(() => {
      message.style.opacity = "0";
    }, 3000);
  }

  // 开始移动
  setTimeout(moveBunny, 1000);

  // 让兔子跟随鼠标
  document.addEventListener('mousemove', function(e) {
    const distX = e.clientX - posX;
    const distY = e.clientY - posY;
    const distance = Math.sqrt(distX * distX + distY * distY);

    if (distance < 200) {
      // 兔子看向鼠标
      const newDirection = (distX > 0) ? 1 : -1;

      if (newDirection !== direction) {
        direction = newDirection;
        bunnyContainer.style.transform = `translate(${posX}px, ${posY}px) scaleX(${direction})`;
      }
    }
  });
});
