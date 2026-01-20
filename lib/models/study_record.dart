class StudyRecord {
  final String word;
  final String wordbookId;
  final String status; // 'remembered', 'forgotten', 'unknown'
  final DateTime studyTime;
  final int studyCount; // 该单词的学习次数
  final DateTime? nextReviewDate; // 下次复习日期
  final int reviewCount; // 复习次数
  final int intervalDays; // 复习间隔天数

  StudyRecord({
    required this.word,
    required this.wordbookId,
    required this.status,
    required this.studyTime,
    required this.studyCount,
    this.nextReviewDate,
    this.reviewCount = 0,
    this.intervalDays = 1,
  });

  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'wordbook_id': wordbookId,
      'status': status,
      'study_time': studyTime.toIso8601String(),
      'study_count': studyCount,
      'next_review_date': nextReviewDate?.toIso8601String(),
      'review_count': reviewCount,
      'interval_days': intervalDays,
    };
  }

  factory StudyRecord.fromJson(Map<String, dynamic> json) {
    return StudyRecord(
      word: json['word'] ?? '',
      wordbookId: json['wordbook_id'] ?? '',
      status: json['status'] ?? '',
      studyTime: DateTime.parse(json['study_time']),
      studyCount: json['study_count'] ?? 1,
      nextReviewDate: json['next_review_date'] != null
          ? DateTime.parse(json['next_review_date'])
          : null,
      reviewCount: json['review_count'] ?? 0,
      intervalDays: json['interval_days'] ?? 1,
    );
  }
}

class DailyStudySession {
  final String date; // YYYY-MM-DD
  final DateTime? startTime;
  final DateTime? endTime;
  final int accumulatedSeconds; // 今日累计学习时长（秒），不包含当前正在学习的这一段
  final List<StudyRecord> records;

  DailyStudySession({
    required this.date,
    this.startTime,
    this.endTime,
    this.accumulatedSeconds = 0,
    required this.records,
  });

  /// 今日学习总时长（秒）
  /// = accumulatedSeconds +（如果正在学习，则加上 now-startTime）
  int totalDurationSecondsAt(DateTime now) {
    int total = accumulatedSeconds;
    if (startTime != null) {
      total += now.difference(startTime!).inSeconds;
    }
    return total < 0 ? 0 : total;
  }

  // 获取今日统计
  Map<String, int> getStatistics() {
    int total = records.length;
    int remembered = 0;
    int forgotten = 0;
    int unknown = 0;

    // 统计每个单词的最终状态
    final Map<String, String> wordFinalStatus = {};
    for (var record in records) {
      wordFinalStatus[record.word] = record.status;
    }

    for (var status in wordFinalStatus.values) {
      switch (status) {
        case 'remembered':
          remembered++;
          break;
        case 'forgotten':
          forgotten++;
          break;
        case 'unknown':
          unknown++;
          break;
      }
    }

    return {
      'total': total,
      'remembered': remembered,
      'forgotten': forgotten,
      'unknown': unknown,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'accumulated_seconds': accumulatedSeconds,
      'records': records.map((r) => r.toJson()).toList(),
    };
  }

  factory DailyStudySession.fromJson(Map<String, dynamic> json) {
    return DailyStudySession(
      date: json['date'] ?? '',
      startTime: json['start_time'] != null
          ? DateTime.parse(json['start_time'])
          : null,
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'])
          : null,
      accumulatedSeconds: json['accumulated_seconds'] ?? 0,
      records: (json['records'] as List<dynamic>?)
              ?.map((r) => StudyRecord.fromJson(r))
              .toList() ??
          [],
    );
  }
}

