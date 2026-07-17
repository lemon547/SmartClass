@echo off
chcp 65001 >nul
title SmartClass Android 开发环境

set FLUTTER_ROOT=E:\dev\flutter
set ANDROID_HOME=E:\dev\android-sdk
set ANDROID_SDK_ROOT=E:\dev\android-sdk
set ANDROID_AVD_HOME=E:\dev\android-avd
set PUB_CACHE=E:\dev\pub-cache
set GRADLE_USER_HOME=E:\dev\gradle
set PUB_HOSTED_URL=https://pub.flutter-io.cn
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
set PATH=E:\dev\flutter\bin;E:\dev\android-sdk\emulator;E:\dev\android-sdk\platform-tools;E:\dev\android-sdk\cmdline-tools\latest\bin;%PATH%

cd /d E:\SmartClass\SmartClass

echo.
echo ========================================
echo   SmartClass  Android 开发
echo ========================================
echo   1. 用 Android Studio 打开项目（推荐）
echo   2. 启动安卓模拟器
echo   3. 命令行运行到模拟器/真机
echo   4. 仅打包 APK
echo   5. 退出
echo ========================================
echo.

choice /c 12345 /n /m "请选择 [1-5]: "
if errorlevel 5 goto :eof
if errorlevel 4 goto build_apk
if errorlevel 3 goto flutter_run
if errorlevel 2 goto start_emulator
if errorlevel 1 goto open_studio

:open_studio
echo 正在打开 Android Studio ...
start "" "C:\Program Files\Android\Android Studio\bin\studio64.exe" "E:\SmartClass\SmartClass\android"
echo.
echo 在 Android Studio 里：
echo   File - Open - 选 android 文件夹
echo   右上角 Device Manager - 启动模拟器
echo   顶部绿色 Run 按钮运行
pause
goto :eof

:start_emulator
echo 启动模拟器 SmartClass_Pixel ...
start "Android Emulator" emulator -avd SmartClass_Pixel
echo 模拟器窗口弹出后，再选菜单 3 运行应用
pause
goto :eof

:flutter_run
echo 检查设备...
adb devices
echo.
echo 首次运行会编译约 3-5 分钟，之后热重载很快（按 r 刷新）
flutter pub get
flutter run
pause
goto :eof

:build_apk
flutter build apk --debug
echo.
echo APK: build\app\outputs\flutter-apk\app-debug.apk
pause
goto :eof
