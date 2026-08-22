# Podstawa twierdzeń o konsekwencjach

Dokument na wypadek pytania „skąd to Pan wziął". Przy sprzedaży do księgowych takie
pytanie **padnie** — i to jest dobry moment, żeby wygrać wiarygodność, a nie ją stracić.

Sugestia, żeby dołożyć konsekwencje błędnego numeru KSeF, pochodzi od księgowej
(rozmowa z 22.08.2026). Poniżej to, co udało się potwierdzić, i to, czego nie.

---

## 1. Obowiązek podawania numeru KSeF w ewidencji — POTWIERDZONE

Od rozliczenia za **luty 2026** podatnicy wykazują w części ewidencyjnej JPK_V7 numer
identyfikujący fakturę w KSeF. Dotyczy to **zarówno rejestru sprzedaży, jak i zakupów**.

Nowe struktury **JPK_V7M(3)** i **JPK_V7K(3)** zostały opublikowane 19 grudnia 2025 r.
w Centralnym Repozytorium Wzorów Dokumentów Elektronicznych i obowiązują od 1 lutego 2026 r.

Gdy numeru KSeF nie ma, pozycja wymaga jednego z oznaczeń:

| Oznaczenie | Kiedy |
|---|---|
| **OFF** | faktury wystawione w czasie awarii lub niedostępności KSeF, a także gdy nie było możliwości wystawienia faktury ustrukturyzowanej z przyczyn po stronie podatnika |
| **BFK** | faktury elektroniczne i papierowe wystawione bez użycia KSeF |
| **DI** | dowody inne niż faktura |

**Kluczowe:** każda pozycja musi mieć albo numer KSeF, albo jedno z tych oznaczeń.
**Pole nie może zostać puste.** To dlatego narzędzie sprawdza jedno i drugie razem.

Źródła:
- [Nowa struktura JPK_VAT z deklaracją — obowiązek wykazywania numeru KSeF od 1 lutego 2026 r. (INFORLEX)](https://www.inforlex.pl/dok/tresc,FOB0000000000007488022,Nowa-struktura-JPK-VAT-z-deklaracja-obowiazek-wykazywania-numeru-KSeF-od-1-lutego-2026-r.html)
- [JPK_VAT: nowe oznaczenia i obowiązkowy numer KSeF od 1 lutego 2026 r. (INFORLEX)](https://www.inforlex.pl/dok/tresc,FOB0000000000007512341,JPK-VAT-nowe-oznaczenia-i-obowiazkowy-numer-KSeF-od-1-lutego-2026-r.html)
- [JPK VAT a KSeF — zmiany od lutego 2026 (ifirma.pl)](https://www.ifirma.pl/blog/ksef-i-fakturowanie/jpk-vat-a-ksef-zmiany-od-lutego-2026-nowa-struktura-i-obowiazkowy-numer-faktury-ksef/)
- [Nowy standard raportowania VAT: JPK_V7(3) KSeF (jpk.info.pl)](https://jpk.info.pl/jpk-v7/standard-raportowania-vat-wersja-3-ksef/)

---

## 2. Kara 500 zł za błąd w ewidencji — POTWIERDZONE, ale z ważnym zastrzeżeniem

Podstawa: **art. 109 ust. 3h ustawy o VAT**.

Mechanizm, i to trzeba podawać dokładnie:

1. Urząd stwierdza w ewidencji błąd uniemożliwiający weryfikację prawidłowości transakcji.
2. Podatnik otrzymuje **wezwanie** i ma **14 dni** na przesłanie korekty albo wyjaśnień
   wykazujących, że błędu nie ma.
3. **Dopiero jeśli** w tym terminie nie złoży korekty ani wyjaśnień, złoży je po terminie,
   albo w wyjaśnieniach nie wykaże braku błędu — naczelnik urzędu **może** nałożyć decyzją
   karę **500 zł za każdy błąd** wskazany w wezwaniu.
4. Karę płaci się w ciągu 14 dni od otrzymania decyzji.

**Czego nie wolno mówić:** że za błędny numer KSeF jest automatycznie 500 zł. To nieprawda
i pierwsza księgowa, która to usłyszy, zdyskwalifikuje całą rozmowę. Kara jest sankcją za
**brak reakcji na wezwanie**, a nie za sam błąd.

Dlatego w ofercie stoi wprost: *„kara nie jest automatyczna — dotyczy sytuacji, w której po
wezwaniu nie złożono w terminie korekty ani wyjaśnień"*. To zdanie nie osłabia argumentu,
a wzmacnia go: pokazuje, że wiesz, o czym mówisz.

Źródła:
- [Kara za błędy w JPK — jakie konsekwencje czekają podatników (poradnikprzedsiebiorcy.pl)](https://poradnikprzedsiebiorcy.pl/-kara-za-bledy-w-jpk-vdek-czyli-jakie-konsekwencje-czekaja-podatnikow)
- [Co grozi podatnikowi za błędy w JPK_V7M lub JPK_V7K (PIT.pl)](https://www.pit.pl/aktualnosci/co-grozi-podatnikowi-za-bledy-w-jpk-v7m-lub-jpk-v7k-1009495)
- [Kary za błędy w JPK_VAT — wysokość, czynny żal, jak uniknąć kary (Infor.pl)](https://ksiegowosc.infor.pl/podatki/vat/jpk-vat/5154010,Kary-za-bledy-w-JPK-VAT-wysokosc-czynny-zal-jak-uniknac-kary.html)
- [Kara pieniężna — błędy w nowym JPK (ISP Modzelewski)](https://isp-modzelewski.pl/serwis/kara-pieniezna-bledy-w-nowym-jpk/)

---

## 3. Odpowiedzialność karnoskarbowa — NIE UŻYWAĆ w sprzedaży

Pojawia się w opracowaniach: przesłanie ewidencji z błędnymi danymi identyfikacyjnymi
faktur może zostać uznane za wadliwe prowadzenie ksiąg, a przy celowym lub rażącym
zaniedbaniu grozi odpowiedzialność z Kodeksu karnego skarbowego.

**Nie wpisałem tego do oferty** i nie radzę używać. Powody:

- to ocena prawna zależna od okoliczności, a nie skutek pomyłki w numerze,
- straszenie odpowiedzialnością karną w ofercie handlowej brzmi nierzetelnie
  i przy księgowym profesjonaliście działa przeciw Tobie,
- nie masz uprawnień doradcy podatkowego, a to już blisko granicy doradzania.

Wystarczy obowiązek z punktu 1 i kara z punktu 2. Są policzalne i sprawdzalne.

---

## 4. Wstrzymanie zwrotu VAT i kontrola krzyżowa — NIEPOTWIERDZONE

W jednym z opracowań pojawiło się twierdzenie, że błędny numer KSeF przy zakupach
uniemożliwia dopasowanie faktury po stronie sprzedawcy, generuje alert i wydłuża
weryfikację zwrotu podatku.

Brzmi wiarygodnie i pasuje do mechaniki systemu, ale **nie znalazłem dla tego
wystarczająco solidnego źródła**. Do oferty nie weszło. Jeśli Twoja księgowa potwierdzi
to z praktyki — możesz tego używać w rozmowie jako jej obserwacji, ale nie wpisuj tego
do dokumentu jako faktu.

---

## Zasada na przyszłość

Każde twierdzenie o skutkach podatkowych w materiałach sprzedażowych musi mieć tu wpis
ze źródłem. Sprzedajesz narzędzie kontrolne ludziom, których zawodem jest weryfikowanie —
jedno niesprawdzone zdanie kosztuje więcej niż dziesięć dobrych argumentów.

Stan na 22.08.2026. Przed pierwszą falą wysyłki warto poprosić księgową o rzut oka na
punkty 1 i 2 — to jedno zdanie w wiadomości, a daje potwierdzenie od osoby z uprawnieniami.
