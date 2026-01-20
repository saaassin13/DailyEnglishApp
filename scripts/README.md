# 数据清除脚本使用说明

本目录包含用于清除应用缓存数据和临时数据库数据的脚本。

## 脚本列表

### 1. `clear_data.dart` - Dart 脚本（应用内清除）

在 Flutter 应用内清除 SharedPreferences 数据。

**使用方法：**

#### 方法1: 作为独立脚本运行
```bash
dart scripts/clear_data.dart
```

#### 方法2: 在应用代码中使用
```dart
import 'scripts/clear_data.dart';

// 清除所有数据（包括设置）
await clearAllData();

// 只清除学习记录（保留设置）
await clearStudyData();

// 只清除设置（保留学习记录）
await clearSettingsData();
```

**清除的数据类型：**
- ✅ 学习会话记录 (`study_session_*`)
- ✅ 单词历史记录 (`word_record_*`)
- ✅ 打卡记录 (`check_in_*`)
- ✅ 应用设置 (`daily_review_count`, `daily_new_count`, `current_wordbook_id`)

---

### 2. `clear_android_data.sh` - Shell 脚本（Android 设备清除）

直接清除 Android 设备或模拟器上的应用数据。

**前置要求：**
- 已安装 Android SDK Platform Tools（adb 命令）
- Android 设备已连接或模拟器正在运行
- 已启用 USB 调试

**使用方法：**
```bash
# 方法1: 直接运行
bash scripts/clear_android_data.sh

# 方法2: 添加执行权限后运行
chmod +x scripts/clear_android_data.sh
./scripts/clear_android_data.sh
```

**功能：**
- 清除 SharedPreferences 文件
- 清除应用数据目录
- 清除应用缓存
- 显示清除前后的数据大小

**注意事项：**
- 如果清除失败，脚本会尝试使用 root 权限
- 如果仍然失败，可以手动卸载并重新安装应用

---

## 快速清除方法

### 方法1: 使用 Flutter 命令（推荐）

在项目根目录运行：
```bash
# 清除应用数据（需要设备连接）
flutter clean
adb shell pm clear com.example.daily_english_app
```

### 方法2: 卸载并重新安装

```bash
# 卸载应用
adb uninstall com.example.daily_english_app

# 重新安装
flutter install
```

### 方法3: 在应用内添加清除按钮

可以在个人中心页面添加一个"清除数据"按钮，调用 `clearAllData()` 函数。

---

## 数据存储位置

### Android
- SharedPreferences: `/data/data/com.example.daily_english_app/shared_prefs/`
- 应用数据: `/data/data/com.example.daily_english_app/`

### iOS
- SharedPreferences: `~/Library/Preferences/[Bundle ID].plist`

---

## 测试建议

1. **清除前备份**：如果需要保留某些数据，请先备份
2. **清除后验证**：清除后重启应用，确认所有数据已重置
3. **功能测试**：清除后测试应用的各个功能，确保正常工作

---

## 常见问题

**Q: 清除数据后应用崩溃？**
A: 确保应用能正确处理空数据的情况，检查初始化逻辑。

**Q: 无法清除 Android 数据？**
A: 
- 检查设备是否已连接：`adb devices`
- 尝试使用 root 权限：`adb root`
- 或者直接卸载重装应用

**Q: 如何只清除学习记录，保留设置？**
A: 使用 `clearStudyData()` 函数，或在脚本中注释掉设置相关的清除代码。

