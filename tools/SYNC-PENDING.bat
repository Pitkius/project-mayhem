@echo off
:: Tik push nepushintus commit'us (kai gavai HTTP 408)
title Deado Push - Sync Pending Only
color 0E
echo Pushinami visi nepushinti commit'ai po viena...
echo Auto-retry: 8 kartus po 45s
echo.
pause
cd /d "%~dp0.."
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0push-deado-chunked.ps1" -SyncOnly
if errorlevel 1 (
    color 0C
    echo KLAIDA! Paleisk dar karta po 1-2 min.
) else (
    color 0A
    echo SEKME! Visi laukiantys commit'ai nupushinti.
)
pause
