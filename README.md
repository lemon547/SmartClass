# SmartClass 班主任助手

跨平台 Flutter 应用（**Android 先交付，iOS 工程已预留**）。数据本地存储，无需登录。

## 功能

- 学生花名册（增删改、家长电话、备注）
- 随机点名（动画抽选、避免重复）
- 积分评价（加减分、快捷理由、排行榜）
- 今日考勤（出勤 / 迟到 / 请假 / 缺勤）
- 值日安排、座位表
- 演示数据一键填充

## 本机工具链（全部在 E 盘）

| 组件 | 路径 |
|------|------|
| Flutter | `E:\dev\flutter` |
| Android SDK | `E:\dev\android-sdk` |
| Pub 缓存 | `E:\dev\pub-cache` |
| Gradle 缓存 | `E:\dev\gradle` |
| 项目 | `E:\SmartClass\SmartClass` |

新开终端先加载环境（或重开 Cursor）：

```powershell
. E:\dev\env.ps1
```

Windows 需开启 **开发人员模式**（插件符号链接）：设置 → 系统 → 开发者选项。

## 运行（Android — 正规开发方式）

**专用软件：Android Studio**（已安装）  
路径：`C:\Program Files\Android\Android Studio\bin\studio64.exe`

### 推荐流程（日常开发）

1. 双击 **`scripts\start-android.bat`** → 选 **1** 用 Android Studio 打开  
   或手动：Android Studio → Open → 选 `E:\SmartClass\SmartClass\android`
2. 右上角 **Device Manager** → 创建/启动模拟器（首次）  
3. 点顶部绿色 **Run ▶** 运行  
4. 改代码后按 **热重载**（闪电图标或 `r`），**几秒**生效，不用每次全量编译

### 为什么第一次慢、后面快？

| 阶段 | 耗时 | 原因 |
|------|------|------|
| 第一次 `flutter run` / Run | 3～8 分钟 | Gradle 编译、下载依赖、装 NDK/CMake |
| 之后每次启动 | 10～30 秒 | 增量编译，缓存已在 `E:\dev\gradle` |
| 改 UI/逻辑后 | **1～3 秒** | 热重载 Hot Reload，不重新打包 |

之前慢是因为：**没有安卓模拟器**，误用了 Windows 桌面版（要下 Windows SDK + C++ 编译，和安卓无关）。

### 命令行方式（可选）

```powershell
. E:\dev\env.ps1
cd E:\SmartClass\SmartClass
# 先开模拟器（或插真机开 USB 调试）
emulator -avd SmartClass_Pixel
flutter run          # 自动装到模拟器/手机
```

### 打包 APK（发给手机安装）

```powershell
flutter build apk --debug
# 输出：build\app\outputs\flutter-apk\app-debug.apk
```


## iOS（后续扩展，本机 Windows 不编译）

`ios/` 目录已随工程生成，与 Android **共用 `lib/` 业务代码**。日后在 Mac 上：

```bash
cd SmartClass
flutter pub get
cd ios && pod install && cd ..
flutter run -d <iphone或模拟器>
flutter build ios
```

扩展约定：

- 新功能只写在 `lib/`，不要在 `android/` 写业务逻辑
- 平台差异（如桌面 sqflite）集中在 `lib/main.dart` 初始化
- 需要原生能力时用 Flutter 插件，两边同时验证

## 慢的原因（已处理）

1. 工具/缓存在 C:、项目在 E: → 跨盘 I/O + Kotlin 增量编译失败  
2. 首次 Gradle 拉 Google 依赖慢 → 已加阿里云镜像  
3. 终端长时间只显示 `Running Gradle...` → 其实在下载/编译，不是死机  

当前全部落在 E: 盘，同盘构建会快很多。
