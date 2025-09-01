import 'package:kwt_flutter/models/models.dart';

// 提取开始小节号
int extractStartSection(TimetableEntry entry) {
  // 优先从sectionText中提取
  if (entry.sectionText.isNotEmpty) {
    final match = RegExp(r'(\d{1,2})').firstMatch(entry.sectionText);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
  }
  
  // 从大节推断小节范围
  switch (entry.sectionIndex) {
    case 1: return 1;
    case 2: return 3;
    case 3: return 6;
    case 4: return 8;
    case 5: return 10;
    default: return 0;
  }
}

// 提取结束小节号
int extractEndSection(TimetableEntry entry) {
  // 优先从sectionText中提取
  if (entry.sectionText.isNotEmpty) {
    final match = RegExp(r'(\d{1,2})[-~至](\d{1,2})').firstMatch(entry.sectionText);
    if (match != null) {
      return int.tryParse(match.group(2)!) ?? 0;
    }
    // 单节次情况
    final singleMatch = RegExp(r'^(\d{1,2})节?$').firstMatch(entry.sectionText);
    if (singleMatch != null) {
      return int.tryParse(singleMatch.group(1)!) ?? 0;
    }
  }
  
  // 从大节推断小节范围
  switch (entry.sectionIndex) {
    case 1: return 2;
    case 2: return 4;
    case 3: return 7;
    case 4: return 9;
    case 5: return 11;
    default: return 0;
  }
}

// 合并连续的相同课程
List<MergedTimetableEntry> mergeContinuousCourses(List<TimetableEntry> entries) {
  if (entries.isEmpty) return [];
  
  // 按天和课程名分组
  final Map<int, Map<String, List<TimetableEntry>>> dayCoursesMap = {};
  
  for (final entry in entries) {
    dayCoursesMap.putIfAbsent(entry.dayOfWeek, () => {});
    dayCoursesMap[entry.dayOfWeek]!.putIfAbsent(entry.courseName, () => []);
    dayCoursesMap[entry.dayOfWeek]![entry.courseName]!.add(entry);
  }
  
  final List<MergedTimetableEntry> merged = [];
  
  for (final dayEntries in dayCoursesMap.values) {
    for (final courseEntries in dayEntries.values) {
      // 按开始小节排序
      courseEntries.sort((a, b) => extractStartSection(a).compareTo(extractStartSection(b)));
      
      int i = 0;
      while (i < courseEntries.length) {
        final current = courseEntries[i];
        final List<TimetableEntry> group = [current];
        int currentEnd = extractEndSection(current);
        
        // 查找连续的相同课程
        for (int j = i + 1; j < courseEntries.length; j++) {
          final next = courseEntries[j];
          final nextStart = extractStartSection(next);
          
          // 检查是否连续且为相同课程
          if (nextStart == currentEnd + 1 && 
              current.courseName == next.courseName &&
              current.teacher == next.teacher) {
            group.add(next);
            currentEnd = extractEndSection(next);
          } else {
            break;
          }
        }
        
        // 创建合并条目
        final startSection = extractStartSection(group.first);
        final endSection = extractEndSection(group.last);
        
        merged.add(MergedTimetableEntry(
          courseName: current.courseName,
          teacher: current.teacher,
          credits: current.credits,
          location: current.location,
          sectionText: '${startSection.toString().padLeft(2, '0')}-${endSection.toString().padLeft(2, '0')}节',
          weekText: current.weekText,
          dayOfWeek: current.dayOfWeek,
          startSection: startSection,
          endSection: endSection,
          rowSpan: group.length,
          originalEntries: group,
        ));
        
        i += group.length;
      }
    }
  }
  
  return merged;
}

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


