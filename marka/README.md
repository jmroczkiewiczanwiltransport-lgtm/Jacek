# Znak MBS Business Solutions

## Skąd wziął się znak

Znak równości wycięty z pełnego kwadratu. Powód nie jest dekoracyjny: uzgodnienie to
doprowadzenie dwóch stron do zgodności, a znak równości jest najkrótszym zapisem tej
myśli — i jednocześnie pojęciem księgowym, bo bilans albo się zgadza, albo nie.

Prześwit zrobiony jest regułą `evenodd`, więc przez kreski widać tło. Znak działa
na białym, na ciemnym i na własnym kolorze marki, bez osobnych wersji z podkładem.

Litery to obrysy kroju **Archivo ExtraBold** (skrót) i **Archivo SemiBold** (deskryptor),
zamienione na ścieżki. W plikach nie ma tekstu — znak wyrenderuje się identycznie na
komputerze, na którym nikt nie ma tych krojów.

## Który plik do czego

| Plik | Kiedy |
|---|---|
| `mbs-logo.svg` | podstawowy, na jasnym tle — strona, oferta, dokumenty |
| `mbs-logo-dark.svg` | na ciemnym tle |
| `mbs-logo-mono.svg` | faktury, pieczątki, druk jednokolorowy, faks |
| `mbs-logo-white.svg` | na kolorze marki i na zdjęciach |
| `mbs-kompakt.svg` | znak + MBS bez deskryptora, gdy brakuje szerokości |
| `mbs-kompakt-mono.svg` | to samo w jednym kolorze |
| `mbs-znak.svg` | awatar, ikona, favicon, profil w mediach |
| `mbs-logo-80.png`, `mbs-logo-160.png` | stopka e-maila, Word, miejsca bez obsługi SVG |
| `mbs-logo-mono-80.png` | wzory faktur w programach księgowych |
| `mbs-znak-512.png` … `-32.png` | awatary i ikony w konkretnych rozmiarach |

Pliki PNG mają przezroczyste tło i są wyrenderowane w podwójnej rozdzielczości, żeby
były ostre na ekranach o dużej gęstości pikseli.

## Rozmiary minimalne

- **Pełne logo z deskryptorem**: nie mniej niż **32 px wysokości** na ekranie i **9 mm**
  w druku. Poniżej „BUSINESS SOLUTIONS" przestaje być czytelne — wtedy używaj wersji
  zwartej, a nie mniejszego pełnego logo.
- **Wersja zwarta**: od 20 px wysokości.
- **Sam znak**: od 16 px, ale przy 16 px prześwit zlewa się — jeśli masz wybór, dawaj 32 px.

## Pole ochronne

Wokół logo zostaw wolną przestrzeń równą **wysokości jednej kreski znaku** (to jedna ósma
wysokości kwadratu). Nie wciskaj logo w narożnik i nie stawiaj obok niego innych znaków
bliżej niż na tę odległość.

## Kolory

| Rola | Wartość | Gdzie |
|---|---|---|
| Zieleń podstawowa | `#0F6E64` | znak na jasnym tle |
| Zieleń na ciemnym | `#39B39F` | znak na ciemnym tle |
| Atrament | `#151C1E` | napis na jasnym tle |
| Biel | `#FFFFFF` | napis i znak na ciemnym tle |

Do druku offsetowego zieleń podstawowa to w przybliżeniu **CMYK 88 / 33 / 55 / 25**.
Przy zamówieniu wizytówek podaj drukarni wartość CMYK, nie kod szesnastkowy — inaczej
sam przeliczy i wyjdzie jaśniejsza.

## Czego nie robić

- nie rozciągaj nieproporcjonalnie i nie przekrzywiaj,
- nie zmieniaj koloru znaku na inny niż z tabeli powyżej,
- nie dodawaj cienia, obwódki ani gradientu,
- nie zamieniaj deskryptora na inny tekst — jeśli nie pasuje, użyj wersji zwartej,
- nie stawiaj wersji jasnozielonej na białym tle (za mały kontrast),
- nie odtwarzaj logo z pliku PNG w dużym rozmiarze — do dużych zastosowań jest SVG.

## Jak powstają pliki

Generator: `tools/genlogo.js` (kopia w katalogu narzędzi projektu). Buduje ścieżki
z obrysów kroju przez `opentype.js` i sam sprawdza wynik: brak `NaN` we współrzędnych
i domknięcie każdego konturu. Bez tej kontroli pierwsza wersja wyszła z uszkodzonym
glifem i połowa deskryptora się nie rysowała — dlatego kontrola została w kodzie.

Wersje rastrowe: `tools/raster.js`, renderowanie przez przeglądarkę z przezroczystym tłem.
