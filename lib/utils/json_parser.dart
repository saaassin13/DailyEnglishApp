import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/word.dart';

class JsonParser {
  /// 从assets加载JSON文件并解析为Word列表
  static Future<List<Word>> loadWordsFromAsset(String assetPath) async {
    try {
      final String jsonString = await rootBundle.loadString(assetPath);
      final List<Word> words = [];

      // 尝试解析为JSON数组
      try {
        final dynamic jsonData = json.decode(jsonString);
        if (jsonData is List) {
          // 如果是数组，遍历每个元素
          for (var item in jsonData) {
            if (item is Map<String, dynamic>) {
              try {
                final Word word = Word.fromJson(item);
                words.add(word);
              } catch (e) {
                print('解析单词错误: $e');
              }
            }
          }
        } else if (jsonData is Map<String, dynamic>) {
          // 如果是单个对象，直接解析
          final Word word = Word.fromJson(jsonData);
          words.add(word);
        }
      } catch (e) {
        // 如果整体解析失败，尝试按行解析（NDJSON格式）
        print('整体解析失败，尝试按行解析: $e');
        final List<String> lines = jsonString.split('\n');
        for (String line in lines) {
          line = line.trim();
          if (line.isEmpty || line == '[' || line == ']') continue;

          // 移除行尾的逗号（如果是数组中的元素）
          if (line.endsWith(',')) {
            line = line.substring(0, line.length - 1);
          }

          try {
            final Map<String, dynamic> jsonData = json.decode(line);
            final Word word = Word.fromJson(jsonData);
            words.add(word);
          } catch (e) {
            print('解析行错误: $e');
          }
        }
      }

      return words;
    } catch (e) {
      print('加载文件错误: $e, 路径: $assetPath');
      return [];
    }
  }

  /// 加载多个JSON文件并合并
  /// 现在使用 english-vocabulary/json 目录下的合并文件
  static Future<List<Word>> loadWordsFromMultipleFiles(
      List<String> fileNames) async {
    final List<Word> allWords = [];
    final Set<String> seenWords = {}; // 用于去重

    for (String fileName in fileNames) {
      final String assetPath = 'english-vocabulary/json/$fileName';
      final List<Word> words = await loadWordsFromAsset(assetPath);

      for (Word word in words) {
        // 使用单词文本作为唯一标识去重
        if (!seenWords.contains(word.word.toLowerCase())) {
          seenWords.add(word.word.toLowerCase());
          allWords.add(word);
        }
      }
    }

    return allWords;
  }
}

