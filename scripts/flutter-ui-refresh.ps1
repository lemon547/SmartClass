# Agent / 开发者：改 UI 后运行此脚本做 analyze + 刷新提示
param(
    [string[]]$Files = @()
)

$ErrorActionPreference = 'Stop'

$env:FLUTTER_ROOT = 'E:\dev\flutter'
$env:PATH = 'E:\dev\flutter\bin;' + $env:PATH

Set-Location 'E:\SmartClass\SmartClass'

# 兼容逗号拼成单个参数的情况
$targets = @()
foreach ($f in $Files) {
    if ($f -match ',') {
        $targets += $f.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    } elseif ($f) {
        $targets += $f
    }
}

Write-Host '[flutter-ui-refresh] dart analyze...' -ForegroundColor Cyan

if ($targets.Count -gt 0) {
    & dart analyze @targets
} else {
    & dart analyze lib/
}

if ($LASTEXITCODE -ne 0) {
    Write-Host '[flutter-ui-refresh] analyze failed — fix errors before expecting UI update' -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host '[flutter-ui-refresh] analyze OK' -ForegroundColor Green

$devRunning = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object {
        $_.CommandLine -and (
            $_.CommandLine -like '*dev_runner.dart*' -or
            ($_.CommandLine -like '*flutter*' -and $_.CommandLine -like '*run*')
        )
    }

if ($devRunning) {
    Write-Host '[flutter-ui-refresh] flutter dev process detected — save triggers auto hot restart via dev-run' -ForegroundColor Green
    Write-Host '[flutter-ui-refresh] if UI still stale, press R in flutter terminal or restart dev-run.ps1' -ForegroundColor Yellow
} else {
    Write-Host '[flutter-ui-refresh] no flutter dev process — start: powershell -File scripts/dev-run.ps1' -ForegroundColor Yellow
    Write-Host '[flutter-ui-refresh] or press Hot Restart in Android Studio / R in flutter run terminal' -ForegroundColor Yellow
}

exit 0
