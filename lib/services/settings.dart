import 'package:shared_preferences/shared_preferences.dart';
import 'package:kwt_flutter/services/config.dart';

// 本地设置服务：封装 SharedPreferences 的键值读写
class SettingsService {
  static const _keyTerm = 'kwt.term';
  static const _keyStartDate = 'kwt.startDate';
  static const _keyLoggedIn = 'kwt.loggedIn';
  static const _keyStudentId = 'kwt.studentId';
  static const _keyStudentName = 'kwt.studentName';
  static const _keyNetworkEnvironment = 'kwt.networkEnvironment';
  static const _keyRememberPassword = 'kwt.rememberPassword';
  static const _keySavedPassword = 'kwt.savedPassword';
  static const _keyRememberedStudentId = 'kwt.rememberedStudentId';

  Future<void> saveTerm(String term) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_keyTerm, term);
  }

  Future<void> saveStartDate(String date) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_keyStartDate, date);
  }

  Future<String?> getTerm() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_keyTerm);
  }

  Future<String?> getStartDate() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_keyStartDate);
  }

  Future<void> setLoggedIn(bool v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_keyLoggedIn, v);
  }

  Future<bool> isLoggedIn() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_keyLoggedIn) ?? false;
  }

  Future<void> saveStudentId(String id) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_keyStudentId, id);
  }

  Future<String?> getStudentId() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_keyStudentId);
  }

  Future<void> saveStudentName(String name) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_keyStudentName, name);
  }

  Future<String?> getStudentName() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_keyStudentName);
  }

  /// 清除本地登录态与基础账户信息
  Future<void> clearAuth() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_keyLoggedIn, false);
    await sp.remove(_keyStudentId);
    await sp.remove(_keyStudentName);
  }

  // 网络环境相关方法
  Future<void> saveNetworkEnvironment(String environment) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_keyNetworkEnvironment, environment);
  }

  Future<String?> getNetworkEnvironment() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_keyNetworkEnvironment);
  }

  Future<String> getCurrentServerUrl() async {
    final environment = await getNetworkEnvironment();
    if (environment == 'internet') {
      return AppConfig.internetServerUrl;
    }
    // 默认为校园网
    return AppConfig.intranetServerUrl;
  }

  // 记住密码与本地保存的密码
  Future<void> setRememberPassword(bool remember) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_keyRememberPassword, remember);
    if (!remember) {
      await sp.remove(_keySavedPassword);
      await sp.remove(_keyRememberedStudentId);
    }
  }

  Future<bool> getRememberPassword() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_keyRememberPassword) ?? false;
  }

  Future<void> savePassword(String password) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_keySavedPassword, password);
  }

  Future<String?> getSavedPassword() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_keySavedPassword);
  }

  // 记住的学号（与“记住账号与密码”联动）
  Future<void> saveRememberedStudentId(String studentId) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_keyRememberedStudentId, studentId);
  }

  Future<String?> getRememberedStudentId() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_keyRememberedStudentId);
  }
}


