// 功能聚合页：以网格形式展示可用功能入口
import 'package:flutter/material.dart';
import 'package:kwt_flutter/pages/class_timetable_page.dart';
import 'package:kwt_flutter/pages/grades_page.dart';
import 'package:kwt_flutter/pages/level_exam_page.dart';
import 'package:kwt_flutter/services/kwt_client.dart';
import 'package:kwt_flutter/services/settings.dart';
import 'package:kwt_flutter/pages/login_page.dart';
import 'package:kwt_flutter/pages/schedule_time_page.dart';

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
                final int crossAxisCount = () {
                  if (constraints.maxWidth >= 720) return 6;
                  if (constraints.maxWidth >= 480) return 5;
                  return 4;
                }();
                const double spacing = 10;
                final double itemWidth = (constraints.maxWidth - spacing * (crossAxisCount - 1)) / crossAxisCount;
                final double itemHeight = itemWidth * 0.9;
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  children: [
                    _tileSized(context, '班级课表', Icons.class_, itemWidth, itemHeight, () => _push(context, ClassTimetablePage(client: client))),
                    _tileSized(context, '课程成绩', Icons.grade, itemWidth, itemHeight, () => _push(context, GradesPage(client: client))),
                    _tileSized(context, '等级考试', Icons.assessment, itemWidth, itemHeight, () => _push(context, LevelExamPage(client: client))),
                    _tileSized(context, '作息时间', Icons.schedule, itemWidth, itemHeight, () => _push(context, const ScheduleTimePage()), requireLogin: false,),
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
  Widget _tileSized(BuildContext context, String label, IconData icon, double w, double h, VoidCallback onTap, {bool requireLogin = true}) {
    return InkWell(
      onTap: () async {
        if (!requireLogin) {
          onTap();
          return;
        }
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
            Icon(
              icon,
              size: (w * 0.45).clamp(18.0, 28.0) as double,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: (w * 0.26).clamp(10.0, 14.0) as double,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
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


