import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/word.dart';
import '../models/wordbook.dart';
import '../services/pronunciation_service.dart';
import '../services/settings_service.dart';
import '../services/study_record_service.dart';
import '../services/word_service.dart';
import 'main_screen.dart';

class StudyDetailScreen extends StatefulWidget {
  final Wordbook wordbook;

  const StudyDetailScreen({
    super.key,
    required this.wordbook,
  });

  @override
  State<StudyDetailScreen> createState() => _StudyDetailScreenState();
}

class _StudyDetailScreenState extends State<StudyDetailScreen> with WidgetsBindingObserver {
  bool _showTranslation = false;
  Timer? _ticker;
  bool _isRefreshingSession = false;
  bool _isInStudySession = false;
  Word? _previousWord; // 用于跟踪单词变化，切换时重置翻译状态
  StudyRecordService? _studyRecordService; // 保存引用，避免 dispose 时访问失效的 context
  DateTime? _sessionStartTime; // 本次会话开始时间
  PronunciationService? _pronunciationService; // 发音服务

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _initializeServices();
      await _loadWordbookIfNeeded();
      await _refreshTodaySession();
      _sessionStartTime = DateTime.now(); // 记录本次会话开始时间
      await _enterStudySession();
      _startTicker();
    });
    
    // 初始化发音服务
    _pronunciationService = PronunciationService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 在 didChangeDependencies 中保存引用，确保可以安全地在 dispose 中使用
    if (_studyRecordService == null) {
      _studyRecordService = context.read<StudyRecordService>();
      print('StudyDetailScreen: 保存 StudyRecordService 引用');
    }
  }

  void _initializeServices() {
    final wordService = context.read<WordService>();
    final studyRecordService = context.read<StudyRecordService>();
    final settingsService = context.read<SettingsService>();
    wordService.setStudyRecordService(studyRecordService);
    wordService.setSettingsService(settingsService);
    // 确保引用已保存
    _studyRecordService ??= studyRecordService;
  }

  Future<void> _loadWordbookIfNeeded() async {
    final wordService = context.read<WordService>();
    final settingsService = context.read<SettingsService>();

    // 确保“当前词库”与用户选择一致
    await settingsService.setCurrentWordbookId(widget.wordbook.id);

    if (wordService.currentWordbook?.id == widget.wordbook.id &&
        wordService.currentWord != null) {
      return;
    }

    await wordService.loadWordbook(
      widget.wordbook,
      dailyNewCount: settingsService.dailyNewCount,
      dailyReviewCount: settingsService.dailyReviewCount,
    );
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isRefreshingSession) return;
      _refreshTodaySession();
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    print('StudyDetailScreen: dispose 开始');
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _exitStudySession();
    _pronunciationService?.dispose();
    print('StudyDetailScreen: dispose 完成');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 防止切后台还在计时：后台视为退出一次学习，回前台再进入一次学习
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _exitStudySession();
    } else if (state == AppLifecycleState.resumed) {
      _enterStudySession();
    }
  }

  Future<void> _enterStudySession() async {
    if (_isInStudySession) return;
    _isInStudySession = true;
    print('StudyDetailScreen: 进入学习会话');
    // 使用保存的引用或从 context 获取
    final service = _studyRecordService ?? context.read<StudyRecordService>();
    await service.accumulateStudyTime(DateTime.now(), isEntering: true);
  }

  void _exitStudySession() {
    if (!_isInStudySession) return;
    _isInStudySession = false;
    print('StudyDetailScreen: 退出学习会话，_studyRecordService = ${_studyRecordService != null}');
    // dispose 里不能 await，直接 fire-and-forget
    // 使用保存的引用，避免访问失效的 context
    if (_studyRecordService != null) {
      _studyRecordService!.accumulateStudyTime(DateTime.now(), isEntering: false);
    } else {
      // 如果引用不存在，尝试从 context 获取（可能失败，但不影响）
      try {
        if (mounted) {
          context.read<StudyRecordService>().accumulateStudyTime(DateTime.now(), isEntering: false);
        }
      } catch (e) {
        print('StudyDetailScreen: _exitStudySession 访问 context 失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wordService = context.watch<WordService>();
    final settingsService = context.watch<SettingsService>();
    final word = wordService.currentWord;

    // 检测单词变化，切换时自动隐藏翻译
    if (word != null && word != _previousWord) {
      _previousWord = word;
      _showTranslation = false;
    }

    return WillPopScope(
      onWillPop: () async {
        print('StudyDetailScreen: onWillPop 回调');
        // 使用保存的引用，避免访问失效的 context
        final service = _studyRecordService ?? context.read<StudyRecordService>();
        await service.accumulateStudyTime(DateTime.now(), isEntering: false);
        _isInStudySession = false;
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE9F6FF), Color(0xFFFFFFFF)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                _buildTopBar(),
                const SizedBox(height: 6),
                _buildWordbookInfoBar(
                  wordbookName: widget.wordbook.name,
                  totalWords: wordService.currentWordbookTotalWords > 0
                      ? wordService.currentWordbookTotalWords
                      : widget.wordbook.totalWords,
                  dailyTotalSeconds: _getTodayTotalSeconds(),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: wordService.isLoading || settingsService.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : (word == null
                          ? _buildEmptyState()
                          : _buildContent(word)),
                ),
                _buildBottomActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (value) {
              if (value == 'reset') {
                _showResetWordbookDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 20),
                    SizedBox(width: 8),
                    Text('重置词库'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWordbookInfoBar({
    required String wordbookName,
    required int totalWords,
    required int dailyTotalSeconds,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '当前词库：$wordbookName（共 $totalWords 词）',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.75),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFE3FF)),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, size: 16, color: Colors.black87),
                const SizedBox(width: 6),
                Text(
                  _formatHms(dailyTotalSeconds),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        '暂无单词数据',
        style: TextStyle(color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildContent(Word word) {
    final usPhone = word.usPhonetic?.trim();
    final ukPhone = word.ukPhonetic?.trim();

    return GestureDetector(
      onTap: () {
        if (!_showTranslation) {
          setState(() => _showTranslation = true);
        }
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Center(
            child: Text(
              word.word,
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                // 美式音标组
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildAccentChip('美'),
                    const SizedBox(width: 8),
                    Text(
                      usPhone == null || usPhone.isEmpty ? '[-]' : '[$usPhone]',
                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                    _buildSpeakerButton(
                      tooltip: '美式发音',
                      onTap: () => _onUsPronunciationTap(word.word),
                    ),
                  ],
                ),
                // 英式音标组
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildAccentChip('英'),
                    const SizedBox(width: 8),
                    Text(
                      ukPhone == null || ukPhone.isEmpty ? '[-]' : '[$ukPhone]',
                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                    _buildSpeakerButton(
                      tooltip: '英式发音',
                      onTap: () => _onUkPronunciationTap(word.word),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildTranslationToggle(),
          const SizedBox(height: 12),
          if (!_showTranslation) _buildRecallHint(),
          if (_showTranslation) ...[
            _buildTranslations(word.translations, word.word),
          ],
          const SizedBox(height: 10),
          _buildPhrases(word.phrases),
          const SizedBox(height: 18),
          _buildSectionTitle('例句'),
          const SizedBox(height: 10),
          _buildSentences(word.sentences),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildAccentChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: Colors.black87),
      ),
    );
  }

  Widget _buildTranslationToggle() {
    return Row(
      children: [
        Expanded(
          child: Text(
            _showTranslation ? '已显示翻译' : '点击屏幕显示答案',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _showTranslation = !_showTranslation),
          child: Text(_showTranslation ? '隐藏翻译' : '翻译'),
        ),
      ],
    );
  }

  Widget _buildRecallHint() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      child: Column(
        children: [
          Text(
            '请回忆单词发音和释义',
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '点击屏幕显示答案',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranslations(List<Translation> translations, String word) {
    if (translations.isEmpty) {
      return Text(
        '暂无释义',
        style: TextStyle(color: Colors.grey[600]),
      );
    }

    final items = translations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      t.displayText,
                      style: const TextStyle(fontSize: 18, height: 1.25),
                    ),
                  ),
                  _buildSpeakerButton(
                    tooltip: '释义发音',
                    onTap: () => _onUsPronunciationTap(word),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildPhrases(List<Phrase> phrases) {
    if (phrases.isEmpty) {
      return const SizedBox.shrink();
    }

    final items = phrases;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('短语'),
        const SizedBox(height: 8),
        ...items.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final p = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$index.',
                      style: const TextStyle(fontSize: 18, height: 1.25),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        p.phrase,
                        style: const TextStyle(fontSize: 18, height: 1.25),
                      ),
                    ),
                    _buildSpeakerButton(
                      tooltip: '短语发音',
                      onTap: () => _onPhrasePronunciationTap(p.phrase),
                    ),
                  ],
                ),
                if (_showTranslation) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Text(
                      p.translation,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSentences(List<Sentence> sentences) {
    if (sentences.isEmpty) {
      return Text(
        '暂无例句',
        style: TextStyle(color: Colors.grey[600]),
      );
    }

    final items = sentences;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.asMap().entries.map((entry) {
        final index = entry.key + 1;
        final s = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$index.',
                    style: const TextStyle(fontSize: 18, height: 1.35),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      s.sentence,
                      style: const TextStyle(fontSize: 18, height: 1.35),
                    ),
                  ),
                ],
              ),
              if (_showTranslation) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: Text(
                    s.translation,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        color: Colors.grey[700],
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSpeakerButton({
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: const Icon(Icons.volume_up_outlined, size: 20),
    );
  }

  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              label: '记住',
              subtitle: '今日不再出现',
              color: const Color(0xFF7BC8A4),
              onTap: () => _onStudyActionTap('remembered'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildActionButton(
              label: '不熟',
              subtitle: '放到末尾再来',
              color: const Color(0xFFF2B24A),
              onTap: () => _onStudyActionTap('forgotten'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildActionButton(
              label: '不会',
              subtitle: '放到末尾再来',
              color: const Color(0xFFE56A6A),
              onTap: () => _onStudyActionTap('unknown'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onStudyActionTap(String status) async {
    final wordService = context.read<WordService>();
    final studyRecordService = context.read<StudyRecordService>();
    final settingsService = context.read<SettingsService>();

    await wordService.markWordStatus(status);

    // 每次学习后检查全局完成状态
    await studyRecordService.checkAndUpdateGlobalCompletionStatus(
      settingsService.dailyTotalCount,
    );

    // 若没有下一个（列表已耗尽），记录“完成学习”并进入完成页（预留）
    if (wordService.currentWord == null) {
      await studyRecordService.setDailyCompletionStatus(
        widget.wordbook.id,
        'completed',
      );
      // 再次检查全局完成状态（确保已更新）
      await studyRecordService.checkAndUpdateGlobalCompletionStatus(
        settingsService.dailyTotalCount,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StudyCompleteScreen(
            wordbookId: widget.wordbook.id,
            sessionStartTime: _sessionStartTime,
          ),
        ),
      );
    } else {
      // 有学习行为即视为“今日已开始学习”（默认未学习，不强制落库）
      // 这里暂不写入 'unlearned'，缺省即“未学习”
    }
  }

  Widget _buildActionButton({
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getTodayTotalSeconds() {
    return _todayTotalSecondsCache ?? 0;
  }

  int? _todayTotalSecondsCache;
  Future<void> _refreshTodaySession() async {
    if (_isRefreshingSession) return;
    _isRefreshingSession = true;
    try {
      final studyRecordService = context.read<StudyRecordService>();
      final session = await studyRecordService.getTodaySession();
      if (!mounted) return;
      final now = DateTime.now();
      int seconds = 0;
      if (session != null) {
        seconds = session.totalDurationSecondsAt(now);
      }
      setState(() {
        _todayTotalSecondsCache = seconds;
      });
    } finally {
      _isRefreshingSession = false;
    }
  }

  String _formatHms(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// 播放美式发音
  Future<void> _onUsPronunciationTap(String word) async {
    if (_pronunciationService == null) return;
    try {
      await _pronunciationService!.playWord(word, PronunciationType.us);
    } catch (e) {
      print('播放美式发音错误: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('播放发音失败，请检查网络连接'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// 播放英式发音
  Future<void> _onUkPronunciationTap(String word) async {
    if (_pronunciationService == null) return;
    try {
      await _pronunciationService!.playWord(word, PronunciationType.uk);
    } catch (e) {
      print('播放英式发音错误: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('播放发音失败，请检查网络连接'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// 播放短语发音（默认美式）
  Future<void> _onPhrasePronunciationTap(String phrase) async {
    if (_pronunciationService == null) return;
    try {
      await _pronunciationService!.playPhrase(phrase);
    } catch (e) {
      print('播放短语发音错误: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('播放发音失败，请检查网络连接'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// 显示重置词库确认对话框
  Future<void> _showResetWordbookDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置词库'),
        content: Text(
          '确定要重置词库"${widget.wordbook.name}"吗？\n\n'
          '重置后将清除该词库的所有学习记录，包括：\n'
          '• 单词学习历史\n'
          '• 学习进度\n'
          '• 完成状态\n\n'
          '此操作不可恢复！',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('确定重置'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _resetWordbook();
    }
  }

  /// 重置词库
  Future<void> _resetWordbook() async {
    try {
      if (!mounted) return;
      
      // 显示加载提示
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final studyRecordService = context.read<StudyRecordService>();
      final wordService = context.read<WordService>();
      final settingsService = context.read<SettingsService>();

      // 重置词库
      await studyRecordService.resetWordbook(widget.wordbook.id);

      // 重新加载词库
      await wordService.loadWordbook(
        widget.wordbook,
        dailyNewCount: settingsService.dailyNewCount,
        dailyReviewCount: settingsService.dailyReviewCount,
      );

      if (!mounted) return;
      
      // 关闭加载对话框
      Navigator.of(context).pop();
      
      // 显示成功提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('词库已重置，可以重新开始学习'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('重置词库错误: $e');
      if (!mounted) return;
      
      // 关闭加载对话框
      Navigator.of(context).pop();
      
      // 显示错误提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('重置失败：$e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

/// 学习完成页面
class StudyCompleteScreen extends StatefulWidget {
  final String wordbookId;
  final DateTime? sessionStartTime; // 本次会话开始时间

  const StudyCompleteScreen({
    super.key,
    required this.wordbookId,
    this.sessionStartTime,
  });

  @override
  State<StudyCompleteScreen> createState() => _StudyCompleteScreenState();
}

class _StudyCompleteScreenState extends State<StudyCompleteScreen> {
  bool _isLoading = true;
  int _totalWords = 0;
  int _rememberedCount = 0;
  int _forgottenCount = 0;
  int _unknownCount = 0;
  int _totalSeconds = 0;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final studyRecordService = context.read<StudyRecordService>();
      
      // 获取今日学习会话
      final session = await studyRecordService.getTodaySession();
      if (session == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 获取学习时长（秒）
      final now = DateTime.now();
      _totalSeconds = session.totalDurationSecondsAt(now);

      // 按词库过滤，统计该词库的学习记录
      // 如果提供了会话开始时间，只统计本次会话开始时间之后的记录
      final wordbookRecords = session.records
          .where((r) {
            if (r.wordbookId != widget.wordbookId) return false;
            // 如果提供了会话开始时间，只统计本次会话的记录
            if (widget.sessionStartTime != null) {
              return r.studyTime.isAfter(widget.sessionStartTime!) || 
                     r.studyTime.isAtSameMomentAs(widget.sessionStartTime!);
            }
            return true;
          })
          .toList();

      print('学习完成页面：本次会话开始时间: ${widget.sessionStartTime}');
      print('学习完成页面：本次会话中该词库的记录数: ${wordbookRecords.length}');
      print('学习完成页面：本次会话中学习的单词: ${wordbookRecords.map((r) => r.word).toSet().toList()}');

      // 统计每个单词的最终状态（去重，保留最后一次状态）
      final Map<String, String> wordFinalStatus = {};
      for (var record in wordbookRecords) {
        wordFinalStatus[record.word] = record.status;
      }

      // 统计各状态数量
      _totalWords = wordFinalStatus.length;
      print('学习完成页面：本次会话中学习的唯一单词数: $_totalWords');
      _rememberedCount = 0;
      _forgottenCount = 0;
      _unknownCount = 0;

      // 对于本次会话中学习过的每个单词，检查其历史记录（交叉统计）
      for (var word in wordFinalStatus.keys) {
        // 记住：本次会话中标记为"记住"的单词数
        if (wordFinalStatus[word] == 'remembered') {
          _rememberedCount++;
          print('学习完成页面：单词 "$word" 计入"记住"');
        }
        
        // 获取单词的完整历史记录（跨日期）
        final history = await studyRecordService.getWordHistory(word, widget.wordbookId);
        
        // 不熟：本次会话中学习过的单词，只要历史记录中曾经有过"不熟"就计入
        final hasForgotten = history.any((record) => record.status == 'forgotten');
        if (hasForgotten) {
          _forgottenCount++;
          print('学习完成页面：单词 "$word" 计入"不熟"（历史记录中有不熟）');
        }
        
        // 不会：本次会话中学习过的单词，只要历史记录中曾经有过"不会"就计入
        final hasUnknown = history.any((record) => record.status == 'unknown');
        if (hasUnknown) {
          _unknownCount++;
          print('学习完成页面：单词 "$word" 计入"不会"（历史记录中有不会）');
        }
      }
      
      print('学习完成页面：统计结果 - 记住: $_rememberedCount, 不熟: $_forgottenCount, 不会: $_unknownCount');

      // 检查是否已完成（预留功能）
      final completionStatus = await studyRecordService.getDailyCompletionStatus(
        widget.wordbookId,
      );
      _isCompleted = completionStatus == 'completed';

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('加载学习完成页面数据错误: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 标记今日学习任务为已完成（预留）
  Future<void> _markAsCompleted() async {
    try {
      final studyRecordService = context.read<StudyRecordService>();
      await studyRecordService.setDailyCompletionStatus(
        widget.wordbookId,
        'completed',
      );
      setState(() {
        _isCompleted = true;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已标记为已完成'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      print('标记完成状态错误: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('标记失败，请重试'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// 格式化时长显示
  String _formatDuration(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '${h}小时${m}分钟${s}秒';
    } else if (m > 0) {
      return '${m}分钟${s}秒';
    } else {
      return '${s}秒';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('学习完成'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 完成图标
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 80,
                    ),
                    const SizedBox(height: 24),
                    
                    // 标题
                    const Text(
                      '今日学习完成！',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 本次学习总数
                    _buildStatCard(
                      icon: Icons.book,
                      label: '本次学习总数',
                      value: '$_totalWords',
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),

                    // 学习时长
                    _buildStatCard(
                      icon: Icons.timer,
                      label: '学习时长',
                      value: _formatDuration(_totalSeconds),
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 24),

                    // 统计标题
                    const Text(
                      '学习统计',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 记住/忘记/不会统计
                    _buildStatusCard(
                      label: '记住',
                      count: _rememberedCount,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 12),
                    _buildStatusCard(
                      label: '不熟',
                      count: _forgottenCount,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 12),
                    _buildStatusCard(
                      label: '不会',
                      count: _unknownCount,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 32),

                    // 标记完成按钮（预留）
                    if (!_isCompleted)
                      OutlinedButton(
                        onPressed: _markAsCompleted,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Colors.blue),
                        ),
                        child: const Text(
                          '标记今日学习任务为已完成（预留）',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    if (!_isCompleted) const SizedBox(height: 16),

                    // 签到按钮
                    ElevatedButton(
                      onPressed: () {
                        // 跳转到主页面并切换到签到标签页
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const MainScreen(initialIndex: 1),
                          ),
                          (route) => false, // 清除所有路由
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '签到',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard({
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}


