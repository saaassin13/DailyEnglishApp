import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../models/study_record.dart';
import '../db/app_database.dart';

class StudyRecordService extends ChangeNotifier {
  static const String _cachedTotalRememberedWordsKey = 'cached_total_remembered_words'; // 缓存的已记住单词总数
  static const String _cachedTotalRememberedWordsDateKey = 'cached_total_remembered_words_date'; // 缓存日期
  int? _cachedTotalRememberedWords; // 缓存的已记住单词总数

  StudyRecordService() {
    // 加载缓存的已记住单词总数
    _loadCachedRememberedWords();
  }

  /// 加载缓存的已记住单词总数
  Future<void> _loadCachedRememberedWords() async {
    try {
      final db = await AppDatabase.instance.database;
      
      final cachedDateRow = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: [_cachedTotalRememberedWordsDateKey],
      );
      
      final todayStr = _getTodayDateString();
      
      // 如果缓存日期是今天，加载缓存值
      if (cachedDateRow.isNotEmpty) {
        final cachedDateStr = cachedDateRow.first['value'] as String?;
        if (cachedDateStr == todayStr) {
          final cachedCountRow = await db.query(
            'settings',
            where: 'key = ?',
            whereArgs: [_cachedTotalRememberedWordsKey],
          );
          if (cachedCountRow.isNotEmpty) {
            _cachedTotalRememberedWords = int.tryParse(cachedCountRow.first['value'] as String? ?? '');
          }
        }
      }
    } catch (e) {
      print('加载缓存的已记住单词总数错误: $e');
    }
  }

  /// 获取今日日期字符串 (YYYY-MM-DD)
  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 获取指定日期的日期字符串 (YYYY-MM-DD)
  String _getDateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 获取某词库某天的学习完成状态：'unlearned' | 'completed'
  /// - 默认：未设置即视为 'unlearned'
  Future<String> getDailyCompletionStatus(String wordbookId, {DateTime? date}) async {
    try {
      final db = await AppDatabase.instance.database;
      final dateStr = date == null ? _getTodayDateString() : _getDateString(date);
      
      final rows = await db.query(
        'daily_completion',
        where: 'date = ? AND wordbook_id = ?',
        whereArgs: [dateStr, wordbookId],
      );
      
      if (rows.isEmpty) return 'unlearned';
      return rows.first['status'] as String? ?? 'unlearned';
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
      final db = await AppDatabase.instance.database;
      final dateStr = date == null ? _getTodayDateString() : _getDateString(date);
      
      await db.insert(
        'daily_completion',
        {
          'date': dateStr,
          'wordbook_id': wordbookId,
          'status': status,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      notifyListeners();
    } catch (e) {
      print('保存每日完成状态错误: $e');
    }
  }

  /// 获取全局今日学习完成状态：'unlearned' | 'completed'
  /// - 默认：未设置即视为 'unlearned'
  Future<String> getGlobalDailyCompletionStatus({DateTime? date}) async {
    try {
      final db = await AppDatabase.instance.database;
      final dateStr = date == null ? _getTodayDateString() : _getDateString(date);
      
      final rows = await db.query(
        'global_daily_completion',
        where: 'date = ?',
        whereArgs: [dateStr],
      );
      
      if (rows.isEmpty) return 'unlearned';
      return rows.first['status'] as String? ?? 'unlearned';
    } catch (e) {
      print('获取全局每日完成状态错误: $e');
      return 'unlearned';
    }
  }

  /// 设置全局今日学习完成状态：'unlearned' | 'completed'
  /// 同时自动签到（如果状态为 'completed'）
  Future<void> setGlobalDailyCompletionStatus(String status, {DateTime? date}) async {
    try {
      final db = await AppDatabase.instance.database;
      final targetDate = date ?? DateTime.now();
      final dateStr = _getDateString(targetDate);
      
      await db.insert(
        'global_daily_completion',
        {
          'date': dateStr,
          'status': status,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      // 如果设置为完成，自动签到
      if (status == 'completed') {
        await db.insert(
          'checkins',
          {
            'date': dateStr,
            'check_in_time': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        print('全局学习完成，已自动签到: $dateStr');
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
      final db = await AppDatabase.instance.database;
      final date = _getTodayDateString();
      
      // 获取会话信息
      final sessionRows = await db.query(
        'daily_sessions',
        where: 'date = ?',
        whereArgs: [date],
      );
      
      // 获取该日期的所有学习记录
      final recordRows = await db.query(
        'study_records',
        where: 'session_date = ?',
        whereArgs: [date],
        orderBy: 'study_time ASC',
      );
      
      final records = recordRows.map((row) => StudyRecord(
        word: row['word'] as String,
        wordbookId: row['wordbook_id'] as String,
        status: row['status'] as String,
        studyTime: DateTime.parse(row['study_time'] as String),
        studyCount: row['study_count'] as int,
        nextReviewDate: row['next_review_date'] != null
            ? DateTime.parse(row['next_review_date'] as String)
            : null,
        reviewCount: row['review_count'] as int,
        intervalDays: row['interval_days'] as int,
      )).toList();
      
      if (sessionRows.isEmpty) {
        return DailyStudySession(
          date: date,
          records: records,
          accumulatedSeconds: 0,
        );
      }
      
      final sessionRow = sessionRows.first;
      return DailyStudySession(
        date: date,
        startTime: sessionRow['start_time'] != null
            ? DateTime.parse(sessionRow['start_time'] as String)
            : null,
        endTime: sessionRow['end_time'] != null
            ? DateTime.parse(sessionRow['end_time'] as String)
            : null,
        accumulatedSeconds: sessionRow['accumulated_seconds'] as int? ?? 0,
        records: records,
      );
    } catch (e) {
      print('获取今日学习会话错误: $e');
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
      final db = await AppDatabase.instance.database;
      
      final rows = await db.query(
        'study_records',
        where: 'word = ? AND wordbook_id = ?',
        whereArgs: [word, wordbookId],
        orderBy: 'study_time DESC',
        limit: 3, // 只保留最近3条记录
      );
      
      return rows.map((row) => StudyRecord(
        word: row['word'] as String,
        wordbookId: row['wordbook_id'] as String,
        status: row['status'] as String,
        studyTime: DateTime.parse(row['study_time'] as String),
        studyCount: row['study_count'] as int,
        nextReviewDate: row['next_review_date'] != null
            ? DateTime.parse(row['next_review_date'] as String)
            : null,
        reviewCount: row['review_count'] as int,
        intervalDays: row['interval_days'] as int,
      )).toList();
    } catch (e) {
      print('获取单词历史记录错误: $e');
      return [];
    }
  }

  /// 保存学习记录（更新版本，包含复习信息）
  Future<void> saveRecord(StudyRecord record) async {
    try {
      final db = await AppDatabase.instance.database;
      final todayStr = _getTodayDateString();
      
      // 确保今日会话存在
      final sessionRows = await db.query(
        'daily_sessions',
        where: 'date = ?',
        whereArgs: [todayStr],
      );
      
      if (sessionRows.isEmpty) {
        await db.insert(
          'daily_sessions',
          {
            'date': todayStr,
            'accumulated_seconds': 0,
          },
        );
      }
      
      // 保存学习记录到 study_records 表
      await db.insert(
        'study_records',
        {
          'session_date': todayStr,
          'word': record.word,
          'wordbook_id': record.wordbookId,
          'status': record.status,
          'study_time': record.studyTime.toIso8601String(),
          'study_count': record.studyCount,
          'next_review_date': record.nextReviewDate?.toIso8601String(),
          'review_count': record.reviewCount,
          'interval_days': record.intervalDays,
        },
      );
      
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
      final db = await AppDatabase.instance.database;
      final date = _getTodayDateString();
      
      // 确保会话存在
      final sessionRows = await db.query(
        'daily_sessions',
        where: 'date = ?',
        whereArgs: [date],
      );
      
      if (sessionRows.isEmpty) {
        await db.insert(
          'daily_sessions',
          {
            'date': date,
            'start_time': startTime.toIso8601String(),
            'accumulated_seconds': 0,
          },
        );
      } else {
        await db.update(
          'daily_sessions',
          {'start_time': startTime.toIso8601String()},
          where: 'date = ?',
          whereArgs: [date],
        );
      }
      
      notifyListeners();
    } catch (e) {
      print('更新开始时间错误: $e');
    }
  }

  /// 更新学习会话的结束时间
  Future<void> updateEndTime(DateTime endTime) async {
    try {
      final db = await AppDatabase.instance.database;
      final date = _getTodayDateString();
      
      await db.update(
        'daily_sessions',
        {'end_time': endTime.toIso8601String()},
        where: 'date = ?',
        whereArgs: [date],
      );
      
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
      final db = await AppDatabase.instance.database;
      final date = _getTodayDateString();
      
      final sessionRows = await db.query(
        'daily_sessions',
        where: 'date = ?',
        whereArgs: [date],
      );
      
      if (isEntering) {
        if (sessionRows.isEmpty) {
          await db.insert(
            'daily_sessions',
            {
              'date': date,
              'start_time': currentTime.toIso8601String(),
              'accumulated_seconds': 0,
            },
          );
        } else {
          await db.update(
            'daily_sessions',
            {'start_time': currentTime.toIso8601String()},
            where: 'date = ?',
            whereArgs: [date],
          );
        }
        notifyListeners();
      } else {
        if (sessionRows.isEmpty) return;
        
        final sessionRow = sessionRows.first;
        final startTimeStr = sessionRow['start_time'] as String?;
        if (startTimeStr == null) return;
        
        final startTime = DateTime.parse(startTimeStr);
        final delta = currentTime.difference(startTime).inSeconds;
        final safeDelta = delta < 0 ? 0 : delta;
        final currentAccumulated = sessionRow['accumulated_seconds'] as int? ?? 0;
        
        await db.update(
          'daily_sessions',
          {
            'start_time': null,
            'end_time': null,
            'accumulated_seconds': currentAccumulated + safeDelta,
          },
          where: 'date = ?',
          whereArgs: [date],
        );
        notifyListeners();
      }
    } catch (e) {
      print('累计学习时长错误: $e');
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
      final db = await AppDatabase.instance.database;
      
      // 获取该词库的所有单词（去重）
      final wordRows = await db.rawQuery('''
        SELECT DISTINCT word 
        FROM study_records 
        WHERE wordbook_id = ?
      ''', [wordbookId]);
      
      final now = DateTime.now();
      final reviewWordsWithDate = <MapEntry<String, DateTime>>[];
      
      for (var row in wordRows) {
        final word = row['word'] as String;
        final history = await getWordHistory(word, wordbookId);
        
        if (history.isEmpty) continue;
        
        // 按时间排序，获取最近的学习记录
        history.sort((a, b) => b.studyTime.compareTo(a.studyTime));
        
        // 获取最近三次状态（最多三次）
        final recentStatuses = history.take(3).map((r) => r.status).toList();
        
        // 检查最近三次状态中是否有"不熟"或"不会"
        final hasForgottenOrUnknown = recentStatuses.any(
          (status) => status == 'forgotten' || status == 'unknown'
        );
        
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
          
          reviewWordsWithDate.add(MapEntry(word, reviewDate));
        }
      }
      
      // 按下次复习日期排序，优先复习更早的
      reviewWordsWithDate.sort((a, b) => a.value.compareTo(b.value));
      
      final result = reviewWordsWithDate.map((e) => e.key).take(limit).toList();
      return result;
    } catch (e) {
      print('获取复习单词列表错误: $e');
      return [];
    }
  }
  
  /// 获取学会的单词数量（最终状态为 remembered）
  Future<int> getLearnedWordCount(String wordbookId) async {
    try {
      final db = await AppDatabase.instance.database;
      
      // 获取该词库的所有单词（去重）
      final wordRows = await db.rawQuery('''
        SELECT DISTINCT word 
        FROM study_records 
        WHERE wordbook_id = ?
      ''', [wordbookId]);
      
      int learnedCount = 0;
      
      for (var row in wordRows) {
        final word = row['word'] as String;
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
      final db = await AppDatabase.instance.database;
      
      // 获取该词库的所有单词（去重）
      final wordRows = await db.rawQuery('''
        SELECT DISTINCT word 
        FROM study_records 
        WHERE wordbook_id = ?
      ''', [wordbookId]);
      
      int familiarCount = 0; // 熟悉（remembered）
      int unfamiliarCount = 0; // 不熟（forgotten + unknown）
      
      for (var row in wordRows) {
        final word = row['word'] as String;
        
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
      final db = await AppDatabase.instance.database;
      final dateStr = _getDateString(date);
      
      // 获取会话信息
      final sessionRows = await db.query(
        'daily_sessions',
        where: 'date = ?',
        whereArgs: [dateStr],
      );
      
      // 获取该日期的所有学习记录
      final recordRows = await db.query(
        'study_records',
        where: 'session_date = ?',
        whereArgs: [dateStr],
        orderBy: 'study_time ASC',
      );
      
      final records = recordRows.map((row) => StudyRecord(
        word: row['word'] as String,
        wordbookId: row['wordbook_id'] as String,
        status: row['status'] as String,
        studyTime: DateTime.parse(row['study_time'] as String),
        studyCount: row['study_count'] as int,
        nextReviewDate: row['next_review_date'] != null
            ? DateTime.parse(row['next_review_date'] as String)
            : null,
        reviewCount: row['review_count'] as int,
        intervalDays: row['interval_days'] as int,
      )).toList();
      
      if (sessionRows.isEmpty) {
        return DailyStudySession(
          date: dateStr,
          records: records,
          accumulatedSeconds: 0,
        );
      }
      
      final sessionRow = sessionRows.first;
      return DailyStudySession(
        date: dateStr,
        startTime: sessionRow['start_time'] != null
            ? DateTime.parse(sessionRow['start_time'] as String)
            : null,
        endTime: sessionRow['end_time'] != null
            ? DateTime.parse(sessionRow['end_time'] as String)
            : null,
        accumulatedSeconds: sessionRow['accumulated_seconds'] as int? ?? 0,
        records: records,
      );
    } catch (e) {
      print('获取指定日期学习会话错误: $e');
      final dateStr = _getDateString(date);
      return DailyStudySession(
        date: dateStr,
        records: [],
        accumulatedSeconds: 0,
      );
    }
  }

  /// 获取指定日期是否已打卡
  Future<bool> isCheckedIn(DateTime date) async {
    try {
      final db = await AppDatabase.instance.database;
      final dateStr = _getDateString(date);
      
      final rows = await db.query(
        'checkins',
        where: 'date = ?',
        whereArgs: [dateStr],
      );
      
      return rows.isNotEmpty;
    } catch (e) {
      print('获取打卡状态错误: $e');
      return false;
    }
  }

  /// 获取指定日期的打卡时间
  Future<DateTime?> getCheckInTime(DateTime date) async {
    try {
      final db = await AppDatabase.instance.database;
      final dateStr = _getDateString(date);
      
      final rows = await db.query(
        'checkins',
        where: 'date = ?',
        whereArgs: [dateStr],
      );
      
      if (rows.isEmpty) return null;
      
      final checkInTimeStr = rows.first['check_in_time'] as String?;
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
      final db = await AppDatabase.instance.database;
      final dateStr = _getDateString(date);
      
      await db.insert(
        'checkins',
        {
          'date': dateStr,
          'check_in_time': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      notifyListeners();
    } catch (e) {
      print('保存打卡记录错误: $e');
    }
  }

  /// 获取指定月份的所有打卡日期
  Future<Set<DateTime>> getCheckedInDatesForMonth(DateTime month) async {
    try {
      final db = await AppDatabase.instance.database;
      
      // 计算月份的开始和结束日期
      final startDate = DateTime(month.year, month.month, 1);
      final endDate = DateTime(month.year, month.month + 1, 0);
      final startDateStr = _getDateString(startDate);
      final endDateStr = _getDateString(endDate);
      
      final rows = await db.query(
        'checkins',
        where: 'date >= ? AND date <= ?',
        whereArgs: [startDateStr, endDateStr],
      );
      
      final checkedInDates = <DateTime>{};
      for (var row in rows) {
        final dateStr = row['date'] as String;
        try {
          final date = DateTime.parse(dateStr);
          checkedInDates.add(DateTime(date.year, date.month, date.day));
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
      final db = await AppDatabase.instance.database;
      
      // 计算月份的开始和结束日期
      final startDate = DateTime(month.year, month.month, 1);
      final endDate = DateTime(month.year, month.month + 1, 0);
      final startDateStr = _getDateString(startDate);
      final endDateStr = _getDateString(endDate);
      
      final rows = await db.query(
        'checkins',
        where: 'date >= ? AND date <= ?',
        whereArgs: [startDateStr, endDateStr],
      );
      
      final checkedInRecords = <DateTime, DateTime>{};
      for (var row in rows) {
        final dateStr = row['date'] as String;
        final checkInTimeStr = row['check_in_time'] as String?;
        
        if (checkInTimeStr != null && checkInTimeStr.isNotEmpty) {
          try {
            final date = DateTime.parse(dateStr);
            final checkInTime = DateTime.parse(checkInTimeStr);
            checkedInRecords[DateTime(date.year, date.month, date.day)] = checkInTime;
          } catch (e) {
            print('解析打卡记录错误: $dateStr, $e');
          }
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
      final db = await AppDatabase.instance.database;
      
      // 计算月份的开始和结束日期
      final startDate = DateTime(month.year, month.month, 1);
      final endDate = DateTime(month.year, month.month + 1, 0);
      final startDateStr = _getDateString(startDate);
      final endDateStr = _getDateString(endDate);
      
      final rows = await db.query(
        'global_daily_completion',
        where: 'date >= ? AND date <= ?',
        whereArgs: [startDateStr, endDateStr],
      );
      
      final completionStatusMap = <DateTime, String>{};
      for (var row in rows) {
        final dateStr = row['date'] as String;
        final status = row['status'] as String? ?? 'unlearned';
        
        try {
          final date = DateTime.parse(dateStr);
          completionStatusMap[DateTime(date.year, date.month, date.day)] = status;
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
      final db = await AppDatabase.instance.database;
      
      final rows = await db.query(
        'checkins',
        orderBy: 'date DESC',
      );
      
      if (rows.isEmpty) return 0;
      
      // 解析所有签到日期并排序
      final checkInDates = <DateTime>[];
      for (var row in rows) {
        final dateStr = row['date'] as String;
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
      final db = await AppDatabase.instance.database;
      
      final rows = await db.query('checkins');
      
      // 统计有效的签到记录（去重）
      final checkInDates = <String>{};
      for (var row in rows) {
        final dateStr = row['date'] as String;
        final checkInTimeStr = row['check_in_time'] as String?;
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
      final db = await AppDatabase.instance.database;
      
      final rows = await db.query('daily_sessions');
      
      int totalSeconds = 0;
      
      for (var row in rows) {
        final accumulatedSeconds = row['accumulated_seconds'] as int? ?? 0;
        totalSeconds += accumulatedSeconds;
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
      final db = await AppDatabase.instance.database;
      
      // 检查缓存
      if (!forceRefresh && _cachedTotalRememberedWords != null) {
        final cachedDateRow = await db.query(
          'settings',
          where: 'key = ?',
          whereArgs: [_cachedTotalRememberedWordsDateKey],
        );
        
        final todayStr = _getTodayDateString();
        if (cachedDateRow.isNotEmpty) {
          final cachedDateStr = cachedDateRow.first['value'] as String?;
          if (cachedDateStr == todayStr) {
            return _cachedTotalRememberedWords!;
          }
        }
      }
      
      // 重新计算：获取所有词库ID
      final wordbookRows = await db.rawQuery('''
        SELECT DISTINCT wordbook_id 
        FROM study_records
      ''');
      
      final wordbookIds = wordbookRows.map((row) => row['wordbook_id'] as String).toSet();
      
      int totalRemembered = 0;
      for (var wordbookId in wordbookIds) {
        final count = await getLearnedWordCount(wordbookId);
        totalRemembered += count;
      }
      
      // 更新缓存
      _cachedTotalRememberedWords = totalRemembered;
      await db.insert(
        'settings',
        {'key': _cachedTotalRememberedWordsKey, 'value': totalRemembered.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await db.insert(
        'settings',
        {'key': _cachedTotalRememberedWordsDateKey, 'value': _getTodayDateString()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
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
      final db = await AppDatabase.instance.database;
      
      final sessionRows = await db.query(
        'daily_sessions',
        orderBy: 'date ASC',
      );
      
      if (sessionRows.isEmpty) return 0.0;
      
      int totalWords = 0;
      DateTime? firstStudyDate;
      
      for (var sessionRow in sessionRows) {
        final dateStr = sessionRow['date'] as String;
        
        // 获取该日期的唯一单词数
        final recordRows = await db.rawQuery('''
          SELECT DISTINCT word 
          FROM study_records 
          WHERE session_date = ?
        ''', [dateStr]);
        
        final uniqueWordCount = recordRows.length;
        if (uniqueWordCount > 0) {
          try {
            final date = DateTime.parse(dateStr);
            if (firstStudyDate == null || date.isBefore(firstStudyDate)) {
              firstStudyDate = date;
            }
          } catch (e) {
            print('解析日期错误: $dateStr, $e');
          }
          
          totalWords += uniqueWordCount;
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
  /// 1. 学习记录（study_records 表中该词库的记录）
  /// 2. 每日完成状态（daily_completion 表中该词库的记录）
  /// 3. 清除已记住单词总数的缓存
  Future<void> resetWordbook(String wordbookId) async {
    try {
      final db = await AppDatabase.instance.database;
      
      // 1. 清除学习记录
      final deletedRecords = await db.delete(
        'study_records',
        where: 'wordbook_id = ?',
        whereArgs: [wordbookId],
      );
      print('已清除 $deletedRecords 条学习记录');
      
      // 2. 清除每日完成状态
      final deletedCompletion = await db.delete(
        'daily_completion',
        where: 'wordbook_id = ?',
        whereArgs: [wordbookId],
      );
      print('已清除 $deletedCompletion 条每日完成状态记录');
      
      // 3. 清除已记住单词总数的缓存
      invalidateRememberedWordsCache();
      
      notifyListeners();
      print('词库 $wordbookId 已重置');
    } catch (e) {
      print('重置词库错误: $e');
      rethrow;
    }
  }
}
