@echo off
REM FiveM su dev režimu — F8: resmon true, profiler, NUI devtools
set "FIVEM=%LOCALAPPDATA%\FiveM\FiveM.exe"
if not exist "%FIVEM%" (
  echo Nerastas FiveM.exe: %FIVEM%
  pause
  exit /b 1
)
start "" "%FIVEM%" +set moo 31337
