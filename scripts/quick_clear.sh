#!/bin/bash

# 快速清除脚本 - 一键清除应用数据
# 使用方法: bash scripts/quick_clear.sh

echo "=========================================="
echo "快速清除应用数据"
echo "=========================================="
echo ""

# 检查 adb
if ! command -v adb &> /dev/null; then
    echo "⚠️  未找到 adb，将只清除本地数据..."
    echo ""
    echo "正在运行 Dart 清除脚本..."
    dart scripts/clear_data.dart
    exit 0
fi

# 检查设备
DEVICES=$(adb devices | grep -v "List" | grep "device" | wc -l)
if [ "$DEVICES" -eq 0 ]; then
    echo "⚠️  未检测到设备，将只清除本地数据..."
    echo ""
    echo "正在运行 Dart 清除脚本..."
    dart scripts/clear_data.dart
    exit 0
fi

# 包名
PACKAGE_NAME="com.example.daily_english_app"

echo "检测到设备，清除 Android 应用数据..."
echo "包名: $PACKAGE_NAME"
echo ""

# 清除应用数据
adb shell pm clear $PACKAGE_NAME

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 应用数据已清除！"
    echo ""
    echo "提示：重启应用以查看效果"
else
    echo ""
    echo "❌ 清除失败，尝试使用详细脚本..."
    bash scripts/clear_android_data.sh
fi

