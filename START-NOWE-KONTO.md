# Start na nowym koncie MBS

Instrukcja przeniesienia projektu na własne konto. Wykonuje się raz.

---

## Krok 1 — repozytorium na własnym koncie GitHub (2 minuty)

Konto GitHub już istnieje: **`mbsmroczkiewic…`** (nazwa na MBS, nie na pracodawcę).
Konta zakładać nie trzeba.

Najprostsza droga to funkcja **importu** — kopiuje całą historię w przeglądarce, bez
komend gita i bez hasła do starego konta. Zaloguj się na swoje konto i wejdź na
`github.com/new/import` (albo „+" w prawym górnym rogu → *Import repository*):

| Pole | Wartość |
|---|---|
| Your old repository's clone URL | `https://github.com/jmroczkiewiczanwiltransport-lgtm/Jacek` |
| Owner | Twoje konto |
| Repository name | `mbs-narzedzia` |
| Visibility | **Private** — to najważniejsze pole |

**Begin import.** Stare repozytorium jest publiczne, więc import je odczyta bez żadnych
uprawnień — ta jedna niedogodność wreszcie działa na Twoją korzyść.

Uwaga: import **kopiuje, nie przenosi**. Stare repozytorium zostaje publiczne i trzeba
poprosić o jego usunięcie osobę zarządzającą tamtym kontem.

### Droga zapasowa, jeśli import zawiedzie

Utwórz ręcznie prywatne repozytorium `mbs-narzedzia`, a potem w pierwszej rozmowie na
nowym koncie załącz plik **`MBS-historia.bundle`** — cała historia jest w nim i da się
z niego odtworzyć repozytorium bez GitHuba.

## Krok 2 — konto Claude (5 minut)

Zarejestruj się na **ten sam adres** `mbs.mroczkiewicz@gmail.com`. Osobne konto to
osobna subskrypcja — to koszt rozdzielenia działalności od pracodawcy.

W ustawieniach nowego konta podłącz GitHub (konektor GitHub) do konta z kroku 1.

## Krok 3 — pierwsza rozmowa

Otwórz nową sesję Claude Code z podłączonym repozytorium `mbs-narzedzia` i wklej tekst
poniżej. To wszystko — nie musisz nic wpisywać w terminalu ani znać gita.

Jeśli szedłeś drogą zapasową (bez importu), **załącz też `MBS-historia.bundle`**.

---

### Tekst do wklejenia

> Przenoszę projekt na własne konto. Repozytorium `mbs-narzedzia` zawiera komplet:
> aplikację, stronę, ofertę, znak marki i materiały sprzedażowe (18 commitów, 50 plików).
> Jeśli w załączniku jest `MBS-historia.bundle`, to znaczy że import się nie udał —
> wtedy odtwórz repozytorium z niego i wypchnij na moje konto jako **prywatne**.
>
> Zrób proszę po kolei:
>
> 1. Sprawdź, że repozytorium jest **prywatne** i kompletne (18 commitów, 50 plików).
> 2. Sprawdź, że `./build.sh` przechodzi i że `node tools/keygen.js 1` nie zgłasza
>    rozjazdu soli licencyjnej.
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
