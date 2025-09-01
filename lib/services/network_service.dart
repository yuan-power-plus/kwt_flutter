import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 网络连接状态
enum ConnectionStatus {
  /// 已连接
  connected,
  /// 已断开
  disconnected,
  /// 未知状态
  unknown,
}

/// 网络状态管理服务
class NetworkService extends ChangeNotifier {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  ConnectionStatus _status = ConnectionStatus.unknown;
  Timer? _timer;
  bool _isChecking = false;

  /// 当前网络状态
  ConnectionStatus get status => _status;

  /// 是否已连接
  bool get isConnected => _status == ConnectionStatus.connected;

  /// 开始监听网络状态
  void startMonitoring() {
    if (_timer != null) return;
    
    // 立即检查一次
    _checkConnection();
    
    // 每10秒检查一次网络状态
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkConnection();
    });
  }

  /// 停止监听网络状态
  void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
  }

  /// 检查网络连接
  Future<bool> checkConnection() async {
    await _checkConnection();
    return isConnected;
  }

  /// 内部检查网络连接方法
  Future<void> _checkConnection() async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      if (kIsWeb) {
        // Web 平台的网络检查
        _updateStatus(ConnectionStatus.connected);
      } else {
        // 移动端和桌面端的网络检查
        final result = await InternetAddress.lookup('baidu.com')
            .timeout(const Duration(seconds: 3));
        
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          _updateStatus(ConnectionStatus.connected);
        } else {
          _updateStatus(ConnectionStatus.disconnected);
        }
      }
    } catch (e) {
      _updateStatus(ConnectionStatus.disconnected);
    } finally {
      _isChecking = false;
    }
  }

  /// 更新网络状态
  void _updateStatus(ConnectionStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}

/// 网络状态 Widget
class NetworkStatusBuilder extends StatefulWidget {
  const NetworkStatusBuilder({
    super.key,
    required this.builder,
    this.child,
  });

  final Widget Function(BuildContext context, ConnectionStatus status, Widget? child) builder;
  final Widget? child;

  @override
  State<NetworkStatusBuilder> createState() => _NetworkStatusBuilderState();
}

class _NetworkStatusBuilderState extends State<NetworkStatusBuilder> {
  late final NetworkService _networkService;

  @override
  void initState() {
    super.initState();
    _networkService = NetworkService();
    _networkService.addListener(_onNetworkStatusChanged);
    _networkService.startMonitoring();
  }

  @override
  void dispose() {
    _networkService.removeListener(_onNetworkStatusChanged);
    super.dispose();
  }

  void _onNetworkStatusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _networkService.status, widget.child);
  }
}

/// 网络状态指示器
class NetworkStatusIndicator extends StatelessWidget {
  const NetworkStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return NetworkStatusBuilder(
      builder: (context, status, child) {
        if (status == ConnectionStatus.connected) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: status == ConnectionStatus.disconnected 
            ? Colors.red[600] 
            : Colors.orange[600],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                status == ConnectionStatus.disconnected 
                  ? Icons.wifi_off 
                  : Icons.wifi,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                status == ConnectionStatus.disconnected 
                  ? '网络已断开' 
                  : '网络状态未知',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}