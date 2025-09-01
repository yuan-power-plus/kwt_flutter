// 个人课表页面：按周展示个人课表，支持自动推算周次、选择周次与刷新
import 'package:flutter/material.dart';
import 'package:kwt_flutter/models/models.dart';
import 'package:kwt_flutter/services/kwt_client.dart';
import 'package:kwt_flutter/services/settings.dart';
import 'package:kwt_flutter/utils/timetable_utils.dart';
import 'package:kwt_flutter/pages/login_page.dart';
import 'package:kwt_flutter/common/widget/detail_row.dart';
import 'package:kwt_flutter/common/widget/course_entry_tile.dart';
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
  /// 页面构建：顶部信息栏、提示、课表内容
  Widget build(BuildContext context) {
    final monday = _calcMonday();
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));
    final grid = _buildGrid(); // section 1..5 -> day 1..7
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部信息栏
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.blue[600], size: 24),
                      const SizedBox(width: 12),
                      Text(
                        '第$_weekNo周',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${days.first.year}/${days.first.month}月',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                          icon: Icon(Icons.date_range, color: Colors.blue[600]),
                          label: Text('选择周次', style: TextStyle(color: Colors.blue[600])),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : _load,
                          icon: Icon(Icons.refresh, color: Colors.white),
                          label: const Text('刷新', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 错误信息
            if (_error != null)
              Container(
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
              ),

            // 提示：左右滑动查看更多
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.swipe_left, size: 16, color: Colors.grey),
                  SizedBox(width: 6),
                  Text('向左滑动查看更多信息', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),

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
                  : _buildTimetableGrid(days, grid),
            ),
          ],
        ),
      ),
    );
  }

  /// 课表分页容器：按工作日/周末拆分为两页
  Widget _buildTimetableGrid(List<DateTime> days, Map<int, Map<int, List<TimetableEntry>>> grid) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Expanded(
            child: PageView(
              children: [
                _buildTimetableSubgrid(days, grid, [1, 2, 3, 4, 5]),
                _buildTimetableSubgrid(days, grid, [6, 7]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 单页子表格：显示若干天的节次表头与课程单元格
  Widget _buildTimetableSubgrid(List<DateTime> days, Map<int, Map<int, List<TimetableEntry>>> grid, List<int> dayIndices) {
    return Column(
      children: [
        // 页头：该页显示的星期与日期
        Container(
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  '节次',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              for (final d in dayIndices)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Colors.blue[200]!),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _weekdayName(d),
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${days[d - 1].month}.${days[d - 1].day}',
                          style: TextStyle(
                            color: Colors.blue[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Table(
              columnWidths: const {0: FixedColumnWidth(50)},
              border: TableBorder(
                horizontalInside: BorderSide(color: Colors.grey[200]!),
                verticalInside: BorderSide(color: Colors.blue[200]!),
              ),
              children: [
                for (int section = 1; section <= 5; section++)
                  TableRow(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Text(
                                _sectionLabel(section),
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      for (final d in dayIndices)
                        _Cell(entries: grid[section]?[d] ?? const []),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 根据当前日期计算本周周一日期
  DateTime _calcMonday() {
    final start = DateTime.tryParse(_dateCtrl.text.trim()) ?? DateTime.now();
    final weekday = start.weekday; // 1=Mon
    return start.subtract(Duration(days: weekday - 1));
  }

  /// 将课程列表整理为 section×weekday 的二维映射
  Map<int, Map<int, List<TimetableEntry>>> _buildGrid() {
    final map = <int, Map<int, List<TimetableEntry>>>{};
    for (final e in _timetable) {
      final section = e.sectionIndex > 0 ? e.sectionIndex : guessSectionFromText(e.sectionText);
      if (section <= 0 || section > 5) continue;
      map.putIfAbsent(section, () => {});
      map[section]!.putIfAbsent(e.dayOfWeek, () => []);
      map[section]![e.dayOfWeek]!.add(e);
    }
    return map;
  }

  /// 周几名（1..7）
  String _weekdayName(int i) {
    const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return names[i - 1];
  }

  /// 大节中文序号（1..5）
  String _sectionLabel(int i) {
    const names = ['一', '二', '三', '四', '五'];
    return names[i - 1];
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.entries});
  final List<TimetableEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minHeight: 80),
      child: entries.isEmpty
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final e in entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CourseEntryTile(
                      entry: e,
                      onTap: () => CourseDetailDialog.show(context, e),
                    ),
                  ),
              ],
            ),
    );
  }
}

// 位置压缩逻辑改为工具方法 compactLocation

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


