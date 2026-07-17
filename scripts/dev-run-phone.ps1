# SmartClass — 真机开发：USB 连接 + 保存代码自动热重启到手机
param(
    [switch]$Emulator,
    [switch]$NoWait
)

$ErrorActionPreference = 'Stop'

$env:FLUTTER_ROOT = 'E:\dev\flutter'
$env:ANDROID_HOME = 'E:\dev\android-sdk'
$env:ANDROID_SDK_ROOT = 'E:\dev\android-sdk'
$env:PUB_CACHE = 'E:\dev\pub-cache'
$env:GRADLE_USER_HOME = 'E:\dev\gradle'
$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
$env:PATH = 'E:\dev\flutter\bin;E:\dev\android-sdk\platform-tools;' + $env:PATH

Set-Location 'E:\SmartClass\SmartClass'

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  SmartClass phone dev (USB + hot restart)' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  Save lib/*.dart -> auto sync to phone' -ForegroundColor Gray
Write-Host '  Manual in terminal: r reload, R restart' -ForegroundColor Gray
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

$deviceId = $null
if ($Emulator) {
    $pickArgs = @()
} else {
    $pickArgs = @('-WaitAuthorize')
    if ($NoWait) { $pickArgs = @() }
}

$pickScript = Join-Path $PSScriptRoot 'pick-android-device.ps1'
$pickResult = & powershell -ExecutionPolicy Bypass -File $pickScript @pickArgs 2>&1
$pickExit = $LASTEXITCODE

foreach ($line in $pickResult) {
    if ($line -match '^\[device\]' -or $line -match 'Unlock|Allow|Enable|timed out|only emulator|no Android') {
        Write-Host $line
    } elseif ($line.Trim() -ne '') {
        $deviceId = $line.Trim()
    }
}

if ($pickExit -ne 0 -and -not $deviceId) {
    Write-Host ''
    Write-Host 'Cannot start: authorize your phone USB debugging first.' -ForegroundColor Red
    Write-Host 'Then rerun: powershell -File scripts/dev-run-phone.ps1' -ForegroundColor Yellow
    exit $pickExit
}

flutter pub get | Out-Null

if ($deviceId) {
    Write-Host "[SmartClass] Target device: $deviceId" -ForegroundColor Green
    dart tool/dev_runner.dart -d $deviceId
} else {
    Write-Host '[SmartClass] No device id, flutter will pick default' -ForegroundColor Yellow
    dart tool/dev_runner.dart
}
