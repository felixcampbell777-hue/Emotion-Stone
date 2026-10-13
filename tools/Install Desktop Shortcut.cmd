@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install_desktop_shortcut.ps1"
if errorlevel 1 pause
