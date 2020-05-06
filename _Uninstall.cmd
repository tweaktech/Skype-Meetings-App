:: Do not use this batch file with SCCM
@echo off
setlocal enabledelayedexpansion
set SCRIPTDIR=%~dp0
set SCRIPTDIR=%SCRIPTDIR:~0,-1%

IF EXIST "%SystemRoot%\System32\WhoAmI.exe" (
 WhoAmI /priv | find "SeImpersonatePrivilege" >NUL || color 4f && echo. && echo This script must be run from an elevated command prompt. && echo. && pause && exit /b
)

start "" /wait "%SCRIPTDIR%\Deploy-Application.exe" Uninstall