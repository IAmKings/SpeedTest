# 组件清单

## UI 组件总览

本项目包含以下 UI 组件，按功能分类：

## 页面 (Views)

### HomePage
- **文件：** `lib/features/speed_test/presentation/views/home_page.dart`
- **路由：** `/` (根路由)
- **描述：** 应用首页，包含测速仪表盘、开始按钮、历史记录展示
- **状态依赖：** `SpeedTestViewModel`, `HistoryViewModel`, `UnitProvider`

**主要区域：**
1. 脉冲开始按钮 (`_PulsingStartButton`)
2. 结果行 (`_ResultRow`) - 显示 Ping/下载/上传
3. 仪表盘 (`SpeedGauge`)
4. 状态文本和进度条
5. 历史记录区域 (`_HistorySection`)

### SettingsPage
- **文件：** `lib/features/speed_test/presentation/views/settings_page.dart`
- **路由：** 通过 `Navigator.push` 跳转
- **描述：** 设置页面，包含语言、单位、主题、版本检测设置
- **状态依赖：** `ThemeProvider`, `LocaleProvider`, `UnitProvider`

**设置项：**
- 语言切换
- 速度单位切换 (Mbps/MB/s)
- 主题切换 (浅色/深色/系统)
- 测试服务器显示
- 版本检测
- 关于信息

---

## 基础组件 (Widgets)

### SpeedGauge
- **文件：** `lib/features/speed_test/presentation/widgets/speed_gauge.dart`
- **类型：** StatefulWidget
- **描述：** 270度弧形仪表盘，带指针动画

**参数：**
| 参数 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `speed` | `double` | 必填 | 当前速度值 |
| `label` | `String` | 必填 | 仪表盘标签 |
| `unit` | `String` | 必填 | 显示单位 |
| `isMbps` | `bool` | `true` | 是否使用 Mbps 刻度 |

**刻度配置：**
- Mbps 模式：`[0, 5, 10, 50, 100, 250, 500, 1000, 2000]`
- MB/s 模式：`[0, 1, 2, 5, 10, 25, 50, 100, 200]`

### HistoryTile
- **文件：** `lib/features/speed_test/presentation/widgets/history_tile.dart`
- **类型：** StatelessWidget
- **描述：** 历史测速结果列表项卡片

**参数：**
| 参数 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `result` | `SpeedResult` | 必填 | 测速结果数据 |
| `downloadLabel` | `String` | `'Download'` | 下载标签 |
| `uploadLabel` | `String` | `'Upload'` | 上传标签 |
| `pingLabel` | `String` | `'Ping'` | Ping 标签 |
| `mbpsUnit` | `String` | `'Mbps'` | Mbps 单位 |
| `mbsUnit` | `String` | `'MB/s'` | MB/s 单位 |
| `msUnit` | `String` | `'ms'` | 毫秒单位 |
| `isMbps` | `bool` | `true` | 是否使用 Mbps 单位 |

**显示内容：**
- 日期和时间
- 下载速度（带颜色标识）
- 上传速度（带颜色标识）
- Ping 值（带颜色标识）

### PingIndicator
- **文件：** `lib/features/speed_test/presentation/widgets/ping_indicator.dart`
- **类型：** StatelessWidget
- **描述：** 延迟指示器，带动态动画点

**参数：**
| 参数 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `ping` | `double` | 必填 | Ping 值 |
| `isActive` | `bool` | `false` | 是否处于活跃状态 |
| `pingLabel` | `String` | `'Ping'` | 标签文本 |
| `unit` | `String` | `'ms'` | 单位文本 |

### VersionCheckDialog
- **文件：** `lib/features/speed_test/presentation/widgets/version_check_dialog.dart`
- **类型：** StatelessWidget (Dialog)
- **描述：** 版本检测结果对话框

**参数：**
| 参数 | 类型 | 描述 |
|------|------|------|
| `versionInfo` | `VersionInfo` | 版本信息 |
| `onUpdate` | `VoidCallback` | 更新按钮回调 |
| `onSkip` | `VoidCallback` | 跳过按钮回调 |
| `onLater` | `VoidCallback` | 稍后按钮回调 |

### DownloadProgressDialog
- **文件：** `lib/features/speed_test/presentation/widgets/download_progress_dialog.dart`
- **类型：** StatelessWidget (Dialog)
- **描述：** APK 下载进度对话框

**参数：**
| 参数 | 类型 | 描述 |
|------|------|------|
| `progress` | `int` | 下载进度 (0-100) |

---

## 首页内部组件

### _PulsingStartButton
- **文件：** `lib/features/speed_test/presentation/views/home_page.dart`
- **类型：** StatefulWidget
- **描述：** 脉冲动画开始按钮

**特性：**
- 缩放动画 (0.92 ~ 1.05)
- 透明度动画 (0.7 ~ 1.0)
- 自适应颜色（深色模式白色，浅色模式主题色）
- 外发光效果

### _ResultRow
- **文件：** `lib/features/speed_test/presentation/views/home_page.dart`
- **类型：** StatelessWidget
- **描述：** 测速结果行，同时显示 Ping/下载/上传

**颜色标识：**
| 指标 | 颜色 | 色值 |
|------|------|------|
| Ping | 紫色 | `#A855F7` |
| 下载 | 蓝色 | `#2563EB` |
| 上传 | 绿色 | `#22C55E` |

### _ResultColumn
- **文件：** `lib/features/speed_test/presentation/views/home_page.dart`
- **类型：** StatelessWidget
- **描述：** 单列结果展示（标签+数值+单位）

### _AnimatedDots
- **文件：** `lib/features/speed_test/presentation/views/home_page.dart`
- **类型：** StatefulWidget
- **描述：** 动态动画点（测速中显示）

### _HistorySection
- **文件：** `lib/features/speed_test/presentation/views/home_page.dart`
- **类型：** StatelessWidget
- **描述：** 历史记录区域（底部抽屉）

### _HistorySheet
- **文件：** `lib/features/speed_test/presentation/views/home_page.dart`
- **类型：** StatelessWidget
- **描述：** 完整历史记录列表底部抽屉

---

## 内部组件 (非公开)

### _GaugePainter
- **文件：** `lib/features/speed_test/presentation/widgets/speed_gauge.dart`
- **类型：** CustomPainter
- **描述：** 仪表盘绘制器

### _SpeedColumn
- **文件：** `lib/features/speed_test/presentation/widgets/history_tile.dart`
- **类型：** StatelessWidget
- **描述：** 历史记录单列

### _SelectorBottomSheet
- **文件：** `lib/features/speed_test/presentation/views/settings_page.dart`
- **类型：** StatelessWidget
- **描述：** 通用的底部选择器

### _SettingsTile
- **文件：** `lib/features/speed_test/presentation/views/settings_page.dart`
- **类型：** StatelessWidget
- **描述：** 设置列表项

### _AboutDialog
- **文件：** `lib/features/speed_test/presentation/views/settings_page.dart`
- **类型：** StatelessWidget
- **描述：** 关于对话框

### _DownloadProgressNotifier
- **文件：** `lib/features/speed_test/presentation/views/settings_page.dart`
- **类型：** ChangeNotifier
- **描述：** 下载进度通知器

---

## 颜色主题

### 指标专属颜色
| 名称 | 颜色 | 用途 |
|------|------|------|
| `downloadColor` | `#2563EB` | 下载速度 |
| `uploadColor` | `#22C55E` | 上传速度 |
| `pingColor` | `#A855F7` | Ping 延迟 |

### 速度质量颜色
| 名称 | 颜色 | 速度范围 |
|------|------|----------|
| `speedExcellent` | `#22C55E` | ≥100 Mbps |
| `speedGood` | `#84CC16` | 50-100 Mbps |
| `speedFair` | `#FACC15` | 25-50 Mbps |
| `speedPoor` | `#F97316` | 10-25 Mbps |
| `speedVeryPoor` | `#EF4444` | <10 Mbps |

---

## 第三方组件依赖

| 组件 | 版本 | 用途 |
|------|------|------|
| `provider` | ^6.1.2 | 状态管理 |
| `http` | ^1.2.2 | 网络请求 |
| `sqflite` | ^2.3.3 | SQLite 数据库 |
| `shared_preferences` | ^2.2.3 | 偏好设置存储 |
| `intl` | ^0.19.0 | 国际化 |
| `package_info_plus` | ^8.0.2 | 应用信息 |
| `permission_handler` | ^11.3.1 | 权限处理 |
| `android_intent_plus` | ^5.0.0 | Android Intent |
