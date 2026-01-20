#!/bin/bash

# 清除 Android 设备上的应用数据脚本
# 
# 使用方法：
#   1. 连接 Android 设备或启动模拟器
#   2. 运行: bash scripts/clear_android_data.sh
#   3. 或者: chmod +x scripts/clear_android_data.sh && ./scripts/clear_android_data.sh

# 应用包名（从 pubspec.yaml 中的 name 字段获取）
PACKAGE_NAME="com.example.daily_english_app"

# 检查 adb 是否可用
if ! command -v adb &> /dev/null; then
    echo "错误: 未找到 adb 命令"
    echo "请确保 Android SDK Platform Tools 已安装并在 PATH 中"
    exit 1
fi

# 检查设备连接
DEVICES=$(adb devices | grep -v "List" | grep "device" | wc -l)
if [ "$DEVICES" -eq 0 ]; then
    echo "错误: 未检测到连接的 Android 设备或模拟器"
    echo "请确保设备已连接并启用 USB 调试"
    exit 1
fi

echo "=========================================="
echo "清除 Android 应用数据"
echo "=========================================="
echo "包名: $PACKAGE_NAME"
echo "设备数量: $DEVICES"
echo ""

# 显示当前数据大小
echo "检查当前数据大小..."
DATA_SIZE=$(adb shell du -sh /data/data/$PACKAGE_NAME 2>/dev/null | awk '{print $1}')
if [ -n "$DATA_SIZE" ]; then
    echo "当前数据大小: $DATA_SIZE"
else
    echo "警告: 无法获取数据大小（应用可能未安装）"
fi

echo ""
read -p "确认清除所有应用数据？(y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "操作已取消"
    exit 0
fi

echo ""
echo "开始清除数据..."

# 方法1: 清除 SharedPreferences（推荐，保留应用安装）
echo "1. 清除 SharedPreferences..."
adb shell run-as $PACKAGE_NAME rm -rf /data/data/$PACKAGE_NAME/shared_prefs/* 2>/dev/null
if [ $? -eq 0 ]; then
    echo "   ✓ SharedPreferences 已清除"
else
    echo "   ✗ 清除 SharedPreferences 失败（可能需要 root 权限）"
fi

# 方法2: 清除应用数据（包括 SharedPreferences、数据库、缓存等）
echo "2. 清除应用数据..."
adb shell pm clear $PACKAGE_NAME 2>/dev/null
if [ $? -eq 0 ]; then
    echo "   ✓ 应用数据已清除"
else
    echo "   ✗ 清除应用数据失败"
    echo "   尝试使用 root 权限..."
    adb root 2>/dev/null
    sleep 2
    adb shell rm -rf /data/data/$PACKAGE_NAME/* 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "   ✓ 使用 root 权限清除成功"
    else
        echo "   ✗ 清除失败，请手动清除或重新安装应用"
    fi
fi

# 方法3: 清除应用缓存
echo "3. 清除应用缓存..."
adb shell pm clear $PACKAGE_NAME 2>/dev/null
if [ $? -eq 0 ]; then
    echo "   ✓ 应用缓存已清除"
else
    echo "   ✗ 清除应用缓存失败"
fi

echo ""
echo "=========================================="
echo "数据清除完成！"
echo "=========================================="
echo ""
echo "提示："
echo "  - 如果清除失败，可以尝试卸载并重新安装应用"
echo "  - 卸载命令: adb uninstall $PACKAGE_NAME"
echo "  - 重新安装: flutter install"
echo ""

