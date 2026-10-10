@echo off
rem Double-click to install: Python venv, packages, .env, Ollama model
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\setup.ps1"
pause
