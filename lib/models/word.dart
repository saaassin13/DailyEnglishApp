class Word {
  final String word;
  final String? usPhonetic;
  final String? ukPhonetic;
  final List<Translation> translations;
  final List<Phrase> phrases;
  final List<Sentence> sentences;
  final String? bookId;

  Word({
    required this.word,
    this.usPhonetic,
    this.ukPhonetic,
    required this.translations,
    required this.phrases,
    required this.sentences,
    this.bookId,
  });

  factory Word.fromJson(Map<String, dynamic> json) {
    // 兼容两种结构：
    // 1) 新结构（你更新后的合并词库）：{word, us, uk, translations, phrases, sentences}
    // 2) 旧结构（历史 json）：{headWord, content.word.content...}
    final content = json['content']?['word']?['content'];

    final dynamic rawTranslations = json['translations'] ?? content?['trans'];
    final dynamic rawPhrases = json['phrases'] ?? content?['phrase']?['phrases'];
    final dynamic rawSentences = json['sentences'] ?? content?['sentence']?['sentences'];

    final translations = (rawTranslations is List)
        ? rawTranslations
            .whereType<Map<String, dynamic>>()
            .map((t) => Translation.fromJson(t))
            .toList()
        : <Translation>[];

    final phrases = (rawPhrases is List)
        ? rawPhrases
            .whereType<Map<String, dynamic>>()
            .map((p) => Phrase.fromJson(p))
            .toList()
        : <Phrase>[];

    final sentences = (rawSentences is List)
        ? rawSentences
            .whereType<Map<String, dynamic>>()
            .map((s) => Sentence.fromJson(s))
            .toList()
        : <Sentence>[];

    return Word(
      word: (json['word'] ?? json['headWord'] ?? '').toString(),
      usPhonetic: (json['us'] ?? content?['usphone'])?.toString(),
      ukPhonetic: (json['uk'] ?? content?['ukphone'])?.toString(),
      translations: translations,
      phrases: phrases,
      sentences: sentences,
      bookId: json['bookId']?.toString(),
    );
  }
}

class Translation {
  final String translation;
  final String? pos; // 词性

  Translation({
    required this.translation,
    this.pos,
  });

  factory Translation.fromJson(Map<String, dynamic> json) {
    // 新结构：{translation, type}
    // 旧结构：{tranCn, pos}
    return Translation(
      translation: (json['translation'] ?? json['tranCn'] ?? '').toString(),
      pos: (json['type'] ?? json['pos'])?.toString(),
    );
  }

  String get displayText {
    final p = pos?.trim();
    if (p == null || p.isEmpty) return translation;

    // 新结构的 type 可能为 adv/v/n/adj 等缩写，也可能已有点号（adv.）
    final normalized = p.endsWith('.') ? p.substring(0, p.length - 1) : p;
    final lower = normalized.toLowerCase();

    const cnMap = <String, String>{
      'n': '名',
      'v': '动',
      'adj': '形',
      'adv': '副',
      'prep': '介',
      'pron': '代',
      'conj': '连',
      'interj': '感',
      'num': '数',
      'art': '冠',
    };

    final cn = cnMap[lower];
    final label = cn == null ? '${normalized}.' : '$cn(${normalized}.)';
    return '$label $translation';
  }
}

class Phrase {
  final String phrase;
  final String translation;

  Phrase({
    required this.phrase,
    required this.translation,
  });

  factory Phrase.fromJson(Map<String, dynamic> json) {
    // 新结构：{phrase, translation}
    // 旧结构：{pContent, pCn}
    return Phrase(
      phrase: (json['phrase'] ?? json['pContent'] ?? '').toString(),
      translation: (json['translation'] ?? json['pCn'] ?? '').toString(),
    );
  }
}

class Sentence {
  final String sentence;
  final String translation;

  Sentence({
    required this.sentence,
    required this.translation,
  });

  factory Sentence.fromJson(Map<String, dynamic> json) {
    // 新结构：{sentence, translation}
    // 旧结构：{sContent, sCn}
    return Sentence(
      sentence: (json['sentence'] ?? json['sContent'] ?? '').toString(),
      translation: (json['translation'] ?? json['sCn'] ?? '').toString(),
    );
  }
}

