# SmartClass — Agent 指南

## UI 改动后必须刷新

凡修改 `lib/screens/`、`lib/widgets/`、`lib/providers/`、`lib/theme/` 等界面相关代码，**必须**遵循：

`.cursor/skills/flutter-ui-verify/SKILL.md`

要点：

1. 改完后跑 `dart analyze`
2. 确认应用已热重启（不是仅热重载）
3. 回复用户时说明刷新状态

## 推荐本地开发启动

**真机 USB 调试（推荐测 bug）：**

```powershell
powershell -ExecutionPolicy Bypass -File scripts/dev-run-phone.ps1
```

**电脑模拟器（方便截图）：**

```powershell
powershell -ExecutionPolicy Bypass -File scripts/dev-run-emulator.ps1
```

**真机 + 模拟器同时开：**

```powershell
powershell -ExecutionPolicy Bypass -File scripts/dev-run-dual.ps1
```

## 改 UI 后快速检查

```powershell
powershell -ExecutionPolicy Bypass -File scripts/flutter-ui-refresh.ps1
```
