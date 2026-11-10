@echo off
cd /d "%~dp0..\game"
python tools\serve_web.py
if errorlevel 1 pause
