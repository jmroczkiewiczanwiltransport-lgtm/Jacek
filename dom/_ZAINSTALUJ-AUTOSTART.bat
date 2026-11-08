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

rem  Harmonogram uruchamia pythonw.exe wprost, wiec musimy znac jego pelna
rem  sciezke. Pytamy o nia samego Pythona - pythonw.exe lezy zawsze obok
rem  python.exe, a "zgaduj po PATH" potrafi trafic w zaslepke ze Sklepu.
set "PYTHON=python"
python --version >nul 2>&1
if errorlevel 1 set "PYTHON=py"
%PYTHON% --version >nul 2>&1
if errorlevel 1 goto brak_pythona

set "PYTHONW="
for /f "delims=" %%P in ('%PYTHON% -c "import sys,os;print(os.path.join(os.path.dirname(sys.executable),'pythonw.exe'))" 2^>nul') do set "PYTHONW=%%P"
if not defined PYTHONW goto brak_pythona
if not exist "%PYTHONW%" goto brak_pythona

rem  Zatrzymujemy panel, zanim wystartujemy nowy. Bez tego stary proces trzyma
rem  port 8125, nowy nie ma gdzie wstac i po cichu pada - a uzytkownik widzi
rem  stara wersje i slusznie mysli, ze instalacja nic nie dala.
echo   Zatrzymuje dzialajacy panel, jesli jakis chodzi...
call :zatrzymaj_panel
if errorlevel 1 goto port_zajety
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

rem  Zadanie uruchamia pythonw.exe wprost, bez posrednika w postaci pliku .bat.
rem  Tak jest, bo Harmonogram trzyma zadanie w obiekcie job i zamyka go, gdy
rem  konczy sie proces akcji - a .bat, ktory odpalal pythona przez "start /b"
rem  i wychodzil, konczyl sie po ulamku sekundy i zabieral panel ze soba.
rem  Teraz procesem zadania JEST panel: zyje tak dlugo jak zadanie.
rem  pythonw.exe nie otwiera zadnego okna, wiec nie trzeba niczego ukrywac -
rem  a wlasnie ukrywanie okna bralo nam po kolei dwa antywirusy.
rem
rem  Adresu sterownika tu nie podajemy. Panel trzyma go sam w adres-pompy.txt
rem  i sam poprawia, gdy router da pompie nowy - jedno miejsce zamiast trzech.
rem
rem  Zakladanie zadania wymaga administratora, restart panelu nie. Dlatego
rem  najpierw sprawdzamy, czy zadanie juz jest i czy robi dokladnie to -
rem  jesli tak, nie ruszamy go wcale. Bez tego kazda aktualizacja konczyla sie
rem  czerwona "Odmowa dostepu", po ktorej i tak szlo "Gotowe". Komunikat o
rem  bledzie, po ktorym wszystko dziala, uczy ignorowania komunikatow o bledach.
call :sprawdz_zadanie
if not errorlevel 1 goto zadanie_juz_jest

echo   Zakladam zadanie w Harmonogramie Windows...
powershell -NoProfile -Command "$a=New-ScheduledTaskAction -Execute $env:PYTHONW -Argument 'pompa-acond.py panel' -WorkingDirectory $env:DOCEL; $t=New-ScheduledTaskTrigger -AtLogOn; $s=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1); Register-ScheduledTask -TaskName $env:ZADANIE -Action $a -Trigger $t -Settings $s -Force | Out-Null"
rem  To samo sprawdzenie, co przed rejestracja - a nie samo pytanie, czy
rem  zadanie istnieje. Stare zadanie istnieje zawsze, wiec tamto pytanie
rem  przepuszczalo odmowe dostepu jako sukces: instalator mowil zalozone, a zadanie dalej
rem  wskazywalo na stary plik. Dokladnie ten blad, przed ktorym ostrzega
rem  komentarz dziesiec linijek wyzej.
call :sprawdz_zadanie
if errorlevel 1 goto blad_zadania
echo   Zadanie zalozone.
goto po_zadaniu

:zadanie_juz_jest
echo   Zadanie w Harmonogramie juz jest i wskazuje tam gdzie trzeba.

:po_zadaniu

echo.
echo   Uruchamiam panel, zebys nie musial czekac do restartu...

rem  schtasks /Run na zadaniu zalozonym przez administratora potrafi odbic sie
rem  od "Odmowa dostepu", gdy klikasz ten plik bez uprawnien. Kiedys bylo to
rem  schowane za ">nul 2>&1" i instalator mowil "uruchamiam", nie uruchamiajac
rem  nic. Teraz, gdy Harmonogram odmowi, startujemy panel sami - tak samo, jak
rem  robi to dwuklik na _URUCHOM-PANEL.bat.
schtasks /Run /TN "%ZADANIE%" >nul 2>&1
if errorlevel 1 (
  echo   Harmonogram nie pozwolil uruchomic zadania z tego okna - startuje panel recznie.
  start "" "%PYTHONW%" pompa-acond.py panel
)

rem  Instalator ma sprawdzic, a nie zapewnic. Kazda runda tej historii wygladala
rem  tak samo: "Gotowe", a panelu nie ma. Teraz pytamy panel o stan i dopiero
rem  po odpowiedzi cokolwiek obiecujemy - a obok piszemy, kto odpowiedzial
rem  i od kiedy chodzi, zeby stary proces nie mogl udawac nowego.
echo   Sprawdzam, czy panel odpowiada...
call :czy_odpowiada
if errorlevel 1 goto nie_wstal

echo.
echo   Panel dziala: http://localhost:8125
call :kto_odpowiada
echo   Bedzie sie uruchamial sam po kazdym zalogowaniu do Windowsa, bez okna.
echo   To, co wypisuje, trafia do:
echo     %DOCEL%\panel.log
echo.
echo   Zeby to wylaczyc, uruchom _USUN-AUTOSTART.bat
echo   Aktualizacja: wrzucasz nowe pliki do tego folderu i klikasz ten plik.
echo.
pause
exit /b

:nie_wstal
echo.
echo   Panel nie odpowiada na porcie 8125. Ostatnie linijki z panel.log:
echo   ----------------------------------------------------------------
powershell -NoProfile -Command "$p=$env:DOCEL+'\panel.log'; if (Test-Path $p) { Get-Content $p -Tail 15 } else { '   (panel.log jeszcze nie powstal - python w ogole nie ruszyl)' }"
echo   ----------------------------------------------------------------
echo.
echo   Przeslij mi te linijki - to jest cala diagnoza, nie trzeba nic przepisywac.
echo.
rem  Log juz spisany, wiec reczny start niczego nie zaciera. A dom nie ma
rem  powodu czekac na to, az rozgryzie sie Harmonogram. Najpierw zwalniamy
rem  port - jesli trzyma go zawieszony panel, nowy odbilby sie od niego.
echo   Na teraz uruchamiam panel recznie...
call :zatrzymaj_panel
start "" "%PYTHONW%" pompa-acond.py panel
call :czy_odpowiada
if errorlevel 1 (
  echo   ...i to tez sie nie udalo. Odpal _URUCHOM-PANEL.bat dwuklikiem - w czarnym
  echo   oknie zobaczysz, na czym sie wywraca.
) else (
  echo   Panel dziala: http://localhost:8125  ^(ale sam po restarcie nie wstanie^)
)
echo.
pause
exit /b 1

:zle_miejsce
echo.
echo   Panel lezy w Pobranych. Windows potrafi sam czyscic ten folder, a razem
echo   z nim poszlaby cala zebrana historia pomiarow.
echo.
echo   Przenies caly folder na C:\PanelPompy i uruchom ten plik jeszcze raz.
echo.
pause
exit /b 1

:brak_pythona
echo.
echo   Nie znalazlem Pythona na tym komputerze (albo brakuje pythonw.exe).
echo.
echo   Pobierz go z:  https://python.org/downloads
echo   WAZNE: przy instalacji zaznacz "Add python.exe to PATH".
echo.
pause
exit /b 1

:blad_zadania
echo.
echo   Nie udalo sie zalozyc zadania w Harmonogramie. Jesli zadanie "Panel pompy"
echo   juz istnieje i zalozyl je administrator, to tylko administrator moze je
echo   zmienic - a wlasnie zmieniamy, na co ma wskazywac.
echo.
echo   Kliknij ten plik prawym przyciskiem i wybierz "Uruchom jako administrator".
echo   Wystarczy ten jeden raz; kolejne aktualizacje juz tego nie potrzebuja.
echo.
rem  Nie zostawiamy go z martwym panelem tylko dlatego, ze autostart sie nie
rem  udal. To dwie osobne sprawy: autostart dotyczy jutra, panel dzisiaj.
echo   Na teraz uruchamiam panel recznie, zeby dom nie zostal bez nadzoru...
start "" "%PYTHONW%" pompa-acond.py panel
call :czy_odpowiada
if errorlevel 1 (
  echo   ...i to tez sie nie udalo. Odpal _URUCHOM-PANEL.bat dwuklikiem.
) else (
  echo   Panel dziala: http://localhost:8125
)
echo.
pause
exit /b 1

rem  Jedno sprawdzenie w jednym miejscu. Dwie kopie tego samego warunku
rem  rozjechaly sie po dwoch dniach.
:sprawdz_zadanie
powershell -NoProfile -Command "$z=Get-ScheduledTask -TaskName $env:ZADANIE -ErrorAction SilentlyContinue; if (-not $z) { exit 1 }; $e=$z.Actions[0].Execute; $k=$z.Actions[0].WorkingDirectory; if ($e) { $e=$e.Trim('\"') }; if ($k) { $k=$k.Trim('\"').TrimEnd('\') }; if ($e -eq $env:PYTHONW -and $k -eq $env:DOCEL) { exit 0 } else { exit 1 }"
exit /b %errorlevel%

:port_zajety
echo.
echo   Port 8125 nadal jest zajety i nie umiem go zwolnic. Trzyma go:
call :kto_odpowiada
echo.
echo   Najprosciej: uruchom komputer ponownie. Po zalogowaniu panel wstanie
echo   sam - zadanie w Harmonogramie jest juz ustawione.
echo.
pause
exit /b 1

rem  Zatrzymanie, ktore sprawdza, czy sie udalo. 8.11 instalator zabijal
rem  procesy po nazwie polecenia, po cichu, i szedl dalej. Proces z 5.11
rem  przezyl, trzymal port, nowy panel odbil sie od zajetego portu - a test
rem  na koncu zapukal do starego i oglosil "Panel dziala". Teraz zabijamy
rem  takze to, co faktycznie trzyma port, i czekamy, az port bedzie wolny.
:zatrzymaj_panel
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*pompa-acond.py*panel*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }; foreach ($x in @(Get-NetTCPConnection -LocalPort 8125 -State Listen -ErrorAction SilentlyContinue)) { Stop-Process -Id $x.OwningProcess -Force -ErrorAction SilentlyContinue }; for ($i=0; $i -lt 20; $i++) { if (-not (Get-NetTCPConnection -LocalPort 8125 -State Listen -ErrorAction SilentlyContinue)) { exit 0 }; Start-Sleep -Milliseconds 500 }; exit 1"
exit /b %errorlevel%

rem  "Dziala" znaczy: /api/stan odpowiedzial w kilka sekund. Samo przyjecie
rem  polaczenia nie wystarcza - zawieszony panel z 5.11 przyjmowal je
rem  bez zarzutu, a potem milczal w nieskonczonosc.
:czy_odpowiada
powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; $t=[Diagnostics.Stopwatch]::StartNew(); while ($t.Elapsed.TotalSeconds -lt 25) { try { $o=Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:8125/api/stan' -TimeoutSec 5; if ($o.StatusCode -eq 200) { exit 0 } } catch { Start-Sleep -Milliseconds 750 } }; exit 1"
exit /b %errorlevel%

rem  Kto odpowiada na porcie i od kiedy. Godzina startu z dzisiaj to nowy
rem  panel; data sprzed dni to stary, ktory przezyl.
:kto_odpowiada
powershell -NoProfile -Command "$p=@(Get-NetTCPConnection -LocalPort 8125 -State Listen -ErrorAction SilentlyContinue); if ($p.Count -eq 0) { '    (nikt nie nasluchuje na 8125)' } else { foreach ($x in $p) { $g=Get-Process -Id $x.OwningProcess -ErrorAction SilentlyContinue; '    PID ' + $x.OwningProcess + '  ' + $g.ProcessName + ', uruchomiony ' + $g.StartTime } }"
exit /b 0
