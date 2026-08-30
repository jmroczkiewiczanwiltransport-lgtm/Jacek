@echo off
chcp 65001 >nul
title Panel pompy ciepla
cd /d "%~dp0"

rem  Adres panelu pompy. Gdyby sterownik dostal inny adres z routera,
rem  popraw go w tej jednej linii.
set POMPA=http://192.168.88.9/PAGE115.XML
set PORT=8125

echo.
echo   ============================================
echo     Panel pompy ciepła
echo   ============================================
echo.

rem  Szukamy Pythona — raz jako "python", raz jako "py".
set PYTHON=python
python --version >nul 2>&1
if errorlevel 1 set PYTHON=py
%PYTHON% --version >nul 2>&1
if errorlevel 1 goto brak_pythona

rem  Panel musi wiedzieć, która zmienna w pompie jest którą.
if not exist opisy-panelu.json (
  if exist opisy-panelu.przyklad.json (
    copy /y opisy-panelu.przyklad.json opisy-panelu.json >nul
    echo   Przygotowałem opisy-panelu.json
  )
)

rem  Bez otwartego portu telefon nie wejdzie — zapora odrzuca połączenie po cichu.
rem  Regułę zakładamy raz; Windows poprosi wtedy o zgodę administratora.
netsh advfirewall firewall show rule name="Panel pompy" >nul 2>&1
if errorlevel 1 (
  echo   Otwieram port %PORT% w zaporze. Windows zapyta o zgodę — kliknij TAK.
  powershell -NoProfile -Command "Start-Process netsh -Verb RunAs -Wait -ArgumentList 'advfirewall','firewall','add','rule','name=Panel pompy','dir=in','action=allow','protocol=TCP','localport=%PORT%','profile=private'" >nul 2>&1
  echo.
)

rem  Sterownik czasem chce ciasteczka sesji. Jeśli je masz, wklej samą wartość
rem  (np.  SoftPLC=11480121 ) do pliku ciasteczko.txt obok tego skrótu.
set CIASTECZKO=
if exist ciasteczko.txt set /p CIASTECZKO=<ciasteczko.txt

echo   Uruchamiam. To okno zostaw otwarte — panel działa, dopóki ono żyje.
echo   Zatrzymanie: Ctrl+C
echo.

if defined CIASTECZKO (
  %PYTHON% pompa-acond.py panel %POMPA% --ciasteczko "%CIASTECZKO%"
) else (
  %PYTHON% pompa-acond.py panel %POMPA%
)

echo.
echo   Panel zatrzymany.
echo.
echo   Gdyby telefon nie wchodził na panel, sprawdź w PowerShellu:
echo       Get-NetConnectionProfile
echo   przy WiFi ma być  NetworkCategory : Private  (nie Public).
pause
exit /b

:brak_pythona
echo   Nie znalazłem Pythona na tym komputerze.
echo.
echo   Pobierz go z:  https://python.org/downloads
echo   WAŻNE: przy instalacji zaznacz "Add python.exe to PATH"
echo   na pierwszym ekranie instalatora.
echo.
echo   Potem uruchom ten plik jeszcze raz.
echo.
pause
