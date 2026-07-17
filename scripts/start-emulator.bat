@echo off
REM 启动 SmartClass 安卓模拟器
set ANDROID_HOME=E:\dev\android-sdk
set ANDROID_SDK_ROOT=E:\dev\android-sdk
set ANDROID_AVD_HOME=E:\dev\android-avd
set PATH=E:\dev\android-sdk\emulator;E:\dev\android-sdk\platform-tools;%PATH%
start "SmartClass Emulator" emulator -avd SmartClass_Pixel
