# Kontekst projektu — do wklejenia w nowej rozmowie

Jeśli zaczynasz rozmowę od zera (inne urządzenie, inna aplikacja, nowa sesja), wklej ten
plik na początku. Wystarcza, żeby kontynuować bez powtarzania ustaleń.

---

## Kto

**Jacek Mroczkiewicz MBS Business Solutions** — jednoosobowa działalność, aktywna
od 1 stycznia 2025. NIP `7871809487`, REGON `540507784`, ul. Ludomska 13/A,
64-600 Dąbrówka Leśna (pod Obornikami, ok. 30 km od Poznania).
Kontakt: `mbs.mroczkiewicz@gmail.com`. **Telefonu nie ma i celowo nie ma go
w materiałach** — jedyny dostępny numer należy do pracodawcy. Do załatwienia przed
pierwszą wysyłką: karta prepaid albo eSIM.

Na co dzień pracuje na etacie w firmie transportowej. **MBS ma stać obok tamtej pracy,
nie na niej** — i to jest twarda zasada, nie preferencja (decyzja z 23.08.2026):

- w materiałach nie ma pracodawcy, jego branży ani „doświadczenia w firmie transportowej",
- narzędzie do przepału floty **nie jest w ofercie** — usunięte ze strony i z tekstów,
- transport drogowy nie jest segmentem docelowym,
- kontrahenci, biuro rachunkowe i klienci pracodawcy **nie są źródłem kontaktów**.

Uzgodnienia KSeF zostają: to problem każdego biura rachunkowego w Polsce, a nie proces
pracodawcy. Cel sprzedaży to biura rachunkowe i firmy spoza transportu.

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

**Adresy dla klientów mają iść z własnego hostingu, nie z artefaktów Claude.** Folder
`www/` (składany przez `npm run www`) daje stronę i demo jako pliki do wystawienia na
darmowym hostingu statycznym — adres jest wtedy własny i nie zepsuje się przy przenoszeniu
konta. Paczka do przeciągnięcia: `dist/mbs-strona.zip`. Szczegóły: `www/README.md`.

Artefakty poniżej zostają tylko do podglądu — należą do przestrzeni AnwilTransport
i są prywatne:
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

**Kwoty i daty (od 23.08.2026, na prośbę pierwszej użytkowniczki — księgowej):**
opcjonalne kolumny w obu plikach — data wystawienia, data otrzymania, kwota netto,
kwota VAT. Brutto usunięte na wskazanie księgowej (nie ma go w ewidencji). Porównywane tylko gdy wskazane w OBU plikach, dla pozycji dopasowanych
do faktury z KSeF. Rozbieżności lądują w zakładce „Kwoty i daty" i w osobnym arkuszu
raportu. Próg kwot: 1 grosz. Daty: Excel-serial i tekst traktowane równoważnie.
Pole wskazane tylko po jednej stronie nie blokuje uzgodnienia — jest o tym miękki
komunikat, żeby nikt nie myślał, że kwoty sprawdzono, gdy nie sprawdzono.

**Kierunek potwierdzony przez księgową (23.08.2026): sprawdzenie kompleksowe pod JPK,
nie tylko numery KSeF.** W związku z tym: słowniki nagłówków znają nazwy pól ewidencji
JPK_V7 (NrDostawcy, DowodZakupu, DataZakupu, DataWpływu, NrKSeF, K_40–K_45; K_46/K_47 to korekty — celowo poza słownikiem) oraz
angielskie (Invoice Date, Posting date/VAT Date, Net/Gross); NIP-y w rejestrze przechodzą
walidację sumy kontrolnej (błędne → „Do wyjaśnienia" + komunikat — taki wpis nie
przejdzie w JPK niezależnie od numeru KSeF); kolumna z „date/data" w nagłówku nigdy nie
jest brana za kwotę.

Wyjście: raport `.xlsx` (z dysku) lub `.csv` (na stronie), kolumna do wklejenia
(bezpieczna dla plików z formułami), opcjonalnie uzupełniony rejestr.

Licencja: pełny wynik na ekranie, eksport ograniczony do 100 pozycji bez klucza.
Klucze: `node tools/keygen.js`. Sól jest w kodzie strony, więc to bariera, nie zabezpieczenie.

## Formularz zapytań (od 23.08.2026)

Sekcja Kontakt ma formularz „Zapytanie indywidualne" (imię/firma, e-mail, telefon
opcjonalnie, opis, jeden załącznik) oparty o **Netlify Forms** — działa tylko na
hostingu Netlify, nie z dysku ani z innego hostingu. Po wysłaniu przekierowanie na
`/dziekujemy.html` (w paczce). Przy załączniku stoi ostrzeżenie, żeby nie wysyłać
danych osobowych — formularz przesyła plik do nas, w przeciwieństwie do narzędzi.

**Do zrobienia raz w panelu Netlify:** Site configuration → Forms → **Enable form
detection**, potem wgrać paczkę jeszcze raz; następnie Forms → Notifications →
dodać powiadomienie e-mail na mbs.mroczkiewicz@gmail.com. Darmowy plan: 100 zgłoszeń
miesięcznie. Zgłoszenia widać w panelu: zakładka Forms → zapytanie.

## Fakty, na których stoi sprzedaż

- Od rozliczenia za **luty 2026** każda pozycja ewidencji JPK_V7 musi mieć numer KSeF
  albo oznaczenie **OFF / BFK / DI**. Puste pole nie przechodzi (struktury JPK_V7M(3),
  JPK_V7K(3)).
- Kara **500 zł za każdy błąd** — art. 109 ust. 3h ustawy o VAT — ale **nie automatycznie**:
  dopiero gdy po wezwaniu nie złożono w terminie 14 dni korekty ani wyjaśnień.
- Czego **nie** używać: odpowiedzialności karnoskarbowej (ocena prawna, blisko doradzania
  bez uprawnień) i wstrzymania zwrotu VAT (brak solidnego źródła). Szczegóły i źródła:
  `sprzedaz/podstawa-prawna.md`.

## Szkolenia obowiązkowe — druga noga oferty

Rozbudowane 23.08.2026 do własnej sekcji na stronie (`#szkolenia`). Teza: **kontrola nie
pyta, czy szkolenie było — pyta o protokół.** Materiał u klienta zwykle jest; brakuje
narzędzia, które przez niego przeprowadzi, sprawdzi wynik i wypluje listę z datami.

Mechanizm, który sprzedaje: materiał → **test zamknięty, dopóki materiał nie jest
przejrzany** → protokół. Ta blokada jest powodem, dla którego wynik w protokole coś znaczy.

Argumenty handlowe: bez abonamentu za pracownika, z dysku firmowego bez serwera, dwie
wersje językowe i lektor.

W sekcji jest też **miniatura platformy** (widok pracownika: karty szkoleń, pasek postępu,
zablokowany test, przełącznik języka). **Treści miniatury są zmyślone** (BHP, wózek
widłowy) — zasada: nic z platformy zbudowanej dla pracodawcy nie trafia na stronę MBS,
nawet poglądowo. Pokazujemy mechanikę, nie czyjkolwiek materiał.

**Granica, która musi stać na stronie:** nie prowadzi szkoleń i nie wystawia zaświadczeń.
Materiał, pytania, próg i decyzja, kto szkoli, są klienta — tam, gdzie przepis wymaga
uprawnionego szkolącego, narzędzie go nie zastępuje. Bez tego zdania oferta obiecuje
uprawnienia, których nie ma.

Cena (propozycja Claude z 23.08.2026, jawnie na stronie): **2 900 zł netto jednorazowo**
za platformę z pierwszym szkoleniem, **od 900 zł** każde kolejne szkolenie; dokładna cena
po obejrzeniu materiału, z góry. Uzasadnienie: kotwica 20× abonament KSeF; zewnętrzne
platformy e-learningowe to koszt rzędu dziesiątek tysięcy + abonamenty per pracownik.
Hasło sekcji: „Platforma e-learningowa Twojej firmy". Do sekcji doszła też złota ramka:
pracownik przechodzi szkolenie sam i sam wypełnia test, udział prowadzącego może
ograniczyć się do podsumowania — tam, gdzie charakter szkolenia na to pozwala.

Stara notatka: cena była **do ustalenia.** Na stronie stoi „wycena po obejrzeniu materiału, jednorazowo,
z ceną podaną z góry" — to jest uczciwe, ale kwoty nadal nie ma i trzeba ją wymyślić
przed pierwszą rozmową.

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

1. **Numer telefonu** — usunięty z materiałów (był tylko firmowy pracodawcy).
   Zamiast niego zobowiązanie: odpowiedź w ciągu jednego dnia roboczego. Prepaid
   albo eSIM przed pierwszą falą wysyłki — bez numeru nie działa kanał telefoniczny,
   najskuteczniejszy w tym segmencie.
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
Cennik: 149 zł/mies. za biuro albo 990 zł jednorazowo za stanowisko, plus sprawdzenie
próbne za 0 zł. Stoi **jawnie na stronie** w sekcji „Cennik" — przy tej kwocie ukryta
cena odstrasza bardziej niż sama liczba.
