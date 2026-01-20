# 数据模型定义

## Word（单词）

```dart
class Word {
  final String word;                    // 单词
  final String? usPhonetic;            // 美式音标
  final String? ukPhonetic;            // 英式音标
  final List<Translation> translations; // 释义列表
  final List<Phrase> phrases;          // 短语列表
  final List<Sentence> sentences;      // 例句列表
  final String? bookId;                // 所属词库ID
}
```

### Translation（释义）
```dart
class Translation {
  final String translation;  // 中文释义
  final String? pos;         // 词性（n/v/adj/adv等）
}
```

### Phrase（短语）
```dart
class Phrase {
  final String phrase;       // 短语
  final String translation;  // 中文翻译
}
```

### Sentence（例句）
```dart
class Sentence {
  final String sentence;     // 英文例句
  final String translation;  // 中文翻译
}
```

## Wordbook（词库）

```dart
class Wordbook {
  final String id;           // 词库ID
  final String name;         // 词库名称
  final int totalWords;      // 总单词数
  final List<String> jsonFiles; // 关联的JSON文件列表
}
```

预定义词库：
- 小学（849词）
- 中学（2320词）
- 高中（3877词）
- 大学四级（7508词）
- 大学六级（5651词）
- 考研（9602词）
- 托福（13477词）
- SAT（8887词）

## StudyRecord（学习记录）

```dart
class StudyRecord {
  final String word;              // 单词
  final String wordbookId;        // 词库ID
  final String status;            // 状态：'remembered'/'forgotten'/'unknown'
  final DateTime studyTime;      // 学习时间
  final int studyCount;           // 学习次数
  final DateTime? nextReviewDate; // 下次复习日期
  final int reviewCount;          // 复习次数
  final int intervalDays;         // 复习间隔天数
}
```

## DailyStudySession（每日学习会话）

```dart
class DailyStudySession {
  final String date;                    // 日期（YYYY-MM-DD）
  final DateTime? startTime;            // 开始时间
  final DateTime? endTime;              // 结束时间
  final int accumulatedSeconds;         // 累计学习时长（秒）
  final List<StudyRecord> records;      // 学习记录列表
}
```

## 复习算法

### EbbinghausAlgorithm（艾宾浩斯遗忘曲线）

复习间隔天数：`[1, 2, 4, 7, 15, 30]`

- **记住（remembered）**：按复习次数递增间隔
- **不熟（forgotten）**：间隔1天
- **不会（unknown）**：间隔1天

