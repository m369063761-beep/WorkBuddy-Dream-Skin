@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\install-anime-theme-shells.ps1"
if errorlevel 1 pause

