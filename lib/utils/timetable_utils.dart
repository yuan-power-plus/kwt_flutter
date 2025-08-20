import 'package:kwt_flutter/models/models.dart';

// 统一的节次文本格式化：将如“01~02节”“第01-02节”“01-02”等规范为“第01-02节”
String formatSectionsFromWeekText(String weekText) {
  final m1 = RegExp(r'(第?\s*(\d{1,2})\s*[-~至]\s*(\d{1,2})\s*节)').firstMatch(weekText);
  if (m1 != null) {
    return '第${m1.group(2)!.padLeft(2, '0')}-${m1.group(3)!.padLeft(2, '0')}节';
  }
  final m2 = RegExp(r'((\d{1,2})\s*[-~至]\s*(\d{1,2})\s*节)').firstMatch(weekText);
  if (m2 != null) {
    return '第${m2.group(2)!.padLeft(2, '0')}-${m2.group(3)!.padLeft(2, '0')}节';
  }
  final m3 = RegExp(r'(\d{1,2})\s*[-~至]\s*(\d{1,2})').firstMatch(weekText);
  if (m3 != null) {
    return '第${m3.group(1)!.padLeft(2, '0')}-${m3.group(2)!.padLeft(2, '0')}节';
  }
  return weekText;
}

// 根据 TimetableEntry 的各字段计算最终节次展示文案
String formatSections(TimetableEntry e) {
  if (e.sectionText.isNotEmpty) {
    return formatSectionsFromWeekText(e.sectionText);
  }
  if (e.weekText.isNotEmpty) {
    final s = formatSectionsFromWeekText(e.weekText);
    if (s.contains('节')) return s;
  }
  switch (e.sectionIndex) {
    case 1:
      return '第01-02节';
    case 2:
      return '第03-04节';
    case 3:
      return '第06-07节';
    case 4:
      return '第08-09节';
    case 5:
      return '第10-11节';
    default:
      return '';
  }
}

// 统一的地点压缩：去空白、规范破折号、去冗余“潘安湖”，保留后两段
String compactLocation(String raw) {
  var s = raw.replaceAll(RegExp(r"\s+"), "");
  s = s.replaceAll('－', '-').replaceAll('—', '-').replaceAll('–', '-');
  s = s.replaceAll('潘安湖', '');
  final parts = s.split('-').where((e) => e.isNotEmpty).toList();
  if (parts.length >= 2) {
    return parts.sublist(parts.length - 2).join('-');
  }
  return parts.isNotEmpty ? parts.first : s;
}

// 将小节范围推断为第几大节（1..5），失败返回 0
int guessSectionFromText(String sectionText) {
  final m = RegExp(r'(\d{1,2})\s*~\s*(\d{1,2})').firstMatch(sectionText);
  if (m != null) {
    final start = int.tryParse(m.group(1) ?? '0') ?? 0;
    if (start <= 2) return 1;
    if (start <= 4) return 2;
    if (start <= 7) return 3;
    if (start <= 9) return 4;
    return 5;
  }
  return 0;
}


