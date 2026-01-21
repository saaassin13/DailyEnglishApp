#!/bin/bash

# 清除 SQLite 数据库数据的 Shell 脚本（Android）
# 
# 使用方法：
#   bash scripts/clear_sqlite_data.sh
#   或
#   chmod +x scripts/clear_sqlite_data.sh
#   ./scripts/clear_sqlite_data.sh

PACKAGE_NAME="com.example.daily_english_app"
DB_PATH="/data/data/${PACKAGE_NAME}/app_flutter/daily_english.db"

echo "=========================================="
echo "清除 SQLite 数据库数据"
echo "=========================================="
echo ""
echo "包名: $PACKAGE_NAME"
echo "数据库路径: $DB_PATH"
echo ""

# 检查 adb 是否可用
if ! command -v adb &> /dev/null; then
    echo "❌ 错误: 未找到 adb 命令"
    echo "请确保 Android SDK Platform Tools 已安装并在 PATH 中"
    exit 1
fi

# 检查设备连接
DEVICES=$(adb devices | grep -v "List" | grep "device$" | wc -l)
if [ "$DEVICES" -eq 0 ]; then
    echo "❌ 错误: 未检测到已连接的 Android 设备"
    echo "请确保："
    echo "  1. 设备已通过 USB 连接"
    echo "  2. 已启用 USB 调试"
    echo "  3. 已授权此计算机"
    echo ""
    echo "运行 'adb devices' 查看设备列表"
    exit 1
fi

echo "✓ 检测到 $DEVICES 个设备"
echo ""

# 检查数据库文件是否存在
echo "检查数据库文件..."
DB_EXISTS=$(adb shell run-as $PACKAGE_NAME ls $DB_PATH 2>/dev/null | grep -c "daily_english.db" || echo "0")

if [ "$DB_EXISTS" -eq "0" ]; then
    echo "⚠ 数据库文件不存在，可能还没有创建过数据"
    echo ""
    echo "检查相关文件..."
    
    # 检查 WAL 和 SHM 文件
    WAL_EXISTS=$(adb shell run-as $PACKAGE_NAME ls "${DB_PATH}-wal" 2>/dev/null | grep -c "daily_english.db-wal" || echo "0")
    SHM_EXISTS=$(adb shell run-as $PACKAGE_NAME ls "${DB_PATH}-shm" 2>/dev/null | grep -c "daily_english.db-shm" || echo "0")
    
    if [ "$WAL_EXISTS" -eq "0" ] && [ "$SHM_EXISTS" -eq "0" ]; then
        echo "✓ 确认：没有找到任何数据库文件"
        exit 0
    fi
else
    echo "✓ 找到数据库文件"
fi

echo ""
echo "准备删除以下文件："
echo "  - $DB_PATH"
echo "  - ${DB_PATH}-wal"
echo "  - ${DB_PATH}-shm"
echo ""

# 确认删除
read -p "确认删除所有数据库文件？(y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "已取消操作"
    exit 0
fi

echo ""
echo "正在删除数据库文件..."

# 删除主数据库文件
if adb shell run-as $PACKAGE_NAME rm $DB_PATH 2>/dev/null; then
    echo "✓ 已删除: daily_english.db"
else
    echo "⚠ 删除 daily_english.db 失败（可能文件不存在）"
fi

# 删除 WAL 文件
if adb shell run-as $PACKAGE_NAME rm "${DB_PATH}-wal" 2>/dev/null; then
    echo "✓ 已删除: daily_english.db-wal"
fi

# 删除 SHM 文件
if adb shell run-as $PACKAGE_NAME rm "${DB_PATH}-shm" 2>/dev/null; then
    echo "✓ 已删除: daily_english.db-shm"
fi

echo ""
echo "=========================================="
echo "✓ 数据清除完成！"
echo "=========================================="
echo ""
echo "建议："
echo "  1. 重启应用以确保数据库重新初始化"
echo "  2. 验证应用功能是否正常"

