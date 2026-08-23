# Start na nowym koncie MBS

Instrukcja przeniesienia projektu na własne konto. Wykonuje się raz.

---

## Krok 1 — konto GitHub (5 minut)

Wejdź na `github.com`, **Sign up**, adres **`mbs.mroczkiewicz@gmail.com`**.

Nazwa użytkownika: coś prostego i Twojego, np. `mbs-mroczkiewicz`. Będzie widoczna
w adresie repozytorium, więc nie wpisuj nazwy pracodawcy.

Nie twórz jeszcze żadnego repozytorium — zrobi się samo w kroku 3.

## Krok 2 — konto Claude (5 minut)

Zarejestruj się na **ten sam adres** `mbs.mroczkiewicz@gmail.com`. Osobne konto to
osobna subskrypcja — to koszt rozdzielenia działalności od pracodawcy.

W ustawieniach nowego konta podłącz GitHub (konektor GitHub) do konta z kroku 1.

## Krok 3 — pierwsza rozmowa

Otwórz nową sesję Claude Code. **Załącz plik `MBS-historia.bundle`** i wklej tekst
poniżej. To wszystko — nie musisz nic wpisywać w terminalu ani znać gita.

---

### Tekst do wklejenia

> Przenoszę projekt na nowe konto. W załączniku `MBS-historia.bundle` jest całe
> repozytorium razem z historią (17 commitów) — to kompletny projekt, nie fragment.
>
> Zrób proszę po kolei:
>
> 1. Sklonuj repozytorium z bundla i sprawdź, że masz 17 commitów i 49 plików.
> 2. Utwórz na moim koncie GitHub **prywatne** repozytorium `mbs-narzedzia`
>    i wypchnij tam całą historię.
> 3. Przeczytaj `KONTEKST.md` — jest tam wszystko o projekcie i firmie.
> 4. Przeczytaj `PRZENIESIENIE.md` — są tam pozostałe kroki przeniesienia.
> 5. Opublikuj od nowa trzy strony: aplikację (`dist/artifact-body.html`),
>    stronę (`strona/index.html`) i ofertę (`sprzedaz/oferta.html`).
> 6. Podmień nowy adres dema aplikacji w dwóch miejscach: w `strona/index.html`
>    (karta „Uzgodnienia KSeF", odsyłacz „Sprawdź na swoim pliku") oraz
>    w `sprzedaz/wiadomosci.md` (miejsce oznaczone `[link]`).
> 7. Przebuduj: `./build.sh` oraz `node tools/mkpdf.js`.
> 8. Zacommituj i wypchnij.
>
> Uwagi: repozytorium ma być **prywatne** — w środku jest sól licencyjna
> i cały playbook sprzedażowy. Materiały są po polsku i mają zostać po polsku.
> Skill `frontend-design` jest w `.claude/skills/` i obowiązuje.

---

## Czego się spodziewać

Nowe adresy trzech stron będą **inne** niż stare. To normalne — strony należą do konta,
które je publikuje. Ponieważ nie wysłałeś jeszcze nikomu żadnego linku, nic się nie psuje.

Stare repozytorium `jmroczkiewiczanwiltransport-lgtm/Jacek` zostaje nietknięte. Nadal jest
publiczne i nie masz do niego dostępu jako właściciel. Do rozważenia później: poproś osobę
zarządzającą tamtym kontem o usunięcie repozytorium albo o przełączenie na prywatne.

## Co jest już bezpieczne

- **Klucze licencyjne** — sól wymieniona 23.08.2026, klucze wydane wcześniej są nieważne.
  Aktualne klucze wygenerujesz przez `node tools/keygen.js 10`.
- **Kopia projektu** — masz `MBS-projekt-kopia.tar.gz` i `MBS-historia.bundle` na dysku,
  więc projekt istnieje niezależnie od jakiegokolwiek konta i tej sesji.

## Co nadal zostaje do zrobienia

1. **Numer telefonu** — jedyne puste pole na stronie i w ofercie.
2. **Test aplikacji na prawdziwym eksporcie z KSeF** — największe otwarte ryzyko;
   aplikacja nie była sprawdzona na realnym pliku z Aplikacji Podatnika.
3. **Udostępnienie stron** przed wysłaniem komukolwiek linku.
4. **Domena** — do sprawdzenia u rejestratora.
