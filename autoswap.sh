#!/bin/bash

# 必须以 root 权限运行
if [[ $EUID -ne 0 ]]; then
    echo "错误：请使用 sudo 运行此脚本"
    exit 1
fi

echo "正在强制清理所有 swap 并重新创建合适大小的新 swapfile..."

# 1. 先读取当前所有激活的 swap 路径（关键！在 swapoff 前读取）
mapfile -t SWAP_PATHS < <(awk '{print $1}' /proc/swaps 2>/dev/null | grep '^/')

# 2. 关闭所有 swap
swapoff -a

# 3. 删除所有之前记录的 swap 文件（只删文件类型，忽略分区）
if (( ${#SWAP_PATHS[@]} > 0 )); then
    echo "检测到旧 swap 文件，正在删除："
    for path in "${SWAP_PATHS[@]}"; do
        if [[ -f "$path" ]]; then
            echo "   删除: $path"
            rm -f "$path"
        elif [[ -b "$path" ]]; then
            echo "   跳过分区类型 swap: $path"
        fi
    done
else
    echo "未检测到现有 swap 文件。"
fi

# 4. 清理 /etc/fstab 中的所有 swap 条目（备份仅一次）
if [[ ! -f /etc/fstab.bak ]]; then
    cp /etc/fstab /etc/fstab.bak && echo "已备份 /etc/fstab 为 /etc/fstab.bak"
fi
sed -i '/[[:space:]]swap[[:space:]]/d' /etc/fstab
sed -i '/\/swapfile/d' /etc/fstab
sed -i '/\/SwapDir\/swap/d' /etc/fstab

# 5. 计算根分区总大小（GB）
TOTAL_KB=$(df -k / | tail -1 | awk '{print $2}')
TOTAL_GB=$((TOTAL_KB / 1024 / 1024))

# 6. 决定新 swap 大小
if (( TOTAL_GB < 5 )); then
    SWAP_GB=0.5
elif (( TOTAL_GB <= 30 )); then
    SWAP_GB=2
else
    SWAP_GB=4
fi

SWAPFILE="/swapfile"

echo "根分区总空间约 ${TOTAL_GB}GB，将创建 ${SWAP_GB}GB 新 swapfile（位于 $SWAPFILE）"

# 7. 检查可用空间（预留 10% 裕量）
AVAIL_KB=$(df -k / | tail -1 | awk '{print $4}')
REQUIRED_KB=$(( SWAP_GB * 1024 * 1024 * 11 / 10 ))
if (( AVAIL_KB < REQUIRED_KB )); then
    echo "错误：可用空间不足（需约 $((REQUIRED_KB / 1024 / 1024))GB，当前仅 $((AVAIL_KB / 1024 / 1024))GB）"
    exit 1
fi

# 8. 创建新 swapfile
echo "正在分配空间..."
fallocate -l ${SWAP_GB}G "$SWAPFILE"
chmod 600 "$SWAPFILE"
mkswap "$SWAPFILE" > /dev/null
swapon "$SWAPFILE"

# 9. 添加到 fstab（永久生效）
echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab

echo "完成！旧 swap 文件已彻底删除，新 ${SWAP_GB}GB swapfile 已启用。"
echo "当前 swap 状态："
swapon --show
echo "磁盘空间已释放，可用 df -h / 检查确认。"
# 或者直接复制保存为文件
