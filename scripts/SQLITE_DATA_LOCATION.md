# SQLite 数据库文件位置说明

## 数据库文件信息

- **文件名**: `daily_english.db`
- **存储方式**: 使用 `path_provider` 的 `getApplicationDocumentsDirectory()` 获取应用文档目录

## 各平台数据库文件路径

### Android

**路径**: `/data/data/com.example.daily_english_app/app_flutter/daily_english.db`

**说明**:
- 包名: `com.example.daily_english_app`
- 完整路径示例: `/data/data/com.example.daily_english_app/app_flutter/daily_english.db`
- 需要 root 权限才能直接访问（调试时可通过 adb 访问）

**相关文件**:
- `daily_english.db` - 主数据库文件
- `daily_english.db-wal` - WAL (Write-Ahead Logging) 日志文件（如果启用）
- `daily_english.db-shm` - 共享内存文件（如果启用）

### iOS

**路径**: `~/Library/Application Support/[Bundle ID]/daily_english.db`

**说明**:
- 需要通过应用沙盒访问
- 完整路径示例: `/Users/[username]/Library/Application Support/com.example.dailyEnglishApp/daily_english.db`
- 在模拟器中可以通过 Finder 访问

### Linux (桌面应用)

**路径**: `~/.local/share/daily_english_app/daily_english.db` 或类似路径

**说明**:
- 具体路径取决于应用的配置
- 通常位于用户主目录下的 `.local/share/` 目录

### macOS (桌面应用)

**路径**: `~/Library/Application Support/daily_english_app/daily_english.db`

## 数据库表结构

数据库包含以下表：

1. **settings** - 应用设置（每日学习量、用户名等）
2. **daily_sessions** - 每日学习会话
3. **study_records** - 学习记录（每条记录独立存储）
4. **daily_completion** - 按词库的每日完成状态
5. **global_daily_completion** - 全局每日完成状态
6. **checkins** - 签到记录

## 清除数据的方法

### 方法1: 使用 Shell 脚本（Android，推荐）

```bash
# 清除所有 SQLite 数据（删除数据库文件）
bash scripts/clear_sqlite_data.sh

# 或赋予执行权限后直接运行
chmod +x scripts/clear_sqlite_data.sh
./scripts/clear_sqlite_data.sh
```

**优点**：
- 不需要 Flutter 环境
- 自动检测设备连接
- 交互式确认，安全可靠

### 方法2: 在 Flutter 应用内调用

```dart
// 在 Flutter 应用中导入并调用
import 'package:daily_english_app/scripts/clear_sqlite_data.dart';

// 清除所有数据（删除数据库文件）
await clearAllSqliteData();

// 或只清除学习记录，保留设置
await clearStudyDataOnly();

// 或只清除设置，保留学习记录
await clearSettingsDataOnly();
```

**注意**：`clear_sqlite_data.dart` 只能在 Flutter 应用环境中运行，不能作为独立的 Dart 脚本运行。

### 方法2: 通过 adb 删除（Android）

```bash
# 连接设备
adb devices

# 删除数据库文件
adb shell run-as com.example.daily_english_app rm /data/data/com.example.daily_english_app/app_flutter/daily_english.db

# 删除相关文件
adb shell run-as com.example.daily_english_app rm /data/data/com.example.daily_english_app/app_flutter/daily_english.db-wal
adb shell run-as com.example.daily_english_app rm /data/data/com.example.daily_english_app/app_flutter/daily_english.db-shm
```

### 方法3: 卸载重装应用

最简单的方法，会删除所有应用数据（包括数据库）。

```bash
# Android
adb uninstall com.example.daily_english_app
flutter install

# iOS (需要在 Xcode 中操作)
```

### 方法4: 在应用内添加清除功能

可以在应用的个人中心页面添加"清除所有数据"按钮，调用清除函数。

## 注意事项

1. **备份数据**: 清除前请确保不需要保留数据，或先备份数据库文件
2. **数据库连接**: 清除前确保应用已关闭，或数据库连接已关闭
3. **权限问题**: Android 上直接访问数据库文件需要 root 权限，建议使用脚本或应用内清除功能
4. **WAL 文件**: SQLite 可能使用 WAL 模式，清除时记得同时删除 `-wal` 和 `-shm` 文件

## 验证清除结果

清除后可以：
1. 重启应用，确认所有数据已重置
2. 检查数据库文件是否已删除或为空
3. 测试应用的各个功能，确保正常工作

