@echo off
rem Double-click to stop starting the bot at Windows logon
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\autostart-uninstall.ps1"
pause
