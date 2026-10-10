@echo off
rem Double-click to start the bot automatically at Windows logon
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\autostart-install.ps1"
pause
