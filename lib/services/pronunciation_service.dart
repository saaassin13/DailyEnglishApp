import 'package:audioplayers/audioplayers.dart';

enum PronunciationType {
  us, // 美式发音 type=2
  uk, // 英式发音 type=1
}

class PronunciationService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  /// 播放单词发音
  /// [word] 要发音的单词
  /// [type] 发音类型：美式或英式
  Future<void> playWord(String word, PronunciationType type) async {
    try {
      final int typeValue = type == PronunciationType.us ? 2 : 1;
      final String url =
          'https://dict.youdao.com/dictvoice?audio=$word&type=$typeValue';

      await _audioPlayer.play(UrlSource(url));
    } catch (e) {
      print('播放发音错误: $e');
      rethrow;
    }
  }

  /// 播放短语发音
  Future<void> playPhrase(String phrase) async {
    try {
      // 短语发音使用美式发音
      final String url =
          'https://dict.youdao.com/dictvoice?audio=$phrase&type=2';
      await _audioPlayer.play(UrlSource(url));
    } catch (e) {
      print('播放短语发音错误: $e');
      rethrow;
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}

