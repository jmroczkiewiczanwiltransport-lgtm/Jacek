#!/usr/bin/env python3
"""Robi plik kalendarza (.ics) z zadań sezonowych wokół pompy ciepła.

Wgrywasz go raz do kalendarza w telefonie i przypomnienia przychodzą same —
tak jak terminy rachunków.

    python3 przypomnienia.py
    python3 przypomnienia.py --wyprzedzenie 2      # przypomnij 2 dni wcześniej
"""

import argparse
import json
import os
from datetime import date, datetime, timedelta

KATALOG = os.path.dirname(os.path.abspath(__file__))


def zadania(plik):
    with open(plik, encoding='utf-8') as f:
        dane = json.load(f)
    wynik = []
    for z in dane.get('zadania', []):
        poczatek = datetime.strptime(z['data'], '%Y-%m-%d').date()
        for numer in range(int(z.get('ile_razy', 1))):
            if numer and z.get('powtarzaj_miesiecy'):
                miesiac = poczatek.month - 1 + numer * int(z['powtarzaj_miesiecy'])
                dzien = date(poczatek.year + miesiac // 12, miesiac % 12 + 1,
                             min(poczatek.day, 28))
            elif numer:
                break
            else:
                dzien = poczatek
            wynik.append((dzien, z['tytul'], z.get('opis', '')))
    return sorted(wynik)


def zlozony_tekst(tekst):
    """iCalendar wymaga łamania długich linii i ucieczek dla znaków sterujących."""
    tekst = (tekst.replace('\\', '\\\\').replace(';', '\;')
             .replace(',', '\\,').replace('\n', '\\n'))
    linie, biezaca = [], ''
    for znak in tekst:
        if len(biezaca.encode('utf-8')) >= 72:
            linie.append(biezaca)
            biezaca = ' '
        biezaca += znak
    linie.append(biezaca)
    return '\r\n'.join(linie)


def kalendarz(lista, wyprzedzenie):
    teraz = datetime.now().strftime('%Y%m%dT%H%M%S')
    wiersze = ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//pompa ciepla//PL',
               'CALSCALE:GREGORIAN', 'METHOD:PUBLISH', 'X-WR-CALNAME:Pompa ciepła']
    for numer, (dzien, tytul, opis) in enumerate(lista):
        wiersze += [
            'BEGIN:VEVENT',
            f'UID:pompa-{dzien:%Y%m%d}-{numer}@dom',
            f'DTSTAMP:{teraz}Z',
            f'DTSTART;VALUE=DATE:{dzien:%Y%m%d}',
            f'DTEND;VALUE=DATE:{dzien + timedelta(days=1):%Y%m%d}',
            zlozony_tekst(f'SUMMARY:{tytul}'),
            zlozony_tekst(f'DESCRIPTION:{opis}'),
            'TRANSP:TRANSPARENT',
            'BEGIN:VALARM',
            'ACTION:DISPLAY',
            zlozony_tekst(f'DESCRIPTION:{tytul}'),
            f'TRIGGER:-P{wyprzedzenie}DT0H0M0S' if wyprzedzenie else 'TRIGGER:PT9H',
            'END:VALARM',
            'END:VEVENT',
        ]
    wiersze.append('END:VCALENDAR')
    return '\r\n'.join(wiersze) + '\r\n'


def main():
    parser = argparse.ArgumentParser(description='Przypomnienia sezonowe do kalendarza.')
    parser.add_argument('--zadania', default=os.path.join(KATALOG, 'przypomnienia.json'))
    parser.add_argument('--plik', default=os.path.join(KATALOG, 'wyniki', 'pompa-przypomnienia.ics'))
    parser.add_argument('--wyprzedzenie', type=int, default=1,
                        help='ile dni wcześniej przypomnieć (0 = tego samego dnia rano)')
    argumenty = parser.parse_args()

    lista = zadania(argumenty.zadania)
    os.makedirs(os.path.dirname(argumenty.plik), exist_ok=True)
    with open(argumenty.plik, 'w', encoding='utf-8', newline='') as f:
        f.write(kalendarz(lista, argumenty.wyprzedzenie))

    print(f'Zapisano {argumenty.plik} — zadań: {len(lista)}\n')
    for dzien, tytul, _ in lista:
        print(f'   {dzien:%d.%m.%Y}   {tytul}')
    print('\nWgraj ten plik do kalendarza w telefonie: wyślij go sobie mailem')
    print('i otwórz załącznik, albo skopiuj na telefon i otwórz. Przypomnienia')
    print('przyjdą same, dzień wcześniej.')


if __name__ == '__main__':
    main()
