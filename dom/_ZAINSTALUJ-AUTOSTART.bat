@echo off
chcp 65001 >nul
title Autostart panelu pompy
cd /d "%~dp0"

rem  Autostart wskazuje na folder, w którym ten plik leży. Panel ma już swoje
rem  stałe miejsce (u Jacka C:\PanelPompy) i nie ma po co robić kopii gdzie
rem  indziej — druga kopia znaczy dwa zestawy danych i aktualizowanie nie tej,
rem  która chodzi. Jedyne, na co nie pozwalamy, to Pobrane: ten folder Windows
rem  czyści sam, a leży w nim cała zebrana historia.
set "DOCEL=%~dp0"
if "%DOCEL:~-1%"=="\" set "DOCEL=%DOCEL:~0,-1%"
echo %DOCEL% | findstr /i "\\Downloads\\ \\Pobrane\\" >nul
if not errorlevel 1 goto zle_miejsce
set "SZABLON=%~dp0autostart.szablon.vbs"
set "STARTUP_VBS=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Panel pompy.vbs"

echo.
echo   ============================================
echo     Autostart panelu pompy
echo   ============================================
echo.
echo   Panel mieszka w:
echo     %DOCEL%
echo.

rem  Zatrzymujemy panel, zanim wystartujemy nowy. Bez tego stary proces trzyma
rem  port 8125, nowy nie ma gdzie wstac i po cichu pada — a uzytkownik widzi
rem  stara wersje i slusznie mysli, ze instalacja nic nie dala.
echo   Zatrzymuje dzialajacy panel, jesli jakis chodzi...
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*pompa-acond.py*panel*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }" >nul 2>&1
echo.

if not exist "%DOCEL%\logowanie.txt" (
  echo   UWAGA: nie znalazłem logowanie.txt — panel nie zaloguje się do sterownika.
  echo   Załóż go w %DOCEL% : nazwa użytkownika w pierwszej linijce, hasło w drugiej.
  echo.
)

rem  Skrót w Autostarcie. Ścieżkę wstawiamy przez PowerShella, przez zmienne
rem  środowiskowe — inaczej cudzysłowy i spacje w nazwie użytkownika rozjeżdżają
rem  się nie do naprawienia.
powershell -NoProfile -Command "[IO.File]::WriteAllText($env:STARTUP_VBS, [IO.File]::ReadAllText($env:SZABLON).Replace('KATALOG_PANELU', $env:DOCEL))"
if not exist "%STARTUP_VBS%" goto blad_skrotu

echo   Gotowe. Panel będzie się uruchamiał sam po zalogowaniu do Windowsa,
echo   bez okna terminala. To, co wypisuje, trafia do:
echo     %DOCEL%\panel.log
echo.
echo   Uruchamiam go teraz, żebyś nie musiał czekać do restartu…
start "" wscript.exe "%STARTUP_VBS%"
echo.
echo   Panel: http://localhost:8125
echo.
echo   Żeby to wyłączyć, uruchom _USUN-AUTOSTART.bat
echo   Aktualizacja: wrzucasz nowe pliki do tego folderu i klikasz ten plik.
echo.
pause
exit /b

:zle_miejsce
echo.
echo   Panel leży w Pobranych. Windows potrafi sam czyścić ten folder, a razem
echo   z nim poszłaby cała zebrana historia pomiarów.
echo.
echo   Przenieś cały folder na C:\PanelPompy i uruchom ten plik jeszcze raz.
echo.
pause
exit /b 1

:blad_skrotu
echo   Nie udało się założyć skrótu w Autostarcie.
echo   Spróbuj ręcznie: naciśnij Windows+R, wpisz  shell:startup  i skopiuj tam
echo   plik  %DOCEL%\autostart.szablon.vbs  , podmieniając w nim
echo   napis KATALOG_PANELU na  %DOCEL%
echo.
pause
