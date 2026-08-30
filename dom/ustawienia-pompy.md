# Pompa ciepła — dziennik ustawień

Zapis tego, co i kiedy zostało zmienione w sterowniku, żeby po sezonie dało się
odtworzyć decyzje. Sterownik: ACOND THERM, sw 160.36, panel pod `192.168.88.9`.

## 30.08.2026 — przygotowanie do sezonu

Cel: przesunąć grzanie na godziny własnej produkcji z fotowoltaiki. Taryfa G11
(płaska cena), więc noc nie jest tańsza — jedyne, co się opłaca, to zużywać własny
prąd zamiast go oddawać. W net-billingu oddana kilowatogodzina jest warta trzy do
czterech razy mniej niż kupiona, a w lipcu 2026 oddane 1066 kWh było warte 0 zł.

Wszystkie trzy harmonogramy były **skonfigurowane, ale wyłączone**.

| Harmonogram | Ustawienie | Stan po zmianie |
|---|---|---|
| Grzanie CWU (`PAGE118`) | 12:00–14:00 (czw/pt/sob do 15:00, niedz. 10:30–13:00) | **włączony** |
| Temperatura wody grzewczej | 12:00–14:00 wszystkie dni, 45,0 °C | **włączony** |
| Temperatura pokojowa (`PAGE116`) | okna wieczorne 16:00–18:00, 19–20 °C | wyłączony — celowo |

Harmonogram temperatury pokojowej zostaje wyłączony świadomie: przy ogrzewaniu
podłogowym głębokie obniżenia nocne szkodzą, bo jastrych stygnie godzinami, a potem
pompa odrabia to dużą mocą przy gorszej sprawności. Jedna stała nastawa przez dobę
jest dla podłogówki lepsza.

Poprawione przy okazji: sobotnie okno 07:31–08:30 w harmonogramie wody grzewczej
(przypadkowy wpis) wyzerowane do 00:00–00:00.

### Stan wyjściowy liczników

Spisany przed sezonem, do porównania w lutym:

| Licznik | 30.08.2026 |
|---|---|
| Energia elektryczna | 4506 kWh |
| Motogodziny sprężarki | 6039 h |
| Motogodziny wentylatora | 6108 h |
| Biwalencja 1 (grzałka) | 119 h |
| Biwalencja 2 (grzałka) | 43 h |
| Motogodziny CWU | 1218 h |

Najważniejszy jest przyrost biwalencji: grzałka robi kilowatogodzinę ciepła
z kilowatogodziny prądu, pompa z jednej trzeciej.

## Do zrobienia

- [ ] **Przed sezonem (wrzesień):** podnieść nastawę pokojową z 15,3 °C (ustawienie
      letnie) na normalną, ok. 21 °C. Bez tego podbicie wody w południe nie ma się
      gdzie zatrzymać, a dom nie będzie grzany.
- [ ] **Pierwszy tydzień po włączeniu blokady CWU:** sprawdzić, czy nie brakuje
      ciepłej wody wieczorem. Jeśli brakuje — podnieść nastawę CWU z 45 na 48 °C.
- [ ] **Grudzień:** wyłączyć harmonogram temperatury wody grzewczej. Zimą nie ma
      nadwyżki z paneli, a wymuszanie 45 °C wody to sam gorszy COP bez zysku.
- [ ] **Marzec:** włączyć go z powrotem.
- [ ] **Zima:** odśnieżać panele. Kilowatogodzina ze stycznia była warta 0,68 zł,
      z lipca 0,00 zł — zimowa produkcja jest najcenniejsza w roku.

## Czego nie robimy i dlaczego

**Wejście HDO / SG Ready** — niepotrzebne, skoro harmonogramy w pompie robią to samo
bez ingerencji w instalację.

**Zmiana taryfy na G12/G12w** — nie opłaca się. Z danych godzinowych: zimą tylko 31 %
poboru wypada w tanich godzinach G12 i 51 % w G12w, przy progu opłacalności ok. 55 %.

**Automatyka reagująca na rzeczywistą nadwyżkę** — sensowna dopiero, gdy dane pokażą,
jak często podbicie w południe trafia w dzień pochmurny. Harmonogram grzeje 12:00–14:00
niezależnie od pogody; automat robiłby to tylko wtedy, gdy naprawdę świeci.
