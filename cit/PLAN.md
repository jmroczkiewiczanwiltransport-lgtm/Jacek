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

## Koncepcja

„KSeF Uzgodnienia dla ksiąg": program księgowy **generuje** JPK_KR_PD, ale nikt nie
daje księgowej narzędzia, żeby plik **sprawdzić przed wysyłką**. Ta sama architektura:
jeden plik HTML, wszystko w przeglądarce, księgi nie opuszczają komputera (dane
wrażliwsze niż faktury — argument gra jeszcze mocniej).

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

## Czego potrzebuję, zanim napiszę pierwszą linię

Lekcja z KSeF: prawdziwy plik przemodelował narzędzie trzykrotnie
(kolumny, zera, K_44/K_45). Nie budujemy na ślepo.

1. **Oficjalny XSD struktury JPK_KR_PD(1)** + **broszura informacyjna MF** —
   serwery gov.pl są zablokowane z sesji Claude; właściciel pobiera je u siebie
   (podatki.gov.pl → struktury JPK / CRIP) i wrzuca do rozmowy jak zwykłe pliki.
2. **Testowy JPK_KR_PD z prawdziwego programu księgowego** — poprosić Alicję,
   żeby wygenerowała plik dla firmy testowej/zanonimizowanej ze swojego programu.
   Jej program ma już moduł JPK_CIT (wszystkie mają od 2025).
3. **Odpowiedź Alicji na pytanie:** „obsługujecie spółki z o.o.? co w JPK_CIT
   boli najbardziej?" — jej ból = kolejność kafli, jak przy KSeF.

## Cennik (szkic — do decyzji przy premierze)

Kotwica jak w KSeF: abonament za biuro / licencja jednorazowa. Księgi są
„cięższe" od faktur, więc cena może być wyższa (np. 249 zł/mies. albo 1 490 zł
jednorazowo). Pakiet KSeF + CIT ze zniżką dla obecnych klientów — najprostsza
dosprzedaż jednym mailem.

## Czego NIE robimy teraz

- Nie dodajemy na stronę (ani karty, ani wzmianki) — dopóki v0 nie przejdzie
  testu na prawdziwym pliku.
- Nie ruszamy czasu przeznaczonego na sprzedaż KSeF.
