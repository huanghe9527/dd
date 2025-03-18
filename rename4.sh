#!/bin/bash
# 主机名智能配置脚本 v4（最终稳定版）
# 特性：保留大小写、安全验证、完整回滚机制

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
    echo -e "  • 字母开头（区分大小写）"
    echo -e "  • 仅包含字母、数字和连字符(-)"
    echo -e "  • 不以数字或连字符结尾"
    echo -e "  • 长度1-63字符"
    echo -e "\n${COLOR_INFO}有效示例:${COLOR_END}"
    echo -e "  WebServer-01  Production-DB  staging-node"
}

validate_hostname() {
    local hostname_regex='^[A-Za-z]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$'
    [[ "$1" =~ $hostname_regex ]] || return 1
    [[ "$1" != *--* ]] || return 1
    return 0
}

backup_hosts() {
    if ! cp /etc/hosts "$HOSTS_BACKUP"; then
        echo -e "${COLOR_ERROR}错误：创建hosts备份失败，请检查权限${COLOR_END}" >&2
        exit $EXIT_OPERATION_FAILED
    fi
    echo -e "${COLOR_INFO}已创建hosts备份：$HOSTS_BACKUP${COLOR_END}"
}

atomic_update_file() {
    local tmp_file
    tmp_file=$(mktemp) || return 1
    cp /etc/hosts "$tmp_file" || return 1
    echo "$tmp_file"
}

update_hosts() {
    local old_hostname=$(hostname -s)
    local new_hostname=$1
    local tmp_file

    if ! tmp_file=$(atomic_update_file); then
        echo -e "${COLOR_ERROR}错误：创建临时文件失败${COLOR_END}" >&2
        return 1
    fi

    # 清理旧主机名（精确匹配大小写）
    sed -i -E "/^127\.0\.0\.1/s/\b${old_hostname}\b//g" "$tmp_file"
    sed -i -E "/^::1/s/\b${old_hostname}\b//g" "$tmp_file"

    # 添加新主机名（仅当不存在时）
    if ! grep -qE "^127\.0\.0\.1.*\b${new_hostname}\b" "$tmp_file"; then
        sed -i -E "/^127\.0\.0\.1/s/(localhost)/\1 ${new_hostname}/" "$tmp_file"
    fi

    if ! grep -qE "^::1.*\b${new_hostname}\b" "$tmp_file"; then
        sed -i -E "/^::1/s/(localhost)/\1 ${new_hostname}/" "$tmp_file"
    fi

    # 标准化格式
    sed -i -E 's/[[:space:]]+/ /g' "$tmp_file"
    sed -i -E 's/[[:space:]]$//' "$tmp_file"

    if ! mv "$tmp_file" /etc/hosts; then
        echo -e "${COLOR_ERROR}错误：更新hosts文件失败${COLOR_END}" >&2
        return 1
    fi
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
    
    echo -e "静态主机名: $(hostnamectl --static)"
    echo -e "瞬时主机名: $(hostnamectl --transient)"
    echo -e "持久主机名: $(hostnamectl --pretty)"

    echo -e "\n解析测试："
    if ! getent hosts "$(hostname)"; then
        echo -e "${COLOR_WARNING}警告：未能解析当前主机名${COLOR_END}"
    fi

    echo -e "\n系统状态："
    hostnamectl status | grep -i 'static hostname'
}

get_new_hostname() {
    local attempt=0
    while true; do
        ((attempt++))
        read -p "请输入新主机名（输入 q 退出）: " new_hostname
        new_hostname=$(echo "$new_hostname" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        case "$new_hostname" in
            [Qq])
                echo -e "${COLOR_WARNING}操作已取消${COLOR_END}"
                exit $EXIT_SUCCESS
                ;;
            '')
                echo -e "${COLOR_ERROR}错误：主机名不能为空${COLOR_END}"
                ;;
            *)
                if validate_hostname "$new_hostname"; then
                    break
                else
                    if (( attempt == 1 )); then
                        echo -e "${COLOR_ERROR}无效！请检查："
                        echo -e "1. 字母开头（区分大小写）"
                        echo -e "2. 仅含字母/数字/连字符"
                        echo -e "3. 不以数字或连字符结尾"
                        echo -e "4. 1-63个字符长度${COLOR_END}"
                        show_usage
                    else
                        echo -e "${COLOR_ERROR}仍不符合规范，示例：Prod-Server01${COLOR_END}"
                    fi
                fi
                ;;
        esac
    done
    echo "$new_hostname"
}

main() {
    # 权限验证
    [[ $EUID -eq 0 ]] || {
        echo -e "${COLOR_ERROR}错误：必须使用sudo权限运行${COLOR_END}" >&2
        show_usage
        exit $EXIT_NOT_ROOT
    }

    # 显示当前信息
    echo -e "\n${COLOR_INFO}当前主机名：$(hostname)${COLOR_END}"
    echo -e "${COLOR_INFO}主机名规范：${COLOR_END}"
    echo -e "${COLOR_WARNING}• 必须字母开头（区分大小写）"
    echo -e "• 可包含数字和连字符"
    echo -e "• 不以连字符或数字结尾"
    echo -e "• 长度1-63字符${COLOR_END}"

    # 获取输入
    local new_hostname=$(get_new_hostname)
    local current_hostname=$(hostname -s)

    # 重复性检查
    if [[ "$new_hostname" == "$current_hostname" ]]; then
        echo -e "${COLOR_WARNING}新主机名与当前主机名完全相同，无需修改${COLOR_END}"
        exit $EXIT_HOSTNAME_SAME
    fi

    # 开始修改
    echo -e "\n${COLOR_INFO}正在修改主机名：${COLOR_END}"
    echo -e "旧主机名 → ${COLOR_WARNING}$current_hostname${COLOR_END}"
    echo -e "新主机名 → ${COLOR_SUCCESS}$new_hostname${COLOR_END}"

    # 备份hosts
    backup_hosts

    # 设置主机名
    if ! hostnamectl set-hostname "$new_hostname"; then
        echo -e "${COLOR_ERROR}主机名修改失败！请检查："
        echo -e "• 是否包含非法字符"
        echo -e "• 是否超过长度限制"
        echo -e "• 系统日志（journalctl -xe）${COLOR_END}" >&2
        exit $EXIT_OPERATION_FAILED
    fi

    # 处理云环境
    [[ -f /etc/cloud/cloud.cfg ]] && {
        echo -e "${COLOR_INFO}检测到云环境，更新配置...${COLOR_END}"
        sed -i 's/preserve_hostname:.*/preserve_hostname: true/' /etc/cloud/cloud.cfg
    }

    # 更新hosts文件
    if ! update_hosts "$new_hostname"; then
        echo -e "${COLOR_ERROR}错误：hosts文件更新失败，正在回滚...${COLOR_END}"
        hostnamectl set-hostname "$current_hostname"
        mv -f "$HOSTS_BACKUP" /etc/hosts
        exit $EXIT_OPERATION_FAILED
    fi

    # 重启服务
    restart_services

    # 验证结果
    verify_changes

    # 成功提示
    echo -e "\n${COLOR_SUCCESS}✔ 修改成功！建议操作：${COLOR_END}"
    echo -e "1. 打开新终端验证主机名"
    echo -e "2. 检查应用程序日志"
    echo -e "3. 回滚方法："
    echo -e "   • sudo hostnamectl set-hostname '$current_hostname'"
    echo -e "   • sudo cp $HOSTS_BACKUP /etc/hosts"

    exit $EXIT_SUCCESS
}

main
chmod +775 ./rename.sh && ./rename.sh
