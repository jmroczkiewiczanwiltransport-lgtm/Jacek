# JPK_CIT Kontrola — plan produktu nr 2

Decyzja właściciela (23.08.2026): budujemy **teraz**, żeby być gotowym zanim
zacznie się panika drugiej fali. Podział pracy: budowa nie zabiera czasu
sprzedaży KSeF — plan 14 dni biegnie równolegle i ma pierwszeństwo.

## Rynek i timing

- Fala 1 (przychody > 50 mln EUR + PGK): księgi za 2025 wysłane do **31.07.2026**
  (termin przedłużony rozporządzeniem z 16.02.2026). Nie nasz klient — mają ERP i Big4.
- **Fala 2 — nasz rynek:** księgi za **2026**, raport w 2027, praktycznie wszyscy
  podatnicy CIT będący VAT-owcami. To klienci biur rachunkowych. „Dym" zacznie się
  przy zamknięciach rocznych 2026 i potrwa do lata 2027.
- Fala 3: pozostali, rok później.

Cel: narzędzie **gotowe i przetestowane jesienią 2026**, sprzedawane od momentu,
gdy biura zaczną pytać.

## Koncepcja — ZMIENIONA po odpowiedzi Alicji (23.08.2026, wieczór)

Alicja (WhatsApp): „my potrzebujemy takie narzędzie, które z zapisów
«dziennik zapisów za dany rok» przygotuje jpk_kr_pd. Czyli pogrupuje odpowiednio
konta, żeby wyjść na wynik netto. I kwotę podatku do zapłaty. Jeszcze będzie
trzeba raportować Środki Trwałe."

Czyli nie kontroler, tylko **GENERATOR**: jej program księgowy nie składa
JPK_KR_PD (albo składa źle). Narzędzie ma:

1. wczytać **eksport dziennika zapisów za rok** (xlsx/csv z programu) + plan kont,
2. dać księgowej **ekran mapowania kont na znaczniki podatkowe MF** (jak mapowanie
   kolumn w KSeF, ale większe — słownik znaczników, maks. 2 na konto, zapis mapowania
   do pliku, żeby za rok wczytać gotowe),
3. **policzyć**: ZOiS z dziennika (BO + obroty = BZ per konto), pogrupować konta
   do wyniku rachunkowego, przejść na wynik podatkowy w RPD i pokazać **kwotę
   podatku** (stawka 9/19% do wyboru, zaliczki wpisywane przez księgową),
4. **złożyć poprawny XML JPK_KR_PD** zgodny z XSD — z wbudowaną kontrolą przed
   zapisem (sumy, ciągłość dziennika, kompletność znaczników — cały plan kontrolera
   staje się walidacją wewnętrzną generatora),
5. etap 2: **JPK_ST_KR** (środki trwałe) — Alicja sygnalizuje, że też będzie trzeba.

Architektura bez zmian: jeden HTML, wszystko w przeglądarce, księgi nie opuszczają
komputera. **Granica bez zmian:** narzędzie liczy i składa plik; mapowanie kont,
klasyfikacje i zatwierdzenie wyniku należą do księgowej — kwota podatku jest
wynikiem JEJ decyzji mapowania, do zweryfikowania z jej CIT-8, nie poradą podatkową.

### Rynek — skorygowany twardym faktem (24.08.2026)

**Alicja jest główną księgową w międzynarodowym koncernie, nie w biurze
rachunkowym.** Jej firma dostała ofertę na takie narzędzie: **100 000 zł
jednorazowo + 2 300 zł/mies. utrzymania** — i, co ważniejsze: **„nikt inny się
nie odezwał do nas z ofertą, mimo pisania z prośbą o ofertę"**. Popyt przerasta
podaż: firmy proszą o oferty i dostają ciszę.

Dlaczego: koncerny mają zagraniczne ERP (SAP itp.), które nie produkują polskiego
JPK_KR_PD; lokalizacja to projekt za setki tysięcy. Polskich spółek zagranicznych
grup są tysiące — wszystkie z tym samym problemem w tym samym terminie.

### Dwa segmenty, dwie ceny

**A. Koncerny / spółki z zagranicznym ERP (premium — nowy segment):**
- pilot u pracodawcy Alicji: **wdrożenie 25 000–30 000 zł netto + abonament
  1 500 zł/mies.** (decyzja właściciela 24.08.2026: „nie róbmy im za darmo —
  25–30 tys. plus abonament brzmi rozsądnie") — ok. 1/3 ceny konkurencji
  (100k + 2,3k/mc), przy architekturze, którą dział bezpieczeństwa koncernu
  pokocha (dane nie opuszczają ich komputera). Pilot = płatny; rabatem względem
  rynku płacą za pakiet referencyjny;
- w zamian za cenę pilotażową: referencja koncernu + zgoda na case study;
- uwaga wdrożeniowa: sprzedaż korporacyjna = umowa, wymagania zakupowe,
  odpowiedzialność — do przygotowania przed rozmową (wzór umowy, zakres SLA).

**Warunki pilota (zaakceptowane przez właściciela 24.08.2026):** cena pilotażowa
w zamian za pakiet referencyjny — wszystko wpisane do umowy, nie „na gębę":
1. **referencja pisemna** podpisana przez główną księgową / dyrektora finansowego,
2. **logo i nazwa firmy na stronie MBS** + zgoda na case study (jedna strona:
   problem → wdrożenie → wynik; kwoty firmy nie padają) — wymaga zgody działu
   marketingu/centrali, załatwić na początku, nie na końcu,
3. **polecenie wewnątrz grupy**: przedstawienie do 2–3 innych polskich spółek
   grupy albo zaprzyjaźnionych firm z tym samym problemem,
4. prawo MBS do podawania firmy jako klienta referencyjnego w rozmowach handlowych.

Jeśli firma nie może dać logo (polityka centrali) — cena pilotażowa rośnie o ~30%
albo zamieniamy na referencję anonimizowaną („międzynarodowa grupa z branży X").

**B. Biura rachunkowe (wolumen — później):** wdrożenie 2 900 zł + 990 zł/rok
bez limitu spółek. Ten segment rusza po pilocie z segmentu A.

Kotwice tła: wdrożenia ERP 10–40 tys. + 6–15 tys./rok; moduły programów
księgowych od ~1,2 tys./stanowisko + 30–50% licencji rocznie.

## Kontrole (wersja 0 — do zweryfikowania na prawdziwym pliku)

Struktura: węzły `Naglowek / Podmiot1 / ZOiS / Dziennik / Ctrl / RPD`.

1. **Spięcie sum:** obroty Wn = obroty Ma w dzienniku; ZOiS: BO + obroty = BZ
   per konto; sumy kontrolne w `Ctrl` zgodne z zawartością.
2. **Bilans otwarcia = bilans zamknięcia poprzedniego roku** (dwa pliki obok siebie —
   dokładnie jak dwa pliki w KSeF Uzgodnieniach).
3. **Ciągłość dziennika:** numeracja bez dziur i duplikatów, daty w obrębie okresu,
   zapisy poza okresem wyłapane.
4. **Znaczniki podatkowe kont:** konta bez znacznika, znaczniki nieistniejące
   w słowniku MF, więcej niż 2 znaczniki na koncie (limit ze struktury).
5. **Spójność RPD:** wynik rachunkowy z ksiąg vs przejście na wynik podatkowy;
   pozycje RPD niepodparte kontami ze znacznikami.
6. **NIP-y kontrahentów:** suma kontrolna (kontrola gotowa — przenosimy z KSeF).

Wynik jak w KSeF Uzgodnieniach: kafle wg pilności, zakładki z numerem
wiersza/zapisu, raport .xlsx, komunikaty po polsku, znaczniki DEMO + klucz
licencyjny (ta sama sól i keygen — jeden klucz MBS może obsługiwać oba narzędzia
albo osobne pule: do decyzji przy wdrożeniu).

## Rok wzorcowy: 2025 (ustalone 24.08.2026)

Testujemy na zamkniętym roku 2025 — właściciel ma dostęp do kompletu danych od
Alicji. Rok zamknięty = znamy prawidłowy wynik i kwotę podatku z CIT-8, więc
v0 ma jednoznaczny cel: **wyjść na jej liczby co do grosza.** Każda rozbieżność
to albo błąd narzędzia, albo różnica w mapowaniu — obie rzeczy chcemy zobaczyć.

Zasada przy danych: to są księgi prawdziwej spółki. Kwoty muszą zostać prawdziwe
(inaczej wzorzec nie działa), ale nazwy kontrahentów można zanonimizować, jeśli
Alicja sobie tego życzy — dla obliczeń są nieistotne. Decyzja należy do niej.

## Czego potrzebuję, zanim napiszę pierwszą linię (lista po odpowiedzi Alicji)

1. ~~**XSD struktury JPK_KR_PD(1) + broszura MF**~~ — **DOSTARCZONE 28.08.2026**
   (broszury + schematy jako PDF; brakuje samych plików `.xsd` do walidacji).
   Struktura rozpisana w `cit/STRUKTURA-KR_PD.md`.
2. **Eksport dziennika zapisów za rok** z jej programu (xlsx/csv) — dane firmy
   testowej albo zanonimizowane. To jest GŁÓWNE wejście narzędzia.
3. ~~**Plan kont** tej samej firmy~~ — **DOSTARCZONY 28.08.2026** (508 kont),
   mapowanie wstępne gotowe (97% kont z propozycją znacznika).
4. **Jak dziś grupują konta do wyniku** — ich robocze mapowanie (choćby w Excelu
   albo opisane słowami), czyli które konta idą do jakiej pozycji wyniku.
5. **Wyliczenie podatku za ten rok do porównania** (CIT-8 albo robocze wyliczenie) —
   żeby v0 miało wzorzec: nasz wynik musi zgadzać się z jej wynikiem.
6. Jeśli jej program jednak COŚ generuje (choćby stary JPK_KR) — plik jako odniesienie.

## Pierwsze dane projektowe — 28.08.2026

Właściciel dostał od Alicji dwie rzeczy: **dokumentację MF** (6 PDF-ów:
broszury i schematy JPK_KR_PD(1) oraz JPK_ST_KR(1), wraz z aktualizacjami
obowiązującymi od 01.07.2026) i **plan kont** spółki (`KONTA1.xlsx`, 508 kont).

Struktura rozpisana w `cit/STRUKTURA-KR_PD.md`. Słowniki znaczników wyciągnięte
do `cit/slowniki/znaczniki-KR_PD.json` i `znaczniki-ST_KR.json`
(skrypt `cit/narzedzia/wyciag-slownikow.py`).

### Co wyszło z dokumentacji — trzy rzeczy zmieniające zakres

1. **`wersjaSchemy` to `1-1`, nie `1-0`.** Pierwsze wydanie broszury podaje
   `1-0`; aktualizacja MF to zmienia. Plik z `1-0` byłby odrzucony.
2. **W JPK_KR_PD nie ma pola na wynik ani na kwotę podatku.** Węzeł RPD to
   osiem korekt (K_1–K_8) między wynikiem księgowym a podatkowym — i nic więcej.
   Kwotę podatku narzędzie liczy **jako pomoc do CIT-8 i jako kontrolę
   mapowania**, nie jako element raportu. Trzeba to Alicji powiedzieć wprost,
   bo prosiła o „kwotę podatku do zapłaty" jako o wynik pliku.
3. **Znacznik `S_12_1` jest obowiązkowy dla każdego konta** w węźle ZOiS7
   (jednostki pozostałe) — słownik ma 244 pozycje. Ale w ZOiS8 (jednostki
   stosujące MSSF) ten znacznik jest **opcjonalny i dowolnym tekstem**.
   Do potwierdzenia u każdego klienta: księgi statutowe wg UoR (→ ZOiS7,
   pełne mapowanie) czy wg MSSF (→ ZOiS8, mapowanie prawie zbędne).
   Dla koncernów to pytanie warte dziesiątek godzin pracy.

Bonus sprzedażowy: od 16.06.2026 **pełnomocnictwo UPL-1 obejmuje podpisywanie
JPK_KR_PD** — nie trzeba nowych pełnomocnictw.

### Co wyszło z planu kont

- **Plan kont nie jest polski.** Układ zespołów: 1 kapitały i rezerwy,
  2 aktywa trwałe i umorzenia, 3 zapasy, 4 rozrachunki, 5 środki pieniężne,
  6 koszty, 7 przychody, 8 zamknięcie. To układ zachodni (SAP/SKR), a nie
  wzorcowy polski. **Wniosek dla architektury: żadnych podpowiedzi po numerze
  konta bez wskazania profilu planu.** Podpowiadamy z nazwy konta, a numer jest
  tylko wsparciem. Profile planów kont trzymamy w
  `cit/slowniki/reguly-mapowania.json` (`pl_standard`, `erp_zagraniczny_a`).
  To potwierdza całą tezę o rynku: skoro plan kont jest zachodni, to i program
  nie złoży polskiego JPK.
- **Nazwy kont przychodzą w rozsypanym kodowaniu.** Osiem znaków spoza ASCII,
  żadne standardowe kodowanie nie odtwarza ich poprawnie (sprawdzone wszystkie
  kodowania Pythona) — tabela wyprowadzona z kontekstu:
  `¡`→Ś, `£`→Ą, `©`→Ż, `¬`→Ł, `Ê`→Ę, `ù`→Ń (`Ó` i `Ö` są poprawne).
  Ma znaczenie, bo **nazwa konta wchodzi do pliku XML w polu `S_2`** — bez
  naprawy fiskus dostaje „SPRZEDA© CZÊ¡CI". Do potwierdzenia z Alicją, czy
  naprawiać (proponuję: tak, z podglądem przed zapisem).
- **Plan kont sam nosi klasyfikację podatkową.** 16 kont ma w nazwie „(NKUP)"
  albo „NIEKOSZTOWA", 2 wprost „KUP". Czyli firma już rozdziela KUP/NKUP na
  poziomie konta — dokładnie to, czego potrzebują znaczniki PD. Znaczniki
  podatkowe da się w dużej części wyprowadzić automatycznie.
- Znaleziona przy okazji **niespójność w ich planie kont**: konto 397140 nosi
  nazwę „ODPIS AKTUAL.MASZ.KSA", identyczną z 397110, choć wg numeracji powinno
  dotyczyć segmentu KBL. Do zgłoszenia Alicji — pozycja bilansowa wychodzi ta
  sama, ale ktoś kiedyś skopiował nazwę.

### Silnik mapowania — działa, 97% na pierwszym prawdziwym planie kont

`cit/narzedzia/propozycja-mapowania.py` + reguły w
`cit/slowniki/reguly-mapowania.json` (99 reguł S_12_1, 4 reguły PD).
Prototyp w Pythonie, żeby szybko sprawdzać trafność na prawdziwych danych;
te same reguły przenosimy potem do narzędzia w przeglądarce.

Wynik na 508 kontach spółki Alicji:

| | |
|---|---|
| konkretny znacznik `S_12_1` | **495 kont (97%)** |
| pewność wysoka | 287 (56%) |
| pewność średnia | 184 (36%) |
| pewność niska | 37 (7%) |
| bez żadnej reguły | 0 |
| do decyzji księgowej („?") | 13 |
| znacznik podatkowy `S_12_3` | 16 |

Dwa mechanizmy, które to wyciągnęły z 73% do 97%:

1. **Parowanie kont korygujących.** Konto umorzeniowe albo odpisowe dziedziczy
   znacznik konta wartości brutto z końcówką `_U` / `_A` (MF przewiduje takie
   warianty). Para dobierana po rdzeniu nazwy — z rozwinięciem skrótów
   („ODPIS AKTUAL.CZ.KSA" → „MAGAZYN CZESCI KSA") i wsparciem zbieżności
   numeru konta. Sparowało 54 konta.
2. **Kara za niezgodność kodu segmentu.** Krótkie kody w nazwach (KSA, KHU,
   KBL, JD) to segmenty i marki. Jeśli kod z jednej nazwy nie występuje
   w drugiej, ocena pary jest ścinana — dzięki temu narzędzie **odmawia
   sparowania** zamiast wpisać sąsiedni magazyn. Na tym pliku poprawiło dwie
   pary (KMB → KBR (EX KMB)) i jedną słusznie zostawiło otwartą.

Każdy znacznik z reguł jest sprawdzany wobec słownika MF przed użyciem —
literówka w regule wysypuje skrypt, a nie produkuje plik odrzucony przez schemę.

Wyjście to xlsx dla księgowej: propozycja + opis znacznika ze słownika MF +
pewność + **dlaczego tak** + dwie kolumny na poprawki. Poprawki wracają do nas
i stają się mapowaniem tej firmy — w kolejnych latach wczytywanym gotowym.
To jest jednocześnie pierwsza rzecz do pokazania na spotkaniu: „wasze 508 kont,
97% przypisane, zostaje 13 do rozmowy".

### Odpowiedzi Alicji (28.08.2026) — i co z nich wynika

| Pytanie | Odpowiedź | Skutek |
|---|---|---|
| ZOiS7 czy ZOiS8 | **ZOiS7** | znacznik obowiązkowy przy każdym koncie, słownik 244 pozycji — pełne mapowanie 508 kont jest robotą do wykonania, nie opcją |
| kwota podatku | „wychodzi z kont, pracujemy także na odroczonym" | narzędzie liczy podatek **bieżący i odroczony**; rozdzielone znaczniki `RPJ_RKM_B` i `RPJ_RKM_O` |
| naprawa nazw kont | „do poprawy opisy kont" | naprawiamy kodowanie, z podglądem przed zapisem |
| konto 397140 | „do zmiany, podał poprawnie" | błąd potwierdzony po ich stronie, poprawią u siebie |
| jednostki powiązane | „powiązane Kuhn, cash pool" | tokeny `KUHN`, `KHU`, `CASH POOL`, `IC`, `WEWNATRZGRUP` wpisane do reguł |
| konta techniczne | bez odpowiedzi | 13 kont nadal otwarte — do rozmowy |
| pliki `.xsd` | właściciel: „muszę ściągnąć, mam tylko pdf" | do dobrania; podatki.gov.pl jest niedostępne z naszego środowiska (proxy 403) |

Wdrożone w regułach tego samego dnia:

- **Podatek bieżący vs odroczony.** Konto „Podatek dochodowy" → `RPJ_RKM_B`,
  „AKTYWOWANY PDOP" → `RPJ_RKM_O`. Aktywo i rezerwa z tytułu odroczonego
  podatku trafiają na `BAAV1_W` i `BPBI1`.
- **Przełącznik jednostek powiązanych.** Nowa sekcja `powiazane` w regułach:
  lista tokenów od klienta + tablica zamian. Po rozpoznaniu konta powiązanego
  znacznik przechodzi na wariant powiązany — w rachunku wyników przez zamianę
  końcówki `_POZ` → `_POW`, w bilansie przez tablicę (pozycje powiązane mają
  tam inne kody, nie samą końcówkę). Pozycje bez wariantu powiązanego (koszty
  rodzajowe, zapasy) zostają nietknięte — to nie pomyłka, MF ich nie dzieli.
  Na planie kont Alicji przełączyło **10 kont**: sprzedaż i wartość sprzedanych
  towarów w segmencie KHU (Kuhn), korekty bonusowe, odsetki cash poolingu,
  zobowiązania wobec Kuhn.

To jest mechanizm wielokrotnego użytku: każdy kolejny klient podaje własne
tokeny grupy i dostaje ten sam podział bez pisania reguł od nowa.

### Czego brakowało, żeby policzyć wynik (stan przed 29.08.2026)

1. **Eksport dziennika zapisów za 2025** — bez tego nie ma ZOiS, nie ma sum
   kontrolnych, nie ma wyniku. To jest jedyna rzecz naprawdę blokująca.
2. **ZOiS roczny z BO i BZ** z ich programu — do porównania z tym, co policzymy
   z dziennika. Bez tego nie odróżnimy błędu narzędzia od błędu mapowania.
3. **CIT-8 albo robocze wyliczenie podatku za 2025** — wzorzec do trafienia.
4. **Pliki `.xsd`** (nie PDF) — do automatycznej walidacji gotowego pliku.
   PDF wystarcza do generowania, ale walidacja schemą jest tańsza niż debugowanie
   odrzuconego pliku. Do dobrania z BIP MF.
5. Decyzja co do **13 kont technicznych i zbiorczych** (580000, 580001, 400000,
   600000, 601010, 409100, 409800, 460000, 467490, 476000 i trzy odpisy) —
   pytanie do każdego to samo: czy konto ma własne zapisy na ostatnim poziomie
   analitycznym. Jedyne pytanie z listy bez odpowiedzi.

## Test na prawdziwych księgach — 29.08.2026

Alicja dosłała komplet za 2025: **dziennik zapisów (290 436 wierszy)**,
zestawienie sald i obrotów (xlsx + wydruk PDF z systemu) oraz dwa arkusze
robocze — koszty niestanowiące KUP i przychody niepodlegające opodatkowaniu,
z gotowym wyliczeniem dochodu i podatku. Czyli wzorzec, na który mieliśmy
wyjść co do grosza.

### Co to za system

Eksport z francuskiego ERP (nagłówki `NRCRONO`, `CPTGE`, `LICOFD`, `MTLIG`,
dzienniki `ACH`/`VTE`/`RGT`/`AUX`/`SLD`/`OUV`). **Nazwy kont w dzienniku są po
angielsku, a w planie kont po polsku** — parametr języka eksportu ma warianty
FR/DE/US/ES i polskiego wśród nich nie ma. Wniosek dla generatora: nazwa konta
do pola `S_2` musi iść z planu kont, nie z dziennika, a reguły mapowania muszą
patrzeć na obie wersje nazwy.

Jakość danych wzorowa: suma wszystkich kwot **0,00 co do grosza**, zero
zapisów poza rokiem, bilans otwarcia zbilansowany. Kwota jest w jednej
kolumnie ze znakiem (dodatnia = Wn, ujemna = Ma) — do `Z_4` i `Z_7` trzeba ją
rozdzielić.

### Uzgodnienie z ich zestawieniem sald i obrotów

Konto po koncie zgadza się wszystko poza **10 kontami, i na każdym z nich
różnica jest identyczna po stronie Wn i Ma** — czyli to zapisy, które się
znoszą (rozliczenia, storna), a ich raport je zwija. Największy taki przypadek
to przeksięgowanie wyniku 891000 → 120000 na **4 313 115,24**, które okazało
się dokładnym sprawdzianem: wynik brutto 5 696 635,24 minus zaksięgowany
podatek 1 383 520,00 daje dokładnie tę kwotę. Księgi się spinają.

### Wynik i podatek policzone z dziennika

| | ich wyliczenie | z dziennika | różnica |
|---|---|---|---|
| wynik brutto | 5 696 635,24 | **5 696 635,24** | **0,00** |
| korekty podatkowe | 2 148 114,00 | 2 098 275,10 | −49 838,90 |
| dochód | 7 844 749,24 | 7 794 910,34 | −49 838,90 |
| podatek 19% | 1 490 502,36 | 1 481 032,96 | −9 469,40 |

**Wynik księgowy trafiony co do grosza.** Dochód różni się o 0,64%, i cały ten
rozjazd to **cztery nazwane pozycje**, nie błąd rachunku:

1. `623150` prezenty i darowizny (−125 006,97) — wybierają pojedyncze pozycje
   z konta reklamowego. Narzędzie nie ma jak tego zgadnąć z nazwy konta.
2. `661500` odsetki cash pool (+75 047,69) — wyłączają część konta
   (limit kosztów finansowania dłużnego), my liczyliśmy całe.
3. `658010` pozostałe koszty NKUP (+13 578,07) — też część konta.
4. `758010` przychody NKUP (−13 457,70) — **nazwa konta mówi NKUP, a w ich
   zestawieniu tej pozycji nie ma.** Pytanie do księgowej, nie nasz błąd.

### Ile da się policzyć automatycznie

Z 24 pozycji korekt podatkowych **21 wychodzi co do grosza z samego salda
konta** — czyli ze znacznika przy koncie, bez żadnej pracy ręcznej. Po stronie
przychodów **wszystkie 8 pozycji to całe konta**, suma zgadza się dokładnie:
−7 751 201,34.

Zostają **3 konta, na których NKUP to tylko część zapisów**. To definiuje
brakującą funkcję narzędzia: przy koncie ze znacznikiem podatkowym księgowa
musi móc albo przyjąć całe saldo, albo **oznaczyć pojedyncze wiersze dziennika**
— i to oznaczenie ma się zapamiętać na kolejny rok. Bez tego nie ma dokładnego
podatku, a z tym mamy 100%.

### Poprawki reguł wymuszone przez prawdziwe księgi

- Znak korekty: konto wyłączone z podatku koryguje dochód o **swoje saldo ze
  znakiem**, bez przypadków szczególnych. Pierwsza wersja brała wartość
  bezwzględną i myliła się o 1,1 mln — na kontach rezerw, gdzie utworzenie
  i rozwiązanie idą w przeciwne strony, oraz na odwróceniu amortyzacji
  niekosztowej z lat ubiegłych (saldo Ma na koncie kosztowym).
- `VAT niepodlegający odliczeniu` to zwykle **KUP** — reguła nie może łapać
  samego „nie podlega", musi wymagać wprost NKUP. Konto 635200 było łapane
  błędem, a księgowa go nie wyłącza.
- Reguły znaczników podatkowych rozpoznają teraz nazwy **angielskie**
  (`NOT DED`, `NON DEDUCT`, `INV RESERVE`, `DOUBTFUL`, `PROVISION`, `REVERSAL`),
  bo tak nazywa konta zagraniczny ERP.
- Rezerwy, odpisy i wyceny bilansowe dostają `PD5` (różnica przejściowa),
  a nie `PD4` — odwracają się w latach następnych.

### Znalezione przy okazji

- **5 kont jest w dzienniku, a nie ma ich w planie kont** (`623300`, `707112`,
  `707222`, `707412`, `707542` — sprzedaż eksportowa i wynajem powierzchni
  targowej). Do pliku JPK muszą trafić razem ze znacznikami, więc plan kont
  trzeba uzupełnić. Sumy niewielkie, ale plik bez nich byłby niekompletny.
- Przychody i koszty w ich arkuszu roboczym są o **845 169,48** wyższe niż
  obroty kont — dokładnie tyle po obu stronach. Na wynik i podatek to nie
  wpływa (wynik brutto zgadza się co do grosza), ale warto wiedzieć, skąd.

### Narzędzie

`cit/narzedzia/uzgodnienie-wyniku.py` — z dziennika i znaczników liczy wynik
księgowy, pozycje `K_1`–`K_8` węzła RPD, dochód i podatek (19% i 9%),
porównuje ze wzorcem księgowej i wypisuje konta spoza planu kont.
To jest jądro generatora; brakuje mu jeszcze złożenia XML i oznaczania
pojedynczych wierszy.

## Generator XML i blokada na węźle Dziennik (29.08.2026, wieczór)

`cit/narzedzia/generator-xml.py` składa plik: `Naglowek`, `Podmiot1`,
`Kontrahent`, `ZOiS7` i `RPD`. Na księgach 2025 daje **286 kont w ZOiS
i 2 472 kontrahentów**, a złożony węzeł ZOiS sam się kontroluje:
obroty Wn = Ma (3 634 211 940,19) i salda Wn = Ma (463 755 844,49),
co do grosza. Wyliczone `K_1`–`K_8` dają dokładnie tę samą korektę
(2 098 275,10), co niezależne uzgodnienie wyniku — dwa narzędzia liczą to
samo dwiema drogami.

### Czego z tego eksportu NIE da się złożyć

Plik, który dostaliśmy, to **księga główna (grand livre), nie dziennik**.
Ma konto, datę, kwotę, opis i kod kontrahenta — i to wystarcza na ZOiS i RPD.
Ale węzeł `Dziennik` **jest w schemie obowiązkowy** (`maxOccurs="unbounded"`
bez `minOccurs="0"` — opcjonalny jest tylko `Kontrahent`), a wymaga pól,
których w tym eksporcie nie ma:

| Pole | Czego brakuje |
|---|---|
| `D_1` | numeru zapisu, który spina obie strony księgowania — sprawdzone: klucz `(dziennik, NUECR)` **nie bilansuje się do zera w 59 932 z 64 496 przypadków**, więc nie jest identyfikatorem zapisu |
| `D_4` | numeru dowodu — jest tylko opis, w którym numer czasem występuje, a czasem nie |
| `D_5` | rodzaju dowodu księgowego |
| `D_7`, `D_8` | daty sporządzenia dowodu i daty ujęcia w księgach — eksport ma **jedną** datę |
| `D_9` | osoby odpowiedzialnej za treść zapisu |

Wniosek: potrzebny **drugi eksport — dziennik (livre journal)**, nie księga
główna. To standardowy raport w tym systemie. Bez niego nie ma poprawnego
pliku, a mając go, mamy komplet: reszta jest policzona i sprawdzona.

### Kolejność prac

1. **Poprosić o eksport dziennika** za 2025 z numerem zapisu, numerem
   i rodzajem dowodu, trzema datami i osobą odpowiedzialną. To jedyna
   blokada techniczna.
2. **Dane podmiotu** do nagłówka: NIP, pełna nazwa, REGON, adres, kod urzędu
   skarbowego, czy rok podatkowy = obrotowy, czy stosują CIT estoński albo MSSF.
3. **Oznaczanie pojedynczych wierszy** — dla trzech kont, na których NKUP to
   część zapisów (623150, 661500, 658010). Bez tego dochód jest o 0,64% obok.
4. **Cztery konta bez znacznika** (397120, 409100, 409800, 580001) i **pięć
   kont z dziennika do dopisania w planie** (623300, 707112, 707222, 707412,
   707542) — pytania do księgowej, nie robota programistyczna.
5. **Walidacja schemą** — po zdobyciu plików `.xsd` (właściciel ściąga;
   podatki.gov.pl jest niedostępne z naszego środowiska).
6. **Przeniesienie do przeglądarki** — dopiero gdy plik przejdzie walidację.
   Reguły i słowniki są już w plikach JSON, więc port to przepisanie logiki,
   nie wymyślanie jej od nowa.

### Pole, które wymaga decyzji księgowej

`S_3` (konto nadrzędne) jest wymagane, a ich plan kont jest płaski — same
konta sześciocyfrowe. Generator przyjmuje konto syntetyczne z tego samego
zespołu, a gdy konto samo nim jest, jego trzycyfrowy symbol. To jedyne pole
ZOiS, którego nie da się wyprowadzić z danych bez rozstrzygnięcia.

## Cennik (szkic — do decyzji przy premierze)

Kotwica jak w KSeF: abonament za biuro / licencja jednorazowa. Księgi są
„cięższe" od faktur, więc cena może być wyższa (np. 249 zł/mies. albo 1 490 zł
jednorazowo). Pakiet KSeF + CIT ze zniżką dla obecnych klientów — najprostsza
dosprzedaż jednym mailem.

## Czego NIE robimy teraz

- Nie dodajemy na stronę (ani karty, ani wzmianki) — dopóki v0 nie przejdzie
  testu na prawdziwym pliku.
- Nie ruszamy czasu przeznaczonego na sprzedaż KSeF.
