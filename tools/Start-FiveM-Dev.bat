@echo off
REM FiveM su dev režimu — F10: resmon, F8: nui_devTools
set "FIVEM=%LOCALAPPDATA%\FiveM\FiveM.exe"
if not exist "%FIVEM%" (
  echo Nerastas FiveM.exe: %FIVEM%
  pause
  exit /b 1
)
start "" "%FIVEM%" +set moo 31337
echo.
echo Paleidžiamas FiveM dev režimu (+set moo 31337)...
echo Po prisijungimo:
echo   - Resmon: F10 (admin)
echo   - NUI DevTools: /devtools  arba http://localhost:13172/
echo   - F8: resmon true
echo.
echo Shortcut darbalaukyje: paleisk tools\Install-FiveM-Dev-Shortcut.bat
echo.
timeout /t 8 /nobreak >nul
