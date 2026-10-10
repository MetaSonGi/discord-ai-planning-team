@echo off
rem Double-click to start the bot (runs setup first if needed)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\run.ps1"
pause
