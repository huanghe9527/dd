#!/bin/bash
#fail2ban第二版
#设置出错即退出
set -e

# 配置文件路径变量
JAIL_CONF="/etc/fail2ban/jail.local"
NGINX_ACCESS_LOG="/etc/nginx/logs/access.log"
NGINX_ERROR_LOG="/etc/nginx/logs/error.log"

# 自动安装并配置 fail2ban 的函数
install_fail2ban() {
  echo "🚀 开始安装并配置 Fail2Ban..."

  # 安装 fail2ban
  apt update && apt install -y fail2ban

  # 检测当前 sshd 使用的端口（适配非22端口）
  SSH_PORT=$(ss -tnlp | grep sshd | awk '{print $4}' | sed -n 's/.*:\([0-9]\+\)/\1/p' | head -n1)
  echo "📡 检测到 SSH 使用端口为：$SSH_PORT"

  # 创建 filter.d 目录（如果不存在）
  mkdir -p /etc/fail2ban/filter.d

  # 写入 jail.local 主配置
  cat > "$JAIL_CONF" <<EOF
[DEFAULT]
bantime = 86400             # 封禁时间：1天
findtime = 600              # 检测时间窗口：10分钟
maxretry = 5                # 最大重试次数
backend = systemd
# ignoreip = 127.0.0.1/8 ::1  # 忽略本地地址
allowipv6 = auto

[sshd]
enabled = true
port = $SSH_PORT            # 动态检测的 SSH 端口
logpath = %(sshd_log)s
maxretry = 3

[nginx-http-auth]
enabled = true
port = http,https
logpath = $NGINX_ERROR_LOG
filter = nginx-http-auth
maxretry = 3

[nginx-badbots]
enabled = true
port = http,https
logpath = $NGINX_ACCESS_LOG
filter = nginx-badbots
maxretry = 5
bantime = 3600

[nginx-404]
enabled = true
port = http,https
logpath = $NGINX_ACCESS_LOG
filter = nginx-404
maxretry = 15
findtime = 600
bantime = 3600

[nginx-limit-req]
enabled = true
port = http,https
logpath = $NGINX_ACCESS_LOG
filter = nginx-limit-req
maxretry = 30
findtime = 60
bantime = 600

[recidive]
enabled = true
logpath = /var/log/fail2ban.log
maxretry = 5
findtime = 86400
bantime = 604800
EOF

  # 编写各类过滤器规则
  cat > /etc/fail2ban/filter.d/nginx-badbots.conf <<EOF
[Definition]
failregex = ^<HOST> -.*"(GET|POST).*(\\.env|\\.git|\\.aws|\\.vscode|\\.idea|\\.DS_Store|\\.bak|\\.sql|\\.tar|\\.gz|\\.zip|\\.yml|\\.json|\\.config|\\.log).*" 404
EOF

  cat > /etc/fail2ban/filter.d/nginx-404.conf <<EOF
[Definition]
failregex = ^<HOST> -.*"(GET|POST).*" 404
EOF

  cat > /etc/fail2ban/filter.d/nginx-limit-req.conf <<EOF
[Definition]
failregex = ^<HOST> -.*"(GET|POST).*" 200
EOF

  cat > /etc/fail2ban/filter.d/nginx-http-auth.conf <<EOF
[Definition]
failregex = no user/password was provided for basic authentication.*
EOF

  # 启用并重启 fail2ban 服务
  systemctl enable fail2ban
  systemctl restart fail2ban

  echo -e "\033[1;32mFail2Ban 安装与配置完成！\033[0m"
  echo -e "\n\033[1;34m建议：\033[0m"
  echo -e "\033[0;32msystemctl status fail2ban #查看状态\033[0m"
  echo -e "\n\033[0;31mlimit_req_zone \$binary_remote_addr zone=req_limit:10m rate=10r/s;\033[0m"
  echo -e "\033[0;31mlimit_req zone=req_limit burst=20 nodelay;\033[0m"
  echo -e "\n\033[1;32m可接入 Cloudflare 可有效隐藏源站 IP + 抵抗爬虫与暴力攻击。\033[0m"
}

# 卸载 fail2ban 的函数
uninstall_fail2ban() {
  echo "❌ 正在卸载 Fail2Ban..."
  systemctl stop fail2ban
  systemctl disable fail2ban
  apt purge -y fail2ban
  rm -rf /etc/fail2ban
  echo "✅ Fail2Ban 已完全卸载并清理。"
}

# 查看 fail2ban 当前状态
show_status() {
  echo "📋 Fail2Ban 当前服务状态："
  systemctl status fail2ban --no-pager || true
  echo
  fail2ban-client status || true
}

# 主菜单函数
main_menu() {
  echo "========= Fail2Ban 管理菜单 ========="
  echo "1) 安装并配置 Fail2Ban"
  echo "2) 卸载 Fail2Ban"
  echo "3) 查看运行状态"
  echo "0) 退出脚本"
  echo "====================================="
  read -rp "请输入选项编号: " choice
  case "$choice" in
    1) install_fail2ban ;;
    2) uninstall_fail2ban ;;
    3) show_status ;;
    0) echo "👋 退出"; exit 0 ;;
    *) echo "❌ 无效选项，请重试"; sleep 1; main_menu ;;
  esac
}

# 执行菜单函数
main_menu() {
  # 如果传入参数，则直接执行对应操作
  case "$1" in
    -1) install_fail2ban; exit 0 ;;
    -2) uninstall_fail2ban; exit 0 ;;
    -3) show_status; exit 0 ;;
  esac

 echo "========= Fail2Ban 管理菜单 ========="
  echo "1) 安装并配置 Fail2Ban"
  echo "2) 卸载 Fail2Ban"
  echo "3) 查看运行状态"
  echo "0) 退出脚本"
  echo "====================================="
  read -rp "请输入选项编号: " choice
  case "$choice" in
    1) install_fail2ban ;;
    2) uninstall_fail2ban ;;
    3) show_status ;;
    0) echo "👋 退出"; exit 0 ;;
    *) echo "❌ 无效选项，请重试"; sleep 1; main_menu ;;
  esac
}

# 执行菜单逻辑，传入第一个参数（如 -1）
main_menu "$1"
