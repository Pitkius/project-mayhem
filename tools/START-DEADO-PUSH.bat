@echo off
:: Paleidzia push NAUJOJE CMD lange (visiskai atskirai nuo Cursor)
:: Naudojimas: START-DEADO-PUSH.bat [chunk_nr]
:: Pvz. START-DEADO-PUSH.bat 3
if "%~1"=="" (
    start "Deado Push" cmd /k "cd /d %~dp0 && RUN-DEADO-PUSH.bat"
) else (
    start "Deado Push" cmd /k "cd /d %~dp0 && RUN-DEADO-PUSH.bat %~1"
)
