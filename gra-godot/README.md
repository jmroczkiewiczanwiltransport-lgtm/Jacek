# Kurs na czas 3D (Godot)

Symulator jazdy zestawem z naczepą: z parkingu MOP drogą ekspresową do ronda, przez strefę
przemysłową na plac centrum logistycznego i tyłem pod wyznaczoną rampę — zanim zamknie się
okno rozładunku. Etapy 1–2 projektu: jazda i mapa, potem dźwięk i wersja na telefon.

To osobna gra od `gra/kurs-na-czas.html` (wersja przeglądarkowa). Tamta działa z jednego
pliku w przeglądarce; ta wymaga silnika Godot i karty graficznej z Vulkanem.

## Jak uruchomić

1. Pobierz **Godot 4.6** (wersja standardowa, nie .NET) z <https://godotengine.org/download>.
   To jeden plik, bez instalatora.
2. Uruchom Godota, wybierz **Importuj**, wskaż plik `gra-godot/project.godot`.
3. Naciśnij **F5** (Uruchom projekt).

Projekt nie ma żadnych plików modeli ani tekstur — cała mapa i pojazdy powstają w kodzie
przy starcie, więc pierwsze uruchomienie trwa kilka sekund.

## Wersja na telefon

Gra ma sterowanie dotykowe i lżejsze ustawienia grafiki, które włączają się same na telefonie
(albo po pierwszym dotknięciu ekranu). Są dwie drogi na telefon:

- **Android — plik APK.** Buduje się z tego projektu (polecenie niżej). Instalacja spoza sklepu:
  telefon zapyta o zgodę na „instalowanie z nieznanych źródeł”. Wymaga Androida 7+ i procesora
  64-bitowego (arm64).
- **Przeglądarka (Android i iPhone).** Eksport „Web” daje katalog `build/web/` (ok. 38 MB), który
  trzeba wystawić na dowolnym serwerze WWW przez HTTPS, np. GitHub Pages.

Budowanie (wymaga szablonów eksportu Godot 4.6; dla Androida także JDK 17 i Android SDK
ustawionych w Ustawieniach edytora → Eksport → Android):

```
godot --headless --path gra-godot --export-release "Web" build/web/index.html
GODOT_ANDROID_KEYSTORE_RELEASE_PATH=klucz.keystore GODOT_ANDROID_KEYSTORE_RELEASE_USER=alias \
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=haslo \
godot --headless --path gra-godot --export-release "Android" build/kurs-na-czas-3d.apk
```

Klucza podpisu nie ma w repozytorium. Aktualizacja zainstalowanej gry wymaga pliku podpisanego
tym samym kluczem; inaczej trzeba najpierw odinstalować starą wersję.

Na ekranie dotykowym: lewy kciuk przesuwa kierownicę, prawy trzyma GAZ lub HAMULEC (im wyżej
palec, tym mocniej). Przyciski: D/R kierunek jazdy, P hamulec postojowy, KAM widok, strzałki i AW
kierunkowskazy, ŚW światła, WYC wycieraczki, ZW zwalniacz, TRĄB klakson, II postój. Pod rampą
pojawia się przycisk ZGŁOŚ ROZŁADUNEK. Przycisk „wstecz” w Androidzie zatrzymuje grę.

## Sterowanie (klawiatura i pad)

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
| H | klakson |
| M | wycisz / włącz dźwięk |
| C | kamera: kabina / zza naczepy / z góry / kamera cofania |
| Z / X | spojrzenie w lewe / prawe lusterko (widok z kabiny) |
| Enter | zgłoszenie rozładunku pod rampą |
| Backspace | powrót na trasę (kosztuje 30 s) |
| F1, Esc | ściąga klawiszy, postój (pauza) |

Pad: lewa gałka — kierownica, prawy / lewy spust — gaz / hamulec, A — postojowy,
X — kierunek jazdy, Y — kamera.

## Co jest w grze

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
- **Grafika:** trzy poziomy (niska / średnia / wysoka) przełączane w menu. Na telefonie i w
  przeglądarce gra sama wyłącza efekty ekranowe, skraca cienie i zmniejsza liczbę drzew i aut.
- **Dźwięk:** silnik z modelem obrotów i zmianą 12 biegów, toczenie, wiatr, deszcz, klakson,
  sygnał cofania, przekaźnik kierunkowskazów, syk hamulca postojowego, uderzenia, mijane
  pojazdy. W widoku z kabiny dźwięki z zewnątrz są przytłumione. Wszystko generowane w kodzie,
  bez plików audio.
- **Sterowanie dotykowe:** kierownica i pedały analogowe, przyciski urządzeń, wiele palców naraz.

## Czego jeszcze nie ma

- **Wyboru trasy**, tankowania, postojów i czasu pracy kierowcy.
- **Wypadków, kontroli drogowej** i innych zdarzeń poza trzema wymienionymi wyżej.
- **Wersji na iPhone'a jako aplikacji** — tylko przez przeglądarkę.
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
- `tests/touch_audio_test.gd` — dotyk: pedały, kierownica dwoma palcami naraz, przyciski,
  postój; dźwięk: wszystkie 12 dźwięków niepuste, częstotliwości klaksonu (310 i 370 Hz),
  sygnału cofania (1150 Hz) i rytmu silnika, zmiana biegów do 12. przy 90 km/h.

```
godot --headless --path gra-godot -s tests/sim_test.gd
godot --headless --path gra-godot -s tests/game_test.gd
godot --headless --path gra-godot -s tests/touch_audio_test.gd
```

Sprawdzone ręcznie w tej sesji:

- Obraz na programowym rendererze (bez karty graficznej) w trzech trybach: Forward+
  (komputer), Mobile i Compatibility (telefon, przeglądarka) — po kilka klatek.
- Eksport „Web” uruchomiony w Chromium z emulacją telefonu: start gry dotknięciem,
  zwolnienie hamulca postojowego i jazda na pedale gazu.
- Eksport „Android”: plik APK zbudowany, podpis zweryfikowany (`apksigner verify`).

**Nie sprawdzono:**

- Gry na żadnym prawdziwym telefonie: płynność, wygoda sterowania i czas ładowania są nieznane.
- Dźwięku nikt nie słyszał — sprawdzone są tylko liczby (głośność, częstotliwości).
- Płynności na prawdziwej karcie graficznej i wyglądu poziomu „wysoka” (SDFGI).
- Gry z klawiatury lub pada przez człowieka; cofania pod rampę nikt nie wykonał ręcznie.

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
| `scripts/touch.gd` | sterowanie dotykowe |
| `scripts/audio.gd` | generowanie i odtwarzanie dźwięku |
| `export_presets.cfg` | ustawienia eksportu na Androida i do przeglądarki |
| `scripts/kit.gd` | narzędzia do budowy brył i materiałów |
| `shaders/` | asfalt z liniami i kałużami, teren |
