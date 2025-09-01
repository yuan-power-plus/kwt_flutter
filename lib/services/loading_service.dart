import 'package:flutter/material.dart';

/// 加载状态类型
enum LoadingType {
  /// 普通加载
  normal,
  /// 页面初始化加载
  initial,
  /// 刷新加载
  refresh,
  /// 提交加载
  submit,
}

/// 加载状态信息
class LoadingState {
  const LoadingState({
    required this.isLoading,
    required this.type,
    this.message,
  });

  final bool isLoading;
  final LoadingType type;
  final String? message;

  static const idle = LoadingState(isLoading: false, type: LoadingType.normal);
  
  LoadingState copyWith({
    bool? isLoading,
    LoadingType? type,
    String? message,
  }) {
    return LoadingState(
      isLoading: isLoading ?? this.isLoading,
      type: type ?? this.type,
      message: message ?? this.message,
    );
  }
}

/// 全局加载状态管理服务
class LoadingService extends ChangeNotifier {
  static final LoadingService _instance = LoadingService._internal();
  factory LoadingService() => _instance;
  LoadingService._internal();

  LoadingState _state = LoadingState.idle;
  final Map<String, LoadingState> _namedStates = {};

  /// 当前加载状态
  LoadingState get state => _state;

  /// 是否正在加载
  bool get isLoading => _state.isLoading;

  /// 显示加载状态
  void show({
    LoadingType type = LoadingType.normal,
    String? message,
  }) {
    _state = LoadingState(
      isLoading: true,
      type: type,
      message: message,
    );
    notifyListeners();
  }

  /// 隐藏加载状态
  void hide() {
    _state = LoadingState.idle;
    notifyListeners();
  }

  /// 获取命名加载状态
  LoadingState getNamedState(String name) {
    return _namedStates[name] ?? LoadingState.idle;
  }

  /// 显示命名加载状态
  void showNamed(
    String name, {
    LoadingType type = LoadingType.normal,
    String? message,
  }) {
    _namedStates[name] = LoadingState(
      isLoading: true,
      type: type,
      message: message,
    );
    notifyListeners();
  }

  /// 隐藏命名加载状态
  void hideNamed(String name) {
    _namedStates[name] = LoadingState.idle;
    notifyListeners();
  }

  /// 是否有任何加载状态
  bool get hasAnyLoading {
    return _state.isLoading || _namedStates.values.any((state) => state.isLoading);
  }

  /// 包装异步操作并自动管理加载状态
  Future<T> wrap<T>(
    Future<T> Function() operation, {
    LoadingType type = LoadingType.normal,
    String? message,
    String? name,
  }) async {
    try {
      if (name != null) {
        showNamed(name, type: type, message: message);
      } else {
        show(type: type, message: message);
      }
      
      return await operation();
    } finally {
      if (name != null) {
        hideNamed(name);
      } else {
        hide();
      }
    }
  }
}

/// 加载状态构建器
class LoadingBuilder extends StatefulWidget {
  const LoadingBuilder({
    super.key,
    required this.builder,
    this.name,
    this.child,
  });

  final Widget Function(BuildContext context, LoadingState state, Widget? child) builder;
  final String? name;
  final Widget? child;

  @override
  State<LoadingBuilder> createState() => _LoadingBuilderState();
}

class _LoadingBuilderState extends State<LoadingBuilder> {
  late final LoadingService _loadingService;

  @override
  void initState() {
    super.initState();
    _loadingService = LoadingService();
    _loadingService.addListener(_onLoadingStateChanged);
  }

  @override
  void dispose() {
    _loadingService.removeListener(_onLoadingStateChanged);
    super.dispose();
  }

  void _onLoadingStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.name != null
        ? _loadingService.getNamedState(widget.name!)
        : _loadingService.state;
    
    return widget.builder(context, state, widget.child);
  }
}

/// 加载覆盖层
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.child,
    this.name,
  });

  final Widget child;
  final String? name;

  @override
  Widget build(BuildContext context) {
    return LoadingBuilder(
      name: name,
      builder: (context, state, _) {
        return Stack(
          children: [
            child,
            if (state.isLoading) ...[
              // 半透明背景
              Container(
                color: Colors.black.withValues(alpha: 0.3),
              ),
              // 加载指示器
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      if (state.message != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          state.message!,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// 加载按钮
class LoadingButton extends StatelessWidget {
  const LoadingButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.name,
    this.style,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final String? name;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    return LoadingBuilder(
      name: name,
      builder: (context, state, _) {
        final isLoading = state.isLoading;
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: style,
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : child,
        );
      },
    );
  }
}