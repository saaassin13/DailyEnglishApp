import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../db/app_database.dart';

class SettingsService extends ChangeNotifier {
  static const String _keyDailyReviewCount = 'daily_review_count';
  static const String _keyDailyNewCount = 'daily_new_count';
  static const String _keyCurrentWordbookId = 'current_wordbook_id';
  static const String _keyUsername = 'username';
  
  // 默认值
  static const int _defaultDailyReviewCount = 10;
  static const int _defaultDailyNewCount = 20;
  static const String _defaultUsername = '用户';
  
  int _dailyReviewCount = _defaultDailyReviewCount;
  int _dailyNewCount = _defaultDailyNewCount;
  String? _currentWordbookId;
  String _username = _defaultUsername;
  bool _isLoading = true;

  int get dailyReviewCount => _dailyReviewCount;
  int get dailyNewCount => _dailyNewCount;
  int get dailyTotalCount => _dailyReviewCount + _dailyNewCount;
  String? get currentWordbookId => _currentWordbookId;
  String get username => _username;
  bool get isLoading => _isLoading;

  SettingsService() {
    _loadSettings();
  }

  /// 从 SQLite 加载设置
  Future<void> _loadSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await AppDatabase.instance.database;
      
      // 加载每日复习数量
      final reviewCountRow = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: [_keyDailyReviewCount],
      );
      if (reviewCountRow.isNotEmpty) {
        _dailyReviewCount = int.tryParse(reviewCountRow.first['value'] as String? ?? '') ?? _defaultDailyReviewCount;
      }
      
      // 加载每日新学数量
      final newCountRow = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: [_keyDailyNewCount],
      );
      if (newCountRow.isNotEmpty) {
        _dailyNewCount = int.tryParse(newCountRow.first['value'] as String? ?? '') ?? _defaultDailyNewCount;
      }
      
      // 加载当前词库ID
      final wordbookIdRow = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: [_keyCurrentWordbookId],
      );
      if (wordbookIdRow.isNotEmpty) {
        _currentWordbookId = wordbookIdRow.first['value'] as String?;
      }
      
      // 加载用户名
      final usernameRow = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: [_keyUsername],
      );
      if (usernameRow.isNotEmpty) {
        _username = usernameRow.first['value'] as String? ?? _defaultUsername;
      }
    } catch (e) {
      print('加载设置错误: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 设置每日复习数量
  Future<void> setDailyReviewCount(int count) async {
    if (count < 0) return;
    
    _dailyReviewCount = count;
    notifyListeners();

    try {
      final db = await AppDatabase.instance.database;
      await db.insert(
        'settings',
        {'key': _keyDailyReviewCount, 'value': count.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('保存每日复习数量错误: $e');
    }
  }

  /// 设置每日新学数量
  Future<void> setDailyNewCount(int count) async {
    if (count < 0) return;
    
    _dailyNewCount = count;
    notifyListeners();

    try {
      final db = await AppDatabase.instance.database;
      await db.insert(
        'settings',
        {'key': _keyDailyNewCount, 'value': count.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('保存每日新学数量错误: $e');
    }
  }

  /// 设置每日学习量（总数量，自动分配复习和新学）
  Future<void> setDailyTotalCount(int totalCount) async {
    if (totalCount < 0) return;
    
    // 按比例分配：新学占60%，复习占40%
    _dailyNewCount = (totalCount * 0.6).round();
    _dailyReviewCount = totalCount - _dailyNewCount;
    
    notifyListeners();

    try {
      final db = await AppDatabase.instance.database;
      final batch = db.batch();
      batch.insert(
        'settings',
        {'key': _keyDailyNewCount, 'value': _dailyNewCount.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      batch.insert(
        'settings',
        {'key': _keyDailyReviewCount, 'value': _dailyReviewCount.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await batch.commit(noResult: true);
    } catch (e) {
      print('保存每日学习量错误: $e');
    }
  }

  /// 设置当前词库ID
  Future<void> setCurrentWordbookId(String? wordbookId) async {
    _currentWordbookId = wordbookId;
    notifyListeners();

    try {
      final db = await AppDatabase.instance.database;
      if (wordbookId != null) {
        await db.insert(
          'settings',
          {'key': _keyCurrentWordbookId, 'value': wordbookId},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        await db.delete(
          'settings',
          where: 'key = ?',
          whereArgs: [_keyCurrentWordbookId],
        );
      }
    } catch (e) {
      print('保存当前词库ID错误: $e');
    }
  }

  /// 设置用户名
  Future<void> setUsername(String username) async {
    if (username.trim().isEmpty) {
      _username = _defaultUsername;
    } else {
      _username = username.trim();
    }
    notifyListeners();

    try {
      final db = await AppDatabase.instance.database;
      await db.insert(
        'settings',
        {'key': _keyUsername, 'value': _username},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('保存用户名错误: $e');
    }
  }
}