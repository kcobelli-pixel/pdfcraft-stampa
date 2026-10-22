@echo off
rem Doppio clic dopo ogni aggiornamento di PdfCraft: installa la versione con la correzione della stampa.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Applica-stampa.ps1"
echo.
pause
