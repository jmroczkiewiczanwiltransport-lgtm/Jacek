# KSeF Uzgodnienia

Aplikacja do uzgadniania eksportu z KSeF z rejestrem zakupu. Jeden plik HTML, działa
w przeglądarce, bez serwera i bez bazy danych. Żaden plik nie jest nigdzie wysyłany —
całe przetwarzanie odbywa się na komputerze użytkownika.

## Co robi

Wczytuje dwa arkusze i zestawia je ze sobą w obie strony:

**Rejestr → KSeF**
- uzupełnia brakujące numery KSeF tam, gdzie dopasowanie jest jednoznaczne,
- wykrywa numery **błędne** — wpisane, ale niezgodne z KSeF (kategoria „Korekty"),
- oznacza numery **do wyjaśnienia** — nieistniejące w KSeF, o złym formacie albo
  z NIP-em innym niż NIP dostawcy,
- zostawia puste te pozycje, których w KSeF nie ma (dokumenty spoza KSeF, flagi BFK/DI).

**KSeF → rejestr**
- wskazuje faktury, które są w KSeF, ale **nie mają odpowiednika w rejestrze**.
  To najcenniejsza część wyniku: każda taka pozycja to potencjalnie nieodliczony VAT
  i niezaksięgowany koszt.

## Zasady dopasowania

Klucz podstawowy: **NIP + numer faktury** znormalizowany (bez spacji, wielkie litery).

Kolejne próby, gdy klucz podstawowy nie trafia:
1. porównanie tylko znaków alfanumerycznych (`FV/001/26` = `FV-001-26`),
2. dopasowanie podciągiem w ramach tego samego NIP-u.

Dopasowania z punktów 1–2 są oznaczane jako **przybliżone — sprawdź**. Dopasowanie
następuje wyłącznie wtedy, gdy kandydat jest jeden; przy kilku kandydatach pozycja
trafia do „Bez dopasowania" z listą numerów.

**Plik KSeF jest źródłem prawdy.** Jeśli wpisany numer różni się od numeru z KSeF przy
zgodnym kluczu, to wpisany numer jest błędny — trafia do korekt.

## Trzy sposoby odebrania wyniku

| Sposób | Kiedy używać | Ryzyko |
|---|---|---|
| **Raport .xlsx** | zawsze — dokumentacja kontrolna, każda kategoria na osobnej karcie z numerem wiersza | brak |
| **Kolumna do wklejenia** | gdy rejestr zawiera formuły lub łącza zewnętrzne (np. plik idący pod JPK) | brak — nie rusza pliku |
| **Uzupełniony rejestr .xlsx** | gdy rejestr to zwykły eksport bez formuł | zapis przez przeglądarkę może zniszczyć formuły i łącza zewnętrzne — aplikacja ostrzega, gdy je wykryje |

Kolumna do wklejenia jest wyrównana do wierszy rejestru: pierwsza wartość odpowiada
pierwszemu wierszowi danych, puste wiersze są zachowane. Wolno ją wklejać tylko wtedy,
gdy plik nie był w międzyczasie sortowany.

## Budowa i uruchomienie

```bash
./build.sh
```

Powstają cztery pliki:

- `dist/ksef-uzgodnienia.html` — samowystarczalny plik do rozdawania i uruchamiania
  z dysku (otwiera się dwuklikiem, także bez internetu),
- `dist/artifact-body.html` — fragment aplikacji do publikacji jako strona,
- `dist/strona.html` — strona usługowa jako kompletny dokument, do hostowania,
- `dist/oferta.html` — jednostronicowa oferta jako kompletny dokument.

**Do hostowania i wysyłania używaj wyłącznie plików z `dist/`.** Źródła w `strona/`
i `sprzedaz/` są fragmentami bez `<!doctype>` i bez `<meta charset>` — służą tylko
publikacji, gdzie brakujące znaczniki dodaje platforma. Otwarte z dysku albo
wystawione na serwerze bez nagłówka `charset` psują polskie znaki: Firefox i Safari
czytają wtedy plik jako windows-1252 i zamiast „którą" wychodzi „ktÃ³rÄ…".

Źródła: `src/app.css`, `src/app.body.html`, `src/app.js`.
Biblioteka: `vendor/xlsx.full.min.js` (SheetJS 0.18.5, Apache-2.0) — wbudowana w wynik,
żeby plik działał offline.

Kroje pisma pobierane są z Google Fonts. Bez internetu aplikacja działa normalnie,
tylko z krojami systemowymi.

## Narzędzia pomocnicze

Sama aplikacja i strony nie mają zależności — budują się skryptem `./build.sh`.
Narzędzia do znaku marki i PDF wymagają pakietów npm:

```bash
npm install          # kroje pisma, opentype.js, playwright-core
npm run pdf          # dist/MBS-oferta-KSeF.pdf z osadzonymi krojami
npm run logo         # marka/*.svg i marka/*.png
npm run keys         # dziesięć nowych kluczy licencyjnych
```

Przeglądarka do generowania PDF i plików PNG jest brana z `PLAYWRIGHT_BROWSERS_PATH`,
a nie pobierana.

## Dwie wersje, dwa zestawy możliwości

Ten sam kod źródłowy daje dwa warianty, bo przeglądarkowy podglądacz stron nie pozwala
stronie zapisywać plików bezpośrednio.

| | Plik z dysku (`dist/ksef-uzgodnienia.html`) | Strona opublikowana |
|---|---|---|
| Raport | `.xlsx`, każda kategoria na osobnej karcie | `.csv` (rozdzielany średnikiem, z BOM), przy braku zgody na `.csv` — `.txt` |
| Kolumna do wklejenia | tak | tak |
| Zapis uzupełnionego rejestru | tak | nie — strona nie może nadpisać pliku na dysku |
| Działa bez internetu | tak | nie |
| Biblioteka SheetJS | pełna | `core` (bez tablic stron kodowych) |

Aplikacja sama rozpoznaje, w którym trybie działa, i dostosowuje przyciski oraz opisy.
Wersję opublikowaną traktuj jako demo do wysłania klientowi; do pracy wydawaj plik z dysku.

## Licencjonowanie

Wersja bez klucza jest w pełni sprawna na ekranie — **limit dotyczy tylko eksportu**
(pierwsze 100 pozycji na karcie raportu i w kolumnie do wklejenia). Taki gate pokazuje
całą wartość przed zakupem, a płaci się za wynik do pracy.

Generowanie kluczy:

```bash
node tools/keygen.js 10          # wypisz 10 nowych kluczy
node tools/keygen.js KSU-...     # sprawdź, czy klucz jest poprawny
```

Klucz jest weryfikowany offline sumą kontrolną — nie ma serwera licencji, więc nie ma
czego blokować i nie ma jak podejrzeć, kto pracuje na pliku.

**Uczciwie o ograniczeniu:** klucz i sól (`SALT` w `src/app.js`) siedzą w kodzie strony,
więc osoba, która potrafi czytać JavaScript, obejdzie limit w kilka minut. Dla odbiorcy
biurowego to wystarczająca bariera, ale nie jest to zabezpieczenie kryptograficzne.
Jeśli kiedyś okaże się to problemem, właściwym krokiem jest podpisywanie kluczy
kluczem prywatnym i wiązanie ich z NIP-em nabywcy, a nie utrudnianie kodu.

Zmiana `SALT` unieważnia wszystkie wcześniej wydane klucze.

## Struktura projektu

```
src/app.css          styl (paleta, typografia, układ)
src/app.body.html    struktura strony
src/app.js           rozpoznawanie kolumn, dopasowanie, eksporty, licencja
vendor/              SheetJS
tools/keygen.js      generator kluczy licencyjnych
build.sh             składa dist/
dist/                wynik budowy (do rozdawania)
```

## Uwagi wdrożeniowe

- Rozpoznawanie kolumn i wiersza nagłówka jest automatyczne, ale zawsze pokazywane
  użytkownikowi do zatwierdzenia w kroku 2. Każdy program księgowy nazywa kolumny
  inaczej, więc automat ma być pomocą, nie założeniem.
- Arkusz z pustym marginesem u góry nie rozjeżdża numeracji: zakres wymuszany jest
  od komórki A1, żeby indeks wiersza zawsze odpowiadał numerowi w Excelu.
- Faktura obecna w rejestrze, ale mająca w KSeF kilka numerów na ten sam klucz, nie
  jest raportowana jako „brak w rejestrze" — trafia do „Bez dopasowania" z listą
  kandydatów, bo problem jest po stronie KSeF.
- Na ekranie renderowane jest maksymalnie 500 pozycji na kategorię; raport .xlsx
  zawiera wszystkie.
