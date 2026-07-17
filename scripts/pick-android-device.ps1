# SmartClass — 检测已连接的 Android 设备（真机优先）
param(
    [switch]$WaitAuthorize,
    [int]$WaitSeconds = 120
)

$ErrorActionPreference = 'Stop'

$env:FLUTTER_ROOT = 'E:\dev\flutter'
$env:ANDROID_HOME = 'E:\dev\android-sdk'
$env:ANDROID_SDK_ROOT = 'E:\dev\android-sdk'
$env:PATH = 'E:\dev\flutter\bin;E:\dev\android-sdk\platform-tools;' + $env:PATH

Set-Location 'E:\SmartClass\SmartClass'

function Get-AdbDeviceLines {
    adb devices | Select-Object -Skip 1 | Where-Object { $_.Trim() -ne '' }
}

function Get-DeviceStatus {
    param([string[]]$Lines)

    $authorizedPhones = @()
    $unauthorized = @()
    $emulators = @()

    foreach ($line in $Lines) {
        $parts = ($line -split '\s+', 2)
        if ($parts.Count -lt 2) { continue }
        $id = $parts[0]
        $state = $parts[1]

        if ($state -eq 'device') {
            if ($id -like 'emulator-*') {
                $emulators += $id
            } else {
                $authorizedPhones += $id
            }
        } elseif ($state -eq 'unauthorized') {
            $unauthorized += $id
        }
    }

    return [PSCustomObject]@{
        Phones       = $authorizedPhones
        Unauthorized = $unauthorized
        Emulators    = $emulators
    }
}

$deadline = (Get-Date).AddSeconds($WaitSeconds)
do {
    $status = Get-DeviceStatus (Get-AdbDeviceLines)

    if ($status.Phones.Count -gt 0) {
        Write-Host "[device] phone ready: $($status.Phones[0])" -ForegroundColor Green
        Write-Output $status.Phones[0]
        exit 0
    }

    if ($status.Unauthorized.Count -gt 0) {
        Write-Host '[device] phone connected but UNAUTHORIZED' -ForegroundColor Yellow
        Write-Host '  1. Unlock your phone' -ForegroundColor Yellow
        Write-Host '  2. Tap "Allow USB debugging" on the popup' -ForegroundColor Yellow
        Write-Host '  3. Check "Always allow from this computer" if shown' -ForegroundColor Yellow
        if (-not $WaitAuthorize) { exit 2 }
    } elseif ($status.Emulators.Count -gt 0) {
        Write-Host "[device] only emulator: $($status.Emulators[0])" -ForegroundColor Cyan
        if (-not $WaitAuthorize) {
            Write-Output $status.Emulators[0]
            exit 0
        }
    } else {
        Write-Host '[device] no Android device found' -ForegroundColor Red
        Write-Host '  Enable USB debugging: Settings -> Developer options -> USB debugging' -ForegroundColor Gray
        if (-not $WaitAuthorize) { exit 1 }
    }

    if ($WaitAuthorize -and (Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 3
    } else {
        break
    }
} while ($WaitAuthorize -and (Get-Date) -lt $deadline)

Write-Host '[device] timed out waiting for authorized phone' -ForegroundColor Red
exit 3
