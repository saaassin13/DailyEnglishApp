class Wordbook {
  final String id;
  final String name;
  final int totalWords;
  final List<String> jsonFiles; // 关联的JSON文件列表

  Wordbook({
    required this.id,
    required this.name,
    required this.totalWords,
    required this.jsonFiles,
  });

  // 预定义的词库映射
  // 使用 english-vocabulary/json 目录下的合并文件
  static final List<Wordbook> predefinedWordbooks = [
    Wordbook(
      id: 'xiaoxue',
      name: '小学',
      totalWords: 849, // 实际统计数量
      jsonFiles: ['primary.json'],
    ),
    Wordbook(
      id: 'chuzhong',
      name: '中学',
      totalWords: 2320, // 实际统计数量
      jsonFiles: ['middle.json'],
    ),
    Wordbook(
      id: 'gaozhong',
      name: '高中',
      totalWords: 3877, // 实际统计数量
      jsonFiles: ['high.json'],
    ),
    Wordbook(
      id: 'cet4',
      name: '大学四级',
      totalWords: 7508, // 实际统计数量
      jsonFiles: ['cet4.json'],
    ),
    Wordbook(
      id: 'cet6',
      name: '大学六级',
      totalWords: 5651, // 实际统计数量
      jsonFiles: ['cet6.json'],
    ),
    Wordbook(
      id: 'kaoyan',
      name: '考研',
      totalWords: 9602, // 实际统计数量
      jsonFiles: ['kaoyan.json'],
    ),
    Wordbook(
      id: 'toefl',
      name: '托福',
      totalWords: 13477, // 实际统计数量
      jsonFiles: ['toefl.json'],
    ),
    Wordbook(
      id: 'sat',
      name: 'SAT',
      totalWords: 8887, // 实际统计数量
      jsonFiles: ['sat.json'],
    ),
  ];
}

