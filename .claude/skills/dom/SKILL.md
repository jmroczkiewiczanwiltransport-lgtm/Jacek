---
name: dom
description: Instalacja domowa Jacka — pompa ciepła ACOND THERM, fotowoltaika na net-billingu, rozliczenia z Eneą, oświetlenie Hue i Tuya. Wczytaj to, zanim ruszysz cokolwiek w katalogach dom/, hue/ albo tuya/, albo gdy rozmowa dotyczy ogrzewania, rachunków za prąd, harmonogramów pompy czy paneli sterowania w domu.
---

# Dom — pompa ciepła, fotowoltaika, oświetlenie

Temat rozłożony na cały rok: sezon grzewczy 2026/27 ma być tańszy niż poprzedni.
Ten plik jest pamięcią między rozmowami — czytaj go w całości, zanim zaczniesz,
i **dopisuj do niego ustalenia**, zwłaszcza te, które kosztowały godzinę dochodzenia.

Rozmawiamy po polsku. Kod, komentarze, komunikaty i nazwy zmiennych też są po polsku
— to konwencja całego repozytorium, nie ozdobnik.

## Sprzęt i adresy

| Co | Adres | Uwagi |
|---|---|---|
| Pompa ciepła ACOND THERM | `192.168.88.9` | sterownik Tecomat Foxtrot, sw 160.36 |
| Mostek Philips Hue | `192.168.88.10` | sparowany, klucz w `~/.hue-most.json` |
| Komputer Jacka (Windows 11) | `192.168.88.18` | laptop, bywa poza domem |
| Router | `192.168.88.1` | najpewniej MikroTik (adresacja .88.x) |
| Falownik Huawei SUN2000 | — | **nie jest w sieci**, patrz niżej |

Ogrzewanie: podłogówka w całym domu plus grzejnik elektryczny w łazience.
Taryfa **G11**. Fotowoltaika rozliczana **net-billingiem**, umowa od stycznia 2026
— danych sprzed tej daty nie ma i nie będzie.

## Jak czytać pompę

Sterownik oddaje wszystkie wartości wprost w `PAGE115.XML`, jako
`<INPUT NAME="__T<skrót>_<typ>_<format>" VALUE="…"/>`. Skróty są stałe, dopóki nie
zmieni się program sterownika. Rozpoznane zmienne siedzą w `dom/opisy-panelu.przyklad.json`
(rozpoznane przez porównanie dwóch odczytów o różnych porach: wartości mierzone
dryfują, nastawy nie).

```bash
python3 dom/pompa-acond.py strona http://192.168.88.9/PAGE115.XML
python3 dom/pompa-acond.py panel  http://192.168.88.9/PAGE115.XML
```

Login i hasło idą z pliku `dom/logowanie.txt` (nazwa użytkownika w pierwszej linijce,
hasło w drugiej; w `.gitignore`, **nigdy nie proś o jego treść**).

## Ustalenia, które kosztowały najwięcej czasu

**Logowanie do sterownika jest nieoczywiste.** Hasło nie idzie otwartym tekstem.
Formularz (`SYSWWW/LOGIN.XSL` + `SHA1.JS` → `ProccessLogin`) wysyła
`SHA-1(numer_sesji + hasło)` jako pole `PASS`, POST-em na `SYSWWW/LOGIN.XML`.
Numer sesji (ciasteczko `SoftPLC`) jest inny za każdym razem, **więc podsłuchanego
skrótu ani ciasteczka nie da się zapamiętać na stałe** — trzeba przechodzić całą
procedurę. `pompa-acond.py` robi to sam w `zaloguj()`. Nie wracaj do pomysłu
z zapisywaniem ciasteczka; to była ślepa uliczka, po której zostało tylko awaryjne
`--ciasteczko`.

**Zapis do sterownika idzie impulsami, nie wartościami.** Panel sterownika przy
kliknięciu „+" wysyła POST na `PAGE115.XML` z treścią `__TCA37B6A0_BOOL_i=1`
(„−" to `__TF795EE37_BOOL_i=1`). Nowej wartości nie przekazuje wcale — sterownik
sam przesuwa nastawę o 0,1 °C i sam pilnuje swoich granic. Dlatego skok z 15,3
na 21,0 to blisko sześćdziesiąt impulsów, a nie jeden zapis. Nazwy kolejnych
przycisków (CWU, harmonogramy, tryb urlopowy) trzeba podejrzeć tak samo:
F12 → Network → filtr `method:POST` → kliknąć raz → zakładka Payload.

**Modbus TCP w pompie nie działa.** Port 502 jest otwarty, ale sterownik nim nie mówi
— wszystkie jednostki (0, 1, 2, 3) dają timeout. Serwer Modbus nie jest uruchomiony
w programie sterownika. Nie próbuj tej drogi jeszcze raz; czytanie ze strony WWW
daje komplet danych i wystarcza.

**Falownik nie jest podpięty do sieci.** Skan `python3 dom/falownik-huawei.py 192.168.88.0/24`
znajduje tylko pompę. Jacek nigdy nie widział produkcji z paneli — wszystkie liczby,
którymi operujemy, pochodzą z licznika Enei. Podpięcie falownika wymagałoby dongla
i konfiguracji przez FusionSolar; **zimą i tak nic by nie pokazał**, więc to temat
na wiosnę, nie priorytet.

**`hue/panel.html` otwarty z dysku nigdy nie zadziała.** Strona z `file://` nie ma
prawa odpytywać urządzenia w sieci — akceptacja certyfikatu mostka tego nie zmienia.
Jedyna działająca droga to `node hue.mjs panel`.

## Co jest uruchomione u Jacka

- **Panel pompy** — `%LOCALAPPDATA%\PanelPompy`, autostart przy logowaniu do Windowsa,
  bez okna terminala (VBS w Autostarcie). Port **8125**. Zapisuje odczyt do
  `dane-pompy.csv` co 5 minut, własnym wątkiem, niezależnie od ruchu na stronie.
  Aktualizacja: pobrać paczkę, kliknąć `_ZAINSTALUJ-AUTOSTART.bat` — pliki użytkownika
  i historia przeżywają.
- **Panel Hue** — port **8123**, uruchamiany ręcznie (`node hue.mjs panel --w-sieci`),
  żyje tylko z otwartym oknem terminala.
- Reguły zapory dla obu portów są założone, profil prywatny.

Jacek nie jest programistą. Podawaj gotowe komendy do wklejenia, jedną naraz, i mów,
czego się spodziewać po każdej. Nie zakładaj, że wie, gdzie jest terminal ani czym
różni się folder od paczki.

## Co mówią dane

Analiza godzinowa z Enei (`dom/prad-enea.py`, dane 01–08.2026):

**Zimą cztery piąte rachunku to pompa.** Metoda: nocą fotowoltaika nie produkuje, więc
pobór z sieci = całe zużycie domu. Najniższe letnie noce dają zużycie bazowe domu
**0,195 kWh/h ≈ 4,7 kWh/dobę**. Reszta to ogrzewanie.

| miesiąc | pobór | z tego pompa | udział |
|---|---|---|---|
| styczeń | 1228 kWh | ~1083 kWh | 88 % |
| luty | 704 kWh | ~573 kWh | 81 % |
| marzec | 282 kWh | ~137 kWh | 49 % |
| kwiecień | 209 kWh | ~68 kWh | 33 % |

Ta sama godzina nocna: latem 0,29 kWh/h, w styczniu 0,77, w lutym 0,84.

**Rachunek robi się w styczniu i lutym** — 67 % rocznego poboru. Wszystko poza pompą
to margines; oszczędzanie na oświetleniu czy czuwaniu nie zmieni tu nic.

**Fotowoltaika zimą nie pomoże.** Styczeń 2026: oddane 13 kWh przy pobranych 1228.
Zima była ostra i panele stały zasypane śniegiem — Jacek uważa, że to się nie powtórzy
w takim stopniu, więc nie wyciągaj z tego jednego stycznia wniosków o typowej zimie.
Odśnieżanie paneli ma sens: kilowatogodzina ze stycznia była warta 0,68 zł, z lipca 0,00.

**Gra toczy się o sezon przejściowy** — marzec, kwiecień, październik, listopad. Wtedy
jest i słońce, i zapotrzebowanie na ciepło.

## Decyzje i dlaczego

Pełny zapis w `dom/ustawienia-pompy.md` — **zawsze go przeczytaj** przed zmianami
w sterowniku i **dopisz** każdą zmianę.

Skrótowo:

- **Zostajemy na G11.** Zimą tylko 31 % poboru wypada w tanich godzinach G12
  i 51 % w G12w, przy progu opłacalności ok. 55 %.
- **Harmonogramy CWU i temperatury wody grzewczej: 10:00–16:00, wszystkie dni.**
  Były skonfigurowane fabrycznie, ale **wyłączone** — włączenie ich było największym
  pojedynczym zyskiem w całej pracy. Zastane godziny startowały o 12:00 i przesypiały
  szczyt produkcji (najwięcej energii szło do sieci o 10, 11 i 12).
- **Harmonogram temperatury pokojowej zostaje wyłączony.** Przy podłogówce głębokie
  obniżenia szkodzą: jastrych stygnie godzinami, a potem pompa odrabia to dużą mocą
  przy gorszym COP.
- **Bez HDO/SG Ready** — harmonogramy w pompie robią to samo bez ingerencji w instalację.
- **Bez automatyki reagującej na rzeczywistą nadwyżkę** — dopóki nie wiadomo, jak często
  podbicie w południe trafia w dzień pochmurny. Do tego potrzebne są dane z zimy.

## Kalendarz

Zadania siedzą w `dom/przypomnienia.json`, panel pokazuje najbliższe trzy,
`dom/przypomnienia.py` robi z nich plik `.ics` do kalendarza w telefonie.

Najbliższe: 6 września (sprawdzić ciepłą wodę wieczorem), 20 września (podnieść nastawę
pokojową z letnich 15,3 °C na ok. 21 °C), 1 października (spisać liczniki),
1 grudnia (wyłączyć harmonogram wody grzewczej), 1 marca (włączyć z powrotem).

## Otwarte wątki

1. **Panel na komputerze, który zostaje w domu.** Laptop Jacka jeździ do pracy, więc
   dziury w historii wypadną w godzinach 8–16 — dokładnie tam, gdzie toczy się gra
   z harmonogramami. Jacek zadeklarował, że przeniesie panel na inny komputer.
2. **Kolejne przyciski sterowania.** Nastawa pokojowa jest zrobiona (tabela
   `STEROWANIE` w `pompa-acond.py`). Do dołożenia, każdy po jednym podejrzeniu
   w F12: podgrzanie CWU na żądanie, włącznik harmonogramu wody grzewczej
   (zadania z 1 grudnia i 1 marca stałyby się jednym kliknięciem), tryb urlopowy,
   nastawa CWU 45/48 °C.
3. **Rezerwacje adresów w routerze** dla `.9`, `.10` i komputera z panelem — zaczęte,
   niedokończone.
4. **Falownik** — dopiero gdyby trafił do sieci.

## Zasady pracy nad tym kodem

- **Testuj na udawanych urządzeniach.** W trakcie pracy powstały symulatory sterownika
  Tecomat (z prawdziwą procedurą logowania) i falownika SUN2000. Zmiany w pobieraniu
  danych albo w logowaniu sprawdzaj na nich, zanim każesz Jackowi cokolwiek uruchamiać
  — on ma jedno urządzenie i nie ma jak wrócić do stanu sprzed.
- **Nigdy nie nadpisuj danych użytkownika.** `logowanie.txt`, `opisy-panelu.json`
  i `dane-pompy.csv` to jego rzeczy; instalator kopiuje je tylko, gdy ich nie ma.
  Historia zbierana przez miesiące jest nie do odtworzenia.
- **Nie zabijaj procesów wzorcem pasującym do własnego polecenia.** `pkill -f` na
  „pompa-acond.py panel" trafia we własną powłokę — składaj wzorzec w locie i wyklucz
  własny PID.
- **Pliki .bat i .vbs zapisuj z końcami linii CRLF.**
