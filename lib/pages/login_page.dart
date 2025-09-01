// 登录页面：支持选择网络环境、拉取验证码并提交登录
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:kwt_flutter/services/kwt_client.dart';
import 'package:kwt_flutter/services/settings.dart';
import 'package:kwt_flutter/config/app_config.dart';

/// 登录页
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  KwtClient? _client;
  final _settings = SettingsService();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  Uint8List? _captcha;
  bool _busy = false;
  String? _error;
  String _selectedNetworkEnvironment = 'intranet'; // 默认选择校园网
  bool _rememberPassword = false;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  /// 加载已保存的初始状态（网络环境、记住账号与密码）并初始化客户端
  Future<void> _loadInitialState() async {
    final savedEnvironment = await _settings.getNetworkEnvironment();
    if (savedEnvironment != null) {
      setState(() {
        _selectedNetworkEnvironment = savedEnvironment;
      });
    }
    // 记住账号与密码（仅在开启“记住”时自动填充）
    final remember = await _settings.getRememberPassword();
    String? savedPwd;
    String? rememberedSid;
    if (remember) {
      rememberedSid = await _settings.getRememberedStudentId();
      savedPwd = await _settings.getSavedPassword();
    }
    setState(() {
      _rememberPassword = remember;
      if (rememberedSid != null && rememberedSid.isNotEmpty) {
        _userCtrl.text = rememberedSid;
      }
      if (savedPwd != null && savedPwd.isNotEmpty) {
        _passCtrl.text = savedPwd;
      }
    });
    await _initClient();
  }

  /// 根据选择的网络环境创建客户端并刷新验证码
  Future<void> _initClient() async {
    final serverUrl = _selectedNetworkEnvironment == 'internet' 
        ? NetworkEnvironment.internet.baseUrl
        : NetworkEnvironment.intranet.baseUrl;
    final c = await KwtClient.createPersisted(baseUrl: serverUrl);
    if (!mounted) return;
    setState(() => _client = c);
    await _loadCaptcha();
  }

  /// 拉取验证码图片
  Future<void> _loadCaptcha() async {
    if (_client == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final img = await _client!.fetchCaptcha();
      setState(() {
        _captcha = img;
      });
    } catch (e) {
      setState(() => _error = '获取验证码失败: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  /// 执行登录流程：失败刷新验证码，成功持久化信息并进入主界面
  Future<void> _doLogin() async {
    if (_client == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await _client!.login(
        userAccount: _userCtrl.text.trim(),
        userPassword: _passCtrl.text,
        verifyCode: _codeCtrl.text.trim(),
      );
      if (!ok) {
        setState(() => _error = '登录失败，请检查账号/密码/验证码');
        await _loadCaptcha();
        return;
      }
      // 登录成功：保存登录态、学号、网络环境选择，并尝试拉取姓名
      await _settings.setLoggedIn(true);
      await _settings.saveNetworkEnvironment(_selectedNetworkEnvironment);
      final sid = _userCtrl.text.trim();
      if (sid.isNotEmpty) {
        await _settings.saveStudentId(sid);
      }
      // 保存“记住账号与密码”状态与数据
      await _settings.setRememberPassword(_rememberPassword);
      if (_rememberPassword) {
        await _settings.saveRememberedStudentId(sid);
        await _settings.savePassword(_passCtrl.text);
      }
      try {
        final info = await _client!.fetchProfileInfo();
        final name = (info['name'] ?? '').trim();
        if (name.isNotEmpty) {
          await _settings.saveStudentName(name);
        }
      } catch (_) {}
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/tabs', (route) => false, arguments: _client);
    } catch (e) {
      setState(() => _error = '登录异常: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: null,
        title: const Text('登录', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
        centerTitle: false,
      ),
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo和标题区域
              const SizedBox(height: 60),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'lib/assets/images/logo.png',
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '科文通',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // 登录表单
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '登录',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    
                    // 网络环境选择
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedNetworkEnvironment,
                        decoration: const InputDecoration(
                          labelText: '网络环境',
                          prefixIcon: Icon(Icons.wifi, color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'intranet',
                            child: Text('校园网环境'),
                          ),
                          DropdownMenuItem(
                            value: 'internet',
                            child: Text('外网环境'),
                          ),
                        ],
                        onChanged: (value) async {
                          if (value != null && value != _selectedNetworkEnvironment) {
                            setState(() {
                              _selectedNetworkEnvironment = value;
                            });
                            // 网络环境改变时重新创建客户端
                            await _initClient();
                          }
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 学号输入框
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: TextField(
                        controller: _userCtrl,
                        decoration: InputDecoration(
                          labelText: '学号',
                          prefixIcon: Icon(Icons.person, color: Colors.grey[600]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 密码输入框
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: TextField(
                        controller: _passCtrl,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: '密码',
                          prefixIcon: Icon(Icons.lock, color: Colors.grey[600]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 12),

                    // 记住账号与密码
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberPassword,
                          onChanged: (v) async {
                            if (v == null) return;
                            setState(() => _rememberPassword = v);
                            if (!v) {
                              // 关闭时立即清除已记住的数据
                              await _settings.setRememberPassword(false);
                            }
                          },
                        ),
                        const SizedBox(width: 4),
                        const Text('记住账号与密码'),
                      ],
                    ),

                    const SizedBox(height: 4),
                    
                    // 验证码输入框和图片
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: TextField(
                              controller: _codeCtrl,
                              decoration: InputDecoration(
                                labelText: '验证码',
                                prefixIcon: Icon(Icons.security, color: Colors.grey[600]),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // 验证码图片 - 自适应大小
                        GestureDetector(
                          onTap: _busy ? null : _loadCaptcha,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: _captcha == null
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.refresh, color: Colors.grey[600], size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          '刷新',
                                          style: TextStyle(color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  )
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.memory(
                                      _captcha!,
                                      fit: BoxFit.contain,
                                      // 不限制尺寸，让图片自适应
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // 错误信息
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red[600], size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(color: Colors.red[600]),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // 登录按钮
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _busy ? null : _doLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                '登录',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // 底部提示
              Text(
                '请使用您的学号和密码登录系统',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


