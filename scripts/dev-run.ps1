# SmartClass — 推荐开发启动：保存 lib/ 后自动热重启
param(
    [switch]$Phone,
    [switch]$Emulator
)

$ErrorActionPreference = 'Stop'

if ($Phone) {
    & (Join-Path $PSScriptRoot 'dev-run-phone.ps1') @PSBoundParameters
    exit $LASTEXITCODE
}

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
Write-Host '  SmartClass dev-run (auto hot restart)' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  Save lib/*.dart -> auto R (hot restart)' -ForegroundColor Gray
Write-Host '  Phone USB: use scripts/dev-run-phone.ps1' -ForegroundColor Gray
Write-Host '  Manual: r = reload, R = restart, q = quit' -ForegroundColor Gray
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

$deviceId = $null
if (-not $Emulator) {
    $pickScript = Join-Path $PSScriptRoot 'pick-android-device.ps1'
    $pickOut = & powershell -ExecutionPolicy Bypass -File $pickScript 2>&1
    foreach ($line in $pickOut) {
        if ($line -match '^\[device\]') { Write-Host $line }
        elseif ($line.Trim() -ne '' -and $line -notmatch '^\[device\]') {
            $deviceId = $line.Trim()
        }
    }
}

flutter pub get | Out-Null

if ($deviceId) {
    Write-Host "[SmartClass] Target device: $deviceId" -ForegroundColor Green
    dart tool/dev_runner.dart -d $deviceId
} else {
    dart tool/dev_runner.dart
}