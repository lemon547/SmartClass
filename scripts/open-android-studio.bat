@echo off
set ANDROID_HOME=E:\dev\android-sdk
set ANDROID_SDK_ROOT=E:\dev\android-sdk
set ANDROID_AVD_HOME=E:\dev\android-avd
set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr
set PATH=E:\dev\flutter\bin;E:\dev\android-sdk\platform-tools;E:\dev\android-sdk\emulator;%PATH%
start "" "C:\Program Files\Android\Android Studio\bin\studio64.exe" "E:\SmartClass\SmartClass\android"
