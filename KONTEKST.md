# Kontekst projektu — do wklejenia w nowej rozmowie

Jeśli zaczynasz rozmowę od zera (inne urządzenie, inna aplikacja, nowa sesja), wklej ten
plik na początku. Wystarcza, żeby kontynuować bez powtarzania ustaleń.

---

## Kto

**Jacek Mroczkiewicz MBS Business Solutions** — jednoosobowa działalność, aktywna
od 1 stycznia 2025. NIP `7871809487`, REGON `540507784`, ul. Ludomska 13/A,
64-600 Dąbrówka Leśna (pod Obornikami, ok. 30 km od Poznania).
Kontakt: `mbs.mroczkiewicz@gmail.com`. **Telefon: nadal nieuzupełniony.**

Na co dzień pracuje w firmie transportowej (ANWIL Transport) — stamtąd bierze się
znajomość procesów: KSeF/JPK na plikach z AS400, paliwo floty, szkolenia kierowców.
MBS to działalność obok, sprzedawana biurom rachunkowym i firmom.

## Co jest zbudowane

**Uwaga: projekt jest w trakcie przenoszenia na własne konto.** Powstawał w repozytorium
`jmroczkiewiczanwiltransport-lgtm/Jacek` (gałąź `claude/desktop-cloud-access-myd0rp`) —
konto nie zostało założone przez właściciela projektu i nie ma do niego dostępu jako
administrator. Docelowe miejsce to prywatne repozytorium na koncie GitHub założonym na
`mbs.mroczkiewicz@gmail.com`. Kroki: `START-NOWE-KONTO.md`.

| Co | Gdzie |
|---|---|
| Aplikacja **KSeF Uzgodnienia** | `src/`, wynik w `dist/ksef-uzgodnienia.html` |
| Strona usługowa MBS | `strona/index.html`, wynik `dist/strona.html` |
| Oferta + PDF | `sprzedaz/oferta.html`, `dist/MBS-oferta-KSeF.pdf` |
| Znak marki (19 plików) | `marka/` + instrukcja `marka/README.md` |
| Materiały sprzedażowe | `sprzedaz/` — wiadomości, demo, teksty ogólne, gdzie szukać klientów, podstawa prawna |
| Narzędzia | `tools/` — keygen, generator znaku, raster, mkpdf; `build.sh`; `package.json` |

Opublikowane strony — **adresy poniżej należą do starego konta i przy przenoszeniu
trzeba je opublikować od nowa**; są prywatne i wymagają udostępnienia przed wysłaniem
komukolwiek:
- aplikacja: `https://claude.ai/code/artifact/a4209876-33c6-4d72-ba0d-e03d30aa0cf9`
- strona: `https://claude.ai/code/artifact/6b4ffd16-48ec-4f28-a406-443eb64201e2`
- oferta: `https://claude.ai/code/artifact/44781b54-d3bb-48c8-905b-3325c555a433`

## Co robi aplikacja

Zestawia eksport z KSeF z rejestrem zakupu, **w obie strony**, całość w przeglądarce
(zero serwera — to warunek wejścia do biur operujących danymi klientów).

Kategorie wyniku, w kolejności pilności:
1. **Bez numeru i bez oznaczenia** — pozycje, których JPK_V7 nie przyjmie
2. **Korekty** — numer wpisany, ale niezgodny z KSeF
3. **W KSeF, brak w rejestrze** — nieodliczony VAT
4. Do wyjaśnienia, Uzupełnione (dokładne/przybliżone), Bez dopasowania, Zgodne

Dopasowanie: NIP + znormalizowany numer faktury; zapasowo porównanie alfanumeryczne
i podciągiem w ramach NIP-u (oznaczane jako „przybliżone — sprawdź"). Tylko przy jednym
kandydacie. **Plik KSeF jest źródłem prawdy.**

Wyjście: raport `.xlsx` (z dysku) lub `.csv` (na stronie), kolumna do wklejenia
(bezpieczna dla plików z formułami), opcjonalnie uzupełniony rejestr.

Licencja: pełny wynik na ekranie, eksport ograniczony do 100 pozycji bez klucza.
Klucze: `node tools/keygen.js`. Sól jest w kodzie strony, więc to bariera, nie zabezpieczenie.

## Fakty, na których stoi sprzedaż

- Od rozliczenia za **luty 2026** każda pozycja ewidencji JPK_V7 musi mieć numer KSeF
  albo oznaczenie **OFF / BFK / DI**. Puste pole nie przechodzi (struktury JPK_V7M(3),
  JPK_V7K(3)).
- Kara **500 zł za każdy błąd** — art. 109 ust. 3h ustawy o VAT — ale **nie automatycznie**:
  dopiero gdy po wezwaniu nie złożono w terminie 14 dni korekty ani wyjaśnień.
- Czego **nie** używać: odpowiedzialności karnoskarbowej (ocena prawna, blisko doradzania
  bez uprawnień) i wstrzymania zwrotu VAT (brak solidnego źródła). Szczegóły i źródła:
  `sprzedaz/podstawa-prawna.md`.

## Zasady, których się trzymamy

- **Żadnych liczb, których nie mamy.** Bez „oszczędzamy 20 godzin miesięcznie", bez
  referencji, bez liczników klientów. Liczby pochodzą z pliku klienta.
- **Nie obiecywać półki, której nie ma.** Karty usług na stronie mają etykiety
  „Gotowe narzędzie" albo „Na zamówienie".
- **Nie doradzać podatkowo.** Narzędzie pokazuje rozbieżności; decyzję podejmuje księgowa.
- **Do hostowania i wysyłania tylko pliki z `dist/`.** Źródła w `strona/` i `sprzedaz/`
  to fragmenty bez `<meta charset>` — z dysku psują polskie znaki.
- Oferta idzie **PDF-em w załączniku**, nie linkiem. Demo aplikacji odwrotnie — linkiem.

## Co jest otwarte

1. **Numer telefonu** — jedyne puste pole na stronie i w ofercie.
2. **Udostępnienie stron** — wszystkie trzy są prywatne. Najpierw demo, potem strona,
   potem sprawdzić link w trybie prywatnym przeglądarki.
3. **Test na prawdziwym eksporcie z KSeF** — największe otwarte ryzyko. Aplikacja była
   sprawdzona na plikach zgodnych z układem kolumn ze skryptu produkcyjnego, ale nie
   na realnym eksporcie z Aplikacji Podatnika.
4. **Domena** — `mbs.pl` prawie pewnie zajęta; do sprawdzenia u rejestratora.
   Strona to zwykły HTML, wejdzie na GitHub Pages albo dowolny hosting.
5. **Potwierdzenie od księgowej** punktów o JPK_V7 i karze — ona to zasugerowała,
   warto poprosić o rzut oka.

## Stan sprzedaży

Zero wysłanych wiadomości, zero klientów. Plan: zacząć od własnej księgowej (już
zobaczyła narzędzie i potwierdziła, że ma sens), potem jej polecenia, potem biura
w promieniu 50 km. Zimne kontakty dopiero po pierwszym płacącym kliencie.
Cennik: 149 zł/mies. za biuro albo 990 zł jednorazowo za stanowisko — do zmiany.
