import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/study_record.dart';

class StudyRecordService extends ChangeNotifier {
  static const String _keyPrefix = 'study_session_';
  static const String _wordRecordPrefix = 'word_record_'; // 单词历史记录前缀
  static const String _checkInPrefix = 'check_in_'; // 打卡记录前缀
  static const String _dailyCompletionPrefix = 'daily_completion_'; // 每日学习完成状态前缀（按词库）
  static const String _globalDailyCompletionPrefix = 'global_daily_completion_'; // 全局每日学习完成状态前缀
  static const String _cachedTotalRememberedWordsKey = 'cached_total_remembered_words'; // 缓存的已记住单词总数
  static const String _cachedTotalRememberedWordsDateKey = 'cached_total_remembered_words_date'; // 缓存日期
  SharedPreferences? _prefs;
  bool _isInitializing = false;
  int? _cachedTotalRememberedWords; // 缓存的已记住单词总数

  StudyRecordService() {
    // 在构造函数中异步初始化 SharedPreferences
    _ensureInitialized().then((_) {
      _loadCachedRememberedWords();
    });
  }

  /// 加载缓存的已记住单词总数
  Future<void> _loadCachedRememberedWords() async {
    try {
      final initialized = await _ensureInitialized();
      if (!initialized || _prefs == null) return;

      final cachedDateStr = _prefs!.getString(_cachedTotalRememberedWordsDateKey);
      final todayStr = _getTodayDateString();
      
      // 如果缓存日期是今天，加载缓存值
      if (cachedDateStr == todayStr) {
        _cachedTotalRememberedWords = _prefs!.getInt(_cachedTotalRememberedWordsKey);
      }
    } catch (e) {
      print('加载缓存的已记住单词总数错误: $e');
    }
  }

  /// 初始化 SharedPreferences
  Future<bool> _ensureInitialized() async {
    if (_prefs != null) return true;
    if (_isInitializing) {
      // 如果正在初始化，等待完成
      int retries = 0;
      while (_isInitializing && retries < 10) {
        await Future.delayed(const Duration(milliseconds: 100));
        retries++;
      }
      return _prefs != null;
    }

    _isInitializing = true;
    try {
      // 重试机制：最多重试3次
      for (int i = 0; i < 3; i++) {
        try {
          _prefs = await SharedPreferences.getInstance();
          _isInitializing = false;
          return true;
        } catch (e) {
          print('初始化 SharedPreferences 错误 (尝试 ${i + 1}/3): $e');
          if (i < 2) {
            await Future.delayed(Duration(milliseconds: 200 * (i + 1)));
          }
        }
      }
      _isInitializing = false;
      return false;
    } catch (e) {
      print('初始化 SharedPreferences 最终错误: $e');
      _isInitializing = false;
      return false;
    }
  }

  /// 获取今日日期字符串 (YYYY-MM-DD)
  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 获取某词库某天的学习完成状态：'unlearned' | 'completed'
  /// - 默认：未设置即视为 'unlearned'
  Future<String> getDailyCompletionStatus(String wordbookId, {DateTime? date}) async {
    try {
      final initialized = await _ensureInitialized();
      if (!initialized || _prefs == null) return 'unlearned';
      final dateStr = date == null ? _getTodayDateString() : _getDateString(date);
      final key = '$_dailyCompletionPrefix${dateStr}_$wordbookId';
      return _prefs!.getString(key) ?? 'unlearned';
    } catch (e) {
      print('获取每日完成状态错误: $e');
      return 'unlearned';
    }
  }

  /// 设置某词库某天的学习完成状态：'unlearned' | 'completed'
  Future<void> setDailyCompletionStatus(
    String wordbookId,
    String status, {
    DateTime? date,
  }) async {
    try {
      final initialized = await _ensureInitialized();
      if (!initialized || _prefs == null) {
        print('SharedPreferences 未初始化，无法保存每日完成状态');
        return;
      }
      final dateStr = date == null ? _getTodayDateString() : _getDateString(date);
      final key = '$_dailyCompletionPrefix${dateStr}_$wordbookId';
      await _prefs!.setString(key, status);
      notifyListeners();
    } catch (e) {
      print('保存每日完成状态错误: $e');
    }
  }

  /// 获取指定日期的日期字符串 (YYYY-MM-DD)
  String _getDateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 获取全局今日学习完成状态：'unlearned' | 'completed'
  /// - 默认：未设置即视为 'unlearned'
  Future<String> getGlobalDailyCompletionStatus({DateTime? date}) async {
    try {
      final initialized = await _ensureInitialized();
      if (!initialized || _prefs == null) return 'unlearned';
      final dateStr = date == null ? _getTodayDateString() : _getDateString(date);
      final key = '$_globalDailyCompletionPrefix$dateStr';
      return _prefs!.getString(key) ?? 'unlearned';
    } catch (e) {
      print('获取全局每日完成状态错误: $e');
      return 'unlearned';
    }
  }

  /// 设置全局今日学习完成状态：'unlearned' | 'completed'
  /// 同时自动签到（如果状态为 'completed'）
  Future<void> setGlobalDailyCompletionStatus(String status, {DateTime? date}) async {
    try {
      final initialized = await _ensureInitialized();
      if (!initialized || _prefs == null) {
        print('SharedPreferences 未初始化，无法保存全局完成状态');
        return;
      }
      final targetDate = date ?? DateTime.now();
      final dateStr = _getDateString(targetDate);
      final key = '$_globalDailyCompletionPrefix$dateStr';
      await _prefs!.setString(key, status);
      
      // 如果设置为完成，自动签到
      if (status == 'completed') {
        final checkInDateStr = _getDateString(targetDate);
        final checkInKey = '$_checkInPrefix$checkInDateStr';
        final checkInTime = DateTime.now().toIso8601String();
        await _prefs!.setString(checkInKey, checkInTime);
        print('全局学习完成，已自动签到: $checkInDateStr');
      }
      
      notifyListeners();
    } catch (e) {
      print('保存全局完成状态错误: $e');
    }
  }

  /// 检查并更新全局完成状态
  /// 如果今日学习的唯一单词数 >= 每日学习量，则设置为完成
  Future<void> checkAndUpdateGlobalCompletionStatus(int dailyTarget) async {
    try {
      // 先检查是否已经完成
      final currentStatus = await getGlobalDailyCompletionStatus();
      if (currentStatus == 'completed') {
        return; // 已经完成，不需要重复检查
      }

      // 获取今日学习会话
      final session = await getTodaySession();
      if (session == null) return;

      // 统计今日学习的唯一单词数（去重）
      final Map<String, String> wordFinalStatus = {};
      for (var record in session.records) {
        wordFinalStatus[record.word] = record.status;
      }
      final uniqueWordCount = wordFinalStatus.length;

      // 如果达到每日目标，设置为完成
      if (uniqueWordCount >= dailyTarget) {
        await setGlobalDailyCompletionStatus('completed');
        print('今日学习完成：已学习 $uniqueWordCount 个单词，目标 $dailyTarget');
      }
    } catch (e) {
      print('检查全局完成状态错误: $e');
    }
  }

  /// 获取今日学习会话
  Future<DailyStudySession?> getTodaySession() async {
    try {
      // 确保 SharedPreferences 已初始化
      final initialized = await _ensureInitialized();
      if (!initialized || _prefs == null) {
        print('SharedPreferences 未初始化，返回空会话');
        final date = _getTodayDateString();
        return DailyStudySession(
          date: date,
          records: [],
          accumulatedSeconds: 0,
        );
      }

      final date = _getTodayDateString();
      final key = '$_keyPrefix$date';
      final jsonString = _prefs!.getString(key);

      if (jsonString == null) {
        return DailyStudySession(
          date: date,
          records: [],
          accumulatedSeconds: 0,
        );
      }

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return DailyStudySession.fromJson(json);
    } catch (e) {
      print('获取今日学习会话错误: $e');
      // 如果出错，返回一个空会话而不是 null
      final date = _getTodayDateString();
      return DailyStudySession(
        date: date,
        records: [],
        accumulatedSeconds: 0,
      );
    }
  }

  /// 获取单词的所有历史记录（跨日期）
  Future<List<StudyRecord>> getWordHistory(String word, String wordbookId) async {
    try {
      final initialized = await _ensureInitialized();
      if (!initialized || _prefs == null) return [];
      
      final key = '$_wordRecordPrefix${wordbookId}_$word';
      final jsonString = _prefs!.getString(key);
      
      if (jsonString == null) return [];
      
      final json = jsonDecode(jsonString) as List<dynamic>;
      return json.map((r) => StudyRecord.fromJson(r as Map<String, dynamic>)).toList();
    } catch (e) {
      print('获取单词历史记录错误: $e');
      return [];
    }
  }
  
  /// 保存单词的历史记录
  Future<void> _saveWordHistory(String word, String wordbookId, StudyRecord record) async {
    try {
      final initialized = await _ensureInitialized();
      if (!initialized || _prefs == null) {
        print('_saveWordHistory: SharedPreferences 未初始化，无法保存单词 $word 的历史记录');
        return;
      }
      
      final key = '$_wordRecordPrefix${wordbookId}_$word';
      final history = await getWordHistory(word, wordbookId);
      
      print('_saveWordHistory: 单词 $word (词库: $wordbookId) 的现有历史记录数量: ${history.length}');
      print('_saveWordHistory: 准备保存的记录 - 状态: ${record.status}, 时间: ${record.studyTime}');
      
      // 添加新记录
      history.add(record);
      
      // 保存（只保留最近3条记录）
      final recordsToSave = history.length > 3 
          ? history.sublist(history.length - 3)
          : history;
      
      final json = recordsToSave.map((r) => r.toJson()).toList();
      await _prefs!.setString(key, jsonEncode(json));
      
      print('_saveWordHistory: 单词 $word 的历史记录已保存，共 ${recordsToSave.length} 条');
    } catch (e) {
      print('保存单词历史记录错误: $e');
    }
  }

  /// 保存学习记录（更新版本，包含复习信息）
  Future<void> saveRecord(StudyRecord record) async {
    try {
      // 保存到今日会话
      final session = await getTodaySession();
      if (session != null) {
        final updatedRecords = List<StudyRecord>.from(session.records);
        updatedRecords.add(record);
        
        final updatedSession = DailyStudySession(
          date: session.date,
          startTime: session.startTime,
          endTime: session.endTime,
          accumulatedSeconds: session.accumulatedSeconds,
          records: updatedRecords,
        );
        
        await _saveSession(updatedSession);
      }
      
      // 保存到历史记录
      await _saveWordHistory(record.word, record.wordbookId, record);
      
      // 如果单词状态变为 remembered，清除已记住单词总数的缓存
      if (record.status == 'remembered') {
        invalidateRememberedWordsCache();
      }
      
      notifyListeners();
    } catch (e) {
      print('保存学习记录错误: $e');
    }
  }

  /// 更新学习会话的开始时间
  Future<void> updateStartTime(DateTime startTime) async {
    try {
      final session = await getTodaySession();
      if (session == null) return;

      final updatedSession = DailyStudySession(
        date: session.date,
        startTime: startTime,
        endTime: null,
        accumulatedSeconds: session.accumulatedSeconds,
        records: session.records,
      );

      await _saveSession(updatedSession);
      notifyListeners();
    } catch (e) {
      print('更新开始时间错误: $e');
    }
  }

  /// 更新学习会话的结束时间
  Future<void> updateEndTime(DateTime endTime) async {
    try {
      final session = await getTodaySession();
      if (session == null) return;

      final updatedSession = DailyStudySession(
        date: session.date,
        startTime: session.startTime,
        endTime: endTime,
        accumulatedSeconds: session.accumulatedSeconds,
        records: session.records,
      );

      await _saveSession(updatedSession);
      notifyListeners();
    } catch (e) {
      print('更新结束时间错误: $e');
    }
  }

  /// 累计学习时长
  /// - 进入学习页面：本次从0开始计时（覆盖 startTime）
  /// - 退出/完成：把本次时长加入到今日累计 accumulatedSeconds，并清空 startTime/endTime
  Future<void> accumulateStudyTime(DateTime currentTime, {bool isEntering = true}) async {
    try {
      final session = await getTodaySession();
      if (session == null) return;

      if (isEntering) {
        final updated = DailyStudySession(
          date: session.date,
          startTime: currentTime,
          endTime: null,
          accumulatedSeconds: session.accumulatedSeconds,
          records: session.records,
        );
        await _saveSession(updated);
        notifyListeners();
      } else {
        if (session.startTime == null) return;
        final delta = currentTime.difference(session.startTime!).inSeconds;
        final safeDelta = delta < 0 ? 0 : delta;
        final updated = DailyStudySession(
          date: session.date,
          startTime: null,
          endTime: null,
          accumulatedSeconds: session.accumulatedSeconds + safeDelta,
          records: session.records,
        );
        await _saveSession(updated);
        notifyListeners();
      }
    } catch (e) {
      print('累计学习时长错误: $e');
    }
  }

  /// 保存学习会话
  Future<void> _saveSession(DailyStudySession session) async {
    try {
      // 确保 SharedPreferences 已初始化
      final initialized = await _ensureInitialized();
      if (!initialized || _prefs == null) {
        print('SharedPreferences 未初始化，无法保存会话');
        return;
      }

      final key = '$_keyPrefix${session.date}';
      final jsonString = jsonEncode(session.toJson());
      await _prefs!.setString(key, jsonString);
    } catch (e) {
      print('保存学习会话错误: $e');
    }
  }

  /// 获取单词的最终状态（跨所有日期）
  Future<String?> getWordFinalStatus(String word, String wordbookId) async {
    try {
      final history = await getWordHistory(word, wordbookId);
      if (history.isEmpty) return null;
      
      // 按时间排序，返回最后一次的状态
      history.sort((a, b) => b.studyTime.compareTo(a.studyTime));
      return history.first.status;
    } catch (e) {
      print('获取单词最终状态错误: $e');
      return null;
    }
  }

  /// 获取单词的学习次数
  Future<int> getWordStudyCount(String word, String wordbookId) async {
    try {
      final session = await getTodaySession();
      if (session == null) return 0;

      return session.records
          .where((r) => r.word == word && r.wordbookId == wordbookId)
          .length;
    } catch (e) {
      print('获取单词学习次数错误: $e');
      return 0;
    }
  }

  /// 获取需要复习的单词列表（根据遗忘曲线）
  /// 检查最近三次状态，如果有"不熟"或"不会"则加入复习
  Future<List<String>> getReviewWords(String wordbookId, {int limit = 50}) async {
    try {
      final initialized = await _ensureInitialized();
      if (!initialized || _prefs == null) {
        print('getReviewWords: SharedPreferences 未初始化');
        return [];
      }
      
      // 获取所有单词记录
      final allKeys = _prefs!.getKeys()
          .where((key) => key.startsWith('$_wordRecordPrefix${wordbookId}_'))
          .toList();
      
      print('getReviewWords: 找到 ${allKeys.length} 个单词记录，词库ID: $wordbookId');
      print('getReviewWords: 所有记录键: $allKeys');
      
      final now = DateTime.now();
      final reviewWordsWithDate = <MapEntry<String, DateTime>>[];
      
      for (var key in allKeys) {
        final word = key.replaceFirst('$_wordRecordPrefix${wordbookId}_', '');
        final history = await getWordHistory(word, wordbookId);
        
        print('getReviewWords: 单词 $word 的历史记录数量: ${history.length}');
        
        if (history.isEmpty) continue;
        
        // 按时间排序，获取最近的学习记录
        history.sort((a, b) => b.studyTime.compareTo(a.studyTime));
        
        // 获取最近三次状态（最多三次）
        final recentStatuses = history.take(3).map((r) => r.status).toList();
        print('getReviewWords: 单词 $word 的最近三次状态: $recentStatuses');
        
        // 检查最近三次状态中是否有"不熟"或"不会"
        final hasForgottenOrUnknown = recentStatuses.any(
          (status) => status == 'forgotten' || status == 'unknown'
        );
        
        print('getReviewWords: 单词 $word 是否有不熟/不会: $hasForgottenOrUnknown');
        
        // 如果最近三次状态中有"不熟"或"不会"，则需要复习
        if (hasForgottenOrUnknown) {
          // 获取最后一次学习记录
          final lastRecord = history.first;
          
          // 确定复习日期：如果有下次复习日期且已到时间，使用它；否则使用当前时间
          DateTime reviewDate;
          if (lastRecord.nextReviewDate != null && 
              (now.isAfter(lastRecord.nextReviewDate!) || 
               now.isAtSameMomentAs(lastRecord.nextReviewDate!))) {
            reviewDate = lastRecord.nextReviewDate!;
          } else {
            // 如果没有下次复习日期或还没到时间，但最近三次状态中有不熟/不会，也需要复习
            reviewDate = now;
          }
          
          print('getReviewWords: 单词 $word 需要复习，复习日期: $reviewDate');
          reviewWordsWithDate.add(MapEntry(word, reviewDate));
        }
      }
      
      // 按下次复习日期排序，优先复习更早的
      reviewWordsWithDate.sort((a, b) => a.value.compareTo(b.value));
      
      final result = reviewWordsWithDate.map((e) => e.key).take(limit).toList();
      print('getReviewWords: 最终返回 ${result.length} 个需要复习的单词: $result');
      
      return result;
    } catch (e) {
      print('获取复习单词列表错误: $e');
      return [];
    }
  }
  
  /// 获取学会的单词数量（最终状态为 remembered）
  Future<int> getLearnedWordCount(String wordbookId) async {
    try {
      final initialized = await _ensureInitialized();
      if (!initialized || _prefs == null) return 0;
      
      // 获取所有单词记录
      final allKeys = _prefs!.getKeys()
          .where((key) => key.startsWith('$_wordRecordPrefix${wordbookId}_'))
          .toList();
      
      int learnedCount = 0;
      
      for (var key in allKeys) {
        final word = key.replaceFirst('$_wordRecordPrefix${wordbookId}_', '');
        final finalStatus = await getWordFinalStatus(word, wordbookId);
        
        if (finalStatus == 'remembered') {
          learnedCount++;
        }
      }
      
      return learnedCount;
    } catch (e) {
      print('获取学会单词数量错误: $e');
      return 0;
    }
  }

  /// 获取词库进度统计（熟悉/不熟/未选）
  /// 返回 Map: {'familiar': 熟悉数量, 'unfamiliar': 不熟数量, 'unselected': 未选数量}
  /// 统计规则：如果最近3次历史记录中存在2次或以上"不熟"或"不会"，则计入"不熟"
  Future<Map<String, int>> getWordbookProgress(String wordbookId, int totalWords) async {
    try {
      final initialized = await _ensureInitialized();
      if (!initialized || _prefs == null) {
        return {
          'familiar': 0,
          'unfamiliar': 0,
          'unselected': totalWords,
        };
      }
      
      // 获取所有单词记录
      final allKeys = _prefs!.getKeys()
          .where((key) => key.startsWith('$_wordRecordPrefix${wordbookId}_'))
          .toList();
      
      int familiarCount = 0; // 熟悉（remembered）
      int unfamiliarCount = 0; // 不熟（forgotten + unknown）
      final Set<String> studiedWords = {}; // 已学习的单词集合
      
      for (var key in allKeys) {
        final word = key.replaceFirst('$_wordRecordPrefix${wordbookId}_', '');
        studiedWords.add(word.toLowerCase());
        
        // 获取单词的历史记录
        final history = await getWordHistory(word, wordbookId);
        if (history.isEmpty) continue;
        
        // 按时间排序，获取最近3次记录
        history.sort((a, b) => b.studyTime.compareTo(a.studyTime));
        final recentRecords = history.take(3).toList();
        
        // 统计最近3次中"不熟"或"不会"的次数
        int forgottenOrUnknownCount = recentRecords
            .where((r) => r.status == 'forgotten' || r.status == 'unknown')
            .length;
        
        // 获取最终状态（最后一次记录的状态）
        final finalStatus = recentRecords.first.status;
        
        // 如果最近3次记录中有2次或以上是"不熟"或"不会"，则计入"不熟"
        if (forgottenOrUnknownCount >= 2) {
          unfamiliarCount++;
        } else {
          // 否则按照最终状态判断
          if (finalStatus == 'remembered') {
            familiarCount++;
          } else if (finalStatus == 'forgotten' || finalStatus == 'unknown') {
            unfamiliarCount++;
          }
        }
      }
      
      // 未选 = 总单词数 - 已学习的单词数
      // 注意：这里需要知道词库中实际有多少单词，但我们已经有了totalWords参数
      // 但是studiedWords只包含有记录的单词，可能词库中的某些单词还没有被学习过
      // 所以未选数量 = totalWords - familiarCount - unfamiliarCount
      int unselectedCount = totalWords - familiarCount - unfamiliarCount;
      if (unselectedCount < 0) unselectedCount = 0;
      
      return {
        'familiar': familiarCount,
        'unfamiliar': unfamiliarCount,
        'unselected': unselectedCount,
      };
    } catch (e) {
      print('获取词库进度统计错误: $e');
      return {
        'familiar': 0,
        'unfamiliar': 0,
        'unselected': totalWords,
      };
    }
  }

  /// 获取学习进度（用于恢复）
  Future<Map<String, dynamic>> getStudyProgress(String wordbookId) async {
    try {
      final session = await getTodaySession();
      if (session == null) {
        return {
          'current_index': 0,
          'word_statuses': <String, String>{},
          'word_study_counts': <String, int>{},
        };
      }

      // 获取该词库的所有记录
      final wordbookRecords = session.records
          .where((r) => r.wordbookId == wordbookId)
          .toList();

      // 构建单词状态映射（最终状态）
      final Map<String, String> wordStatuses = {};
      final Map<String, int> wordStudyCounts = {};

      for (var record in wordbookRecords) {
        // 更新最终状态（后面的记录覆盖前面的）
        wordStatuses[record.word] = record.status;
        // 累计学习次数
        wordStudyCounts[record.word] =
            (wordStudyCounts[record.word] ?? 0) + 1;
      }

      // 找到当前学习位置（第一个未完成或需要复习的单词）
      // 这里返回一个标记，实际位置由 WordService 根据单词列表确定
      return {
        'current_index': 0, // 由 WordService 计算
        'word_statuses': wordStatuses,
        'word_study_counts': wordStudyCounts,
      };
    } catch (e) {
      print('获取学习进度错误: $e');
      return {
        'current_index': 0,
        'word_statuses': <String, String>{},
        'word_study_counts': <String, int>{},
      };
    }
  }

  /// 获取指定日期的学习会话
  Future<DailyStudySession?> getSessionByDate(DateTime date) async {
    try {
      final initialized = await _ensureInitialized();
      if (!initialized || _prefs == null) {
        final dateStr = _getDateString(date);
        return DailyStudySession(
          date: dateStr,
          records: [],
        );
      }

      final dateStr = _getDateString(date);
      final key = '$_keyPrefix$dateStr';
      final jsonString = _prefs!.getString(key);

      if (jsonString == null) {
        return DailyStudySession(
          date: dateStr,
          records: [],
        );
      }

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return DailyStudySession.fromJson(json);
    } catch (e) {
      print('获取指定日期学习会话错误: $e');
      final dateStr = _getDateString(date);
      return DailyStudySession(
        date: dateStr,
        records: [],
      );
    }
  }

  /// 获取指定日期是否已打卡
  Future<bool> isCheckedIn(DateTime date) async {
    try {
      final initialized = await _ensureInitialized();
      if (!initialized || _prefs == null) return false;

      final dateStr = _getDateString(date);
      final key = '$_checkInPrefix$dateStr';
      final checkInTime = _prefs!.getString(key);
      return checkInTime != null && checkInTime.isNotEmpty;
    } catch (e) {
      print('获取打卡状态错误: $e');
      return false;
    }
  }

  /// 获取指定日期的打卡时间
  Future<DateTime?> getCheckInTime(DateTime date) async {
    try {
      final initialized = await _ensureInitialized();
      if (!initialized || _prefs == null) return null;

      final dateStr = _getDateString(date);
      final key = '$_checkInPrefix$dateStr';
      final checkInTimeStr = _prefs!.getString(key);
      
      if (checkInTimeStr == null || checkInTimeStr.isEmpty) {
        return null;
      }
      
      return DateTime.parse(checkInTimeStr);
    } catch (e) {
      print('获取打卡时间错误: $e');
      return null;
    }
  }

  /// 保存打卡记录（包含时间戳）
  Future<void> checkIn(DateTime date) async {
    try {
      final initialized = await _ensureInitialized();
      if (!initialized || _prefs == null) {
        print('SharedPreferences 未初始化，无法保存打卡记录');
        return;
      }

      final dateStr = _getDateString(date);
      final key = '$_checkInPrefix$dateStr';
      final checkInTime = DateTime.now().toIso8601String();
      await _prefs!.setString(key, checkInTime);
      notifyListeners();
    } catch (e) {
      print('保存打卡记录错误: $e');
    }
  }

  /// 获取指定月份的所有打卡日期
  Future<Set<DateTime>> getCheckedInDatesForMonth(DateTime month) async {
    try {
      final initialized = await _ensureInitialized();
      if (!initialized || _prefs == null) return {};

      final checkedInDates = <DateTime>{};
      final allKeys = _prefs!.getKeys()
          .where((key) => key.startsWith(_checkInPrefix))
          .toList();

      for (var key in allKeys) {
        final dateStr = key.replaceFirst(_checkInPrefix, '');
        try {
          final date = DateTime.parse(dateStr);
          // 检查是否在指定月份
          if (date.year == month.year && date.month == month.month) {
            checkedInDates.add(DateTime(date.year, date.month, date.day));
          }
        } catch (e) {
          print('解析日期错误: $dateStr, $e');
        }
      }

      return checkedInDates;
    } catch (e) {
      print('获取月份打卡日期错误: $e');
      return {};
    }
  }

  /// 获取指定月份的所有打卡记录（包含时间）
  Future<Map<DateTime, DateTime>> getCheckedInRecordsForMonth(DateTime month) async {
    try {
      final initialized = await _ensureInitialized();
      if (!initialized || _prefs == null) return {};

      final checkedInRecords = <DateTime, DateTime>{};
      final allKeys = _prefs!.getKeys()
          .where((key) => key.startsWith(_checkInPrefix))
          .toList();

      for (var key in allKeys) {
        final dateStr = key.replaceFirst(_checkInPrefix, '');
        try {
          final date = DateTime.parse(dateStr);
          // 检查是否在指定月份
          if (date.year == month.year && date.month == month.month) {
            final checkInTimeStr = _prefs!.getString(key);
            if (checkInTimeStr != null && checkInTimeStr.isNotEmpty) {
              final checkInTime = DateTime.parse(checkInTimeStr);
              checkedInRecords[DateTime(date.year, date.month, date.day)] = checkInTime;
            }
          }
        } catch (e) {
          print('解析打卡记录错误: $dateStr, $e');
        }
      }

      return checkedInRecords;
    } catch (e) {
      print('获取月份打卡记录错误: $e');
      return {};
    }
  }

  /// 获取指定月份所有日期的全局完成状态
  /// 返回 Map<DateTime, String>，其中 String 为 'unlearned' | 'completed'
  Future<Map<DateTime, String>> getGlobalDailyCompletionStatusForMonth(DateTime month) async {
    try {
      final initialized = await _ensureInitialized();
      if (!initialized || _prefs == null) return {};

      final completionStatusMap = <DateTime, String>{};
      final allKeys = _prefs!.getKeys()
          .where((key) => key.startsWith(_globalDailyCompletionPrefix))
          .toList();

      for (var key in allKeys) {
        final dateStr = key.replaceFirst(_globalDailyCompletionPrefix, '');
        try {
          // 解析日期字符串（格式：YYYY-MM-DD），只使用年月日部分
          final dateParts = dateStr.split('-');
          if (dateParts.length == 3) {
            final year = int.parse(dateParts[0]);
            final monthValue = int.parse(dateParts[1]);
            final day = int.parse(dateParts[2]);
            final date = DateTime(year, monthValue, day);
            // 检查是否在指定月份
            if (date.year == month.year && date.month == month.month) {
              final status = _prefs!.getString(key) ?? 'unlearned';
              completionStatusMap[DateTime(date.year, date.month, date.day)] = status;
            }
          }
        } catch (e) {
          print('解析全局完成状态错误: $dateStr, $e');
        }
      }

      return completionStatusMap;
    } catch (e) {
      print('获取月份全局完成状态错误: $e');
      return {};
    }
  }

  /// 获取连续签到天数
  Future<int> getConsecutiveCheckInDays() async {
    try {
      final initialized = await _ensureInitialized();
      if (!initialized || _prefs == null) return 0;

      final allKeys = _prefs!.getKeys()
          .where((key) => key.startsWith(_checkInPrefix))
          .toList();

      if (allKeys.isEmpty) return 0;

      // 解析所有签到日期并排序
      final checkInDates = <DateTime>[];
      for (var key in allKeys) {
        final dateStr = key.replaceFirst(_checkInPrefix, '');
        try {
          final date = DateTime.parse(dateStr);
          checkInDates.add(DateTime(date.year, date.month, date.day));
        } catch (e) {
          print('解析签到日期错误: $dateStr, $e');
        }
      }

      if (checkInDates.isEmpty) return 0;

      // 去重并排序（从新到旧）
      checkInDates.sort((a, b) => b.compareTo(a));
      final uniqueDates = <DateTime>[];
      for (var date in checkInDates) {
        if (uniqueDates.isEmpty || uniqueDates.last != date) {
          uniqueDates.add(date);
        }
      }

      // 计算连续签到天数
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      int consecutiveDays = 0;
      DateTime expectedDate = todayDate;

      for (var checkInDate in uniqueDates) {
        if (checkInDate == expectedDate) {
          consecutiveDays++;
          expectedDate = expectedDate.subtract(const Duration(days: 1));
        } else if (checkInDate.isBefore(expectedDate)) {
          // 如果签到日期早于预期日期，说明中断了
          break;
        }
      }

      return consecutiveDays;
    } catch (e) {
      print('获取连续签到天数错误: $e');
      return 0;
    }
  }

  /// 获取累积签到天数
  Future<int> getTotalCheckInDays() async {
    try {
      final initialized = await _ensureInitialized();
      if (!initialized || _prefs == null) return 0;

      final allKeys = _prefs!.getKeys()
          .where((key) => key.startsWith(_checkInPrefix))
          .toList();

      // 统计有效的签到记录
      final checkInDates = <String>{};
      for (var key in allKeys) {
        final dateStr = key.replaceFirst(_checkInPrefix, '');
        final checkInTimeStr = _prefs!.getString(key);
        if (checkInTimeStr != null && checkInTimeStr.isNotEmpty) {
          checkInDates.add(dateStr);
        }
      }

      return checkInDates.length;
    } catch (e) {
      print('获取累积签到天数错误: $e');
      return 0;
    }
  }

  /// 获取累积学习小时数
  Future<int> getTotalStudyHours() async {
    try {
      final initialized = await _ensureInitialized();
      if (!initialized || _prefs == null) return 0;

      final allKeys = _prefs!.getKeys()
          .where((key) => key.startsWith(_keyPrefix))
          .toList();

      int totalSeconds = 0;

      for (var key in allKeys) {
        try {
          final jsonString = _prefs!.getString(key);
          if (jsonString == null || jsonString.isEmpty) continue;

          final json = jsonDecode(jsonString) as Map<String, dynamic>;
          final accumulatedSeconds = json['accumulated_seconds'] as int? ?? 0;
          totalSeconds += accumulatedSeconds;
        } catch (e) {
          print('解析学习会话错误: $key, $e');
        }
      }

      // 转换为小时（向上取整）
      return (totalSeconds / 3600).ceil();
    } catch (e) {
      print('获取累积学习小时数错误: $e');
      return 0;
    }
  }

  /// 获取所有词库已记住的单词总数（带缓存优化）
  /// 缓存策略：如果缓存存在且是今天的数据，直接返回缓存；否则重新计算并更新缓存
  Future<int> getTotalRememberedWordsCount({bool forceRefresh = false}) async {
    try {
      final initialized = await _ensureInitialized();
      if (!initialized || _prefs == null) return 0;

      // 检查缓存
      if (!forceRefresh && _cachedTotalRememberedWords != null) {
        final cachedDateStr = _prefs!.getString(_cachedTotalRememberedWordsDateKey);
        final todayStr = _getTodayDateString();
        if (cachedDateStr == todayStr) {
          return _cachedTotalRememberedWords!;
        }
      }

      // 重新计算
      final allKeys = _prefs!.getKeys()
          .where((key) => key.startsWith(_wordRecordPrefix))
          .toList();

      final wordbookIds = <String>{};
      for (var key in allKeys) {
        // 键名格式：word_record_{wordbookId}_{word}
        final parts = key.replaceFirst(_wordRecordPrefix, '').split('_');
        if (parts.isNotEmpty) {
          wordbookIds.add(parts[0]);
        }
      }

      int totalRemembered = 0;
      for (var wordbookId in wordbookIds) {
        final count = await getLearnedWordCount(wordbookId);
        totalRemembered += count;
      }

      // 更新缓存
      _cachedTotalRememberedWords = totalRemembered;
      await _prefs!.setInt(_cachedTotalRememberedWordsKey, totalRemembered);
      await _prefs!.setString(_cachedTotalRememberedWordsDateKey, _getTodayDateString());

      return totalRemembered;
    } catch (e) {
      print('获取已记住单词总数错误: $e');
      return 0;
    }
  }

  /// 当单词状态变化时，清除缓存（需要在标记单词状态时调用）
  void invalidateRememberedWordsCache() {
    _cachedTotalRememberedWords = null;
  }

  /// 获取平均每日学习单词量（按总天数计算）
  /// 总天数 = 从首次学习日期到今天的天数
  Future<double> getAvgDailyStudyWords() async {
    try {
      final initialized = await _ensureInitialized();
      if (!initialized || _prefs == null) return 0.0;

      final allKeys = _prefs!.getKeys()
          .where((key) => key.startsWith(_keyPrefix))
          .toList();

      if (allKeys.isEmpty) return 0.0;

      int totalWords = 0;
      DateTime? firstStudyDate;

      for (var key in allKeys) {
        try {
          final jsonString = _prefs!.getString(key);
          if (jsonString == null || jsonString.isEmpty) continue;

          final json = jsonDecode(jsonString) as Map<String, dynamic>;
          final dateStr = json['date'] as String?;
          final records = json['records'] as List<dynamic>? ?? [];

          if (dateStr != null && records.isNotEmpty) {
            // 解析日期
            try {
              final date = DateTime.parse(dateStr);
              if (firstStudyDate == null || date.isBefore(firstStudyDate)) {
                firstStudyDate = date;
              }
            } catch (e) {
              print('解析日期错误: $dateStr, $e');
            }

            // 统计该日期的唯一单词数
            final uniqueWords = <String>{};
            for (var record in records) {
              final word = record['word'] as String?;
              if (word != null) {
                uniqueWords.add(word);
              }
            }
            totalWords += uniqueWords.length;
          }
        } catch (e) {
          print('解析学习会话错误: $key, $e');
        }
      }

      if (firstStudyDate == null) return 0.0;

      // 计算总天数（从首次学习日期到今天）
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final firstDate = DateTime(firstStudyDate.year, firstStudyDate.month, firstStudyDate.day);
      final totalDays = todayDate.difference(firstDate).inDays + 1; // +1 包含今天

      if (totalDays <= 0) return 0.0;
      return totalWords / totalDays;
    } catch (e) {
      print('获取平均每日学习单词量错误: $e');
      return 0.0;
    }
  }

  /// 重置词库状态（清除该词库的所有学习记录）
  /// 包括：
  /// 1. 单词历史记录（word_record_{wordbookId}_*）
  /// 2. 学习会话记录中该词库的记录（从 study_session_* 中移除该词库的记录）
  /// 3. 每日完成状态（daily_completion_{date}_{wordbookId}）
  /// 4. 清除已记住单词总数的缓存
  Future<void> resetWordbook(String wordbookId) async {
    try {
      final initialized = await _ensureInitialized();
      if (!initialized || _prefs == null) {
        print('SharedPreferences 未初始化，无法重置词库');
        return;
      }

      // 1. 清除单词历史记录
      final wordRecordKeys = _prefs!.getKeys()
          .where((key) => key.startsWith('$_wordRecordPrefix${wordbookId}_'))
          .toList();
      
      for (var key in wordRecordKeys) {
        await _prefs!.remove(key);
      }
      print('已清除 ${wordRecordKeys.length} 条单词历史记录');

      // 2. 清除学习会话中该词库的记录
      final sessionKeys = _prefs!.getKeys()
          .where((key) => key.startsWith(_keyPrefix))
          .toList();
      
      for (var sessionKey in sessionKeys) {
        try {
          final jsonString = _prefs!.getString(sessionKey);
          if (jsonString == null || jsonString.isEmpty) continue;

          final json = jsonDecode(jsonString) as Map<String, dynamic>;
          final records = json['records'] as List<dynamic>? ?? [];
          
          // 过滤掉该词库的记录
          final filteredRecords = records
              .where((r) {
                final record = r as Map<String, dynamic>;
                return record['wordbook_id'] != wordbookId;
              })
              .toList();
          
          // 如果有变化，更新会话
          if (filteredRecords.length != records.length) {
            json['records'] = filteredRecords;
            await _prefs!.setString(sessionKey, jsonEncode(json));
          }
        } catch (e) {
          print('处理学习会话错误: $sessionKey, $e');
        }
      }
      print('已清除学习会话中该词库的记录');

      // 3. 清除每日完成状态
      final completionKeys = _prefs!.getKeys()
          .where((key) => key.startsWith('$_dailyCompletionPrefix') && key.contains('_$wordbookId'))
          .toList();
      
      for (var key in completionKeys) {
        await _prefs!.remove(key);
      }
      print('已清除 ${completionKeys.length} 条每日完成状态记录');

      // 4. 清除已记住单词总数的缓存
      invalidateRememberedWordsCache();

      notifyListeners();
      print('词库 $wordbookId 已重置');
    } catch (e) {
      print('重置词库错误: $e');
      rethrow;
    }
  }
}

