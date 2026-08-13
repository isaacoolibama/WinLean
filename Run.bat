@echo off
:: ============================================================
::  WinLean - inicializador local / local launcher
::  Prefere a interface Rust; cai para o menu PowerShell se ela
::  nao estiver presente.
:: ============================================================
title WinLean

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Solicitando privilegios de administrador...
    echo Requesting administrator privileges...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"

if not exist "WinLean.ps1" (
    echo.
    echo   WinLean.ps1 nao encontrado nesta pasta.
    echo   WinLean.ps1 was not found in this folder.
    echo.
    pause
    exit /b 1
)

if exist "winlean.exe" (
    winlean.exe --script ".\WinLean.ps1" %*
) else if exist "ui\target\release\winlean.exe" (
    ui\target\release\winlean.exe --script ".\WinLean.ps1" %*
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File ".\WinLean.ps1" %*
)

echo.
pause
