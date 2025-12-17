#!/bin/bash

# 出错直接忽略，避免 cron 报错
set +e

#1. 清理 APT 缓存
apt-get clean >/dev/null 2>&1
apt-get autoclean >/dev/null 2>&1
apt-get autoremove -y --purge >/dev/null 2>&1

#2. 清理 systemd journal（限制体积）
journalctl --vacuum-size=100M >/dev/null 2>&1
journalctl --vacuum-time=7d >/dev/null 2>&1

#3. 清理过大的日志文件（只清空，不删除）
find /var/log -type f -name "*.log" -size +20M -exec truncate -s 0 {} \; >/dev/null 2>&1

#4. 删除 logrotate 压缩旧日志+清理临时目录+清理crash
rm -f /var/log/*.gz /var/log/*.[0-9] >/dev/null 2>&1
rm -rf /tmp/* /var/tmp/* >/dev/null 2>&1
rm -rf /var/crash/* >/dev/null 2>&1

#5. 清理旧内核（保留当前）
CURRENT_KERNEL="$(uname -r)"
dpkg --list | awk '/linux-image-[0-9]/ {print $2}' | while read KERNEL; do
    echo "$KERNEL" | grep -q "$CURRENT_KERNEL" && continue
    apt-get purge -y "$KERNEL" >/dev/null 2>&1
done

#6. Docker 存在才清理
if command -v docker >/dev/null 2>&1; then
    docker system prune -af >/dev/null 2>&1
fi
exit 0

#7. 删除不必要负载
systemctl disable man-db.timer
systemctl disable apt-daily.timer
systemctl disable apt-daily-upgrade.timer

#8. 删除不必要语言
cd /usr/share/locale || exit
for d in */; do
    case "$d" in
        zh_CN/|zh_TW/|zh_HK/)
            ;;
        *)
            rm -rf "$d"
            ;;
    esac
done

echo "默认清理"
echo "debian的话就先apt清理续命顺便清理unixbench和memtester和wget-log关键词文件"
apt clean && find / -type f \( -name "*wget-log*" -o -name "*unixbench*" -o -name "*LemonBenchReport*" -o -name "*memtester*" \) -exec rm -f {} \;

#删除垃圾文件夹规则 *T*_*+*_*
echo "删除垃圾文件夹规则 *T*_*+*_*"
find /root/ -type d -iname '*T*_*+*_*' -exec rm -rf {} \;

#删除垃圾文件 包含unixbench关键词 memtester关键词
echo "删除垃圾文件 包含unixbench关键词 memtester关键词 webBenchmark关键词 nohup.out关键词"
find /root/ -type f \( -iname '*unixbench*' -o -iname '*memtester*' -o -iname '*webBenchmark*' -o -iname '*nohup.out*' \) -exec rm -f {} \;

#检查存储占用情况
usage=$(df / --output=pcent | tail -n 1 | tr -d ' %')

#判断存储是否超过或等于90%
echo "判断存储是否超过或等于90%"
if [ "$usage" -ge 90 ]; then
    echo "存储占用 $usage%，执行清理操作..."
    echo "给过机会了半小时还是超90%必须清理"
    echo "以下文件将被删除：/gd | /100g | /256g | /512g | /1t | /SwapDir"
    apt clean
    rm -rf ./gd/*
    rm -rf /1t/gd/*
    rm -rf /gd*
    rm -rf /100g*
    rm -rf /256g*
    rm -rf /512g*
    rm -rf /1t*
    rm -rf /SwapDir*
    rm -rf /tmp/*
    rm -rf /var/log/*
    rm -rf /var/cache/*
    rm -rf /etc/nginx/logs/*
    rm -rf /opt/unixbench/*
    rm -rf /opt/netdata/*
    echo "是超过了,已经帮你清理了!包括常规apt更新缓存,我连日志都不放过。清理完成。"
else
    echo "存储占用 $usage%，无需清理。干他妈的多杀点"
    rm -rf /opt/netdata*
    #rm -rf /opt/netdata/var/cache*
    #rm -rf /opt/netdata/var/log* 
    #rm -rf /opt/netdata/usr/share/netdata*
    #rm -rf /opt/netdata/usr/libexec/netdata*
    rm -rf /var/cache/netdata*
    rm -rf /usr/share/netdata*
    rm -rf /etc/nginx/logs/error.log
    rm -rf /etc/nginx/logs/access.log
    rm -rf /usr/libexec/netdata*
    
    
    exit
fi
