# Folder do wystawienia w internecie

Zawartość tego folderu to gotowa strona. Powstaje z `dist/` — **nie edytuj plików tutaj**,
bo nadpisze je następna budowa. Zmiany rób w `strona/` i `src/`, potem `./build.sh`
i `bash tools/www.sh`.

| Plik | Co to |
|---|---|
| `index.html` | strona MBS |
| `ksef.html` | demo aplikacji KSeF Uzgodnienia |
| `robots.txt` | zgoda na indeksowanie w wyszukiwarkach |

Odsyłacz „Sprawdź na swoim pliku" na stronie wskazuje na `ksef.html` — plik obok, nie na
zewnętrzny adres. Dzięki temu strona jest samowystarczalna i link nie zepsuje się przy
zmianie konta ani hostingu.

**Oferty tu nie ma celowo.** Zawiera cennik, a idzie PDF-em w załączniku do maila.

## Jak wystawić za darmo

Najprościej, bez konta GitHub i bez komend:

1. Wejdź na `app.netlify.com/drop` (albo `pages.cloudflare.com`).
2. Przeciągnij **cały ten folder** (albo plik `mbs-strona.zip`) na stronę.
3. Dostajesz stały adres, np. `nazwa.netlify.app`. Gotowe, koszt 0 zł.

Hosting jest darmowy bezterminowo. Płatna jest tylko własna domena — `.pl` to ok. 60–100 zł
rocznie. Domenę dokupujesz później i podpinasz do tego samego hostingu; strony nie trzeba
wystawiać od nowa.

## Dlaczego nie artefakty Claude

Adresy artefaktów należą do konta i przestrzeni, w której je opublikowano. Ten folder daje
adres, który jest **Twój** — nie zepsuje się przy przenoszeniu konta ani przy zmianie planu.
Artefakty zostają do Twojego podglądu; klientom dawaj adres z tego hostingu.
