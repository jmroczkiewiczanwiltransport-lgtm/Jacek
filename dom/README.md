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

### 3. Pompa ciepła

Zależy od modelu — to jedyny element, którego nie da się przygotować w ciemno.
Panel pod adresem IP to dobry znak: prawie zawsze znaczy, że moduł ma lokalne API.
Trzy typowe drogi:

- **gotowa integracja** — sporo pomp ma swoją w Home Assistancie albo w HACS
  (m.in. ecoNET300, Daikin, Panasonic, Midea, Viessmann, Modbus),
- **Modbus TCP** — jeśli moduł go wystawia, Home Assistant czyta i ustawia rejestry
  wprost, bez pośredników,
- **REST** — gdy panel WWW ma własne API; wtedy piszemy sensory i przełączniki ręcznie.

Żeby wybrać, potrzebna jest marka i model pompy oraz to, co pokazuje jej panel.

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
