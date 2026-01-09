#!/bin/bash

# 获取根分区总容量（单位：G，取整数）
DISK_G=$(df -BG / | awk 'NR==2 {gsub("G","",$2); print $2}')

# 默认大小
RUN_SIZE="128M"

# 简单条件判断
if [ "$DISK_G" -le 8 ]; then
    RUN_SIZE="128M"
elif [ "$DISK_G" -le 10 ]; then
    RUN_SIZE="512M"
elif [ "$DISK_G" -le 20 ]; then
    RUN_SIZE="1024M"
elif [ "$DISK_G" -le 50 ]; then
    RUN_SIZE="2048M"
else
    RUN_SIZE="3072M"
fi

echo "[+] Disk size: ${DISK_G}G"
echo "[+] Setting /run tmpfs size to: ${RUN_SIZE}"

# 清理旧的 /run tmpfs 配置
sed -i '\|tmpfs\s\+/run\s\+tmpfs|d' /etc/fstab

# 写入永久配置
echo "tmpfs  /run  tmpfs  rw,nosuid,nodev,size=${RUN_SIZE}  0  0" >> /etc/fstab

# 立即生效
mount -o remount,size=${RUN_SIZE} /run

# 输出结果
df -h /run

echo "[✓] /run tmpfs configured and applied permanently."
