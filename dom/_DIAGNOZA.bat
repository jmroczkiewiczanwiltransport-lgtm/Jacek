@echo off
chcp 65001 >nul
title Diagnoza panelu pompy
cd /d "%~dp0"
set "PLIK=%~dp0diagnoza.txt"

rem  Ten plik nie naprawia - on patrzy. Powstal, bo diagnoza panelu polegala
rem  na przepisywaniu polecen z PowerShella ze zrzutu ekranu, a to raz wklei
rem  sie dwa razy, raz utnie ogonek. Jeden dwuklik, jeden plik tekstowy.
rem
rem  Tresci logowanie.txt NIE czytamy - tylko sprawdzamy, czy jest i ile ma
rem  linijek. Haslo do sterownika nie ma po co trafiac do pliku, ktory potem
rem  wedruje przez czat.

echo.
echo   ============================================
echo     Diagnoza panelu pompy
echo   ============================================
echo.
echo   Zbieram. To tylko czyta - niczego nie zmienia.
echo.

set "PYTHON=python"
python --version >nul 2>&1
if errorlevel 1 set "PYTHON=py"

> "%PLIK%" echo === DIAGNOZA PANELU POMPY ===
>>"%PLIK%" echo Kiedy : %DATE% %TIME%
>>"%PLIK%" echo Folder: %~dp0
>>"%PLIK%" echo.

>>"%PLIK%" echo --- 1. Procesy Pythona: kto zyje i od kiedy ---
powershell -NoProfile -Command "$w=Get-CimInstance Win32_Process | Where-Object { $_.Name -like 'python*' }; if ($w) { $w | ForEach-Object { 'PID {0,-7} start {1:yyyy-MM-dd HH:mm:ss}  {2}' -f $_.ProcessId, $_.CreationDate, $_.CommandLine } } else { 'ZADNEGO procesu Pythona - panel nie dziala wcale' }" >>"%PLIK%" 2>&1
>>"%PLIK%" echo.

>>"%PLIK%" echo --- 2. Kto trzyma port 8125 ---
powershell -NoProfile -Command "$p=Get-NetTCPConnection -LocalPort 8125 -State Listen -ErrorAction SilentlyContinue; if ($p) { $p | ForEach-Object { $g=Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue; 'nasluchuje PID ' + $_.OwningProcess + ' (' + $g.ProcessName + '), uruchomiony ' + $g.StartTime } } else { 'NIKT - port 8125 jest wolny' }" >>"%PLIK%" 2>&1
rem  Stan watkow procesu na porcie. Gdy panel wisi, to rozstrzyga, czy stoi
rem  kod (watki czekaja na cos - Wait / UserRequest, Executive), czy caly proces
rem  wstrzymal ktos z zewnatrz (Wait / Suspended). Do tego, czy w tej chwili
rem  w ogole liczy cokolwiek - procesor przez dwie sekundy.
powershell -NoProfile -Command "foreach ($x in @(Get-NetTCPConnection -LocalPort 8125 -State Listen -ErrorAction SilentlyContinue)) { $g=Get-Process -Id $x.OwningProcess -ErrorAction SilentlyContinue; if ($g) { $c1=$g.CPU; Start-Sleep -Seconds 2; $g.Refresh(); 'watkow ' + $g.Threads.Count + ', uchwytow ' + $g.HandleCount + ', pamiec ' + [int]($g.WorkingSet64/1MB) + ' MB, procesor razem ' + [int]$g.CPU + ' s, przez ostatnie 2 s: ' + [math]::Round($g.CPU - $c1, 2) + ' s'; $g.Threads | Group-Object { if ($_.ThreadState -eq 'Wait') { [string]$_.ThreadState + ' / ' + [string]$_.WaitReason } else { [string]$_.ThreadState } } | Sort-Object Count -Descending | ForEach-Object { '   ' + $_.Count + ' x ' + $_.Name } } }" >>"%PLIK%" 2>&1
>>"%PLIK%" echo.

>>"%PLIK%" echo --- 3. Zadanie w Harmonogramie ---
powershell -NoProfile -Command "$z=Get-ScheduledTask -TaskName 'Panel pompy' -ErrorAction SilentlyContinue; if ($z) { 'Uruchamia : ' + $z.Actions[0].Execute; 'Argumenty : ' + $z.Actions[0].Arguments; 'Katalog   : ' + $z.Actions[0].WorkingDirectory; 'Stan      : ' + $z.State; $i=Get-ScheduledTaskInfo -TaskName 'Panel pompy'; 'Ostatni bieg: ' + $i.LastRunTime + '   wynik: ' + $i.LastTaskResult } else { 'BRAK zadania o nazwie Panel pompy' }" >>"%PLIK%" 2>&1
>>"%PLIK%" echo.

>>"%PLIK%" echo --- 4. Co naprawde oddaje /api/stan ---
powershell -NoProfile -Command "try { $o=Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:8125/api/stan' -TimeoutSec 25; 'HTTP ' + $o.StatusCode; $t=$o.Content; 'dlugosc ' + $t.Length + ' znakow'; if ($t.Length -gt 6000) { $t.Substring(0,6000) + ' ...(uciete)' } else { $t } } catch { 'NIE ODPOWIEDZIAL: ' + $_.Exception.Message }" >>"%PLIK%" 2>&1
>>"%PLIK%" echo.

>>"%PLIK%" echo --- 5. Ostatnie 150 linijek panel.log ---
powershell -NoProfile -Command "if (Test-Path 'panel.log') { $f=Get-Item 'panel.log'; 'ostatni zapis ' + $f.LastWriteTime; '---'; Get-Content 'panel.log' -Tail 150 } else { 'brak panel.log' }" >>"%PLIK%" 2>&1
>>"%PLIK%" echo.

>>"%PLIK%" echo --- 6. Czy historia rosnie ---
powershell -NoProfile -Command "foreach ($n in 'dane-pompy.csv','pogoda.csv','slonce.csv','kominek.csv','liczniki.csv') { if (Test-Path $n) { $f=Get-Item $n; '{0,-16} ostatni zapis {1}  {2} B' -f $n, $f.LastWriteTime, $f.Length } else { '{0,-16} BRAK' -f $n } }" >>"%PLIK%" 2>&1
powershell -NoProfile -Command "if (Test-Path 'dane-pompy.csv') { '--- 3 ostatnie wiersze dane-pompy.csv ---'; Get-Content 'dane-pompy.csv' -Tail 3 }" >>"%PLIK%" 2>&1
>>"%PLIK%" echo.

>>"%PLIK%" echo --- 7. Wersje plikow panelu ---
powershell -NoProfile -Command "foreach ($n in 'pompa-acond.py','panel-pompy.html','_URUCHOM-PANEL.bat','_ZAINSTALUJ-AUTOSTART.bat','przypomnienia.json','slonce.json','opisy-panelu.json') { if (Test-Path $n) { $f=Get-Item $n; '{0,-28} {1}  {2} B' -f $n, $f.LastWriteTime, $f.Length } else { '{0,-28} BRAK' -f $n } }" >>"%PLIK%" 2>&1
>>"%PLIK%" echo.

>>"%PLIK%" echo --- 7b. Ustawienia automatu (slonce.json) ---
powershell -NoProfile -Command "if (Test-Path 'slonce.json') { Get-Content 'slonce.json' } else { 'BRAK slonce.json - automat sloneczny nie dziala wcale' }" >>"%PLIK%" 2>&1
>>"%PLIK%" echo.

>>"%PLIK%" echo --- 8. Sterownik: adres i logowanie ---
powershell -NoProfile -Command "if (Test-Path 'adres-pompy.txt') { 'adres-pompy.txt:'; Get-Content 'adres-pompy.txt' } else { 'brak adres-pompy.txt' }" >>"%PLIK%" 2>&1
powershell -NoProfile -Command "if (Test-Path 'logowanie.txt') { 'logowanie.txt: jest, niepustych linijek: ' + @(Get-Content 'logowanie.txt' | Where-Object { $_.Trim() }).Count } else { 'logowanie.txt: BRAK - panel nie zaloguje sie do sterownika' }" >>"%PLIK%" 2>&1
>>"%PLIK%" echo.

>>"%PLIK%" echo --- 9. Siec ---
powershell -NoProfile -Command "Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notlike '127.*' } | ForEach-Object { 'ten komputer: ' + $_.IPAddress + ' (' + $_.InterfaceAlias + ')' }" >>"%PLIK%" 2>&1
powershell -NoProfile -Command "try { $a=(Get-Content 'adres-pompy.txt' -ErrorAction Stop)[0]; $h=([Uri]$a).Host; if (Test-Connection -ComputerName $h -Count 1 -Quiet -ErrorAction SilentlyContinue) { 'sterownik ' + $h + ' odpowiada na ping' } else { 'sterownik ' + $h + ' NIE odpowiada na ping' } } catch { 'nie wiem, pod jakim adresem jest sterownik' }" >>"%PLIK%" 2>&1


rem  Pogoda 1.11 i 8.11 nie wstala przez dlugie minuty po starcie, z bledem
rem  getaddrinfo - komputer nie zamienial nazwy api.open-meteo.com na adres.
rem  Przegladarka tego nie zdradzi, bo ma wlasny DNS przez HTTPS. Tu pytamy
rem  osobno Windowsa i osobno Pythona, a potem probujemy pobrac prognoze
rem  swiezym procesem. Wspolrzedne ogolne (srodek Polski), nie adres domu.
>>"%PLIK%" echo.
>>"%PLIK%" echo --- 10. Pogoda: czy ten komputer siega do Open-Meteo ---
powershell -NoProfile -Command "try { $r=@(Resolve-DnsName api.open-meteo.com -Type A -DnsOnly -ErrorAction Stop | Where-Object { $_.IPAddress }); 'DNS Windows : ' + ($r.IPAddress -join ', ') } catch { 'DNS Windows : BLAD - ' + $_.Exception.Message }" >>"%PLIK%" 2>&1
%PYTHON% -I -c "import socket; print('DNS Python  : ' + ', '.join(sorted({a[4][0] for a in socket.getaddrinfo('api.open-meteo.com', 443)})))" >>"%PLIK%" 2>&1
%PYTHON% -I -c "import time, urllib.request; t=time.time(); r=urllib.request.urlopen('https://api.open-meteo.com/v1/forecast?latitude=52&longitude=19&current=temperature_2m', timeout=15); print(f'HTTPS Python: HTTP {r.status} w {time.time()-t:.1f} s')" >>"%PLIK%" 2>&1
powershell -NoProfile -Command "Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object { $_.ServerAddresses } | ForEach-Object { 'serwery DNS : ' + $_.InterfaceAlias + ' -> ' + ($_.ServerAddresses -join ', ') }" >>"%PLIK%" 2>&1
powershell -NoProfile -Command "Get-NetIPInterface -AddressFamily IPv4 -ConnectionState Connected | Sort-Object InterfaceMetric | ForEach-Object { 'karta       : ' + $_.InterfaceAlias + ', metryka ' + $_.InterfaceMetric }" >>"%PLIK%" 2>&1
powershell -NoProfile -Command "$p=Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'; if ($p.ProxyEnable) { 'proxy       : ' + $p.ProxyServer } else { 'proxy       : brak' }" >>"%PLIK%" 2>&1
powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; try { $d=(Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:8125/api/stan' -TimeoutSec 10).Content | ConvertFrom-Json; if ($d.pogoda.blad) { 'panel mowi  : ' + $d.pogoda.blad } elseif ($d.pogoda) { 'panel mowi  : prognoza jest, sprzed ' + $d.pogoda.sprzed + ' s' } else { 'panel mowi  : brak pogody' } } catch { 'panel mowi  : nie odpowiada' }" >>"%PLIK%" 2>&1

echo   Gotowe. Otwieram diagnoza.txt - przeslij mi calosc.
echo.
start "" notepad "%PLIK%"

echo   ============================================
echo.
echo   Diagnoza jest juz zapisana, wiec teraz moge bezpiecznie
echo   zatrzymac wszystko, co udaje panel, i uruchomic go od nowa.
echo.
pause

echo.
echo   Zatrzymuje stare procesy panelu...
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*pompa-acond.py*panel*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }; foreach ($x in @(Get-NetTCPConnection -LocalPort 8125 -State Listen -ErrorAction SilentlyContinue)) { Stop-Process -Id $x.OwningProcess -Force -ErrorAction SilentlyContinue }; for ($i=0; $i -lt 20; $i++) { if (-not (Get-NetTCPConnection -LocalPort 8125 -State Listen -ErrorAction SilentlyContinue)) { exit 0 }; Start-Sleep -Milliseconds 500 }; exit 1" >nul 2>&1
if errorlevel 1 echo   UWAGA: port 8125 dalej zajety - uruchom komputer ponownie.

set "PYTHON=python"
python --version >nul 2>&1
if errorlevel 1 set "PYTHON=py"
set "PYTHONW="
for /f "delims=" %%P in ('%PYTHON% -c "import sys,os;print(os.path.join(os.path.dirname(sys.executable),'pythonw.exe'))" 2^>nul') do set "PYTHONW=%%P"

echo   Uruchamiam panel od nowa...
schtasks /Run /TN "Panel pompy" >nul 2>&1
if errorlevel 1 if exist "%PYTHONW%" start "" "%PYTHONW%" pompa-acond.py panel

powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; $t=[Diagnostics.Stopwatch]::StartNew(); while ($t.Elapsed.TotalSeconds -lt 25) { try { $o=Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:8125/api/stan' -TimeoutSec 5; if ($o.StatusCode -eq 200) { exit 0 } } catch { Start-Sleep -Milliseconds 750 } }; exit 1"
if errorlevel 1 (
  if exist "%PYTHONW%" start "" "%PYTHONW%" pompa-acond.py panel
  powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; $t=[Diagnostics.Stopwatch]::StartNew(); while ($t.Elapsed.TotalSeconds -lt 25) { try { $o=Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:8125/api/stan' -TimeoutSec 5; if ($o.StatusCode -eq 200) { exit 0 } } catch { Start-Sleep -Milliseconds 750 } }; exit 1"
)
if errorlevel 1 (
  echo.
  echo   Panel nadal nie odpowiada na porcie 8125. Odpal _URUCHOM-PANEL.bat
  echo   dwuklikiem - w czarnym oknie zobaczysz, na czym sie wywraca.
) else (
  echo.
  echo   Panel dziala: http://localhost:8125
)
echo.
pause
