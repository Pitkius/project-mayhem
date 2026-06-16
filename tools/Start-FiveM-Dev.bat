@echo off
REM FiveM su dev režimu — F8: resmon, nui_devTools, profiler
REM NUI inspector: http://localhost:13172/  (arba tools\Open-NUI-DevTools.bat)
set "FIVEM=%LOCALAPPDATA%\FiveM\FiveM.exe"
if not exist "%FIVEM%" (
  echo Nerastas FiveM.exe: %FIVEM%
  pause
  exit /b 1
)
start "" "%FIVEM%" +set moo 31337
echo.
echo Paleidžiamas FiveM dev režimu (+set moo 31337)...
echo Po prisijungimo prie serverio:
echo   - NUI DevTools: F10 arba atidaryk http://localhost:13172/
echo   - resmon: F8 - resmon true
echo   - Pagalba žaidime: /devhelp
echo.
timeout /t 10 /nobreak >nul
start "" "http://localhost:13172/"
