---
name: flutter-ui-verify
description: >-
  Mandatory after any SmartClass Flutter UI/screen/widget/state change: analyze,
  ensure Provider refresh, and verify the running app hot-restarts so the user
  sees updates. Use when editing lib/screens, lib/widgets, lib/providers,
  lib/theme, or when the user says 页面没更新, 没刷新, hot reload, 热重载,
  UI not updating, or asks to verify UI changes.
---

# SmartClass：UI 改动后必须刷新页面

## 硬性要求（每次改 UI 相关代码后、回复用户前）

只要本轮改动涉及以下路径，**不得**在未完成刷新流程前宣称「已完成」：

- `lib/screens/**`
- `lib/widgets/**`
- `lib/providers/**`
- `lib/theme/**`
- `lib/app.dart`

## 标准流程

```
1. dart analyze（仅分析本轮改动的文件）
2. 检查开发进程是否在跑（见下方）
3. 触发或确认热重启
4. 在最终回复中说明刷新结果（一行即可）
```

### 1. 静态检查

```powershell
cd E:\SmartClass\SmartClass
$env:FLUTTER_ROOT='E:\dev\flutter'
$env:PATH='E:\dev\flutter\bin;' + $env:PATH
dart analyze <改动的 dart 文件>
```

有 error 必须先修，再谈刷新。

### 2. 开发进程检查（按优先级）

| 方式 | 如何识别 | Agent 怎么做 |
|------|----------|--------------|
| **推荐** `scripts/dev-run.ps1` | 终端输出含 `[SmartClass] Watching lib/` | 保存文件后 watcher 会自动按 `R` 热重启；等 2–3 秒后在回复里写「已触发热重启」 |
| 普通 `flutter run` | 某终端在跑 flutter，显示 `Flutter run key commands` | 提醒用户在该终端按 **`R`**（热重启，不是 `r`） |
| Android Studio Run | 无 flutter 终端 | 提醒用户点 IDE 的 **Hot Restart**（⚡带弯箭头），或改用 `scripts/dev-run.ps1` |

**UI 结构改动**（新 Widget、改 layout、改 AppBar/actions、删 FAB 等）→ 必须 **热重启 `R`**，仅热重载 `r` 常常看不出变化。

**Provider / 模型 / 数据库逻辑** → 除热重启外，确认 `notifyListeners()` 或 `context.watch` 已接上。

### 3. 若应用未在跑

真机 USB（推荐测 bug）：

```powershell
cd E:\SmartClass\SmartClass
powershell -ExecutionPolicy Bypass -File scripts/dev-run-phone.ps1
```

模拟器 / 自动选设备：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/dev-run.ps1
```

设备/模拟器需已连接。真机首次需在手机上点「允许 USB 调试」。启动后告知用户：之后改 `lib/` 会自动热重启到手机。

### 4. 常见「页面没更新」原因

| 现象 | 处理 |
|------|------|
| 改了 Widget 结构但只按了 `r` | 改按 **`R`** 或重启 dev-run |
| 数据变了 UI 不变 | 查 `notifyListeners()`、`context.watch` vs `read` |
| 还在看旧路由/旧 Tab | 退出页面再进入，或热重启 |
| 用 Android Studio 跑且未热重启 | 换 `dev-run.ps1` 或 IDE Hot Restart |
| 改了 assets / pubspec | 必须完全停止再 `flutter run` |

## 代码审查清单（改 UI 时顺带看）

```
- [ ] 展示数据来自 watch 而非只 read 一次
- [ ] 写操作后 controller 调用了 notifyListeners 或重新 load
- [ ] 无仅依赖 hot reload 才能生效的全局/静态缓存
- [ ] 删除的 UI 元素在代码里已无引用
```

## 禁止

- 不得假设「保存即生效」而不说明是否需要热重启
- 不得跳过 analyze 直接说「刷新好了」
- 不得在未验证的情况下让用户自己猜要不要重启

## 回复模板

成功（dev-run 在跑）：

> 已 analyze 通过；dev-run 监视器会自动热重启，约 2 秒后界面应已更新。

需用户操作：

> 代码已改并通过 analyze。请在 flutter 终端按 **R** 热重启（或 IDE 点 Hot Restart），UI 结构改动必须热重启才能看到效果。

未启动应用：

> 已启动 `scripts/dev-run.ps1`（需模拟器/真机已连接）。首次编译约 3–5 分钟，之后保存 `lib/` 会自动热重启。
