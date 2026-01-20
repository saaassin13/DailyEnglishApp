import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/wordbook.dart';
import '../screens/study_detail_screen.dart';
import '../services/word_service.dart';
import '../services/study_record_service.dart';
import '../services/settings_service.dart';

class WordbookSelectionScreen extends StatefulWidget {
  const WordbookSelectionScreen({super.key});

  @override
  State<WordbookSelectionScreen> createState() => _WordbookSelectionScreenState();
}

class _WordbookSelectionScreenState extends State<WordbookSelectionScreen> {
  int _selectedTabIndex = 0; // 0: 待复习, 1: 待新学, 2: 新词待选
  
  // 统计数据
  int _reviewCount = 0;
  int _newWordCount = 0;
  int _unselectedCount = 0;
  
  // 词库进度数据（只存储当前选中词库的进度）
  final Map<String, Map<String, int>> _wordbookProgress = {};
  final Map<String, bool> _wordbookLoading = {};
  VoidCallback? _studyRecordListener;
  bool _isReloading = false;
  bool _isTodayCompleted = false; // 今日任务是否已完成

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
      _attachStudyRecordListener();
      _loadStatistics();
    });
  }

  /// 初始化服务之间的关联
  void _initializeServices() {
    final wordService = context.read<WordService>();
    final studyRecordService = context.read<StudyRecordService>();
    final settingsService = context.read<SettingsService>();
    
    wordService.setStudyRecordService(studyRecordService);
    wordService.setSettingsService(settingsService);
  }

  void _attachStudyRecordListener() {
    // 监听学习记录变更：保存每个单词状态后，词库页要能及时更新“熟悉/不熟/未选”
    final studyRecordService = context.read<StudyRecordService>();
    _studyRecordListener = () {
      _reloadStatisticsFromStudyRecordChange();
    };
    studyRecordService.addListener(_studyRecordListener!);
  }

  void _detachStudyRecordListener() {
    final listener = _studyRecordListener;
    if (listener == null) return;
    try {
      context.read<StudyRecordService>().removeListener(listener);
    } catch (_) {
      // ignore: provider disposed
    }
    _studyRecordListener = null;
  }

  Future<void> _reloadStatisticsFromStudyRecordChange() async {
    if (_isReloading) return;
    _isReloading = true;
    try {
      if (!mounted) return;
      await _loadStatistics();
      if (!mounted) return;
      setState(() {});
    } finally {
      _isReloading = false;
    }
  }

  @override
  void dispose() {
    _detachStudyRecordListener();
    super.dispose();
  }

  /// 加载统计数据
  Future<void> _loadStatistics() async {
    try {
      final studyRecordService = context.read<StudyRecordService>();
      final settingsService = context.read<SettingsService>();

      // 获取当前词库ID
      final currentWordbookId = settingsService.currentWordbookId;
      final dailyTotalTarget = settingsService.dailyTotalCount;
      // 复习优先，但复习最多不超过每日总量
      final reviewFetchLimit = dailyTotalTarget;
      
      // 检查全局今日任务是否已完成
      final globalCompletionStatus = await studyRecordService.getGlobalDailyCompletionStatus();
      _isTodayCompleted = globalCompletionStatus == 'completed';
      
      if (currentWordbookId != null) {
        // 获取待复习数量（复习优先；最多取到每日总量）
        final reviewWords = await studyRecordService.getReviewWords(
          currentWordbookId,
          limit: reviewFetchLimit,
        );
        _reviewCount = reviewWords.length;

        // 待新学数量：用"每日总量 - 待复习"补齐；若无复习则全部新学
        _newWordCount = (dailyTotalTarget - _reviewCount).clamp(0, dailyTotalTarget);

        // 获取新词待选数量
        final currentWordbook = Wordbook.predefinedWordbooks
            .firstWhere((wb) => wb.id == currentWordbookId, orElse: () => Wordbook.predefinedWordbooks.first);
        _unselectedCount = await context.read<WordService>().getUnselectedWordCount(currentWordbook);

        // 只加载当前选中词库的进度
        await _loadWordbookProgress(currentWordbookId);
      } else {
        // 如果没有当前词库，使用第一个词库的统计
        if (Wordbook.predefinedWordbooks.isNotEmpty) {
          final firstWordbook = Wordbook.predefinedWordbooks.first;
          
          final reviewWords = await studyRecordService.getReviewWords(
            firstWordbook.id,
            limit: reviewFetchLimit,
          );
          _reviewCount = reviewWords.length;
          _newWordCount = (dailyTotalTarget - _reviewCount).clamp(0, dailyTotalTarget);
          _unselectedCount = await context.read<WordService>().getUnselectedWordCount(firstWordbook);
          
          // 加载第一个词库的进度
          await _loadWordbookProgress(firstWordbook.id);
        } else {
          _isTodayCompleted = false;
        }
      }
    } catch (e) {
      print('加载统计数据错误: $e');
    }
  }

  /// 加载指定词库的进度
  Future<void> _loadWordbookProgress(String wordbookId) async {
    final studyRecordService = context.read<StudyRecordService>();
    final wordbook = Wordbook.predefinedWordbooks.firstWhere(
      (wb) => wb.id == wordbookId,
      orElse: () => Wordbook.predefinedWordbooks.first,
    );

    if (!mounted) return;
    setState(() {
      _wordbookLoading[wordbookId] = true;
    });

    try {
      final progress = await studyRecordService.getWordbookProgress(
        wordbookId,
        wordbook.totalWords,
      );
      if (!mounted) return;
      setState(() {
        _wordbookProgress[wordbookId] = progress;
        _wordbookLoading[wordbookId] = false;
      });
    } catch (e) {
      print('加载词库 ${wordbook.name} 进度错误: $e');
      if (!mounted) return;
      setState(() {
        _wordbookLoading[wordbookId] = false;
      });
    }
  }

  /// 点击词库，设置为当前学习词库
  Future<void> _selectWordbook(Wordbook wordbook) async {
    final settingsService = context.read<SettingsService>();
    await settingsService.setCurrentWordbookId(wordbook.id);
    
    // 重新加载统计数据
    await _loadStatistics();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已选择词库：${wordbook.name}'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  /// 双击词库，进入学习页面（预留）
  void _enterStudyPage(Wordbook wordbook) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudyDetailScreen(wordbook: wordbook),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部标题栏
            _buildHeader(),
            
            // 每日学习量显示
            _buildDailyStudySection(),
            
            // 三个标签（今日任务完成时隐藏）
            if (!_isTodayCompleted) _buildTabs(),
            
            // 词库列表
            Expanded(
              child: _buildWordbookList(),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建顶部标题栏
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '词库',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'reset_current') {
                _showResetCurrentWordbookDialog();
              }
            },
            itemBuilder: (context) {
              final settingsService = context.read<SettingsService>();
              final currentWordbookId = settingsService.currentWordbookId;
              
              if (currentWordbookId == null) {
                return [
                  const PopupMenuItem(
                    enabled: false,
                    child: Text('请先选择一个词库'),
                  ),
                ];
              }
              
              final currentWordbook = Wordbook.predefinedWordbooks.firstWhere(
                (wb) => wb.id == currentWordbookId,
                orElse: () => Wordbook.predefinedWordbooks.first,
              );
              
              return [
                PopupMenuItem(
                  value: 'reset_current',
                  child: Row(
                    children: [
                      const Icon(Icons.refresh, size: 20),
                      const SizedBox(width: 8),
                      Text('重置词库"${currentWordbook.name}"'),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }

  /// 构建每日学习量显示
  Widget _buildDailyStudySection() {
    final dailyTotalTarget = context.watch<SettingsService>().dailyTotalCount;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // 每日学习量数字/卡片（点击打开设置）
          GestureDetector(
            onTap: _openDailyTargetSettings,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$dailyTotalTarget',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const Text(
                  '每日学习量',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // 说明文字
          Expanded(
            child: Text(
              '每日学习量 = 当日复习 + 当日新学（复习优先，不足则新学补齐）',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
          // 设置按钮
          GestureDetector(
            onTap: _openDailyTargetSettings,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '设置',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDailyTargetSettings() async {
    if (!mounted) return;
    final settingsService = context.read<SettingsService>();
    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _DailyTargetSettingsSheet(
        initialTotal: settingsService.dailyTotalCount,
      ),
    );

    if (!mounted) return;
    if (result == null) return;

    await settingsService.setDailyTotalCount(result);
    if (!mounted) return;
    await _loadStatistics();
    if (!mounted) return;
    setState(() {});
  }

  /// 构建三个标签
  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildTab(0, '待复习', _reviewCount, Colors.grey),
          const SizedBox(width: 8),
          _buildTab(1, '待新学', _newWordCount, Colors.grey),
          const SizedBox(width: 8),
          _buildTab(2, '新词待选', _unselectedCount, Colors.orange),
        ],
      ),
    );
  }

/// 构建单个标签
Widget _buildTab(int index, String label, int count, Color color) {
  final isSelected = _selectedTabIndex == index;
  
  return Expanded(
    child: GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8), // 减少 horizontal padding 从 12 到 8
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : Colors.grey[100],
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, // 添加这行，让 Row 只占用最小空间
          children: [
            Flexible( // 使用 Flexible 包裹 Text，允许文本在空间不足时缩小
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected ? Colors.blue : Colors.black87,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis, // 添加溢出处理
                maxLines: 1,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

  /// 构建词库列表
  Widget _buildWordbookList() {
    final settingsService = context.watch<SettingsService>();
    final currentWordbookId = settingsService.currentWordbookId;

    if (Wordbook.predefinedWordbooks.isEmpty) {
      return const Center(
        child: Text('没有找到词库'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: Wordbook.predefinedWordbooks.length,
      itemBuilder: (context, index) {
        final wordbook = Wordbook.predefinedWordbooks[index];
        final isSelected = wordbook.id == currentWordbookId;
        // 只显示选中词库的进度
        final progress = isSelected ? _wordbookProgress[wordbook.id] : null;
        final isLoading = isSelected ? (_wordbookLoading[wordbook.id] ?? false) : false;

        return _buildWordbookItem(wordbook, isSelected, progress, isLoading);
      },
    );
  }

  /// 构建词库列表项
  Widget _buildWordbookItem(
    Wordbook wordbook,
    bool isSelected,
    Map<String, int>? progress,
    bool isLoading,
  ) {
    final familiar = progress?['familiar'] ?? 0;
    final unfamiliar = progress?['unfamiliar'] ?? 0;
    final unselected = progress?['unselected'] ?? 0;
    final total = wordbook.totalWords;
    final learned = familiar + unfamiliar;
    final progressPercent = total > 0 ? (learned / total) : 0.0;

    return GestureDetector(
      onTap: () => _selectWordbook(wordbook),
      onDoubleTap: () => _enterStudyPage(wordbook),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey[200]!,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 词库名称和选中状态
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (isSelected)
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 20,
                      )
                    else
                      const Icon(
                        Icons.radio_button_unchecked,
                        color: Colors.grey,
                        size: 20,
                      ),
                    const SizedBox(width: 8),
                    Text(
                      wordbook.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.blue : Colors.black87,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onPressed: () {
                    // TODO: 显示更多选项
                  },
                ),
              ],
            ),
            
            // 只在选中且有进度数据时显示统计信息
            if (isSelected) ...[
              const SizedBox(height: 12),
              if (isLoading)
                const LinearProgressIndicator()
              else if (progress != null) ...[
                // 进度信息
                Row(
                  children: [
                    _buildProgressItem('熟悉', familiar, Colors.green),
                    const SizedBox(width: 8),
                    _buildProgressItem('不熟', unfamiliar, Colors.orange),
                    const SizedBox(width: 8),
                    _buildProgressItem('未选', unselected, Colors.grey),
                  ],
                ),
                const SizedBox(height: 8),
                
                // 进度条
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressPercent,
                    minHeight: 6,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                
                // 进度文字
                Text(
                  '$learned/$total | 预计还需 ${_calculateRemainingDays(learned, total)} 天完成',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// 显示重置当前词库确认对话框
  Future<void> _showResetCurrentWordbookDialog() async {
    final settingsService = context.read<SettingsService>();
    final currentWordbookId = settingsService.currentWordbookId;
    
    if (currentWordbookId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先选择一个词库'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    final currentWordbook = Wordbook.predefinedWordbooks.firstWhere(
      (wb) => wb.id == currentWordbookId,
      orElse: () => Wordbook.predefinedWordbooks.first,
    );
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置词库'),
        content: Text(
          '确定要重置词库"${currentWordbook.name}"吗？\n\n'
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
      await _resetCurrentWordbook(currentWordbook);
    }
  }

  /// 重置当前词库
  Future<void> _resetCurrentWordbook(Wordbook wordbook) async {
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

      // 重置词库
      await studyRecordService.resetWordbook(wordbook.id);

      // 重新加载统计数据
      await _loadStatistics();
      
      // 重新加载词库进度
      await _loadWordbookProgress(wordbook.id);

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

  /// 构建进度项
  Widget _buildProgressItem(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label $count',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  /// 计算预计完成天数
  String _calculateRemainingDays(int learned, int total) {
    if (learned >= total) return '0';
    
    final remaining = total - learned;
    final dailyTotal = _reviewCount + _newWordCount;
    
    if (dailyTotal <= 0) return '365+';
    
    final days = (remaining / dailyTotal).ceil();
    return days > 365 ? '365+' : '$days';
  }
}

class _DailyTargetSettingsSheet extends StatefulWidget {
  final int initialTotal;

  const _DailyTargetSettingsSheet({
    required this.initialTotal,
  });

  @override
  State<_DailyTargetSettingsSheet> createState() => _DailyTargetSettingsSheetState();
}

class _DailyTargetSettingsSheetState extends State<_DailyTargetSettingsSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTotal.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + bottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '设置每日学习单词数',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '每日学习总数',
                hintText: '例如：25',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '展示的每日学习量始终等于你设置的总数；复习优先，不足则新学补齐。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final value = int.tryParse(_controller.text.trim());
                      if (value == null || value < 0) return;
                      Navigator.of(context).pop(value);
                    },
                    child: const Text('保存'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

