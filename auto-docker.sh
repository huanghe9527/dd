#!/bin/bash
# 一键安装 Docker 的脚本，兼容 Debian/Ubuntu 和 AMD64/ARM 架构
# 支持 Debian 10 (Buster) 等旧版本系统
# 安装完成后以彩色加粗输出简洁的验证信息

# 遇到错误时退出，但会处理特定错误
set -e

# ANSI 颜色代码
GREEN="\033[1;32m"
RED="\033[1;31m"
RESET="\033[0m"

# 函数：检测发行版和代号
get_distro_info() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        CODENAME=$VERSION_CODENAME
        # 对于没有 VERSION_CODENAME 的旧系统
        if [ -z "$CODENAME" ] && command -v lsb_release >/dev/null 2>&1; then
            CODENAME=$(lsb_release -cs)
        fi
    else
        echo -e "${RED}错误：无法检测发行版，/etc/os-release 文件不存在。${RESET}"
        exit 1
    fi
    # 处理特定发行版
    case $DISTRO in
        debian|raspbian)
            [ -z "$CODENAME" ] && CODENAME=$(cat /etc/debian_version | cut -d. -f1)
            DISTRO="debian" # 统一将 raspbian 视为 debian
            ;;
        ubuntu)
            [ -z "$CODENAME" ] && CODENAME=$(lsb_release -cs 2>/dev/null || echo "focal")
            ;;
        *)
            echo -e "${RED}警告：不支持的发行版 '$DISTRO'，尝试以 Debian 方式继续。${RESET}"
            DISTRO="debian"
            CODENAME=${CODENAME:-buster}
            ;;
    esac
    echo -e "${GREEN}检测到发行版：$DISTRO，代号：$CODENAME${RESET}"
}

# 函数：安装软件包，忽略不可用的包
install_packages() {
    echo -e "${GREEN}正在安装软件包：$@${RESET}"
    if ! $SUDO apt-get install -y "$@" >/dev/null 2>&1; then
        echo -e "${RED}警告：部分软件包安装失败，继续安装其他可用软件包。${RESET}"
    fi
}

# 函数：添加 Docker GPG 密钥
add_docker_gpg_key() {
    local PRIMARY_URL="https://download.docker.com/linux/$DISTRO/gpg"
    local FALLBACK_URL="https://download.docker.com/linux/debian/gpg"
    echo -e "${GREEN}尝试添加 Docker GPG 密钥...${RESET}"
    if [ -f /etc/apt/keyrings/docker.gpg ]; then
        echo -e "${GREEN}GPG 密钥文件已存在，正在覆盖...${RESET}"
    fi
    # 尝试主 URL
    if curl -fsSL "$PRIMARY_URL" | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes >/dev/null 2>&1; then
        echo -e "${GREEN}成功添加 GPG 密钥。${RESET}"
    else
        echo -e "${RED}主 URL ($PRIMARY_URL) 失败，尝试备用 URL ($FALLBACK_URL)...${RESET}"
        if ! curl -fsSL "$FALLBACK_URL" | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes >/dev/null 2>&1; then
            echo -e "${RED}错误：无法下载 GPG 密钥。请检查网络连接或 Docker 仓库可用性。${RESET}"
            exit 1
        fi
        echo -e "${GREEN}成功从备用 URL 添加 GPG 密钥。${RESET}"
    fi
    $SUDO chmod a+r /etc/apt/keyrings/docker.gpg
}

# 检查 sudo 权限
if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
    if ! command -v sudo >/dev/null 2>&1; then
        echo -e "${RED}错误：需要 sudo，但未安装。${RESET}"
        exit 1
    fi
fi

# 更新软件包索引并安装依赖
echo -e "${GREEN}更新软件包索引并安装依赖...${RESET}"
$SUDO apt-get update >/dev/null 2>&1
install_packages ca-certificates curl gnupg lsb-release

# 创建密钥环目录
$SUDO install -m 0755 -d /etc/apt/keyrings >/dev/null 2>&1

# 获取发行版信息
get_distro_info

# 添加 Docker GPG 密钥
add_docker_gpg_key

# 添加 Docker 仓库到 APT 源
echo -e "${GREEN}添加 Docker 仓库...${RESET}"
ARCH=$(dpkg --print-architecture)
echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$DISTRO $CODENAME stable" | $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null

# 再次更新软件包索引
$SUDO apt-get update >/dev/null 2>&1

# 安装 Docker 核心组件
echo -e "${GREEN}安装 Docker 核心组件...${RESET}"
CORE_PACKAGES="docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
OPTIONAL_PACKAGES="docker-scan-plugin"

install_packages $CORE_PACKAGES
# 尝试安装可选组件，失败则跳过
for pkg in $OPTIONAL_PACKAGES; do
    install_packages $pkg || echo -e "${RED}提示：$pkg 在此系统上不可用，已跳过。${RESET}"
done

# 启动并启用 Docker 服务
echo -e "${GREEN}启动并启用 Docker 服务...${RESET}"
$SUDO systemctl enable docker >/dev/null 2>&1 || echo -e "${RED}警告：无法启用 Docker 服务。${RESET}"
$SUDO systemctl start docker >/dev/null 2>&1 || echo -e "${RED}警告：无法启动 Docker 服务。${RESET}"

# 验证安装结果
echo -e "${GREEN}===== Docker 安装验证 =====${RESET}"
# 检查 Docker 版本
if command -v docker >/dev/null; then
    echo -e "${GREEN}Docker 版本：$(docker --version)${RESET}"
else
    echo -e "${RED}Docker 未安装。${RESET}"
fi

# 检查 Docker Compose 版本
if docker compose version >/dev/null 2>&1; then
    echo -e "${GREEN}Docker Compose 版本：$(docker compose version)${RESET}"
else
    echo -e "${RED}Docker Compose 未安装。${RESET}"
fi

# 检查 Containerd 版本
if command -v containerd >/dev/null; then
    echo -e "${GREEN}Containerd 版本：$(containerd --version)${RESET}"
else
    echo -e "${RED}Containerd 未安装。${RESET}"
fi

# 检查 Docker 服务状态
if $SUDO systemctl is-active docker >/dev/null; then
    echo -e "${GREEN}Docker 服务状态：运行中${RESET}"
else
    echo -e "${RED}Docker 服务状态：未运行${RESET}"
fi

# 检查 Docker 组权限
if groups | grep -qw docker; then
    echo -e "${GREEN}Docker 组权限：当前用户已在 docker 组${RESET}"
else
    echo -e "${RED}Docker 组权限：当前用户不在 docker 组，请注销并重新登录${RESET}"
fi

# 显示 Docker 系统信息
echo -e "${GREEN}Docker 系统信息：${RESET}"
if docker info >/dev/null 2>&1; then
    echo -e "${GREEN}$(docker info --format '{{.ServerVersion}}\t{{.OperatingSystem}}\t{{.Architecture}}')${RESET}"
else
    echo -e "${RED}无法获取 Docker 系统信息${RESET}"
fi

# 将当前用户添加到 docker 组（可选）
if [ -n "$USER" ]; then
    echo -e "${GREEN}将当前用户添加到 docker 组...${RESET}"
    $SUDO usermod -aG docker "$USER" >/dev/null 2>&1 || echo -e "${RED}警告：无法将用户添加到 docker 组。${RESET}"
    echo -e "${GREEN}请注销并重新登录以应用 docker 组权限变更。${RESET}"
else
    echo -e "${RED}警告：\$USER 变量未设置，跳过 docker 组添加。${RESET}"
fi

echo -e "${GREEN}===== 安装和验证完成 =====${RESET}"
