@echo off
:: ============================================================
::  WinLean - inicializador local / local launcher
::  Prefere a interface Rust; cai para o menu PowerShell se ela
::  nao estiver presente.
:: ============================================================
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
    start "" "%~dp0winlean.exe" --script "%~dp0WinLean.ps1" %*
    exit /b
) else if exist "ui\target\release\winlean.exe" (
    start "" "%~dp0ui\target\release\winlean.exe" --script "%~dp0WinLean.ps1" %*
    exit /b
)

:: O fallback precisa de console; a GUI solicita elevacao sozinha e exibe apenas o UAC.
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -File ".\WinLean.ps1" %*
