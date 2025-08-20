// 底部 Tab 框架页：承载课表/功能/我的
import 'package:flutter/material.dart';
import 'package:kwt_flutter/pages/features_page.dart';
import 'package:kwt_flutter/pages/profile_page.dart';
import 'package:kwt_flutter/pages/timetable_page.dart';
import 'package:kwt_flutter/services/kwt_client.dart';
import 'package:kwt_flutter/services/settings.dart';

/// Tab 容器页
class TabScaffold extends StatefulWidget {
  const TabScaffold({super.key, required this.client});
  final KwtClient client;

  @override
  State<TabScaffold> createState() => _TabScaffoldState();
}

class _TabScaffoldState extends State<TabScaffold> {
  int _index = 0;
  final SettingsService _settings = SettingsService();

  /// 处理物理返回键：弹出确认对话框，防止误退出
  Future<bool> _onWillPop() async {
    // 显示确认对话框
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('您确定要退出应用吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            child: const Text('退出'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      TimetablePage(client: widget.client),
      FeaturesPage(client: widget.client),
      ProfilePage(client: widget.client),
    ];
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: pages[_index],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.table_chart_outlined), label: '课表'),
            NavigationDestination(icon: Icon(Icons.explore_outlined), label: '功能'),
            NavigationDestination(icon: Icon(Icons.person_outline), label: '我的'),
          ],
          onDestinationSelected: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}


