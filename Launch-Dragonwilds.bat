@echo off
setlocal EnableExtensions
cd /d "%~dp0"

REM Deploy Teflon Ted mods, then launch RuneScape: Dragonwilds via Steam app id if needed.

if not exist "%~dp0Environment.ps1" (
  echo [ERROR] Environment.ps1 not found. Copy Environment.ps1.example and set DRAGONWILDS_INSTALL.
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Deploy-Mods.ps1"
if errorlevel 1 (
  echo [ERROR] Deploy failed.
  pause
  exit /b 1
)

for /f "usebackq delims=" %%I in (`powershell -NoProfile -ExecutionPolicy Bypass -Command ". '%~dp0Environment.ps1'; Write-Output $DRAGONWILDS_INSTALL"`) do set "DW=%%I"
set "EXE=%DW%\Binaries\Win64\RSDragonwilds-Win64-Shipping.exe"
if not exist "%EXE%" (
  echo [ERROR] Game exe not found: %EXE%
  pause
  exit /b 1
)

if not exist "%DW%\Binaries\Win64\ue4ss\UE4SS.dll" (
  echo [ERROR] UE4SS not installed under Binaries\Win64\ue4ss
  pause
  exit /b 1
)

echo Launching Dragonwilds...
start "" /D "%DW%\Binaries\Win64" "%EXE%"
endlocal
exit /b 0
