# Nakladka uruchamiajaca prawdziwy panel w testach - patrz dom/testy/scenariusz.sh.
"""Uruchamia prawdziwy panel z podstawiona prognoza i przyspieszonym zegarem."""
import importlib.util, sys, time as _czas

KAT, PRZYSPIESZENIE, *reszta = sys.argv[1:]
PRZYSPIESZENIE = float(PRZYSPIESZENIE)
sys.path.insert(0, KAT)
import pogoda
if '--slonecznie' in reszta:
    reszta.remove('--slonecznie')
    pogoda.pogoda = lambda ustawienia=None, okno=(11, 16), limit=10: {
        'temperatura': 5.0, 'zachmurzenie': 10, 'suma_doby': 3.5, 'suma_okna': 3.0,
        'suma_jutra': 2.5, 'okno': list(okno), 'ocena': 'sloneczny', 'nazwa': 'test'}
else:
    def _bez_sieci(*a, **k):
        raise OSError('getaddrinfo failed (atrapa: brak DNS)')
    pogoda.pogoda = _bez_sieci

spec = importlib.util.spec_from_file_location('pompa_acond', f'{KAT}/pompa-acond.py')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)

class Zegar:                       # czas prawdziwy, sen sciesniety
    def __getattr__(self, nazwa): return getattr(_czas, nazwa)
    @staticmethod
    def sleep(s): _czas.sleep(s / PRZYSPIESZENIE)
m.time = Zegar()
sys.argv = ['pompa-acond.py'] + reszta
m.main()
