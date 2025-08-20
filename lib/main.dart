// 应用入口与全局路由配置：负责初始化主题、本地化、登录态判断与页面跳转
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kwt_flutter/pages/login_page.dart';
import 'package:kwt_flutter/pages/tab_scaffold.dart';
import 'package:kwt_flutter/services/kwt_client.dart';
import 'package:kwt_flutter/services/config.dart';
import 'package:kwt_flutter/services/settings.dart';
import 'package:kwt_flutter/theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

/// 根组件：提供主题、本地化与路由，按登录态进入首页或登录页
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// 根据已保存的网络环境创建持久化的 [KwtClient]
  Future<KwtClient> _createKwtClientWithNetworkEnvironment() async {
    final settings = SettingsService();
    final serverUrl = await settings.getCurrentServerUrl();
    return KwtClient.createPersisted(baseUrl: serverUrl);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      theme: AppTheme.light(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      home: FutureBuilder<bool>(
        future: SettingsService().isLoggedIn(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          
          final isLoggedIn = snapshot.data ?? false;
          
          if (isLoggedIn) {
            // 已登录，进入主界面
            return FutureBuilder<KwtClient>(
              future: _createKwtClientWithNetworkEnvironment(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }
                return TabScaffold(client: snapshot.data!);
              },
            );
          } else {
            // 未登录，显示登录页面
            return const LoginPage();
          }
        },
      ),
      routes: {
        '/tabs': (ctx) {
          final arg = ModalRoute.of(ctx)!.settings.arguments;
          if (arg is KwtClient) {
            return TabScaffold(client: arg);
          }
          // 如果没有传递client参数，检查登录状态
          return FutureBuilder<bool>(
            future: SettingsService().isLoggedIn(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              
              final isLoggedIn = snapshot.data ?? false;
              
              if (!isLoggedIn) {
                // 未登录，直接返回登录页面
                return const LoginPage();
              }
              
              // 已登录，创建client并进入主界面
              return FutureBuilder<KwtClient>(
                future: _createKwtClientWithNetworkEnvironment(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Scaffold(body: Center(child: CircularProgressIndicator()));
                  }
                  return TabScaffold(client: snapshot.data!);
                },
              );
            },
          );
        },
      },
    );
  }
}
