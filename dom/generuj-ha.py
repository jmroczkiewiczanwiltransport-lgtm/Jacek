#!/usr/bin/env python3
"""Przekłada to, co już mamy, na gotowce do Home Assistanta.

Czyta:
  ../tuya/urzadzenia.json     urządzenia Tuya wraz z kluczami lokalnymi
  ../tuya/automatyka.json     sceny i reguły czasowe (albo automatyka.przyklad.json)
  raport z mostka Hue         opcjonalnie, z „node hue.mjs raport plik.json"

Pisze:
  prywatne/dodawanie-tuya.txt lista do przeklikania w kreatorze tuya-local
                              (zawiera klucze — poza repozytorium)
  wyniki/sceny.yaml           sceny Home Assistanta
  wyniki/automatyzacje.yaml   reguły czasowe, w tym względem wschodu i zachodu słońca
  wyniki/pulpit.yaml          pulpit (widok Lovelace)

    python3 generuj-ha.py [--hue raport.json]
"""

import argparse
import json
import os
import re
import unicodedata

import yaml


class Cytat(str):
    """Tekst, który w YAML-u musi zostać w cudzysłowach. Bez tego „01:00:00"
    bywa czytane jako liczba sześćdziesiątkowa, a nie godzina."""


yaml.SafeDumper.add_representer(
    Cytat, lambda dumper, dane: dumper.represent_scalar('tag:yaml.org,2002:str', str(dane), style="'"))

KATALOG = os.path.dirname(os.path.abspath(__file__))
TUYA = os.path.join(KATALOG, '..', 'tuya')

# Zakres barwy sterowników w kelwinach. MiBoxery bywają 2700–6500 K, ale nie wszystkie
# — jeśli w Home Assistancie barwa wychodzi inna niż w scenie, popraw tutaj i przegeneruj.
BARWA_OD_K, BARWA_DO_K = 2700, 6500


def bez_ogonkow(tekst):
    rozlozone = unicodedata.normalize('NFD', str(tekst or ''))
    return ''.join(z for z in rozlozone if unicodedata.category(z) != 'Mn')


def identyfikator(nazwa):
    """„Ledy ogród" → „ledy_ogrod" — tak Home Assistant nazywa encje."""
    czysta = bez_ogonkow(nazwa).lower().replace('ł', 'l')
    return re.sub(r'_+', '_', re.sub(r'[^a-z0-9]+', '_', czysta)).strip('_')


def encja(urzadzenie):
    przedrostek = 'switch' if urzadzenie.get('rodzaj') == 'przelacznik' else 'light'
    return f'{przedrostek}.{identyfikator(urzadzenie["nazwa"])}'


def jasnosc_ha(procent):
    """Home Assistant liczy jasność w skali 0–255."""
    return max(1, min(255, round(255 * float(procent) / 100)))


def barwa_ha(procent):
    return round(BARWA_OD_K + (BARWA_DO_K - BARWA_OD_K) * float(procent) / 100)


def wczytaj(sciezka, domyslne=None):
    if not os.path.exists(sciezka):
        return domyslne
    with open(sciezka, encoding='utf-8') as f:
        return json.load(f)


# ─────────────────────────── lista do przeklikania ───────────────────────────

def lista_do_kreatora(urzadzenia):
    linie = [
        'Dodawanie urządzeń Tuya do Home Assistanta (integracja tuya-local)',
        '',
        'Ustawienia → Urządzenia i usługi → Dodaj integrację → Tuya Local,',
        'a potem dla każdego urządzenia po kolei:',
        '',
        'WAŻNE: w polu nazwy wpisz dokładnie tę nazwę, która jest niżej. Na niej opierają',
        'się wygenerowane sceny, automatyzacje i pulpit — inna nazwa to inna encja.',
        '',
        'Ten plik zawiera klucze lokalne. Trzymaj go u siebie.',
        '',
    ]
    for u in urzadzenia:
        linie += [
            '─' * 62,
            f'  Nazwa           {u["nazwa"]}',
            f'  Adres (host)    {u.get("ip") or "(uruchom: python3 tuya.py skanuj)"}',
            f'  Device ID       {u["id"]}',
            f'  Local key       {u.get("klucz", "")}',
            f'  Protokół        {u.get("wersja", 3.3)}',
            f'  Typ urządzenia  ' + ('przełącznik / gniazdo' if u.get('rodzaj') == 'przelacznik'
                                     else 'światło biało-ciepłe (CCT)'),
            f'  Powstanie encja {encja(u)}',
            '',
        ]
    return '\n'.join(linie)


# ─────────────────────────────── sceny ───────────────────────────────

def stan_encji(urzadzenie, akcja):
    if urzadzenie.get('rodzaj') == 'przelacznik':
        return {'state': Cytat('on' if akcja.get('wlacz', True) else 'off')}
    if akcja.get('wlacz') is False or akcja.get('jasnosc') == 0:
        return {'state': Cytat('off')}
    stan = {'state': Cytat('on')}
    if akcja.get('jasnosc') is not None:
        stan['brightness'] = jasnosc_ha(akcja['jasnosc'])
    if akcja.get('barwa') is not None:
        stan['color_temp_kelvin'] = barwa_ha(akcja['barwa'])
    return stan


def cel_na_urzadzenia(cel, urzadzenia):
    tekst = str(cel or 'wszystko').strip()
    if not tekst or bez_ogonkow(tekst).lower() == 'wszystko':
        return list(urzadzenia)
    if tekst.lower().startswith(('grupa:', 'grupy:')):
        nazwa = tekst.split(':', 1)[1]
        return [u for u in urzadzenia if nazwa in u.get('grupy', [])]
    dokladne = [u for u in urzadzenia if u['nazwa'] == tekst]
    if dokladne:
        return dokladne
    szukane = bez_ogonkow(tekst).lower()
    czesciowe = [u for u in urzadzenia if szukane in bez_ogonkow(u['nazwa']).lower()]
    return czesciowe or [u for u in urzadzenia if tekst in u.get('grupy', [])]


def sceny_ha(automatyka, urzadzenia):
    wynik = []
    for nazwa, kroki in (automatyka.get('sceny') or {}).items():
        encje = {}
        for krok in kroki:
            for u in cel_na_urzadzenia(krok.get('cel'), urzadzenia):
                encje[encja(u)] = stan_encji(u, krok.get('akcja', {}))
        if encje:
            wynik.append({'id': 'dom_' + identyfikator(nazwa), 'name': nazwa, 'entities': encje})
    return wynik


# ───────────────────────────── automatyzacje ─────────────────────────────

DNI_HA = {'pn': 'mon', 'wt': 'tue', 'sr': 'wed', 'cz': 'thu', 'pt': 'fri', 'sb': 'sat', 'nd': 'sun'}


def wyzwalacz(zapis):
    """„06:30" → wyzwalacz czasowy; „zachod-00:15" → wyzwalacz słoneczny."""
    tekst = bez_ogonkow(str(zapis)).lower().strip()
    proste = re.fullmatch(r'(\d{1,2}):(\d{2})', tekst)
    if proste:
        return {'trigger': 'time', 'at': Cytat(f'{int(proste[1]):02d}:{proste[2]}:00')}
    wzgledne = re.fullmatch(r'(wschod|zachod)\s*(?:([+-])\s*(\d{1,2}):(\d{2}))?', tekst)
    if not wzgledne:
        raise ValueError(f'nie rozumiem godziny „{zapis}"')
    wyzwalacz_slonca = {'trigger': 'sun',
                        'event': 'sunrise' if wzgledne[1] == 'wschod' else 'sunset'}
    if wzgledne[2]:
        wyzwalacz_slonca['offset'] = Cytat(f'{wzgledne[2]}{int(wzgledne[3]):02d}:{wzgledne[4]}:00')
    return wyzwalacz_slonca


def akcje_ha(cel, akcja, urzadzenia):
    if akcja.get('scena'):
        return [{'action': 'scene.turn_on',
                 'target': {'entity_id': 'scene.' + identyfikator(akcja['scena'])}}]
    cele = cel_na_urzadzenia(cel, urzadzenia)
    swiatla = [u for u in cele if u.get('rodzaj') != 'przelacznik']
    przelaczniki = [u for u in cele if u.get('rodzaj') == 'przelacznik']
    kroki = []
    wlaczyc = akcja.get('wlacz', True) and akcja.get('jasnosc') != 0

    if swiatla:
        dane = {}
        if wlaczyc:
            if akcja.get('jasnosc') is not None:
                dane['brightness'] = jasnosc_ha(akcja['jasnosc'])
            if akcja.get('barwa') is not None:
                dane['color_temp_kelvin'] = barwa_ha(akcja['barwa'])
            if akcja.get('przejscie'):
                dane['transition'] = akcja['przejscie']
        elif akcja.get('przejscie'):
            dane['transition'] = akcja['przejscie']
        krok = {'action': f'light.turn_{"on" if wlaczyc else "off"}',
                'target': {'entity_id': [encja(u) for u in swiatla]}}
        if dane:
            krok['data'] = dane
        kroki.append(krok)

    if przelaczniki:
        kroki.append({'action': f'switch.turn_{"on" if wlaczyc else "off"}',
                      'target': {'entity_id': [encja(u) for u in przelaczniki]}})
    return kroki


def automatyzacje_ha(automatyka, urzadzenia):
    wynik = []
    for h in automatyka.get('harmonogramy') or []:
        if h.get('wylaczona'):
            continue
        try:
            wyzw = wyzwalacz(h['o'])
        except ValueError as powod:
            print(f'  pomijam „{h.get("nazwa")}": {powod}')
            continue
        automatyzacja = {
            'id': 'dom_' + identyfikator(h.get('nazwa', 'regula')),
            'alias': h.get('nazwa', 'Reguła'),
            'description': f'Wygenerowane z automatyka.json (o: {h["o"]})',
            'triggers': [wyzw],
            'conditions': [],
            'actions': akcje_ha(h.get('cel'), h.get('akcja', {}), urzadzenia),
            'mode': 'single',
        }
        if h.get('dni'):
            automatyzacja['conditions'].append({
                'condition': 'time',
                'weekday': [DNI_HA[bez_ogonkow(d).lower()] for d in h['dni'] if bez_ogonkow(d).lower() in DNI_HA],
            })
        if not automatyzacja['conditions']:
            del automatyzacja['conditions']
        if automatyzacja['actions']:
            wynik.append(automatyzacja)

    obecnosc = automatyka.get('obecnosc') or {}
    if obecnosc.get('wlaczona'):
        wynik.append(automatyzacja_obecnosci(obecnosc, urzadzenia))
    return wynik


def automatyzacja_obecnosci(obecnosc, urzadzenia):
    """Losowe zapalanie i gaszenie — sprawdzane co 10 minut, z losem decydującym,
    czy tym razem coś się zmieni."""
    cele = cel_na_urzadzenia(obecnosc.get('cel'), urzadzenia)
    return {
        'id': 'dom_symulacja_obecnosci',
        'alias': 'Symulacja obecności',
        'description': 'Losowo zapala i gasi światło po zmierzchu',
        'triggers': [{'trigger': 'time_pattern', 'minutes': '/10'}],
        'conditions': [
            {'condition': 'sun', 'after': 'sunset'},
            {'condition': 'time', 'before': Cytat(obecnosc.get('do', '23:00') + ':00')},
            {'condition': 'template',
             'value_template': '{{ range(0, 3) | random == 0 }}'},
        ],
        'actions': [{
            'choose': [{
                'conditions': [{'condition': 'template',
                                'value_template': '{{ range(0, 10) | random < 6 }}'}],
                'sequence': [{'action': 'light.turn_on',
                              'target': {'entity_id': [encja(u) for u in cele
                                                       if u.get('rodzaj') != 'przelacznik']},
                              'data': {'brightness': jasnosc_ha(obecnosc.get('jasnosc', 60))}}],
            }],
            'default': [{'action': 'light.turn_off',
                         'target': {'entity_id': [encja(u) for u in cele
                                                  if u.get('rodzaj') != 'przelacznik']}}],
        }],
        'mode': 'single',
    }


# ──────────────────────────────── pulpit ────────────────────────────────

def kafelek(encja_id, rodzaj):
    kafel = {'type': 'tile', 'entity': encja_id}
    if rodzaj != 'przelacznik':
        kafel['features'] = [{'type': 'light-brightness'}]
    return kafel


def pulpit_ha(automatyka, urzadzenia, hue):
    karty = []

    sceny = list((automatyka.get('sceny') or {}).keys())
    if sceny:
        karty.append({
            'type': 'grid', 'columns': 2, 'square': False,
            'cards': [{'type': 'heading', 'heading': 'Sceny'}]
                     + [{'type': 'tile', 'entity': 'scene.' + identyfikator(nazwa), 'name': nazwa}
                        for nazwa in sceny],
        })

    grupy = {}
    for u in urzadzenia:
        for g in u.get('grupy', []):
            grupy.setdefault(g, []).append(u)
    for nazwa_grupy, w_grupie in grupy.items():
        karty.append({
            'type': 'grid', 'columns': 2, 'square': False,
            'cards': [{'type': 'heading', 'heading': nazwa_grupy.capitalize()}]
                     + [kafelek(encja(u), u.get('rodzaj')) for u in w_grupie],
        })

    luzem = [u for u in urzadzenia if not u.get('grupy')]
    if luzem:
        karty.append({
            'type': 'grid', 'columns': 2, 'square': False,
            'cards': [{'type': 'heading', 'heading': 'Pozostałe'}]
                     + [kafelek(encja(u), u.get('rodzaj')) for u in luzem],
        })

    if hue:
        karty.append({
            'type': 'grid', 'columns': 2, 'square': False,
            'cards': [{'type': 'heading', 'heading': 'Hue'}]
                     + [{'type': 'tile', 'entity': f'light.{identyfikator(n)}',
                         'features': [{'type': 'light-brightness'}]} for n in hue],
        })

    return {'views': [{'title': 'Dom', 'path': 'dom', 'icon': 'mdi:home', 'cards': karty}]}


def swiatla_hue(raport):
    """Z raportu „node hue.mjs raport" wyciąga same lampy."""
    if not raport:
        return []
    return [u['nazwa'] for u in raport.get('urzadzenia', []) if u.get('typ') == 'światło'
            or 'światło' in str(u.get('typ', ''))]


# ──────────────────────────────── główna ────────────────────────────────

def zapisz_yaml(sciezka, dane, naglowek):
    with open(sciezka, 'w', encoding='utf-8') as f:
        f.write(naglowek)
        yaml.safe_dump(dane, f, allow_unicode=True, sort_keys=False, default_flow_style=False, width=100)


def main():
    parser = argparse.ArgumentParser(description='Gotowce do Home Assistanta.')
    parser.add_argument('--hue', help='raport z mostka Hue (node hue.mjs raport plik.json)')
    parser.add_argument('--urzadzenia', default=os.path.join(TUYA, 'urzadzenia.json'))
    parser.add_argument('--automatyka', default=os.path.join(TUYA, 'automatyka.json'))
    argumenty = parser.parse_args()

    dane = wczytaj(argumenty.urzadzenia)
    if dane is None:
        dane = wczytaj(os.path.join(TUYA, 'urzadzenia.przyklad.json'))
        print('Nie ma tuya/urzadzenia.json — biorę wzór. Prawdziwe klucze pobierz przez '
              '„python3 tuya.py klucze".')
    urzadzenia = dane['urzadzenia']

    automatyka = (wczytaj(argumenty.automatyka)
                  or wczytaj(os.path.join(TUYA, 'automatyka.przyklad.json'), {}))
    hue = swiatla_hue(wczytaj(argumenty.hue) if argumenty.hue else None)

    os.makedirs(os.path.join(KATALOG, 'wyniki'), exist_ok=True)
    os.makedirs(os.path.join(KATALOG, 'prywatne'), exist_ok=True)

    sciezka_listy = os.path.join(KATALOG, 'prywatne', 'dodawanie-tuya.txt')
    with open(sciezka_listy, 'w', encoding='utf-8') as f:
        f.write(lista_do_kreatora(urzadzenia))
    os.chmod(sciezka_listy, 0o600)

    sceny = sceny_ha(automatyka, urzadzenia)
    automatyzacje = automatyzacje_ha(automatyka, urzadzenia)
    pulpit = pulpit_ha(automatyka, urzadzenia, hue)

    zapisz_yaml(os.path.join(KATALOG, 'wyniki', 'sceny.yaml'), sceny,
                '# Sceny — do scenes.yaml w Home Assistancie.\n'
                '# Wygenerowane z tuya/automatyka.json — nie edytuj tu, tylko tam i przegeneruj.\n')
    zapisz_yaml(os.path.join(KATALOG, 'wyniki', 'automatyzacje.yaml'), automatyzacje,
                '# Automatyzacje — do automations.yaml w Home Assistancie.\n'
                '# Godziny względem słońca liczy sam Home Assistant z ustawionej lokalizacji.\n')
    zapisz_yaml(os.path.join(KATALOG, 'wyniki', 'pulpit.yaml'), pulpit,
                '# Pulpit — wklej w: Pulpity → ⋮ → Edytuj → ⋮ → Edytor kodu YAML.\n')

    print(f'Urządzeń Tuya: {len(urzadzenia)}   scen: {len(sceny)}   '
          f'automatyzacji: {len(automatyzacje)}   lamp Hue: {len(hue)}')
    print(f'\n  prywatne/dodawanie-tuya.txt   lista do kreatora (z kluczami — nie wysyłaj nikomu)')
    print(f'  wyniki/sceny.yaml')
    print(f'  wyniki/automatyzacje.yaml')
    print(f'  wyniki/pulpit.yaml')
    if not hue:
        print('\nLampy Hue nie trafiły na pulpit. Zrób raport i przegeneruj:')
        print('  cd ../hue && node hue.mjs raport hue.json')
        print('  cd ../dom && python3 generuj-ha.py --hue ../hue/hue.json')


if __name__ == '__main__':
    main()
