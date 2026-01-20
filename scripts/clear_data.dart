import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

/// 清除应用的所有缓存数据和临时数据库数据
/// 
/// 使用方法：
/// 1. 在应用内调用：在 Flutter 应用中导入并调用 clearAllData()
/// 2. 作为独立脚本运行：dart scripts/clear_data.dart
Future<void> main() async {
  print('开始清除应用数据...');
  await clearAllData();
  print('数据清除完成！');
}

/// 清除所有 SharedPreferences 数据
Future<void> clearAllData() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    // 获取所有键
    final allKeys = prefs.getKeys();
    print('找到 ${allKeys.length} 个数据键');
    
    // 统计要清除的数据类型
    int studySessionCount = 0;
    int wordRecordCount = 0;
    int checkInCount = 0;
    int settingsCount = 0;
    
    // 分类统计
    for (var key in allKeys) {
      if (key.startsWith('study_session_')) {
        studySessionCount++;
      } else if (key.startsWith('word_record_')) {
        wordRecordCount++;
      } else if (key.startsWith('check_in_')) {
        checkInCount++;
      } else if (key == 'daily_review_count' || 
                 key == 'daily_new_count' || 
                 key == 'current_wordbook_id') {
        settingsCount++;
      }
    }
    
    print('\n数据统计：');
    print('  学习会话记录: $studySessionCount 条');
    print('  单词历史记录: $wordRecordCount 条');
    print('  打卡记录: $checkInCount 条');
    print('  设置项: $settingsCount 条');
    print('  总计: ${allKeys.length} 条');
    
    // 清除所有数据
    final cleared = await prefs.clear();
    
    if (cleared) {
      print('\n✓ 所有数据已成功清除！');
    } else {
      print('\n✗ 清除数据时出现错误');
    }
    
    // 验证清除结果
    final remainingKeys = prefs.getKeys();
    if (remainingKeys.isEmpty) {
      print('✓ 验证通过：所有数据已清除');
    } else {
      print('⚠ 警告：仍有 ${remainingKeys.length} 个键未被清除');
      print('  剩余键: ${remainingKeys.join(", ")}');
    }
    
  } catch (e) {
    print('清除数据时发生错误: $e');
    exit(1);
  }
}

/// 清除学习记录数据（保留设置）
Future<void> clearStudyData() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    
    int clearedCount = 0;
    
    for (var key in allKeys) {
      if (key.startsWith('study_session_') ||
          key.startsWith('word_record_') ||
          key.startsWith('check_in_')) {
        await prefs.remove(key);
        clearedCount++;
      }
    }
    
    print('已清除 $clearedCount 条学习记录数据（设置已保留）');
  } catch (e) {
    print('清除学习记录数据时发生错误: $e');
  }
}

/// 清除设置数据（保留学习记录）
Future<void> clearSettingsData() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.remove('daily_review_count');
    await prefs.remove('daily_new_count');
    await prefs.remove('current_wordbook_id');
    
    print('已清除设置数据（学习记录已保留）');
  } catch (e) {
    print('清除设置数据时发生错误: $e');
  }
}

