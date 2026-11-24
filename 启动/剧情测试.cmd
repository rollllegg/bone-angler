@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\game\tools\Run-StoryLab.ps1"
if errorlevel 1 pause
