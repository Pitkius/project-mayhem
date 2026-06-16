@echo off
REM Sukuria darbalaukyje shortcut "FiveM Dev" su resmon / F10 palaikymu
set "FIVEM=%LOCALAPPDATA%\FiveM\FiveM.exe"
set "DESKTOP=%USERPROFILE%\Desktop"
set "SHORTCUT=%DESKTOP%\FiveM Dev.lnk"

if not exist "%FIVEM%" (
  echo Nerastas FiveM.exe: %FIVEM%
  pause
  exit /b 1
)

powershell -NoProfile -Command "$s = New-Object -ComObject WScript.Shell; $l = $s.CreateShortcut('%SHORTCUT%'); $l.TargetPath = '%FIVEM%'; $l.Arguments = '+set moo 31337'; $l.WorkingDirectory = '%LOCALAPPDATA%\FiveM'; $l.Description = 'FiveM dev rezimas (F10 resmon)'; $l.Save()"

echo.
echo Sukurta: %SHORTCUT%
echo Naudok si shortcut vietoj paprasto FiveM — tada F10 atidarys resmon.
echo.
pause
