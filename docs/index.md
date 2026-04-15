# SpeedTest 项目文档索引

## 项目概览

- **类型：** 单体应用 (monolith)
- **主要语言：** Dart (Flutter)
- **架构：** MVVM (Model-View-ViewModel)
- **平台：** Android

## 快速参考

- **技术栈：** Flutter 3.27.1 + Provider + SQLite
- **入口点：** `lib/main.dart`
- **架构模式：** 特性模块化 (Feature-based)

## 项目结构

```
SpeedTest/
├── speed_test_app/           # Flutter 应用主目录
│   ├── lib/
│   │   ├── app/              # 应用核心配置
│   │   ├── core/              # 核心工具
│   │   ├── features/          # 功能模块
│   │   └── main.dart          # 应用入口
│   ├── android/               # Android 平台代码
│   ├── ios/                   # iOS 平台代码
│   └── pubspec.yaml           # 依赖配置
├── docs/                      # 项目文档 (本文档目录)
└── .github/                   # GitHub 配置
```

## 技术栈详情

| 分类 | 技术 | 版本 |
|------|------|------|
| 框架 | Flutter | 3.27.1 |
| 状态管理 | Provider | 6.1.2 |
| 本地数据库 | sqflite | 2.3.3 |
| 网络请求 | http | 1.2.2 |
| 国际化 | flutter_localizations + intl | - |
| 持久化 | SharedPreferences | 2.2.3 |
| 测速 API | Cloudflare Speed Test | - |

## 生成文档

- [项目概览](./project-overview.md)
- [架构文档](./architecture.md)
- [源码树分析](./source-tree-analysis.md)
- [开发指南](./development-guide.md)
- [组件清单](./component-inventory.md)

## 现有文档

- [README.md](../speed_test_app/README.md) - 项目自述文件

## 入门指南

1. 确保已安装 Flutter 3.27.1
2. 运行 `flutter pub get` 安装依赖
3. 运行 `flutter run` 启动应用

## 关键文件位置

| 功能 | 文件路径 |
|------|----------|
| 应用入口 | `lib/main.dart` |
| 主题配置 | `lib/app/theme.dart` |
| 测速服务 | `lib/features/speed_test/data/services/speed_test_service.dart` |
| 历史记录 | `lib/features/speed_test/data/repositories/history_repository.dart` |
| 首页 UI | `lib/features/speed_test/presentation/views/home_page.dart` |
| 设置页面 | `lib/features/speed_test/presentation/views/settings_page.dart` |
