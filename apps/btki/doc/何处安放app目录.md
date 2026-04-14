方案 A：软链接 + 最小 ACL 授权（简单直观）

1. 给 shiny 用户授予对应用目录的只读/遍历权限（不改变 owner）

- 如未安装 ACL 工具：sudo apt-get install -y acl
- 授权应用目录及其新创建文件： sudo setfacl -R -m u:shiny:rx /home/wang/shiny_apps/mzh-lab sudo setfacl -R -d -m u:shiny:rx /home/wang/shiny_apps/mzh-lab
- 如果你的 /home、/home/wang 或 /home/wang/shiny_apps 是 700，需要给最小遍历权限（仅 x）： sudo setfacl -m u:shiny:--x /home sudo setfacl -m u:shiny:--x /home/wang sudo setfacl -m u:shiny:--x /home/wang/shiny_apps

2. 在 /srv/shiny-server 下创建链接

- 建议将链接名与应用名一致，便于访问：[http://server:3838/mzh-lab](http://server:3838/mzh-lab) sudo ln -s /home/wang/shiny_apps/mzh-lab /srv/shiny-server/mzh-lab

3. 验证

- 以 shiny 身份确认可读： sudo -u shiny -H bash -lc 'ls -l /srv/shiny-server/mzh-lab && (test -r /srv/shiny-server/mzh-lab/app.R || (test -r /srv/shiny-server/mzh-lab/ui.R && test -r /srv/shiny-server/mzh-lab/server.R)) && echo OK'
- 如需重载服务（通常不必）：sudo systemctl reload shiny-server

方案 B：bind 挂载到 /srv/shiny-server（不改家目录父路径权限，推荐给权限要求更严的环境） 说明：shiny 只会通过 /srv/shiny-server/mzh-lab 访问，不需要穿越 /home 路径；你只需保证应用目录本身对 shiny 可读。可选地把挂载点设为只读，进一步防止服务进程写入代码目录。

1. 先确保 shiny 对应用目录有读权限（不必给父目录权限）


- 同方案 A 的这条（只针对应用目录本身）： sudo setfacl -R -m u:shiny:rx /home/wang/shiny_apps/mzh-lab sudo setfacl -R -d -m u:shiny:rx /home/wang/shiny_apps/mzh-lab


2. 创建挂载点并绑定


- 创建目标目录： sudo mkdir -p /srv/shiny-server/mzh-lab

- 绑定（生效到下次重启）： sudo mount --bind /home/wang/shiny_apps/mzh-lab /srv/shiny-server/mzh-lab

- 可选：改为只读（建议用于代码和数据不希望被服务写入时）： sudo mount -o remount,bind,ro /srv/shiny-server/mzh-lab


3. 开机自动挂载（建议）


- 在 /etc/fstab 追加一行：

name=/etc/fstab

```
# 让 Shiny 看到你的 app 目录（若需要只读，在某些系统上需要后续 remount ro）
/home/wang/shiny_apps/mzh-lab  /srv/shiny-server/mzh-lab  none  bind  0  0
```

- 如果你想持久只读，部分发行版需要在开机后再 remount 一次只读；可以加一个 systemd oneshot 或在 rc.local 里执行： mount -o remount,bind,ro /srv/shiny-server/mzh-lab


4. 验证


- 同方案 A 的验证步骤。

权限控制补充

- 不让 shiny 写代码/数据：
  - 方案 A：保持对应用目录仅 rx；方案 B：挂载只读。
- 如果应用需要写某些输出（上传/缓存/日志）：
  - 给一个单独的可写目录，例如： sudo mkdir -p /var/lib/shiny-apps/mzh-lab-write sudo chown shiny:shiny /var/lib/shiny-apps/mzh-lab-write
  - 在应用里把写路径指向该目录，代码目录保持只读。
- 查看权限问题时的日志位置：
  - /var/log/shiny-server.log 以及对应应用目录下的日志（若配置）。

选择建议

- 想最少改动就能跑：方案 A（软链 + ACL）。
- 不想给家目录父路径任何权限、隔离更好：方案 B（bind 挂载，最好只读）。