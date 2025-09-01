// 个人课表页面：按周展示个人课表，支持自动推算周次、选择周次与刷新
import 'package:flutter/material.dart';
import 'package:kwt_flutter/models/models.dart';
import 'package:kwt_flutter/services/kwt_client.dart';
import 'package:kwt_flutter/services/settings.dart';
import 'package:kwt_flutter/utils/timetable_utils.dart';
import 'package:kwt_flutter/pages/login_page.dart';
import 'package:kwt_flutter/common/widget/detail_row.dart';
import 'package:kwt_flutter/config/app_config.dart';

/// 个人课表页
class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key, required this.client});
  final KwtClient client;

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  final _settings = SettingsService();
  final _termCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _timeModeCtrl = TextEditingController();
  bool _busy = false;
  String? _error;
  List<TimetableEntry> _timetable = const [];
  List<MergedTimetableEntry> _mergedTimetable = const [];
  int _weekNo = 1;

  @override
  void initState() {
    super.initState();
    _initFromSettings();
  }

  /// 从设置加载默认学期与开学日期，并自动计算周次与日期
  Future<void> _initFromSettings() async {
    _termCtrl.text = await _settings.getTerm() ?? AppConfig.defaultTerm;
    final savedStart = await _settings.getStartDate() ?? '';
    _timeModeCtrl.text = KwtClient.defaultTimeMode;

    // 依据开始日期与系统时间自动设置周次与日期
    if (savedStart.isNotEmpty) {
      final autoWeek = _computeWeekFromStart(savedStart);
      _weekNo = autoWeek;
      final start = DateTime.tryParse(savedStart);
      if (start != null) {
        final rq = start.add(Duration(days: (autoWeek - 1) * 7));
        _dateCtrl.text = rq.toIso8601String().substring(0, 10);
      }
    } else {
      _dateCtrl.text = DateTime.now().toIso8601String().substring(0, 10);
      _weekNo = 1;
    }

    setState(() {});
    await _load();
  }

  @override
  void dispose() {
    _termCtrl.dispose();
    _dateCtrl.dispose();
    _timeModeCtrl.dispose();
    super.dispose();
  }

  /// 根据开学日期计算当前周次
  int _computeWeekFromStart(String startDate) {
    final start = DateTime.tryParse(startDate);
    if (start == null) return 1;
    final now = DateTime.now();
    final diff = now.difference(DateTime(start.year, start.month, start.day)).inDays;
    if (diff < 0) return 1;
    final week = (diff ~/ 7) + 1;
    return week < 1 ? 1 : week;
  }

  /// 拉取并渲染个人课表
  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await widget.client.fetchPersonalTimetableStructured(
        date: _dateCtrl.text.trim(),
        timeMode: _timeModeCtrl.text.trim(),
        termId: _termCtrl.text.trim(),
      );
      setState(() => _timetable = data);
      setState(() => _mergedTimetable = mergeContinuousCourses(data));
    } on AuthExpiredException catch (e) {
      // 登录会话失效：清 Cookie、清登录态并跳回登录
      try { await widget.client.clearCookies(); } catch (_) {}
      await _settings.clearAuth();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      setState(() => _error = '加载失败: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monday = _calcMonday();
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // 顶部周次信息
            _buildWeekHeader(days),
            
            // 错误信息
            if (_error != null) _buildErrorMessage(),
            
            // 课表内容
            Expanded(
              child: _busy
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('加载中...', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : _buildTimetableContent(days),
            ),
          ],
        ),
      ),
    );
  }

  // 构建顶部周次信息
  Widget _buildWeekHeader(List<DateTime> days) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, // 白色背景与表头保持一致
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.blue[600], size: 20),
              const SizedBox(width: 8),
              Text(
                '第$_weekNo周',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const Spacer(),
              Text(
                '${days.first.year}/${days.first.month}月',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          final no = await showDialog<int>(
                            context: context,
                            builder: (_) => _WeekPickerDialog(initial: _weekNo),
                          );
                          if (no != null) {
                            setState(() => _weekNo = no);
                            final start = DateTime.tryParse(await _settings.getStartDate() ?? _dateCtrl.text.trim());
                            if (start != null) {
                              final rq = start.add(Duration(days: (no - 1) * 7));
                              _dateCtrl.text = rq.toIso8601String().substring(0, 10);
                              _load();
                            }
                          }
                        },
                  icon: Icon(Icons.date_range, color: Colors.blue[600], size: 18),
                  label: Text('选择周次', style: TextStyle(color: Colors.blue[600], fontSize: 14)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    side: BorderSide(color: Colors.blue[600]!, width: 1),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _load,
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                  label: const Text('刷新', style: TextStyle(color: Colors.white, fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0, // 移除阴影
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 构建课表内容
  Widget _buildTimetableContent(List<DateTime> days) {
    if (_mergedTimetable.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '本周暂无课程安排',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    // 扁平化设计，不使用卡片容器
    return Column(
      children: [
        // 表头
        _buildTableHeader(days),
        // 表体
        Expanded(
          child: _buildTableBody(days),
        ),
      ],
    );
  }

  // 构建表头
  Widget _buildTableHeader(List<DateTime> days) {
    return Container(
      color: Colors.grey[100],
      child: Row(
        children: [
          Container(
            width: 50, // 与网格行保持一致
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '时间',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
                fontSize: 12, // 减小字体
              ),
              textAlign: TextAlign.center,
            ),
          ),
          for (int i = 0; i < 7; i++)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      _weekdayName(i + 1),
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 12, // 减小字体
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${days[i].month}.${days[i].day}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 构建表体
  Widget _buildTableBody(List<DateTime> days) {
    return SingleChildScrollView(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final containerWidth = constraints.maxWidth;
          return Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Stack(
              children: [
                // 基础网格
                _buildBaseGrid(),
                // 课程覆盖层
                ..._buildCourseOverlays(containerWidth),
              ],
            ),
          );
        },
      ),
    );
  }
  
  // 构建基础网格（只显示边框和时间）
  Widget _buildBaseGrid() {
    return Column(
      children: [
        // 第1-5节
        for (int section = 1; section <= 5; section++) 
          _buildBaseGridRow(section),
        // 午休分割线
        _buildBreakLine('午休'),
        // 第6-9节
        for (int section = 6; section <= 9; section++) 
          _buildBaseGridRow(section),
        // 晚休分割线
        _buildBreakLine('晚休'),
        // 第10-12节
        for (int section = 10; section <= 12; section++) 
          _buildBaseGridRow(section),
      ],
    );
  }
  
  // 构建基础网格行（固定高度）
  Widget _buildBaseGridRow(int section) {
    return Container(
      height: 60, // 固定高度
      decoration: BoxDecoration(
        border: Border(
          top: section == 1 ? BorderSide.none : BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          // 时间列
          Container(
            width: 50,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                right: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  section.toString(),
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getSectionTimeRange(section),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 8,
                    height: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // 课程列（空白区域）
          for (int day = 1; day <= 7; day++)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    left: day == 1 ? BorderSide.none : BorderSide(color: Colors.grey[300]!),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  // 构建课程覆盖层
  List<Widget> _buildCourseOverlays(double containerWidth) {
    final List<Widget> overlays = [];
    
    for (final course in _mergedTimetable) {
      final dayIndex = course.dayOfWeek - 1; // 0-6
      final startSection = course.startSection; // 1-12
      final endSection = course.endSection; // 1-12
      
      // 计算位置，考虑分割线的影响
      final cellWidth = (containerWidth - 50) / 7;
      final left = 50.0 + cellWidth * dayIndex;
      
      // 计算顶部位置和高度，考虑分割线
      double top = 0;
      double height = 0;
      
      if (startSection <= 5 && endSection <= 5) {
        // 全部在第1-5节
        top = 60.0 * (startSection - 1);
        height = 60.0 * (endSection - startSection + 1);
      } else if (startSection <= 5 && endSection > 5 && endSection <= 9) {
        // 跨越午休：从第1-5节到第6-9节
        top = 60.0 * (startSection - 1);
        height = 60.0 * (5 - startSection + 1) + 30.0 + 60.0 * (endSection - 6 + 1);
      } else if (startSection <= 5 && endSection > 9) {
        // 跨越午休和晚休：从第1-5节到第10-12节
        top = 60.0 * (startSection - 1);
        height = 60.0 * (5 - startSection + 1) + 30.0 + 60.0 * 4 + 30.0 + 60.0 * (endSection - 10 + 1);
      } else if (startSection >= 6 && startSection <= 9 && endSection <= 9) {
        // 全部在第6-9节
        top = 60.0 * 5 + 30.0 + 60.0 * (startSection - 6);
        height = 60.0 * (endSection - startSection + 1);
      } else if (startSection >= 6 && startSection <= 9 && endSection > 9) {
        // 跨越晚休：从第6-9节到第10-12节
        top = 60.0 * 5 + 30.0 + 60.0 * (startSection - 6);
        height = 60.0 * (9 - startSection + 1) + 30.0 + 60.0 * (endSection - 10 + 1);
      } else {
        // 全部在第10-12节
        top = 60.0 * 5 + 30.0 + 60.0 * 4 + 30.0 + 60.0 * (startSection - 10);
        height = 60.0 * (endSection - startSection + 1);
      }
      
      overlays.add(
        Positioned(
          left: left,
          top: top,
          width: cellWidth,
          height: height,
          child: _buildMergedCourseCell(course),
        ),
      );
    }
    
    return overlays;
  }
  
  // 构建合并的课程单元格
  Widget _buildMergedCourseCell(MergedTimetableEntry course) {
    final colors = _getCourseColors(course.colorHash);
    
    return Container(
      margin: const EdgeInsets.all(0.5),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: colors['background'],
        border: Border.all(color: colors['border']!, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 课程名称 - 主要信息
          Text(
            course.courseName,
            style: TextStyle(
              color: colors['text'],
              fontWeight: FontWeight.w600,
              fontSize: 12,
              height: 1.2,
            ),
            maxLines: null, // 允许多行显示
          ),
          // 地点信息 - 次要信息
          if (course.location.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              compactLocation(course.location),
              style: TextStyle(
                color: colors['text']!.withOpacity(0.8),
                fontSize: 10,
                height: 1.1,
              ),
              maxLines: null,
            ),
          ],
          // 教师信息 - 可选显示
          if (course.teacher.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              course.teacher,
              style: TextStyle(
                color: colors['text']!.withOpacity(0.7),
                fontSize: 9,
                height: 1.0,
              ),
              maxLines: null,
            ),
          ],
          // 节次信息
          if (course.startSection != course.endSection) ...[
            const SizedBox(height: 2),
            Text(
              '第${course.startSection}-${course.endSection}节',
              style: TextStyle(
                color: colors['text']!.withOpacity(0.6),
                fontSize: 8,
                height: 1.0,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 构建分割线（午休/晚休）
  Widget _buildBreakLine(String label) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          top: BorderSide(color: Colors.grey[300]!, width: 1),
          bottom: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
  

  // 构建课程单元格
  Widget _buildCourseCell(MergedTimetableEntry course) {
    final colors = _getCourseColors(course.colorHash);
    
    return Container(
      margin: const EdgeInsets.all(0.5), // 减少边距
      padding: const EdgeInsets.all(6), // 适当增加内边距
      decoration: BoxDecoration(
        color: colors['background'],
        border: Border.all(color: colors['border']!, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, // 使用最小尺寸
        children: [
          // 课程名称 - 主要信息
          Text(
            course.courseName,
            style: TextStyle(
              color: colors['text'],
              fontWeight: FontWeight.w600,
              fontSize: 12, // 稍微增大字体
              height: 1.2, // 行高
            ),
            maxLines: null, // 允许多行显示
            overflow: TextOverflow.visible, // 可见溢出
          ),
          // 地点信息 - 次要信息
          if (course.location.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              compactLocation(course.location),
              style: TextStyle(
                color: colors['text']!.withOpacity(0.8),
                fontSize: 10,
                height: 1.1,
              ),
              maxLines: null, // 允许多行显示
              overflow: TextOverflow.visible,
            ),
          ],
          // 教师信息 - 可选显示
          if (course.teacher.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              course.teacher,
              style: TextStyle(
                color: colors['text']!.withOpacity(0.7),
                fontSize: 9,
                height: 1.0,
              ),
              maxLines: null, // 允许多行显示
              overflow: TextOverflow.visible,
            ),
          ],
          // 节次信息
          if (course.startSection != course.endSection) ...[
            const SizedBox(height: 2),
            Text(
              '第${course.startSection}-${course.endSection}节',
              style: TextStyle(
                color: colors['text']!.withOpacity(0.6),
                fontSize: 8,
                height: 1.0,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 获取小节时间范围
  String _getSectionTimeRange(int section) {
    const timeRanges = {
      1: '08:15\n08:55',
      2: '09:00\n09:40',
      3: '09:55\n10:35',
      4: '10:40\n11:20',
      5: '11:25\n12:05',
      6: '13:50\n14:30',
      7: '14:35\n15:15',
      8: '15:30\n16:10',
      9: '16:15\n16:55',
      10: '18:30\n19:10',
      11: '19:15\n19:55',
      12: '20:00\n20:40',
    };
    return timeRanges[section] ?? '';
  }

  // 获取课程颜色主题
  Map<String, Color> _getCourseColors(int hash) {
    final colors = [
      {'background': const Color(0xFFE3F2FD), 'border': const Color(0xFF2196F3), 'text': const Color(0xFF1976D2)},
      {'background': const Color(0xFFF3E5F5), 'border': const Color(0xFF9C27B0), 'text': const Color(0xFF7B1FA2)},
      {'background': const Color(0xFFE8F5E8), 'border': const Color(0xFF4CAF50), 'text': const Color(0xFF388E3C)},
      {'background': const Color(0xFFFFF3E0), 'border': const Color(0xFFFF9800), 'text': const Color(0xFFF57C00)},
      {'background': const Color(0xFFFFEBEE), 'border': const Color(0xFFF44336), 'text': const Color(0xFFD32F2F)},
      {'background': const Color(0xFFF1F8E9), 'border': const Color(0xFF8BC34A), 'text': const Color(0xFF689F38)},
    ];
    return colors[hash.abs() % colors.length];
  }

  // 构建错误信息
  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(color: Colors.red[600]),
            ),
          ),
        ],
      ),
    );
  }



  /// 根据当前日期计算本周周一日期
  DateTime _calcMonday() {
    final start = DateTime.tryParse(_dateCtrl.text.trim()) ?? DateTime.now();
    final weekday = start.weekday; // 1=Mon
    return start.subtract(Duration(days: weekday - 1));
  }



  /// 周几名（1..7）
  String _weekdayName(int i) {
    const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return names[i - 1];
  }


}



class _WeekPickerDialog extends StatefulWidget {
  const _WeekPickerDialog({required this.initial});
  final int initial;
  @override
  State<_WeekPickerDialog> createState() => _WeekPickerDialogState();
}

class _WeekPickerDialogState extends State<_WeekPickerDialog> {
  late int _value;
  @override
  void initState() {
    super.initState();
    _value = widget.initial;
  }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择周次'),
      content: SizedBox(
        width: 260,
        child: DropdownButton<int>(
          isExpanded: true,
          value: _value,
          items: List.generate(25, (i) => i + 1).map((e) => DropdownMenuItem(value: e, child: Text('第$e周'))).toList(),
          onChanged: (v) => setState(() => _value = v ?? _value),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(context, _value), child: const Text('确定')),
      ],
    );
  }
}


