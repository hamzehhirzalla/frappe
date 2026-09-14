@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0manage.ps1" Start
if errorlevel 1 (
  pause
  exit /b 1
)
start "Frappe" "http://localhost:8080"
