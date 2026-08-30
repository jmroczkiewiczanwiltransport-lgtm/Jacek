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

### 3. Pompa ciepła ACOND

Sterownik ACOND wystawia **Modbus TCP na porcie 502**, po tym samym kablu, którym pompa
jest wpięta do sieci — nic dokładać nie trzeba. Home Assistant ma wbudowaną obsługę
Modbusa, więc nie potrzeba żadnego dodatku.

Trzy rzeczy do załatwienia, zanim cokolwiek zadziała:

**Właściwy adres.** Sterownik ma dwa porty Ethernet:

| Port | Adres | Do czego |
|---|---|---|
| ETH1 | 192.168.134.176 (stały) | sieć serwisowa pompy — **nie ten** |
| ETH2 | 192.168.88.9 (z DHCP) | sieć domowa — **ten** |

Adres z ETH2 przydzielany jest dynamicznie, więc po restarcie routera może się zmienić
i integracja przestanie działać. Zarezerwuj go na routerze dla adresu MAC
`F8-DC-7A-7D-24-89` (u Ciebie router trzyma sieć 192.168.88.x, to typowe dla MikroTika:
IP → DHCP Server → Leases → „Make Static”).

**Odblokowanie Modbusa.** Komunikację Modbus musi włączyć w pompie **serwis ACOND-a** —
z poziomu ekranu sterownika się tego nie zrobi. Przy okazji poproś o dokumentację
protokołu z tablicą rejestrów: `AC-Z010` dla oprogramowania w wersji `160.36`
(dokumentacja.acond.cz, publiczny plik `AC-Z010-EN.pdf`).

**Rozpoznanie rejestrów.** Tablicy nie trzeba mieć, żeby zacząć — skrypt `pompa-acond.py`
odczyta rejestry wprost z pompy:

```bash
cd dom
python3 pompa-acond.py skanuj 192.168.88.9
```

Pokaże wszystkie niezerowe rejestry z podpowiedzią, czym mogą być („482 → 48,2 °C?”).
Porównaj je z tym, co pokazuje ekran sterownika — temperatura zewnętrzna i temperatura
wody zwykle rzucają się w oczy od razu. Nastawy najprościej znaleźć tak:

```bash
python3 pompa-acond.py obserwuj 192.168.88.9 --od 0 --ile 100
```

Skrypt wypisuje każdą zmianę na bieżąco; pokręć nastawą na sterowniku i zobacz, który
rejestr drgnął. Rozpoznane rejestry wpisz do `opisy-pompy.json` (wzór:
`opisy-pompy.przyklad.json`) i wygeneruj konfigurację:

```bash
python3 pompa-acond.py yaml 192.168.88.9
```

Powstanie `wyniki/pompa-acond.yaml` — wklej do `configuration.yaml`, sprawdź konfigurację
i przeładuj. Odczyty pojawią się jako encje i wejdą na pulpit razem ze światłami.

> **Zacznij od samych odczytów — i najlepiej na tym zostań.**
>
> Odczyt niczego w pompie nie zmienia. Zapis owszem, i to bardziej, niż wygląda:
> sterowanie przez Modbus jest w ACOND-zie pomyślane jako oddanie regulacji systemowi
> nadrzędnemu. Pompa wygasza wtedy własny czujnik temperatury i oczekuje, że bieżącą
> temperaturę poda jej Home Assistant. Jeśli komunikacja ucichnie na dłużej niż
> `MaxCommDataRefresh`, pompa wraca do trybu auto.
>
> W praktyce znaczy to tyle, że włączając sterowanie, bierzesz na siebie regulację
> ogrzewania. Błąd w automatyzacji to nie zgaszona lampka, tylko zimny dom albo
> przegrzany zbiornik. Dlatego wygenerowana sekcja sterowania jest **zakomentowana** —
> odkomentuj ją świadomie i po rozmowie z serwisem, a nie „żeby zobaczyć, czy działa”.
> Do samego podglądu temperatur i zużycia na jednym pulpicie sterowanie nie jest potrzebne.

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
