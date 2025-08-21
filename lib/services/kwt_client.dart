// 后端客户端：封装登录、验证码、课表、成绩、等级考试等接口的请求与解析
import 'dart:convert';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:kwt_flutter/models/models.dart';
import 'package:kwt_flutter/services/config.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// 登录状态失效异常：当后端返回登录页/未登录提示时抛出
class AuthExpiredException implements Exception {
  AuthExpiredException([this.message = '登录已失效']);
  final String message;
  @override
  String toString() => message;
}

/// 科文通后端客户端
///
/// - 维护 Cookie（支持持久化）与基础网络配置
/// - 提供验证码、登录、基础页面解析能力
/// - 提供课表、成绩、等级考试等数据的拉取与解析
class KwtClient {
  KwtClient({
    Dio? dio,
    CookieJar? cookieJar,
    required String baseUrl,
  })  : _cookieJar = cookieJar ?? CookieJar(),
        _baseUrl = baseUrl,
        _dio = dio ?? Dio(BaseOptions(
          baseUrl: baseUrl, 
          followRedirects: true,
          connectTimeout: AppConfig.connectionTimeout,
          receiveTimeout: AppConfig.receiveTimeout,
        )) {
    _dio.interceptors.add(CookieManager(_cookieJar));
    _dio.interceptors.add(_buildUnifiedInterceptor());
  }

  /// 创建带持久化 Cookie 存储的客户端
  static Future<KwtClient> createPersisted({required String baseUrl}) async {
    final dir = await getApplicationSupportDirectory();
    final cookieDir = Directory('${dir.path}/cookies');
    if (!cookieDir.existsSync()) cookieDir.createSync(recursive: true);
    final jar = PersistCookieJar(storage: FileStorage(cookieDir.path));
    final client = KwtClient(cookieJar: jar, baseUrl: baseUrl);
    return client;
  }

  final Dio _dio;
  final CookieJar _cookieJar;
  final String _baseUrl;

  String get baseUrl => _baseUrl;

  static const String defaultTimeMode = AppConfig.defaultTimeMode;

  /// 简单判断返回的 HTML 是否像登录页/未登录提示
  bool _htmlLooksLikeLoginPage(String html) {
    final lc = html.toLowerCase();
    if (html.contains('请先登录系统')) return true; // 精确中文短语
    final hasLoginFields = lc.contains('useraccount') && lc.contains('userpassword');
    final hasCaptcha = lc.contains('/verifycode.servlet') || lc.contains('randomcode');
    if (hasLoginFields) return true;
    if (hasCaptcha && lc.contains('login')) return true;
    return false;
  }

  /// 统一的网络拦截器：
  /// - 记录请求/响应日志（debug 环境）
  /// - 对超时、网络错误进行友好包装
  Interceptor _buildUnifiedInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        if (kDebugMode) {
          debugPrint('[DIO][REQ] ${options.method} ${options.uri}');
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        if (kDebugMode) {
          debugPrint('[DIO][RES] ${response.statusCode} ${response.requestOptions.uri}');
        }
        // 仅在 HTML 内容时检查是否被重定向到登录页
        try {
          final contentType = (response.headers['content-type']?.join(';') ?? '').toLowerCase();
          final looksHtml = contentType.contains('text/html') || contentType.contains('text/plain');
          if (looksHtml) {
            String html = '';
            final data = response.data;
            if (data is List<int>) {
              html = utf8.decode(data, allowMalformed: true);
            } else if (data is Uint8List) {
              html = utf8.decode(data, allowMalformed: true);
            } else if (data is String) {
              html = data;
            }
            if (html.isNotEmpty && _htmlLooksLikeLoginPage(html)) {
              return handler.reject(DioException(
                requestOptions: response.requestOptions,
                error: AuthExpiredException('登录已失效，请重新登录'),
                type: DioExceptionType.badResponse,
                response: response,
              ));
            }
          }
        } catch (_) {}
        handler.next(response);
      },
      onError: (error, handler) {
        if (kDebugMode) {
          debugPrint('[DIO][ERR] ${error.type} ${error.requestOptions.uri}: ${error.message}');
        }
        // 统一错误信息封装，便于 UI 层一致提示
        if (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.sendTimeout) {
          handler.next(DioException(
            requestOptions: error.requestOptions,
            type: error.type,
            error: '请求超时，请稍后重试',
          ));
          return;
        }
        if (error.type == DioExceptionType.unknown) {
          handler.next(DioException(
            requestOptions: error.requestOptions,
            type: error.type,
            error: '网络连接失败，请检查网络设置',
          ));
          return;
        }
        handler.next(error);
      },
    );
  }

  /// 获取登录验证码图片
  Future<Uint8List> fetchCaptcha() async {
    final response = await _dio.get(
      '/verifycode.servlet',
      options: Options(
        responseType: ResponseType.bytes,
        headers: {
          'Referer': '$_baseUrl/',
          'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
        },
      ),
    );
    return Uint8List.fromList((response.data as List<int>));
  }

  /// 从多处页面提取可用学期选项，并按时间倒序返回
  Future<List<String>> fetchTermOptions() async {
    Future<List<String>> parseTermsFromHtml(String html) async {
      final document = html_parser.parse(html);
      final Set<String> termSet = {};
      for (final sel in document.querySelectorAll('select')) {
        final id = sel.id.toLowerCase();
        final name = (sel.attributes['name'] ?? '').toLowerCase();
        if (id.contains('kksj') || name.contains('kksj') || id.contains('xnxq') || name.contains('xnxq')) {
          for (final opt in sel.querySelectorAll('option')) {
            String v = (opt.attributes['value'] ?? '').trim();
            final t = opt.text.trim();
            if (v.isEmpty && t.isNotEmpty) v = t;
            // 只保留形如 YYYY-YYYY-N 的学期，若文本包含则提取
            final m = RegExp(r'(\d{4})-(\d{4})-(\d)').firstMatch(v) ?? RegExp(r'(\d{4})[^\d]+(\d{4})[^\d]+(\d)').firstMatch(v) ?? RegExp(r'(\d{4})-(\d)').firstMatch(v);
            if (m != null) {
              if (m.groupCount == 3) {
                termSet.add('${m.group(1)}-${m.group(2)}-${m.group(3)}');
              } else if (m.groupCount == 2) {
                final y1 = int.tryParse(m.group(1) ?? '0') ?? 0;
                final y2 = (y1 + 1).toString().padLeft(4, '0');
                termSet.add('${m.group(1)}-$y2-${m.group(2)}');
              }
            }
          }
        }
      }
      // 兜底：从整页文本用正则收集所有学期格式
      final allText = document.documentElement?.text ?? '';
      for (final m in RegExp(r'(\d{4})-(\d{4})-(\d)').allMatches(allText)) {
        termSet.add('${m.group(1)}-${m.group(2)}-${m.group(3)}');
      }
      return termSet.toList();
    }

    Future<List<String>> tryGet(String path) async {
      try {
        final res = await _dio.get(
          path,
          options: Options(
            responseType: ResponseType.bytes,
            headers: {
              'Referer': '$_baseUrl/framework/xsMainV.htmlx',
              'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
              'Accept-Language': 'zh-CN,zh;q=0.9',
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Safari/537.36',
            },
          ),
        );
        final bytes = Uint8List.fromList((res.data as List<int>));
        final html = utf8.decode(bytes, allowMalformed: true);
        return await parseTermsFromHtml(html);
      } catch (_) {
        return [];
      }
    }

    // 先尝试从成绩查询页“查询条件”页面提取（更全）
    var terms = await tryGet('/kscj/cjcx_query');
    if (terms.isEmpty) {
      // 次选：成绩列表页（可能不全）
      terms = await tryGet('/kscj/cjcx_list');
    }
    if (terms.isEmpty) {
      // 再尝试班级课表查询页
      terms = await tryGet('/kbcx/kbxx_xzb');
    }
    int termKey(String t) {
      // 形如 2024-2025-2 -> 2024 与 2
      final m = RegExp(r'^(\d{4})-\d{4}-(\d)').firstMatch(t);
      if (m != null) {
        final y = int.tryParse(m.group(1) ?? '0') ?? 0;
        final s = int.tryParse(m.group(2) ?? '0') ?? 0;
        return y * 10 + s;
      }
      return 0;
    }
    terms.sort((a, b) => termKey(b).compareTo(termKey(a))); // 最新在前
    return terms;
  }

  String _b64(String? s) => base64Encode(utf8.encode(s ?? ''));

  /// 登录教务系统，返回是否成功
  Future<bool> login({
    required String userAccount,
    required String userPassword,
    required String verifyCode,
  }) async {
    final encoded = '${_b64(userAccount)}%%%${_b64(userPassword)}';
    final params = {
      'loginMethod': 'LoginToXk',
      'userAccount': userAccount,
      'userPassword': userPassword,
      'RANDOMCODE': verifyCode,
      'encoded': encoded,
    };
    final response = await _dio.post(
      '/xk/LoginToXk',
      queryParameters: params,
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: true,
        headers: {
          'Referer': '$_baseUrl/',
        },
        validateStatus: (code) => true,
      ),
    );
    final bytes = Uint8List.fromList((response.data as List<int>));
    final html = utf8.decode(bytes, allowMalformed: true);
    final failed = RegExp(r'(验证码|密码错误|失败|不存在|错误)', caseSensitive: false).hasMatch(html);
    return !failed;
  }

  /// 拉取主页并尝试解析姓名等基本信息
  Future<Map<String, String>> fetchProfileInfo() async {
    try {
      final res = await _dio.get(
        '/framework/xsMainV.htmlx',
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Referer': '$_baseUrl/'},
          validateStatus: (s) => true,
        ),
      );
      final bytes = Uint8List.fromList((res.data as List<int>));
      final html = utf8.decode(bytes, allowMalformed: true);
      final doc = html_parser.parse(html);
      String name = '';
      // 常见结构：<li class="user"></li><li><span>姓名</span></li>
      final userLi = doc.querySelector('li.user');
      if (userLi != null) {
        final next = userLi.nextElementSibling;
        if (next != null) {
          name = next.querySelector('span')?.text.trim() ?? '';
        }
      }
      // 兜底：尝试搜索含中文姓名样式的 span
      if (name.isEmpty) {
        final candidates = doc.querySelectorAll('span');
        for (final s in candidates) {
          final t = s.text.trim();
          if (RegExp(r'^[\u4e00-\u9fa5]{2,6}$').hasMatch(t)) {
            name = t;
            break;
          }
        }
      }
      return {'name': name};
    } catch (_) {
      return {'name': ''};
    }
  }

  /// 退出登录（后端与本地状态）
  Future<void> logout() async {
    try {
      await _dio.post(
        '/xk/LoginToXk',
        queryParameters: {'method': 'exit'},
        options: Options(
          headers: {'Referer': '$_baseUrl/'},
          validateStatus: (s) => true,
        ),
      );
    } catch (_) {}
  }

  /// 清除本地 Cookie（含持久化存储）
  Future<void> clearCookies() async {
    try {
      await _cookieJar.deleteAll();
    } catch (_) {}
  }

  /// 拉取个人课表（原始二维表形式）
  Future<List<List<String>>> fetchPersonalTimetable({
    required String date, // rq: 例如 2025-09-08
    required String timeMode, // sjmsValue: 例如 2AA072D3F1D747B98B4F5F84683493E5
    required String termId, // xnxqid: 例如 2024-2025-2
    bool showWeekend = false,
  }) async {
    final response = await _dio.get(
      '/framework/mainV_index_loadkb.htmlx',
      queryParameters: {
        'rq': date,
        'sjmsValue': timeMode,
        'xnxqid': termId,
        'xswk': showWeekend.toString(),
      },
      options: Options(
        responseType: ResponseType.bytes,
        headers: {
          'Referer': '$_baseUrl/',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      ),
    );
    final bytes = Uint8List.fromList((response.data as List<int>));
    final html = utf8.decode(bytes, allowMalformed: true);
    return _extractTableRows(html);
  }

  /// 拉取个人课表（结构化实体）
  Future<List<TimetableEntry>> fetchPersonalTimetableStructured({
    required String date,
    required String timeMode,
    required String termId,
    bool showWeekend = false,
  }) async {
    final response = await _dio.get(
      '/framework/mainV_index_loadkb.htmlx',
      queryParameters: {
        'rq': date,
        'sjmsValue': timeMode,
        'xnxqid': termId,
        'xswk': showWeekend.toString(),
      },
      options: Options(
        responseType: ResponseType.bytes,
        headers: {
          'Referer': '$_baseUrl/',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      ),
    );
    final bytes = Uint8List.fromList((response.data as List<int>));
    final html = utf8.decode(bytes, allowMalformed: true);
    if (_htmlLooksLikeLoginPage(html)) {
      throw AuthExpiredException('登录已失效，请重新登录');
    }
    return parsePersonalTimetableStructured(html);
  }

  /// 拉取课程成绩（原始二维表形式）
  Future<List<List<String>>> fetchGrades({
    required String term, // kksj: 例如 2024-2025-2
    String courseProperty = '', // kcxz
    String courseAttr = '', // kcsx
    String courseName = '', // kcmc
    String display = 'all', // xsfs
    String mold = '',
  }) async {
    final form = FormData.fromMap({
      'kksj': term,
      'kcxz': courseProperty,
      'kcsx': courseAttr,
      'kcmc': courseName,
      'xsfs': display,
      'mold': mold,
    });
    final response = await _dio.post(
      '/kscj/cjcx_list',
      data: form,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {
          'Referer': '$_baseUrl/',
          'Content-Type': 'multipart/form-data',
        },
      ),
    );
    final bytes = Uint8List.fromList((response.data as List<int>));
    final html = utf8.decode(bytes, allowMalformed: true);
    return _extractTableRows(html);
  }

  /// 拉取课程成绩（结构化实体）
  Future<List<GradeEntry>> fetchGradesStructured({
    required String term,
    String courseProperty = '',
    String courseAttr = '',
    String courseName = '',
    String display = 'all',
    String mold = '',
  }) async {
    final form = FormData.fromMap({
      'kksj': term,
      'kcxz': courseProperty,
      'kcsx': courseAttr,
      'kcmc': courseName,
      'xsfs': display,
      'mold': mold,
    });
    final response = await _dio.post(
      '/kscj/cjcx_list',
      data: form,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {
          'Referer': '$_baseUrl/',
          'Content-Type': 'multipart/form-data',
        },
      ),
    );
    final bytes = Uint8List.fromList((response.data as List<int>));
    final html = utf8.decode(bytes, allowMalformed: true);
    if (_htmlLooksLikeLoginPage(html)) {
      throw AuthExpiredException('登录已失效，请重新登录');
    }
    return _parseGrades(html);
  }

  /// 拉取等级考试成绩（结构化实体）
  Future<List<ExamLevelEntry>> fetchExamLevel() async {
    final response = await _dio.get(
      '/kscj/djkscj_list',
      options: Options(
        responseType: ResponseType.bytes,
        headers: {
          'Referer': '$_baseUrl/',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      ),
    );
    final bytes = Uint8List.fromList((response.data as List<int>));
    final html = utf8.decode(bytes, allowMalformed: true);
    if (_htmlLooksLikeLoginPage(html)) {
      throw AuthExpiredException('登录已失效，请重新登录');
    }
    return parseExamLevel(html);
  }

  List<List<String>> _extractTableRows(String html) {
    final document = html_parser.parse(html);
    final rows = <List<String>>[];
    // 简易提取第一个表格所有行的文本单元格
    final tables = document.querySelectorAll('table');
    if (tables.isEmpty) return rows;
    final table = tables.first;
    for (final tr in table.querySelectorAll('tr')) {
      final cells = tr.querySelectorAll('th,td').map((e) => e.text.trim()).where((t) => t.isNotEmpty).toList();
      if (cells.isNotEmpty) rows.add(cells);
    }
    return rows;
  }

  List<GradeEntry> _parseGrades(String html) {
    final document = html_parser.parse(html);
    // 成绩页常见结构：table#dataList -> thead 定义列，tbody 为数据
    final table = document.querySelector('#dataList') ?? document.querySelector('table');
    if (table == null) return [];
    final rows = table.querySelectorAll('tr');
    final entries = <GradeEntry>[];
    // 尝试解析表头，映射列名到下标
    final headerCells = rows.isNotEmpty ? rows.first.querySelectorAll('th,td') : <dom.Element>[];
    final headers = headerCells.map((e) => e.text.trim()).toList();
    int idx(String name, List<String> alt) {
      final all = [name, ...alt];
      for (final n in all) {
        final j = headers.indexWhere((h) => h.contains(n));
        if (j >= 0) return j;
      }
      return -1;
    }
    final iTerm = idx('学期', ['开课学期', '开课时间']);
    final iCode = idx('课程编号', ['课程代码', '课程代号']);
    final iName = idx('课程名称', ['课程名']);
    final iScore = idx('成绩', ['总评']);
    final iCredit = idx('学分', []);
    final iHours = idx('总学时', ['学时']);
    final iGpa = idx('绩点', []);
    final iExamType = idx('考试性质', ['考试类型']);
    final iCourseAttr = idx('课程属性', ['属性']);
    final iCourseNature = idx('课程性质', ['性质']);

    for (int r = 1; r < rows.length; r++) {
      final cells = rows[r].querySelectorAll('th,td');
      if (cells.length < 3) continue;
      String at(int i) => i >= 0 && i < cells.length ? cells[i].text.trim() : '';
      entries.add(GradeEntry(
        term: at(iTerm),
        courseCode: at(iCode),
        courseName: at(iName),
        score: at(iScore),
        scoreFlag: '',
        credit: at(iCredit),
        totalHours: at(iHours),
        gpa: at(iGpa),
        examType: at(iExamType),
        examNature: '',
        courseAttr: at(iCourseAttr),
        courseNature: at(iCourseNature),
        generalType: '',
      ));
    }
    return entries;
  }

  List<TimetableEntry> parsePersonalTimetableStructured(String html) {
    final document = html_parser.parse(html);
    final tbody = document.querySelector('table tbody');
    if (tbody == null) return [];
    final result = <TimetableEntry>[];
    final rows = tbody.querySelectorAll('tr');
    for (final row in rows) {
      final tds = row.querySelectorAll('td');
      if (tds.isEmpty) continue;
      final firstText = tds.first.text.trim();
      // 仅提取“第N大节”的行，忽略“中午/下午课后/备注”
      int sectionIndex = 0;
      if (firstText.contains('大节')) {
        if (firstText.contains('第一')) sectionIndex = 1;
        if (firstText.contains('第二')) sectionIndex = 2;
        if (firstText.contains('第三')) sectionIndex = 3;
        if (firstText.contains('第四')) sectionIndex = 4;
        if (firstText.contains('第五')) sectionIndex = 5;
      } else {
        continue;
      }
      for (int i = 1; i < tds.length && i <= 7; i++) {
        final td = tds[i];
        final boxes = td.querySelectorAll('span.box');
        for (final box in boxes) {
          final detail = box.nextElementSibling;
          String courseName = '';
          String teacher = '';
          String credits = '';
          String location = '';
          String sectionText = '';
          String weekText = '';
          final ps = box.querySelectorAll('p');
          if (ps.isNotEmpty) courseName = ps.first.text.trim();
          if (ps.length > 1) teacher = ps[1].text.replaceAll('教师：', '').trim();
          final hint = box.querySelector('span.text')?.text.trim() ?? '';
          if (hint.contains('小节')) {
            final parts = hint.split(' ');
            if (parts.isNotEmpty) sectionText = parts[0];
            if (parts.length > 1) weekText = parts[1];
          }
          if (detail != null) {
            final pTitle = detail.querySelector('p');
            if (pTitle != null && pTitle.text.trim().isNotEmpty) {
              courseName = pTitle.text.trim();
            }
            final spans = detail.querySelectorAll('div.tch-name span');
            if (spans.isNotEmpty) {
              credits = spans.first.text.replaceAll('学分：', '').trim();
            }
            final infoSpans = detail.querySelectorAll('div span');
            for (final s in infoSpans) {
              final t = s.text.trim();
              if (t.contains('潘安湖') || t.contains('楼')) {
                location = t;
              }
              if (t.contains('星期')) {
                weekText = t;
              }
            }
          }
          result.add(TimetableEntry(
            courseName: courseName,
            teacher: teacher,
            credits: credits,
            location: location,
            sectionText: sectionText,
            weekText: weekText,
            dayOfWeek: i,
            sectionIndex: sectionIndex,
          ));
        }
      }
    }
    return result;
  }

  List<ExamLevelEntry> parseExamLevel(String html) {
    final document = html_parser.parse(html);
    final table = document.querySelector('#dataList');
    if (table == null) return [];
    final rows = table.querySelectorAll('tr');
    final result = <ExamLevelEntry>[];
    for (int i = 2; i < rows.length; i++) {
      final cells = rows[i].querySelectorAll('td');
      if (cells.length < 11) continue;
      String txt(dom.Element e) => e.text.trim();
      result.add(ExamLevelEntry(
        course: txt(cells[1]),
        writtenScore: txt(cells[2]),
        labScore: txt(cells[3]),
        totalScore: txt(cells[4]),
        writtenLevel: txt(cells[6]),
        labLevel: txt(cells[7]),
        totalLevel: txt(cells[8]),
        startDate: txt(cells[9]),
        endDate: txt(cells[10]),
      ));
    }
    return result;
  }

  Future<List<TimetableEntry>> fetchClassTimetableStructured({
    required String term, // xnxqh
    required String timeMode, // kbjcmsid
    String department = '', // skyx
    String grade = '', // sknj
    String major = '', // skzy
    String classId = '', // skbjid
    String className = '', // skbj
    String weekStart = '', // zc1
    String weekEnd = '', // zc2
    String weekdayStart = '', // skxq1 (1-7)
    String weekdayEnd = '', // skxq2
    String sectionStart = '', // jc1
    String sectionEnd = '', // jc2
  }) async {
    final form = FormData.fromMap({
      'xnxqh': term,
      'kbjcmsid': timeMode,
      'skyx': department,
      'sknj': grade,
      'skzy': major,
      'skbjid': classId,
      'skbj': className,
      'zc1': weekStart,
      'zc2': weekEnd,
      'skxq1': weekdayStart,
      'skxq2': weekdayEnd,
      'jc1': sectionStart,
      'jc2': sectionEnd,
    });
    final response = await _dio.post(
      '/kbcx/kbxx_xzb_ifr',
      data: form,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {
          'Referer': '$_baseUrl/',
          'Content-Type': 'multipart/form-data',
        },
      ),
    );
    final bytes = Uint8List.fromList((response.data as List<int>));
    final html = utf8.decode(bytes, allowMalformed: true);
    return parseClassTimetableStructured(html);
  }

  List<TimetableEntry> parseClassTimetableStructured(String html) {
    // 班级课表：表格 id="timetable"，每个单元格含多个 div.kbcontent1
    // 表头第1行：星期一..星期日（每个 colspan=7）
    // 表头第2行：每个星期下有 7 个节次列（如 0102、030405、0607、0809、101112、13、14）
    final document = html_parser.parse(html);
    final table = document.querySelector('#timetable');
    if (table == null) return [];

    // 解析第二行表头，提取每个星期下的7个节次标签（仅取星期一的 7 个即可，后续按重复使用）
    final List<String> slotLabels = [];
    try {
      final thead = table.querySelector('thead');
      final headerRows = thead?.querySelectorAll('tr') ?? const [];
      if (headerRows.length >= 2) {
        final tdCells = headerRows[1].querySelectorAll('td');
        if (tdCells.length >= 8) {
          for (int k = 1; k <= 7 && k < tdCells.length; k++) {
            slotLabels.add(tdCells[k].text.trim());
          }
        }
      }
    } catch (_) {}

    String _sectionTextFromLabel(String raw) {
      final s = raw.replaceAll(RegExp(r"\s+"), '');
      if (s.isEmpty) return '';
      // 形如 0102 -> 第01-02节
      if (RegExp(r'^\d{4} ? ?$').hasMatch(s) || s.length == 4 && RegExp(r'^\d{4} ?$').hasMatch(s)) {}
      if (RegExp(r'^\d{4} ?$').hasMatch(s)) {}
      if (RegExp(r'^\d{4} ?$').hasMatch(s)) {}
      if (RegExp(r'^\d{4}$').hasMatch(s)) {
        final a = s.substring(0, 2);
        final b = s.substring(2, 4);
        return '第${a}-${b}节';
      }
      // 形如 030405/101112 -> 第03-05节
      if (RegExp(r'^\d{6}$').hasMatch(s)) {
        final a = s.substring(0, 2);
        final b = s.substring(4, 6);
        return '第${a}-${b}节';
      }
      // 形如 13/14 -> 第13节
      if (RegExp(r'^\d{1,2}$').hasMatch(s)) {
        return '第${s.padLeft(2, '0')}节';
      }
      // 已经为“第..节/..节”格式时原样返回
      return s;
    }

    final result = <TimetableEntry>[];
    final allRows = table.querySelectorAll('tr');
    // 跳过前两行表头
    for (int r = 2; r < allRows.length; r++) {
      final tds = allRows[r].querySelectorAll('td');
      if (tds.isEmpty) continue;
      for (int i = 1; i < tds.length; i++) {
        final td = tds[i];
        final blocks = td.querySelectorAll('div.kbcontent1');
        if (blocks.isEmpty) continue;
        // 列布局修正：每 7 列为一组（星期），组内 7 列为节次
        final int dayOfWeek = ((i - 1) ~/ 7) + 1; // 1..7 -> 星期一..星期日
        final int slotIndex = ((i - 1) % 7) + 1;  // 1..7 -> 当天第几个节次列
        final int sectionIndex = slotIndex <= 5 ? slotIndex : 5; // 13/14 合并为第5大节
        final String slotLabel = (slotLabels.length == 7) ? slotLabels[slotIndex - 1] : '';

        for (final div in blocks) {
          // 更稳健地按 <br> 拆分：避免课程名后跟上班级
          final lines = <String>[];
          final sb = StringBuffer();
          for (final node in div.nodes) {
            if (node.nodeType == dom.Node.TEXT_NODE) {
              sb.write(node.text);
            } else if (node is dom.Element && node.localName == 'br') {
              final txt = sb.toString().trim();
              if (txt.isNotEmpty) lines.add(txt);
              sb.clear();
            }
          }
          final tail = sb.toString().trim();
          if (tail.isNotEmpty) lines.add(tail);
          String courseName = '';
          String teacher = '';
          String credits = '';
          String location = '';
          String sectionText = '';
          String weekText = '';
          if (lines.isNotEmpty) courseName = lines[0];
          for (final line in lines) {
            if (line.contains('周')) {
              weekText = line;
              break;
            }
          }
          if (lines.length >= 4 && (lines[1].startsWith('(') || lines[1].startsWith('（'))) {
            teacher = lines[3].replaceAll(RegExp(r'^教师[:：]?'), '').trim();
          } else if (lines.length >= 3) {
            teacher = lines[2].replaceAll(RegExp(r'^教师[:：]?'), '').trim();
          }
          if (lines.isNotEmpty) {
            location = lines.last;
          }
          // 从信息行中提取节次（如“01~02节”），若没有则按列的节次标签推断
          for (final line in lines) {
            final m = RegExp(r'(\d{1,2})\s*[-~至]\s*(\d{1,2})\s*节').firstMatch(line);
            if (m != null) {
              sectionText = '${m.group(1)!.padLeft(2, '0')}~${m.group(2)!.padLeft(2, '0')}节';
              break;
            }
          }
          if (sectionText.isEmpty) {
            sectionText = _sectionTextFromLabel(slotLabel);
          }
          result.add(TimetableEntry(
            courseName: courseName,
            teacher: teacher,
            credits: credits,
            location: location,
            sectionText: sectionText,
            weekText: weekText,
            dayOfWeek: dayOfWeek,
            sectionIndex: sectionIndex,
          ));
        }
      }
    }
    return result;
  }

  Future<List<Map<String, String>>> searchClasses({
    required String keyword,
    int maxRow = 10,
  }) async {
    // Autocomplete 服务：/kbcx/querySkbj，paramName=skbj
    final response = await _dio.post(
      '/kbcx/querySkbj',
      data: FormData.fromMap({'skbj': keyword, 'maxRow': maxRow.toString()}),
      options: Options(
        headers: {
          'Referer': '$_baseUrl/',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        responseType: ResponseType.json,
        validateStatus: (s) => true,
      ),
    );
    final data = response.data;
    if (data is Map && data['list'] is List) {
      final List list = data['list'];
      return list.map<Map<String, String>>((e) => {
            'id': (e['xx04id'] ?? '').toString(),
            'name': (e['bj'] ?? '').toString(),
          }).toList();
    }
    return [];
  }
}


