# 架构文档

## 架构概览

### 架构模式

本项目采用 **MVVM (Model-View-ViewModel)** 架构模式，结合 **Provider** 进行状态管理。

```
┌─────────────────────────────────────────────────────────────┐
│                         View Layer                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │   HomePage      │  │  SettingsPage   │  │  Widgets   │ │
│  └────────┬────────┘  └────────┬────────┘  └──────┬──────┘ │
└───────────┼────────────────────┼─────────────────┼─────────┘
            │                    │                 │
            ▼                    ▼                 ▼
┌─────────────────────────────────────────────────────────────┐
│                     ViewModel Layer                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │SpeedTestViewModel│ │HistoryViewModel │  │ Providers   │ │
│  └────────┬────────┘  └────────┬────────┘  └──────┬──────┘ │
└───────────┼────────────────────┼─────────────────┼─────────┘
            │                    │
            ▼                    ▼
┌─────────────────────────────────────────────────────────────┐
│                       Data Layer                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │SpeedTestService │  │HistoryRepository│  │SharedPrefs │ │
│  └────────┬────────┘  └────────┬────────┘  └──────┬──────┘ │
└───────────┼────────────────────┼─────────────────┼─────────┘
            │                    │
            ▼                    ▼
┌─────────────────────────────────────────────────────────────┐
│                    External Services                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │Cloudflare API   │  │   SQLite DB     │  │GitHub API   │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## 核心组件

### 1. View 层

#### HomePage
- **职责：** 应用主页面，展示测速仪表盘和历史记录
- **状态依赖：** `SpeedTestViewModel`, `HistoryViewModel`, `UnitProvider`
- **关键逻辑：**
  - 测速状态机监听
  - 结果颜色应用
  - 单位转换显示

#### SettingsPage
- **职责：** 应用设置页面
- **状态依赖：** `ThemeProvider`, `LocaleProvider`, `UnitProvider`
- **关键逻辑：**
  - 版本检测
  - 设置项持久化

### 2. ViewModel 层

#### SpeedTestViewModel
- **职责：** 管理测速状态机
- **状态：**
  ```dart
  enum TestState { idle, testingPing, testingDownload, testingUpload, completed, error }
  ```
- **关键方法：**
  - `startTest()` - 开始完整测速流程
  - `stopTest()` - 停止当前测速

#### HistoryViewModel
- **职责：** 管理历史记录列表
- **关键方法：**
  - `loadHistory()` - 加载历史记录
  - `deleteResult(id)` - 删除单条记录
  - `clearAllHistory()` - 清空所有记录

#### ThemeProvider
- **职责：** 管理主题模式
- **状态：** `AppThemeMode.system | light | dark`

#### LocaleProvider
- **职责：** 管理语言设置
- **状态：** `AppLocale.system | english | simplifiedChinese | traditionalChinese`

#### UnitProvider
- **职责：** 管理速度单位
- **状态：** `SpeedUnit.mbps | mbs`
- **关键方法：**
  - `convertSpeed(mbps)` - 速度单位转换

### 3. Data 层

#### SpeedTestService
- **职责：** 与 Cloudflare Speed Test API 交互
- **关键方法：**
  - `measurePing()` - 测量延迟
  - `runDownloadTest()` - 返回下载速度 Stream
  - `runUploadTest()` - 返回上传速度 Stream

#### HistoryRepository
- **职责：** SQLite 数据库操作
- **关键方法：**
  - `insertResult()` - 保存测速结果
  - `getAllResults()` - 获取所有历史
  - `getLatestResult()` - 获取最新结果
  - `deleteResult()` - 删除记录
  - `clearAll()` - 清空所有
  - `getAverages()` - 获取平均值

#### VersionService
- **职责：** GitHub Releases 版本检测
- **关键方法：**
  - `checkLatestVersion()` - 检查最新版本
  - `downloadApk()` - 下载 APK
  - `installApk()` - 安装 APK

## 数据模型

### SpeedResult
```dart
class SpeedResult {
  final int? id;
  final DateTime timestamp;
  final double downloadSpeed; // Mbps
  final double uploadSpeed;   // Mbps
  final double ping;          // ms
  final String? serverInfo;
}
```

### VersionInfo
```dart
class VersionInfo {
  final String version;
  final String downloadUrl;
  final String releaseNotes;
  final String tagName;
}
```

## 状态流

### 测速状态机

```
                    ┌─────────┐
                    │  idle   │
                    └────┬────┘
                         │ startTest()
                         ▼
              ┌──────────────────────┐
              │    testingPing       │
              └──────────┬───────────┘
                         │ 完成
                         ▼
              ┌──────────────────────┐
              │   testingDownload    │◄────────┐
              └──────────┬───────────┘         │
                         │ 完成                 │ stopTest()
                         ▼                     │
              ┌──────────────────────┐         │
              │    testingUpload      │─────────┘
              └──────────┬───────────┘
                         │ 完成
                         ▼
              ┌──────────────────────┐
         ┌───►│     completed        │───┐
         │    └──────────────────────┘   │
         │                                  │ startTest()
         │    ┌──────────────────────┐   │
         └────│       error           │───┘
              └──────────────────────┘
```

### 测速完成后的数据流

```
SpeedTestViewModel.startTest() 完成
         │
         ▼
saveResult() ──► HistoryRepository.insertResult()
         │
         ▼
notifyListeners() ──► HomePage 重建 UI
         │
         ▼
HistoryViewModel 刷新历史记录
```

## Provider 依赖关系

```
┌─────────────────────────────────────────────────────────────┐
│                      Provider Layer                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   SpeedTestService (无依赖)                                  │
│         │                                                    │
│         ▼                                                    │
│   HistoryRepository (依赖 SpeedTestService)                    │
│         │                                                    │
│         ├──────────────────────┐                             │
│         ▼                      ▼                             │
│   SpeedTestViewModel    HistoryViewModel                     │
│         │                      │                             │
│         └──────────────────────┘                             │
│                      │                                       │
│                      ▼                                       │
│              ThemeProvider                                  │
│              LocaleProvider                                  │
│              UnitProvider                                   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## 数据库 Schema

### speed_results 表

| 列名 | 类型 | 约束 |
|------|------|------|
| `id` | INTEGER | PRIMARY KEY AUTOINCREMENT |
| `timestamp` | INTEGER | NOT NULL |
| `download_speed` | REAL | NOT NULL |
| `upload_speed` | REAL | NOT NULL |
| `ping` | REAL | NOT NULL |
| `server_info` | TEXT | NULLABLE |

## API 集成

### Cloudflare Speed Test API

```dart
// 配置
static const String downloadTestUrl = 'https://speed.cloudflare.com/__down?bytes=10000000';
static const String uploadTestUrl = 'https://speed.cloudflare.com/__up';
static const String pingTestUrl = 'https://speed.cloudflare.com/__down?bytes=0';

// 配置参数
static const int downloadTestDurationSeconds = 10;
static const int uploadTestDurationSeconds = 10;
static const int pingTestCount = 5;
static const int measurementIntervalMs = 200;
```

### GitHub Releases API

```dart
// 检查最新版本
GET https://api.github.com/repos/IAmKings/SpeedTest/releases/latest

// 响应解析
{
  "tag_name": "v1.0.5",
  "body": "release notes",
  "assets": [{ "browser_download_url": "*.apk" }]
}
```

## 模块化设计

本项目采用 **特性模块化 (Feature-based)** 组织方式：

```
lib/features/
└── speed_test/              # 测速功能模块（唯一模块）
    ├── data/               # 数据层封装
    │   ├── models/         # 数据模型
    │   ├── repositories/    # 数据仓库（数据访问）
    │   └── services/       # 外部服务（API 调用）
    │
    └── presentation/        # 展示层封装
        ├── viewmodels/     # 状态管理
        ├── views/          # 页面
        └── widgets/        # UI 组件
```

**优势：**
- 易于隔离和测试
- 便于功能扩展
- 清晰的职责分离

## 国际化架构

```
┌─────────────────────────────────────────┐
│            LocaleProvider               │
│         (AppLocale 状态管理)              │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│         AppLocalizations                │
│    (flutter gen-l10n 自动生成)          │
└─────────────────┬───────────────────────┘
                  │
        ┌─────────┴─────────┐
        ▼         ▼         ▼
    app_en.arb  app_zh.arb  app_zh_TW.arb
```

## 主题架构

```dart
MaterialApp(
  theme: AppTheme.lightTheme,    // 浅色主题
  darkTheme: AppTheme.darkTheme,  // 深色主题
  themeMode: themeProvider.flutterThemeMode,
)
```

**颜色配置：**
- Primary Seed: `#2563EB` (蓝色)
- 指标颜色: 下载(蓝)、上传(绿)、Ping(紫)
