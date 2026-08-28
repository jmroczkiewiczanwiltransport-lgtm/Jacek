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

## Notatka dla właściciela — czego NIE pisać

- Nie obiecuj terminu, dopóki nie zobaczysz dziennika. Nie wiemy, ile wierszy
  ma ich rok ani w jakim stanie jest eksport.
- Nie wchodź w cenę w tej wiadomości. Cena idzie osobno, po pokazaniu
  mapowania — wtedy jest już co wyceniać.
- Punkt 2 (brak kwoty podatku w pliku) powiedz sam, zanim ktoś to wykryje.
  Uczciwość w tym miejscu jest warta więcej niż wygodna niedopowiedź.
