@echo off
REM SmartClass — 全部使用 E 盘工具链 + 国内镜像
set FLUTTER_ROOT=E:\dev\flutter
set ANDROID_HOME=E:\dev\android-sdk
set ANDROID_SDK_ROOT=E:\dev\android-sdk
set PUB_CACHE=E:\dev\pub-cache
set GRADLE_USER_HOME=E:\dev\gradle
set PUB_HOSTED_URL=https://pub.flutter-io.cn
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
set PATH=E:\dev\flutter\bin;E:\dev\android-sdk\platform-tools;E:\dev\android-sdk\cmdline-tools\latest\bin;%PATH%
cd /d E:\SmartClass\SmartClass
echo [SmartClass] env ready. Commands: flutter run / flutter build apk
cmd /k
