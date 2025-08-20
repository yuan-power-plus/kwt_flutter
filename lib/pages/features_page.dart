// 功能聚合页：以网格形式展示可用功能入口
import 'package:flutter/material.dart';
import 'package:kwt_flutter/pages/class_timetable_page.dart';
import 'package:kwt_flutter/pages/grades_page.dart';
import 'package:kwt_flutter/pages/level_exam_page.dart';
import 'package:kwt_flutter/services/kwt_client.dart';
import 'package:kwt_flutter/services/settings.dart';
import 'package:kwt_flutter/pages/login_page.dart';

/// 功能入口页
class FeaturesPage extends StatelessWidget {
  const FeaturesPage({super.key, required this.client});
  final KwtClient client;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('功能区域', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: Colors.black)),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const int crossAxisCount = 3; // 固定三列
                const double spacing = 16;
                final double itemWidth = (constraints.maxWidth - spacing * (crossAxisCount - 1)) / crossAxisCount;
                final double itemHeight = itemWidth * 0.66;
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  children: [
                    _tileSized(context, '班级课表', Icons.class_, itemWidth, itemHeight, () => _push(context, ClassTimetablePage(client: client))),
                    _tileSized(context, '课程成绩', Icons.grade, itemWidth, itemHeight, () => _push(context, GradesPage(client: client))),
                    _tileSized(context, '等级考试成绩', Icons.assessment, itemWidth, itemHeight, () => _push(context, LevelExamPage(client: client))),
                  ],
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  /// 功能卡片
  Widget _tileSized(BuildContext context, String label, IconData icon, double w, double h, VoidCallback onTap) {
    return InkWell(
      onTap: () async {
        final settings = SettingsService();
        final loggedIn = await settings.isLoggedIn();
        if (!loggedIn) {
          // 未登录：跳转到登录页
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginPage()));
          final v = await settings.isLoggedIn();
          if (v) {
            onTap();
          }
          return;
        }
        onTap();
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 1.5,
        child: SizedBox(
          width: w,
          height: h,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: w * 0.22, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: w * 0.11, fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  /// 通用跳转封装
  Future<void> _push(BuildContext context, Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}


