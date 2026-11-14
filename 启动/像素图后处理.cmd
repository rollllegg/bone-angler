@echo off
setlocal
set "PIXEL_PYTHON=%~dp0..\game\.tools\perfect-pixel\venv\Scripts\python.exe"
if not exist "%PIXEL_PYTHON%" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\game\tools\Install-PerfectPixel.ps1"
    if errorlevel 1 goto failed
)
if "%~1"=="" (
    "%PIXEL_PYTHON%" "%~dp0..\game\tools\perfect_pixel.py" --help
    echo.
    echo Drag one or more pixel-art images onto this file to process them.
    pause
    exit /b 0
)
"%PIXEL_PYTHON%" "%~dp0..\game\tools\perfect_pixel.py" %*
if errorlevel 1 goto failed
pause
exit /b 0
:failed
echo PerfectPixel failed. See the message above; original images are preserved.
pause
exit /b 1
