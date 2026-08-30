@echo off
chcp 65001 >nul
title Panel pompy ciepla
cd /d "%~dp0"

rem  Adres panelu pompy. Gdyby sterownik dostal inny adres z routera,
rem  popraw go w tej jednej linii.
set POMPA=http://192.168.88.9/PAGE115.XML

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

echo   Uruchamiam. To okno zostaw otwarte — panel działa, dopóki ono żyje.
echo   Zatrzymanie: Ctrl+C
echo.
echo   Przy pierwszym uruchomieniu Windows zapyta o dostęp do sieci.
echo   Kliknij ZEZWÓL i zaznacz "Sieci prywatne", inaczej telefon nie wejdzie.
echo.

%PYTHON% pompa-acond.py panel %POMPA%

echo.
echo   Panel zatrzymany.
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
