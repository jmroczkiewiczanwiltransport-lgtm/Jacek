# Wiadomość do Alicji — po przejrzeniu dokumentacji i planu kont

Do wysłania po tym, jak właściciel przejrzy propozycję mapowania.
Ton: koleżeński, konkretny, bez żargonu programistycznego.

---

Dzięki za pliki — komplet. Przeszedłem broszury i schemę i pierwszą rzecz już
mam gotową: **wasze 508 kont z propozycją znacznika MF do każdego**. 97% kont
dostało konkretny znacznik, do rozmowy zostaje 13. Przy każdym koncie jest
napisane, dlaczego taki znacznik, i są dwie puste kolumny na Twoje poprawki.
Poprawki wracają do mnie i zostają zapamiętane jako mapowanie Waszej firmy —
w kolejnym roku wczytuje się gotowe, bez klikania od nowa.

Zanim policzę wynik, muszę Cię o kilka rzeczy dopytać.

**1. Najważniejsze: ZOiS7 czy ZOiS8?**
Schema ma osiem wariantów zestawienia obrotów i sald. Dla normalnej spółki to
ZOiS7 („jednostki pozostałe") i tam znacznik jest **obowiązkowy przy każdym
koncie**. Ale jeśli księgi statutowe prowadzicie według MSSF, to jest ZOiS8 —
i tam znacznik jest **opcjonalny**. Prowadzicie polskie księgi według ustawy
o rachunkowości, czy według MSSF? Od tej jednej odpowiedzi zależy, czy
mapowanie 508 kont jest robotą obowiązkową, czy prawie zbędną.

**2. Kwota podatku — muszę powiedzieć, jak jest.**
W strukturze JPK_KR_PD **nie ma pola na wynik ani na kwotę podatku**. Węzeł RPD
to osiem pozycji: przychody zwolnione, niepodlegające, koszty niestanowiące KUP
i tak dalej (K_1–K_8). Fiskus zestawia to sobie sam z CIT-8. Więc narzędzie
kwotę podatku **policzy i pokaże** — bo to najlepsza kontrola, czy mapowanie
jest dobre, i bo Ty tej liczby potrzebujesz do CIT-8 — ale w samym pliku ta
kwota nie występuje. Mówię od razu, żeby nie było niespodzianki przy odbiorze.

**3. Nazwy kont przychodzą uszkodzone.**
W pliku z planem kont polskie znaki się rozsypały: „SPRZEDA© CZÊ¡CI KSA"
zamiast „SPRZEDAŻ CZĘŚCI KSA". Rozszyfrowałem tabelę i umiem to naprawić.
Pytanie, czy naprawiać, bo **nazwa konta wchodzi do pliku XML** — inaczej
wysyłacie do urzędu nazwy z krzaczkami. Proponuję: naprawiam, a Ty widzisz
podgląd przed zapisem i możesz odrzucić.

**4. Jedna niespójność w Waszym planie kont.**
Konto **397140** ma nazwę „ODPIS AKTUAL.MASZ.KSA" — identyczną jak 397110,
choć według numeracji powinno dotyczyć segmentu KBL (jak 370140). Pozycja
bilansowa wychodzi ta sama, więc nic złego się nie stało, ale ktoś kiedyś
skopiował nazwę. Zerknij, czy to celowe.

**5. Jednostki powiązane.**
Znaczniki MF rozdzielają wiele pozycji na „od jednostek powiązanych" i „od
pozostałych". Widzę u Was konta wewnątrzgrupowe (KUHN, CASH POOL IC,
wewnątrzgrupowe rozliczenia). Powiedz, które konta traktujecie jako powiązane —
albo daj listę spółek grupy, a ja dopiszę regułę.

**6. Konta techniczne.**
Kilka kont nie da się przypisać bez Twojej decyzji: 580000 i 580001
(INTERNAL ENTRIES), 400000 „Rozrachunki i Roszczenia", 600000 i 601010
„KOSZTY WEDLUG RODZAJU", 409100/409800/460000/467490 (zbiorcze rozrachunki),
476000 (różnice kursowe NKUP). Pytanie do każdego jest to samo: **czy to konto
ma własne zapisy na ostatnim poziomie analitycznym**, czy tylko zbiera
analitykę? Jeśli tylko zbiera, do pliku nie wchodzi.

**7. I to, na co czekam najbardziej: dziennik zapisów za 2025.**
Eksport w xlsx albo csv, cały rok. Do tego, jeśli program to daje, **roczne
zestawienie obrotów i sald z BO i BZ** — porównam z tym, co sam wyliczę
z dziennika, i wtedy wiemy, że liczymy dobrze. No i **CIT-8 albo Twoje robocze
wyliczenie podatku za 2025** jako wzorzec: cel jest taki, żeby wyjść na Twoje
liczby co do grosza.

Ostatnia rzecz, techniczna: przydałyby się same pliki **.xsd** ze strony MF
(nie PDF-y ze schemą — te już mam). Z nich program potrafi sam sprawdzić plik
przed wysyłką. Jeśli nie masz pod ręką, dobiorę je sam.

---

---

## Mail — po policzeniu roku 2025 (29.08.2026)

Załączniki: `PROPOZYCJA-MAPOWANIA.xlsx` (513 kont) i `UZGODNIENIE-PODATKU-2025.xlsx`.

Wersja obowiązująca. Wcześniejsza wiadomość została wycofana (właściciel poprosił
księgową o jej zignorowanie), więc ten mail **musi bronić się sam** — stąd zdanie
porządkujące na wstępie i akapit tłumaczący, czym są załączniki i że dwie kolumny
arkusza są dla księgowej.

Uwaga: ten mail może trafić dalej niż do księgowej — do dyrektora finansowego
albo do centrali — dlatego nie ma w nim ceny ani niczego sprzedażowego.
Rozmowa o pieniądzach idzie osobnym wątkiem, po potwierdzeniu liczb.

**Temat:** Rok 2025 policzony — wynik zgadza się co do grosza; potrzebuję jeszcze jednego eksportu

```
Pani Alicjo,

ta wiadomość zastępuje poprzednią — proszę pracować na niej, jest kompletna.

Przeliczyłem cały 2025 rok z przesłanych ksiąg i mam pierwszy konkretny wynik.

Wynik brutto: 5 696 635,24 zł — dokładnie tyle, co w Państwa wyliczeniu.
Różnica zero.

Sprawdziło się to jeszcze raz, niezależnie: w dzienniku jest przeksięgowanie
wyniku z konta 891000 na 120000 na kwotę 4 313 115,24, a wynik brutto
pomniejszony o zaksięgowany podatek 1 383 520,00 daje dokładnie tę samą
liczbę. Księgi spinają się z trzech stron.

Dochód wychodzi mi 7 794 910,34 przy Państwa 7 844 749,24. Różnica to 0,64%
i w całości rozkłada się na cztery konkretne pozycje — nie jest to błąd
rachunku, tylko miejsca, w których podejmują Państwo decyzję, a program sam
jej nie odgadnie:

- 623150 prezenty i darowizny (-125 006,97) — wybierają Państwo pojedyncze
  pozycje z konta reklamowego,
- 661500 odsetki cash pool (+75 047,69) — wyłączają Państwo część konta,
  ja policzyłem całe,
- 658010 pozostałe koszty NKUP (+13 578,07) — również część konta,
- 758010 przychody NKUP (-13 457,70) — konto ma w nazwie NKUP, a w Państwa
  zestawieniu tej pozycji nie ma. To moje pytanie, nie moja poprawka: czy
  pominięcie jest celowe? Przy 19% chodzi o 2 557 zł.

Warto dodać liczbę, która najwięcej mówi o tym, ile z tego da się
zautomatyzować: z 24 pozycji korekt podatkowych 21 wychodzi co do grosza
z samego salda konta, a po stronie przychodów wszystkie osiem, z sumą
dokładnie -7 751 201,34. Trzy konta wymagają wskazania pojedynczych zapisów
— i to właśnie dopisuję do narzędzia, tak żeby raz wskazane pozycje
zapamiętywały się na kolejny rok.

W załączeniu dwie rzeczy.

Pierwsza to mapowanie Państwa planu kont na znaczniki Ministerstwa Finansów
— 513 kont, czyli 508 z planu i pięć, które są w księgach, a w planie ich nie
ma. Przy każdym koncie jest proponowany znacznik, jego opis wprost ze słownika
MF, ocena pewności i zdanie „dlaczego tak". Kolorem żółtym i pomarańczowym
oznaczyłem pozycje wymagające sprawdzenia. Dwie ostatnie kolumny są dla Pani
— to, co Pani tam wpisze, ma pierwszeństwo przed moją propozycją i zostaje
zapamiętane jako mapowanie Państwa spółki, więc w kolejnym roku wczytuje się
gotowe, bez klikania od nowa. Konkretny znacznik dostało 499 kont z 513.

Druga to uzgodnienie wyniku i podatku — te same liczby co wyżej, ale pozycja
po pozycji, żeby dało się je sprawdzić bez zaufania mi na słowo.

O co proszę teraz — jeden eksport.

Plik, który Pani przysłała, to księga główna (grand livre). Do zestawienia
obrotów i sald oraz do wyliczenia podatku nadaje się w zupełności i na nim
właśnie wszystko policzyłem. Ale struktura JPK_KR_PD wymaga osobnego węzła
„Dziennik", który jest obowiązkowy, a potrzebuje pól nieobecnych w księdze
głównej:

- numeru zapisu spinającego obie strony księgowania — sprawdziłem numer,
  który jest w pliku: nie bilansuje się do zera przy 59 932 z 64 496
  zapisów, więc to nie ten identyfikator,
- numeru dowodu oraz rodzaju dowodu księgowego,
- trzech dat: operacji gospodarczej, sporządzenia dowodu i ujęcia
  w księgach — w pliku jest jedna,
- danych osoby odpowiedzialnej za treść zapisu.

Proszę zatem o raport „dziennik" (livre journal) za 2025, najlepiej w xlsx
lub csv. W Państwa systemie to standardowy wydruk. To jedyna rzecz, która
dzieli nas od kompletnego pliku — cała reszta jest policzona i sprawdzona.

Przy okazji, drobniejsze rzeczy.

Do nagłówka pliku potrzebuję: NIP, pełną nazwę, REGON, adres, kod urzędu
skarbowego, informację czy rok podatkowy pokrywa się z obrotowym oraz czy
spółka stosuje CIT estoński albo MSSF.

Pięć kont, których nie ma w planie kont, to: 623300, 707112,
707222, 707412 i 707542 — wynajem powierzchni targowej i sprzedaż
eksportowa. Kwoty niewielkie, ale do pliku muszą trafić razem ze
znacznikami, więc plan kont wymaga uzupełnienia.

Cztery konta czekają na Państwa decyzję co do znacznika: 397120, 409100,
409800 i 580001. Pytanie przy każdym jest to samo — czy konto ma własne
zapisy na ostatnim poziomie analitycznym, czy tylko zbiera analitykę.

I jedno pole struktury, którego nie da się wyprowadzić z danych: S_3, konto
nadrzędne. Jest wymagane przy każdym koncie, a Państwa plan jest płaski.
Na razie przyjmuję konto syntetyczne z tego samego zespołu, ale to wymaga
Pani potwierdzenia.

Jeszcze jedna uwaga techniczna: eksport z Państwa systemu opisuje konta po
angielsku, a plan kont jest po polsku, więc do pliku JPK nazwy biorę z planu
kont, a reguły rozpoznają obie wersje.

Pozdrawiam serdecznie,
Jacek Mroczkiewicz
MBS Business Solutions
```

## Prośba nr 2 — eksport dziennika (po analizie ksiąg 2025)

Do wysłania od razu; to jedyna rzecz, która blokuje gotowy plik.

```
Alicja, policzyłem wszystko z Waszych ksiąg i wynik brutto wychodzi
5 696 635,24 — czyli dokładnie tyle, co u Ciebie, co do grosza. Dochód
wychodzi 7 794 910,34 przy Twoich 7 844 749,24 i całą różnicę umiem wskazać
palcem: to cztery pozycje, o które muszę dopytać (osobna lista).

Potrzebuję jeszcze jednego eksportu. To, co przysłałaś, to księga główna
(grand livre) — świetnie się nadaje do zestawienia obrotów i sald i do
wyliczenia podatku, ale struktura JPK wymaga osobnego węzła „Dziennik",
a w nim pól, których w księdze głównej nie ma:

- numer zapisu spinający obie strony księgowania (sprawdziłem: numer, który
  jest w pliku, nie bilansuje się do zera przy 60 tys. zapisów, więc to nie
  ten identyfikator),
- numer dowodu i rodzaj dowodu,
- trzy daty: operacji gospodarczej, sporządzenia dowodu i ujęcia w księgach
  (w pliku jest jedna data),
- osoba odpowiedzialna za treść zapisu.

Czyli potrzebny jest raport „dziennik" (livre journal) za 2025, nie księga
główna. W Waszym systemie to standardowy wydruk — najlepiej w xlsx albo csv.

I druga rzecz, drobniejsza — dane do nagłówka pliku: NIP, pełna nazwa,
REGON, adres, kod urzędu skarbowego, czy rok podatkowy pokrywa się
z obrotowym oraz czy spółka stosuje CIT estoński albo MSSF.
```

## Wersja na WhatsApp (skrócona, do wklejenia)

Trzy wiadomości. Można wysłać 1 i 2 od razu, a pytania po jej odpowiedzi —
blokuje nas wyłącznie dziennik.

### Wiadomość 1

```
Alicja, dokumentacja komplet, dzięki. Przeszedłem broszury i schemę.

Pierwsza rzecz gotowa: Wasze 508 kont z propozycją znacznika MF do
każdego konta. 97% ma konkretny znacznik, do rozmowy zostaje 13. Przy
każdym jest napisane, dlaczego taki, i dwie puste kolumny na Twoje
poprawki. Poprawki zapamiętuję jako mapowanie Waszej firmy — w kolejnym
roku wczytuje się gotowe, bez klikania od nowa.
```

### Wiadomość 2

```
Żeby policzyć wynik, potrzebuję trzech plików:

1. eksport dziennika zapisów za cały 2025 (xlsx albo csv)
2. roczne zestawienie obrotów i sald z BO i BZ — porównam z tym, co sam
   wyliczę z dziennika, wtedy wiemy, że liczy dobrze
3. CIT-8 albo Twoje robocze wyliczenie podatku za 2025, jako wzorzec

Cel: wyjść na Twoje liczby co do grosza.
```

### Wiadomość 3

```
I pytania:

1. ZOiS7 czy ZOiS8? Schema ma 8 wariantów zestawienia obrotów i sald.
Dla normalnej spółki to ZOiS7 i tam znacznik jest obowiązkowy przy
KAŻDYM koncie. Jeśli księgi statutowe prowadzicie wg MSSF, to ZOiS8 —
tam znacznik jest opcjonalny. Ustawa o rachunkowości czy MSSF?

2. Kwota podatku — powiem, jak jest: w strukturze JPK_KR_PD nie ma pola
na wynik ani na kwotę podatku. RPD to 8 pozycji korekt, a fiskus
zestawia to sobie z CIT-8. Narzędzie kwotę policzy i pokaże, bo to
najlepsza kontrola mapowania i Ty tej liczby potrzebujesz — ale w samym
pliku ona nie występuje. Mówię od razu, żeby nie było niespodzianki.

3. Nazwy kont przyszły uszkodzone: "SPRZEDA© CZÊ¡CI KSA" zamiast
"SPRZEDAŻ CZĘŚCI KSA". Umiem naprawić i pytam, czy naprawiać — nazwa
konta wchodzi do pliku XML, więc inaczej idą do urzędu krzaczki.
Proponuję: naprawiam, Ty widzisz podgląd przed zapisem.

4. Konto 397140 ma nazwę "ODPIS AKTUAL.MASZ.KSA", identyczną jak 397110,
choć wg numeracji powinno dotyczyć KBL (jak 370140). Pozycja bilansowa
wychodzi ta sama, ale ktoś kiedyś skopiował nazwę. Zerknij, czy celowo.

5. Znaczniki MF rozdzielają pozycje na "od jednostek powiązanych" i "od
pozostałych". Widzę konta wewnątrzgrupowe (KUHN, CASH POOL IC,
wewnątrzgrupowe rozliczenia). Które konta są powiązane — albo daj listę
spółek grupy, dopiszę regułę.

6. Konta techniczne, do każdego to samo pytanie: ma własne zapisy na
ostatnim poziomie analitycznym, czy tylko zbiera analitykę? Jeśli tylko
zbiera, do pliku nie wchodzi. Chodzi o 580000 i 580001 (INTERNAL
ENTRIES), 400000, 600000 i 601010, 409100, 409800, 460000, 467490
i 476000.

7. Techniczne: przydałyby się same pliki .xsd ze strony MF, nie PDF-y ze
schemą (te mam) — z nich program sam sprawdza plik przed wysyłką. Nie
masz pod ręką, dobiorę sam.
```

## Notatka dla właściciela — czego NIE pisać

- Nie obiecuj terminu, dopóki nie zobaczysz dziennika. Nie wiemy, ile wierszy
  ma ich rok ani w jakim stanie jest eksport.
- Nie wchodź w cenę w tej wiadomości. Cena idzie osobno, po pokazaniu
  mapowania — wtedy jest już co wyceniać.
- Punkt 2 (brak kwoty podatku w pliku) powiedz sam, zanim ktoś to wykryje.
  Uczciwość w tym miejscu jest warta więcej niż wygodna niedopowiedź.
