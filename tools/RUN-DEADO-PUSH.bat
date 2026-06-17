@echo off
title Deado Clothing Push
color 0A
set START_CHUNK=1
if not "%~1"=="" set START_CHUNK=%~1
echo.
echo  ============================================
echo   DEADO CLOTHING CHUNKED PUSH
echo  ============================================
echo.
echo   Chunk nuo: %START_CHUNK%
echo   1. UZDARYK CURSOR VISISKAI
echo   2. Palauk kol sis push baigsis
echo   3. Progresas: tools\push-deado-chunked.log
echo.
echo  Jei nutruko, paleisk:
echo   RUN-DEADO-PUSH.bat 15
echo.
pause
cd /d "%~dp0.."
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0push-deado-chunked.ps1" -StartFromChunk %START_CHUNK%
set ERR=%ERRORLEVEL%
echo.
if %ERR% neq 0 (
    color 0C
    echo  KLAIDA! Ziurek tools\push-deado-chunked.log
) else (
    echo  SEKME! Visi chunk'ai nupushinti i deado-clothing-pack
)
echo.
pause
exit /b %ERR%
