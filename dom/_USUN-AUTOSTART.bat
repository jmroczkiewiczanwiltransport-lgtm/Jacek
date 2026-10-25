@echo off
chcp 65001 >nul
title Wyłączanie autostartu panelu
set "STARTUP_VBS=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Panel pompy.vbs"

echo.
echo   Wyłączam autostart panelu pompy.
echo.

if exist "%STARTUP_VBS%" (
  del "%STARTUP_VBS%"
  echo   Skrót z Autostartu usunięty.
) else (
  echo   Skrótu w Autostarcie i tak nie było.
)

rem  Panel chodzi bez okna, więc trzeba go zatrzymać po nazwie polecenia.
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*pompa-acond.py*panel*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"
echo   Działający panel zatrzymany.
echo.
echo   Pliki i zebrana historia zostają tam, gdzie były:
echo     %~dp0
echo   Nic stąd nie kasuję — to dwa miesiące pomiarów.
echo.
pause
