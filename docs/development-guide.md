# 开发指南

## 环境要求

| 要求 | 版本 |
|------|------|
| Flutter SDK | 3.27.1 |
| Dart SDK | ^3.6.0 |
| Android SDK | 21+ |
| Xcode | 14.0+ (iOS 开发) |

## 本地开发

### 1. 安装依赖

```bash
cd speed_test_app
flutter pub get
```

### 2. 运行应用

```bash
# Debug 模式
flutter run

# 指定设备
flutter devices    # 查看可用设备
flutter run -d <device_id>
```

### 3. 代码分析

```bash
# 分析代码
flutter analyze

# 带修复建议的分析
flutter analyze --fix
```

### 4. 测试

```bash
# 运行测试
flutter test

# 运行特定测试文件
flutter test test/widget_test.dart
```

## 项目架构

### MVVM 架构

本项目采用 MVVM (Model-View-ViewModel) 架构：

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│    View     │ ←── │  ViewModel   │ ←── │    Model     │
│  (Widgets)  │     │ (ChangeNotifier) │   │   (Data)    │
└─────────────┘     └──────────────┘     └─────────────┘
     ↑                    ↑                    ↑
  UI 组件            状态管理              数据结构
```

### 模块组织

```
features/
└── speed_test/              # 测速功能模块
    ├── data/                # 数据层
    │   ├── models/          # 数据模型
    │   ├── repositories/     # 数据仓库
    │   └── services/        # 外部服务
    │
    └── presentation/         # 展示层
        ├── viewmodels/      # 状态管理
        ├── views/           # 页面
        └── widgets/         # UI 组件
```

## 状态管理

### Provider 配置

在 `lib/app/app.dart` 中配置：

```dart
MultiProvider(
  providers: [
    // 基础状态
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ChangeNotifierProvider(create: (_) => LocaleProvider()),
    ChangeNotifierProvider(create: (_) => UnitProvider()),

    // 服务
    Provider<SpeedTestService>(create: (_) => SpeedTestService()),

    // 仓库 (依赖服务)
    ProxyProvider<SpeedTestService, HistoryRepository>(
      update: (_, speedTestService, __) => HistoryRepository(),
    ),

    // ViewModels (依赖仓库)
    ChangeNotifierProxyProvider<HistoryRepository, SpeedTestViewModel>(
      create: (_) => SpeedTestViewModel(),
      update: (_, historyRepository, previous) {
        final vm = previous ?? SpeedTestViewModel(historyRepository: historyRepository);
        vm.setHistoryRepository(historyRepository);
        return vm;
      },
    ),
    ChangeNotifierProxyProvider<HistoryRepository, HistoryViewModel>(...),
  ],
)
```

### 在 Widget 中使用

```dart
// 读取状态
final themeProvider = context.watch<ThemeProvider>();
final unitProvider = context.read<UnitProvider>();

// 监听多个状态
Consumer2<HistoryViewModel, UnitProvider>(
  builder: (context, historyVM, unitProvider, _) {
    return Text('Unit: ${unitProvider.unit}');
  },
)
```

## 添加新功能

### 1. 添加新的 Provider

```dart
// lib/app/new_provider.dart
class NewProvider extends ChangeNotifier {
  // 状态和方法
}
```

### 2. 在 app.dart 中注册

```dart
ChangeNotifierProvider(create: (_) => NewProvider()),
```

### 3. 在 Widget 中使用

```dart
final newProvider = context.watch<NewProvider>();
```

### 4. 添加新的页面

```dart
// lib/features/speed_test/presentation/views/new_page.dart
class NewPage extends StatelessWidget {
  const NewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('New Page')),
      body: Center(child: Text('New Page Content')),
    );
  }
}
```

### 5. 添加路由（如需导航）

在 `home_page.dart` 或 `app.dart` 中添加导航：

```dart
onTap: () => Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => const NewPage()),
),
```

## 国际化

### 添加新的翻译字符串

1. 编辑 `lib/l10n/app_en.arb`:

```json
{
  "newKey": "New Value",
  "@newKey": {
    "description": "Description of the string"
  }
}
```

2. 其他语言文件也需要添加对应翻译

3. 重新生成代码：

```bash
flutter gen-l10n
```

### 使用翻译

```dart
Text(AppLocalizations.of(context)!.newKey)
```

## 构建和发布

### Android 构建

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# 输出位置: build/app/outputs/flutter-apk/
```

### iOS 构建

```bash
# Debug
flutter build ios --debug

# Release
flutter build ios --release
```

### GitHub Actions 自动发布

Push tag 自动触发 GitHub Release：

```bash
# 创建 tag
git tag v1.0.6

# 推送 tag
git push origin v1.0.6
```

## 目录约定

| 目录 | 用途 | 约束 |
|------|------|------|
| `lib/app/` | 全局配置 | 不应包含业务逻辑 |
| `lib/core/` | 公共工具 | 可被多个功能复用 |
| `lib/features/` | 功能模块 | 按特性隔离 |
| `lib/l10n/` | 国际化 | 仅包含翻译资源 |

## 代码规范

- 使用 `flutter analyze` 检查代码
- 遵循 Dart style guide
- 所有用户可见字符串必须国际化
- ViewModel 中不应直接操作 UI
- 组件应该是 stateless（如果可能）
