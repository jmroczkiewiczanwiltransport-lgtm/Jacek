# Skille projektowe

Skille w tym katalogu są wczytywane w **każdej** sesji Claude Code pracującej na tym
repozytorium — niezależnie od tego, jakie wtyczki są włączone na koncie i z jakiej
powierzchni korzystasz (przeglądarka, aplikacja, terminal).

## dom

Instalacja domowa: pompa ciepła ACOND THERM, fotowoltaika na net-billingu, rozliczenia
z Eneą, oświetlenie Hue i Tuya. Wczytuje się przy pracy w `dom/`, `hue/` i `tuya/`
albo gdy rozmowa dotyczy ogrzewania i rachunków za prąd.

To pamięć między rozmowami — temat rozłożony na cały sezon grzewczy, a każda sesja
zaczyna od zera. Trzyma adresy urządzeń, ustalenia, które kosztowały godziny dochodzenia
(sposób logowania do sterownika, martwy Modbus, falownik poza siecią), wnioski z danych
Enei i listę otwartych wątków.

**Dopisuj do niego ustalenia.** Skill bez aktualizacji zestarzeje się w miesiąc i zacznie
wprowadzać w błąd. Zapis decyzji o samych nastawach sterownika idzie osobno, do
`dom/ustawienia-pompy.md`.

## frontend-design

Wytyczne projektowe: kierunek estetyczny, typografia, unikanie wyglądu „z szablonu".

**Pochodzenie:** kopia skilla z Twojej osobistej wtyczki „Frontend design"
(autor Prithvi Rajasekara, rejestr „claude cowork"). Trafiła tu, bo wtyczki z tamtego
rejestru nie są widoczne w sesjach Claude Code — a w repozytorium działa wszędzie.

**Uwaga o licencji:** nagłówek pliku odwołuje się do `LICENSE.txt`, którego nie mamy.
Jeśli to repozytorium jest albo będzie publiczne, warto albo dołączyć oryginalną licencję,
albo trzymać ten plik poza gitem (`.gitignore`). Przy repozytorium prywatnym, na własny
użytek, sprawa jest bez znaczenia.
