# 源码树分析

## 项目结构总览

```
SpeedTest/
├── speed_test_app/                    # Flutter 应用主目录
│   ├── android/                      # Android 平台代码
│   ├── ios/                          # iOS 平台代码
│   ├── lib/                          # Dart 源代码
│   ├── test/                         # 测试代码
│   ├── assets/                       # 静态资源
│   ├── pubspec.yaml                  # 依赖配置
│   └── README.md                     # 项目文档
│
├── docs/                             # 项目文档目录
│
└── .github/                          # GitHub 配置
    └── workflows/                    # GitHub Actions 工作流
```

## lib/ 目录结构详解

```
lib/
├── app/                              # [核心] 应用配置和状态管理
│   ├── app.dart                      # ⭐ MultiProvider 入口点
│   ├── theme.dart                    # Material 3 主题定义
│   ├── theme_provider.dart            # 主题状态 (light/dark/system)
│   ├── locale_provider.dart           # 语言状态 (en/zh/zh_TW)
│   └── unit_provider.dart             # 单位状态 (Mbps/MB/s)
│
├── core/                              # [核心] 公共工具
│   ├── constants/
│   │   └── app_constants.dart        # 常量定义 (API URL, 时间配置)
│   └── utils/
│       └── speed_rating.dart         # 速度评级工具函数
│
├── features/                         # [功能模块] 按特性组织
│   └── speed_test/                   # 测速功能模块
│       ├── data/                      # ┬─ 数据层
│       │   ├── models/               # │   数据模型
│       │   ├── repositories/         # │   数据仓库
│       │   └── services/             # │   外部服务
│       │
│       └── presentation/              # ├─ 展示层
│           ├── viewmodels/           # │   状态管理
│           ├── views/                # │   页面
│           └── widgets/               # │   组件
│
├── l10n/                             # [国际化] ARB 资源文件
│   ├── app_en.arb
│   ├── app_zh.arb
│   └── app_zh_TW.arb
│
└── main.dart                         # ⭐ 应用入口点
```

## 关键目录说明

### app/ - 应用核心配置

| 文件 | 用途 | 入口点 |
|------|------|--------|
| `app.dart` | MultiProvider 配置，聚合所有状态 | 应用启动时加载 |
| `theme.dart` | Material 3 主题定义（颜色、Typography） | 全局引用 |
| `theme_provider.dart` | ThemeMode 状态管理 | Consumer/Provider |
| `locale_provider.dart` | Locale 状态管理 | Consumer/Provider |
| `unit_provider.dart` | SpeedUnit 状态管理 | Consumer/Provider |

### features/speed_test/data/ - 数据层

| 文件 | 用途 |
|------|------|
| `models/speed_result.dart` | 测速结果数据模型 (id, timestamp, downloadSpeed, uploadSpeed, ping) |
| `repositories/history_repository.dart` | SQLite 数据仓库 (CRUD 操作) |
| `services/speed_test_service.dart` | Cloudflare API 测速服务 |
| `services/version_service.dart` | GitHub Releases 版本检测服务 |

### features/speed_test/presentation/ - 展示层

#### ViewModels (状态管理)
| 文件 | 用途 |
|------|------|
| `speed_test_viewmodel.dart` | 测速状态机 (idle→ping→download→upload→completed) |
| `history_viewmodel.dart` | 历史记录列表管理 |

#### Views (页面)
| 文件 | 路由 | 用途 |
|------|------|------|
| `home_page.dart` | / | 首页，包含仪表盘、测速按钮、历史记录 |
| `settings_page.dart` | /settings | 设置页面（主题、语言、单位、版本检测） |

#### Widgets (组件)
| 文件 | 用途 |
|------|------|
| `speed_gauge.dart` | 270度弧形仪表盘，自定义绘制，指针动画 |
| `history_tile.dart` | 历史记录列表项卡片 |
| `ping_indicator.dart` | 延迟指示器（带动画点） |
| `version_check_dialog.dart` | 版本检测对话框 |
| `download_progress_dialog.dart` | 下载进度对话框 |

## 入口点分析

### main.dart
```dart
void main() {
  runApp(const SpeedTestApp());
}
```
- 简单入口，调用 `SpeedTestApp`

### app.dart
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ChangeNotifierProvider(create: (_) => LocaleProvider()),
    ChangeNotifierProvider(create: (_) => UnitProvider()),
    Provider<SpeedTestService>(...),
    ProxyProvider<SpeedTestService, HistoryRepository>(...),
    ChangeNotifierProxyProvider<HistoryRepository, SpeedTestViewModel>(...),
    ChangeNotifierProxyProvider<HistoryRepository, HistoryViewModel>(...),
  ],
  child: MaterialApp(home: HomePage()),
)
```

**依赖关系：**
```
SpeedTestService
    ↓
HistoryRepository ← SpeedTestService
    ↓
SpeedTestViewModel ← HistoryRepository
HistoryViewModel ← HistoryRepository
```

## 关键集成点

### 测速流程
```
HomePage → SpeedTestViewModel.startTest()
    → SpeedTestService.measurePing()
    → SpeedTestService.runDownloadTest() (Stream)
    → SpeedTestService.runUploadTest() (Stream)
    → HistoryRepository.insertResult()
    → HistoryViewModel.loadHistory()
```

### 单位转换
```
UnitProvider.unit (SpeedUnit.mbps 或 SpeedUnit.mbs)
    ↓
HomePage._getSpeedForCurrentPhase() → displayValue
    ↓
SpeedGauge(speed: displayValue)
HistoryTile(isMbps: unitProvider.isMbps)
```

### 主题切换
```
ThemeProvider.themeMode (AppThemeMode.system/light/dark)
    ↓
MaterialApp(themeMode: themeProvider.flutterThemeMode)
    ↓
AppTheme.lightTheme / darkTheme
```

## 关键文件位置速查

| 功能 | 文件路径 |
|------|----------|
| **入口** | `lib/main.dart` |
| **状态配置** | `lib/app/app.dart` |
| **主题** | `lib/app/theme.dart` |
| **测速服务** | `lib/features/speed_test/data/services/speed_test_service.dart` |
| **历史存储** | `lib/features/speed_test/data/repositories/history_repository.dart` |
| **测速状态** | `lib/features/speed_test/presentation/viewmodels/speed_test_viewmodel.dart` |
| **首页 UI** | `lib/features/speed_test/presentation/views/home_page.dart` |
| **仪表盘** | `lib/features/speed_test/presentation/widgets/speed_gauge.dart` |
| **设置页** | `lib/features/speed_test/presentation/views/settings_page.dart` |
| **国际化** | `lib/l10n/app_zh.arb` (中文) |
