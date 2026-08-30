"""Klient Modbus TCP — wspólny dla pompy ciepła i falownika.

Modbus jest na tyle prostym protokołem, że własna obsługa jest pewniejsza niż
biblioteka zmieniająca API między wersjami. Tyle, ile trzeba do odczytu i zapisu
rejestrów, i nic ponad to.
"""

import socket
import struct

# Kody funkcji Modbus
CZYTAJ_HOLDING = 3
CZYTAJ_INPUT = 4
ZAPISZ_JEDEN = 6

BLEDY = {
    1: 'nieobsługiwana funkcja',
    2: 'nie ma takiego rejestru',
    3: 'zła wartość albo za duży zakres',
    4: 'awaria urządzenia',
    6: 'urządzenie zajęte',
}


class Modbus:
    """Klient Modbus TCP — tyle, ile potrzeba do odczytu i zapisu rejestrów."""

    def __init__(self, host, port=502, jednostka=1, limit=5.0):
        self.host, self.port, self.jednostka, self.limit = host, port, jednostka, limit
        self.gniazdo = None
        self.transakcja = 0

    def __enter__(self):
        self.gniazdo = socket.create_connection((self.host, self.port), timeout=self.limit)
        self.gniazdo.settimeout(self.limit)
        return self

    def __exit__(self, *_):
        if self.gniazdo:
            self.gniazdo.close()

    def _rozmowa(self, pdu):
        self.transakcja = (self.transakcja + 1) % 0x10000
        naglowek = struct.pack('>HHHB', self.transakcja, 0, len(pdu) + 1, self.jednostka)
        self.gniazdo.sendall(naglowek + pdu)

        odpowiedz = self._odbierz(8)
        transakcja, protokol, dlugosc, jednostka, funkcja = struct.unpack('>HHHBB', odpowiedz)
        if protokol != 0:
            raise OSError('to nie jest Modbus TCP — inny protokół w odpowiedzi')
        reszta = self._odbierz(dlugosc - 2)
        if funkcja & 0x80:
            kod = reszta[0]
            raise OSError(f'urządzenie odmówiło: {BLEDY.get(kod, f"kod {kod}")}')
        return reszta

    def _odbierz(self, ile):
        bufor = b''
        while len(bufor) < ile:
            kawalek = self.gniazdo.recv(ile - len(bufor))
            if not kawalek:
                raise OSError('urządzenie zerwało połączenie')
            bufor += kawalek
        return bufor

    def czytaj(self, od, ile, funkcja=CZYTAJ_HOLDING):
        """Zwraca listę słów 16-bitowych. Modbus pozwala na 125 naraz."""
        wynik = []
        while ile > 0:
            porcja = min(ile, 125)
            odpowiedz = self._rozmowa(struct.pack('>BHH', funkcja, od + len(wynik), porcja))
            bajtow = odpowiedz[0]
            wynik += list(struct.unpack(f'>{bajtow // 2}H', odpowiedz[1:1 + bajtow]))
            ile -= porcja
        return wynik

    def zapisz(self, rejestr, wartosc):
        self._rozmowa(struct.pack('>BHH', ZAPISZ_JEDEN, rejestr, wartosc & 0xFFFF))


def ze_znakiem(slowo):
    return slowo - 0x10000 if slowo > 0x7FFF else slowo


def podpowiedz(slowo):
    """Zgaduje, czym może być wartość — po to, żeby dało się rozpoznać rejestry."""
    z = ze_znakiem(slowo)
    tropy = []
    if slowo in (0, 1):
        tropy.append('wyłącz./włącz.?')
    if -400 <= z <= 1500:
        tropy.append(f'{z / 10:.1f} °C?')
    if 0 < slowo <= 100:
        tropy.append(f'{slowo} %?')
    if 1000 <= slowo <= 30000:
        tropy.append(f'{slowo} W?')
    return '  '.join(tropy)


