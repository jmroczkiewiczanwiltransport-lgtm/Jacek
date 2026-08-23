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

Cena (kotwice rynkowe sprawdzone 24.08.2026): wdrożenia ERP z JPK_CIT to
10–40 tys. zł + 6–15 tys./rok utrzymania; moduły programów księgowych od ~1,2 tys.
za stanowisko + 30–50% licencji rocznie za aktualizacje, a JPK_CIT często wymusza
płatny upgrade. Biuro rachunkowe nie kupi żadnej z tych opcji — nasza półka jest
pomiędzy. Propozycja: **wdrożenie 2 900 zł netto za biuro** (z mapowaniem pierwszej
spółki i wyjściem na wynik zgodny z CIT-8) + **utrzymanie 990 zł/rok** (aktualizacje
struktur MF — wersja (2) przyjdzie — poprawki, wsparcie; bez limitu spółek);
etap ŚT (+900 zł), gdy obowiązek dojdzie. Do decyzji po v0.

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

1. **XSD struktury JPK_KR_PD(1) + broszura MF** — Alicja już deklaruje: „przygotuję
   pliki z MF ze schemą". Może też wrzucić właściciel (podatki.gov.pl → struktury JPK).
2. **Eksport dziennika zapisów za rok** z jej programu (xlsx/csv) — dane firmy
   testowej albo zanonimizowane. To jest GŁÓWNE wejście narzędzia.
3. **Plan kont** tej samej firmy (wykaz kont z nazwami).
4. **Jak dziś grupują konta do wyniku** — ich robocze mapowanie (choćby w Excelu
   albo opisane słowami), czyli które konta idą do jakiej pozycji wyniku.
5. **Wyliczenie podatku za ten rok do porównania** (CIT-8 albo robocze wyliczenie) —
   żeby v0 miało wzorzec: nasz wynik musi zgadzać się z jej wynikiem.
6. Jeśli jej program jednak COŚ generuje (choćby stary JPK_KR) — plik jako odniesienie.

## Cennik (szkic — do decyzji przy premierze)

Kotwica jak w KSeF: abonament za biuro / licencja jednorazowa. Księgi są
„cięższe" od faktur, więc cena może być wyższa (np. 249 zł/mies. albo 1 490 zł
jednorazowo). Pakiet KSeF + CIT ze zniżką dla obecnych klientów — najprostsza
dosprzedaż jednym mailem.

## Czego NIE robimy teraz

- Nie dodajemy na stronę (ani karty, ani wzmianki) — dopóki v0 nie przejdzie
  testu na prawdziwym pliku.
- Nie ruszamy czasu przeznaczonego na sprzedaż KSeF.
