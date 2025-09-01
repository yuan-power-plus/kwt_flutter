import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

/// 缓存项
class CacheItem<T> {
  const CacheItem({
    required this.data,
    required this.timestamp,
    this.expiration,
  });

  final T data;
  final DateTime timestamp;
  final Duration? expiration;

  /// 是否已过期
  bool get isExpired {
    if (expiration == null) return false;
    return DateTime.now().difference(timestamp) > expiration!;
  }

  /// 剩余时间
  Duration get remainingTime {
    if (expiration == null) return Duration.zero;
    final elapsed = DateTime.now().difference(timestamp);
    return expiration! - elapsed;
  }

  Map<String, dynamic> toJson() => {
    'data': data,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'expiration': expiration?.inMilliseconds,
  };

  factory CacheItem.fromJson(Map<String, dynamic> json) {
    return CacheItem<T>(
      data: json['data'] as T,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      expiration: json['expiration'] != null 
        ? Duration(milliseconds: json['expiration'])
        : null,
    );
  }
}

/// 缓存策略
enum CacheStrategy {
  /// 仅内存缓存
  memoryOnly,
  /// 仅磁盘缓存
  diskOnly,
  /// 内存+磁盘缓存
  memoryAndDisk,
}

/// 缓存管理服务
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  // 内存缓存
  final Map<String, CacheItem> _memoryCache = {};
  
  // 磁盘缓存目录
  Directory? _cacheDir;
  
  // 最大内存缓存大小
  static const int maxMemoryCacheSize = 100;
  
  /// 初始化缓存服务
  Future<void> initialize() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      _cacheDir = Directory('${appDir.path}/cache');
      if (!_cacheDir!.existsSync()) {
        await _cacheDir!.create(recursive: true);
      }
    } catch (e) {
      debugPrint('Failed to initialize cache directory: $e');
    }
  }

  /// 设置缓存
  Future<void> set<T>(
    String key,
    T data, {
    Duration? expiration,
    CacheStrategy strategy = CacheStrategy.memoryAndDisk,
  }) async {
    final item = CacheItem<T>(
      data: data,
      timestamp: DateTime.now(),
      expiration: expiration,
    );

    // 内存缓存
    if (strategy == CacheStrategy.memoryOnly || strategy == CacheStrategy.memoryAndDisk) {
      _setMemoryCache(key, item);
    }

    // 磁盘缓存
    if (strategy == CacheStrategy.diskOnly || strategy == CacheStrategy.memoryAndDisk) {
      await _setDiskCache(key, item);
    }
  }

  /// 获取缓存
  Future<T?> get<T>(String key, {CacheStrategy strategy = CacheStrategy.memoryAndDisk}) async {
    CacheItem<T>? item;

    // 先从内存获取
    if (strategy == CacheStrategy.memoryOnly || strategy == CacheStrategy.memoryAndDisk) {
      item = _getMemoryCache<T>(key);
      if (item != null && !item.isExpired) {
        return item.data;
      }
    }

    // 再从磁盘获取
    if (strategy == CacheStrategy.diskOnly || strategy == CacheStrategy.memoryAndDisk) {
      item = await _getDiskCache<T>(key);
      if (item != null && !item.isExpired) {
        // 同步到内存缓存
        if (strategy == CacheStrategy.memoryAndDisk) {
          _setMemoryCache(key, item);
        }
        return item.data;
      }
    }

    return null;
  }

  /// 删除缓存
  Future<void> remove(String key, {CacheStrategy strategy = CacheStrategy.memoryAndDisk}) async {
    // 删除内存缓存
    if (strategy == CacheStrategy.memoryOnly || strategy == CacheStrategy.memoryAndDisk) {
      _memoryCache.remove(key);
    }

    // 删除磁盘缓存
    if (strategy == CacheStrategy.diskOnly || strategy == CacheStrategy.memoryAndDisk) {
      await _removeDiskCache(key);
    }
  }

  /// 清除所有缓存
  Future<void> clear({CacheStrategy strategy = CacheStrategy.memoryAndDisk}) async {
    // 清除内存缓存
    if (strategy == CacheStrategy.memoryOnly || strategy == CacheStrategy.memoryAndDisk) {
      _memoryCache.clear();
    }

    // 清除磁盘缓存
    if (strategy == CacheStrategy.diskOnly || strategy == CacheStrategy.memoryAndDisk) {
      await _clearDiskCache();
    }
  }

  /// 清除过期缓存
  Future<void> clearExpired() async {
    // 清除过期的内存缓存
    _memoryCache.removeWhere((key, item) => item.isExpired);

    // 清除过期的磁盘缓存
    if (_cacheDir != null && _cacheDir!.existsSync()) {
      final files = _cacheDir!.listSync();
      for (final file in files) {
        if (file is File) {
          try {
            final content = await file.readAsString();
            final json = jsonDecode(content) as Map<String, dynamic>;
            final item = CacheItem.fromJson(json);
            if (item.isExpired) {
              await file.delete();
            }
          } catch (e) {
            // 删除无法解析的文件
            await file.delete();
          }
        }
      }
    }
  }

  /// 获取缓存信息
  Map<String, dynamic> getCacheInfo() {
    final memorySize = _memoryCache.length;
    final diskSize = _cacheDir?.listSync().length ?? 0;
    
    return {
      'memorySize': memorySize,
      'diskSize': diskSize,
      'maxMemorySize': maxMemoryCacheSize,
    };
  }

  /// 设置内存缓存
  void _setMemoryCache<T>(String key, CacheItem<T> item) {
    // 检查缓存大小，如果超过限制则删除最旧的
    if (_memoryCache.length >= maxMemoryCacheSize) {
      final oldestKey = _memoryCache.entries
          .reduce((a, b) => a.value.timestamp.isBefore(b.value.timestamp) ? a : b)
          .key;
      _memoryCache.remove(oldestKey);
    }
    
    _memoryCache[key] = item;
  }

  /// 获取内存缓存
  CacheItem<T>? _getMemoryCache<T>(String key) {
    final item = _memoryCache[key];
    if (item != null && item.data is T) {
      return item as CacheItem<T>;
    }
    return null;
  }

  /// 设置磁盘缓存
  Future<void> _setDiskCache<T>(String key, CacheItem<T> item) async {
    if (_cacheDir == null) return;
    
    try {
      final file = File('${_cacheDir!.path}/${_sanitizeKey(key)}.json');
      final json = jsonEncode(item.toJson());
      await file.writeAsString(json);
    } catch (e) {
      debugPrint('Failed to write disk cache: $e');
    }
  }

  /// 获取磁盘缓存
  Future<CacheItem<T>?> _getDiskCache<T>(String key) async {
    if (_cacheDir == null) return null;
    
    try {
      final file = File('${_cacheDir!.path}/${_sanitizeKey(key)}.json');
      if (!file.existsSync()) return null;
      
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return CacheItem<T>.fromJson(json);
    } catch (e) {
      debugPrint('Failed to read disk cache: $e');
      return null;
    }
  }

  /// 删除磁盘缓存
  Future<void> _removeDiskCache(String key) async {
    if (_cacheDir == null) return;
    
    try {
      final file = File('${_cacheDir!.path}/${_sanitizeKey(key)}.json');
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Failed to remove disk cache: $e');
    }
  }

  /// 清除磁盘缓存
  Future<void> _clearDiskCache() async {
    if (_cacheDir == null) return;
    
    try {
      if (_cacheDir!.existsSync()) {
        await _cacheDir!.delete(recursive: true);
        await _cacheDir!.create(recursive: true);
      }
    } catch (e) {
      debugPrint('Failed to clear disk cache: $e');
    }
  }

  /// 清理缓存键名，移除不安全字符
  String _sanitizeKey(String key) {
    return key.replaceAll(RegExp(r'[^\w\-_.]'), '_');
  }
}

/// 缓存扩展方法
extension CacheExtensions on CacheService {
  /// 获取或设置缓存（如果不存在则通过 factory 创建）
  Future<T> getOrSet<T>(
    String key,
    Future<T> Function() factory, {
    Duration? expiration,
    CacheStrategy strategy = CacheStrategy.memoryAndDisk,
  }) async {
    // 先尝试获取缓存
    final cached = await get<T>(key, strategy: strategy);
    if (cached != null) {
      return cached;
    }

    // 缓存不存在，创建新数据
    final data = await factory();
    
    // 设置缓存
    await set(key, data, expiration: expiration, strategy: strategy);
    
    return data;
  }
}