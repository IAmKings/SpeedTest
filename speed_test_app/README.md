# Speed Test App

一款使用 Flutter 构建的网速测试应用，支持实时测速、测速历史记录、多语言切换和主题切换。

![Version](https://img.shields.io/badge/version-2.0.6-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.27.1-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## 功能特性

### 核心功能
- **网速测试** - 支持下载速度、上传速度和网络延迟测试
- **实时动画仪表盘** - 270度弧形仪表盘，指针平滑动画
- **智能刻度** - 根据单位（Mbps/MB/s）自动切换刻度范围
- **测速历史** - 本地 SQLite 数据库存储历史记录
- **数据统计** - 显示最近10次测试的平均值
- **网络类型显示** - 仪表盘内部实时显示当前网络类型和 WiFi 名称

### 用户体验
- **多语言支持** - 英文、简体中文、繁体中文
- **主题切换** - 浅色模式、深色模式、跟随系统
- **单位切换** - Mbps（兆比特）和 MB/s（兆字节）一键切换
- **WiFi 权限管理** - 测试前检查位置权限，支持"不再提示"
- **Material Design 3** - 遵循最新 Material 设计规范

## 技术栈

| 分类 | 技术 |
|------|------|
| 框架 | Flutter 3.27.1 |
| 状态管理 | Provider |
| 架构 | MVVM (Model-View-ViewModel) |
| 本地数据库 | SQLite (sqflite) |
| 网络请求 | http |
| 国际化 | flutter_localizations + intl |
| 持久化 | SharedPreferences |
| 测速 API | Cloudflare Speed Test |

## 项目架构

```
lib/
├── app/                          # 应用核心配置
│   ├── app.dart                  # 应用入口，MultiProvider 配置
│   ├── theme.dart                # Material 3 主题定义
│   ├── theme_provider.dart       # 主题状态管理
│   ├── locale_provider.dart      # 语言状态管理
│   ├── unit_provider.dart        # 单位状态管理
│   ├── network_provider.dart     # 网络状态管理
│   ├── network_permission_provider.dart # WiFi 权限状态管理
│   ├── connection_config_provider.dart # 并发连接数配置
│   └── version_provider.dart     # 版本更新管理
│
├── core/                         # 核心工具
│   ├── constants/
│   │   └── app_constants.dart    # 应用常量
│   └── utils/
│       └── speed_rating.dart     # 速度评级工具
│
├── features/                    # 功能模块
│   └── speed_test/              # 测速功能
│       ├── data/
│       │   ├── models/
│       │   │   └── speed_result.dart      # 测速结果数据模型
│       │   ├── repositories/
│       │   │   └── history_repository.dart # 历史记录数据仓库
│       │   └── services/
│       │       ├── speed_test_service.dart # 测速服务（API调用）
│       │       └── version_service.dart   # 版本更新服务
│       │
│       └── presentation/
│           ├── viewmodels/
│           │   ├── speed_test_viewmodel.dart # 测速 ViewModel
│           │   └── history_viewmodel.dart   # 历史记录 ViewModel
│           ├── views/
│           │   ├── home_page.dart           # 主页
│           │   └── settings_page.dart       # 设置页
│           └── widgets/
│               ├── speed_gauge.dart          # 仪表盘组件
│               ├── ping_indicator.dart       # 延迟指示器
│               ├── history_tile.dart         # 历史记录条目
│               ├── version_check_dialog.dart # 版本更新对话框
│               └── download_progress_dialog.dart # 下载进度对话框
│
├── l10n/                        # 国际化资源
│   ├── app_en.arb               # 英文
│   ├── app_zh.arb               # 简体中文
│   └── app_zh_TW.arb           # 繁体中文
│
└── main.dart                    # 应用入口
```

## MVVM 架构说明

```
┌─────────────────────────────────────────────────────────────┐
│                         View 层                              │
│  (home_page.dart, settings_page.dart, widgets/)             │
│  - UI 渲染，接收用户交互                                     │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ 状态消费 / 方法调用
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      ViewModel 层                            │
│  (SpeedTestViewModel, HistoryViewModel)                     │
│  - 业务逻辑处理                                              │
│  - 状态管理 (ChangeNotifier + notifyListeners)               │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ 数据读写
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                       Data 层                                │
│  (SpeedTestService, HistoryRepository, SpeedResult)          │
│  - API 调用 (Cloudflare Speed Test)                          │
│  - 本地存储 (SQLite)                                         │
│  - 单一数据源 (SSOT)                                         │
└─────────────────────────────────────────────────────────────┘
```

## 安装与运行

### 环境要求
- Flutter SDK 3.6.0 或更高版本
- Dart SDK 3.6.0 或更高版本

### 安装步骤

```bash
# 克隆项目
git clone <repository-url>
cd speed_test_app

# 安装依赖
flutter pub get

# 运行应用（开发模式）
flutter run

# 运行应用（指定设备）
flutter run -d <device-id>
```

### 构建发布

```bash
# 构建 Android Release APK
flutter build apk --release

# 构建 iOS
flutter build ios --release

# 构建 Web
flutter build web
```

构建产物位于 `build/app/outputs/flutter-apk/app-release.apk`

## 仪表盘刻度说明

应用采用**区间平分算法**计算指针角度，270度弧线被均分为8个区间：

### Mbps 刻度
| 区间 | 刻度范围 | 对应角度 |
|------|----------|----------|
| 1 | 0 ~ 5 | 0° ~ 33.75° |
| 2 | 5 ~ 10 | 33.75° ~ 67.5° |
| 3 | 10 ~ 50 | 67.5° ~ 101.25° |
| 4 | 50 ~ 100 | 101.25° ~ 135° |
| 5 | 100 ~ 250 | 135° ~ 168.75° |
| 6 | 250 ~ 500 | 168.75° ~ 202.5° |
| 7 | 500 ~ 1000 | 202.5° ~ 236.25° |
| 8 | 1000 ~ 2000 | 236.25° ~ 270° |

### MB/s 刻度
| 区间 | 刻度范围 | 对应角度 |
|------|----------|----------|
| 1 | 0 ~ 1 | 0° ~ 33.75° |
| 2 | 1 ~ 2 | 33.75° ~ 67.5° |
| 3 | 2 ~ 5 | 67.5° ~ 101.25° |
| 4 | 5 ~ 10 | 101.25° ~ 135° |
| 5 | 10 ~ 25 | 135° ~ 168.75° |
| 6 | 25 ~ 50 | 168.75° ~ 202.5° |
| 7 | 50 ~ 100 | 202.5° ~ 236.25° |
| 8 | 100 ~ 200 | 236.25° ~ 270° |

## 配置说明

### 测速服务器
应用默认使用 Cloudflare Speed Test API：
- 下载测试: `https://speed.cloudflare.com/__down`
- 上传测试: `https://speed.cloudflare.com/__up`
- Ping 测试: `https://speed.cloudflare.com/__down?bytes=0`

可在 `lib/core/constants/app_constants.dart` 中修改 `downloadTestUrl`、`uploadTestUrl`、`pingTestUrl`。

### 测试参数
可在 `lib/core/constants/app_constants.dart` 中调整：
- `downloadTestDurationSeconds` - 下载测试时长（默认10秒）
- `uploadTestDurationSeconds` - 上传测试时长（默认10秒）
- `measurementIntervalMs` - 测量间隔（默认200ms）

## 依赖版本

| 依赖 | 版本 | 用途 |
|------|------|------|
| provider | ^6.1.2 | 状态管理 |
| http | ^1.2.2 | 网络请求 |
| sqflite | ^2.3.3 | SQLite 数据库 |
| path_provider | ^2.1.4 | 文件路径获取 |
| shared_preferences | ^2.2.3 | 轻量级持久化 |
| intl | ^0.19.0 | 国际化 |
| package_info_plus | ^8.0.2 | 应用信息 |
| permission_handler | ^11.3.1 | 权限管理 |
| connectivity_plus | ^6.0.0 | 网络连接状态 |
| network_info_plus | ^6.0.0 | WiFi 信息获取 |

## 许可证

本项目基于 MIT 许可证开源。

## 致谢

- [Cloudflare Speed Test API](https://speed.cloudflare.com/) - 提供测速服务
- [Flutter](https://flutter.dev/) - 跨平台 UI 框架
