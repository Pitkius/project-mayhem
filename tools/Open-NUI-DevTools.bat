@echo off
REM Atidaro FiveM NUI Chrome inspector (reikia paleisto FiveM su +set moo 31337)
echo.
echo  FiveM NUI DevTools
echo  ==================
echo  1. Paleisk FiveM per Start-FiveM-Dev.bat (arba shortcut su +set moo 31337)
echo  2. Prisijunk prie serverio ir atidaryk UI (register, HUD, inventory...)
echo  3. Sioje naršykleje pasirink TIKSLU resursa, pvz.:
echo       nui://fivempro_charcreator/html/index.html
echo     NE "Main - https://cfx.re/" (tas rodo pilka tuscia)
echo.
start "" "http://localhost:13172/"
timeout /t 2 >nul
