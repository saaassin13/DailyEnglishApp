import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// 清除 SQLite 数据库的所有数据
/// 
/// ⚠️ 注意：此脚本只能在 Flutter 应用环境中运行，不能作为独立的 Dart 脚本运行
/// 
/// 使用方法：
/// 1. 在 Flutter 应用中调用：
///    ```dart
///    import 'package:daily_english_app/scripts/clear_sqlite_data.dart';
///    await clearAllSqliteData();
///    ```
/// 
/// 2. 对于 Android，推荐使用 shell 脚本：
///    ```bash
///    bash scripts/clear_sqlite_data.sh
///    ```
/// 
/// 3. 或者使用 adb 命令直接删除：
///    ```bash
///    adb shell run-as com.example.daily_english_app rm /data/data/com.example.daily_english_app/app_flutter/daily_english.db
///    ```
Future<void> main() async {
  print('⚠️  此脚本只能在 Flutter 应用环境中运行！');
  print('');
  print('请使用以下方法之一：');
  print('1. 在 Flutter 应用中调用 clearAllSqliteData()');
  print('2. 使用 shell 脚本: bash scripts/clear_sqlite_data.sh');
  print('3. 使用 adb 命令直接删除数据库文件');
  print('');
  print('详细信息请查看: scripts/SQLITE_DATA_LOCATION.md');
  exit(1);
}

/// 清除所有 SQLite 数据库数据
/// 
/// 选项：
/// - deleteDatabase: true 时删除整个数据库文件（推荐，更彻底）
/// - deleteDatabase: false 时只清空所有表的数据（保留表结构）
Future<void> clearAllSqliteData({bool deleteDatabase = true}) async {
  try {
    // 获取数据库文件路径
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'daily_english.db');
    
    print('数据库文件路径: $dbPath');
    
    // 检查文件是否存在
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      print('⚠ 数据库文件不存在，可能还没有创建过数据');
      return;
    }
    
    if (deleteDatabase) {
      // 方法1: 删除整个数据库文件（推荐）
      print('\n正在删除数据库文件...');
      
      // 先关闭可能打开的数据库连接
      try {
        final db = await openDatabase(dbPath);
        await db.close();
      } catch (e) {
        // 如果数据库未打开，忽略错误
      }
      
      // 删除数据库文件
      await dbFile.delete();
      print('✓ 数据库文件已删除');
      
      // 同时删除可能存在的数据库日志文件
      final dbWalFile = File('$dbPath-wal');
      final dbShmFile = File('$dbPath-shm');
      
      if (await dbWalFile.exists()) {
        await dbWalFile.delete();
        print('✓ 数据库 WAL 文件已删除');
      }
      if (await dbShmFile.exists()) {
        await dbShmFile.delete();
        print('✓ 数据库 SHM 文件已删除');
      }
      
    } else {
      // 方法2: 只清空所有表的数据（保留表结构）
      print('\n正在清空所有表的数据...');
      
      final db = await openDatabase(dbPath);
      
      // 获取所有表的数据统计
      final tables = [
        'settings',
        'daily_sessions',
        'study_records',
        'daily_completion',
        'global_daily_completion',
        'checkins',
      ];
      
      final Map<String, int> counts = {};
      
      for (var table in tables) {
        try {
          final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
          counts[table] = result.first['count'] as int;
        } catch (e) {
          print('⚠ 无法查询表 $table: $e');
        }
      }
      
      print('\n数据统计：');
      int totalCount = 0;
      for (var entry in counts.entries) {
        print('  ${entry.key}: ${entry.value} 条');
        totalCount += entry.value;
      }
      print('  总计: $totalCount 条');
      
      // 清空所有表
      await db.transaction((txn) async {
        for (var table in tables) {
          await txn.delete(table);
        }
      });
      
      print('\n✓ 所有表的数据已清空');
      
      // 验证清除结果
      final Map<String, int> remainingCounts = {};
      for (var table in tables) {
        try {
          final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
          remainingCounts[table] = result.first['count'] as int;
        } catch (e) {
          // 忽略错误
        }
      }
      
      final remainingTotal = remainingCounts.values.fold(0, (a, b) => a + b);
      if (remainingTotal == 0) {
        print('✓ 验证通过：所有数据已清除');
      } else {
        print('⚠ 警告：仍有 $remainingTotal 条数据未被清除');
      }
      
      await db.close();
    }
    
    print('\n✓ 数据清除完成！');
    
  } catch (e) {
    print('✗ 清除数据时发生错误: $e');
    print('\n堆栈跟踪:');
    print(e.toString());
    exit(1);
  }
}

/// 只清除学习记录数据（保留设置）
Future<void> clearStudyDataOnly() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'daily_english.db');
    
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      print('⚠ 数据库文件不存在');
      return;
    }
    
    final db = await openDatabase(dbPath);
    
    // 统计要删除的数据
    final studyRecordsCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM study_records')
    ) ?? 0;
    final sessionsCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM daily_sessions')
    ) ?? 0;
    final completionCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM daily_completion')
    ) ?? 0;
    final globalCompletionCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM global_daily_completion')
    ) ?? 0;
    final checkinsCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM checkins')
    ) ?? 0;
    
    print('\n数据统计：');
    print('  学习记录: $studyRecordsCount 条');
    print('  学习会话: $sessionsCount 条');
    print('  每日完成状态: $completionCount 条');
    print('  全局完成状态: $globalCompletionCount 条');
    print('  签到记录: $checkinsCount 条');
    
    // 删除学习相关数据
    await db.transaction((txn) async {
      await txn.delete('study_records');
      await txn.delete('daily_sessions');
      await txn.delete('daily_completion');
      await txn.delete('global_daily_completion');
      await txn.delete('checkins');
    });
    
    print('\n✓ 学习记录数据已清除（设置已保留）');
    
    await db.close();
  } catch (e) {
    print('清除学习记录数据时发生错误: $e');
  }
}

/// 只清除设置数据（保留学习记录）
Future<void> clearSettingsDataOnly() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'daily_english.db');
    
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      print('⚠ 数据库文件不存在');
      return;
    }
    
    final db = await openDatabase(dbPath);
    
    // 删除设置数据
    await db.delete('settings');
    
    print('✓ 设置数据已清除（学习记录已保留）');
    
    await db.close();
  } catch (e) {
    print('清除设置数据时发生错误: $e');
  }
}

