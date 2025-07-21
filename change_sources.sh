#!/bin/bash

# 检查是否以 root 权限运行
if [ "$(id -u)" != "0" ]; then
    echo "此脚本必须以 root 权限运行" 1>&2
    exit 1
fi

# 函数：检测 Linux 发行版
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo $ID
    else
        echo "unknown"
    fi
}

# 获取发行版并检查支持情况
DISTRO=$(detect_distro)
if [ "$DISTRO" != "debian" ] && [ "$DISTRO" != "ubuntu" ]; then
    echo "不支持的发行版: $DISTRO"
    exit 1
fi

# 获取版本代号（如 buster、focal）
. /etc/os-release
CODENAME=$VERSION_CODENAME

# 检查并安装 curl（假设默认源可用）
if ! command -v curl &> /dev/null; then
    echo "curl 未安装，正在安装..."
    if ! apt-get update || ! apt-get install -y curl; then
        echo "安装 curl 失败，请检查默认软件源配置"
        exit 1
    fi
fi

# 获取 IP 的国家代码
COUNTRY=$(curl -s http://ip-api.com/json | grep -oP '(?<="countryCode":")[^"]*')
if [ -z "$COUNTRY" ]; then
    echo "无法获取国家代码，网络可能有问题"
    exit 1
fi

# 定义颜色和样式变量
COLOR_RESET="\033[0m"
COLOR_BOLD="\033[1m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_CYAN="\033[36m"
COLOR_HIGHLIGHT="\033[1;36m"  # 加粗青色用于高亮

# 根据地理位置选择镜像源
if [ "$COUNTRY" = "CN" ]; then
    # 定义中国高校镜像源名称和 URL
    MIRROR_NAMES=(
        "01.华东地区--清华大学★"
        "02.华东地区--中国科学技术大学"
        "03.华东地区--南京大学"
        "04.华东地区--北京外国语大学"
        "05.华东地区--北京大学"
        "06.东北地区--哈尔滨工业大学"
        "07.东北地区--吉林大学"
        "08.东北地区--大连东软"
        "09.华南地区--中山大学★"
        "10.华南地区--南方科技大学"
        "11.西南地区--重庆大学"
        "12.西北地区--西安交通大学"
        "13.西北地区--西北农业科技大学"
        "14.西北地区--西安电子科技大学★"
        "15.腾讯官方源"
        "16.阿里官方源"
        "17.官方源"
    )
    
    # 根据发行版设置对应的镜像 URL
    if [ "$DISTRO" = "debian" ]; then
        MIRROR_URLS=(
            "https://mirrors.tuna.tsinghua.edu.cn/debian/"
            "https://mirrors.ustc.edu.cn/debian/"
            "https://mirror.nju.edu.cn/debian/"
            "https://mirrors.bfsu.edu.cn/debian/"
            "https://mirrors.pku.edu.cn/debian/"
            "https://mirrors.hit.edu.cn/debian/"
            "https://mirrors.jlu.edu.cn/debian/"
            "https://mirrors.neusoft.edu.cn/debian/"
            "https://mirrors.sysu.edu.cn/debian/"
            "https://mirrors.sustech.edu.cn/debian/"
            "https://mirrors.cqu.edu.cn/debian/"
            "https://mirrors.xjtu.edu.cn/debian/"
            "https://mirrors.nwsuaf.edu.cn/debian/"
            "https://mirrors.xidian.edu.cn/debian/"
            "https://mirrors.tencent.com/debian/"
            "https://mirrors.aliyun.com/debian/"
            "https://deb.debian.org/debian"
        )
    elif [ "$DISTRO" = "ubuntu" ]; then
        MIRROR_URLS=(
            "https://mirrors.tuna.tsinghua.edu.cn/ubuntu/"
            "https://mirrors.ustc.edu.cn/ubuntu/"
            "https://mirror.nju.edu.cn/ubuntu/"
            "https://mirrors.bfsu.edu.cn/ubuntu/"
            "https://mirrors.pku.edu.cn/ubuntu/"
            "https://mirrors.hit.edu.cn/ubuntu/"
            "https://mirrors.jlu.edu.cn/ubuntu/"
            "https://mirrors.neusoft.edu.cn/ubuntu/"
            "https://mirrors.sysu.edu.cn/ubuntu/"
            "https://mirrors.sustech.edu.cn/ubuntu/"
            "https://mirrors.cqu.edu.cn/ubuntu/"
            "https://mirrors.xjtu.edu.cn/ubuntu/"
            "https://mirrors.nwsuaf.edu.cn/ubuntu/"
            "https://mirrors.xidian.edu.cn/ubuntu/"
            "https://mirrors.tencent.com/ubuntu/"
            "https://mirrors.aliyun.com/ubuntu/"
            "https://archive\n\n.ubuntu.com/ubuntu/"
        )
    fi

    # 用户选择镜像源
    echo "检测到您位于中国大陆，请选择一个镜像源："
    select MIRROR_NAME in "${MIRROR_NAMES[@]}"; do
        if [ -n "$MIRROR_NAME" ]; then
            MIRROR_URL=${MIRROR_URLS[$((REPLY-1))]}
            echo "已选择镜像源：$MIRROR_NAME ($MIRROR_URL)"
            break
        fi
    done
else
    # 非中国大陆地区使用默认官方镜像
    if [ "$DISTRO" = "debian" ]; then
        if [ "$CODENAME" = "buster" ]; then
            MIRROR_URL="http://archive.debian.org/debian/"
            echo "检测到 Debian 10 (buster)，使用归档镜像源：$MIRROR_URL"
        else
            MIRROR_URL="https://deb.debian.org/debian/"
            echo "使用 Debian 默认官方镜像源：$MIRROR_URL"
        fi
    elif [ "$DISTRO" = "ubuntu" ]; then
        MIRROR_URL="https://archive.ubuntu.com/ubuntu/"
        echo "使用 Ubuntu 默认官方镜像源：$MIRROR_URL"
    fi
fi

# 备份原始 sources.list
cp /etc/apt/sources.list /etc/apt/sources.list.bak
echo "已备份原始软件 ۦ软件源配置文件至 /etc/apt/sources.list.bak"

# 根据发行版更新 sources.list
if [ "$DISTRO" = "debian" ]; then
    cat > /etc/apt/sources.list <<EOF
# 主软件源
deb $MIRROR_URL $CODENAME main contrib non-free
deb-src $MIRROR_URL $CODENAME main contrib non-free

# 更新软件源
deb $MIRROR_URL $CODENAME-updates main contrib non-free
deb-src $MIRROR_URL $CODENAME-updates main contrib non-free

# 回溯软件源
#deb $MIRROR_URL $CODENAME-backports main contrib non-free
#deb-src $MIRROR_URL $CODENAME-backports main contrib non-free

# 安全更新软件源（保持官方源）
#deb http://security.debian.org/debian-security $CODENAME-security main contrib non-free
#deb-src http://security.debian.org/debian-security $CODENAME-security main contrib non-free

EOF
elif [ "$DISTRO" = "ubuntu" ]; then
    cat > /etc/apt/sources.list <<EOF
# 主软件源
deb $MIRROR_URL $CODENAME main restricted universe multiverse
# 更新软件源
deb $MIRROR_URL $CODENAME-updates main restricted universe multiverse
# 安全更新软件源（保持官方源）
#deb http://security.ubuntu.com/ubuntu $CODENAME-security main restricted universe multiverse
EOF
fi

# 检测并更新软件源
echo "正在更新软件源..."
if apt-get update; then
    echo "软件源更新成功！"
else
    echo "软件源更新失败，恢复原始配置文件..."
    mv /etc/apt/sources.list.bak /etc/apt/sources.list
    if apt-get update; then
        echo "已恢复原始软件源并更新成功"
    else
        echo "恢复后更新仍失败，请检查网络或原始源配置"
        exit 1
    fi
fi
