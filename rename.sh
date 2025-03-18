#!/bin/bash
# 主机名智能配置脚本 3（交互式版）
# 功能：安全修改主机名并确保系统完整性

# 配置参数
declare -r SCRIPT_NAME="$(basename "$0")"
declare -r TIMESTAMP=$(date +%Y%m%d-%H%M%S)
declare -r HOSTS_BACKUP="/etc/hosts.$TIMESTAMP.bak"
declare -r COLOR_ERROR='\033[1;31m'
declare -r COLOR_SUCCESS='\033[1;32m'
declare -r COLOR_WARNING='\033[1;33m'
declare -r COLOR_INFO='\033[1;34m'
declare -r COLOR_END='\033[0m'

# 退出状态码
declare -r EXIT_SUCCESS=0
declare -r EXIT_NOT_ROOT=2
declare -r EXIT_HOSTNAME_INVALID=3
declare -r EXIT_HOSTNAME_SAME=4
declare -r EXIT_OPERATION_FAILED=5

show_usage() {
    echo -e "${COLOR_INFO}使用方法:${COLOR_END}"
    echo -e "  sudo ./$SCRIPT_NAME"
    echo -e "\n${COLOR_INFO}规范要求:${COLOR_END}"
    echo -e "  - 仅包含字母、数字和连字符(-)"
    echo -e "  - 不以数字或连字符开头/结尾"
    echo -e "  - 长度1-63字符"
    echo -e "\n${COLOR_INFO}示例:${COLOR_END}"
    echo -e "  有效主机名：web-server-01"
}

validate_hostname() {
    local hostname_regex='^[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$'
    [[ "$1" =~ $hostname_regex ]] || return 1
    [[ "$1" != *--* ]] || return 1  # 防止连续连字符
    return 0
}

backup_hosts() {
    cp /etc/hosts "$HOSTS_BACKUP" || {
        echo -e "${COLOR_ERROR}错误：无法创建hosts备份文件${COLOR_END}" >&2
        exit $EXIT_OPERATION_FAILED
    }
    echo -e "${COLOR_INFO}已创建hosts备份：$HOSTS_BACKUP${COLOR_END}"
}

update_hosts() {
    local old_hostname=$(hostname)
    local new_hostname=$1

    # 清理旧条目
    sed -i -E "/^127\.0\.0\.1/s/[[:space:]]${old_hostname}\$//g" /etc/hosts
    sed -i -E "/^::1/s/[[:space:]]${old_hostname}\$//g" /etc/hosts

    # 添加新条目（智能处理不同格式）
    if ! grep -qE "^127\.0\.0\.1[[:space:]]+.*[[:space:]]${new_hostname}([[:space:]]|$)" /etc/hosts; then
        sed -i -E "/^127\.0\.0\.1/s/(localhost)/\1 ${new_hostname}/" /etc/hosts
    fi

    if ! grep -qE "^::1[[:space:]]+.*[[:space:]]${new_hostname}([[:space:]]|$)" /etc/hosts; then
        sed -i -E "/^::1/s/(localhost)/\1 ${new_hostname}/" /etc/hosts
    fi

    # 标准化格式
    sed -i -E 's/[[:space:]]+/ /g' /etc/hosts
    sed -i -E 's/[[:space:]]$//' /etc/hosts
}

restart_services() {
    echo -e "${COLOR_INFO}重启相关服务...${COLOR_END}"
    systemctl restart systemd-hostnamed 2>/dev/null
    systemctl restart systemd-logind 2>/dev/null
    systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null
    systemctl daemon-reload
}

verify_changes() {
    echo -e "\n${COLOR_INFO}验证结果：${COLOR_END}"
    
    # 检查三级主机名
    echo -e "静态主机名: $(hostnamectl --static)"
    echo -e "瞬时主机名: $(hostnamectl --transient)"
    echo -e "持久主机名: $(hostnamectl --pretty)"

    # 解析检查
    echo -e "\n解析测试："
    getent hosts "$(hostname)"

    # Sudo测试
    echo -e "\nSudo测试："
    sudo -k 2>/dev/null
    sudo -n true 2>&1 | grep -v "password" && echo -e "${COLOR_SUCCESS}✔ Sudo配置正常${COLOR_END}" || {
        echo -e "${COLOR_WARNING}⚠ 检测到sudo警告，运行以下命令刷新缓存："
        echo -e "  exec sudo -i"
        echo -e "  exit${COLOR_END}"
    }
}

get_new_hostname() {
    while true; do
        read -p "请输入新主机名（输入 q 退出）: " new_hostname
        case "$new_hostname" in
            [Qq])
                echo -e "${COLOR_WARNING}已取消操作${COLOR_END}"
                exit $EXIT_SUCCESS
                ;;
            *)
                if validate_hostname "$new_hostname"; then
                    break
                else
                    echo -e "${COLOR_ERROR}无效主机名，请参考以下规范：${COLOR_END}"
                    show_usage
                fi
                ;;
        esac
    done
    echo "$new_hostname"
}

main() {
    # 权限检查
    if [[ $EUID -ne 0 ]]; then
        echo -e "${COLOR_ERROR}错误：本脚本需要使用sudo权限运行${COLOR_END}" >&2
        show_usage
        exit $EXIT_NOT_ROOT
    fi

    # 显示欢迎信息
    echo -e "\n${COLOR_INFO}当前主机名：$(hostname)${COLOR_END}"
    echo -e "${COLOR_INFO}使用方法:${COLOR_END}"
    echo -e "${COLOR_WARNING}  sudo ./$SCRIPT_NAME${COLOR_END}"
    echo -e "\n${COLOR_INFO}规范要求:${COLOR_END}"
    echo -e "${COLOR_WARNING}  - 仅包含字母、数字和连字符(-)${COLOR_END}"
    echo -e "${COLOR_WARNING}  - 不以数字或连字符开头/结尾${COLOR_END}"
    echo -e "${COLOR_WARNING}  - 长度1-63字符${COLOR_END}"
    echo -e "\n${COLOR_INFO}示例:${COLOR_END}"
    echo -e "${COLOR_WARNING}  有效主机名：web-server-01${COLOR_END}"
    echo -e "${COLOR_INFO}请开始配置新的主机名...${COLOR_END}"

    # 获取新主机名
    local new_hostname=$(get_new_hostname)
    local current_hostname=$(hostname)

    # 新旧主机名比对
    if [[ "$new_hostname" == "$current_hostname" ]]; then
        echo -e "${COLOR_WARNING}新主机名与当前主机名相同，无需修改${COLOR_END}"
        exit $EXIT_HOSTNAME_SAME
    fi

    echo -e "${COLOR_INFO}开始修改主机名：$current_hostname → $new_hostname${COLOR_END}"

    # 备份hosts
    backup_hosts

    # 修改主机名
    echo -e "${COLOR_INFO}设置系统主机名...${COLOR_END}"
    if ! hostnamectl set-hostname "$new_hostname"; then
        echo -e "${COLOR_ERROR}主机名修改失败，请检查日志${COLOR_END}" >&2
        exit $EXIT_OPERATION_FAILED
    fi

    # 处理云环境
    if [[ -f /etc/cloud/cloud.cfg ]]; then
        echo -e "${COLOR_INFO}检测到云环境配置，更新preserve_hostname...${COLOR_END}"
        sed -i 's/preserve_hostname:.*/preserve_hostname: true/' /etc/cloud/cloud.cfg
    fi

    # 更新hosts
    update_hosts "$new_hostname"

    # 重启服务
    restart_services

    # 验证
    verify_changes

    echo -e "\n${COLOR_SUCCESS}✔ 修改成功！建议操作：${COLOR_END}"
    echo -e "- 新开终端窗口确认主机名"
    echo -e "- 检查关键应用日志"
    echo -e "- 如需回滚："
    echo -e "  1. sudo hostnamectl set-hostname '$current_hostname'"
    echo -e "  2. cp $HOSTS_BACKUP /etc/hosts"

    exit $EXIT_SUCCESS
}

main
