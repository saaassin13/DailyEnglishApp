import 'package:flutter/foundation.dart';
import '../models/word.dart';
import '../models/wordbook.dart';
import '../models/study_record.dart';
import '../utils/json_parser.dart';
import 'study_record_service.dart';
import 'review_algorithm.dart';
import 'settings_service.dart';

class WordService extends ChangeNotifier {
  Wordbook? _currentWordbook;
  List<Word> _allWords = [];
  List<Word> _dailyWords = [];
  int _currentWordIndex = 0;
  bool _isLoading = false;
  
  // 单词状态跟踪
  final Map<String, String> _wordStatuses = {}; // word -> status
  final Map<String, int> _wordStudyCounts = {}; // word -> count
  
  StudyRecordService? _studyRecordService;
  SettingsService? _settingsService;

  Wordbook? get currentWordbook => _currentWordbook;
  List<Word> get dailyWords => _dailyWords;
  int get currentWordbookTotalWords => _allWords.length;
  Word? get currentWord =>
      _currentWordIndex < _dailyWords.length ? _dailyWords[_currentWordIndex] : null;
  int get currentWordIndex => _currentWordIndex;
  int get totalWords => _dailyWords.length;
  bool get isLoading => _isLoading;
  bool get hasNextWord => _currentWordIndex < _dailyWords.length - 1;
  bool get hasPreviousWord => _currentWordIndex > 0;
  
  /// 设置 StudyRecordService
  void setStudyRecordService(StudyRecordService service) {
    _studyRecordService = service;
  }

  /// 设置 SettingsService
  void setSettingsService(SettingsService service) {
    _settingsService = service;
  }
  
  /// 检查是否完成（所有单词的最终状态都是 remembered）
  bool get isCompleted {
    if (_dailyWords.isEmpty) return false;
    
    for (var word in _dailyWords) {
      final status = _wordStatuses[word.word];
      if (status != 'remembered') {
        return false;
      }
    }
    return true;
  }
  
  /// 获取单词的最终状态
  String? getWordStatus(String word) {
    return _wordStatuses[word];
  }
  
  /// 获取单词的学习次数
  int getWordStudyCount(String word) {
    return _wordStudyCounts[word] ?? 0;
  }

  /// 加载词库（修改版本：先新学后复习）
  Future<void> loadWordbook(Wordbook wordbook, {int? dailyNewCount, int? dailyReviewCount}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentWordbook = wordbook;
      _allWords = await JsonParser.loadWordsFromMultipleFiles(wordbook.jsonFiles);
      
      // 保存当前词库ID
      if (_settingsService != null) {
        await _settingsService!.setCurrentWordbookId(wordbook.id);
      }
      
      // 生成每日单词：先新学后复习
      await _generateDailyWords(
        newCount: dailyNewCount ?? 30,
        reviewCount: dailyReviewCount ?? 20,
      );
      
      // 恢复学习进度
      await _restoreStudyProgress(wordbook.id);
      
      _currentWordIndex = 0;
    } catch (e) {
      print('加载词库错误: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// 恢复学习进度
  Future<void> _restoreStudyProgress(String wordbookId) async {
    if (_studyRecordService == null) return;
    
    try {
      final progress = await _studyRecordService!.getStudyProgress(wordbookId);
      _wordStatuses.clear();
      _wordStudyCounts.clear();
      
      // 恢复单词状态
      final wordStatuses = progress['word_statuses'] as Map<String, String>?;
      if (wordStatuses != null) {
        _wordStatuses.addAll(wordStatuses);
      }
      
      // 恢复学习次数
      final wordStudyCounts = progress['word_study_counts'] as Map<String, int>?;
      if (wordStudyCounts != null) {
        _wordStudyCounts.addAll(wordStudyCounts);
      }
      
      // 找到当前学习位置（第一个未完成或需要复习的单词）
      // 注意：所有已学习的单词都保留在列表中，用户可以通过"上一条"访问
      for (int i = 0; i < _dailyWords.length; i++) {
        final word = _dailyWords[i];
        final status = _wordStatuses[word.word];
        // 如果单词未学习或不是 remembered，则定位到这里
        if (status == null || status != 'remembered') {
          _currentWordIndex = i;
          break;
        }
      }
      // 如果所有单词都已完成，定位到最后一个
      if (_currentWordIndex == 0 && _dailyWords.isNotEmpty) {
        bool allCompleted = true;
        for (var word in _dailyWords) {
          if (_wordStatuses[word.word] != 'remembered') {
            allCompleted = false;
            break;
          }
        }
        if (allCompleted) {
          _currentWordIndex = _dailyWords.length - 1;
        }
      }
    } catch (e) {
      print('恢复学习进度错误: $e');
    }
  }

  /// 生成每日单词列表（先新学后复习）
  Future<void> _generateDailyWords({
    required int newCount,
    required int reviewCount,
  }) async {
    if (_allWords.isEmpty) {
      _dailyWords = [];
      return;
    }

    _dailyWords = [];
    
    // 1. 先获取需要复习的单词
    if (_studyRecordService != null && _currentWordbook != null) {
      final reviewWords = await _studyRecordService!.getReviewWords(
        _currentWordbook!.id,
        limit: reviewCount,
      );
      
      print('需要复习的单词列表: $reviewWords (共${reviewWords.length}个)');
      
      // 从所有单词中找到需要复习的单词对象（不区分大小写匹配）
      final reviewWordObjects = <Word>[];
      for (var reviewWord in reviewWords) {
        if (reviewWordObjects.length >= reviewCount) break;
        
        try {
          final wordObj = _allWords.firstWhere(
            (w) => w.word.toLowerCase() == reviewWord.toLowerCase(),
            orElse: () => _allWords.firstWhere(
              (w) => w.word == reviewWord,
            ),
          );
          // 避免重复添加
          if (!reviewWordObjects.any((w) => w.word.toLowerCase() == wordObj.word.toLowerCase())) {
            reviewWordObjects.add(wordObj);
          }
        } catch (e) {
          print('找不到复习单词: $reviewWord, 错误: $e');
        }
      }
      
      print('找到的复习单词对象: ${reviewWordObjects.map((w) => w.word).toList()} (共${reviewWordObjects.length}个)');
      _dailyWords.addAll(reviewWordObjects);
    }
    
    // 2. 然后获取新学的单词（排除已学会的）
    // 计算实际需要的新学单词数：如果复习单词不足，用新学单词补齐总数
    final actualReviewCount = _dailyWords.length;
    final actualNewCountNeeded = newCount + (reviewCount - actualReviewCount);
    
    final learnedWords = <String>{};
    if (_studyRecordService != null && _currentWordbook != null) {
      // 获取所有已学会的单词
      final allKeys = _allWords.map((w) => w.word).toList();
      for (var word in allKeys) {
        final status = await _studyRecordService!.getWordFinalStatus(
          word,
          _currentWordbook!.id,
        );
        if (status == 'remembered') {
          learnedWords.add(word);
        }
      }
    }
    
    // 从所有单词中排除已学会的和已加入复习的
    final newWordCandidates = _allWords
        .where((w) => !learnedWords.contains(w.word) && 
                     !_dailyWords.any((dw) => dw.word.toLowerCase() == w.word.toLowerCase()))
        .toList();
    
    // 随机打乱并取前 actualNewCountNeeded 个（确保总数是 newCount + reviewCount）
    newWordCandidates.shuffle();
    final newWordsToAdd = newWordCandidates.take(actualNewCountNeeded).toList();
    print('新学单词: ${newWordsToAdd.map((w) => w.word).toList()} (共${newWordsToAdd.length}个)');
    _dailyWords.addAll(newWordsToAdd);
    
    print('最终每日单词列表: ${_dailyWords.map((w) => w.word).toList()} (共${_dailyWords.length}个)');
  }

  /// 下一个单词
  void nextWord() {
    if (hasNextWord) {
      _currentWordIndex++;
      notifyListeners();
    }
  }

  /// 上一个单词
  void previousWord() {
    if (hasPreviousWord) {
      _currentWordIndex--;
      notifyListeners();
    }
  }

  /// 标记单词状态（修改版本：包含复习信息）
  Future<void> markWordStatus(String status) async {
    final word = currentWord;
    if (word == null || _currentWordbook == null) return;
    
    final wordText = word.word;
    final wordbookId = _currentWordbook!.id;
    
    // 获取历史记录，计算复习信息
    int reviewCount = 0;
    DateTime? nextReviewDate;
    int intervalDays = 1;
    
    if (_studyRecordService != null) {
      final history = await _studyRecordService!.getWordHistory(wordText, wordbookId);
      if (history.isNotEmpty) {
        history.sort((a, b) => b.studyTime.compareTo(a.studyTime));
        final lastRecord = history.first;
        reviewCount = lastRecord.reviewCount;
        
        // 根据状态更新复习次数
        if (status == 'remembered') {
          reviewCount++;
        } else {
          // forgotten 或 unknown，重置复习次数
          reviewCount = 0;
        }
      }
      
      // 计算下次复习日期
      nextReviewDate = EbbinghausAlgorithm.calculateNextReview(
        status: status,
        reviewCount: reviewCount,
        lastReviewDate: DateTime.now(),
      );
      
      intervalDays = EbbinghausAlgorithm.calculateIntervalDays(
        status: status,
        reviewCount: reviewCount,
      );
    }
    
    // 更新状态和学习次数
    _wordStatuses[wordText] = status;
    _wordStudyCounts[wordText] = (_wordStudyCounts[wordText] ?? 0) + 1;
    
    // 保存学习记录（包含复习信息）
    if (_studyRecordService != null) {
      try {
        final record = StudyRecord(
          word: wordText,
          wordbookId: wordbookId,
          status: status,
          studyTime: DateTime.now(),
          studyCount: _wordStudyCounts[wordText]!,
          nextReviewDate: nextReviewDate,
          reviewCount: reviewCount,
          intervalDays: intervalDays,
        );
        await _studyRecordService!.saveRecord(record);
      } catch (e) {
        print('保存学习记录错误: $e');
      }
    }
    
    notifyListeners();
    
    // 交互逻辑（按需求）：
    // - remembered：今日不再出现（移除后续重复）
    // - forgotten/unknown：把当前单词移动到“今日所学列表最后”，直到其状态变为 remembered
    _reorderDailyQueueAfterAnswer(word, status);
  }
  
  /// 按按钮结果重排今日队列，并把指针推进到下一个单词
  void _reorderDailyQueueAfterAnswer(Word answeredWord, String status) {
    if (_dailyWords.isEmpty) return;
    if (_currentWordIndex < 0 || _currentWordIndex >= _dailyWords.length) return;

    final current = _dailyWords[_currentWordIndex];
    if (current.word.toLowerCase() != answeredWord.word.toLowerCase()) {
      // 防御：currentWord 与传入不一致时，不做队列操作，只做安全推进
      if (_currentWordIndex < _dailyWords.length - 1) {
        _currentWordIndex++;
      }
      notifyListeners();
      return;
    }

    // 1) 先移除当前位置（避免“移动到末尾”时产生重复）
    _dailyWords.removeAt(_currentWordIndex);

    if (status == 'remembered') {
      // 2a) remembered：移除后续所有重复（历史上可能因为不熟/不会被移动过）
      _dailyWords.removeWhere(
        (w) => w.word.toLowerCase() == answeredWord.word.toLowerCase(),
      );
      // 2b) 指针保持在当前 index，即原来的“下一个单词”已经顶上来了
    } else if (status == 'forgotten' || status == 'unknown') {
      // 2c) forgotten/unknown：移动到末尾
      _dailyWords.add(answeredWord);
      // 指针仍保持当前 index（顶上来的就是下一个单词）
    } else {
      // 未知状态：不重排，直接推进到下一个（这里也维持当前 index）
    }

    // 3) 边界修正：如果已经没有下一个单词，则 currentWord 会变为 null
    if (_currentWordIndex >= _dailyWords.length && _dailyWords.isNotEmpty) {
      _currentWordIndex = _dailyWords.length - 1;
    }
    notifyListeners();
  }

  /// 重新生成每日单词
  Future<void> regenerateDailyWords({int newCount = 30, int reviewCount = 20}) async {
    await _generateDailyWords(newCount: newCount, reviewCount: reviewCount);
    _currentWordIndex = 0;
    notifyListeners();
  }

  /// 使用新的每日学习量重新生成单词
  Future<void> regenerateDailyWordsWithNewCount(int newCount, int reviewCount) async {
    await regenerateDailyWords(newCount: newCount, reviewCount: reviewCount);
  }

  /// 获取待新学数量（今日新学的单词数量）
  Future<int> getTodayNewWordCount(String wordbookId) async {
    try {
      if (_studyRecordService == null) return 0;
      
      final session = await _studyRecordService!.getTodaySession();
      if (session == null) return 0;
      
      // 统计今日新学的单词（排除复习的单词）
      final todayRecords = session.records
          .where((r) => r.wordbookId == wordbookId)
          .toList();
      
      if (todayRecords.isEmpty) return 0;
      
      // 获取需要复习的单词列表
      final reviewWords = await _studyRecordService!.getReviewWords(wordbookId);
      final reviewWordsSet = reviewWords.map((w) => w.toLowerCase()).toSet();
      
      // 统计今日新学的单词（不在复习列表中的）
      int newWordCount = 0;
      final processedWords = <String>{};
      
      for (var record in todayRecords) {
        final wordLower = record.word.toLowerCase();
        if (!reviewWordsSet.contains(wordLower) && !processedWords.contains(wordLower)) {
          newWordCount++;
          processedWords.add(wordLower);
        }
      }
      
      return newWordCount;
    } catch (e) {
      print('获取待新学数量错误: $e');
      return 0;
    }
  }

  /// 获取新词待选数量（词库中未学习过的单词数量）
  Future<int> getUnselectedWordCount(Wordbook wordbook) async {
    try {
      if (_studyRecordService == null) {
        return wordbook.totalWords;
      }
      
      // 加载词库的所有单词
      final allWords = await JsonParser.loadWordsFromMultipleFiles(wordbook.jsonFiles);
      
      int unselectedCount = 0;
      
      for (var word in allWords) {
        final status = await _studyRecordService!.getWordFinalStatus(word.word, wordbook.id);
        if (status == null) {
          // 没有学习记录，算作未选
          unselectedCount++;
        }
      }
      
      return unselectedCount;
    } catch (e) {
      print('获取新词待选数量错误: $e');
      return wordbook.totalWords;
    }
  }
}

