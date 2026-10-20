# Pompa ciepła — dziennik ustawień

Zapis tego, co i kiedy zostało zmienione w sterowniku, żeby po sezonie dało się
odtworzyć decyzje. Sterownik: ACOND THERM, sw 160.36, panel pod `192.168.88.9`.

## 30.08.2026 — przygotowanie do sezonu

Cel: przesunąć grzanie na godziny własnej produkcji z fotowoltaiki. Taryfa G11
(płaska cena), więc noc nie jest tańsza — jedyne, co się opłaca, to zużywać własny
prąd zamiast go oddawać. W net-billingu oddana kilowatogodzina jest warta trzy do
czterech razy mniej niż kupiona, a w lipcu 2026 oddane 1066 kWh było warte 0 zł.

Wszystkie trzy harmonogramy były **skonfigurowane, ale wyłączone**.

| Harmonogram | Ustawienie | Stan po zmianie |
|---|---|---|
| Grzanie CWU (`PAGE118`) | **10:00–16:00 wszystkie dni** | **włączony** |
| Temperatura wody grzewczej (`PAGE117`) | **10:00–16:00 wszystkie dni, 45,0 °C** | **włączony** |
| Temperatura pokojowa (`PAGE116`) | okna wieczorne 16:00–18:00, 19–20 °C | wyłączony — celowo |

Harmonogram temperatury pokojowej zostaje wyłączony świadomie: przy ogrzewaniu
podłogowym głębokie obniżenia nocne szkodzą, bo jastrych stygnie godzinami, a potem
pompa odrabia to dużą mocą przy gorszej sprawności. Jedna stała nastawa przez dobę
jest dla podłogówki lepsza.

Godziny ujednolicone na **10:00–16:00 we wszystkich dniach obu harmonogramów**. Zastane
ustawienia miały trzy różne warianty w tygodniu i start o 12:00, co przesypiało szczyt
produkcji — z danych godzinowych za lipiec 2026 najwięcej energii szło do sieci
o 10:00, 11:00 i 12:00.

Szersze okno nic nie kosztuje: okno nie mówi, jak długo pompa grzeje, tylko kiedy wolno
jej zacząć. Pompa dogrzewa do nastawy i staje. Przy taryfie G11 grzanie o 15:30 kosztuje
tyle samo co o 21:00, więc szerokie okno wyłącznie zmniejsza ryzyko zimnej wody przy
włączonej blokadzie.

Poprawione przy okazji: sobotnie okno 07:31–08:30 w harmonogramie wody grzewczej
(przypadkowy wpis) wyzerowane do 00:00–00:00.

Kłódka przy ikonie kranu na ekranie CWU pokazuje stan blokady na żywo: zamknięta poza
oknem, otwarta w oknie. Przydaje się do sprawdzenia, czy zmiana weszła.

### Stan wyjściowy liczników

Spisany przed sezonem, do porównania w lutym:

| Licznik | 30.08.2026 |
|---|---|
| Energia elektryczna | 4506 kWh |
| Motogodziny sprężarki | 6039 h |
| Motogodziny wentylatora | 6108 h |
| Biwalencja 1 (grzałka) | 119 h |
| Biwalencja 2 (grzałka) | 43 h |
| Motogodziny CWU | 1218 h |

Najważniejszy jest przyrost biwalencji: grzałka robi kilowatogodzinę ciepła
z kilowatogodziny prądu, pompa z jednej trzeciej.

## 27.09.2026 — pierwsze tygodnie sezonu

**Próg końca sezonu grzewczego: 14,5 → 12,8 °C**, zmienione świadomie przez
Jacka. Sezon rusza, gdy średnia zewnętrzna spadnie poniżej progu — niższy próg
odsuwa start o jakieś dwa tygodnie (z początku na połowę października). Dom przy
średniej 15 °C trzyma 21,8 °C bez grzania, więc zwłoka nic nie kosztuje
w komforcie, a oszczędza.

**Nastawa pokojowa:** 20 września podniesiona z letnich 15,3 na 21 °C, ale
27 września sterownik pokazuje **19,4**. Wartość do ustalenia i zapisania tutaj,
gdy Jacek zdecyduje.

### Odczyt licznika

| | 30.08.2026 | 27.09.2026 | przyrost |
|---|---|---|---|
| Energia elektryczna | 4506 kWh | 4540 kWh | **+34 kWh / 4 tyg.** |

Nieco ponad kilowatogodzina na dobę, przy ogrzewaniu jeszcze nieruszonym — to
jest koszt samej ciepłej wody i punkt odniesienia dla pierwszego miesiąca
z grzaniem.

### Sprawy techniczne

Sterownik zmienił adres w sieci (9 → 8 → 23) i przez trzy tygodnie panel nie
zbierał danych — stąd dziura w historii od 2 do 27 września. Odnalazł się
dopiero po adresie MAC (`f8:dc:7a:7d:24:89`). Panel robi to teraz sam.
**Rezerwacja adresu w routerze wciąż niezrobiona** i to ona usunęłaby przyczynę.

## 17–18.10.2026 — pierwszy mierzony weekend

Nastawa pokojowa podniesiona z 18,1 na **20,5 °C** w sobotę rano. Przez cały
weekend bez zmian — pierwszy pomiar przy jednej, stałej wartości.

### Przebieg i liczby

| Chwila | Licznik | W domu | Na dworze |
|---|---|---|---|
| sob. 07:43 | 4565 kWh | 18,7 °C | 6,7 °C |
| sob. 12:15 | 4569 kWh | — | — |
| sob. 21:15 | 4573 kWh | 20,1 °C | 9,8 °C |
| nd. 00:38 | 4575 kWh | **20,5 °C** | 9,9 °C |
| nd. 08:37 | 4578 kWh | 20,9 °C | 9,7 °C |
| nd. 10:29 | 4579 kWh | 21,0 °C | 11,8 °C |

**Podniesienie domu o 1,8 °C kosztowało 10 kWh** — tyle, ile cała doba
utrzymywania. Dom doszedł do nastawy przed północą, czyli po jakichś
czternastu godzinach.

**Utrzymanie: 3 kWh przez osiem godzin nocy**, czyli **0,37 kWh/h** przy 20,5 °C
w domu i 9–10 °C na dworze. W przeliczeniu na dobę około **9 kWh**.

Po naładowaniu płyty dom przestrzelił do 20,9–21,0 °C i pompa zeszła z 7,2 kW
do 1,35 kW. Przestrzelenie jest normalne — beton oddaje to, co wziął.

### Harmonogramy — stan faktyczny odczytany ze sterownika

**Poprawka do wcześniejszych notatek: okno to 10:00–16:00, nie 12:00–14:00.**

| Harmonogram | Stan | Godziny | Wartość |
|---|---|---|---|
| Temperatury wody grzewczej | włączony | codziennie 10:00–16:00 | 45,0 °C |
| Blokada ogrzewania CWU poza harmonogramem | włączona | codziennie 10:00–16:00 | CWU 45,0 °C |
| Temperatury pokojowej (obieg 1) | **wyłączony** | stare okna wieczorne | 19,0–20,0 °C |

Harmonogram wody grzewczej **nadpisuje termostat pokojowy**. Zmierzone 18.10
o 10:29: w domu 21,0 °C przy nastawie 20,5, a pompa i tak grzała 4,7 kW,
bo woda szła na 45 °C (o 8:37 było 24,8 °C, o 10:29 już 40,4 °C). Krzywa
pogodowa chciałaby wtedy około 28 °C.

### Zimny prysznic — poprawione

Blokada CWU od 16:00 do 10:00 okazała się za ostra. Zbiornik stygnie
**0,7 °C na godzinę**: z 45 °C o 16:00 schodzi do 33 °C nad ranem. Woda pod
prysznicem o siódmej była za chłodna.

Rozwiązanie: **okno poranne 05:00–07:00** w pierwszym, dotąd pustym wierszu
harmonogramu CWU. Koszt około 0,8–1 kWh z sieci dziennie, bo o piątej rano
paneli nie ma. Samo podniesienie temperatury zbiornika z 45 na 50 °C nie
wystarczy — rano i tak byłoby około 38 °C.

Wieczorna kąpiel jest bezpieczna: ostatnie dogrzanie o 16:00, o dwudziestej
zbiornik ma jeszcze około 42 °C.

### Pogoda i czego ten weekend nie zmierzył

**Niedziela 18.10 cały dzień pod cienką, równą warstwą chmur** — bez cieni,
produkcja rzędu 30–40 % pogodnego dnia. Czyli zmierzyliśmy strategię
południowego podbicia w jej **najgorszym przypadku**: 45 °C wody przez sześć
godzin, z obniżoną sprawnością, głównie za prąd z sieci.

Zostawione celowo, żeby mieć z czym porównać dzień słoneczny.

### Czujnik zewnętrzny stoi w słońcu

17.10: **6,7 °C o 8:08 i 17,4 °C o 12:15**, przy średniej dobowej 11,5 °C.
Jedenaście stopni skoku w cztery godziny w połowie października to nie
powietrze, tylko nasłoneczniona obudowa.

Działa przeciwko strategii południowej: sterownik dobiera temperaturę wody po
tym odczycie, więc **im mocniej świeci, tym bardziej odpuszcza** — dokładnie
wtedy, gdy prąd jest z dachu. Do sprawdzenia, po której stronie elewacji wisi.

### Sprawy techniczne

Panel przez dwa dni pokazywał świeże dane i **nie zapisywał ani jednego
wiersza** — wątek zbierający padł po cichu na nieoczekiwanym wyjątku, bo
łapaliśmy wyłącznie `OSError`. Poprawione: pętla łapie wszystko, a panel
zapala ostrzeżenie, gdy historia nie rośnie od kwadransa.

Chodziły też **dwa panele naraz**, oba pukające pod nieaktualny adres
`192.168.88.8` (pompa jest na `.23`). Znajduje ją po MAC-u, ale to kolejny
argument za rezerwacją w routerze.

Dołożony **dziennik palenia w kominku** — przycisk w panelu, zapis do
`kominek.csv`, pas na wykresie ostatniej doby.

## 18.10.2026 wieczorem — monitoring na komputerze stacjonarnym

Panel przeniesiony z laptopa na stacjonarny. Przy okazji wyszły trzy rzeczy.

### Dziury w historii to nie był wyłączony laptop

Najpierw tak to zdiagnozowałem i **była to zła diagnoza**. Dane mówią inaczej:

| Dzień | Od | Do | Wpisów | Powinno być |
|---|---|---|---|---|
| 12.10 | 00:04 | 23:19 | 49 | ~280 |
| 14.10 | 00:00 | 23:58 | 64 | ~288 |
| 15.10 | 00:03 | **00:53** | 11 | ~288 |
| 17.10 | **21:08** | 23:59 | 35 | — |
| 18.10 | 00:04 | 19:09 | **230** | 230 ✓ |

Zapisy ciągną się przez całą dobę, tylko jest ich pięć razy za mało. Wyłączony
komputer zostawiłby jedną dziurę, nie dwieście małych. To był wątek zbierający,
który padał i wracał. **15.10 o 00:53 padł na dobre** i nie zapisał nic aż do
21:08 w sobotę — czyli do chwili, gdy ruszyła poprawiona wersja. Od tamtej
godziny 265 wpisów bez przerwy. Pierwszy taki ciąg w tej historii.

Wniosek na przyszłość: **zanim zwalisz dziurę na sprzęt, popatrz na rozkład
wpisów w dobie.** Awaria programu i wyłączony komputer wyglądają inaczej.

### Liczniki nie zapisały się ani razu przez półtora miesiąca

W paczce z laptopa nie było `liczniki.csv`. Odliczanie doby szło od zegara
`monotonic`, czyli od **włączenia komputera**, a nie od startu panelu — przy
komputerze gaszonym na noc warunek „minęła doba" nie spełniał się nigdy.
Naprawione: pierwszy spis idzie przy pierwszym obiegu pętli, więc każde
uruchomienie zostawia odczyt.

### Antywirus na stacjonarnym zgłosił trojana

Podejrzany jest `autostart.szablon.vbs` — skrypt VBS, który startuje
z autostartu i odpala ukryte okno `cmd` (`shell.Run ..., 0, False`). To jest
podręcznikowy kształt droppera; heurystyka zapala się od samej formy, nie od
treści. **Do wymiany na `pythonw.exe`** — robi to samo, a jest normalnym,
podpisanym programem. To nie jest obchodzenie antywirusa, tylko usunięcie
rzeczy, która słusznie wygląda podejrzanie.

### Mina w `_URUCHOM-PANEL.bat`

Plik wciąż podaje `http://192.168.88.8/PAGE115.XML` — stary adres pompy,
sprzed przeprowadzki na `.23`. Pod ósemką siedzi teraz **monitor domofonu**.
Panel działa, bo najpierw sięga po adres z `adres-pompy.txt`, ale gdyby `.23`
kiedyś zamilkło, zacznie pukać do domofonu. Do poprawienia.

### Oba okna grzania przesunięte na 11:00

Wieczorem przestawione w sterowniku, z 10:00 na 11:00, koniec bez zmian o 16:00:

- `PAGE117.XML` — temperatura wody grzewczej, 45 °C, siedem dni
- `PAGE118.XML` — blokada ogrzewania CWU poza harmonogramem, 45 °C, siedem dni

Powód: o dziesiątej w październiku panele dopiero ruszają, więc ta godzina była
grzaniem z sieci. Od środy porównamy z danymi godzinowymi Enei za 17–18.10, czyli
jeszcze sprzed zmiany — i wtedy będzie widać, ile ta godzina naprawdę kosztowała.

Razem z tym zmieniłem `OKNO_GRZANIA` w panelu na `(11, 16)`, żeby kafel „Słońce"
liczył sumę promieniowania dla tego samego okna, co sterownik.

**Uwaga na pomyłkę przy klikaniu:** strona harmonogramu pokojowego wygląda
prawie identycznie jak ta z wodą grzewczą. Różnica jest w wierszu TEMPERATURE —
**45,0** to woda, **19–20** to pokój. Pokojowy ma zostać wyłączony; włączenie go
nadpisałoby nastawę 20,5 starymi oknami z zeszłego sezonu.

### Stan na teraz

Panel chodzi z `C:\Users\jacek\Downloads\PanelPompy` — **tymczasowo**, bo
tak wylądował rozpakowany zip. Do przeniesienia do `%LOCALAPPDATA%` razem
z autostartem. Pogoda z Open-Meteo działa: o zmroku czujnik 10,9 °C przy
modelu 11,2 °C, czyli zgodnie. Dzień wyszedł pośredni — 1,4 kWh/m² w oknie
10:00–16:00 przy zachmurzeniu 91 %.

## 19.10.2026 — pierwszy zmierzony dzień z oknem 11:00–16:00

Poniedziałek, dom pusty, pogodnie (prognoza 2,1 kWh/m²). Pierwszy dzień
z przesuniętymi harmonogramami i pierwszy policzony co do godziny.

| | |
|---|---|
| Prąd z licznika | **6 kWh** (4582 → 4588) |
| Ciepło oddane | **25,1 kWh** |
| **COP dobowy** | **4,2** |
| Ciepło w oknie 11:00–16:00 | **19,0 kWh (76 %)** |
| Prąd w oknie | 4 z 6 kWh |

Do 11:00 pompa nie zrobiła nic — jedenaście godzin postoju, licznik bez ruchu.
O 11:07, siedem minut po otwarciu okna, ruszyła od ciepłej wody: 38,4 → 46,1 °C
w 35 minut. Potem, od 12:47 do 20:18, praca ciągła ze szczytem **6,5 kW**
o 13:50 i zejściem do 1,3 kW wieczorem.

**Strategia południowa działa.** Trzy czwarte ciepła powstaje w oknie, w którym
pracują panele.

### Pas martwy termostatu pokojowego — zmierzony

Twierdziłem rano, że powyżej nastawy pompa nie ruszy. **Było to zbyt
kategoryczne.** Z dwóch dni widać:

- zatrzymuje się przy **+1,1 °C** nad nastawą (18.10, 21,6 przy 20,5),
- wraca przy **+0,6 °C** (19.10, 21,1 przy 20,5).

Czyli pas martwy to około pół stopnia. Wieczorne grzanie powyżej nastawy nie
jest błędem, tylko normalną pracą w tym paśmie.

### Czujnik zewnętrzny — 19,6 °C o 12:22

O 12:22 pokazał **19,6 °C**, o 13:57 — **9,9 °C**. Dziesięć stopni w półtorej
godziny to nie powietrze, tylko stygnąca ściana. Dokładnego błędu nie ma, bo
zapis pogody ruszy dopiero po podmianie plików.

### Dwie rzeczy niewyjaśnione

**Postój 11:47–12:42, 55 minut w środku słońca.** Sprawdzona i **odrzucona**
hipoteza, że to przekroczenie progu „koniec sezonu grzewczego" (13,9 °C):
18.10 czujnik był ponad progiem od 11:24 do 14:00 i pompa grzała normalnie,
nawet 4,5 kW. Najprawdopodobniej opóźnienie po cyklu CWU — ale to zgadywanie.

**CWU poszło do 53,8 °C**, dziewięć stopni ponad nastawę 45. Drugi cykl ruszył
o 14:07. Może antylegionella, poniedziałek by pasował. Do sprawdzenia
w sterowniku.

## 18.10.2026 — ile z rachunku to naprawdę pompa

Pierwsze zestawienie danych godzinowych Enei z własnym pomiarem pompy. Niedziela,
dane „po bilansowaniu":

| | kWh | udział |
|---|---|---|
| **Cały dom** (Enea) | **18,355** | 100 % |
| Pompa ciepła (licznik sterownika) | **7,0** | **38 %** |
| **Reszta domu** | **11,4** | **62 %** |

Oddane przed bilansowaniem 2,376 kWh, po bilansowaniu **0,000** — bilansowanie
godzinowe skasowało wszystko. To samo 17.10: 2,589 → 0,028. **Autokonsumpcja
jest praktycznie stuprocentowa**, czyli dokładnie to, o co chodzi w net-billingu.

**Wniosek, który zmienia priorytety:** pompa to mniej niż dwie piąte rachunku.
Harmonogramy, krzywa i nasłoneczniony czujnik dotyczą tej mniejszej części.

Pompa pracowała 18.10 przez siedemnaście godzin bez przerwy, od północy do
17:00, ale na minimum — po około **0,4 kWh na godzinę**. Potem stanęła o 17:42
i do końca doby nie wzięła nic.

A najwyższy słupek Enei tego dnia to **godzina 21**, i godziny 18–23 są
wszystkie wysokie. Pompa w żadnej z nich nie pracowała. **Wieczorny szczyt to
dom, nie ogrzewanie** — i to po pełnej cenie, bo po ciemku.

**Do ustalenia:** co składa się na te 11,4 kWh. Najprościej odczytać w aplikacji
Enei wartość dla godziny 3:00 (pobór podstawowy) i 21:00 (szczyt), odjąć 0,4 kWh
pompy. Wysoki pobór podstawowy to zwykle najtańsza oszczędność, jaka istnieje.

## 20.10.2026 — skąd się biorą te 11,4 kWh „reszty domu"

Z danych godzinowych Enei za 18.10, po odjęciu pompy (0,41 kWh/h przy pracy
na minimum):

| Godzina | Enea | Pompa | Dom |
|---|---|---|---|
| 3:00 (pobór podstawowy) | 0,694 kWh | 0,41 | **0,28 kWh/h ≈ 280 W** |
| 21:00 (szczyt) | 1,428 kWh | 0 (stała) | **1,43 kWh**, z tego ~1,15 to aktywność |

**280 W non stop to 6,7 kWh na dobę — prawie 60 % „reszty domu".** W skali roku
2450 kWh, około 2200 zł. Większość rachunku poza ogrzewaniem to nie pralka,
tylko rzeczy, które po prostu stoją i ciągną.

Jacek wskazał składniki: **rekuperacja chodząca 24 h**, **osobna lodówka na
napoje**, oraz **ledy wokół domu, automat 19:30–22:30** (te ostatnie nie wchodzą
do poboru nocnego, ale trafiają w najdroższe godziny doby).

**Rekuperacji nie ruszamy** — odzyskuje więcej ciepła, niż zużywa prądu. Do
sprawdzenia: stan filtrów (zapchane podnoszą pobór o połowę) i czy jest
elektryczna nagrzewnica wstępna. Taka grzałka bierze 500–1500 W i włącza się
przy mrozie; w styczniu zobaczymy ją jako skok poboru nocnego.

**Metoda pomiaru bez żadnego sprzętu:** wartość godziny 3:00 w aplikacji Enei to
czysty pobór podstawowy. Wyłączyć badane urządzenie na jedną dobę i porównać
z poprzednią nocą. Odpowiedź przychodzi z dwudniowym opóźnieniem, ale jest
dokładna.

### Zmiany wprowadzone

- **20.10 wieczorem:** ledy ograniczone do frontu domu i do najniższej jasności
  (było: całość, pełna jasność, 19:30–22:30). Porównanie: godzina 21:00
  z 18.10 = 1,428 kWh, pompa wtedy stała.

### Uwaga o koszcie samego monitoringu

Stacjonarny komputer chodzi od 18.10 przez całą dobę i **wszedł do poboru
podstawowego**. Przy typowym biegu jałowym 60–80 W to 1,5–2 kWh dziennie,
czyli 40–55 zł miesięcznie — możliwe, że więcej, niż wynosi cała oszczędność
z poprawienia nasłonecznionego czujnika. Do zmierzenia watomierzem; docelowo
panel wart przeniesienia na coś, co bierze 3 W zamiast siedemdziesięciu.

## Do zrobienia

- [ ] **Przed sezonem (wrzesień):** podnieść nastawę pokojową z 15,3 °C (ustawienie
      letnie) na normalną, ok. 21 °C. Bez tego podbicie wody w południe nie ma się
      gdzie zatrzymać, a dom nie będzie grzany.
- [ ] **Pierwszy tydzień po włączeniu blokady CWU:** sprawdzić, czy nie brakuje
      ciepłej wody wieczorem. Jeśli brakuje — podnieść nastawę CWU z 45 na 48 °C.
- [ ] **Grudzień:** wyłączyć harmonogram temperatury wody grzewczej. Zimą nie ma
      nadwyżki z paneli, a wymuszanie 45 °C wody to sam gorszy COP bez zysku.
- [ ] **Marzec:** włączyć go z powrotem.
- [ ] **Zima:** odśnieżać panele. Kilowatogodzina ze stycznia była warta 0,68 zł,
      z lipca 0,00 zł — zimowa produkcja jest najcenniejsza w roku.

## Czego nie robimy i dlaczego

**Wejście HDO / SG Ready** — niepotrzebne, skoro harmonogramy w pompie robią to samo
bez ingerencji w instalację.

**Zmiana taryfy na G12/G12w** — nie opłaca się. Z danych godzinowych: zimą tylko 31 %
poboru wypada w tanich godzinach G12 i 51 % w G12w, przy progu opłacalności ok. 55 %.

**Automatyka reagująca na rzeczywistą nadwyżkę** — sensowna dopiero, gdy dane pokażą,
jak często podbicie w południe trafia w dzień pochmurny. Harmonogram grzeje 10:00–16:00
niezależnie od pogody; automat robiłby to tylko wtedy, gdy naprawdę świeci.
