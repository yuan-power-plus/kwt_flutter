// 应用与网络相关的常量配置
class AppConfig {
  // 网络环境配置
  static const String intranetServerUrl = 'http://10.110.225.76/jsxsd'; // 校园网环境
  static const String internetServerUrl = 'http://222.187.129.200:51234/jsxsd'; // 外网环境
  
  // 默认时间模式
  static const String defaultTimeMode = '2AA072D3F1D747B98B4F5F84683493E5';
  
  // 应用配置
  static const String appName = '科文通';
  static const String appVersion = '3.3.1';
  // GitHub Releases 信息（用于检查更新）
  static const String githubOwner = 'yuan-power-plus';
  static const String githubRepo = 'kwt_flutter';
  
  // 网络配置
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  
  // 缓存配置
  static const Duration cookieExpiration = Duration(days: 7);
}
