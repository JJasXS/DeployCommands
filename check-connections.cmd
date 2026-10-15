@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0check-connections.ps1"
exit /b %ERRORLEVEL%

:: .\check-connections.cmd