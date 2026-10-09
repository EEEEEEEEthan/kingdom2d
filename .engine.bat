@echo off
setlocal
cd /d "%~dp0"

set "version=4.7.2"
set "flavor=stable"
set "engineDir=%USERPROFILE%\godot\%version%-%flavor%"
set "engineExe=%engineDir%\Godot_v%version%-%flavor%_win64.exe"

call .engine-prepare.bat "%version%" "%flavor%"
if errorlevel 1 exit /b 1

if "%~1"=="" (
    start "" "%engineExe%" --editor --path "%CD%"
) else (
    "%engineExe%" %*
)
exit /b %errorlevel%
