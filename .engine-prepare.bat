@echo off
setlocal enabledelayedexpansion

set "useMono=0"
if "%~1"=="" (
    set "versionNumber=4.8"
    set "flavor=dev6"
) else (
    if "%~2"=="" (
        echo Usage: %~nx0 ^<version^> ^<flavor^>
        exit /b 1
    )
    set "versionNumber=%~1"
    set "flavor=%~2"
)
set "engineDir=%USERPROFILE%\godot\%versionNumber%-%flavor%"
set "tmpDir=%TEMP%\godot-engine-prepare"
set "zipFile=%tmpDir%\godot.zip"

if not "%useMono%"=="0" (
    set "zipSlug=mono_win64.zip"
    set "godotExeFile=Godot_v%versionNumber%-%flavor%_mono_win64.exe"
) else (
    set "zipSlug=win64.exe.zip"
    set "godotExeFile=Godot_v%versionNumber%-%flavor%_win64.exe"
)
set "engineExe=%engineDir%\%godotExeFile%"

REM 1. Check if engine exists
if exist "%engineExe%" (
    echo Engine already exists, skipping download
    goto :done
)

REM 2. Remove old engine folder
if exist "%engineDir%" (
    echo Removing old engine folder...
    rmdir /s /q "%engineDir%"
)

REM 3. Download engine to temp
echo Creating temp directory...
if not exist "%tmpDir%" mkdir "%tmpDir%"

echo Downloading engine %versionNumber%-%flavor%...
powershell -NoProfile -ExecutionPolicy Bypass -Command "& {$v='%versionNumber%'; $f='%flavor%'; $s='%zipSlug%'; $u='https://downloads.godotengine.org/?version='+$v+'&flavor='+$f+'&slug='+$s+'&platform=windows.64'; Invoke-WebRequest -Uri $u -OutFile '%zipFile%'}"
if errorlevel 1 (
    echo Download failed
    exit /b 1
)

REM 4. Extract to temp directory first
echo Extracting engine...
set "extractDir=%tmpDir%\extract"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& {Expand-Archive -Path '%zipFile%' -DestinationPath '%extractDir%' -Force}"
if errorlevel 1 (
    echo Extraction failed
    exit /b 1
)

echo Moving files to %engineDir%...
if not exist "%engineDir%" mkdir "%engineDir%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& {$extractDir='%extractDir%'; $engineDir='%engineDir%'; $exeName='%godotExeFile%'; $foundExe=Get-ChildItem -Path $extractDir -Recurse -Filter $exeName | Select-Object -First 1; if ($foundExe) { $sourceDir=$foundExe.Directory.FullName; Get-ChildItem -Path $sourceDir | Copy-Item -Destination $engineDir -Recurse -Force } else { Write-Host 'Engine exe not found'; exit 1 }}"
if errorlevel 1 (
    echo Failed to move files
    exit /b 1
)

REM 5. Remove temp
echo Cleaning temp files...
rmdir /s /q "%tmpDir%"

:done
if not exist "%engineExe%" (
    echo Engine exe not found: %engineExe%
    exit /b 1
)

echo Engine preparation completed!
endlocal
