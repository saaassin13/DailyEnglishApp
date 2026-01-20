import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/study_record_service.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  DateTime _currentMonth = DateTime.now();
  Map<DateTime, String> _completionStatusMap = {};
  bool _isLoading = true;
  StudyRecordService? _studyRecordService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMonthData();
      _attachStudyRecordListener();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 确保在依赖变化时也能刷新数据（比如从其他页面跳转回来）
    if (_studyRecordService == null) {
      _attachStudyRecordListener();
    }
  }

  void _attachStudyRecordListener() {
    if (!mounted) return;
    _studyRecordService = context.read<StudyRecordService>();
    _studyRecordService?.addListener(_onStudyRecordChanged);
  }

  void _onStudyRecordChanged() {
    if (mounted) {
      _loadMonthData();
    }
  }

  @override
  void dispose() {
    _studyRecordService?.removeListener(_onStudyRecordChanged);
    super.dispose();
  }

  Future<void> _loadMonthData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final studyRecordService = context.read<StudyRecordService>();
      final statusMap = await studyRecordService.getGlobalDailyCompletionStatusForMonth(
        DateTime(_currentMonth.year, _currentMonth.month, 1),
      );

      if (!mounted) return;
      setState(() {
        _completionStatusMap = statusMap;
        _isLoading = false;
      });
    } catch (e) {
      print('加载月份数据错误: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
    _loadMonthData();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
    _loadMonthData();
  }

  void _goToCurrentMonth() {
    final now = DateTime.now();
    if (_currentMonth.year != now.year || _currentMonth.month != now.month) {
      setState(() {
        _currentMonth = DateTime(now.year, now.month, 1);
      });
      _loadMonthData();
    }
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
            
            // 日历部分
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildCalendar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final monthNames = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    final currentMonthName = monthNames[_currentMonth.month - 1];
    final currentYear = _currentMonth.year;
    final now = DateTime.now();
    final isCurrentMonth = _currentMonth.year == now.year && _currentMonth.month == now.month;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '签到',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _previousMonth,
              ),
              GestureDetector(
                onTap: isCurrentMonth ? null : _goToCurrentMonth,
                child: Text(
                  '$currentMonthName $currentYear',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isCurrentMonth ? Colors.black87 : Colors.blue,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _nextMonth,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstDayWeekday = firstDayOfMonth.weekday; // 1 = Monday, 7 = Sunday
    final daysInMonth = lastDayOfMonth.day;
    
    // 计算需要显示的天数（包括上个月的最后几天和下个月的前几天）
    final startOffset = (firstDayWeekday - 1) % 7; // 转换为周日=0的格式
    final totalCells = ((daysInMonth + startOffset + 6) ~/ 7) * 7;
    
    final now = DateTime.now();
    final isCurrentMonth = _currentMonth.year == now.year && _currentMonth.month == now.month;
    final today = now.day;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            // 星期标题
            _buildWeekdayHeaders(),
            const SizedBox(height: 8),
            // 日期网格
            _buildDateGrid(
              startOffset: startOffset,
              daysInMonth: daysInMonth,
              totalCells: totalCells,
              isCurrentMonth: isCurrentMonth,
              today: today,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekdayHeaders() {
    final weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Row(
      children: weekdays.map((day) {
        return Expanded(
          child: Center(
            child: Text(
              day,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateGrid({
    required int startOffset,
    required int daysInMonth,
    required int totalCells,
    required bool isCurrentMonth,
    required int today,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: totalCells,
      itemBuilder: (context, index) {
        if (index < startOffset) {
          // 上个月的日期
          final prevMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 0);
          final day = prevMonth.day - (startOffset - index - 1);
          return _buildDateCell(
            day: day,
            isCurrentMonth: false,
            isToday: false,
            completionStatus: 'unlearned',
          );
        } else if (index < startOffset + daysInMonth) {
          // 当前月的日期
          final day = index - startOffset + 1;
          final date = DateTime(_currentMonth.year, _currentMonth.month, day);
          final completionStatus = _completionStatusMap[date] ?? 'unlearned';
          return _buildDateCell(
            day: day,
            isCurrentMonth: true,
            isToday: isCurrentMonth && day == today,
            completionStatus: completionStatus,
          );
        } else {
          // 下个月的日期
          final day = index - startOffset - daysInMonth + 1;
          return _buildDateCell(
            day: day,
            isCurrentMonth: false,
            isToday: false,
            completionStatus: 'unlearned',
          );
        }
      },
    );
  }

  Widget _buildDateCell({
    required int day,
    required bool isCurrentMonth,
    required bool isToday,
    required String completionStatus,
  }) {
    final isCompleted = completionStatus == 'completed';
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 日期数字
          if (isToday)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$day',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            Text(
              '$day',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: isCurrentMonth ? Colors.black87 : Colors.grey[400],
                decoration: isToday ? TextDecoration.underline : null,
                decorationColor: Colors.green,
              ),
            ),
          const SizedBox(height: 4),
          // 完成状态指示器
          if (isCurrentMonth)
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green : Colors.grey[300],
                shape: BoxShape.circle,
              ),
            )
          else
            const SizedBox(height: 6),
        ],
      ),
    );
  }
}

