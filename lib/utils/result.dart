/// Result 类型：用于统一处理成功与失败结果，避免异常传播
sealed class Result<T> {
  const Result();
}

/// 成功结果
final class Success<T> extends Result<T> {
  const Success(this.data);
  final T data;
}

/// 失败结果
final class Failure<T> extends Result<T> {
  const Failure(this.error, [this.stackTrace]);
  final Object error;
  final StackTrace? stackTrace;
  
  String get message {
    if (error is Exception) {
      return error.toString();
    }
    return error.toString();
  }
}

/// Result 扩展方法
extension ResultExtensions<T> on Result<T> {
  /// 是否成功
  bool get isSuccess => this is Success<T>;
  
  /// 是否失败
  bool get isFailure => this is Failure<T>;
  
  /// 获取数据，失败时返回 null
  T? get dataOrNull {
    return switch (this) {
      Success(:final data) => data,
      Failure() => null,
    };
  }
  
  /// 获取错误，成功时返回 null
  Object? get errorOrNull {
    return switch (this) {
      Success() => null,
      Failure(:final error) => error,
    };
  }
  
  /// 映射成功结果
  Result<R> map<R>(R Function(T) transform) {
    return switch (this) {
      Success(:final data) => Success(transform(data)),
      Failure(:final error, :final stackTrace) => Failure(error, stackTrace),
    };
  }
  
  /// 映射失败结果
  Result<T> mapError(Object Function(Object) transform) {
    return switch (this) {
      Success(:final data) => Success(data),
      Failure(:final error, :final stackTrace) => Failure(transform(error), stackTrace),
    };
  }
  
  /// 处理结果
  R when<R>({
    required R Function(T data) success,
    required R Function(Object error) failure,
  }) {
    return switch (this) {
      Success(:final data) => success(data),
      Failure(:final error) => failure(error),
    };
  }
}

/// 便捷方法
Result<T> success<T>(T data) => Success(data);
Result<T> failure<T>(Object error, [StackTrace? stackTrace]) => Failure(error, stackTrace);

/// 异步操作的 Result 包装
Future<Result<T>> resultOf<T>(Future<T> Function() operation) async {
  try {
    final data = await operation();
    return Success(data);
  } catch (error, stackTrace) {
    return Failure(error, stackTrace);
  }
}

/// 同步操作的 Result 包装
Result<T> resultOfSync<T>(T Function() operation) {
  try {
    final data = operation();
    return Success(data);
  } catch (error, stackTrace) {
    return Failure(error, stackTrace);
  }
}