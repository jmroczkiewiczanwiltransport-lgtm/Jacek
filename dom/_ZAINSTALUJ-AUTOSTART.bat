@echo off
chcp 65001 >nul
title Autostart panelu pompy
cd /d "%~dp0"

rem  Panel musi mieszkać w stałym miejscu, a nie w Pobranych: folder z paczką
rem  zmienia nazwę przy każdej aktualizacji i autostart wskazywałby w pustkę.
set "DOCEL=%LOCALAPPDATA%\PanelPompy"
set "SZABLON=%~dp0autostart.szablon.vbs"
set "STARTUP_VBS=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Panel pompy.vbs"

echo.
echo   ============================================
echo     Autostart panelu pompy
echo   ============================================
echo.
echo   Panel zamieszka w:
echo     %DOCEL%
echo.

if not exist "%DOCEL%" mkdir "%DOCEL%"

rem  Pliki programu — te nadpisujemy zawsze, to jest właśnie aktualizacja.
for %%p in (pompa-acond.py modbus.py falownik.py panel-pompy.html przypomnienia.py przypomnienia.json opisy-panelu.przyklad.json _URUCHOM-PANEL.bat autostart.szablon.vbs) do (
  if exist "%%p" copy /y "%%p" "%DOCEL%\" >nul
)

rem  Twoje pliki — kopiujemy tylko, jeśli tam ich jeszcze nie ma. Inaczej
rem  aktualizacja skasowałaby zebraną historię albo dane do logowania.
for %%p in (logowanie.txt ciasteczko.txt opisy-panelu.json dane-pompy.csv) do (
  if exist "%%p" if not exist "%DOCEL%\%%p" copy /y "%%p" "%DOCEL%\" >nul
)

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
echo   Od teraz aktualizujesz tak: pobierasz paczkę i klikasz ten plik jeszcze raz.
echo.
pause
exit /b

:blad_skrotu
echo   Nie udało się założyć skrótu w Autostarcie.
echo   Spróbuj ręcznie: naciśnij Windows+R, wpisz  shell:startup  i skopiuj tam
echo   plik  %DOCEL%\autostart.szablon.vbs  , podmieniając w nim
echo   napis KATALOG_PANELU na  %DOCEL%
echo.
pause
