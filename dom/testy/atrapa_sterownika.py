# Atrapa sterownika Tecomat do testow panelu - patrz dom/testy/scenariusz.sh.
"""Atrapa sterownika Tecomat: PAGE115.XML, impulsy nastawy, licznik zapytan."""
import http.server, json, sys, threading, time, urllib.parse

ZMIENNE = {
    '__T46AA2571_REAL_.1f': '20.1',   # Temperatura pokojowa
    '__T9E13248E_REAL_.1f': '30.0', '__T50A32455_REAL_.1f': '28.0',
    '__T881A25AA_REAL_.1f': '46.5',   # CWU
    '__T033A2538_REAL_.1f': '0.0', '__TDE3BFC02_REAL_.1f': '3.0',
    '__TD50B2FF2_REAL_.2f': '0.00', '__TA725D6FD_REAL_.0f': '4716',
    '__TB48CC351_REAL_.1f': '18.0',
}
NASTAWA, W_GORE, W_DOL = '__T05D9E707_REAL_.1f', '__TCA37B6A0_BOOL_i', '__TF795EE37_BOOL_i'
stan = {'nastawa': 20.0, 'zapytania': 0, 'odczyty': 0, 'impulsy': 0,
        'rownolegle_max': 0, 'w_toku': 0}
zamek = threading.Lock()

def xml():
    z = dict(ZMIENNE, **{NASTAWA: f"{stan['nastawa']:.1f}"})
    return ('<PAGE>' + ''.join(f'<INPUT NAME="{k}" VALUE="{v}"/>' for k, v in z.items())
            + '</PAGE>').encode()

class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _oddaj(self, tresc, typ='text/xml'):
        self.send_response(200); self.send_header('Content-Type', typ)
        self.send_header('Content-Length', str(len(tresc))); self.end_headers()
        self.wfile.write(tresc)
    def _rozmowa(self, akcja):
        with zamek:
            stan['zapytania'] += 1; stan['w_toku'] += 1
            stan['rownolegle_max'] = max(stan['rownolegle_max'], stan['w_toku'])
        try:
            time.sleep(0.05)            # wbudowany serwer nie jest szybki
            akcja()
            self._oddaj(xml())
        finally:
            with zamek: stan['w_toku'] -= 1
    def do_GET(self):
        if self.path == '/_stan':      # dla testu, poza licznikiem
            with zamek: return self._oddaj(json.dumps(stan).encode(), 'application/json')
        if self.path.startswith('/_ustaw?'):   # „czlowiek przy sterowniku"
            stan['nastawa'] = float(urllib.parse.parse_qs(self.path[8:])['n'][0])
            return self._oddaj(b'ok', 'text/plain')
        def czytaj():
            stan['odczyty'] += 1
        self._rozmowa(czytaj)
    def do_POST(self):
        tresc = urllib.parse.parse_qs(self.rfile.read(int(self.headers.get('Content-Length', 0))).decode())
        def wcisnij():
            stan['impulsy'] += 1
            if W_GORE in tresc: stan['nastawa'] = round(stan['nastawa'] + 0.1, 1)
            if W_DOL in tresc: stan['nastawa'] = round(stan['nastawa'] - 0.1, 1)
        self._rozmowa(wcisnij)

http.server.ThreadingHTTPServer(('127.0.0.1', int(sys.argv[1])), H).serve_forever()
