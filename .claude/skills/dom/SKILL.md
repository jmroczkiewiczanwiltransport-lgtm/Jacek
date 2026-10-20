---
name: dom
description: Instalacja domowa Jacka — pompa ciepła ACOND THERM, fotowoltaika na net-billingu, rozliczenia z Eneą, oświetlenie Hue i Tuya. Wczytaj to, zanim ruszysz cokolwiek w katalogach dom/, hue/ albo tuya/, albo gdy rozmowa dotyczy ogrzewania, rachunków za prąd, harmonogramów pompy czy paneli sterowania w domu.
---

# Dom — pompa ciepła, fotowoltaika, oświetlenie

Temat rozłożony na cały rok: sezon grzewczy 2026/27 ma być tańszy niż poprzedni.
Ten plik jest pamięcią między rozmowami — czytaj go w całości, zanim zaczniesz,
i **dopisuj do niego ustalenia**, zwłaszcza te, które kosztowały godzinę dochodzenia.

Rozmawiamy po polsku. Kod, komentarze, komunikaty i nazwy zmiennych też są po polsku
— to konwencja całego repozytorium, nie ozdobnik.

## Sprzęt i adresy

| Co | Adres | Uwagi |
|---|---|---|
| Pompa ciepła ACOND THERM | adres z DHCP, **zmienny**: bywało `.9`, `.8`, `.23`, od 20.10.2026 `.10` | MAC **`f8:dc:7a:7d:24:89`** (ETH2 „w rogu", DYNAMIC IP) — po nim się ją znajduje; sterownik Tecomat Foxtrot, sw 160.36. **ETH1 „pośrodku", MAC `f8:dc:7a:7d:24:88`, `192.168.134.176` FIXED — osobna sieć serwisowa, nie ruszać.** Adres zmienia się po każdym zaniku prądu, bo router rozdaje pulę od nowa |
| Mostek Philips Hue | **adres nieznany** (był `.10`, ale 20.10.2026 pod tym adresem stanęła pompa) | sparowany, klucz w `~/.hue-most.json`; do ustalenia na nowo |
| Komputer stacjonarny (Acer, Windows 11, użytkownik `jacek`) | `192.168.88.22` | **tu od 18.10.2026 chodzi monitoring**; Python 3.15 w `AppData\Local\Python\pythoncore-3.15-64` |
| Komputer Jacka (Windows 11) | `192.168.88.18` | laptop, bywa poza domem; od 18.10 już nie zbiera |
| Router | `192.168.88.1` | najpewniej MikroTik (adresacja .88.x) |
| Falownik Huawei SUN2000 | — | **nie jest w sieci**, patrz niżej |

Ogrzewanie: podłogówka w całym domu plus grzejnik elektryczny w łazience.
Taryfa **G11**. Fotowoltaika rozliczana **net-billingiem**, umowa od stycznia 2026
— danych sprzed tej daty nie ma i nie będzie.

## Jak czytać pompę

Sterownik oddaje wszystkie wartości wprost w `PAGE115.XML`, jako
`<INPUT NAME="__T<skrót>_<typ>_<format>" VALUE="…"/>`. Skróty są stałe, dopóki nie
zmieni się program sterownika. Rozpoznane zmienne siedzą w `dom/opisy-panelu.przyklad.json`
(rozpoznane przez porównanie dwóch odczytów o różnych porach: wartości mierzone
dryfują, nastawy nie).

```bash
python3 dom/pompa-acond.py strona http://192.168.88.9/PAGE115.XML
python3 dom/pompa-acond.py panel  http://192.168.88.9/PAGE115.XML
```

Login i hasło idą z pliku `dom/logowanie.txt` (nazwa użytkownika w pierwszej linijce,
hasło w drugiej; w `.gitignore`, **nigdy nie proś o jego treść**).

## Ustalenia, które kosztowały najwięcej czasu

**Logowanie do sterownika jest nieoczywiste.** Hasło nie idzie otwartym tekstem.
Formularz (`SYSWWW/LOGIN.XSL` + `SHA1.JS` → `ProccessLogin`) wysyła
`SHA-1(numer_sesji + hasło)` jako pole `PASS`, POST-em na `SYSWWW/LOGIN.XML`.
Numer sesji (ciasteczko `SoftPLC`) jest inny za każdym razem, **więc podsłuchanego
skrótu ani ciasteczka nie da się zapamiętać na stałe** — trzeba przechodzić całą
procedurę. `pompa-acond.py` robi to sam w `zaloguj()`. Nie wracaj do pomysłu
z zapisywaniem ciasteczka; to była ślepa uliczka, po której zostało tylko awaryjne
`--ciasteczko`.

**Na laptopie Jacka działa VPN z adresem `26.x`.** Pytanie systemu „jakim adresem
wychodzę na świat" zwracało właśnie ten adres, więc panel wypisywał go jako adres
do wpisania w telefonie — i telefon nigdy nie mógł trafić. `_adres_lokalny()`
wybiera teraz spośród adresów RFC 1918. Warto o tym pamiętać przy każdej diagnozie
sieciowej na tym komputerze.

**Sterownika szuka się po MAC-u, nie po adresie.** Adres zmieniał się już trzy
razy (`.9` → `.8` → `.23`). We wrześniu 2026 doszło do tego, że pod starym adresem
odpowiadał ping, ale żaden port nie był otwarty — bo adres przejęło inne
urządzenie. Rozstrzygnęło dopiero `arp -a | findstr /i "f8-dc-7a"`. Zaczynaj od
tego, zanim zaczniesz podejrzewać awarię pompy, zaporę albo swój kod.

**Adres sterownika się zmienia.** ETH2 stoi na DHCP i router przydzielił mu we
wrześniu 2026 `.8` zamiast `.9`. Objawy wyglądają jak awaria pompy: panel milczy,
historia się urywa, sterowanie nie działa. Zanim zaczniesz szukać czegokolwiek
innego, sprawdź adres — na sterowniku widać go na ekranie „Info ETH2".
`pompa-acond.py` radzi sobie z tym sam (skanuje sieć, rozpoznaje po
`SYSWWW/LOGIN.XML`, zapamiętuje w `adres-pompy.txt`), ale rezerwacja w routerze
nadal jest niezrobiona i to ona rozwiązałaby sprawę u źródła.

**Zapis do sterownika idzie impulsami, nie wartościami.** Panel sterownika przy
kliknięciu „+" wysyła POST na `PAGE115.XML` z treścią `__TCA37B6A0_BOOL_i=1`
(„−" to `__TF795EE37_BOOL_i=1`). Nowej wartości nie przekazuje wcale — sterownik
sam przesuwa nastawę o 0,1 °C i sam pilnuje swoich granic. Dlatego skok z 15,3
na 21,0 to blisko sześćdziesiąt impulsów, a nie jeden zapis. Nazwy kolejnych
przycisków (CWU, harmonogramy, tryb urlopowy) trzeba podejrzeć tak samo:
F12 → Network → filtr `method:POST` → kliknąć raz → zakładka Payload.

**Modbus TCP w pompie nie działa.** Port 502 jest otwarty, ale sterownik nim nie mówi
— wszystkie jednostki (0, 1, 2, 3) dają timeout. Serwer Modbus nie jest uruchomiony
w programie sterownika. Nie próbuj tej drogi jeszcze raz; czytanie ze strony WWW
daje komplet danych i wystarcza.

**Falownik nie jest podpięty do sieci.** Skan `python3 dom/falownik-huawei.py 192.168.88.0/24`
znajduje tylko pompę. Jacek nigdy nie widział produkcji z paneli — wszystkie liczby,
którymi operujemy, pochodzą z licznika Enei. Podpięcie falownika wymagałoby dongla
i konfiguracji przez FusionSolar; **zimą i tak nic by nie pokazał**, więc to temat
na wiosnę, nie priorytet.

**`hue/panel.html` otwarty z dysku nigdy nie zadziała.** Strona z `file://` nie ma
prawa odpytywać urządzenia w sieci — akceptacja certyfikatu mostka tego nie zmienia.
Jedyna działająca droga to `node hue.mjs panel`.

## Co jest uruchomione u Jacka

- **Panel pompy** — `%LOCALAPPDATA%\PanelPompy`, autostart przy logowaniu do Windowsa,
  bez okna terminala (VBS w Autostarcie). Port **8125**. Zapisuje odczyt do
  `dane-pompy.csv` co 5 minut, własnym wątkiem, niezależnie od ruchu na stronie.
  Aktualizacja: pobrać paczkę, kliknąć `_ZAINSTALUJ-AUTOSTART.bat` — pliki użytkownika
  i historia przeżywają.
- **Panel Hue** — port **8123**, uruchamiany ręcznie (`node hue.mjs panel --w-sieci`),
  żyje tylko z otwartym oknem terminala.
- Reguły zapory dla obu portów są założone, profil prywatny.

Jacek nie jest programistą. Podawaj gotowe komendy do wklejenia, jedną naraz, i mów,
czego się spodziewać po każdej. Nie zakładaj, że wie, gdzie jest terminal ani czym
różni się folder od paczki.

## Co mówią dane

Analiza godzinowa z Enei (`dom/prad-enea.py`, dane 01–08.2026):

**Zimą cztery piąte rachunku to pompa.** Metoda: nocą fotowoltaika nie produkuje, więc
pobór z sieci = całe zużycie domu. Najniższe letnie noce dają zużycie bazowe domu
**0,195 kWh/h ≈ 4,7 kWh/dobę**. Reszta to ogrzewanie.

| miesiąc | pobór | z tego pompa | udział |
|---|---|---|---|
| styczeń | 1228 kWh | ~1083 kWh | 88 % |
| luty | 704 kWh | ~573 kWh | 81 % |
| marzec | 282 kWh | ~137 kWh | 49 % |
| kwiecień | 209 kWh | ~68 kWh | 33 % |

Ta sama godzina nocna: latem 0,29 kWh/h, w styczniu 0,77, w lutym 0,84.

**Rachunek robi się w styczniu i lutym** — 67 % rocznego poboru. Wszystko poza pompą
to margines; oszczędzanie na oświetleniu czy czuwaniu nie zmieni tu nic.

**Fotowoltaika zimą nie pomoże.** Styczeń 2026: oddane 13 kWh przy pobranych 1228.
Zima była ostra i panele stały zasypane śniegiem — Jacek uważa, że to się nie powtórzy
w takim stopniu, więc nie wyciągaj z tego jednego stycznia wniosków o typowej zimie.
Odśnieżanie paneli ma sens: kilowatogodzina ze stycznia była warta 0,68 zł, z lipca 0,00.

**Gra toczy się o sezon przejściowy** — marzec, kwiecień, październik, listopad. Wtedy
jest i słońce, i zapotrzebowanie na ciepło.

## Decyzje i dlaczego

Pełny zapis w `dom/ustawienia-pompy.md` — **zawsze go przeczytaj** przed zmianami
w sterowniku i **dopisz** każdą zmianę.

Skrótowo:

- **Zostajemy na G11.** Zimą tylko 31 % poboru wypada w tanich godzinach G12
  i 51 % w G12w, przy progu opłacalności ok. 55 %.
- **Harmonogramy CWU i temperatury wody grzewczej: 10:00–16:00, wszystkie dni.**
  Były skonfigurowane fabrycznie, ale **wyłączone** — włączenie ich było największym
  pojedynczym zyskiem w całej pracy. Zastane godziny startowały o 12:00 i przesypiały
  szczyt produkcji (najwięcej energii szło do sieci o 10, 11 i 12).
- **Harmonogram temperatury pokojowej zostaje wyłączony.** Przy podłogówce głębokie
  obniżenia szkodzą: jastrych stygnie godzinami, a potem pompa odrabia to dużą mocą
  przy gorszym COP.
- **Bez HDO/SG Ready** — harmonogramy w pompie robią to samo bez ingerencji w instalację.
- **Bez automatyki reagującej na rzeczywistą nadwyżkę** — dopóki nie wiadomo, jak często
  podbicie w południe trafia w dzień pochmurny. Do tego potrzebne są dane z zimy.

## Harmonogramy w sterowniku — stan odczytany 17.10.2026

Strony sterownika (zalogowany, `http://192.168.88.23`): ikona **zegara** w lewym
górnym rogu prowadzi do harmonogramów, **termometr** do krzywej grzewczej,
**wykres** do historii ostatniej doby.

| Harmonogram | Strona | Stan | Godziny | Wartość |
|---|---|---|---|---|
| Temperatury wody grzewczej | `PAGE117.XML` | **włączony** | codziennie **11:00–16:00** | 45,0 °C |
| Blokada ogrzewania CWU poza harmonogramem | `PAGE118.XML` | **włączona** | codziennie **11:00–16:00** | CWU 45,0 °C |
| Temperatury pokojowej (obieg 1) | — | **wyłączony** | stare okna wieczorne, patrz niżej | 19,0–20,0 °C |

**Okna przesunięte z 10:00 na 11:00 dnia 18.10.2026.** O dziesiątej w październiku
panele dopiero ruszają — ta godzina była grzaniem z sieci. Koniec został na 16:00.
Jeżeli zmieniasz te godziny, zmień też `OKNO_GRZANIA` w `dom/pompa-acond.py`,
bo kafel „Słońce" liczy sumę promieniowania dokładnie dla tego okna.

**Strona z harmonogramem pokojowym wygląda myląco jak ta z wodą grzewczą.**
Rozpoznaje się je po wierszu TEMPERATURE: **45,0** to woda grzewcza, **19–20**
to pokój. Pokojowego nie włączać — ma w sobie stare okna i nadpisałby nastawę.

To jest celowa „przerzutka na południe": całe grzanie — i wody użytkowej, i
podłogi — zepchnięte do okna, w którym pracują panele. Działa.

**Stare okna w wyłączonym harmonogramie pokojowym** (gdyby kiedyś go włączać,
najpierw wyzerować): pon 16–18 / wt 14–18 / śr 5–7 i 16–18 / czw 5–7 i 16–18 /
pt 16–18 / sob 13–17 / nd 6–9.

**Krzywa grzewcza** (strona 126) — i to jest najważniejsza rzecz o tym
sterowniku: tytuł strony brzmi **RETURN WATER TEMPERATURE DEPENDING ON OUTDOOR
TEMPERATURE**. Krzywa ustala temperaturę **wody wracającej z podłogi**, nie
wyjściowej.

| Na dworze | Powrót ma mieć |
|---|---|
| −15 °C | 38,0 °C |
| −5 °C | 34,0 °C |
| +5 °C | 30,0 °C |
| +15 °C | 24,0 °C |

Nisko i dobrze — przy podłogówce niska woda to wysoki COP. Powyżej +15 °C
sterownik najwyraźniej **przedłuża ostatni odcinek**, a nie przycina na 24 °C
(tak wychodzi z dopasowania do danych z 19.10; gdyby przycinał, pompa grzałaby
w południe, a stała).

Nastawa pokojowa **przesuwa** wynik krzywej, nie zastępuje go. 19.10 o 20:24:
krzywa dawała 27,9 °C, a „wymagana" na stronie głównej 22,8 — bo w domu było
21,0 przy nastawie 20,5. Pompa moduluje moc tak, żeby powrót trzymał tę
wartość; nie jest to prosty termostat włącz/wyłącz.

**NIGHT DROP wpisany 22:00–06:00, ale obniżenie 0,0 °C**, czyli nie działa.
Tak ma zostać.

**Antysepsa (antylegionella) jest włączona** — widać ją na wykresie sterownika
jako osobny cykl CWU do ~55 °C (19.10 o 14:07). Kosztuje około kilowatogodziny.
Zostawić; przy zbiorniku na 45 °C to realne zabezpieczenie sanitarne.

**Antysepsa (antylegionella) jest dozwolona** — do sprawdzenia, jak często
startuje, bo dojście zbiornika do 60–65 °C wymaga grzałki elektrycznej.

### Czujnik zewnętrzny stoi w słońcu

17.10 pokazał **6,7 °C o 8:08 i 17,4 °C o 12:15**, przy średniej dobowej 11,5 °C.
Jedenaście stopni skoku w cztery godziny w połowie października to nie powietrze,
tylko nasłoneczniona obudowa.

To działa **przeciwko** strategii południowej: sterownik dobiera temperaturę wody
po tym odczycie, więc im mocniej świeci, tym bardziej odpuszcza — dokładnie wtedy,
gdy prąd jest z dachu.

**19.10 zmierzone co do minuty.** Czujnik poszedł z 11,6 do 19,6 °C, krzywa
obniżyła żądany powrót z 26,0 do 21,2 °C — czyli do poziomu wody, która akurat
wracała z podłogi. Sterownik uznał, że jest dobrze, i **stał 55 minut, od 11:47
do 12:42**. O 12:47 czujnik spadł do 15,8, żądanie podskoczyło do 23,5 i pompa
ruszyła w tej samej minucie. Koszt: około 1 kWh przeniesionej ze słońca do
wieczornej sieci, czyli ~90 gr w pogodny dzień.

Sprawdzona i **odrzucona** inna hipoteza: że to przekroczenie progu „koniec
sezonu grzewczego" (14,0 °C). 18.10 czujnik był ponad progiem od 11:24 do 14:00
i pompa grzała normalnie. Mechanizm idzie przez krzywą, nie przez próg.

**Ściana jest południowa** — maksimum odczytu wypada o 12:00–12:22, czyli pół
godziny po górowaniu słońca. Ściana zachodnia dałaby szczyt koło 16:00.
Do sprawdzenia, gdzie dokładnie wisi; powinien być od północy, w cieniu.

### Pogoda w panelu — Open-Meteo, model ICON-D2

Od 18.10 panel pobiera co kwadrans temperaturę, zachmurzenie i promieniowanie
słoneczne z Open-Meteo (bez klucza, bez rejestracji). Model **icon_d2** — DWD,
siatka 2 km, obejmuje Polskę; przy prognozie dalej niż dwie doby serwis sam
schodzi na grubszą siatkę.

Po co: temperatura z modelu stoi w kafelku obok odczytu czujnika, więc błąd
nasłonecznionej obudowy widać na bieżąco; suma promieniowania w oknie
11:00–16:00 mówi **rano**, czy południowe podbicie pójdzie z dachu, czy z sieci
(dane Enei przychodzą dopiero po 2–3 dniach). Progi oceny: ≥ 2,0 kWh/m² to
dzień pogodny, ≤ 0,9 pochmurny.

Współrzędne domu leżą w `dom/pogoda.json` — **gitignore, bo repozytorium jest
publiczne**. Adres ulicy nie wchodzi do repozytorium w żadnej postaci.

Pobiera osobny wątek; `/api/stan` oddaje tylko ostatni udany odczyt z jego
wiekiem, więc martwe łącze do Open-Meteo nigdy nie blokuje otwarcia panelu.

### Zanik prądu — co się wtedy dzieje (20.10.2026, 16:00–18:30)

Sprawdzone w praktyce, bo zdarzyło się po raz pierwszy od uruchomienia
monitoringu:

1. **Panel nie wstaje sam** — autostartu nie ma, trzeba ręcznie uruchomić
   `_URUCHOM-PANEL.bat`. Dziura w `dane-pompy.csv` na cały czas przerwy.
2. **Komputer może wrócić bez sieci.** Panel wypisał wtedy
   `getaddrinfo failed`, `nie wiem, w jakiej jestem sieci` i podstawił
   `http://ten-komputer:8125` zamiast adresu. To nie jest awaria panelu —
   po powrocie Wi-Fi wraca sam, nie trzeba go restartować.
3. **Wszystkie adresy w domu się przetasowują.** Nie tylko pompa — 20.10
   stacjonarny przeszedł z `.22` na `.17`, a pompa przez wieczór pokazywała
   kolejno `.4` i `.10`. Panel odnajduje sterownik po MAC-u, ale strona
   sterownika w przeglądarce jest pod nowym numerem. Nowy adres najszybciej
   odczytać **wprost z wyświetlacza na ścianie**: menu → Info ETH2 (ten
   „w rogu").

**Najważniejsza lekcja z tego wieczoru — moja, nie Jacka.** Przeszukanie sieci
wskazało poprawnie `192.168.88.10`. Ja uznałem to za pomyłkę, bo w tej tabeli
pod `.10` miałem zapisany mostek Hue. **Zaufałem własnej notatce sprzed tygodnia
zamiast świeżemu pomiarowi** — a po zaniku prądu notatka była już nieaktualna.
Skutek: Jacek restartował pompę bezpiecznikiem i szukał nieistniejących portów
przez godzinę.

Po zaniku prądu **cała ta tabela jest podejrzana, dopóki się jej nie sprawdzi**.
Kolejność zaufania: wyświetlacz na ścianie → `arp -a` → `Test-NetConnection` →
dopiero na końcu notatki.

**Dwie rzeczy, które to zamkną:** rezerwacje adresów w routerze oraz autostart
panelu plus ustawienie w BIOS-ie „włącz po przywróceniu zasilania".

## Kalendarz

Zadania siedzą w `dom/przypomnienia.json`, panel pokazuje najbliższe trzy,
`dom/przypomnienia.py` robi z nich plik `.ics` do kalendarza w telefonie.

Najbliższe: 6 września (sprawdzić ciepłą wodę wieczorem), 20 września (podnieść nastawę
pokojową z letnich 15,3 °C na ok. 21 °C), 1 października (spisać liczniki),
1 grudnia (wyłączyć harmonogram wody grzewczej), 1 marca (włączyć z powrotem).

## Jak Jacek mieszka i co z tego wynika

**Wychodzi ~8:00, wraca ~18:00.** Okno 10–16, w którym grzejemy z własnego prądu,
wypada w pustym domu — więc przegrzanie jastrychu w południe **nic nie kosztuje
w komforcie**. To najmocniejszy argument za podbiciem nastawy pokojowej na te
godziny (np. 22 °C w oknie, 21 poza nim) i jednocześnie powód, dla którego panel
na jego laptopie nie zbierze danych z 8–18: laptop wyjeżdża razem z nim.

**Kominek 18:00–23:00**, tylko w salonie, bez rozprowadzenia na inne pomieszczenia.
Czujnik pokojowy jest ~6 m od niego i podbija się do 23 °C. Skutek: wieczorem
sterownik uznaje, że dom jest nagrzany, i **wyłącza grzanie całego domu** — także
sypialni, które z kominka nie dostają nic. Po 23:00, gdy ogień gaśnie, pompa
nadrabia w nocy, przy najgorszym COP. Strata w pieniądzach umiarkowana, strata
w komforcie większa. Rozważane: przeniesienie czujnika do pomieszczenia
neutralnego albo oparcie regulacji na krzywej grzewczej.

**Nastawa pokojowa podniesiona 20.09.2026 z letnich 15,3 na 21 °C.**

## Sieć domowa

Router: **TP-Link HX520** (Aginet, mesh AP), `192.168.88.1`, MAC `0c:ef:15:88:5a:4b`,
WiFi `TP-Link_5A4B`. Do tego wzmacniacz **RE205** (`5c:a6:e6:67:02:62`).
**Hasła do panelu routera nikt nie zna** — nie ma go na naklejce, ustawił je ten,
kto konfigurował sieć (adresacja `192.168.88.x` nie jest fabryczna dla TP-Linka).
Bez hasła nie ma rezerwacji DHCP, więc adresy będą się przesuwać dalej.
**Nie resetuj routera** — padłoby WiFi i wszystkie urządzenia dostałyby nowe adresy naraz.

Na laptopie działa VPN z bramą `26.0.0.1` obok domowej `192.168.88.1`. Przy
diagnozie sieciowej sprawdzaj, czy narzędzie nie patrzy na ten adres.

Zamiast listy dzierżaw z routera używaj **`dom/siec.py`** — przeczesuje sieć
i wypisuje adresy, MAC-i i otwarte porty.

### Domofon Hikvision

| Urządzenie | Adres | Uwagi |
|---|---|---|
| Monitor **DS-KH6320-WTE1** | `192.168.88.8` (statyczny) | MAC `a4:d5:c2:41:08:6e`, firmware V2.2.96 |
| Stacja przy furtce **DS-KV8113-WME1(C)** | `192.168.88.210` | nr seryjny `FW5799425`, firmware V2.2.65 build 231213, **do przestawienia na statyczny** |

Urządzenie pod `192.168.88.18` (MAC `a4:e8:8d:31:19:97`, porty 554 i 8000) to
**nie** stacja przy furtce — prawdopodobnie osobna kamera, do zidentyfikowania.
Wcześniejsza hipoteza, że stacja przeniosła się na `.18`, była błędna: kreator
monitora sam wykrył stację pod `.210`, czyli pod adresem, który monitor miał
wpisany od początku.

Błąd **10200** na monitorze i „urządzenie offline" w aplikacji: obraz wrócił
dopiero po tym, jak Jacek zresetował monitor do ustawień fabrycznych (wbrew
ostrzeżeniu) i przeszedł kreator od nowa. W kreatorze, na ekranie **8/9
„Ustawienia panelu wejściowego"**, monitor sam znajduje stację — trzeba ją
zaznaczyć i zatwierdzić, nie wpisywać adresu ręcznie. Po resecie monitor wraca
na `192.168.88.64` albo `192.168.1.64`; własny adres ustawia się w kroku 3/9
(„Lokalny adres IP") — uwaga, żeby nie wpisać tam adresu innego urządzenia.

Poza kreatorem adres stacji poprawia się w: **Zarządzanie urządzeniami →
Główny panel wejściowy (Seria D)**. Pola są wyszarzone, dopóki nie wejdzie się
w tryb konfiguracji (ikona klucza na prawym pasku, hasło fabryczne `888999` —
osobne od hasła `admin` do panelu WWW).

Rozpoznawanie urządzeń: port **554 (RTSP)** i **8000** to kamery i domofony.
Do zmiany adresów służy **SADP** Hikvisiona (instalator potrafi sypnąć „NSIS
Error" — trzeba rozpakować cały ZIP poza OneDrive). **Nie resetuj** monitora ani
stacji — kasuje to powiązania, kody otwierania i konta.

### Skrzynka z alarmem i siecią domofonu

W jednej zamkniętej obudowie:

| Element | Model | Uwagi |
|---|---|---|
| Centrala alarmu | **SATEL INTEGRA 64** | transformator Pulsar **AWT682**, 60 VA |
| Moduł sieciowy alarmu | **SATEL ETHM-1** | zgłaszał „Brak kabla" i „Brak poł. SATEL2" |
| Switch PoE | **Hikvision DS-3E0106P-E/M(B)** | 5 gniazd, budżet PoE 35 W |
| Akumulator | **ALARMTEC BP18-12**, 12 V 18 Ah | data **2023**, centrala resetuje się przy zaniku 230 V |

**Mapa gniazd switcha** (ustalona 28.09.2026 przez wypinanie kabli i obserwację
pingów — metoda działa bezbłędnie, powtórzyć w razie wątpliwości):

| Gniazdo | Co |
|---|---|
| 1 | monitor domofonu `192.168.88.8` |
| 2 | stacja przy furtce `192.168.88.210` — **28.09 przełożona do gniazda 3** |
| 3 | wolne / po przełożeniu: stacja |
| 4 | moduł ETHM-1 alarmu |
| 5 UPLINK | do routera; **wtyk zrobiony fatalnie** — klej, wystające żyłki, do przerobienia |

### Domofon — objaw i co już wykluczono

**Objaw.** Stacja `.210` znika z sieci, nie wraca sama nigdy, wraca po restarcie
zasilania. Czas życia **zmienny** — bywa 15 minut, bywa dłużej; krócej wieczorem,
gdy kamera włącza podczerwień. Tak jest **od montażu rok temu**. Monitor `.8`
odpowiada bez potknięcia przez całą dobę.

**Wykluczone, nie wracać:**

- **Konflikt adresów IP** — `arp -a` pod `.8` pokazuje MAC monitora, nikogo obcego.
- **Wi-Fi stacji** — urządzenie, które gubi Wi-Fi, wraca samo. Ta stacja nie wraca.
- **Zasilanie z centrali alarmu** — switch ma własny zasilacz, wspólne jest tylko
  gniazdko 230 V.
- **Budżet PoE** — dioda **PoE-MAX na switchu jest zgaszona** przez cały czas
  awarii (film przejrzany klatka po klatce). Mruganie oznaczałoby granicę mocy.
- **Przegrzewanie obudowy** — test przy **otwartych drzwiczkach** 28.09: stacja
  padła mimo otwartej skrzynki.
- **Nieznana kamera pod `.24`** — to **ten sam monitor** po Wi-Fi (identyczny
  numer seryjny i BootTime co `.8`, MAC FN-LINK = moduł Wi-Fi). Wi-Fi monitora
  wyłączone 28.09.

**Zostało do sprawdzenia:** gniazdo w switchu (stacja przełożona na 3, test
nocny), kabel do bramy, sama stacja.

**Stacja ma stary firmware** — `V2.2.65 build 231213`, monitor `V2.2.96 build
241111`. Aktualizacja stacji to pierwsza darmowa rzecz do zrobienia, bo
zawieszanie się to typowy błąd łatany w kolejnych wersjach.

### Domofon — narzędzia diagnostyczne, które się sprawdziły

**Restart stacji bez gaszenia alarmu:** wyjąć jej kabel z switcha na 10 sekund.
Stacja jest zasilana po PoE, więc to dla niej pełny restart. Potwierdzone przez
`BootTime` w odpowiedzi SADP.

**Rejestrator pingów** — wklejany do PowerShell, zapisuje do pliku:

```powershell
while ($true) {
  $t = Get-Date -Format "HH:mm:ss"
  $m = if (Test-Connection 192.168.88.8   -Count 1 -Quiet) {"OK "} else {"BRAK"}
  $f = if (Test-Connection 192.168.88.210 -Count 1 -Quiet) {"OK "} else {"BRAK"}
  $r = if (Test-Connection 192.168.88.1   -Count 1 -Quiet) {"OK "} else {"BRAK"}
  $i = if (Test-Connection 8.8.8.8        -Count 1 -Quiet) {"OK "} else {"BRAK"}
  "$t  monitor=$m  furtka=$f  router=$r  internet=$i" | Tee-Object -Append "$env:USERPROFILE\domofon.log"
  Start-Sleep 10
}
```

Kolumny z routerem i internetem są po to, żeby nie obwiniać sprzętu za czkawkę
łącza — wpisy alarmu „Brak połączenia z serwerem SATEL" okazały się właśnie tym.

**SADP w jednej linii** — zastępuje narzędzie Hikvisiona (którego instalator sypie
„NSIS Error"). Zwraca model, numer seryjny, firmware, MAC i **BootTime** każdego
urządzenia Hikvisiona w sieci, bez hasła:

```powershell
$a=[Net.IPAddress]::Parse("239.255.255.250"); $u=New-Object Net.Sockets.UdpClient; $u.Client.SetSocketOption([Net.Sockets.SocketOptionLevel]::Socket,[Net.Sockets.SocketOptionName]::ReuseAddress,$true); $u.Client.Bind((New-Object Net.IPEndPoint([Net.IPAddress]::Any,37020))); $u.JoinMulticastGroup($a); $x='<?xml version="1.0" encoding="utf-8"?><Probe><Uuid>'+[guid]::NewGuid().ToString()+'</Uuid><Types>inquiry</Types></Probe>'; $b=[Text.Encoding]::UTF8.GetBytes($x); [void]$u.Send($b,$b.Length,(New-Object Net.IPEndPoint($a,37020))); $k=(Get-Date).AddSeconds(8); while((Get-Date) -lt $k){ if($u.Available -gt 0){ $e=New-Object Net.IPEndPoint([Net.IPAddress]::Any,0); $d=$u.Receive([ref]$e); "--- $($e.Address) ---"; [Text.Encoding]::UTF8.GetString($d) }; Start-Sleep -Milliseconds 150 }; $u.Close(); "koniec"
```

**Uwaga przy wklejaniu do PowerShell:** wieloliniowe bloki potrafią się rozjechać
i pierwsze linie giną. Przy dłuższych poleceniach dawać wszystko **w jednej
linii**, rozdzielone średnikami.

### Domofon — dane urządzeń

| | Monitor | Stacja |
|---|---|---|
| Model | DS-KH6320-WTE1 | DS-KV8113-WME1(C) |
| Adres | `192.168.88.8` statyczny | `192.168.88.210` statyczny |
| MAC | `a4-d5-c2-41-08-6e` | `a4-d5-c2-40-f2-72` |
| Nr seryjny | `…0120250219WRQ38689928U` | `…0120250219RRFW5799425` |
| Firmware | V2.2.96 build 241111 | V2.2.65 build 231213 |

Hasło trybu konfiguracji monitora: `888999` (osobne od `admin` do panelu WWW).
**Nie resetować** monitora ani stacji — kasuje powiązania, kody i konta.

**Instalator (montaż rok temu) odmówił naprawy.** Rękojmia na usługę to 2 lata,
sprzęt ma rok gwarancji producenta u sprzedawcy.

Ta sama choroba co przy pompie, ten sam lek: stałe adresy.

## Otwarte wątki

1. **Panel na komputerze, który zostaje w domu.** Laptop jeździ do pracy, więc
   historia ma dziurę 8–18 — dokładnie tam, gdzie toczy się gra z harmonogramami.
   Jacek zadeklarował przeniesienie na inny komputer; nadal niezrobione. **To blokuje
   wszystkie decyzje oparte na pomiarach**, więc przy każdej takiej rozmowie warto
   o tym przypomnieć, zamiast doradzać na wyczucie.
2. **Kolejne przyciski sterowania.** Nastawa pokojowa jest zrobiona (tabela
   `STEROWANIE` w `pompa-acond.py`). Do dołożenia, każdy po jednym podejrzeniu
   w F12: podgrzanie CWU na żądanie, włącznik harmonogramu wody grzewczej
   (zadania z 1 grudnia i 1 marca stałyby się jednym kliknięciem), tryb urlopowy,
   nastawa CWU 45/48 °C.
3. **Rezerwacje adresów w routerze** dla `.9`, `.10` i komputera z panelem — zaczęte,
   niedokończone.
4. **Falownik** — dopiero gdyby trafił do sieci.

## Zasady pracy nad tym kodem

- **Testuj na udawanych urządzeniach.** W trakcie pracy powstały symulatory sterownika
  Tecomat (z prawdziwą procedurą logowania) i falownika SUN2000. Zmiany w pobieraniu
  danych albo w logowaniu sprawdzaj na nich, zanim każesz Jackowi cokolwiek uruchamiać
  — on ma jedno urządzenie i nie ma jak wrócić do stanu sprzed.
- **Po aktualizacji sprawdź, czy chodzi nowa wersja.** Panel trzyma port 8125;
  jeśli stary proces nie zostanie zatrzymany, nowy nie wstanie i użytkownik widzi
  starą wersję mimo udanej instalacji. Instalator zatrzymuje go teraz sam.
- **Wątki w tle muszą przeżyć każdy wyjątek.** Wątek zbierający historię łapał
  kiedyś tylko `OSError` i padał po cichu na wszystkim innym. Panel wyglądał
  zdrowo — dane na żywo idą inną drogą — a historia stała tygodniami. Każda
  pętla w tle: szeroki `except`, ślad w logu raz na rodzaj błędu, i leć dalej.
  Dodatkowo panel pokazuje czerwoną ramkę, gdy historia nie rośnie od kwadransa.
- **Nigdy nie nadpisuj danych użytkownika.** `logowanie.txt`, `opisy-panelu.json`
  i `dane-pompy.csv` to jego rzeczy; instalator kopiuje je tylko, gdy ich nie ma.
  Historia zbierana przez miesiące jest nie do odtworzenia.
- **Nie zabijaj procesów wzorcem pasującym do własnego polecenia.** `pkill -f` na
  „pompa-acond.py panel" trafia we własną powłokę — składaj wzorzec w locie i wyklucz
  własny PID.
- **Pliki .bat i .vbs zapisuj z końcami linii CRLF.**
