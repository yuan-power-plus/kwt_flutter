# 科文通 KWT Flutter

一个用于查询科文通教务系统信息的 Flutter 应用，支持查看课表、成绩、等级考试等核心功能，提供现代化的 Material 3 体验，并适配多平台。

## ✨ 功能特性

- **个人课表查询**: 查看个人课程安排与详情
- **班级课表查询**: 输入班级信息查询对应课表
- **成绩查询**: 查看课程成绩、学分与 GPA
- **等级考试查询**: 四六级等等级考试成绩
- **用户登录**: 支持学号密码登录，自动管理 Cookie
- **检查更新**: 基于 GitHub Releases 的版本检查
- **响应式与深色模式**: 多端适配，Material Design 3 风格

## 🛠️ 技术栈

- Flutter 3 • Dart 3
- 网络: Dio、Cookie 管理、HTML 解析
- 存储: SharedPreferences
- UI: Material 3、Cupertino Icons

## ✅ 运行环境

- Flutter SDK: ^3.8.1
- Dart SDK: ^3.8.1
- Android: API 21+ (Android 5.0+)
- iOS: 12.0+
- 可选: Windows / macOS / Linux / Web

## 🚀 快速开始

1) 克隆并安装依赖

```bash
git clone https://github.com/yuan-power-plus/kwt_flutter
cd kwt_flutter
flutter pub get
```

2) 开发运行

```bash
flutter run
```

应用默认会在「课表」页面启动，你可以在「我的/功能」页登录后使用更多查询能力。

## 📚 使用教程

- **启动应用**: 首次进入默认展示个人课表（未登录时展示空态或引导登录）
- **登录**: 在「我的」或「功能」页面使用学号与密码登录；成功后自动维护会话
- **个人课表**: 首页查看；可切换周次/时间模式
- **班级课表**: 进入「班级课表」页面，输入班级关键字后查询
- **成绩/等级考试**: 对应页面点击查询，支持按学年/学期筛选（若有）
- **更新检查**: 在设置或关于页面触发检查（GitHub Releases: `yuan-power-plus/kwt_flutter`）

## 📦 构建发布

### Android（含签名）

本项目使用 Kotlin DSL（`build.gradle.kts`）并从项目根读取 `key.properties` 完成签名：

```kotlin
// android/app/build.gradle.kts（节选）
val keystoreProperties = Properties()
run {
    val f = rootProject.file("key.properties")
    if (f.exists()) {
        f.inputStream().use { keystoreProperties.load(it) }
    }
}
```

1) 生成签名证书（keystore）

```bash
# 在项目根目录或任意目录执行，建议保存到 android/ 目录下
keytool -genkeypair -v -keystore kwt.jks -alias kwt -keyalg RSA -keysize 2048 -validity 36500 -storetype JKS
```

2) 创建 `key.properties`（android目录下）

```properties
# key.properties（位于项目根目录）
storeFile=kwt.jks
storePassword=你的Keystore密码
keyAlias=kwt
keyPassword=你的Key密码
```

3) 构建发布包

```bash
# APK（推荐用于直装分发）
flutter build apk --release

# App Bundle（推荐上架应用商店）
flutter build appbundle --release
```

构建成功后产物位于：
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

注意：如果未提供 `key.properties`，release 构建会使用未签名配置或失败，请确保文件存在且路径/密码正确。

### iOS（签名与发布）

1) 打开 iOS 工程

```bash
open ios/Runner.xcworkspace
```

2) 在 Xcode 中：
- 选择 Team，设置 Bundle Identifier
- 设置 Signing & Capabilities（开发/发布证书、Provisioning Profile）
- Product > Archive 进行打包并通过 Organizer 分发

3) Flutter 命令行构建（需要已配置签名）：

```bash
flutter build ios --release
```

### 其他平台

- Web: `flutter build web`
- Windows: `flutter build windows`
- macOS: `flutter build macos`
- Linux: `flutter build linux`

## 📁 项目结构

```
lib/
├── assets/           # 静态资源
├── common/           # 通用组件
├── constants/        # 常量定义
├── models/           # 数据模型
├── pages/            # 页面组件
├── services/         # Dio 客户端、配置、设置与更新服务
├── theme/            # 主题配置（Material 3）
├── utils/            # 工具类
└── main.dart         # 应用入口
```

## 🔧 配置与定制

- `lib/services/config.dart`
  - `intranetServerUrl` / `internetServerUrl`: 校内/外访问入口
  - `appName` / `appVersion`: 应用信息
  - `githubOwner` / `githubRepo`: 用于检查更新的仓库
  - `connectionTimeout` / `receiveTimeout`: 网络超时

- App 图标：已集成 `flutter_launcher_icons`，可修改 `pubspec.yaml` 中的相关配置后执行：

```bash
flutter pub run flutter_launcher_icons:main
```

## 📜 许可证与声明

本项目仅供学习与研究使用，请勿用于商业用途。使用本应用时请遵守相关法律法规与学校规定。

## 🤝 贡献

欢迎提交 Issue 与 Pull Request，共同完善项目！
