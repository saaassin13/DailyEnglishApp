import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _isInitializing = false;

  int get dailyReviewCount => _dailyReviewCount;
  int get dailyNewCount => _dailyNewCount;
  int get dailyTotalCount => _dailyReviewCount + _dailyNewCount;
  String? get currentWordbookId => _currentWordbookId;
  String get username => _username;
  bool get isLoading => _isLoading;

  SettingsService() {
    _loadSettings();
  }

  /// 初始化 SharedPreferences（带重试机制）
  Future<SharedPreferences?> _getSharedPreferences() async {
    if (_isInitializing) {
      // 如果正在初始化，等待完成
      int retries = 0;
      while (_isInitializing && retries < 10) {
        await Future.delayed(const Duration(milliseconds: 100));
        retries++;
      }
    }

    _isInitializing = true;
    try {
      // 重试机制：最多重试3次
      for (int i = 0; i < 3; i++) {
        try {
          final prefs = await SharedPreferences.getInstance();
          _isInitializing = false;
          return prefs;
        } catch (e) {
          print('初始化 SharedPreferences 错误 (尝试 ${i + 1}/3): $e');
          if (i < 2) {
            await Future.delayed(Duration(milliseconds: 200 * (i + 1)));
          }
        }
      }
      _isInitializing = false;
      return null;
    } catch (e) {
      print('初始化 SharedPreferences 最终错误: $e');
      _isInitializing = false;
      return null;
    }
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await _getSharedPreferences();
      if (prefs != null) {
        _dailyReviewCount = prefs.getInt(_keyDailyReviewCount) ?? _defaultDailyReviewCount;
        _dailyNewCount = prefs.getInt(_keyDailyNewCount) ?? _defaultDailyNewCount;
        _currentWordbookId = prefs.getString(_keyCurrentWordbookId);
        _username = prefs.getString(_keyUsername) ?? _defaultUsername;
      } else {
        // 如果 SharedPreferences 初始化失败，使用默认值
        print('SharedPreferences 未初始化，使用默认设置');
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
      final prefs = await _getSharedPreferences();
      if (prefs != null) {
        await prefs.setInt(_keyDailyReviewCount, count);
      } else {
        print('SharedPreferences 未初始化，无法保存每日复习数量');
      }
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
      final prefs = await _getSharedPreferences();
      if (prefs != null) {
        await prefs.setInt(_keyDailyNewCount, count);
      } else {
        print('SharedPreferences 未初始化，无法保存每日新学数量');
      }
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
      final prefs = await _getSharedPreferences();
      if (prefs != null) {
        await prefs.setInt(_keyDailyNewCount, _dailyNewCount);
        await prefs.setInt(_keyDailyReviewCount, _dailyReviewCount);
      } else {
        print('SharedPreferences 未初始化，无法保存每日学习量');
      }
    } catch (e) {
      print('保存每日学习量错误: $e');
    }
  }

  /// 设置当前词库ID
  Future<void> setCurrentWordbookId(String? wordbookId) async {
    _currentWordbookId = wordbookId;
    notifyListeners();

    try {
      final prefs = await _getSharedPreferences();
      if (prefs != null) {
        if (wordbookId != null) {
          await prefs.setString(_keyCurrentWordbookId, wordbookId);
        } else {
          await prefs.remove(_keyCurrentWordbookId);
        }
      } else {
        print('SharedPreferences 未初始化，无法保存当前词库ID');
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
      final prefs = await _getSharedPreferences();
      if (prefs != null) {
        await prefs.setString(_keyUsername, _username);
      } else {
        print('SharedPreferences 未初始化，无法保存用户名');
      }
    } catch (e) {
      print('保存用户名错误: $e');
    }
  }
}