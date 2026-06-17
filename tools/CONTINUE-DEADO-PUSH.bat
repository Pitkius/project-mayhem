@echo off
:: Push 4 laukancius commit'us, tada tesia nuo chunk 7 (BatchSize=100 kaip pradzioje)
title Deado Push - Sync + Continue nuo 7
color 0E
echo.
echo  1. Push nepushintus commit'us (03-06)
echo  2. Tesiam nuo chunk 7
echo.
pause
cd /d "%~dp0.."
echo --- SYNC ---
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0push-deado-chunked.ps1" -SyncOnly
if errorlevel 1 (
    color 0C
    echo SYNC NEPAVYKO - paleisk SYNC-PENDING.bat dar karta
    pause
    exit /b 1
)
echo.
echo --- CHUNK 7+ ---
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0push-deado-chunked.ps1" -StartFromChunk 7 -BatchSize 100
set ERR=%ERRORLEVEL%
if %ERR% neq 0 (color 0C & echo KLAIDA!) else (color 0A & echo SEKME!)
pause
exit /b %ERR%
