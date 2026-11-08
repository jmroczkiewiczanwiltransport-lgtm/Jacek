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

> "%PLIK%" echo === DIAGNOZA PANELU POMPY ===
>>"%PLIK%" echo Kiedy : %DATE% %TIME%
>>"%PLIK%" echo Folder: %~dp0
>>"%PLIK%" echo.

>>"%PLIK%" echo --- 1. Procesy Pythona: kto zyje i od kiedy ---
powershell -NoProfile -Command "$w=Get-CimInstance Win32_Process | Where-Object { $_.Name -like 'python*' }; if ($w) { $w | ForEach-Object { 'PID {0,-7} start {1:yyyy-MM-dd HH:mm:ss}  {2}' -f $_.ProcessId, $_.CreationDate, $_.CommandLine } } else { 'ZADNEGO procesu Pythona - panel nie dziala wcale' }" >>"%PLIK%" 2>&1
>>"%PLIK%" echo.

>>"%PLIK%" echo --- 2. Kto trzyma port 8125 ---
powershell -NoProfile -Command "$p=Get-NetTCPConnection -LocalPort 8125 -State Listen -ErrorAction SilentlyContinue; if ($p) { $p | ForEach-Object { 'nasluchuje PID ' + $_.OwningProcess + ' (' + (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName + ')' } } else { 'NIKT - port 8125 jest wolny' }" >>"%PLIK%" 2>&1
>>"%PLIK%" echo.

>>"%PLIK%" echo --- 3. Zadanie w Harmonogramie ---
powershell -NoProfile -Command "$z=Get-ScheduledTask -TaskName 'Panel pompy' -ErrorAction SilentlyContinue; if ($z) { 'Uruchamia : ' + $z.Actions[0].Execute; 'Argumenty : ' + $z.Actions[0].Arguments; 'Katalog   : ' + $z.Actions[0].WorkingDirectory; 'Stan      : ' + $z.State; $i=Get-ScheduledTaskInfo -TaskName 'Panel pompy'; 'Ostatni bieg: ' + $i.LastRunTime + '   wynik: ' + $i.LastTaskResult } else { 'BRAK zadania o nazwie Panel pompy' }" >>"%PLIK%" 2>&1
>>"%PLIK%" echo.

>>"%PLIK%" echo --- 4. Co naprawde oddaje /api/stan ---
powershell -NoProfile -Command "try { $o=Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:8125/api/stan' -TimeoutSec 25; 'HTTP ' + $o.StatusCode; $t=$o.Content; 'dlugosc ' + $t.Length + ' znakow'; if ($t.Length -gt 6000) { $t.Substring(0,6000) + ' ...(uciete)' } else { $t } } catch { 'NIE ODPOWIEDZIAL: ' + $_.Exception.Message }" >>"%PLIK%" 2>&1
>>"%PLIK%" echo.

>>"%PLIK%" echo --- 5. Ostatnie 40 linijek panel.log ---
powershell -NoProfile -Command "if (Test-Path 'panel.log') { $f=Get-Item 'panel.log'; 'ostatni zapis ' + $f.LastWriteTime; '---'; Get-Content 'panel.log' -Tail 40 } else { 'brak panel.log' }" >>"%PLIK%" 2>&1
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
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*pompa-acond.py*panel*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }" >nul 2>&1

set "PYTHON=python"
python --version >nul 2>&1
if errorlevel 1 set "PYTHON=py"
set "PYTHONW="
for /f "delims=" %%P in ('%PYTHON% -c "import sys,os;print(os.path.join(os.path.dirname(sys.executable),'pythonw.exe'))" 2^>nul') do set "PYTHONW=%%P"

echo   Uruchamiam panel od nowa...
schtasks /Run /TN "Panel pompy" >nul 2>&1
if errorlevel 1 if exist "%PYTHONW%" start "" "%PYTHONW%" pompa-acond.py panel

powershell -NoProfile -Command "for ($i=0; $i -lt 24; $i++) { try { $g=New-Object Net.Sockets.TcpClient; $g.Connect('127.0.0.1',8125); $g.Close(); exit 0 } catch { Start-Sleep -Milliseconds 750 } }; exit 1"
if errorlevel 1 (
  if exist "%PYTHONW%" start "" "%PYTHONW%" pompa-acond.py panel
  powershell -NoProfile -Command "Start-Sleep -Seconds 6; try { $g=New-Object Net.Sockets.TcpClient; $g.Connect('127.0.0.1',8125); $g.Close(); exit 0 } catch { exit 1 }"
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
