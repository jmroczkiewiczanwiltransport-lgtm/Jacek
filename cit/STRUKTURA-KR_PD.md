# JPK_KR_PD — struktura pliku (wyciąg z dokumentacji MF)

Źródło: broszura informacyjna MF (maj 2024, wyd. 1) + aktualizacja stron 4–5
obowiązująca od 01.07.2026 + schemat `Schemat_JPK_KR_PD(1)_v1-1`.
Materiały dostarczone przez Alicję 28.08.2026 (6 PDF-ów).

**Uwaga: mamy schemat jako PDF, nie jako plik .xsd.** Do generowania to
wystarcza (kolejność i typy pól są w PDF-ie w całości), ale do automatycznej
walidacji plikiem schemy potrzebny jest `.xsd` z BIP MF. Do dobrania.

## Nagłówek — wartości stałe

| Pole | Wartość |
|---|---|
| `kodSystemowy` | `JPK_KR_PD (1)` |
| **`wersjaSchemy`** | **`1-1`** (aktualizacja MF: nie `1-0`, jak w pierwszym wydaniu broszury) |
| `WariantFormularza` | `1` |
| `CelZlozenia` | `1` pierwsze złożenie, `2` korekta |
| `DomyslnyKodWaluty` | kod ISO-4217 (słownik 181 walut w schemie) |

Pola okresu: `DataOd`/`DataDo` (okres pliku), `RokDataOd`/`RokDataDo` (rok
obrotowy), `RokPdDataOd`/`RokPdDataDo` — **tylko** gdy rok podatkowy różni się
od obrotowego. Plus `KodUrzedu`, `DataWytworzeniaJPK` (znacznik czasu UTC).

## Węzły pliku

`Naglowek` → `Podmiot1` → `Kontrahent` → `ZOiS` → `Dziennik` → `Ctrl` → `RPD`

- **Podmiot1**: `IdentyfikatorPodmiotu` (NIP, PelnaNazwa do 240 znaków, REGON
  opcjonalny) + `Adres` (`AdresPol` albo `AdresZagr`) + opcjonalne znaczniki
  `Znacznik_EST` (CIT estoński) i `Znacznik_MSSF`.
- **Kontrahent** (opcjonalny): `T_1` kod kontrahenta z systemu FK (do 256 zn.),
  `T_2` kod kraju nadania NIP, `T_3` numer identyfikacji podatkowej bez kodu
  kraju. Wskazuje się kontrahentów, z którymi były operacje w okresie.
- **ZOiS**: `xsd:choice` — wybiera się **jeden** z węzłów `ZOiS1`–`ZOiS8`
  zależnie od typu jednostki, i powtarza go dla każdego konta (`maxOccurs="unbounded"`).
- **Dziennik**: `D_1`–`D_12` + zagnieżdżony `KontoZapis` (`Z_1`–`Z_9`).
- **Ctrl**: `C_1`–`C_5` — sumy kontrolne.
- **RPD**: `K_1`–`K_8` — przejście z wyniku księgowego na podatkowy.

### Który ZOiS

| Węzeł | Dla kogo | Znacznik `S_12_1` |
|---|---|---|
| ZOiS1 | banki | `TMapKontaBanki` (131 pozycji) |
| ZOiS2 | ubezpieczyciele i reasekuracja | `TMapKontaUbezp` (205) |
| ZOiS3 | organizacje pożytku publicznego | `TMapKontaPP` (109) |
| ZOiS4 | fundusze inwestycyjne | `TMapKontaFI` (39) |
| ZOiS5 | domy maklerskie | `TMapKontaDM` (209) |
| ZOiS6 | SKOK | `TMapKontaSKOK` (85) |
| **ZOiS7** | **jednostki pozostałe — normalna spółka** | **`TMapKontaPOZ` (244), WYMAGANY** |
| ZOiS8 | jednostki stosujące MSSF | `TZnakowyJPK` — pole **opcjonalne**, dowolny tekst |

To rozróżnienie ma duże znaczenie dla ceny pracy: w **ZOiS7 znacznik jest
obowiązkowy dla każdego konta**, w **ZOiS8 (MSSF) jest opcjonalny**. Do
potwierdzenia z każdym klientem osobno, czy księgi statutowe PL są prowadzone
wg ustawy o rachunkowości (→ ZOiS7), czy wg MSSF (→ ZOiS8).

### Pola ZOiS (identyczne w ZOiS1–ZOiS8)

| Pole | Znaczenie |
|---|---|
| `S_1` | identyfikator konta ostatniego poziomu analitycznego (np. „011-4-1") |
| `S_2` | nazwa konta |
| `S_3` | identyfikator konta nadrzędnego |
| `S_4` / `S_5` | bilans otwarcia Wn / Ma |
| `S_6` / `S_7` | obroty okresu Wn / Ma |
| `S_8` / `S_9` | obroty narastająco od otwarcia ksiąg Wn / Ma |
| `S_10` / `S_11` | saldo na koniec okresu Wn / Ma (z bilansem otwarcia) |
| `S_12_1` | znacznik pozycji bilansu / RZiS — **wymagany** (poza ZOiS8) |
| `S_12_2` | drugi znacznik tego samego typu — opcjonalny |
| `S_12_3` | znacznik podatkowy `TMapKontaPD` (28 pozycji) — opcjonalny |

Czyli **maksymalnie 2 znaczniki bilansowe + 1 podatkowy na konto.**

### Pola Dziennik

| Pole | Znaczenie |
|---|---|
| `D_1` | numer zapisu w dzienniku, ciągły w roku (np. „1/Zak/01/2025") |
| `D_2` | opis / nazwa dziennika częściowego („Zakup", „Sprzedaż") |
| `D_3` | kod kontrahenta — ten sam co `T_1` (opcjonalny) |
| `D_4` | numer dowodu nadany przez wystawcę |
| `D_5` | rodzaj dowodu księgowego |
| `D_6` | data operacji gospodarczej |
| `D_7` | data sporządzenia dowodu (gdy brak — data operacji) |
| `D_8` | data ujęcia dowodu w księgach |
| `D_9` | osoba odpowiedzialna za treść zapisu |
| `D_10` | opis operacji (do 512 znaków) |
| `D_11` | kwota operacji gospodarczej |
| `D_12` | numer KSeF faktury (opcjonalny, wymagany dla faktur z KSeF) |

`KontoZapis` (wiele na zapis): `Z_1` numer kolejny, `Z_2` opis linii,
`Z_3` konto (= `S_1` z ZOiS), `Z_4`/`Z_7` kwota Wn / Ma,
`Z_5`/`Z_8` kwota w walucie obcej, `Z_6`/`Z_9` kod waluty.

**`D_12` jest łącznikiem z naszym pierwszym narzędziem** — numer KSeF wędruje
z rejestru zakupu do księgi. Kto ma poukładany KSeF, ma poukładany JPK_KR_PD.

### Ctrl — sumy kontrolne

| Pole | Co liczy |
|---|---|
| `C_1` | liczba zapisów w `Dziennik` |
| `C_2` | suma `D_11` |
| `C_3` | liczba zapisów w `KontoZapis` |
| `C_4` | suma `Z_4` (Winien) |
| `C_5` | suma `Z_7` (Ma) |

### RPD — i czego w nim NIE ma

| Pole | Znaczenie |
|---|---|
| `K_1` | przychody zwolnione z opodatkowania (różnice trwałe) |
| `K_2` | przychody niepodlegające opodatkowaniu w roku bieżącym |
| `K_3` | przychody opodatkowane w roku bieżącym, ujęte w księgach lat ubiegłych |
| `K_4` | koszty niestanowiące KUP (różnice trwałe) |
| `K_5` | koszty nieuznawane za KUP w roku bieżącym |
| `K_6` | koszty uznane za KUP w roku bieżącym, ujęte w księgach lat ubiegłych |
| `K_7` | przychody podlegające opodatkowaniu nieujmowane w księgach |
| `K_8` | koszty uznawane za KUP nieujmowane w księgach |

**W JPK_KR_PD nie ma pola na wynik i nie ma pola na kwotę podatku.** Plik
zawiera księgi i osiem korekt podatkowych; wynik i podatek fiskus liczy sobie
sam, zestawiając to z CIT-8. To zmienia zakres obietnicy wobec Alicji: kwotę
podatku narzędzie **wylicza jako pomoc roboczą do CIT-8 i jako kontrolę
poprawności mapowania**, ale nie jest to element raportu.

## Typy pól

| Typ | Ograniczenie |
|---|---|
| `TKwotowy` | decimal, max 18 cyfr, dokładnie 2 po przecinku |
| `TZnakowyJPK` | 1–256 znaków |
| `TZnakowy512` | 1–512 znaków |
| `TNaturalnyJPK` | liczba naturalna > 0 |
| `TNumerKSeF` | typ dedykowany numerowi KSeF |
| kodowanie | XML, UTF-8 (polskie znaki obowiązkowo w UTF-8) |

## Znaczniki podatkowe `TMapKontaPD` (28)

Bilansowe: `PD1`, `PD1_1`, `PD1_2`, `PD1_3`, `PD2`, `PD4`, `PD4_1`, `PD4_2`,
`PD4_3`, `PD5`, `PD7`, `PD8_1`, `PD8_2`.
Pozabilansowe (te same tytuły z sufiksem `_PB`, dodatkowo `PD3_PB` i `PD6_PB`).

Odpowiadają pozycjom RPD: PD1 → K_1, PD2 → K_2, PD3 → K_3, PD4 → K_4,
PD5 → K_5, PD6 → K_6; osobno `PD7` (ulga B+R) i `PD8_1`/`PD8_2` (IP Box).

Pełne słowniki (wszystkie 8 typów + PD, z opisami MF) w
`cit/slowniki/znaczniki-KR_PD.json`, generowane skryptem
`cit/narzedzia/wyciag-slownikow.py` z tekstu schematu.

## Terminy (stan po aktualizacji MF od 01.07.2026)

- **Fala 1** — PGK i podatnicy > 50 mln EUR przychodu: rok rozpoczynający się
  po 31.12.2024. Rok kończący się przed 31.12.2025 → wysyłka **do końca lipca 2026**
  (rozporządzenie z 16.02.2026, Dz.U. poz. 188).
- **Fala 2 — nasz rynek** — podatnicy składający JPK_V7M: rok rozpoczynający się
  po **31.12.2025**, czyli dla roku kalendarzowego **rok 2026, wysyłka do końca
  lipca 2027**. Termin ogólny: koniec siódmego miesiąca po zakończeniu roku.
- **Fala 3** — pozostali, w tym JPK_V7K: rok rozpoczynający się po 31.12.2026.
- PIT: JPK_V7M-owcy od roku po 31.12.2025, pozostali po 31.12.2026, wysyłka do 31 lipca.

Zwolnieni: podatnicy zwolnieni podmiotowo (poza fundacjami rodzinnymi),
uprawnieni do zeznania papierowego, prowadzący uproszczoną ewidencję.

**Pełnomocnictwo UPL-1 obejmuje podpisywanie JPK_KR_PD** — od 16.06.2026
(Dz.U. poz. 779). Argument sprzedażowy: nie trzeba nowych pełnomocnictw.

## JPK_ST_KR (środki trwałe) — etap 2

Struktura znacznie prostsza: `Naglowek` → `Podmiot1` → `ST_KR`, gdzie `ST_KR`
to jeden płaski węzeł na składnik majątku, pola `E_1`–`E_32` (w tym `KSeF`).
Nagłówek bez `DataOd`/`DataDo` — plik jest roczny.
Słowniki: `TMetodaAmoryzacji` (5), `TNabycia` (6), `TOdpis` (7),
`TWykreslenie` (7) — w `cit/slowniki/znaczniki-ST_KR.json`.
