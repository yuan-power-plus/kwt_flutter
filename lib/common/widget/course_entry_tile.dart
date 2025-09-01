import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../utils/timetable_utils.dart';
import 'detail_row.dart';

/// 通用的课程条目展示组件
class CourseEntryTile extends StatelessWidget {
  const CourseEntryTile({
    super.key,
    required this.entry,
    this.onTap,
    this.showLocation = true,
    this.compact = false,
  });

  final TimetableEntry entry;
  final VoidCallback? onTap;
  final bool showLocation;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            entry.courseName,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: compact ? 12 : 13,
            ),
            textAlign: TextAlign.center,
          ),
          if (showLocation && !_shouldHideLocation(entry.courseName)) ...[
            SizedBox(height: compact ? 2 : 4),
            Text(
              compactLocation(entry.location),
              style: textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontSize: compact ? 10 : 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  /// 判断是否应该隐藏地点信息（如体育课）
  bool _shouldHideLocation(String courseName) {
    return courseName.trim() == '大学体育A';
  }
}

/// 课程详情弹窗工具类
class CourseDetailDialog {
  /// 显示课程详情弹窗
  static void show(BuildContext context, TimetableEntry entry) {
    FocusScope.of(context).unfocus();
    showDialog(
      context: context,
      builder: (_) => CourseDetailDialogWidget(entry: entry),
    );
  }
}

/// 课程详情弹窗组件
class CourseDetailDialogWidget extends StatelessWidget {
  const CourseDetailDialogWidget({
    super.key,
    required this.entry,
  });

  final TimetableEntry entry;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.class_, color: Colors.blue[600], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.courseName,
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
            final bool isPe = entry.courseName.contains('大学体育') || 
                              entry.courseName.contains('大学物理实验');
            final String teacherValue = isPe
                ? (entry.location.isNotEmpty ? entry.location : entry.teacher)
                : entry.teacher;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                DetailRow(label: '教师', value: teacherValue, icon: Icons.person),
                if (!isPe) DetailRow(label: '地点', value: entry.location, icon: Icons.location_on),
                if (!isPe && _hasScheduleInfo(entry))
                  DetailRow(label: '节次', value: formatSections(entry), icon: Icons.schedule),
                if (!isPe && entry.credits.isNotEmpty) 
                  DetailRow(label: '学分', value: entry.credits, icon: Icons.star),
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
    );
  }

  /// 检查是否有课程安排信息
  bool _hasScheduleInfo(TimetableEntry entry) {
    return entry.weekText.isNotEmpty || 
           entry.sectionIndex > 0 || 
           entry.sectionText.isNotEmpty;
  }
}

