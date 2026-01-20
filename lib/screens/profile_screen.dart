import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/study_record_service.dart';
import '../services/settings_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  String _username = '用户';
  int _consecutiveCheckInDays = 0;
  int _totalCheckInDays = 0;
  int _totalStudyHours = 0;
  int _rememberedWordsCount = 0;
  double _avgDailyStudyWords = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final studyRecordService = context.read<StudyRecordService>();
      final settingsService = context.read<SettingsService>();

      // 加载用户名
      _username = settingsService.username;

      // 加载统计数据
      _consecutiveCheckInDays = await studyRecordService.getConsecutiveCheckInDays();
      _totalCheckInDays = await studyRecordService.getTotalCheckInDays();
      _totalStudyHours = await studyRecordService.getTotalStudyHours();
      _rememberedWordsCount = await studyRecordService.getTotalRememberedWordsCount();
      _avgDailyStudyWords = await studyRecordService.getAvgDailyStudyWords();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('加载个人中心数据错误: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveUsername(String username) async {
    final settingsService = context.read<SettingsService>();
    await settingsService.setUsername(username);
    setState(() {
      _username = settingsService.username;
    });
  }

  Future<void> _editUsername() async {
    final TextEditingController controller = TextEditingController(text: _username);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑用户名'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '请输入用户名',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _saveUsername(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 监听 SettingsService 的变化，更新用户名
    final settingsService = context.watch<SettingsService>();
    if (_username != settingsService.username) {
      _username = settingsService.username;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('个人中心'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 用户名
                    _buildUsernameCard(),
                    const SizedBox(height: 16),
                    // 签到和学习时长统计（一行）
                    _buildStatsRow(),
                    const SizedBox(height: 16),
                    // 已记住的单词量
                    _buildStatCard(
                      icon: Icons.book,
                      label: '已记住的单词量',
                      value: '$_rememberedWordsCount',
                      color: Colors.green,
                    ),
                    const SizedBox(height: 16),
                    // 平均每日学习单词量
                    _buildStatCard(
                      icon: Icons.trending_up,
                      label: '平均每日学习单词量',
                      value: _avgDailyStudyWords.toStringAsFixed(1),
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    // 主题设置（预留）
                    _buildThemeCard(),
                    const SizedBox(height: 16),
                    // 版本号（预留）
                    _buildVersionCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildUsernameCard() {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.person),
        ),
        title: Text(
          _username,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: _editUsername,
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              icon: Icons.calendar_today,
              label: '连续签到',
              value: '$_consecutiveCheckInDays 天',
              color: Colors.blue,
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.grey[300],
            ),
            _buildStatItem(
              icon: Icons.calendar_month,
              label: '累积签到',
              value: '$_totalCheckInDays 天',
              color: Colors.green,
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.grey[300],
            ),
            _buildStatItem(
              icon: Icons.timer,
              label: '累积学习',
              value: '$_totalStudyHours 小时',
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
      ),
    );
  }

  Widget _buildThemeCard() {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: const Icon(Icons.palette),
        title: const Text('主题'),
        subtitle: const Text('白天（预留）'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // TODO: 主题切换功能（预留）
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('主题切换功能开发中')),
          );
        },
      ),
    );
  }

  Widget _buildVersionCard() {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: const Icon(Icons.info),
        title: const Text('版本号'),
        subtitle: const Text('1.0.0（预留）'),
      ),
    );
  }
}

