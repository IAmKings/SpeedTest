# Speed Test App

一款使用 Flutter 构建的网速测试应用，支持实时测速、测速历史记录、多语言切换和主题切换。

![Version](https://img.shields.io/badge/version-2.2.0-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.27.1-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## 功能特性

### 核心功能
- **网速测试** - 支持下载速度、上传速度和网络延迟测试
- **实时动画仪表盘** - 270度弧形仪表盘，指针平滑动画
- **智能刻度** - 根据单位（Mbps/MB/s）自动切换刻度范围
- **测速历史** - 本地 SQLite 数据库存储历史记录
- **数据统计** - 显示最近10次测试的平均值
- **多线程并行测速** - 3-8 个并发连接，提升测速准确性
- **Ping 去极值平均** - 5次测量去掉最大最小值取平均，减少波动

### 用户体验
- **多语言支持** - 英文、简体中文、繁体中文
- **主题切换** - 浅色模式、深色模式、跟随系统
- **单位切换** - Mbps（兆比特）和 MB/s（兆字节）一键切换
- **并发连接配置** - 可在设置中调整 1-8 个并发连接数
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
│   └── unit_provider.dart        # 单位状态管理
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
│       │       └── speed_test_service.dart # 测速服务（API调用）
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
│               └── history_tile.dart         # 历史记录条目
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
- `warmupDurationMs` - 预热阶段时长（默认1500ms），排除 TCP 慢启动影响
- `parallelConnections` - 并发连接数（默认3），可在设置中调整 1-8

## 测速流程详解

### 测试阶段概述

```
┌─────────────────────────────────────────────────────────────┐
│                    完整测速流程                               │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. Ping 测试 (testingPing)                                 │
│     ├─ 5 次 HEAD 请求去极值取平均                            │
│     ├─ 计算 jitter (方差)                                    │
│     └─ 异常处理：失败返回 ping=-1                            │
│                                                              │
│  2. 下载测试 (testingDownload)                              │
│     ├─ 1.5s 预热：多线程下载建立 TCP 连接                    │
│     ├─ 10s 测量：Timer 200ms 固定采样                       │
│     ├─ ChunkSizeEstimator 动态调整 chunk 大小                │
│     ├─ EMA 平滑速度显示 (α=0.2)                            │
│     └─ 资源清理：cancel + HttpClient.close                  │
│                                                              │
│  3. 上传测试 (testingUpload)                               │
│     ├─ 1.5s 预热：数据不计入测量                            │
│     ├─ 10s 测量：Timer 200ms 固定采样                       │
│     ├─ 多线程并发上传                                        │
│     └─ 资源清理：同上                                        │
│                                                              │
│  4. 完成 (completed)                                        │
│     ├─ 保存 SpeedResult 到 SQLite                           │
│     ├─ 记录网络类型、WiFi 名称、信号强度                    │
│     └─ 通知监听器更新 UI                                    │
└─────────────────────────────────────────────────────────────┘
```

### 1. Ping 测试

```
measurePing() → 5 次 HEAD 请求
    │
    ├─ 每次请求超时 10s
    ├─ 请求间隔 100ms
    └─ persistentConnection = true (keep-alive)

结果处理：
    │
    ├─ 排序测量值
    ├─ 去极值（最大+最小）
    ├─ 取剩余值平均作为 ping
    └─ 计算方差作为 jitter
```

### 2. 测试流程通用模式

下载与上传测试均采用 **Timer 200ms 固定采样** 模式：

```
runTestParallel() → 多线程并行
    │
    ├─ 启动 Timer 200ms 固定采样
    ├─ 多线程（默认 3）并发
    │
    ├─ 1.5s 预热阶段：
    │   └─ 下载/上传进行中，不计算速度
    │
    ├─ 10s 测量阶段：
    │   ├─ Timer 每 200ms 计算：speed = (totalBytes * 8) / elapsed / 1e6
    │   ├─ EMA 平滑：V = 0.2 × V_new + 0.8 × V_old
    │   └─ yield 到 ViewModel 更新 UI
    │
    └─ 10s 到或 _isTestRunning=false 时：
        ├─ timer.cancel()
        ├─ subscriptions.cancel()
        ├─ controllers.close()
        └─ HttpClient.close(force: true)
```

**下载与上传差异：**

| 差异项 | 下载 | 上传 |
|--------|------|------|
| 估算器 | `ChunkSizeEstimator` 动态调整 | 使用固定 chunk 大小 |
| 数据生成 | 服务器返回 | `Random().nextInt(256)` 生成 |

### 3. ChunkSizeEstimator 动态调整

```dart
// 根据当前网速动态调整下一次请求的 chunk 大小
// 公式：chunkSize = speedMbps × 0.5s × 125000

// 约束范围
_minChunkSize = 500KB
_maxChunkSize = 10MB
_defaultChunkSize = 2MB
_targetDuration = 500ms  // 目标每次下载耗时
```

### 4. 网络状态监测

```
SpeedTestViewModel.startTest()
    │
    ├─ 记录测试开始时的网络信息
    ├─ 启动信号轮询
    │
    └─ 测试过程中监测网络变化：
        ├─ 网络类型改变 → 抛出 NETWORK_CHANGED
        └─ WiFi 名称改变 → 抛出 NETWORK_CHANGED
```

### 5. 测试参数配置

| 参数 | 默认值 | 说明 |
|------|--------|------|
| pingTestCount | 5 | Ping 测量次数 |
| warmupDurationMs | 1500 | 预热阶段时长 |
| downloadTestDurationSeconds | 10 | 下载测量时长 |
| uploadTestDurationSeconds | 10 | 上传测量时长 |
| measurementIntervalMs | 200 | Timer 采样间隔 |
| parallelConnections | 3 | 并发连接数 |

### 6. 关键文件

| 文件 | 职责 |
|------|------|
| `speed_test_service.dart` | 核心测速逻辑 |
| `speed_test_viewmodel.dart` | 状态管理、进度控制 |
| `app_constants.dart` | 测速参数配置 |

---

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

## 许可证

本项目基于 MIT 许可证开源。

## 致谢

- [Cloudflare Speed Test API](https://speed.cloudflare.com/) - 提供测速服务
- [Flutter](https://flutter.dev/) - 跨平台 UI 框架
