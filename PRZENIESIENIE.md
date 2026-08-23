# Przeniesienie projektu na konto prywatne

Projekt MBS to działalność własna, a dotąd powstawał na koncie powiązanym z pracodawcą
(AnwilTransport). Ta lista porządkuje, co się przenosi samo, co trzeba przenieść ręcznie,
a co zostanie na starym koncie bezpowrotnie.

**Najlepszy moment to teraz** — nic nie zostało jeszcze wysłane klientowi, więc żaden
link, który komuś dałeś, nie przestanie działać.

---

## Co przenosi się samo

Wszystko, co jest w repozytorium git:

- aplikacja KSeF Uzgodnienia (`src/`, `dist/`, `vendor/`)
- strona, oferta, PDF (`strona/`, `sprzedaz/`, `dist/`)
- znak marki, 19 plików (`marka/`)
- materiały sprzedażowe (`sprzedaz/`)
- narzędzia (`tools/`, `build.sh`, `package.json`)
- kontekst projektu (`KONTEKST.md`)
- **skill projektowy** (`.claude/skills/frontend-design/`) — działa w każdej sesji
  na tym repozytorium, niezależnie od konta

Do tego pliki, które masz już lokalnie: PDF oferty, logo, strona jako pojedynczy HTML.

## Czego przenieść się nie da

| Co | Dlaczego |
|---|---|
| **Ta rozmowa** i cała jej historia | sesje są przypisane do konta; nie ma przenoszenia między kontami |
| **Trzy opublikowane strony** (apka, strona, oferta) | należą do konta, które je opublikowało — na nowym koncie publikujesz od nowa i dostajesz **nowe adresy** |
| Skille, wtyczki, konektory z poziomu konta | ustawiane na koncie, nie w projekcie — trzeba dodać ponownie |

Historii rozmowy nie odtworzysz i nie ma sensu próbować. Do tego służy `KONTEKST.md` —
wklejasz go na początku pierwszej rozmowy na nowym koncie i kontynuujesz bez powtarzania
ustaleń.

---

## Kolejność działań

### 1. Konto Claude na własny adres

Zarejestruj się na adres **niezwiązany z pracodawcą** — pasuje `mbs.mroczkiewicz@gmail.com`,
którego już używasz jako kontakt MBS. Osobne konto to osobna subskrypcja.

### 2. GitHub — sprawdź, czy nie jest do rozdzielenia

Repozytorium leży na koncie `jmroczkiewiczanwiltransport-lgtm`. To **konto użytkownika**,
nie organizacja pracodawcy — technicznie jest więc Twoje. Ale nazwa sugeruje firmę,
w której pracujesz, co przy własnej działalności jest co najmniej mylące.

Dwie drogi:
- **zostaw jak jest** — działa, nic nie trzeba robić,
- **przenieś na konto osobiste** — Settings → Danger Zone → *Transfer ownership*.
  Alternatywnie utwórz nowe repozytorium i wypchnij tam całą historię:
  `git remote add prywatne <adres> && git push prywatne --all`

Zanim cokolwiek zrobisz: **repozytorium musi być prywatne** (Settings → General →
Danger Zone → *Change repository visibility*). W publicznym leży `tools/keygen.js`
z solą licencyjną i cały playbook sprzedażowy.

### 3. Zmień sól licencyjną

Repozytorium było publiczne, więc klucze wygenerowane dotąd traktuj jako spalone.
Masz zero sprzedanych licencji, więc unieważnienie nikogo nie boli — za trzy miesiące
przy dziesięciu klientach oznaczałoby dziesięć niemiłych telefonów.

Zmiana: stała `SALT` w `src/app.js`, potem `./build.sh` i `node tools/keygen.js 10`.

### 4. Pierwsza rozmowa na nowym koncie

Podłącz GitHub, dodaj repozytorium, otwórz sesję i wklej `KONTEKST.md`.

### 5. Opublikuj strony od nowa i podmień odsyłacze

Po publikacji z nowego konta dostaniesz trzy nowe adresy. Trzeba je wstawić w dwóch
miejscach, inaczej zostaną martwe linki:

- `strona/index.html` — karta „Uzgodnienia KSeF", odsyłacz „Sprawdź na swoim pliku"
  prowadzi do dema aplikacji,
- `sprzedaz/wiadomosci.md` — miejsca oznaczone `[link]` w szablonach.

Potem `./build.sh` i `node tools/mkpdf.js`.

### 6. Dodaj z powrotem to, co jest na poziomie konta

Wtyczka „Frontend design" (jeśli nadal chcesz ją mieć obok skilla w repozytorium),
konektory, ustawienia. Skille projektowe z `.claude/skills/` dojdą same.

---

## Jedna uwaga na koniec

Praca nad własną działalnością na koncie powiązanym z pracodawcą to nie tylko kwestia
porządku. Zależnie od ustawień organizacji, treść pracy wykonanej na takim koncie może być
widoczna dla jej administratorów. Nie wiem, jak to jest skonfigurowane u Ciebie i nie
zgaduję — ale to argument, żeby rozdzielenie zrobić raczej wcześniej niż później.
