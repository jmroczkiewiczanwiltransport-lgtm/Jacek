# Światła Tuya / SmartLife — sterowanie i automatyka

Sterowanie sterownikami MiBoxer i innymi urządzeniami z aplikacji SmartLife: panel
w przeglądarce, polecenia z konsoli i automatyka względem wschodu i zachodu słońca.

Domyślnie wszystko dzieje się **w sieci lokalnej** — komputer rozmawia ze sterownikami
wprost, bez pośrednictwa chmury. Jest szybciej i działa nawet wtedy, gdy padnie internet.
Gdy urządzenia nie ma w sieci (np. jesteś poza domem albo zmienił adres), polecenie idzie
przez chmurę Tuya, o ile ją skonfigurujesz.

| Plik | Do czego |
|---|---|
| `tuya.py` | polecenia, automatyka w tle, serwer panelu |
| `panel.html` | panel w przeglądarce |
| `urzadzenia.json` | Twoje urządzenia i klucze — **powstaje przy konfiguracji, nie trafia do repozytorium** |
| `automatyka.json` | sceny i reguły — powstaje przy pierwszym zapisie z panelu |

Wymagany Python 3.9+ i jedna biblioteka:

```bash
pip3 install tinytuya
```

## Klucze — jednorazowa konfiguracja

Sterowniki Tuya rozmawiają po sieci lokalnej, ale szyfrują — każde urządzenie ma własny
**klucz lokalny**. Klucze wydaje wyłącznie Tuya i idzie się po nie na ich portal
deweloperski. To jedyny moment, w którym potrzebna jest chmura; potem można ją odłączyć.

1. Załóż darmowe konto na **iot.tuya.com**.
2. **Cloud → Development → Create Cloud Project.**
   - Industry: *Smart Home*, Development Method: *Smart Home*,
   - **Data Center: Central Europe** — musi być ten sam region, w którym działa
     Twoje konto SmartLife. Zły region to najczęstsza przyczyna „nie widzę urządzeń".
3. Po utworzeniu projektu zapisz **Access ID** i **Access Secret**.
4. Zakładka **Service API** — dodaj do projektu *IoT Core* oraz *Authorization*
   (a jeśli jest na liście, też *Smart Home Basic Service*).
5. Zakładka **Devices → Link App Account → Add App Account** — pokaże się kod QR.
   W telefonie: SmartLife → **Ja** → ikona skanowania w prawym górnym rogu → zeskanuj.
   Po chwili na liście *Devices* pojawią się Twoje ledy.
6. W repozytorium:

   ```bash
   cd tuya
   python3 tuya.py klucze
   ```

   Kreator zapyta o Access ID, Access Secret, region (`eu`) i identyfikator dowolnego
   urządzenia z listy *Devices*. Pobierze klucze i zapisze `urzadzenia.json`.

7. Znajdź urządzenia w sieci i uzupełnij adresy:

   ```bash
   python3 tuya.py skanuj
   ```

8. Otwórz `urzadzenia.json` i **dopisz grupy** — to one robią porządek:

   ```json
   {"nazwa": "Ledy front", "grupy": ["elewacja"], ...}
   ```

Projekt deweloperski Tuya jest darmowy, ale **próbny okres trzeba raz na jakiś czas
przedłużyć** na portalu (Cloud → Project → Extend Trial). Sterowanie lokalne działa
niezależnie od tego — przedłużenie jest potrzebne tylko wtedy, gdy chcesz korzystać
z chmury albo pobrać klucze na nowo.

> `urzadzenia.json` zawiera klucze do Twoich urządzeń. Jest wpisany do `.gitignore`
> i nie powinien trafić ani do repozytorium, ani do nikogo poza Tobą.

## Panel

```bash
python3 tuya.py panel
```

Otwiera się pod `http://localhost:8124`.

- **Sterowanie** — sceny, wszystko naraz, grupy, pojedyncze urządzenia: włącznik,
  jasność i barwa. Procenty są liczone tak samo jak w SmartLife, więc wartości
  zgadzają się z tym, co widzisz w telefonie.
- **Automatyka** — sceny i reguły czasowe, klikane; zapisują się do `automatyka.json`.
- **Diagnostyka** — kto odpowiada lokalnie, kto tylko przez chmurę, kto wcale,
  jakie adresy, jakie protokoły i surowe parametry (przydatne, gdy sterownik ma
  nietypową numerację funkcji).

## Polecenia

```
python3 tuya.py lista                 urządzenia, grupy, sceny
python3 tuya.py diagnostyka           łączność, adresy, protokoły
python3 tuya.py dps <cel>             surowe parametry urządzenia

python3 tuya.py wlacz <cel>
python3 tuya.py wylacz <cel>
python3 tuya.py przelacz <cel>
python3 tuya.py jasnosc <cel> <0-100>
python3 tuya.py barwa <cel> <0-100>        0 = ciepła, 100 = zimna
python3 tuya.py scena <nazwa>

python3 tuya.py skanuj                szuka urządzeń i uaktualnia adresy
python3 tuya.py klucze                pobiera klucze z konta Tuya
python3 tuya.py automat [plik.json]   uruchamia automatykę
python3 tuya.py panel [port]          panel w przeglądarce
```

**Cel** to `wszystko`, `grupa:elewacja` albo nazwa urządzenia — wystarczy fragment,
ogonki i wielkość liter nie mają znaczenia (`ledy ogrod` trafi w „Ledy ogród").

```bash
python3 tuya.py jasnosc grupa:elewacja 60
python3 tuya.py wylacz wszystko --przejscie 30
```

`--przejscie` rozkłada zmianę jasności na kilkadziesiąt kroków po stronie komputera —
sterowniki Tuya nie mają płynnego ściemniania same z siebie.

## Automatyka

Reguły siedzą w `automatyka.json` (wzór: `automatyka.przyklad.json`), a wykonuje je:

```bash
python3 tuya.py automat
```

Plik przeładowuje się sam po zapisie z panelu, bez restartu.

### Sceny

Scena to lista kroków — każdy krok robi coś innej grupie:

```json
"Wieczor": [
  { "cel": "grupa:elewacja", "akcja": { "wlacz": true, "jasnosc": 60, "barwa": 10 } },
  { "cel": "grupa:ogrod",    "akcja": { "wlacz": true, "jasnosc": 45, "barwa": 0 } }
]
```

### Reguły czasowe

```json
{ "nazwa": "Zapal o zmierzchu", "o": "zachod-00:15", "akcja": { "scena": "Wieczor" } }
```

Godzina to `22:30` albo `wschod` / `zachod` z przesunięciem (`zachod-00:15`,
`wschod+01:00`). Pory słońca liczone są na miejscu z pola `polozenie` — z dokładnością
do 2–3 minut i bez pytania kogokolwiek w internecie. Pusta lista `dni` znaczy
„codziennie”, inaczej `["pn","wt","sr","cz","pt"]`. Reguła odpala się raz dziennie.

### Akcje

| Pole | Znaczenie |
|---|---|
| `wlacz` | `true` / `false` |
| `przelacz` | odwraca bieżący stan |
| `scena` | nazwa sceny z tego pliku |
| `jasnosc` | 0–100 (%) — ustawienie jasności samo zapala światło, 0 gasi |
| `barwa` | 0–100 (%), 0 = ciepła, 100 = zimna |
| `przejscie` | sekundy płynnej zmiany |

Urządzenia, które danej funkcji nie mają (jak przełącznik garażu), po prostu ją pomijają.

### Symulacja obecności

```json
{ "wlaczona": true, "cel": "grupa:elewacja", "od": "zachod", "do": "23:00",
  "minPrzerwa": 20, "maxPrzerwa": 60, "jasnosc": 55 }
```

Losowo zapala i gasi światło w podanym oknie czasowym.

## Automatyka na stałe

**Linux (systemd, dla użytkownika):** `~/.config/systemd/user/tuya.service`

```ini
[Unit]
Description=Automatyka swiatel Tuya
[Service]
ExecStart=/usr/bin/python3 /sciezka/do/tuya/tuya.py automat
Restart=always
[Install]
WantedBy=default.target
```

```bash
systemctl --user enable --now tuya.service
journalctl --user -u tuya.service -f
```

**Windows:** Harmonogram zadań → zadanie uruchamiane przy logowaniu, program `python`,
argumenty `C:\sciezka\tuya\tuya.py automat`.

## Co warto zostawić w aplikacji SmartLife

Ta automatyka działa tylko wtedy, gdy komputer nie śpi. Automatyzacje zapisane
w aplikacji SmartLife wykonuje chmura Tuya i działają zawsze — dlatego rozsądny podział
wygląda tak:

- **w aplikacji**: rzeczy, które muszą zadziałać niezależnie od wszystkiego —
  zapalenie elewacji o zmierzchu, zgaszenie w środku nocy,
- **tutaj**: sterowanie ręczne z komputera, sceny z dokładnymi wartościami, płynne
  ściemnianie, symulacja obecności, diagnostyka i wszystko, czego aplikacja nie umie.

Jedno drugiego nie blokuje — obie strony wydają temu samemu sterownikowi zwykłe polecenia.

## Gdy coś nie działa

| Objaw | Co sprawdzić |
|---|---|
| `nie odpowiada (901)` | urządzenie zmieniło adres — `python3 tuya.py skanuj`; docelowo zarezerwuj mu stały adres na routerze |
| odpowiada tylko przez chmurę | to samo co wyżej — lokalnie jest szybciej |
| `Unexpected Payload` / `904` | zły klucz lokalny albo zła wersja protokołu; pobierz klucze na nowo (`klucze`) i sprawdź pole `wersja` |
| po ponownym dodaniu urządzenia w aplikacji przestało działać | dodanie urządzenia od nowa zmienia klucz lokalny — uruchom `python3 tuya.py klucze` |
| sterownik reaguje na włącznik, ale nie na jasność | ma inną numerację funkcji — zobacz `python3 tuya.py dps <nazwa>` i dopisz w `urzadzenia.json` pole `dp` |

Jeśli pod przekaźnikiem („Garaż") siedzi napęd bramy, a nie oświetlenie, nie wstawiaj go
do scen ani reguł czasowych, które chodzą bez nadzoru.

## Prywatność

Sterowanie odbywa się w sieci lokalnej. Do chmury Tuya idzie tylko pobranie kluczy
przy konfiguracji oraz — jeśli ją włączysz — polecenia do urządzeń nieobecnych w sieci.
Klucze leżą wyłącznie na Twoim komputerze.
