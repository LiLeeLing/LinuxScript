#!/bin/bash

# 优化后的一键脚本：安装基础组件并配置清理缓存和日志的定时任务 (无广告版)
# 支持 CentOS / Ubuntu / Debian
# 当前日期: 2025-03-08
# 作者: Grok 3 (xAI) - 优化版本 (无广告)

# -------------------- 可配置参数 --------------------
CLEANUP_INTERVAL_MINUTES=60  # 清理任务执行间隔 (分钟)，默认 60 分钟 (1 小时)
LOG_RETENTION_DAYS=14        # 日志保留天数，默认 14 天 (已缩短)
LOG_DIRECTORIES="/var/log"  # 需要清理日志的目录，可以修改为多个目录，用空格分隔，例如 "/var/log /var/www/vhost/*/log"
# ----------------------------------------------------

# 检查是否以root用户运行
if [ "$EUID" -ne 0 ]; then
    echo "错误：请以root用户运行此脚本: sudo $0"
    exit 1
fi

# 检测操作系统
if [ -f /etc/redhat-release ]; then
    OS="CentOS"
    PKG_MANAGER="yum"
    SERVICE_MANAGER="systemctl"
elif [ -f /etc/debian_version ]; then
    OS=$(cat /etc/os-release | grep -w "ID" | cut -d'=' -f2 | tr -d '"')
    PKG_MANAGER="apt"
    SERVICE_MANAGER="systemctl"
else
    echo "错误：不支持的操作系统"
    exit 1
fi

# 检查网络连接 (更简单的检查，可以根据需要修改)
if ! ping -c 1 -W 5 google.com &> /dev/null; then # 添加 -W 超时时间
    echo "警告：网络连接可能失败，请检查网络设置。脚本将继续执行，但更新操作可能失败。"
    # exit 1  #  不再强制退出，允许在无外网环境下安装基础组件，但更新可能会失败
fi

# 显示开始信息
echo "====================================="
echo "开始执行 VPS 清理脚本安装 (优化版 - 无广告)..."
echo "支持系统: CentOS / Ubuntu / Debian"
echo "====================================="

# 更新系统包
echo "更新系统软件包..."
if [ "$PKG_MANAGER" = "yum" ]; then
    yum update -y || echo "警告：系统更新失败，请检查网络或稍后手动更新。" # 更新失败不再强制退出
elif [ "$PKG_MANAGER" = "apt" ]; then
    apt update -y && apt upgrade -y || echo "警告：系统更新失败，请检查网络或稍后手动更新。" # 更新失败不再强制退出
fi

# 安装必要组件
echo "安装基础组件..."
INSTALL_PACKAGES="curl vim wget nano screen unzip zip crontabs" # 定义软件包变量
if [ "$OS" = "CentOS" ]; then
    yum install -y $INSTALL_PACKAGES || { echo "错误：组件安装失败"; exit 1; }
    $SERVICE_MANAGER enable crond
    $SERVICE_MANAGER start crond
elif [ "$OS" = "Ubuntu" ] || [ "$OS" = "Debian" ]; then
    apt install -y $INSTALL_PACKAGES cron || { echo "错误：组件安装失败"; exit 1; } # Ubuntu/Debian 需要安装 cron
    $SERVICE_MANAGER enable cron
    $SERVICE_MANAGER start cron
fi

# 创建文件夹和清理脚本文件
echo "创建清理脚本..."
mkdir -p /opt/script/cron || { echo "错误：创建目录失败"; exit 1; }
cat > /opt/script/cron/cleanCache.sh << 'EOF'
#!/bin/bash
#description: VPS 缓存和日志清理脚本 (优化版)

echo "开始执行缓存清理..."
sync;sync;sync # 写入硬盘，防止数据丢失
echo 1 > /proc/sys/vm/drop_caches
echo 2 > /proc/sys/vm/drop_caches
echo 3 > /proc/sys/vm/drop_caches
echo "缓存清理完毕"

echo "开始清理 $LOG_RETENTION_DAYS 天前的日志文件..."
LOG_DIRS_ARRAY=(${LOG_DIRECTORIES}) # 将空格分隔的目录字符串转换为数组
for log_dir in "${LOG_DIRS_ARRAY[@]}"; do
    if [ -d "$log_dir" ]; then # 检查目录是否存在
        find "$log_dir" -mtime +$LOG_RETENTION_DAYS -type f -name "*.log" -print0 | xargs -0 rm -f
        echo "已清理目录: $log_dir"
    else
        echo "警告：日志目录不存在: $log_dir，跳过清理。"
    fi
done
echo "$LOG_RETENTION_DAYS 天前的日志文件清理完毕"

echo "清理脚本执行完成。"

# 可以考虑使用 logrotate 进行更高级的日志管理，例如日志轮转、压缩等。
# 详细信息请参考 logrotate 的文档。
EOF

# 设置脚本权限
echo "设置脚本权限..."
chmod -R 755 /opt/script/cron || { echo "错误：权限设置失败"; exit 1; }

# 配置定时任务
echo "配置定时任务（每 ${CLEANUP_INTERVAL_MINUTES} 分钟运行一次）..."
(crontab -l 2>/dev/null; echo "*/${CLEANUP_INTERVAL_MINUTES} * * * * sh /opt/script/cron/cleanCache.sh") | crontab - || { echo "错误：定时任务配置失败"; exit 1; }

# 重启cron服务
echo "重启cron服务..."
if [ "$OS" = "CentOS" ]; then
    $SERVICE_MANAGER restart crond || { echo "错误：cron服务重启失败"; exit 1; }
elif [ "$OS" = "Ubuntu" ] || [ "$OS" = "Debian" ]; then
    $SERVICE_MANAGER restart cron || { echo "错误：cron服务重启失败"; exit 1; }
fi

# 显示完成信息
echo "====================================="
echo "脚本执行完毕！"
echo "定时任务已设置，每 ${CLEANUP_INTERVAL_MINUTES} 分钟运行一次 /opt/script/cron/cleanCache.sh"
echo "日志保留天数设置为: ${LOG_RETENTION_DAYS} 天"
echo "清理日志目录为: ${LOG_DIRECTORIES}"
echo "====================================="

# 交互式重启提示（红色和绿色搭配）
echo ""
echo -e "请现在确认重启服务器? [\e[31myes\e[0m/\e[32mno\e[0m]"
read -p "输入你的选择: " choice

case "$choice" in
    [Yy][Ee][Ss]|[Yy])
        echo "正在重启服务器..."
        reboot
        ;;
    [Nn][Oo]|[Nn])
        echo "已取消重启，脚本执行结束。"
        ;;
    *)
        echo "无效输入，默认不重启。"
        ;;
esac
