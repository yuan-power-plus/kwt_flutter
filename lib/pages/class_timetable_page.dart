// 班级课表页面：按学期与班级查询班级课表并网格展示
import 'package:flutter/material.dart';
import 'package:kwt_flutter/models/models.dart';
import 'package:kwt_flutter/services/kwt_client.dart';
import 'package:kwt_flutter/utils/timetable_utils.dart';

/// 班级课表页
class ClassTimetablePage extends StatefulWidget {
  const ClassTimetablePage({super.key, required this.client});
  final KwtClient client;

  @override
  State<ClassTimetablePage> createState() => _ClassTimetablePageState();
}

class _ClassTimetablePageState extends State<ClassTimetablePage> {
  final _termCtrl = TextEditingController();
  List<String> _termOptions = const [];
  final _classCtrl = TextEditingController();
  bool _busy = false;
  String? _error;
  List<TimetableEntry> _list = const [];

  /// 触发查询：校验输入并请求后端
  Future<void> _load() async {
    // 校验班级名称是否填写
    if (_classCtrl.text.trim().isEmpty) {
      setState(() => _error = '请输入班级名称');
      return;
    }
    
    setState(() {
      _busy = true;
      _error = null;
    });
    
    try {
      final data = await widget.client.fetchClassTimetableStructured(
        term: _termCtrl.text.trim(),
        timeMode: KwtClient.defaultTimeMode,
        className: _classCtrl.text.trim(),
      );
      setState(() => _list = data);
    } on AuthExpiredException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = '加载失败: $e');
    } finally {
      setState(() => _busy = false);
    }
    
    // 查询后取消班级输入框焦点
    FocusScope.of(context).unfocus();
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  /// 初始化学期选项并默认选择最新学期
  Future<void> _init() async {
    try {
      _termOptions = await widget.client.fetchTermOptions();
      if (_termCtrl.text.isEmpty && _termOptions.isNotEmpty) {
        _termCtrl.text = _termOptions.first; // 最新学期
      }
    } catch (_) {}
    setState(() {});
  }

  @override
  void dispose() {
    _termCtrl.dispose();
    _classCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('班级课表', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: true,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [],
      ),
      body: Column(
        children: [
          // 查询条件区域
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
              border: Border.all(color: Colors.grey[100]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.schedule, color: Colors.blue[600], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '查询条件',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  runSpacing: 16,
                  spacing: 16,
                  children: [
                    SizedBox(
                      width: 200,
                      child: _termOptions.isEmpty
                          ? TextField(
                              controller: _termCtrl,
                              decoration: InputDecoration(
                                labelText: '学年学期',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                                prefixIcon: Icon(Icons.calendar_today, color: Colors.grey[600]),
                              ),
                            )
                          : DropdownButtonFormField<String>(
                              value: _termOptions.contains(_termCtrl.text) ? _termCtrl.text : null,
                              items: _termOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                              onChanged: (v) => setState(() => _termCtrl.text = v ?? _termCtrl.text),
                              decoration: InputDecoration(
                                labelText: '学年学期',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                                prefixIcon: Icon(Icons.calendar_today, color: Colors.grey[600]),
                              ),
                            ),
                    ),
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _classCtrl,
                        decoration: InputDecoration(
                          labelText: '班级',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          prefixIcon: Icon(Icons.class_, color: Colors.grey[600]),
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _busy ? null : _load,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('查询', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),

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

          // 提示：左右滑动查看更多（放在查询条件与课表卡片之间）
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
                : _GridWeek(entries: _list),
          ),
        ],
      ),
    );
  }
}

class _GridWeek extends StatelessWidget {
  const _GridWeek({required this.entries});
  final List<TimetableEntry> entries;

  @override
  Widget build(BuildContext context) {
    final grid = _buildGrid(entries);
    return Container(
      margin: const EdgeInsets.all(16),
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
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        children: [
          Expanded(
            child: PageView(
              children: [
                _buildSubgrid(grid, const [1, 2, 3, 4, 5]),
                _buildSubgrid(grid, const [6, 7]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubgrid(Map<int, Map<int, List<TimetableEntry>>> grid, List<int> dayIndices) {
    return Column(
      children: [
        // 页头：显示星期
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
                    child: Text(
                      _weekdayName(d),
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
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
                                ['一', '二', '三', '四', '五'][section - 1],
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

  String _weekdayName(int i) {
    const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return names[i - 1];
  }

  Map<int, Map<int, List<TimetableEntry>>> _buildGrid(List<TimetableEntry> list) {
    final map = <int, Map<int, List<TimetableEntry>>>{};
    for (final e in list) {
      final section = e.sectionIndex > 0 ? e.sectionIndex : guessSectionFromText(e.sectionText);
      if (section <= 0 || section > 5) continue;
      map.putIfAbsent(section, () => {});
      map[section]!.putIfAbsent(e.dayOfWeek, () => []);
      map[section]![e.dayOfWeek]!.add(e);
    }
    return map;
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
                for (int i = 0; i < entries.length; i++) ...[
                  GestureDetector(
                    onTap: () => _showDetail(context, entries[i]),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: _EntryTile(entry: entries[i]),
                    ),
                  ),
                  if (i != entries.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: DashedDivider(thickness: 1, dashWidth: 6, dashGap: 4),
                    ),
                ],
              ],
            ),
    );
  }

}

class DashedDivider extends StatelessWidget {
  const DashedDivider({super.key, this.color, this.thickness = 1, this.dashWidth = 5, this.dashGap = 3});
  final Color? color;
  final double thickness;
  final double dashWidth;
  final double dashGap;

  @override
  Widget build(BuildContext context) {
    final lineColor = color ?? Colors.grey[300] ?? Colors.grey;
    return SizedBox(
      height: thickness,
      width: double.infinity,
      child: CustomPaint(
        painter: _DashedLinePainter(color: lineColor, thickness: thickness, dashWidth: dashWidth, dashGap: dashGap),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.color, required this.thickness, required this.dashWidth, required this.dashGap});
  final Color color;
  final double thickness;
  final double dashWidth;
  final double dashGap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke;
    double x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      final x2 = (x + dashWidth).clamp(0.0, size.width).toDouble();
      canvas.drawLine(Offset(x, y), Offset(x2, y), paint);
      x += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.thickness != thickness ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashGap != dashGap;
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});
  final TimetableEntry entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          entry.courseName,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
        (entry.courseName.trim() == '大学体育A')
            ? const SizedBox.shrink()
            : Column(
                children: [
                  const SizedBox(height: 4),
                  Text(
                    compactLocation(entry.location),
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ],
    );
  }
}

// 位置压缩逻辑改为工具方法 compactLocation

void _showDetail(BuildContext context, TimetableEntry e) {
  FocusScope.of(context).unfocus();
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.class_, color: Colors.blue[600], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              e.courseName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Builder(builder: (context) {
            final bool isPe = e.courseName.contains('大学体育');
            final String teacherValue = isPe
                ? (e.location.isNotEmpty ? e.location : e.teacher)
                : e.teacher;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _DetailRow('教师', teacherValue, Icons.person),
                if (!isPe) _DetailRow('地点', e.location, Icons.location_on),
                if (!isPe && e.credits.isNotEmpty) _DetailRow('学分', e.credits, Icons.star),
              ],
            );
          }),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value, this.icon);
  
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 18),
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            child: Text(
              '$label：',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatSections(TimetableEntry e) => formatSections(e);


