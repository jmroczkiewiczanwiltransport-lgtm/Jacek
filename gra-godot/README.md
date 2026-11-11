# Kurs na czas 3D (Godot)

Symulator jazdy zestawem z naczepą: z parkingu MOP drogą ekspresową do ronda, przez strefę
przemysłową na plac centrum logistycznego i tyłem pod wyznaczoną rampę — zanim zamknie się
okno rozładunku. Etap 1 projektu.

To osobna gra od `gra/kurs-na-czas.html` (wersja przeglądarkowa). Tamta działa z jednego
pliku w przeglądarce; ta wymaga silnika Godot i karty graficznej z Vulkanem.

## Jak uruchomić

1. Pobierz **Godot 4.6** (wersja standardowa, nie .NET) z <https://godotengine.org/download>.
   To jeden plik, bez instalatora.
2. Uruchom Godota, wybierz **Importuj**, wskaż plik `gra-godot/project.godot`.
3. Naciśnij **F5** (Uruchom projekt).

Projekt nie ma żadnych plików modeli ani tekstur — cała mapa i pojazdy powstają w kodzie
przy starcie, więc pierwsze uruchomienie trwa kilka sekund.

## Sterowanie

| Klawisz | Działanie |
|---|---|
| W / S lub ↑ / ↓ | gaz / hamulec |
| A / D lub ← / → | kierownica |
| R | kierunek jazdy D / R (tylko na postoju) |
| Spacja | hamulec postojowy |
| Q / E, F | kierunkowskazy, światła awaryjne |
| L | światła: wyłączone / mijania / drogowe |
| P | wycieraczki |
| T | zwalniacz (retarder), 3 stopnie |
| C | kamera: kabina / zza naczepy / z góry / kamera cofania |
| Z / X | spojrzenie w lewe / prawe lusterko (widok z kabiny) |
| Enter | zgłoszenie rozładunku pod rampą |
| Backspace | powrót na trasę (kosztuje 30 s) |
| F1, Esc | ściąga klawiszy, postój (pauza) |

Pad: lewa gałka — kierownica, prawy / lewy spust — gaz / hamulec, A — postojowy,
X — kierunek jazdy, Y — kamera.

## Co jest w etapie 1

- **Zestaw:** ciągnik + naczepa na sworzniu, fizyka pół-symulacyjna: masa ładunku wpływa na
  rozpędzanie i hamowanie, naczepa łamie się przy cofaniu, na mokrym spada przyczepność,
  ogranicznik 90 km/h, zwalniacz, hamulec postojowy.
- **Kamery:** kabina z lusterkami, zza naczepy, z góry, kamera cofania.
- **Mapa:** MOP, ok. 3 km drogi ekspresowej, rondo, droga dojazdowa, brama ze szlabanem,
  plac z 8 rampami (część zajęta).
- **Zlecenia:** 4 (dzień, pochmurno z deszczem, zmierzch, noc z deszczem), rozliczenie:
  stawka, premia za czas i dokładność ustawienia, potrącenia za szkody i spóźnienie.
- **Podjazd pod rampę:** pomocnik pokazuje odchyłkę w bok, kąt i odległość od odbojów.
- **Zdarzenia:** zmiana pogody w trakcie kursu, zmiana rampy przez dyspozytora, zepsuty
  pojazd wystający z pasa awaryjnego.
- **Ruch uliczny:** pojazdy na obu jezdniach, trzymają odstęp i ustępują na rondzie.
- **Grafika:** trzy poziomy (niska / średnia / wysoka) przełączane w menu.

## Czego jeszcze nie ma

- **Dźwięku** — żadnego.
- **Wyboru trasy**, tankowania, postojów i czasu pracy kierowcy.
- **Wypadków, kontroli drogowej** i innych zdarzeń poza trzema wymienionymi wyżej.
- **Sterowania dotykowego** i eksportu na telefon.
- **Gotowych modeli 3D i tekstur ze zdjęć.** Pojazdy, drzewa i budynki są bryłami
  budowanymi w kodzie, więc obraz jest czysty, ale nie fotorealistyczny. Każdą bryłę można
  podmienić na model `.glb` bez zmiany logiki: ciągnik i naczepa powstają w
  `scripts/rig.gd` (`_build_tractor`, `_build_trailer`), pojazdy ruchu w
  `scripts/traffic.gd` (`_make`), otoczenie w `scripts/world.gd`.
- Wycieraczki tylko się poruszają; krople na szybie nie są rysowane.

## Co zostało sprawdzone, a co nie

Sprawdzone automatycznie (bez okna, na Godot 4.6):

- `tests/sim_test.gd` — fizyka zestawu z 18 t ładunku: 0–80 km/h w 18 s, droga hamowania
  z 90 km/h ok. 47 m, zestaw łamie się przy ciasnym skręcie i cofaniu.
- `tests/game_test.gd` — autopilot przejeżdża całą trasę z MOP-u na plac bez kolizji
  (ok. 200 s), ocena ustawienia pod rampą, odrzucenie złej rampy, wypłata, pojawianie się
  ruchu ulicznego.

```
godot --headless --path gra-godot -s tests/sim_test.gd
godot --headless --path gra-godot -s tests/game_test.gd
```

Obraz był oglądany tylko na programowym rendererze (bez karty graficznej), po kilka
klatek z każdego widoku. **Nie sprawdzono:** płynności na prawdziwej karcie graficznej,
wyglądu poziomu „wysoka” (SDFGI), gry z klawiatury przez człowieka, pada.

## Układ projektu

| Plik | Zawartość |
|---|---|
| `scripts/main.gd` | zlecenia, etapy trasy, ocena rampy, zdarzenia, sterowanie |
| `scripts/rig.gd` | zestaw gracza: bryły, fizyka, światła, kabina, lusterka |
| `scripts/world.gd` | mapa: jezdnie, rondo, plac, bariery, znaki, drzewa |
| `scripts/traffic.gd` | ruch uliczny |
| `scripts/sky.gd` | niebo, słońce, mgła, deszcz, poziomy grafiki |
| `scripts/cameras.gd` | cztery widoki |
| `scripts/hud.gd` | zegary, plan kursu, plansze |
| `scripts/kit.gd` | narzędzia do budowy brył i materiałów |
| `shaders/` | asfalt z liniami i kałużami, teren |
