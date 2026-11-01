@echo off
chcp 65001 >nul
title Autostart panelu pompy
cd /d "%~dp0"

rem  Autostart wskazuje na folder, w ktorym ten plik lezy. Panel ma swoje stale
rem  miejsce i nie ma po co robic kopii gdzie indziej - druga kopia znaczy dwa
rem  zestawy danych i aktualizowanie nie tej, ktora chodzi. Jedyne, na co nie
rem  pozwalamy, to Pobrane: ten folder Windows czysci sam.
set "DOCEL=%~dp0"
if "%DOCEL:~-1%"=="\" set "DOCEL=%DOCEL:~0,-1%"
echo %DOCEL% | findstr /i "\\Downloads\\ \\Pobrane\\" >nul
if not errorlevel 1 goto zle_miejsce

set "ZADANIE=Panel pompy"
set "STARY_VBS=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Panel pompy.vbs"

echo.
echo   ============================================
echo     Autostart panelu pompy
echo   ============================================
echo.
echo   Panel mieszka w:
echo     %DOCEL%
echo.

rem  Zatrzymujemy panel, zanim wystartujemy nowy. Bez tego stary proces trzyma
rem  port 8125, nowy nie ma gdzie wstac i po cichu pada - a uzytkownik widzi
rem  stara wersje i slusznie mysli, ze instalacja nic nie dala.
echo   Zatrzymuje dzialajacy panel, jesli jakis chodzi...
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*pompa-acond.py*panel*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }" >nul 2>&1
echo.

if not exist "%DOCEL%\logowanie.txt" (
  echo   UWAGA: nie znalazlem logowanie.txt - panel nie zaloguje sie do sterownika.
  echo   Zaloz go w %DOCEL% : nazwa uzytkownika w pierwszej linijce, haslo w drugiej.
  echo.
)

rem  Sprzatamy po poprzedniej metodzie. Wpis .vbs w folderze Autostartu to
rem  technika, ktorej uzywa zlosliwe oprogramowanie - skrypt uruchamiajacy
rem  ukryte okno konsoli. Avast zglosil to 18.10, 360 Total Security 1.11 jako
rem  Trojan.Generic. Oba mialy racje co do techniki, choc nie co do pliku.
if exist "%STARY_VBS%" del "%STARY_VBS%" >nul 2>&1
if exist "%DOCEL%\autostart.szablon.vbs" del "%DOCEL%\autostart.szablon.vbs" >nul 2>&1

rem  Zamiast tego Harmonogram zadan - mechanizm, ktory Windows daje wlasnie do
rem  tego. Nie dotyka folderu startowego, niczego nie ukrywa i nie podszywa sie
rem  pod nic. Okno konsoli i tak nie zostaje, bo _URUCHOM-PANEL.bat w trybie
rem  "cicho" odpala pythonw i konczy sie po sekundzie.
echo   Zakladam zadanie w Harmonogramie Windows...
powershell -NoProfile -Command "$a=New-ScheduledTaskAction -Execute ($env:DOCEL+'\_URUCHOM-PANEL.bat') -Argument 'cicho' -WorkingDirectory $env:DOCEL; $t=New-ScheduledTaskTrigger -AtLogOn; $s=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -StartWhenAvailable; Register-ScheduledTask -TaskName $env:ZADANIE -Action $a -Trigger $t -Settings $s -Force | Out-Null"
powershell -NoProfile -Command "if (Get-ScheduledTask -TaskName $env:ZADANIE -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }"
if errorlevel 1 goto blad_zadania

echo   Gotowe. Panel bedzie sie uruchamial sam po zalogowaniu do Windowsa,
echo   bez okna terminala. To, co wypisuje, trafia do:
echo     %DOCEL%\panel.log
echo.
echo   Uruchamiam go teraz, zebys nie musial czekac do restartu...
schtasks /Run /TN "%ZADANIE%" >nul 2>&1
echo.
echo   Panel: http://localhost:8125
echo.
echo   Zeby to wylaczyc, uruchom _USUN-AUTOSTART.bat
echo   Aktualizacja: wrzucasz nowe pliki do tego folderu i klikasz ten plik.
echo.
pause
exit /b

:zle_miejsce
echo.
echo   Panel lezy w Pobranych. Windows potrafi sam czyscic ten folder, a razem
echo   z nim poszlaby cala zebrana historia pomiarow.
echo.
echo   Przenies caly folder na C:\PanelPompy i uruchom ten plik jeszcze raz.
echo.
pause
exit /b 1

:blad_zadania
echo.
echo   Nie udalo sie zalozyc zadania w Harmonogramie.
echo   Sprobuj jeszcze raz, klikajac ten plik prawym przyciskiem
echo   i wybierajac "Uruchom jako administrator".
echo.
pause
exit /b 1
