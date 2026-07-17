# SmartClass — 真机 + 模拟器同时开发（真机测 bug，模拟器截图）
$ErrorActionPreference = 'Stop'

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  SmartClass dual dev (phone + emulator)' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  Phone: test on real device' -ForegroundColor Gray
Write-Host '  Emulator: take screenshots on PC' -ForegroundColor Gray
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

$root = Split-Path -Parent $MyInvocation.MyCommand.Path

Start-Process powershell -ArgumentList @(
    '-NoExit',
    '-ExecutionPolicy', 'Bypass',
    '-File', (Join-Path $root 'dev-run-phone.ps1')
) -WindowStyle Normal

Start-Sleep -Seconds 2

Start-Process powershell -ArgumentList @(
    '-NoExit',
    '-ExecutionPolicy', 'Bypass',
    '-File', (Join-Path $root 'dev-run-emulator.ps1')
) -WindowStyle Normal

Write-Host 'Started two windows:' -ForegroundColor Green
Write-Host '  1. Phone dev (USB)' -ForegroundColor Green
Write-Host '  2. Emulator dev (screenshots)' -ForegroundColor Green
Write-Host ''
Write-Host 'Save lib/*.dart -> both devices hot restart automatically.' -ForegroundColor Yellow
