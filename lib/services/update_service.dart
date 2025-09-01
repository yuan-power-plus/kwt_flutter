import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kwt_flutter/config/app_config.dart';

/// 应用更新信息数据结构
///
/// - [latestVersion]: 语义化版本号，如 1.2.3
/// - [releaseName]: 发布名称，如 v1.2.3
/// - [releaseNotes]: 发布说明正文
/// - [htmlUrl]: 发布页面链接
/// - [androidApkUrl]: APK 直链（若存在）
class UpdateInfo {
  UpdateInfo({
    required this.latestVersion,
    required this.releaseName,
    required this.releaseNotes,
    required this.htmlUrl,
    this.androidApkUrl,
  });

  final String latestVersion; // e.g. 1.2.3
  final String releaseName; // e.g. v1.2.3
  final String releaseNotes; // body
  final String htmlUrl; // release html page
  final String? androidApkUrl; // first apk asset if exists
}

/// 更新服务：负责从 GitHub Releases 获取最新版本信息，并提供版本比较能力
class UpdateService {
  /// 从 GitHub Releases API 获取最新发布版本信息
  ///
  /// 通过 [AppConfig.githubOwner] 与 [AppConfig.githubRepo] 指定仓库来源。
  static Future<UpdateInfo?> fetchLatestRelease() async {
    final owner = AppConfig.githubOwner;
    final repo = AppConfig.githubRepo;
    if (owner.isEmpty || repo.isEmpty) return null;

    final dio = Dio(BaseOptions(
      headers: {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'kwt_flutter',
      },
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));

    try {
      final resp = await dio.get('https://api.github.com/repos/$owner/$repo/releases/latest');
      if (resp.statusCode != 200) return null;
      final data = resp.data is Map<String, dynamic> ? resp.data as Map<String, dynamic> : jsonDecode(resp.data as String) as Map<String, dynamic>;

      final String tag = (data['tag_name'] ?? '').toString();
      final String name = (data['name'] ?? tag).toString();
      final String body = (data['body'] ?? '').toString();
      final String htmlUrl = (data['html_url'] ?? '').toString();
      String? apkUrl;
      if (data['assets'] is List) {
        for (final a in data['assets'] as List) {
          final map = a as Map<String, dynamic>;
          final String url = (map['browser_download_url'] ?? '').toString();
          if (url.toLowerCase().endsWith('.apk')) {
            apkUrl = url;
            break;
          }
        }
      }

      final String normalized = _normalizeTagToVersion(tag.isNotEmpty ? tag : name);
      return UpdateInfo(
        latestVersion: normalized,
        releaseName: name.isNotEmpty ? name : tag,
        releaseNotes: body,
        htmlUrl: htmlUrl.isNotEmpty ? htmlUrl : 'https://github.com/$owner/$repo/releases/latest',
        androidApkUrl: apkUrl,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('fetchLatestRelease error: $e');
      }
      return null;
    }
  }

  /// 比较两个语义化版本号 a 与 b
  ///
  /// 返回值：>0 表示 a>b，0 表示相等，<0 表示 a<b
  static int compareSemver(String a, String b) {
    List<int> pa = _parseSemver(a);
    List<int> pb = _parseSemver(b);
    for (int i = 0; i < 3; i++) {
      if (pa[i] != pb[i]) return pa[i] - pb[i];
    }
    return 0;
  }

  /// 解析语义化版本字符串到 [major, minor, patch]
  static List<int> _parseSemver(String v) {
    final cleaned = _normalizeTagToVersion(v);
    final parts = cleaned.split('.');
    int major = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    int minor = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    int patch = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
    return [major, minor, patch];
  }

  /// 归一化 Git 标签或名称到标准版本号格式
  ///
  /// 支持形式如 'v1.2.3' 或 '1.2.3 (build 10)'
  static String _normalizeTagToVersion(String tagOrName) {
    final m = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(tagOrName);
    if (m != null) {
      return '${m.group(1)}.${m.group(2)}.${m.group(3)}';
    }
    return tagOrName.replaceAll(RegExp(r'[^0-9\.]'), '');
  }
}


