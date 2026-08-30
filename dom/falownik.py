"""Odczyt falownika Huawei SUN2000 — wspólny dla narzędzia i panelu."""

import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from modbus import Modbus, CZYTAJ_HOLDING   # noqa: E402

# Rejestry SUN2000. Nazwy i przeliczniki wg powszechnie używanej mapy rejestrów
# Huaweia — po pierwszym odczycie porównaj z aplikacją FusionSolar. Gdyby któraś
# wartość nie miała sensu, znaczy że ten model numeruje ją inaczej.
#   (rejestr, ile słów, ze znakiem, dzielnik, nazwa, jednostka)
REJESTRY = [
    (32064, 2, True, 1, 'Moc z paneli (DC)', 'W'),
    (32080, 2, True, 1, 'Moc oddawana (AC)', 'W'),
    (32086, 1, False, 100, 'Sprawność', '%'),
    (32087, 1, True, 10, 'Temperatura falownika', '°C'),
    (32106, 2, False, 100, 'Uzysk łącznie', 'kWh'),
    (32114, 2, False, 100, 'Uzysk dzisiaj', 'kWh'),
    (37113, 2, True, 1, 'Moc na liczniku (+ pobór / − oddawanie)', 'W'),
]


def zlacz(slowa, ze_znakiem_):
    wartosc = 0
    for slowo in slowa:
        wartosc = (wartosc << 16) | slowo
    granica = 1 << (16 * len(slowa))
    if ze_znakiem_ and wartosc >= granica // 2:
        wartosc -= granica
    return wartosc


def odczytaj(host, port, jednostka):
    wynik = {}
    with Modbus(host, port, jednostka, limit=8) as m:
        for rejestr, ile, znak, dzielnik, nazwa, jednostka_miary in REJESTRY:
            try:
                slowa = m.czytaj(rejestr, ile, CZYTAJ_HOLDING)
                wynik[nazwa] = (zlacz(slowa, znak) / dzielnik, jednostka_miary)
            except OSError as powod:
                wynik[nazwa] = (None, str(powod))
            time.sleep(0.1)          # falownik nie lubi odpytywania bez przerwy
    return wynik


