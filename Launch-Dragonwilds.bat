@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

REM =============================================================================
REM  Launch RuneScape: Dragonwilds with Teflon Ted's mods from this repo.
REM
REM  Double-click this file, or from a terminal:
REM    Launch-Dragonwilds.bat
REM    Launch-Dragonwilds.bat -SkipDeploy
REM
REM  Prerequisites (one-time):
REM    1. UE4SS for RSDragonwilds installed into Binaries\Win64\
REM       (Nexus: https://www.nexusmods.com/runescapedragonwilds/mods/4)
REM    2. Environment.ps1 created from Environment.ps1.example
REM =============================================================================

set "SKIP_DEPLOY=0"
if /I "%~1"=="-SkipDeploy" set "SKIP_DEPLOY=1"
if /I "%~1"=="/SkipDeploy" set "SKIP_DEPLOY=1"

if not exist "%~dp0Environment.ps1" goto :err_no_env

REM Read DRAGONWILDS_INSTALL via a temp file so paths with "(x86)" never hit for /f parsing.
set "DRAGONWILDS_INSTALL="
set "_env_out=%TEMP%\teflonted_dragonwilds_install.txt"
del /q "%_env_out%" 2>nul
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  ". '%~dp0Environment.ps1'; if (-not $DRAGONWILDS_INSTALL) { exit 2 }; [IO.File]::WriteAllText('%_env_out%', $DRAGONWILDS_INSTALL.Trim())"
if errorlevel 1 goto :err_bad_env
if not exist "%_env_out%" goto :err_bad_env

set /p DRAGONWILDS_INSTALL=<"%_env_out%"
del /q "%_env_out%" 2>nul

REM Trim accidental quotes
set "DRAGONWILDS_INSTALL=!DRAGONWILDS_INSTALL:"=!"

if not defined DRAGONWILDS_INSTALL goto :err_bad_env

set "WIN64=!DRAGONWILDS_INSTALL!\Binaries\Win64"
set "EXE=!WIN64!\RSDragonwilds-Win64-Shipping.exe"

if not exist "!EXE!" goto :err_no_exe
if not exist "!WIN64!\ue4ss\UE4SS.dll" goto :err_no_ue4ss
if not exist "!WIN64!\dwmapi.dll" goto :err_no_ue4ss

if "!SKIP_DEPLOY!"=="0" goto :do_deploy
echo Skipping deploy ^(-SkipDeploy^).
goto :launch

:do_deploy
echo.
echo Deploying mods to ue4ss\Mods ...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Deploy-Mods.ps1"
if errorlevel 1 goto :err_deploy_failed

:launch
echo.
echo Launching: !EXE!
echo Mods load from: !WIN64!\ue4ss\Mods
echo   - SortIntoChests  (Alt+`)
echo   - AutoEat
echo   - EatToHeal       (auto-eat food when HP low)
echo   - QuickLaunch     (auto-continue last session; Esc cancels)
echo.

REM Start from Win64 so the dwmapi.dll UE4SS proxy loads with the shipping exe.
start "" /D "!WIN64!" "!EXE!"

endlocal
exit /b 0

:err_no_env
echo.
echo [ERROR] Environment.ps1 not found.
echo         Copy Environment.ps1.example to Environment.ps1
echo         and set DRAGONWILDS_INSTALL to your RSDragonwilds folder
echo         (the one that contains Binaries\Win64).
echo.
pause
exit /b 1

:err_bad_env
echo.
echo [ERROR] Could not read DRAGONWILDS_INSTALL from Environment.ps1
echo.
pause
exit /b 1

:err_no_exe
echo.
echo [ERROR] RSDragonwilds-Win64-Shipping.exe not found at:
echo         !EXE!
echo         Fix DRAGONWILDS_INSTALL in Environment.ps1
echo.
pause
exit /b 1

:err_no_ue4ss
echo.
echo [ERROR] UE4SS not found under:
echo         !WIN64!\ue4ss
echo         Install UE4SS for RSDragonwilds so dwmapi.dll and ue4ss\
echo         sit next to RSDragonwilds-Win64-Shipping.exe.
echo         See Install-UE4SS.ps1 or Nexus mod 4.
echo.
pause
exit /b 1

:err_deploy_failed
echo.
echo [ERROR] Deploy failed — not launching.
echo.
pause
exit /b 1
