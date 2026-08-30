# Mostek Hue — sterowanie i automatyka

Sterowanie mostkiem Philips Hue i podpiętymi do niego urządzeniami: ręcznie z panelu
w przeglądarce, harmonogramami i regułami z konsoli. Wszystko działa w sieci lokalnej,
bez chmury Philipsa i bez konta — panel rozmawia z mostkiem bezpośrednio.

Dwa pliki, obydwa bez żadnych zależności:

| Plik | Do czego |
|---|---|
| `panel.html` | panel w przeglądarce: światła, sceny, czujniki, diagnostyka, edytor reguł |
| `hue.mjs` | polecenia konsolowe, automatyka działająca w tle, serwer panelu |

Wymagany Node 18 lub nowszy (`node --version`).

## Pierwsze uruchomienie

```bash
node hue.mjs polacz
```

Skrypt sam znajdzie mostek (przez usługę Philipsa, a bez internetu — przeglądając
sieć lokalną) i poprosi o naciśnięcie okrągłego przycisku na obudowie. Masz na to
60 sekund. Jeśli mostków jest kilka albo automat go nie widzi, podaj adres:
`node hue.mjs polacz 192.168.1.50`.

Klucz dostępu zapisuje się w `~/.hue-most.json` (prawa 600) razem z odciskiem
certyfikatu mostka. Odcisk jest sprawdzany przy każdym kolejnym połączeniu — gdyby
ktoś podstawił w sieci inne urządzenie pod ten adres, skrypt odmówi rozmowy.
Po wymianie mostka na nowy trzeba ten plik skasować i sparować od nowa.

## Panel w przeglądarce

```bash
node hue.mjs panel
```

Otwiera się pod `http://localhost:8123`. To zalecany sposób: zapytania idą przez Node,
więc nie ma problemu ani z certyfikatem mostka, ani z zasadami CORS przeglądarki.

Panel widzi domyślnie **tylko ten komputer**. Żeby wejść na niego z telefonu:

```bash
node hue.mjs panel --w-sieci
```

Wypisze wtedy adres do wpisania w telefonie. To nie jest ustawienie domyślne, bo
panel Hue **steruje** światłami i trzyma klucz do mostka — w odróżnieniu od panelu
pompy, który tylko czyta. Wystawienie go w sieci domowej ma być świadomą decyzją.
Na Windowsie trzeba jeszcze raz otworzyć port w zaporze:

```powershell
New-NetFirewallRule -DisplayName "Panel Hue" -Direction Inbound -Protocol TCP `
  -LocalPort 8123 -Action Allow -Profile Private
```

Panel można też otworzyć dwuklikiem prosto z dysku (`panel.html`), ale w praktyce
zwykle się nie uda: strona otwarta jako plik nie ma prawa odpytywać urządzenia
w sieci i przeglądarka blokuje to niezależnie od certyfikatu mostka. Zaakceptowanie
certyfikatu pod `https://<adres-mostka>` bywa konieczne, ale nie wystarcza. Wersja
przez `node hue.mjs panel` działa zawsze — Node rozmawia z mostkiem sam i omija
oba ograniczenia.

Cztery zakładki:

- **Sterowanie** — pokoje, strefy i pojedyncze lampy: włącz/wyłącz, jasność, barwa
  światła (2200–6500 K), sceny zdefiniowane w aplikacji Hue.
- **Czujniki** — czujniki ruchu (ruch, temperatura, natężenie światła, bateria)
  i przyciski Hue z ostatnim zdarzeniem. Odświeża się co 5 sekund, więc widać
  na żywo, czy mostek reaguje.
- **Automatyka** — edytor reguł, opisany niżej.
- **Diagnostyka** — wszystkie urządzenia, wersje oprogramowania, łączność Zigbee,
  poziomy baterii, lista rzeczy do sprawdzenia, eksport raportu do JSON.

## Polecenia

```
node hue.mjs znajdz                   szuka mostka w sieci
node hue.mjs polacz [adres]           parowanie
node hue.mjs lista                    pokoje, strefy, lampy, sceny
node hue.mjs czujniki                 czujniki, przyciski, baterie
node hue.mjs diagnostyka              przegląd urządzeń i problemów
node hue.mjs raport [plik.json]       diagnostyka do pliku

node hue.mjs wlacz <cel>
node hue.mjs wylacz <cel>
node hue.mjs przelacz <cel>
node hue.mjs jasnosc <cel> <0-100>
node hue.mjs temperatura <cel> <2000-6500>
node hue.mjs kolor <cel> <#rrggbb>
node hue.mjs scena <cel> <nazwa sceny>

node hue.mjs automat [plik.json]      uruchamia automatykę
node hue.mjs panel [port] [--w-sieci] panel w przeglądarce (--w-sieci wpuszcza telefon)
```

**Cel** to `wszystko`, `pokoj:Salon`, `strefa:Parter`, `lampa:Biurko` albo sama nazwa
(sprawdzana kolejno wśród pokoi, stref i lamp). Wielkość liter i polskie ogonki nie mają
znaczenia. Każde polecenie przyjmuje na końcu `--przejscie <sekundy>` — czas płynnej
zmiany:

```bash
node hue.mjs jasnosc pokoj:Salon 30 --przejscie 10
node hue.mjs wylacz wszystko --przejscie 60
```

Adres mostka i klucz można podać zmiennymi `HUE_MOSTEK` i `HUE_KLUCZ`, a inną lokalizację
pliku konfiguracyjnego — przez `HUE_KONFIG`.

## Automatyka

Reguły siedzą w `automatyka.json` (wzór: `automatyka.przyklad.json`). Można je pisać
ręcznie albo wyklikać w zakładce Automatyka — panel zapisuje ten sam plik, a działający
proces przeładowuje go w ciągu dwóch sekund, bez restartu.

```bash
node hue.mjs automat
```

Program musi działać cały czas — panel sam z siebie niczego nie pilnuje, bo działa tylko
wtedy, gdy jest otwarty w przeglądarce.

### Reguły czasowe

```json
{ "nazwa": "Wieczor", "o": "zachod-00:20", "dni": ["pn","wt","sr","cz","pt"],
  "cel": "pokoj:Salon", "akcja": { "wlacz": true, "jasnosc": 65, "temperatura": 2700, "przejscie": 120 } }
```

Godzina to `06:30` albo `wschod` / `zachod` z przesunięciem (`zachod-00:20`,
`wschod+01:00`). Pory słońca liczone są z pola `polozenie` (szerokość i długość
geograficzna, domyślnie okolice Poznania) — z dokładnością do 2–3 minut, bez pytania
kogokolwiek w internecie. Pusta lista `dni` znaczy „codziennie”. Reguła odpala się raz
dziennie, z opóźnieniem do 15 sekund.

### Czujniki ruchu

```json
{ "czujnik": "Czujnik korytarz", "cel": "pokoj:Korytarz",
  "akcja": { "wlacz": true, "jasnosc": 70 },
  "gasPo": 120, "przejscieGaszenia": 8,
  "wNocy": { "jasnosc": 8, "temperatura": 2200, "od": "22:30", "do": "06:00" } }
```

`gasPo` to sekundy od ostatniego ruchu do zgaszenia; każdy kolejny ruch odlicza od nowa.
`wNocy` nadpisuje akcję w podanych godzinach (typowo: nie oślepiać po ciemku).
Można też ograniczyć całą regułę do przedziału godzin polami `od` i `do`.

### Przyciski

```json
{ "przycisk": "Przycisk sypialnia", "guzik": 1, "zdarzenie": "short_release",
  "cel": "pokoj:Sypialnia", "akcja": { "przelacz": true } }
```

Numery guzików i nazwy zdarzeń (`short_release`, `long_press`, `long_release`,
`initial_press`, `repeat`) podpatrzysz w zakładce Czujniki albo poleceniem
`node hue.mjs czujniki` — naciśnij guzik i sprawdź, co się zmieniło.

### Symulacja obecności

```json
{ "wlaczona": true, "cel": "pokoj:Salon", "od": "zachod", "do": "23:00",
  "minPrzerwa": 15, "maxPrzerwa": 45, "jasnosc": 60 }
```

Losowo zapala i gasi wskazane światło co 15–45 minut w podanym oknie czasowym.

### Akcje

Wspólne dla wszystkich reguł:

| Pole | Znaczenie |
|---|---|
| `wlacz` | `true` / `false` |
| `przelacz` | odwraca bieżący stan |
| `scena` | nazwa sceny z aplikacji Hue |
| `jasnosc` | 0–100 (%) |
| `temperatura` | kelwiny 2000–6500 (ciepła 2200, dzienna 4000, zimna 6500) |
| `kolor` | `#rrggbb` |
| `przejscie` | sekundy płynnej zmiany |

## Automatyka na stałe

**Linux (systemd, dla użytkownika):** `~/.config/systemd/user/hue.service`

```ini
[Unit]
Description=Automatyka Hue
[Service]
ExecStart=/usr/bin/node /sciezka/do/hue/hue.mjs automat
Restart=always
[Install]
WantedBy=default.target
```

```bash
systemctl --user enable --now hue.service
journalctl --user -u hue.service -f
```

**Windows:** Harmonogram zadań → nowe zadanie uruchamiane przy logowaniu,
program `node`, argumenty `C:\sciezka\hue\hue.mjs automat`.

## Czego to nie robi

- Nie tworzy scen — sceny buduje się w aplikacji Hue, tutaj tylko się je uruchamia.
- Nie zapisuje reguł w mostku, tylko wykonuje je z komputera. Zaleta: reguły są
  czytelnym plikiem, który można wersjonować i skopiować. Wada: gdy komputer śpi,
  automatyka nie działa (rzeczy krytyczne trzymaj w aplikacji Hue).
- Nie steruje przez internet spoza domu.
- Nie obsługuje starego API v1 mostka — potrzebny mostek Hue drugiej generacji
  (kwadratowy) z aktualnym oprogramowaniem.

## Prywatność

Nic nie wychodzi poza sieć lokalną. Jedyne połączenie na zewnątrz to `discovery.meethue.com`
przy szukaniu mostka — i tylko wtedy, gdy sam o to poprosisz; przy braku internetu skrypt
przegląda własną podsieć. Klucz dostępu do mostka leży wyłącznie na tym komputerze.
