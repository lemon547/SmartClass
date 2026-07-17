# SmartClass — 模拟器开发：启动模拟器 + 保存代码自动热重启（方便截图）
param(
    [switch]$SkipLaunch
)

$ErrorActionPreference = 'Stop'

$env:FLUTTER_ROOT = 'E:\dev\flutter'
$env:ANDROID_HOME = 'E:\dev\android-sdk'
$env:ANDROID_SDK_ROOT = 'E:\dev\android-sdk'
$env:ANDROID_AVD_HOME = 'E:\dev\android-avd'
$env:PUB_CACHE = 'E:\dev\pub-cache'
$env:GRADLE_USER_HOME = 'E:\dev\gradle'
$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
$env:PATH = 'E:\dev\flutter\bin;E:\dev\android-sdk\emulator;E:\dev\android-sdk\platform-tools;' + $env:PATH

Set-Location 'E:\SmartClass\SmartClass'

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  SmartClass emulator dev (screenshots)' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  Save lib/*.dart -> auto sync to emulator' -ForegroundColor Gray
Write-Host '  Use emulator window for screenshots' -ForegroundColor Gray
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

$deviceId = $null
if (-not $SkipLaunch) {
    $startScript = Join-Path $PSScriptRoot 'start-emulator.ps1'
    $startOut = & powershell -ExecutionPolicy Bypass -File $startScript 2>&1
    foreach ($line in $startOut) {
        if ($line -match '^\[emulator\]') { Write-Host $line }
        elseif ($line.Trim() -ne '' -and $line -match '^emulator-') {
            $deviceId = $line.Trim()
        }
    }
}

if (-not $deviceId) {
    $emu = adb devices | Select-String 'emulator-\d+\s+device'
    if ($emu) { $deviceId = ($emu -split '\s+')[0] }
}

if (-not $deviceId) {
    Write-Host '[emulator] no running emulator found' -ForegroundColor Red
    exit 1
}

flutter pub get | Out-Null
Write-Host "[SmartClass] Target emulator: $deviceId" -ForegroundColor Green
dart tool/dev_runner.dart -d $deviceId
