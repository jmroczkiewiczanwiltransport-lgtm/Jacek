@echo off
chcp 65001 >nul
title Wylaczanie autostartu panelu
set "ZADANIE=Panel pompy"
set "STARY_VBS=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Panel pompy.vbs"

echo.
echo   Wylaczam autostart panelu pompy.
echo.

powershell -NoProfile -Command "Unregister-ScheduledTask -TaskName $env:ZADANIE -Confirm:$false -ErrorAction SilentlyContinue"
powershell -NoProfile -Command "if (Get-ScheduledTask -TaskName $env:ZADANIE -ErrorAction SilentlyContinue) { exit 1 } else { exit 0 }"
if errorlevel 1 (
  echo   Nie udalo sie usunac zadania - sprobuj jako administrator.
) else (
  echo   Zadanie z Harmonogramu usuniete.
)

rem  Resztka po poprzedniej metodzie, gdyby jeszcze gdzies lezala.
if exist "%STARY_VBS%" del "%STARY_VBS%" >nul 2>&1

rem  Panel chodzi bez okna, wiec trzeba go zatrzymac po nazwie polecenia.
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*pompa-acond.py*panel*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"
echo   Dzialajacy panel zatrzymany.
echo.
echo   Pliki i zebrana historia zostaja tam, gdzie byly:
echo     %~dp0
echo   Nic stad nie kasuje - to dwa miesiace pomiarow.
echo.
pause
