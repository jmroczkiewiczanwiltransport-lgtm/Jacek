# Wszystko w jednej aplikacji — Home Assistant

Trzy systemy, trzy aplikacje: Hue, SmartLife i panel pompy ciepła pod adresem IP.
Home Assistant zbiera to w jedno miejsce: jedna aplikacja na telefonie, jeden pulpit,
automatyka, która chodzi zawsze i widzi wszystkie urządzenia naraz — a nie każde osobno.

Ten katalog nie jest kolejnym programem do uruchomienia. To pakiet startowy: skrypt,
który przekłada to, co już mamy (urządzenia Tuya z kluczami, sceny, reguły czasowe),
na gotowe pliki Home Assistanta, plus instrukcja, w jakiej kolejności to poskładać.

## Na czym to ma chodzić

Home Assistant musi działać non stop — inaczej automatyka śpi razem z komputerem.
Do wyboru:

| Sprzęt | Uwagi |
|---|---|
| **Raspberry Pi 5 (4 GB) + karta/dysk SSD** | najpopularniejszy wybór, ok. 400–600 zł, cicho i mało prądu |
| **Mini PC** (np. używany Dell/Lenovo mikro) | szybszy i tańszy z drugiej ręki, więcej prądu |
| **NAS** (Synology, QNAP) | jeśli już stoi w domu — Home Assistant chodzi w kontenerze |

Najprostszy wariant: Raspberry Pi + **Home Assistant OS** wgrany przez *Raspberry Pi
Imager* (jest tam gotowy obraz w „Other specific-purpose OS”). Po włączeniu wchodzisz
na `http://homeassistant.local:8123` i zakładasz konto.

**Ustaw lokalizację** (Ustawienia → System → Ogólne). Z niej Home Assistant liczy
wschód i zachód słońca — wygenerowane reguły z tego korzystają.

## Kolejność

### 1. Hue — pięć minut

Ustawienia → Urządzenia i usługi. Mostek zwykle wykrywa się sam; jak nie, dodaj
integrację **Philips Hue** i podaj adres. Naciśnij przycisk na mostku. Wszystkie lampy,
pokoje i sceny wjeżdżają same. Aplikacja Hue dalej działa — nic w mostku nie psujemy.

### 2. Ledy MiBoxer (Tuya) — lokalnie, bez chmury

Potrzebne klucze lokalne. Jeśli jeszcze ich nie masz, zrób to najpierw w katalogu
`tuya/` (rozdział „Klucze” w `tuya/README.md`):

```bash
cd tuya
python3 tuya.py klucze
python3 tuya.py skanuj
```

Potem:

1. Zainstaluj **HACS** (dodatek do Home Assistanta z integracjami społecznościowymi) —
   instrukcja na `hacs.xyz`.
2. HACS → Integracje → szukaj **Tuya Local** (autor: make-all). Zainstaluj, zrestartuj.
3. Wygeneruj sobie ściągę:

   ```bash
   cd dom
   python3 generuj-ha.py
   ```

   Powstanie `prywatne/dodawanie-tuya.txt` — dla każdego urządzenia adres, Device ID,
   klucz lokalny, wersja protokołu i nazwa do wpisania.
4. Ustawienia → Urządzenia i usługi → Dodaj integrację → **Tuya Local**, i przeklikaj
   urządzenia po kolei według ściągi.

> **Nazwy muszą się zgadzać co do znaku.** Wygenerowane sceny, automatyzacje i pulpit
> odwołują się do encji wyprowadzonych z nazw — „Ledy front” daje `light.ledy_front`.
> Wpiszesz co innego, trzeba będzie poprawiać YAML.

Integracja Tuya z chmury (ta wbudowana w Home Assistanta) też zadziała i jest prostsza,
ale wszystko idzie wtedy przez serwery Tuya: wolniej i pada razem z internetem.
Lokalnie jest lepiej — chmurę możesz zostawić w narzędziu `tuya/` jako zapas.

### 3. Pompa ciepła ACOND

**Sprzęt:** jednostka zewnętrzna **iZZiFAST R290 PRO 7** (rok 2022), 230 V jednofazowo,
prąd maksymalny 13 A, moc grzewcza 1,5–8,6 kW (inwerterowa, modulowana), czynnik R290,
**COP 4,87 przy A7/W35**. Producent: iZZiFAST Sp. z o.o. Sp.k., Ruda Śląska.
Sterownik w szafie jest sterownikiem ACOND THERM (sw 160.36, fw 5.5).

Znamionowy COP mierzony jest przy wodzie 35 °C — czyli dokładnie w warunkach, jakie
daje ogrzewanie podłogowe. Im wyżej krzywa grzewcza, tym dalej od tej liczby.

Zestaw to szafa hydrauliczna **iZZiFAST** z pompą **ACOND** — kompletna kotłownia
w jednej obudowie (bufor, pompa obiegowa, armatura), a sterownik wpuszczony w jej front
to sterownik ACOND-a. To on jest punktem, do którego się podłączamy; szafa sama w sobie
nie ma osobnej elektroniki do gadania.

Sterownik ACOND wystawia **Modbus TCP na porcie 502**, po tym samym kablu, którym pompa
jest wpięta do sieci — nic dokładać nie trzeba. Home Assistant ma wbudowaną obsługę
Modbusa, więc nie potrzeba żadnego dodatku.

Trzy rzeczy do załatwienia, zanim cokolwiek zadziała:

**Właściwy adres.** Sterownik ma dwa porty Ethernet:

| Port | Adres | Do czego |
|---|---|---|
| ETH1 | 192.168.134.176 (stały) | sieć serwisowa pompy — **nie ten** |
| ETH2 | 192.168.88.x (z DHCP) | sieć domowa — **ten** |

Adres z ETH2 (`192.168.88.9`, brama `192.168.88.1`) przydzielany jest z DHCP, więc po
restarcie routera może się zmienić i integracja przestanie działać. Sprawdzisz go
w panelu pompy na stronie informacyjnej (ikona **i**, `PAGE121.XML`) albo na ekranie
sterownika.

Panel WWW sterownika to strony XML (`PAGE115.XML` — ekran główny, `PAGE121.XML` —
informacje: wersje oprogramowania, adresy obu interfejsów, motogodziny sprężarki,
wentylatora, pomp i CWU). Jeśli wartości siedzą wprost w tym XML-u, Home Assistant
może je czytać po HTTP i Modbus nie będzie w ogóle potrzebny do samych odczytów. Zarezerwuj go na routerze dla adresu MAC
`F8-DC-7A-7D-24-89` (u Ciebie router trzyma sieć 192.168.88.x, to typowe dla MikroTika:
IP → DHCP Server → Leases → „Make Static”).

**Odblokowanie Modbusa.** Komunikację Modbus musi włączyć w pompie **serwis ACOND-a** —
z poziomu ekranu sterownika się tego nie zrobi. Przy okazji poproś o dokumentację
protokołu z tablicą rejestrów: `AC-Z010` dla oprogramowania w wersji `160.36`
(dokumentacja.acond.cz, publiczny plik `AC-Z010-EN.pdf`).

**Co ten sterownik w ogóle umie.** Panel serwuje kolejne ekrany jako `PAGE<numer>.XML`.
Przejrzenie ich wszystkich to najprostszy sposób, żeby poznać funkcje sterownika bez
dokumentacji i bez serwisu:

```bash
python3 pompa-acond.py strony http://192.168.88.9/ --od 100 --do-strony 200
```

Skrypt pobiera każdą stronę, wypisuje te, które odpowiedziały, i podświetla napisy
zawierające słowa istotne dla sterowania z zewnątrz: `HDO`, `SG`, `blokada`, `wejście`,
`styk`, `sygnał`, `G12`, `taryfa`, `harmonogram`. Własne słowa podasz przez `--szukaj`,
a `--szukaj-wszystko` wypisze wszystkie napisy ze wszystkich ekranów.

Szuka się tu dwóch rzeczy. **Wejścia zewnętrznego** (u czeskich pomp zwykle „HDO"):
ekran informacyjny ma trzy przełączniki „G12 wyłącza…", więc takie wejście istnieje —
pytanie tylko, na których zaciskach. I **programu czasowego**: jeśli pompa ma własny
harmonogram temperatury, przesunięcie grzania na godziny słoneczne da się zrobić
w niej samej, bez żadnej integracji.

**Najkrótsza droga: strona sterownika.** Panel ACOND THERM serwuje swoje ekrany jako
XML, w którym wartości siedzą wprost — każda jako `<INPUT NAME="__T…_REAL_.1f" VALUE="41.3" />`.
Home Assistant potrafi taką stronę pobrać i wyciągnąć z niej liczby, więc **do samych
odczytów Modbus nie jest w ogóle potrzebny** — ani telefon do serwisu.

Zobacz, co jest na stronie:

```bash
cd dom
python3 pompa-acond.py strona http://192.168.88.9/PAGE115.XML
```

Nazwy zmiennych to skróty (`__T881A25AA_REAL_.1f`), ale stałe — dopóki nie zmieni się
program sterownika, ten sam skrót zawsze oznacza tę samą wielkość. Żeby je rozszyfrować,
przepisz odczyty z ekranu i daj skryptowi je dopasować:

```bash
cp panel-acond.przyklad.json panel-acond.json
# wpisz do pliku to, co panel pokazuje W TEJ CHWILI — jako tekst, w formacie z ekranu
python3 pompa-acond.py dopasuj http://192.168.88.9/PAGE115.XML --panel panel-acond.json
```

Wartości podawaj dokładnie tak, jak są wyświetlone (`"0.00"`, a nie `0`) — format sam
rozstrzyga część niejednoznaczności, bo każda wielkość ma swój.

Gdzie kilka zmiennych ma tę samą wartość (typowo nastawy: 20,0 potrafi wystąpić pięć
razy), skrypt to zgłosi zamiast zgadywać. Rozstrzygniesz je obserwacją:

```bash
python3 pompa-acond.py obserwuj http://192.168.88.9/PAGE115.XML
```

Temperatury mierzone drgają same z siebie, nastawy stoją w miejscu — to je rozdziela.
A gdy zmienisz nastawę na panelu, od razu widać, która zmienna skoczyła.

Na koniec:

```bash
python3 pompa-acond.py yaml http://192.168.88.9/PAGE115.XML
```

Powstaje `wyniki/pompa-acond-strona.yaml` — sekcja `rest:` do `configuration.yaml`. Jedno
zapytanie na minutę, wszystkie czujniki naraz, z jednostkami i klasami urządzeń, więc
temperatury i licznik energii od razu trafiają na wykresy i do panelu energii.

Jeśli strona wymaga logowania, dopisz `--uzytkownik` i `--haslo`; wygenerowany YAML
weźmie wtedy hasło z `secrets.yaml`.

**Droga zapasowa: Modbus TCP.** Potrzebna tylko wtedy, gdy strona nie wystarcza —
albo gdy kiedyś zechcesz nie tylko czytać, ale i sterować.

Najpierw sprawdź, czy Modbus jest w ogóle otwarty:

```bash
python3 pompa-acond.py sprawdz 192.168.88.9
```

Jeśli nie odpowiada, komunikację musi odblokować **serwis ACOND-a** — z poziomu ekranu
sterownika się tego nie zrobi. Przy okazji poproś o dokumentację protokołu: `AC-Z010`
dla oprogramowania `160.36`. Dalej analogicznie, tylko na rejestrach:

```bash
python3 pompa-acond.py skanuj 192.168.88.9
python3 pompa-acond.py dopasuj 192.168.88.9 --panel panel-acond.json --ile 500
python3 pompa-acond.py yaml 192.168.88.9
```

> **Zacznij od samych odczytów — i najlepiej na tym zostań.**
>
> Poniższe dotyczy wyłącznie sterowania przez Modbus. Czytanie strony sterownika jest
> bezpieczne: to to samo, co robi Twoja przeglądarka, i niczego w pompie nie rusza.
>
> Odczyt niczego w pompie nie zmienia. Zapis owszem, i to bardziej, niż wygląda:
> sterowanie przez Modbus jest w ACOND-zie pomyślane jako oddanie regulacji systemowi
> nadrzędnemu. Pompa wygasza wtedy własny czujnik temperatury i oczekuje, że bieżącą
> temperaturę poda jej Home Assistant. Jeśli komunikacja ucichnie na dłużej niż
> `MaxCommDataRefresh`, pompa wraca do trybu auto.
>
> Na panelu pompy jest pole **STEROWANIE** z przełącznikiem (`< ACONDTHERM >`). To ono
> decyduje, kto rządzi regulacją — nie ruszaj go „na próbę”. Do samego odczytu przez
> Modbus przestawiać go nie trzeba.
>
> W praktyce znaczy to tyle, że włączając sterowanie, bierzesz na siebie regulację
> ogrzewania. Błąd w automatyzacji to nie zgaszona lampka, tylko zimny dom albo
> przegrzany zbiornik. Dlatego wygenerowana sekcja sterowania jest **zakomentowana** —
> odkomentuj ją świadomie i po rozmowie z serwisem, a nie „żeby zobaczyć, czy działa”.
> Do samego podglądu temperatur i zużycia na jednym pulpicie sterowanie nie jest potrzebne.

### 3b. Optymalizacja sezonu grzewczego

Zanim cokolwiek przestawisz w pompie, potrzebujesz punktu odniesienia. Bez niego nie
odróżnisz „zmiana pomogła" od „zrobiło się cieplej". Zapis uruchom **przed** sezonem —
dane z września są tak samo potrzebne jak te ze stycznia.

```bash
cd dom
python3 pompa-acond.py zapisuj http://192.168.88.9/PAGE115.XML --co 300
```

Co pięć minut dopisuje wiersz do `dane-pompy.csv`. Zostaw uruchomione; przerwy nie
psują pliku, po ponownym starcie dopisuje dalej. Podsumowanie:

```bash
python3 pompa-acond.py podsumuj
```

```
DZIEŃ             PRĄD   ŚR. NA DWORZE  NAJZIMNIEJ   ŚR. CWU  ODCZYTÓW
2026-11-01      40 kWh          5.0 °C      5.0 °C   45.0 °C        24
2026-11-02      60 kWh          0.0 °C      0.0 °C   45.0 °C        24

Razem: 120 kWh przy średniej 5.7 °C na dworze.
Na stopniodzień: 2.8 kWh
```

Podsumowanie liczy też **rzeczywisty COP**. Panel podaje bieżącą moc grzewczą w kW,
a licznik — pobraną energię elektryczną; scałkowanie mocy po czasie daje ciepło, a iloraz
sprawność. To jedyna liczba mówiąca wprost, czy pompa pracuje dobrze, czy się męczy.
Zimą przy mrozie i cieplejszej wodzie wychodzi mniej niż tabliczkowe 4,87 i tak ma być —
pilnuj trendu przy porównywalnej pogodzie, a nie samej wartości.

Podsumowanie odtwarza też **krzywą grzewczą** — jaką wodę pompa robi przy jakiej
pogodzie. Krzywa jest nastawą w sterowniku, ale z zewnątrz widać jej skutek i to on
się liczy. Przy ogrzewaniu podłogowym każdy stopień wody w dół to około 2–2,5 % mniej
prądu, więc warto wiedzieć, gdzie się stoi, zanim zacznie się cokolwiek przestawiać.

### Liczniki raz w miesiącu — minimum, które warto robić

Jeśli nie chcesz prowadzić ciągłego zapisu, jest wersja minimalna: raz w miesiącu
spisać liczniki i zobaczyć, o ile urosły. To pięć sekund, a wyłapuje najdroższy
scenariusz — grzałki elektryczne pracujące godzinami.

```bash
python3 pompa-acond.py liczniki http://192.168.88.9/
```

Polecenie czyta ekran główny i informacyjny (`PAGE115` i `PAGE121`; inne przez
`--strony`), dopisuje odczyt do `liczniki.csv` i od razu pokazuje przyrost od
poprzedniego razu:

```
PRZYROSTY
   co                                      było      jest    przyrost
   Licznik energii elektrycznej            4506      5734       +1228
   Motogodziny sprężarki                   6039      6612        +573
   Biwalencja 1 (grzałka)                   119       166         +47
   Biwalencja 2 (grzałka)                    43        51          +8
```

Nazwy biorą się z `opisy-panelu.json`, więc po jednym `dopasuj` liczniki opisują się
same. Bez tego pliku widać surowe nazwy zmiennych — działa tak samo, tylko mniej
czytelnie.

**Co z tego czytać:** rosnące motogodziny biwalencji to grzałki elektryczne. Grzałka
robi kilowatogodzinę ciepła z kilowatogodziny prądu, pompa z jednej trzeciej. Kilkadziesiąt
godzin grzałki w miesiącu to już realna pozycja na rachunku i sygnał, że albo krzywa
jest za wysoka, albo pompa nie wyrabia w mrozy.

**Żeby robiło się samo:**

*Windows* — Harmonogram zadań → nowe zadanie, wyzwalacz miesięczny (albo tygodniowy),
program `python`, argumenty `C:\sciezka\dom\pompa-acond.py liczniki http://192.168.88.9/`.

*Linux* — `crontab -e` i wiersz uruchamiający to samo pierwszego dnia miesiąca:

```
0 8 1 * * cd /sciezka/dom && /usr/bin/python3 pompa-acond.py liczniki http://192.168.88.9/ >> liczniki.log 2>&1
```

Odczyty można robić częściej, nic to nie psuje — przyrost liczony jest zawsze względem
poprzedniego wpisu, a `--tylko-podsumuj` pokazuje zmianę bez dopisywania nowego.

**Kilowatogodziny na stopniodzień** to jedyna liczba, którą warto porównywać między
tygodniami. Samo zużycie nic nie mówi, bo zimą rośnie niezależnie od nastaw; podzielone
przez to, ile stopni brakowało do 20 °C, przestaje zależeć od pogody. Spadła po zmianie
nastawy — zmiana pomogła. Nie drgnęła — nie pomogła.

**Na co patrzeć w danych:**

| Objaw | Co zwykle znaczy |
|---|---|
| motogodziny **biwalencji** rosną | grzałka elektryczna dogrzewa — pracuje ze sprawnością 100 %, czyli trzy razy gorzej niż sprężarka. Najdroższa rzecz w całej instalacji |
| wysoka temperatura wody zasilającej | im niższa, tym lepsza sprawność — każdy stopień w dół to ok. 2–2,5 % mniej prądu |
| CWU grzane nocą | w net-billingu lepiej w południe, z własnego prądu, niż nocą z sieci |
| krótkie, częste załączenia sprężarki | taktowanie — zużywa prąd i skraca życie sprężarki |
| grzejnik elektryczny w łazience | grzeje ze sprawnością 100 %, czyli trzy–cztery razy drożej niż pompa. Warto zmierzyć, ile naprawdę zjada |

**Podłogówka to darmowy magazyn ciepła.** Jastrych trzyma ciepło godzinami, więc da się
grzać w południe z własnego prądu i „jechać z rozpędu" wieczorem — bez kupowania
magazynu energii. To najprostszy sposób, żeby nadwyżkę z paneli zamienić w ciepło
zamiast oddawać ją do sieci za jedną trzecią ceny.

**Fotowoltaika w net-billingu zmienia rachunek.** Oddana kilowatogodzina jest warta
mniej więcej jedną trzecią kupionej. Każda kilowatogodzina zużyta na miejscu zamiast
oddana do sieci jest więc warta około trzy razy tyle co ta sama oddana. Wniosek dla
pompy: **przesuwać grzanie CWU i doładowanie bufora na godziny największej produkcji**,
czyli w okolice południa. Największy zysk daje to jesienią i wiosną, gdy słońce jeszcze
albo już świeci, a ogrzewanie już albo jeszcze działa.

To przesunięcie robi się automatyzacją w Home Assistancie — dlatego warto go postawić
przed pełnią sezonu. Ale zapis danych możesz uruchomić już dziś, samym skryptem.

### 3c. Prąd z sieci — kiedy, nie ile

Przy fotowoltaice w net-billingu o pieniądzach decyduje godzina, a nie suma.
Kilowatogodzina zużyta na miejscu jest warta tyle, ile kosztuje kupiona; ta sama
oddana do sieci — jakieś trzy do czterech razy mniej. Dlatego liczy się to, **o której**
pompa bierze prąd z sieci.

Dane godzinowe pobierzesz z eBOK swojego operatora (u Enei: Zużycie → Dane godzinowe →
eksport). Potem:

```bash
cd dom
python3 prad-enea.py dane-godzinowe.csv --cena-kupna 1.10 --cena-sprzedazy 0.28
```

Ceny podaj swoje, z faktury — domyślne to tylko rząd wielkości. Skrypt sam rozpoznaje
układ pliku: szuka kolumn z datą, godziną oraz energią pobraną i oddaną, radzi sobie
z przecinkiem dziesiętnym i z obiema konwencjami numerowania godzin (0–23 oraz 1–24).

Co pokazuje:

- **miesiącami** — pobrane, oddane, bilans,
- **profil dobowy** — o której godzinie bierzesz z sieci, a o której oddajesz,
- **udział poboru w godzinach 9–16** — czyli ile da się w ogóle przesunąć na własną
  produkcję; reszty i tak trzeba kupić,
- **czy zmiana taryfy ma sens** — jaka część poboru wypada w tańszych strefach G12
  i G12w. Poniżej mniej więcej 55 % zmiana zwykle nie zwraca droższej strefy dziennej,
- **pieniądze** — koszt pobranej, depozyt za oddaną i różnica między nimi.

Z tego wychodzi konkretny wniosek, ile warte jest przesunięcie grzania CWU i bufora
na południe. Latem to liczba teoretyczna, bo nie ma czym tej energii zużyć —
ale jesienią i wiosną, gdy słońce jeszcze pracuje, a ogrzewanie już chodzi,
jest to najprostsze dostępne oszczędzanie.

### 3d. Fotowoltaika — Huawei SUN2000

Falownik **SUN2000-10KTL-M1** czyta się lokalnie po Modbus TCP, bez chmury i bez konta
FusionSolar. To ten sam protokół co w pompie, więc obsługuje go ten sam klient
(`modbus.py`, wspólny dla obu).

Najpierw trzeba go włączyć w falowniku: aplikacja **FusionSolar → Uruchomienie
urządzenia** (telefon łączy się z własną siecią WiFi falownika) **→ Ustawienia →
Konfiguracja komunikacji → Modbus TCP → „Włącz (bez ograniczeń)"**. Potem:

```bash
cd dom
python3 falownik-huawei.py 192.168.88.20
python3 falownik-huawei.py 192.168.88.20 --zapisuj --co 300
```

Odczytuje moc z paneli, moc oddawaną, sprawność, temperaturę, uzysk dzienny i łączny
oraz moc na liczniku (dodatnia to pobór, ujemna to oddawanie). Po pierwszym odczycie
porównaj wartości z aplikacją FusionSolar — mapa rejestrów bywa różna między modelami.

> **SUN2000 obsługuje jednego klienta Modbus naraz.** Gdy podłączy się Home Assistant,
> ten skrypt przestanie dostawać odpowiedzi, i odwrotnie. Do stałej pracy używaj
> integracji `huawei_solar` z HACS; skrypt jest do rozpoznania i do zapisu danych,
> zanim Home Assistant stanie.

**Domyślne hasło do sieci WiFi falownika** (`Changeme` na naklejce) warto zmienić —
ta sieć daje dostęp do ustawień instalatorskich.

### 4. Sceny, automatyzacje i pulpit

```bash
cd dom
python3 generuj-ha.py --hue ../hue/hue.json
```

(`hue.json` powstaje z `cd hue && node hue.mjs raport hue.json` — dzięki temu lampy Hue
też trafiają na pulpit.)

Powstają trzy pliki w `wyniki/`:

| Plik | Gdzie trafia |
|---|---|
| `sceny.yaml` | dopisz do `scenes.yaml` w konfiguracji Home Assistanta |
| `automatyzacje.yaml` | dopisz do `automations.yaml` |
| `pulpit.yaml` | Pulpity → ⋮ Edytuj → ⋮ → Edytor kodu YAML → wklej |

Pliki konfiguracyjne najwygodniej edytować dodatkiem **File editor** albo **Studio Code
Server**. Po dopisaniu: Narzędzia deweloperskie → **Sprawdź konfigurację**, potem
**Przeładuj** sceny i automatyzacje (pełny restart niepotrzebny).

Reguły „o zachodzie” przekładają się na wyzwalacz słoneczny Home Assistanta — liczy je
sam z Twojej lokalizacji, więc nic nie trzeba podawać ręcznie.

## Sprawdź po drodze

- **Narzędzia deweloperskie → Stany** — czy encje nazywają się tak, jak w wygenerowanym
  YAML-u (`light.ledy_front`, `switch.garaz`).
- **Barwa światła.** Skrypt zakłada, że sterowniki chodzą w zakresie 2700–6500 K.
  Jeśli w scenie barwa wychodzi inna niż powinna, popraw `BARWA_OD_K` i `BARWA_DO_K`
  na górze `generuj-ha.py` i przegeneruj.
- **Aplikacja na telefonie** — „Home Assistant” w sklepie. Dostęp spoza domu:
  najprościej **Nabu Casa** (płatne, ok. 6,50 $/mies., wspiera projekt) albo własny
  VPN/WireGuard, jeśli wolisz za darmo i z ręką na wszystkim.

## Co się dzieje z tym, co już zbudowane

Nic się nie marnuje:

- `tuya/` **jest potrzebny dalej** — to on wydobywa klucze lokalne i znajduje adresy
  urządzeń, a przy okazji zostaje jako szybkie sterowanie z konsoli i diagnostyka,
  gdy Home Assistant czegoś nie widzi.
- `hue/` przydaje się do diagnostyki mostka (baterie, zasięg, urządzenia bez łączności)
  i do zrzutu listy lamp na pulpit.
- Sceny i reguły z `automatyka.json` przenoszą się automatycznie tym skryptem —
  nie trzeba ich klikać od nowa.

Automatyka z `tuya/` i `hue/` po przejściu na Home Assistanta jest już niepotrzebna;
jeśli oba systemy chodziłyby naraz, dwie automatyki sterowałyby tym samym światłem.
Wyłącz usługi `hue.service` i `tuya.service`, jak tylko reguły ruszą w Home Assistancie.

## Prywatność

`prywatne/dodawanie-tuya.txt` zawiera klucze lokalne urządzeń — jest poza repozytorium
i nie powinien nigdzie wychodzić. Pliki w `wyniki/` mają wyłącznie nazwy i wartości,
więc można je spokojnie wersjonować.
