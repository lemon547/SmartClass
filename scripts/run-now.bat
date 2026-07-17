@echo off
chcp 65001 >nul
title SmartClass 一键运行

set FLUTTER_ROOT=E:\dev\flutter
set ANDROID_HOME=E:\dev\android-sdk
set ANDROID_SDK_ROOT=E:\dev\android-sdk
set PUB_CACHE=E:\dev\pub-cache
set GRADLE_USER_HOME=E:\dev\gradle
set PUB_HOSTED_URL=https://pub.flutter-io.cn
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
set PATH=E:\dev\flutter\bin;E:\dev\android-sdk\platform-tools;%PATH%

cd /d E:\SmartClass\SmartClass
set APK=build\app\outputs\flutter-apk\app-debug.apk

echo.
echo ========================================
echo   SmartClass 一键运行（最快方式）
echo ========================================
echo.

adb devices
echo.

for /f "skip=1 tokens=1" %%d in ('adb devices ^| findstr /r "device$"') do set DEVICE=%%d

if defined DEVICE (
    echo [检测到手机] %DEVICE%
    echo 正在安装到手机...
    adb install -r "%APK%"
    if errorlevel 1 (
        echo 安装失败，请确认手机已开启 USB 调试并允许安装
        pause
        exit /b 1
    )
    echo.
    echo 安装成功！请在手机上打开 SmartClass
    echo 开发模式（改代码自动刷新）请运行: flutter run
    pause
    exit /b 0
)

echo [未检测到手机]
echo.
echo 最快两种方式（任选其一）:
echo.
echo  方式1 - 真机（推荐，不用下模拟器）:
echo    1. 手机开启「开发者选项」-「USB调试」
echo    2. USB 连接电脑，手机上点「允许」
echo    3. 再双击本脚本，自动安装
echo.
echo  方式2 - 直接装 APK（不用连电脑开发）:
echo    把下面这个文件发到手机安装:
echo    %CD%\%APK%
echo.
echo  方式3 - Android Studio（正规开发）:
echo    双击桌面「SmartClass Studio」
echo    右上角 Device Manager 创建模拟器后点 Run
echo.
explorer /select,"%CD%\%APK%"
pause
