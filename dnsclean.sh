#!/bin/bash
# 检查当前用户是否为 root 用户
if [[ 0 -ne 0 ]]; then
   echo "请使用 root 用户运行该脚本。" 
   exit 1
fi
# 清理 DNS 缓存
#方案一
#这个脚本首先会检查当前用户是否为 root 用户，
#因为只有root用户才有权限清理DNS缓存。
#然后它会通过systemctl命令停止systemd-resolved服务，
#删除/run/systemd/resolve/
#目录下的所有文件
#   systemctl stop systemd-resolved.service
#   rm -rf /run/systemd/resolve/*
#   systemctl start systemd-resolved.service
#   systemd-resolve --flush-caches
#   echo "DNS 缓存已清理。"
#方案二
echo "正在清理 DNS 缓存..."
# 直接刷新缓存即可，一般无需停止服务和删除文件
systemd-resolve --flush-caches
echo "DNS 缓存已清理。"