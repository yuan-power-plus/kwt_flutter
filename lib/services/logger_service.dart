import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';

/// 日志级别
enum LogLevel {
  debug,
  info,
  warning,
  error,
  fatal,
}

/// 日志条目
class LogEntry {
  const LogEntry({
    required this.level,
    required this.message,
    required this.timestamp,
    this.tag,
    this.error,
    this.stackTrace,
    this.data,
  });

  final LogLevel level;
  final String message;
  final DateTime timestamp;
  final String? tag;
  final Object? error;
  final StackTrace? stackTrace;
  final Map<String, dynamic>? data;

  Map<String, dynamic> toJson() => {
    'level': level.name,
    'message': message,
    'timestamp': timestamp.toIso8601String(),
    'tag': tag,
    'error': error?.toString(),
    'stackTrace': stackTrace?.toString(),
    'data': data,
  };

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      level: LogLevel.values.firstWhere((e) => e.name == json['level']),
      message: json['message'],
      timestamp: DateTime.parse(json['timestamp']),
      tag: json['tag'],
      error: json['error'],
      stackTrace: json['stackTrace'] != null ? StackTrace.fromString(json['stackTrace']) : null,
      data: json['data'] != null ? Map<String, dynamic>.from(json['data']) : null,
    );
  }
}

/// 日志输出接口
abstract class LogOutput {
  void output(LogEntry entry);
}

/// 控制台日志输出
class ConsoleLogOutput implements LogOutput {
  @override
  void output(LogEntry entry) {
    if (!kDebugMode) return;
    
    final levelEmoji = _getLevelEmoji(entry.level);
    final timestamp = entry.timestamp.toString().substring(11, 23);
    final tag = entry.tag != null ? '[${entry.tag}] ' : '';
    
    debugPrint('$levelEmoji $timestamp $tag${entry.message}');
    
    if (entry.error != null) {
      debugPrint('  Error: ${entry.error}');
    }
    
    if (entry.stackTrace != null && entry.level == LogLevel.error) {
      debugPrint('  StackTrace: ${entry.stackTrace}');
    }
    
    if (entry.data != null) {
      debugPrint('  Data: ${jsonEncode(entry.data)}');
    }
  }
  
  String _getLevelEmoji(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '🐛';
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
      case LogLevel.fatal:
        return '💀';
    }
  }
}

/// 文件日志输出
class FileLogOutput implements LogOutput {
  FileLogOutput({this.maxFileSize = 10 * 1024 * 1024}); // 10MB
  
  final int maxFileSize;
  File? _logFile;
  
  Future<void> initialize() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final logDir = Directory('${dir.path}/logs');
      if (!logDir.existsSync()) {
        await logDir.create(recursive: true);
      }
      
      _logFile = File('${logDir.path}/app.log');
      
      // 检查文件大小，如果过大则轮转
      if (_logFile!.existsSync() && await _logFile!.length() > maxFileSize) {
        await _rotateLogFile();
      }
    } catch (e) {
      debugPrint('Failed to initialize file log output: $e');
    }
  }
  
  @override
  void output(LogEntry entry) {
    if (_logFile == null) return;
    
    _writeToFile(entry);
  }
  
  Future<void> _writeToFile(LogEntry entry) async {
    try {
      final line = '${jsonEncode(entry.toJson())}\n';
      await _logFile!.writeAsString(line, mode: FileMode.append);
    } catch (e) {
      debugPrint('Failed to write log to file: $e');
    }
  }
  
  Future<void> _rotateLogFile() async {
    try {
      if (_logFile == null || !_logFile!.existsSync()) return;
      
      final backupFile = File('${_logFile!.path}.old');
      if (backupFile.existsSync()) {
        await backupFile.delete();
      }
      
      await _logFile!.rename(backupFile.path);
      _logFile = File(_logFile!.path);
    } catch (e) {
      debugPrint('Failed to rotate log file: $e');
    }
  }
}

/// 日志服务
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  final List<LogOutput> _outputs = [];
  LogLevel _minLevel = LogLevel.debug;
  
  /// 初始化日志服务
  Future<void> initialize() async {
    // 添加控制台输出
    _outputs.add(ConsoleLogOutput());
    
    // 在生产环境或启用日志时添加文件输出
    if (AppConfig.enableLogging || kReleaseMode) {
      final fileOutput = FileLogOutput();
      await fileOutput.initialize();
      _outputs.add(fileOutput);
    }
    
    // 设置最小日志级别
    _minLevel = AppConfig.isDebug ? LogLevel.debug : LogLevel.info;
  }
  
  /// 添加日志输出
  void addOutput(LogOutput output) {
    _outputs.add(output);
  }
  
  /// 移除日志输出
  void removeOutput(LogOutput output) {
    _outputs.remove(output);
  }
  
  /// 设置最小日志级别
  void setMinLevel(LogLevel level) {
    _minLevel = level;
  }
  
  /// 记录日志
  void log(
    LogLevel level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {
    if (level.index < _minLevel.index) return;
    
    final entry = LogEntry(
      level: level,
      message: message,
      timestamp: DateTime.now(),
      tag: tag,
      error: error,
      stackTrace: stackTrace,
      data: data,
    );
    
    for (final output in _outputs) {
      try {
        output.output(entry);
      } catch (e) {
        debugPrint('Failed to output log: $e');
      }
    }
  }
  
  /// Debug 日志
  void debug(String message, {String? tag, Map<String, dynamic>? data}) {
    log(LogLevel.debug, message, tag: tag, data: data);
  }
  
  /// Info 日志
  void info(String message, {String? tag, Map<String, dynamic>? data}) {
    log(LogLevel.info, message, tag: tag, data: data);
  }
  
  /// Warning 日志
  void warning(String message, {String? tag, Map<String, dynamic>? data}) {
    log(LogLevel.warning, message, tag: tag, data: data);
  }
  
  /// Error 日志
  void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {
    log(
      LogLevel.error,
      message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
      data: data,
    );
  }
  
  /// Fatal 日志
  void fatal(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {
    log(
      LogLevel.fatal,
      message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
      data: data,
    );
  }
  
  /// 记录网络请求
  void logRequest(String method, String url, {Map<String, dynamic>? data}) {
    debug(
      '$method $url',
      tag: 'HTTP',
      data: data,
    );
  }
  
  /// 记录网络响应
  void logResponse(int statusCode, String url, {Map<String, dynamic>? data}) {
    debug(
      '$statusCode $url',
      tag: 'HTTP',
      data: data,
    );
  }
  
  /// 记录用户操作
  void logUserAction(String action, {Map<String, dynamic>? data}) {
    info(
      'User action: $action',
      tag: 'USER',
      data: data,
    );
  }
  
  /// 记录性能指标
  void logPerformance(String operation, Duration duration, {Map<String, dynamic>? data}) {
    info(
      'Performance: $operation took ${duration.inMilliseconds}ms',
      tag: 'PERF',
      data: data,
    );
  }
}

/// 日志扩展方法
extension LoggerExtensions on LoggerService {
  /// 包装异步操作并记录性能
  Future<T> withPerformanceLogging<T>(
    String operation,
    Future<T> Function() function, {
    String? tag,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await function();
      stopwatch.stop();
      logPerformance(operation, stopwatch.elapsed);
      return result;
    } catch (error, stackTrace) {
      stopwatch.stop();
      this.error(
        'Failed: $operation',
        tag: tag,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}