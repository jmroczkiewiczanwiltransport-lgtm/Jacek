# Materiały sprzedażowe

| Plik | Co to jest |
|---|---|
| `wiadomosci.md` | maile zimne, otwarcie rozmowy telefonicznej, follow-up, podsumowanie po demie, odpowiedzi na zastrzeżenia |
| `demo-3-minuty.md` | scenariusz demo z podziałem na minuty — co klikać, co mówić, kiedy milczeć |
| `oferta.html` | jednostronicowa oferta z cennikiem; do wysłania albo wydruku (ma osobny arkusz dla druku) |
| `teksty-ogolne.md` | gotowe bloki opisujące ogólnie, co MBS może zrobić — od jednego zdania do sekcji na stronę, plus lista sformułowań, których nie używać |

## Co wysyłać, a co linkować

| Materiał | Forma | Dlaczego |
|---|---|---|
| **Oferta** | PDF w załączniku (`dist/MBS-oferta-KSeF.pdf`) | Oferty się wysyła, nie linkuje. Link do cudzej platformy w zimnym mailu obniża wiarygodność, a ta strona jest zaprojektowana jako dwustronicówka do druku. |
| **Demo aplikacji** | link | Klient ma ją uruchomić na swoich plikach — plik do pobrania na tym etapie to za duża prośba. |
| **Strona** | link w stopce maila | Ma potwierdzać, że firma istnieje, a nie sprzedawać. |
| **Aplikacja do pracy** | plik `dist/ksef-uzgodnienia.html` | Dopiero po zakupie. Działa z dysku, bez internetu. |

PDF powstaje z `dist/oferta.html`:

```bash
node tools/mkpdf.js
```

Kroje są **osadzone w pliku** (podzbiory latin i latin-ext), więc dokument wygląda
identycznie u każdego odbiorcy i bez internetu. Skrypt ma własny arkusz dla druku:
przestawia siatki na szerokość A4 i **ukrywa pola pozostawione do uzupełnienia** — puste
„telefon" z przerywaną linią w dokumencie wysyłanym klientowi wygląda na niedokończony.

## Kolejność użycia

1. **Mail albo telefon** (`wiadomosci.md`, szablon 1 lub 3) — cel: zgoda na link, nic więcej.
2. **Link do dema** — klient wrzuca swoje dwa pliki i sam widzi wynik.
3. **Demo prowadzone** (`demo-3-minuty.md`) — tylko jeśli chcą, żebyś przeszedł z nimi.
4. **Podsumowanie z ich liczbami** (szablon 5) — w ciągu godziny po demie.
5. **Oferta** (`oferta.html`) — dopiero teraz, gdy cena ma kontekst.

## Co uzupełnić przed pierwszą wysyłką

- w `oferta.html`: imię i nazwisko, telefon, e-mail (na dole, pozycje oznaczone przerywaną
  linią),
- w `wiadomosci.md`: dane w nawiasach kwadratowych,
- cena — 149 zł / 990 zł to propozycja, nie dogmat.

## Zasada, której nie łam

Żadnych liczb, których nie masz. Nie „biura oszczędzają X godzin", nie „średnio znajdujemy
Y faktur". Liczby w tej sprzedaży mają pochodzić wyłącznie z pliku klienta — dlatego cała
ścieżka prowadzi do tego, żeby klient uruchomił narzędzie na własnych danych, a nie żeby
obejrzał Twoją prezentację.
