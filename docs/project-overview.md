# SpeedTest 项目概览

## 项目信息

| 属性 | 值 |
|------|-----|
| 项目名称 | SpeedTest |
| 应用名称 | Speed Test |
| 包名 | com.klz.speedtest |
| 版本 | 1.0.5 |
| Flutter 版本 | 3.27.1 |

## 项目简介

SpeedTest 是一款使用 Flutter 构建的网速测试应用，支持实时测速、测速历史记录、多语言切换和主题切换。采用 MVVM 架构，使用 Provider 进行状态管理，数据持久化使用 SQLite。

## 核心功能

### 网速测试
- **下载速度测试** - 使用 Cloudflare Speed Test API
- **上传速度测试** - 使用 Cloudflare Speed Test API
- **延迟测试 (Ping)** - 测量网络延迟

### 数据展示
- **实时动画仪表盘** - 270度弧形仪表盘，指针平滑动画
- **智能刻度** - 根据单位（Mbps/MB/s）自动切换刻度范围
- **测速历史** - 本地 SQLite 数据库存储历史记录
- **数据统计** - 显示最近10次测试的平均值

### 用户体验
- **多语言支持** - 英文、简体中文、繁体中文
- **主题切换** - 浅色模式、深色模式、跟随系统
- **单位切换** - Mbps（兆比特）和 MB/s（兆字节）一键切换
- **Material Design 3** - 遵循最新 Material 设计规范

### 版本管理
- **版本检测** - 自动检测 GitHub Releases 最新版本
- **自动更新** - 支持应用内下载和安装更新

## 技术架构

### 架构模式
- **MVVM (Model-View-ViewModel)**
  - Model: 数据模型 (`speed_result.dart`)
  - View: 页面和组件 (`views/`, `widgets/`)
  - ViewModel: 状态管理 (`viewmodels/`)

### 状态管理
- **Provider** - Flutter 官方推荐的状态管理方案
  - `ThemeProvider` - 主题状态管理
  - `LocaleProvider` - 语言状态管理
  - `UnitProvider` - 单位状态管理
  - `SpeedTestViewModel` - 测速状态管理
  - `HistoryViewModel` - 历史记录状态管理

### 数据层
- **SQLite (sqflite)** - 本地数据库存储测速历史
- **SharedPreferences** - 用户偏好设置持久化

### 网络层
- **http** - HTTP 请求库
- **Cloudflare Speed Test API** - 测速服务提供商

## 目录结构

```
lib/
├── app/                              # 应用核心配置
│   ├── app.dart                      # MultiProvider 配置，应用入口
│   ├── theme.dart                    # Material 3 主题定义
│   ├── theme_provider.dart           # 主题状态管理
│   ├── locale_provider.dart           # 语言状态管理
│   └── unit_provider.dart            # 单位状态管理
│
├── core/                             # 核心工具
│   ├── constants/
│   │   └── app_constants.dart        # 应用常量
│   └── utils/
│       └── speed_rating.dart         # 速度评级工具
│
├── features/                         # 功能模块
│   └── speed_test/                   # 测速功能
│       ├── data/                     # 数据层
│       │   ├── models/
│       │   │   └── speed_result.dart    # 测速结果数据模型
│       │   ├── repositories/
│       │   │   └── history_repository.dart # 历史记录数据仓库
│       │   └── services/
│       │       ├── speed_test_service.dart  # 测速服务
│       │       └── version_service.dart      # 版本检测服务
│       │
│       └── presentation/             # 展示层
│           ├── viewmodels/
│           │   ├── speed_test_viewmodel.dart  # 测速 ViewModel
│           │   └── history_viewmodel.dart     # 历史记录 ViewModel
│           ├── views/
│           │   ├── home_page.dart            # 首页
│           │   └── settings_page.dart         # 设置页面
│           └── widgets/
│               ├── speed_gauge.dart          # 仪表盘组件
│               ├── history_tile.dart          # 历史记录条目
│               ├── ping_indicator.dart        # 延迟指示器
│               ├── version_check_dialog.dart  # 版本检测对话框
│               └── download_progress_dialog.dart # 下载进度对话框
│
├── l10n/                             # 国际化资源
│   ├── app_en.arb                    # 英文
│   ├── app_zh.arb                    # 简体中文
│   └── app_zh_TW.arb                 # 繁体中文
│
└── main.dart                         # 应用入口
```

## 平台配置

### Android
- **最低 SDK 版本：** 21
- **目标 SDK 版本：** 34
- **权限：**
  - `INTERNET` - 网络访问
  - `REQUEST_INSTALL_PACKAGES` - 安装更新包

### iOS
- **最低版本：** 12.0

## 依赖关系

### 主要依赖
```yaml
dependencies:
  flutter: sdk
  provider: ^6.1.2          # 状态管理
  http: ^1.2.2              # 网络请求
  sqflite: ^2.3.3           # SQLite 数据库
  path_provider: ^2.1.4     # 文件路径
  shared_preferences: ^2.2.3 # 偏好设置
  intl: ^0.19.0             # 国际化
  package_info_plus: ^8.0.2 # 包信息
  permission_handler: ^11.3.1 # 权限处理
  android_intent_plus: ^5.0.0 # Android Intent
```

## 构建和发布

### 构建命令
```bash
# Debug 构建
flutter build apk --debug

# Release 构建
flutter build apk --release

# iOS 构建
flutter build ios --release
```

### GitHub Actions CI/CD
- **CI 工作流：** Flutter CI 自动构建和测试
- **发布工作流：** push tag 时自动发布到 GitHub Releases
