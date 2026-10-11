@echo off
setlocal
cd /d "%~dp0"

set "version=4.8"
set "flavor=dev7"
set "engineDir=%USERPROFILE%\godot\%version%-%flavor%"
set "engineExe=%engineDir%\Godot_v%version%-%flavor%_win64.exe"

call .engine-prepare.bat "%version%" "%flavor%"
if errorlevel 1 exit /b 1

if "%~1"=="" (
    start "" "%engineExe%" --editor --path "%CD%"
    exit /b 0
)

"%engineExe%" %*
exit /b %errorlevel%
