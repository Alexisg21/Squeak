@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Installer-Squeak.ps1"
if errorlevel 1 (
 echo Installation incomplete. Consultez le message ci-dessus.
 pause
 exit /b 1
)
echo Squeak et son menu Windows sont installes.
pause
