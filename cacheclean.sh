#!/bin/bash

# 2024-6-20加入规则
# 针对跑分数据日志等删除
# 删除包含关键词的文件
echo "清理关键词日志数据和文件夹..."
rm -f /root/*unixbench.sh* /root/*memtester.cpp* /root/*LemonBenchReport*
# 删除包含关键词文件夹
rm -rf /root/*+00_00*
rm -rf /root/*??_??_??-??_??*
rm -rf /root/*??_??_??+??_??*
rm -rf /var/cache/netdata/*
rm -rf /var/log/netdata/*
rm -rf /opt/unixbench/unixbench/results/*
rm -rf /etc/nginx/logs/*
#rm -rf /tmp/*
echo "日志数据等清理完毕"

# 2023-1-1早期规则
# 清理内存缓存脚本
clear_cache() {
    echo "清理内存缓存..."
    sync; echo 1 > /proc/sys/vm/drop_caches
    sync; echo 2 > /proc/sys/vm/drop_caches
    sync; echo 3 > /proc/sys/vm/drop_caches
    echo "内存缓存已清理。"
}

# 执行清理内存缓存
clear_cache
