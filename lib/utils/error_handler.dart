import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/kwt_client.dart';

/// 应用错误类型
enum AppErrorType {
  /// 网络连接错误
  network,
  /// 认证错误（登录失效等）
  authentication,
  /// 服务器错误
  server,
  /// 数据解析错误
  parsing,
  /// 验证错误（表单验证等）
  validation,
  /// 权限错误
  permission,
  /// 未知错误
  unknown,
}

/// 应用错误信息
class AppError {
  const AppError({
    required this.type,
    required this.message,
    this.details,
    this.code,
  });

  final AppErrorType type;
  final String message;
  final String? details;
  final String? code;

  /// 从异常创建应用错误
  factory AppError.fromException(Object error) {
    if (error is AuthExpiredException) {
      return AppError(
        type: AppErrorType.authentication,
        message: error.message,
      );
    }
    
    if (error is DioException) {
      return AppError.fromDioException(error);
    }
    
    return AppError(
      type: AppErrorType.unknown,
      message: error.toString(),
    );
  }
  
  /// 从 Dio 异常创建应用错误
  factory AppError.fromDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AppError(
          type: AppErrorType.network,
          message: '请求超时，请稍后重试',
          details: error.message,
        );
        
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        return AppError(
          type: AppErrorType.server,
          message: _getServerErrorMessage(statusCode),
          code: statusCode?.toString(),
          details: error.message,
        );
        
      case DioExceptionType.cancel:
        return AppError(
          type: AppErrorType.unknown,
          message: '请求已取消',
          details: error.message,
        );
        
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
      default:
        return AppError(
          type: AppErrorType.network,
          message: '网络连接失败，请检查网络设置',
          details: error.message,
        );
    }
  }
  
  /// 获取服务器错误信息
  static String _getServerErrorMessage(int? statusCode) {
    switch (statusCode) {
      case 400:
        return '请求参数错误';
      case 401:
        return '未授权访问';
      case 403:
        return '访问被拒绝';
      case 404:
        return '资源不存在';
      case 500:
        return '服务器内部错误';
      case 502:
        return '网关错误';
      case 503:
        return '服务不可用';
      default:
        return '服务器响应异常';
    }
  }
  
  @override
  String toString() {
    return 'AppError(type: $type, message: $message, code: $code)';
  }
}

class ErrorHandler {
  /// 显示错误提示
  static void showError(BuildContext context, String message, {Duration? duration}) {
    _showSnackBar(
      context,
      message,
      icon: Icons.error_outline,
      backgroundColor: Colors.red[600]!,
      duration: duration,
    );
  }

  /// 显示应用错误
  static void showAppError(BuildContext context, AppError error, {Duration? duration}) {
    showError(context, error.message, duration: duration);
  }

  /// 显示成功提示
  static void showSuccess(BuildContext context, String message, {Duration? duration}) {
    _showSnackBar(
      context,
      message,
      icon: Icons.check_circle_outline,
      backgroundColor: Colors.green[600]!,
      duration: duration,
    );
  }

  /// 显示信息提示
  static void showInfo(BuildContext context, String message, {Duration? duration}) {
    _showSnackBar(
      context,
      message,
      icon: Icons.info_outline,
      backgroundColor: Colors.blue[600]!,
      duration: duration,
    );
  }
  
  /// 显示警告提示
  static void showWarning(BuildContext context, String message, {Duration? duration}) {
    _showSnackBar(
      context,
      message,
      icon: Icons.warning_outlined,
      backgroundColor: Colors.orange[600]!,
      duration: duration,
    );
  }
  
  /// 显示 SnackBar 的通用方法
  static void _showSnackBar(
    BuildContext context,
    String message, {
    required IconData icon,
    required Color backgroundColor,
    Duration? duration,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: duration ?? const Duration(seconds: 4),
      ),
    );
  }

  /// 显示错误对话框
  static Future<void> showErrorDialog(
    BuildContext context,
    String title,
    String message, {
    String? details,
  }) async {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[600]),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (details != null) ...[
              const SizedBox(height: 12),
              Text(
                '详细信息：',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Text(
                details,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 处理并显示错误
  static void handleError(BuildContext context, Object error, {bool showDialog = false}) {
    final appError = AppError.fromException(error);
    
    if (showDialog) {
      showErrorDialog(
        context,
        _getErrorTitle(appError.type),
        appError.message,
        details: appError.details,
      );
    } else {
      showAppError(context, appError);
    }
  }
  
  /// 获取错误标题
  static String _getErrorTitle(AppErrorType type) {
    switch (type) {
      case AppErrorType.network:
        return '网络错误';
      case AppErrorType.authentication:
        return '认证错误';
      case AppErrorType.server:
        return '服务器错误';
      case AppErrorType.parsing:
        return '数据解析错误';
      case AppErrorType.validation:
        return '验证错误';
      case AppErrorType.permission:
        return '权限错误';
      case AppErrorType.unknown:
        return '未知错误';
    }
  }

  /// 格式化网络错误信息（保持向后兼容）
  @Deprecated('使用 AppError.fromException 替代')
  static String formatNetworkError(dynamic error) {
    return AppError.fromException(error).message;
  }
}
