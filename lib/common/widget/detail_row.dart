import 'package:flutter/material.dart';

/// 通用的详情行组件 - 用于显示标签值对信息
class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.labelWidth = 60,
    this.spacing = 12,
    this.labelStyle,
    this.valueStyle,
    this.iconColor,
    this.iconSize = 18,
  });

  final String label;
  final String value;
  final IconData icon;
  final double labelWidth;
  final double spacing;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final Color? iconColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultIconColor = iconColor ?? Colors.grey[600];
    final defaultLabelStyle = labelStyle ?? TextStyle(
      color: Colors.grey[600],
      fontWeight: FontWeight.w500,
    );
    final defaultValueStyle = valueStyle ?? const TextStyle(
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: defaultIconColor, size: iconSize),
          SizedBox(width: spacing),
          SizedBox(
            width: labelWidth,
            child: Text(
              '$label：',
              style: defaultLabelStyle,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: defaultValueStyle,
            ),
          ),
        ],
      ),
    );
  }
}

/// 预设样式的详情行组件变体
class CompactDetailRow extends DetailRow {
  const CompactDetailRow({
    super.key,
    required super.label,
    required super.value,
    required super.icon,
  }) : super(
    labelWidth: 50,
    spacing: 8,
    iconSize: 16,
  );
}

/// 课程详情行组件
class CourseDetailRow extends DetailRow {
  const CourseDetailRow({
    super.key,
    required super.label,
    required super.value,
    required super.icon,
  }) : super(
    labelWidth: 60,
    spacing: 12,
    iconSize: 18,
  );
}