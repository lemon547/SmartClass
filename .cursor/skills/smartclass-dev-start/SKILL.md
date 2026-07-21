---
name: smartclass-dev-start
description: >-
  Starts SmartClass on both USB phone and PC Android emulator via
  scripts/dev-run-dual.ps1. Use when the user says 启动, 启动项目, 启动模拟器和手机,
  start, run dual, 开真机和模拟器, or asks to bring up local Flutter dev on phone + emulator.
---

# SmartClass：启动真机 + 模拟器

用户说「启动」时，默认同时开 **USB 真机** 和 **电脑模拟器**，不要只开其中一个。

## 标准命令（必须执行）

```powershell
cd E:\SmartClass\SmartClass
powershell -ExecutionPolicy Bypass -File scripts/dev-run-dual.ps1
```

该脚本会弹出两个独立 PowerShell 窗口：

1. `dev-run-phone.ps1` — 真机 USB（测 bug）
2. `dev-run-emulator.ps1` — 电脑模拟器（截图）

保存 `lib/*.dart` 后两侧都会自动热重启。

## Agent 流程

1. 先看 terminals：若 dual / phone / emulator 已在跑且输出正常，告知「已在跑」，不必重复启动。
2. 未在跑则执行上面的 dual 命令（`block_until_ms` 可较短，脚本会立刻拉起两个窗口后退出）。
3. 回复用户：已启动双端窗口；首次编译约 3–5 分钟；真机需已 USB 连接并允许调试。

## 仅开一端时（用户明确指定才用）

| 用户意图 | 脚本 |
|----------|------|
| 只要真机 | `scripts/dev-run-phone.ps1` |
| 只要模拟器 | `scripts/dev-run-emulator.ps1` |
| 自动选设备 | `scripts/dev-run.ps1` |

未指定时一律用 **dual**。

## 禁止

- 不要用 LIMEN / Docker / Vite 等其它项目的启动方式
- 不要部署或连生产环境
- 不要在用户只说「启动」时只开模拟器或只开真机
