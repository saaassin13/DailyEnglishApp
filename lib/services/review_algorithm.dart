/// 艾宾浩斯遗忘曲线算法
class EbbinghausAlgorithm {
  // 遗忘曲线复习间隔（天）
  static const List<int> reviewIntervals = [1, 2, 4, 7, 15, 30];
  
  /// 根据学习状态和复习次数计算下次复习日期
  static DateTime calculateNextReview({
    required String status,
    required int reviewCount,
    required DateTime lastReviewDate,
  }) {
    if (status == 'remembered') {
      // 记住的单词，延长复习间隔
      int interval = reviewCount < reviewIntervals.length 
          ? reviewIntervals[reviewCount] 
          : reviewIntervals.last;
      return lastReviewDate.add(Duration(days: interval));
    } else if (status == 'forgotten') {
      // 忘记的单词，缩短间隔，重新开始
      return DateTime.now().add(const Duration(days: 1));
    } else {
      // 不会的单词，第二天复习
      return DateTime.now().add(const Duration(days: 1));
    }
  }
  
  /// 计算复习间隔天数
  static int calculateIntervalDays({
    required String status,
    required int reviewCount,
  }) {
    if (status == 'remembered') {
      return reviewCount < reviewIntervals.length 
          ? reviewIntervals[reviewCount] 
          : reviewIntervals.last;
    } else {
      // forgotten 或 unknown，间隔1天
      return 1;
    }
  }
}

