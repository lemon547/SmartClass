# SmartClass — 启动 Android 模拟器（SmartClass Pixel）
$ErrorActionPreference = 'Stop'

$env:ANDROID_AVD_HOME = 'E:\dev\android-avd'
$env:ANDROID_HOME = 'E:\dev\android-sdk'
$env:ANDROID_SDK_ROOT = 'E:\dev\android-sdk'
$env:PATH = 'E:\dev\android-sdk\emulator;E:\dev\android-sdk\platform-tools;E:\dev\flutter\bin;' + $env:PATH

$running = adb devices | Select-String 'emulator-\d+\s+device'
if ($running) {
    $id = ($running -split '\s+')[0]
    Write-Host "[emulator] already running: $id" -ForegroundColor Green
    Write-Output $id
    exit 0
}

Write-Host '[emulator] starting SmartClass_Pixel ...' -ForegroundColor Cyan
Start-Process -FilePath 'emulator' -ArgumentList '-avd', 'SmartClass_Pixel' -WindowStyle Normal

$deadline = (Get-Date).AddMinutes(3)
do {
    Start-Sleep -Seconds 3
    $booted = adb devices | Select-String 'emulator-\d+\s+device'
    if ($booted) {
        $id = ($booted -split '\s+')[0]
        Write-Host "[emulator] ready: $id" -ForegroundColor Green
        Write-Output $id
        exit 0
    }
    Write-Host '[emulator] waiting for boot...' -ForegroundColor Gray
} while ((Get-Date) -lt $deadline)

Write-Host '[emulator] boot timeout' -ForegroundColor Red
exit 1
