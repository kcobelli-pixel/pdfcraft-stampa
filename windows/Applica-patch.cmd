@echo off
rem Doppio clic dopo ogni aggiornamento di PdfCraft: installa la versione con le patch.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Applica-patch.ps1"
echo.
pause
