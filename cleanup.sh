#!/bin/bash
echo "默认清理"
  echo "debian的话就先apt清理续命顺便清理unixbench和memtester和wget-log关键词文件"
  apt clean && find / -type f \( -name "*wget-log*" -o -name "*unixbench*" -o -name "*LemonBenchReport*" -o -name "*memtester*" \) -exec rm -f {} \;

  #删除垃圾文件夹规则 *T*_*+*_*
  echo "删除垃圾文件夹规则 *T*_*+*_*"
  find /root/ -type d -iname '*T*_*+*_*' -exec rm -rf {} \;

  #删除垃圾文件 包含unixbench关键词 memtester关键词
  echo "删除垃圾文件 包含unixbench关键词 memtester关键词 webBenchmark关键词 nohup.out关键词"
  find /root/ -type f \( -iname '*unixbench*' -o -iname '*memtester*' -o -iname '*webBenchmark*' -o -iname '*nohup.out*' \) -exec rm -f {} \;

# 检查存储占用情况
usage=$(df / --output=pcent | tail -n 1 | tr -d ' %')

# 判断存储是否超过或等于90%
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
    rm -rf /etc/nginx/logs*
    rm -rf /usr/libexec/netdata*
    
    
    exit
fi
