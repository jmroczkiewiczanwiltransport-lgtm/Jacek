#!/usr/bin/env node
// hue.mjs — sterowanie mostkiem Philips Hue z konsoli.
// Node 18+, bez zależności zewnętrznych. API CLIP v2: https://<mostek>/clip/v2/
//
// Konfiguracja (mostek, klucz aplikacji, odcisk certyfikatu) leży w ~/.hue-most.json.
// Można ją nadpisać zmiennymi HUE_MOSTEK / HUE_KLUCZ / HUE_KONFIG.

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import https from 'node:https';
import http from 'node:http';
import { fileURLToPath } from 'node:url';

const KATALOG = path.dirname(fileURLToPath(import.meta.url));
const PLIK_KONFIG = process.env.HUE_KONFIG || path.join(os.homedir(), '.hue-most.json');

// ───────────────────────────── konfiguracja ─────────────────────────────

function wczytajKonfig() {
  try { return JSON.parse(fs.readFileSync(PLIK_KONFIG, 'utf8')); } catch { return {}; }
}

function zapiszKonfig(k) {
  fs.writeFileSync(PLIK_KONFIG, JSON.stringify(k, null, 2));
  try { fs.chmodSync(PLIK_KONFIG, 0o600); } catch {}
}

function wymagajKonfig() {
  const k = wczytajKonfig();
  if (process.env.HUE_MOSTEK) k.most = process.env.HUE_MOSTEK;
  if (process.env.HUE_KLUCZ) k.klucz = process.env.HUE_KLUCZ;
  if (!k.most || !k.klucz) {
    throw new Error('Mostek nie jest sparowany. Uruchom: node hue.mjs polacz');
  }
  return k;
}

// ───────────────────────── komunikacja z mostkiem ─────────────────────────

// Mostek Hue ma certyfikat samopodpisany (CN = identyfikator mostka), więc łańcucha
// zaufania nie da się sprawdzić. Zamiast tego przy parowaniu zapamiętujemy odcisk
// certyfikatu i przy każdym kolejnym połączeniu porównujemy — podmiana urządzenia
// w sieci lokalnej zostanie wykryta.
function zadanieHttps(host, metoda, sciezka, naglowki, cialo, oczekiwanyOdcisk, limitMs = 10000) {
  return new Promise((zwroc, odrzuc) => {
    const dane = cialo === undefined ? null : Buffer.from(JSON.stringify(cialo));
    const req = https.request({
      host, port: 443, method: metoda, path: sciezka,
      rejectUnauthorized: false,
      headers: {
        'Content-Type': 'application/json',
        ...(dane ? { 'Content-Length': dane.length } : {}),
        ...naglowki,
      },
    }, (res) => {
      const odcisk = res.socket.getPeerCertificate?.()?.fingerprint256 || null;
      if (oczekiwanyOdcisk && odcisk && odcisk !== oczekiwanyOdcisk) {
        req.destroy();
        return odrzuc(new Error(
          `Certyfikat mostka ${host} jest inny niż zapamiętany przy parowaniu.\n` +
          'Jeśli to nie była wymiana/reset mostka — ktoś podszywa się pod niego w sieci.\n' +
          'Po wymianie mostka: usuń plik ' + PLIK_KONFIG + ' i sparuj od nowa.'));
      }
      let buf = '';
      res.setEncoding('utf8');
      res.on('data', (c) => { buf += c; });
      res.on('end', () => zwroc({ status: res.statusCode, tekst: buf, odcisk }));
    });
    req.setTimeout(limitMs, () => req.destroy(new Error(`Mostek ${host} nie odpowiada`)));
    req.on('error', odrzuc);
    if (dane) req.write(dane);
    req.end();
  });
}

async function api(k, metoda, zasob, cialo) {
  const { status, tekst } = await zadanieHttps(
    k.most, metoda, '/clip/v2/' + zasob,
    { 'hue-application-key': k.klucz }, cialo, k.odcisk);
  let odp;
  try { odp = JSON.parse(tekst); } catch {
    throw new Error(`Mostek odpowiedział ${status}, treść nie jest JSON-em: ${tekst.slice(0, 120)}`);
  }
  if (odp.errors?.length) throw new Error(odp.errors.map((e) => e.description).join('; '));
  if (status >= 400) throw new Error(`Mostek odpowiedział ${status}: ${tekst.slice(0, 200)}`);
  return odp.data ?? [];
}

const pobierz = (k, zasob) => api(k, 'GET', 'resource/' + zasob);
const ustaw = (k, zasob, id, cialo) => api(k, 'PUT', `resource/${zasob}/${id}`, cialo);

// ───────────────────────────── wyszukiwanie ─────────────────────────────

async function znajdzMostki() {
  const znalezione = [];
  // 1. usługa wyszukiwania Philipsa (wymaga internetu)
  try {
    const odp = await new Promise((zwroc, odrzuc) => {
      const req = https.get('https://discovery.meethue.com', (res) => {
        let b = ''; res.on('data', (c) => { b += c; }); res.on('end', () => zwroc(b));
      });
      req.setTimeout(5000, () => req.destroy(new Error('brak odpowiedzi')));
      req.on('error', odrzuc);
    });
    for (const m of JSON.parse(odp)) {
      znalezione.push({ ip: m.internalipaddress, id: m.id, skad: 'discovery.meethue.com' });
    }
  } catch {}
  if (znalezione.length) return znalezione;

  // 2. bez internetu — przeglądamy własną podsieć /24
  const adres = Object.values(os.networkInterfaces()).flat()
    .find((i) => i && i.family === 'IPv4' && !i.internal);
  if (!adres) return znalezione;
  const baza = adres.address.split('.').slice(0, 3).join('.');
  process.stderr.write(`Brak internetu — przeglądam sieć ${baza}.0/24 …\n`);

  const kandydaci = Array.from({ length: 254 }, (_, i) => `${baza}.${i + 1}`);
  const rownolegle = 32;
  let kursor = 0;
  await Promise.all(Array.from({ length: rownolegle }, async () => {
    while (kursor < kandydaci.length) {
      const ip = kandydaci[kursor++];
      try {
        const { tekst } = await zadanieHttps(ip, 'GET', '/api/config', {}, undefined, null, 900);
        const cfg = JSON.parse(tekst);
        if (cfg.bridgeid) znalezione.push({ ip, id: cfg.bridgeid, nazwa: cfg.name, skad: 'sieć lokalna' });
      } catch {}
    }
  }));
  return znalezione;
}

async function polacz(ip) {
  const k = wczytajKonfig();
  if (!ip) {
    const mostki = await znajdzMostki();
    if (!mostki.length) throw new Error('Nie znalazłem mostka. Podaj adres: node hue.mjs polacz 192.168.1.50');
    if (mostki.length > 1) {
      console.log('Znalazłem kilka mostków:');
      mostki.forEach((m) => console.log(`  ${m.ip}  ${m.id}  (${m.skad})`));
      throw new Error('Wybierz jeden: node hue.mjs polacz <adres>');
    }
    ip = mostki[0].ip;
  }
  console.log(`Mostek: ${ip}`);
  console.log('Naciśnij okrągły przycisk na mostku. Czekam do 60 sekund…');
  const nazwa = `hue-panel#${os.hostname().slice(0, 19)}`;
  for (let proba = 0; proba < 30; proba++) {
    const { tekst, odcisk } = await zadanieHttps(
      ip, 'POST', '/api', {}, { devicetype: nazwa, generateclientkey: true }, null);
    const odp = JSON.parse(tekst)[0] || {};
    if (odp.success) {
      zapiszKonfig({ ...k, most: ip, klucz: odp.success.username, kluczKlienta: odp.success.clientkey, odcisk });
      console.log(`\nSparowano. Konfiguracja: ${PLIK_KONFIG}`);
      return;
    }
    if (odp.error && odp.error.type !== 101) throw new Error(odp.error.description);
    process.stdout.write('.');
    await pauza(2000);
  }
  throw new Error('\nNie doczekałem się naciśnięcia przycisku.');
}

const pauza = (ms) => new Promise((z) => setTimeout(z, ms));

// ───────────────────────── model zasobów mostka ─────────────────────────

async function wczytajStan(k) {
  const [swiatla, pokoje, strefy, sceny, grupy, urzadzenia, ruch, przyciski, zasilanie, zigbee, temperatury, natezenie] =
    await Promise.all(['light', 'room', 'zone', 'scene', 'grouped_light', 'device', 'motion', 'button',
      'device_power', 'zigbee_connectivity', 'temperature', 'light_level'].map((z) => pobierz(k, z)));

  const wgId = (lista) => Object.fromEntries(lista.map((x) => [x.id, x]));
  const s = {
    swiatla, pokoje, strefy, sceny, grupy, urzadzenia, ruch, przyciski, zasilanie, zigbee, temperatury, natezenie,
    idSwiatla: wgId(swiatla), idUrzadzenia: wgId(urzadzenia), idGrupy: wgId(grupy),
  };
  s.domGrupa = grupy.find((g) => g.owner?.rtype === 'bridge_home')?.id || null;
  return s;
}

const nazwaZasobu = (x) => x?.metadata?.name || x?.id || '—';
const bezOgonkow = (t) => (t || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().trim();
const pasuje = (a, b) => bezOgonkow(a) === bezOgonkow(b);

// Cel: "wszystko" | "pokoj:Salon" | "strefa:Parter" | "lampa:Biurko" | sama nazwa.
// Zwraca { zasob: 'grouped_light'|'light', id, opis }.
function znajdzCel(s, cel) {
  const t = String(cel || '').trim();
  if (!t || pasuje(t, 'wszystko') || pasuje(t, 'dom')) {
    if (!s.domGrupa) throw new Error('Mostek nie udostępnia grupy „cały dom”.');
    return { zasob: 'grouped_light', id: s.domGrupa, opis: 'cały dom' };
  }
  const [prefiks, ...reszta] = t.split(':');
  const nazwa = reszta.length ? reszta.join(':') : t;
  const zPrefiksem = reszta.length ? bezOgonkow(prefiks) : null;

  const grupaZ = (kolekcja, etykieta) => {
    const trafienie = kolekcja.find((g) => pasuje(nazwaZasobu(g), nazwa));
    if (!trafienie) return null;
    const usluga = trafienie.services?.find((u) => u.rtype === 'grouped_light');
    if (!usluga) throw new Error(`${etykieta} „${nazwaZasobu(trafienie)}” nie ma grupy świateł.`);
    return { zasob: 'grouped_light', id: usluga.rid, opis: `${etykieta} ${nazwaZasobu(trafienie)}` };
  };

  if (!zPrefiksem || zPrefiksem === 'pokoj') {
    const trafienie = grupaZ(s.pokoje, 'pokój'); if (trafienie) return trafienie;
  }
  if (!zPrefiksem || zPrefiksem === 'strefa') {
    const trafienie = grupaZ(s.strefy, 'strefa'); if (trafienie) return trafienie;
  }
  if (!zPrefiksem || zPrefiksem === 'lampa' || zPrefiksem === 'swiatlo') {
    const lampa = s.swiatla.find((l) => pasuje(nazwaZasobu(l), nazwa));
    if (lampa) return { zasob: 'light', id: lampa.id, opis: `lampa ${nazwaZasobu(lampa)}` };
  }
  throw new Error(`Nie znam celu „${t}”. Zobacz: node hue.mjs lista`);
}

// ─────────────────────────────── akcje ───────────────────────────────

const KELWIN_NA_MIRED = (kelwin) => Math.round(1e6 / kelwin);

function hexNaXy(hex) {
  const m = /^#?([0-9a-f]{6})$/i.exec(hex.trim());
  if (!m) throw new Error(`„${hex}” to nie jest kolor w formacie #rrggbb`);
  const [r, g, b] = [0, 2, 4].map((i) => parseInt(m[1].slice(i, i + 2), 16) / 255)
    .map((v) => (v > 0.04045 ? ((v + 0.055) / 1.055) ** 2.4 : v / 12.92));
  const X = r * 0.4124 + g * 0.3576 + b * 0.1805;
  const Y = r * 0.2126 + g * 0.7152 + b * 0.0722;
  const Z = r * 0.0193 + g * 0.1192 + b * 0.9505;
  const suma = X + Y + Z;
  if (!suma) return { x: 0.3127, y: 0.3290 };
  return { x: +(X / suma).toFixed(4), y: +(Y / suma).toFixed(4) };
}

// Akcja opisana po polsku → ciało żądania CLIP v2.
function budujAkcje(akcja, stanBiezacy) {
  const cialo = {};
  if (akcja.przelacz) {
    if (stanBiezacy === undefined) throw new Error('Do przełączenia potrzebny jest bieżący stan.');
    cialo.on = { on: !stanBiezacy };
  } else if (akcja.wlacz !== undefined) {
    cialo.on = { on: !!akcja.wlacz };
  }
  if (akcja.jasnosc !== undefined && akcja.jasnosc !== null) {
    const j = Math.max(0, Math.min(100, Number(akcja.jasnosc)));
    if (j === 0) cialo.on = { on: false };
    else { cialo.on = cialo.on?.on === false ? cialo.on : { on: true }; cialo.dimming = { brightness: j }; }
  }
  if (akcja.temperatura) {
    const k = Number(akcja.temperatura);
    // przyjmujemy kelwiny (2000–6500) albo miredy (153–500)
    const mired = k > 1000 ? KELWIN_NA_MIRED(k) : Math.round(k);
    cialo.color_temperature = { mirek: Math.max(153, Math.min(500, mired)) };
  }
  if (akcja.kolor) cialo.color = { xy: hexNaXy(akcja.kolor) };
  if (akcja.przejscie !== undefined) cialo.dynamics = { duration: Math.round(Number(akcja.przejscie) * 1000) };
  return cialo;
}

async function wykonaj(k, s, cel, akcja) {
  if (akcja.scena) return uruchomScene(k, s, cel, akcja);
  const t = znajdzCel(s, cel);
  let stanBiezacy;
  if (akcja.przelacz) {
    const [biezacy] = await pobierz(k, `${t.zasob}/${t.id}`);
    stanBiezacy = biezacy?.on?.on;
  }
  const cialo = budujAkcje(akcja, stanBiezacy);
  if (!Object.keys(cialo).length) throw new Error('Pusta akcja — nie ma czego ustawić.');
  await ustaw(k, t.zasob, t.id, cialo);
  return t.opis;
}

async function uruchomScene(k, s, cel, akcja) {
  const kandydaci = s.sceny.filter((sc) => pasuje(nazwaZasobu(sc), akcja.scena));
  if (!kandydaci.length) throw new Error(`Nie ma sceny „${akcja.scena}”.`);
  let scena = kandydaci[0];
  if (cel && kandydaci.length > 1) {
    const grupa = [...s.pokoje, ...s.strefy].find((g) => pasuje(nazwaZasobu(g), String(cel).split(':').pop()));
    scena = kandydaci.find((sc) => sc.group?.rid === grupa?.id) || scena;
  }
  const recall = { action: 'active' };
  if (akcja.przejscie !== undefined) recall.duration = Math.round(Number(akcja.przejscie) * 1000);
  if (akcja.jasnosc !== undefined) recall.dimming = { brightness: Number(akcja.jasnosc) };
  await ustaw(k, 'scene', scena.id, { recall });
  return `scena ${nazwaZasobu(scena)}`;
}

// ───────────────────────────── diagnostyka ─────────────────────────────

function zbierzDiagnostyke(s) {
  const wg = (lista) => Object.fromEntries(lista.map((x) => [x.owner?.rid, x]));
  const zasilanieUrz = wg(s.zasilanie);
  const zigbeeUrz = wg(s.zigbee);

  const urzadzenia = s.urzadzenia.map((u) => {
    const swiatlo = u.services?.find((x) => x.rtype === 'light');
    const lampa = swiatlo ? s.idSwiatla[swiatlo.rid] : null;
    const zas = zasilanieUrz[u.id];
    const zig = zigbeeUrz[u.id];
    return {
      nazwa: nazwaZasobu(u),
      model: u.product_data?.product_name || u.product_data?.model_id || '—',
      oprogramowanie: u.product_data?.software_version || '—',
      typ: swiatlo ? 'światło' : (u.services || []).map((x) => x.rtype).join(', '),
      lacznosc: zig?.status || (lampa ? 'brak danych' : '—'),
      wlaczone: lampa ? !!lampa.on?.on : null,
      jasnosc: lampa?.dimming?.brightness ?? null,
      bateria: zas?.power_state?.battery_level ?? null,
      stanBaterii: zas?.power_state?.battery_state ?? null,
    };
  });

  const problemy = [];
  for (const u of urzadzenia) {
    if (u.lacznosc === 'connectivity_issue') problemy.push(`${u.nazwa}: mostek nie ma łączności (zasilanie? zasięg?)`);
    if (u.bateria !== null && u.bateria <= 20) problemy.push(`${u.nazwa}: bateria ${u.bateria}%`);
    if (u.stanBaterii === 'critical') problemy.push(`${u.nazwa}: bateria na wyczerpaniu`);
  }
  const osierocone = s.sceny.filter((sc) => ![...s.pokoje, ...s.strefy].some((g) => g.id === sc.group?.rid));
  for (const sc of osierocone) problemy.push(`scena „${nazwaZasobu(sc)}”: nie należy do żadnego pokoju ani strefy`);

  return {
    czas: new Date().toISOString(),
    podsumowanie: {
      urzadzen: urzadzenia.length,
      swiatel: s.swiatla.length,
      wlaczonych: s.swiatla.filter((l) => l.on?.on).length,
      pokoi: s.pokoje.length,
      stref: s.strefy.length,
      scen: s.sceny.length,
      czujnikowRuchu: s.ruch.length,
      przyciskow: new Set(s.przyciski.map((p) => p.owner?.rid)).size,
      problemow: problemy.length,
    },
    urzadzenia, problemy,
  };
}

// ─────────────────────── wschód i zachód słońca ───────────────────────
// Algorytm z „sunrise equation” — dokładność ±2 min, w zupełności wystarcza,
// żeby zapalić światło o zmierzchu.

function porySlonca(data, szerokosc, dlugosc) {
  const stopnie = Math.PI / 180;
  // liczymy dla południa czasu lokalnego danego dnia — inaczej tick po północy
  // trafiałby na dzień poprzedni
  const poludnie = new Date(data); poludnie.setHours(12, 0, 0, 0);
  const dzienJulianski = poludnie.getTime() / 86400000 + 2440587.5;
  const n = Math.round(dzienJulianski - 2451545.0 + 0.0008);
  const przyblizenie = n + 0.0009 - dlugosc / 360;   // dlugosc dodatnia na wschód
  const M = (357.5291 + 0.98560028 * przyblizenie) % 360;
  const C = 1.9148 * Math.sin(M * stopnie) + 0.02 * Math.sin(2 * M * stopnie) + 0.0003 * Math.sin(3 * M * stopnie);
  const lambda = (M + C + 180 + 102.9372) % 360;
  const tranzyt = 2451545.0 + przyblizenie + 0.0053 * Math.sin(M * stopnie) - 0.0069 * Math.sin(2 * lambda * stopnie);
  const sinDeklinacji = Math.sin(lambda * stopnie) * Math.sin(23.44 * stopnie);
  const deklinacja = Math.asin(sinDeklinacji);
  const cosGodzinnego = (Math.sin(-0.833 * stopnie) - Math.sin(szerokosc * stopnie) * sinDeklinacji) /
    (Math.cos(szerokosc * stopnie) * Math.cos(deklinacja));
  if (cosGodzinnego > 1) return { wschod: null, zachod: null };   // słońce nie wschodzi
  if (cosGodzinnego < -1) return { wschod: null, zachod: null };   // słońce nie zachodzi
  const katGodzinny = Math.acos(cosGodzinnego) / stopnie;
  const naDate = (jd) => new Date((jd - 2440587.5) * 86400000);
  return { wschod: naDate(tranzyt - katGodzinny / 360), zachod: naDate(tranzyt + katGodzinny / 360) };
}

// "06:30" | "wschod" | "zachod-00:30" | "wschod+01:00"  →  Date na dany dzień
function poraNaDzien(zapis, dzien, polozenie) {
  const t = bezOgonkow(zapis);
  const proste = /^(\d{1,2}):(\d{2})$/.exec(t);
  if (proste) {
    const d = new Date(dzien);
    d.setHours(+proste[1], +proste[2], 0, 0);
    return d;
  }
  const wzgledne = /^(wschod|zachod)\s*(?:([+-])\s*(\d{1,2}):(\d{2}))?$/.exec(t);
  if (!wzgledne) throw new Error(`Nie rozumiem godziny „${zapis}”. Użyj 06:30, wschod, zachod-00:30.`);
  if (!polozenie) throw new Error('Godziny względem słońca wymagają pola "polozenie" w pliku automatyki.');
  const pory = porySlonca(dzien, polozenie.szerokosc, polozenie.dlugosc);
  const baza = wzgledne[1] === 'wschod' ? pory.wschod : pory.zachod;
  if (!baza) return null;
  const przesuniecie = wzgledne[2] ? (wzgledne[2] === '-' ? -1 : 1) * ((+wzgledne[3]) * 60 + (+wzgledne[4])) : 0;
  return new Date(baza.getTime() + przesuniecie * 60000);
}

const DNI = { nd: 0, pn: 1, wt: 2, sr: 3, cz: 4, pt: 5, sb: 6 };
function dzisiajPasuje(dni, data) {
  if (!dni || !dni.length) return true;
  return dni.some((d) => DNI[bezOgonkow(d)] === data.getDay());
}

function wPrzedziale(teraz, od, do_) {
  if (!od || !do_) return true;
  const minuty = teraz.getHours() * 60 + teraz.getMinutes();
  const [go, mo] = od.split(':').map(Number);
  const [gd, md] = do_.split(':').map(Number);
  const a = go * 60 + mo, b = gd * 60 + md;
  return a <= b ? (minuty >= a && minuty < b) : (minuty >= a || minuty < b);
}

// ───────────────────────────── automatyka ─────────────────────────────

function log(...czesci) {
  console.log(new Date().toLocaleTimeString('pl-PL'), ...czesci);
}

async function automat(plik) {
  const k = wymagajKonfig();
  const sciezka = path.resolve(plik || path.join(KATALOG, 'automatyka.json'));
  if (!fs.existsSync(sciezka)) {
    throw new Error(`Brak pliku ${sciezka}. Skopiuj automatyka.przyklad.json i dostosuj.`);
  }
  let cfg = JSON.parse(fs.readFileSync(sciezka, 'utf8'));
  let s = await wczytajStan(k);
  log(`Automatyka wystartowała. Reguł: ${(cfg.harmonogramy || []).length} czasowych, ` +
      `${(cfg.czujniki || []).length} na ruch, ${(cfg.przyciski || []).length} na przyciski.`);

  // plik konfiguracyjny przeładowuje się sam po zapisie z panelu
  fs.watchFile(sciezka, { interval: 2000 }, () => {
    try { cfg = JSON.parse(fs.readFileSync(sciezka, 'utf8')); log('Przeładowano', path.basename(sciezka)); }
    catch (e) { log('Błąd w pliku automatyki:', e.message); }
  });

  const wykonane = new Set();          // klucz: "nazwa|RRRR-MM-DD" — żeby nie odpalać dwa razy
  const wygaszacze = new Map();        // cel → timeout gaszenia po ruchu

  const zrob = async (cel, akcja, powod) => {
    try {
      const opis = await wykonaj(k, s, cel, akcja);
      log(`${powod} → ${opis}`);
    } catch (e) {
      log(`${powod} → błąd: ${e.message}`);
    }
  };

  // odświeżanie listy zasobów (nowa lampa, zmieniona nazwa)
  setInterval(async () => {
    try { s = await wczytajStan(k); } catch (e) { log('Nie mogę odświeżyć stanu:', e.message); }
  }, 5 * 60 * 1000);

  // ── reguły czasowe ──
  setInterval(() => {
    const teraz = new Date();
    const dzienKlucz = teraz.toISOString().slice(0, 10);
    for (const h of cfg.harmonogramy || []) {
      if (h.wylaczona) continue;
      if (!dzisiajPasuje(h.dni, teraz)) continue;
      let cel;
      try { cel = poraNaDzien(h.o, teraz, cfg.polozenie); } catch (e) { log(`„${h.nazwa}”: ${e.message}`); continue; }
      if (!cel) continue;
      const klucz = `${h.nazwa}|${dzienKlucz}`;
      if (wykonane.has(klucz)) continue;
      const roznica = teraz - cel;
      if (roznica >= 0 && roznica < 60000) {
        wykonane.add(klucz);
        zrob(h.cel, h.akcja, `harmonogram „${h.nazwa}”`);
      }
    }
    if (wykonane.size > 500) wykonane.clear();
    planujObecnosc(teraz);
  }, 15000);

  // ── symulacja obecności ──
  let nastepnaObecnosc = 0;
  const planujObecnosc = (teraz) => {
    const o = cfg.obecnosc;
    if (!o?.wlaczona) return;
    let od, do_;
    try {
      od = poraNaDzien(o.od || 'zachod', teraz, cfg.polozenie);
      do_ = poraNaDzien(o.do || '23:00', teraz, cfg.polozenie);
    } catch { return; }
    if (!od || !do_ || teraz < od || teraz > do_) return;
    if (teraz.getTime() < nastepnaObecnosc) return;
    const min = (o.minPrzerwa ?? 15), max = (o.maxPrzerwa ?? 45);
    nastepnaObecnosc = teraz.getTime() + (min + Math.random() * (max - min)) * 60000;
    const zapal = Math.random() < 0.6;
    zrob(o.cel, zapal ? { wlacz: true, jasnosc: o.jasnosc ?? 60, przejscie: 3 } : { wlacz: false, przejscie: 3 },
      'symulacja obecności');
  };

  // ── czujniki ruchu i przyciski: strumień zdarzeń z mostka ──
  strumienZdarzen(k, (zdarzenie) => {
    for (const dane of zdarzenie.data || []) {
      if (dane.type === 'motion') obsluzRuch(dane);
      if (dane.type === 'button') obsluzPrzycisk(dane);
    }
  }, (info) => log(info));

  const nazwaUrzadzeniaUslugi = (rid, kolekcja) => {
    const usluga = kolekcja.find((x) => x.id === rid);
    const urzadzenie = usluga && s.idUrzadzenia[usluga.owner?.rid];
    return urzadzenie ? nazwaZasobu(urzadzenie) : null;
  };

  function obsluzRuch(dane) {
    if (!dane.motion) return;
    const nazwa = nazwaUrzadzeniaUslugi(dane.id, s.ruch);
    for (const r of cfg.czujniki || []) {
      if (r.wylaczona) continue;
      if (!pasuje(r.czujnik, nazwa || '')) continue;
      const teraz = new Date();
      if (!wPrzedziale(teraz, r.od, r.do)) continue;
      const jestRuch = dane.motion.motion ?? dane.motion.motion_report?.motion;
      if (jestRuch) {
        clearTimeout(wygaszacze.get(r.nazwa || r.czujnik));
        const noc = r.wNocy && wPrzedziale(teraz, r.wNocy.od, r.wNocy.do);
        zrob(r.cel, { ...r.akcja, ...(noc ? r.wNocy : {}) }, `ruch: ${nazwa}`);
        if (r.gasPo) {
          wygaszacze.set(r.nazwa || r.czujnik, setTimeout(() => {
            zrob(r.cel, { wlacz: false, przejscie: r.przejscieGaszenia ?? 5 }, `brak ruchu ${r.gasPo}s: ${nazwa}`);
          }, r.gasPo * 1000));
        }
      }
    }
  }

  function obsluzPrzycisk(dane) {
    const raport = dane.button?.button_report || dane.button;
    const zdarzenie = raport?.event || raport?.last_event;
    if (!zdarzenie) return;
    const usluga = s.przyciski.find((p) => p.id === dane.id);
    const nazwa = usluga && s.idUrzadzenia[usluga.owner?.rid] ? nazwaZasobu(s.idUrzadzenia[usluga.owner.rid]) : null;
    const numer = usluga?.metadata?.control_id;
    for (const r of cfg.przyciski || []) {
      if (r.wylaczona) continue;
      if (!pasuje(r.przycisk, nazwa || '')) continue;
      if (r.guzik && Number(r.guzik) !== Number(numer)) continue;
      if ((r.zdarzenie || 'short_release') !== zdarzenie) continue;
      zrob(r.cel, r.akcja, `przycisk ${nazwa}/${numer} (${zdarzenie})`);
    }
  }

  process.on('SIGINT', () => { log('Zatrzymuję automatykę.'); process.exit(0); });
}

// Strumień zdarzeń mostka (SSE). Sam się wznawia po zerwaniu połączenia.
function strumienZdarzen(k, naZdarzenie, naInfo = () => {}) {
  let opoznienie = 1000;
  const polacz = () => {
    const req = https.request({
      host: k.most, port: 443, path: '/eventstream/clip/v2', method: 'GET',
      rejectUnauthorized: false,
      headers: { 'hue-application-key': k.klucz, Accept: 'text/event-stream' },
    }, (res) => {
      if (res.statusCode !== 200) {
        naInfo(`Strumień zdarzeń odrzucony (${res.statusCode}) — ponawiam.`);
        res.resume(); return wznow();
      }
      naInfo('Nasłuchuję zdarzeń z mostka (czujniki, przyciski).');
      opoznienie = 1000;
      let bufor = '';
      res.setEncoding('utf8');
      res.on('data', (kawalek) => {
        bufor += kawalek;
        let koniec;
        while ((koniec = bufor.indexOf('\n\n')) !== -1) {
          const blok = bufor.slice(0, koniec); bufor = bufor.slice(koniec + 2);
          for (const linia of blok.split('\n')) {
            if (!linia.startsWith('data:')) continue;
            try { JSON.parse(linia.slice(5).trim()).forEach(naZdarzenie); } catch {}
          }
        }
      });
      res.on('end', wznow);
      res.on('error', wznow);
    });
    req.on('error', (e) => { naInfo('Strumień zdarzeń: ' + e.message); wznow(); });
    req.end();
  };
  let wznowiony = false;
  const wznow = () => {
    if (wznowiony) return;
    wznowiony = true;
    setTimeout(() => { wznowiony = false; polacz(); }, opoznienie);
    opoznienie = Math.min(opoznienie * 2, 30000);
  };
  polacz();
}

// ─────────────────── serwer panelu (HTML + pośrednik) ───────────────────
// Panel otwarty prosto z dysku trafia na certyfikat mostka i zasady CORS
// przeglądarki. Ten serwer podaje panel po http://localhost i przekazuje
// zapytania do mostka po stronie Node — wtedy działa zawsze.

function serwerPanelu(port = 8123) {
  const konfig = () => wczytajKonfig();
  const serwer = http.createServer(async (req, res) => {
    const url = new URL(req.url, 'http://localhost');
    const odpowiedz = (kod, dane, typ = 'application/json; charset=utf-8') => {
      res.writeHead(kod, { 'Content-Type': typ, 'Cache-Control': 'no-store' });
      res.end(typeof dane === 'string' ? dane : JSON.stringify(dane));
    };
    try {
      if (url.pathname === '/' || url.pathname === '/panel.html') {
        const html = fs.readFileSync(path.join(KATALOG, 'panel.html'), 'utf8');
        return odpowiedz(200, html, 'text/html; charset=utf-8');
      }
      if (url.pathname === '/favicon.ico') { res.writeHead(204); return res.end(); }
      if (url.pathname === '/most-info') {
        const k = konfig();
        return odpowiedz(200, { tryb: 'posrednik', most: k.most || null, sparowany: !!k.klucz });
      }
      if (url.pathname === '/most-szukaj') {
        return odpowiedz(200, { mostki: await znajdzMostki() });
      }
      if (url.pathname === '/most-parowanie' && req.method === 'POST') {
        const cialo = JSON.parse(await zbierzCialo(req) || '{}');
        const ip = cialo.ip || konfig().most;
        if (!ip) return odpowiedz(400, { blad: 'Nie podano adresu mostka.' });
        const { tekst, odcisk } = await zadanieHttps(ip, 'POST', '/api', {},
          { devicetype: `hue-panel#${os.hostname().slice(0, 19)}`, generateclientkey: true }, null);
        const odp = JSON.parse(tekst)[0] || {};
        if (odp.success) {
          zapiszKonfig({ ...konfig(), most: ip, klucz: odp.success.username, kluczKlienta: odp.success.clientkey, odcisk });
          return odpowiedz(200, { sparowany: true });
        }
        return odpowiedz(200, { sparowany: false, blad: odp.error?.description || 'Naciśnij przycisk na mostku.' });
      }
      if (url.pathname === '/automatyka') {
        const plik = path.join(KATALOG, 'automatyka.json');
        if (req.method === 'PUT') {
          const cialo = await zbierzCialo(req);
          JSON.parse(cialo);                              // walidacja przed zapisem
          fs.writeFileSync(plik, cialo);
          return odpowiedz(200, { zapisano: true });
        }
        const domyslny = path.join(KATALOG, 'automatyka.przyklad.json');
        const zrodlo = fs.existsSync(plik) ? plik : domyslny;
        return odpowiedz(200, fs.readFileSync(zrodlo, 'utf8'));
      }
      if (url.pathname.startsWith('/most/')) {
        const k = konfig();
        if (!k.most || !k.klucz) return odpowiedz(409, { blad: 'Mostek nie jest sparowany.' });
        const cialo = req.method === 'GET' ? undefined : JSON.parse(await zbierzCialo(req) || '{}');
        const wynik = await zadanieHttps(k.most, req.method, '/clip/v2/' + url.pathname.slice(6),
          { 'hue-application-key': k.klucz }, cialo, k.odcisk);
        return odpowiedz(wynik.status, wynik.tekst);
      }
      odpowiedz(404, { blad: 'Nie ma takiej ścieżki.' });
    } catch (e) {
      odpowiedz(500, { blad: e.message });
    }
  });
  serwer.listen(port, '127.0.0.1', () => {
    console.log(`Panel: http://localhost:${port}`);
    console.log('Zatrzymanie: Ctrl+C');
  });
}

const zbierzCialo = (req) => new Promise((zwroc) => {
  let b = ''; req.on('data', (c) => { b += c; }); req.on('end', () => zwroc(b));
});

// ─────────────────────────────── wypisy ───────────────────────────────

function wypiszListe(s) {
  const grupy = [...s.pokoje.map((p) => ['pokój', p]), ...s.strefy.map((z) => ['strefa', z])];
  for (const [rodzaj, g] of grupy) {
    const grupa = s.idGrupy[g.services?.find((u) => u.rtype === 'grouped_light')?.rid];
    const stan = grupa?.on?.on ? `włączony${grupa.dimming?.brightness ? `, ${Math.round(grupa.dimming.brightness)}%` : ''}` : 'wyłączony';
    console.log(`\n${rodzaj.toUpperCase()}: ${nazwaZasobu(g)}  (${stan})`);
    for (const rid of g.children || []) {
      const urz = s.idUrzadzenia[rid.rid];
      const swiatlo = urz?.services?.find((u) => u.rtype === 'light');
      const lampa = swiatlo && s.idSwiatla[swiatlo.rid];
      if (!lampa) continue;
      console.log(`   • ${nazwaZasobu(lampa).padEnd(26)} ${lampa.on?.on ? 'wł.' : 'wył.'}` +
        `${lampa.dimming ? `  ${String(Math.round(lampa.dimming.brightness)).padStart(3)}%` : ''}`);
    }
    const sceny = s.sceny.filter((sc) => sc.group?.rid === g.id).map(nazwaZasobu);
    if (sceny.length) console.log(`   sceny: ${sceny.join(', ')}`);
  }
  const luzem = s.swiatla.filter((l) => !grupy.some(([, g]) =>
    (g.children || []).some((c) => s.idUrzadzenia[c.rid]?.services?.some((u) => u.rid === l.id))));
  if (luzem.length) {
    console.log('\nPOZA POKOJAMI');
    for (const l of luzem) console.log(`   • ${nazwaZasobu(l)}`);
  }
}

function wypiszCzujniki(s) {
  const bateria = Object.fromEntries(s.zasilanie.map((z) => [z.owner?.rid, z.power_state?.battery_level]));
  const wypiszGrupe = (tytul, usluga, opis) => {
    const rid = new Set(usluga.map((u) => u.owner?.rid));
    if (!rid.size) return;
    console.log(`\n${tytul}`);
    for (const id of rid) {
      const urz = s.idUrzadzenia[id];
      const bat = bateria[id];
      console.log(`   • ${nazwaZasobu(urz).padEnd(26)} ${opis(id)}` +
        `${bat !== undefined && bat !== null ? `   bateria ${bat}%` : ''}`);
    }
  };
  wypiszGrupe('CZUJNIKI RUCHU', s.ruch, (id) => {
    const m = s.ruch.find((x) => x.owner?.rid === id);
    const temp = s.temperatury.find((x) => x.owner?.rid === id)?.temperature?.temperature;
    const jasno = s.natezenie.find((x) => x.owner?.rid === id)?.light?.light_level;
    return [(m?.motion?.motion ?? m?.motion?.motion_report?.motion) ? 'RUCH' : 'spokój',
      m?.enabled === false ? '(wyłączony)' : '',
      temp !== undefined ? `${temp.toFixed(1)}°C` : '',
      jasno !== undefined ? `${Math.round(10 ** ((jasno - 1) / 10000))} lx` : ''].filter(Boolean).join('  ');
  });
  wypiszGrupe('PRZYCISKI', s.przyciski, (id) => {
    const guziki = s.przyciski.filter((p) => p.owner?.rid === id)
      .map((p) => `${p.metadata?.control_id}:${p.button?.button_report?.event || p.button?.last_event || '—'}`);
    return guziki.join('  ');
  });
}

function wypiszDiagnostyke(d) {
  const p = d.podsumowanie;
  console.log(`Urządzeń: ${p.urzadzen}   światła: ${p.swiatel} (włączonych ${p.wlaczonych})   ` +
    `pokoje: ${p.pokoi}   strefy: ${p.stref}   sceny: ${p.scen}`);
  console.log(`Czujniki ruchu: ${p.czujnikowRuchu}   przyciski: ${p.przyciskow}\n`);
  console.log('URZĄDZENIE'.padEnd(28) + 'MODEL'.padEnd(24) + 'ŁĄCZNOŚĆ'.padEnd(20) + 'BATERIA');
  for (const u of d.urzadzenia) {
    const lacznosc = { connected: 'ok', connectivity_issue: 'BRAK ŁĄCZNOŚCI' }[u.lacznosc] || u.lacznosc;
    console.log(u.nazwa.slice(0, 27).padEnd(28) + String(u.model).slice(0, 23).padEnd(24) +
      String(lacznosc).padEnd(20) + (u.bateria !== null ? `${u.bateria}%` : ''));
  }
  if (d.problemy.length) {
    console.log('\nDO SPRAWDZENIA:');
    for (const x of d.problemy) console.log('   ! ' + x);
  } else {
    console.log('\nBez zastrzeżeń.');
  }
}

// ──────────────────────────────── CLI ────────────────────────────────

const POMOC = `
Sterowanie mostkiem Philips Hue.

  node hue.mjs znajdz                     szuka mostka w sieci
  node hue.mjs polacz [adres]             parowanie (naciśnij przycisk na mostku)
  node hue.mjs lista                      pokoje, strefy, lampy, sceny
  node hue.mjs czujniki                   czujniki ruchu, przyciski, baterie
  node hue.mjs diagnostyka                przegląd urządzeń i problemów
  node hue.mjs raport [plik.json]         diagnostyka do pliku

  node hue.mjs wlacz <cel>
  node hue.mjs wylacz <cel>
  node hue.mjs przelacz <cel>
  node hue.mjs jasnosc <cel> <0-100>
  node hue.mjs temperatura <cel> <2000-6500>     ciepła 2200, dzienna 4000, zimna 6500
  node hue.mjs kolor <cel> <#rrggbb>
  node hue.mjs scena <cel> <nazwa sceny>

  node hue.mjs automat [plik.json]        uruchamia automatykę (harmonogramy, czujniki)
  node hue.mjs panel [port]               panel w przeglądarce (domyślnie 8123)

Cel: "wszystko", "pokoj:Salon", "strefa:Parter", "lampa:Biurko" albo sama nazwa.
Wszystkie akcje przyjmują na końcu czas przejścia w sekundach: --przejscie 5
`;

async function main() {
  const [polecenie, ...arg] = process.argv.slice(2);
  const przejscieIdx = arg.indexOf('--przejscie');
  let przejscie;
  if (przejscieIdx !== -1) { przejscie = Number(arg[przejscieIdx + 1]); arg.splice(przejscieIdx, 2); }

  switch (polecenie) {
    case undefined: case 'pomoc': case '-h': case '--help':
      return console.log(POMOC);

    case 'znajdz': {
      const mostki = await znajdzMostki();
      if (!mostki.length) return console.log('Nie znalazłem mostka w tej sieci.');
      for (const m of mostki) console.log(`${m.ip}   ${m.id}   ${m.nazwa || ''}   (${m.skad})`);
      return;
    }
    case 'polacz': return polacz(arg[0]);
    case 'panel': return serwerPanelu(Number(arg[0]) || 8123);
    case 'automat': return automat(arg[0]);
  }

  const k = wymagajKonfig();

  switch (polecenie) {
    case 'lista': return wypiszListe(await wczytajStan(k));
    case 'czujniki': return wypiszCzujniki(await wczytajStan(k));
    case 'diagnostyka': return wypiszDiagnostyke(zbierzDiagnostyke(await wczytajStan(k)));
    case 'raport': {
      const plik = arg[0] || `hue-diagnostyka-${new Date().toISOString().slice(0, 10)}.json`;
      fs.writeFileSync(plik, JSON.stringify(zbierzDiagnostyke(await wczytajStan(k)), null, 2));
      return console.log(`Zapisano ${plik}`);
    }
  }

  const s = await wczytajStan(k);
  const cel = arg[0];
  const akcje = {
    wlacz: () => ({ wlacz: true }),
    wylacz: () => ({ wlacz: false }),
    przelacz: () => ({ przelacz: true }),
    jasnosc: () => ({ jasnosc: Number(arg[1]) }),
    temperatura: () => ({ wlacz: true, temperatura: Number(arg[1]) }),
    kolor: () => ({ wlacz: true, kolor: arg[1] }),
    scena: () => ({ scena: arg.slice(1).join(' ') }),
  };
  if (!akcje[polecenie]) {
    console.error(`Nie znam polecenia „${polecenie}”.`);
    console.log(POMOC);
    process.exitCode = 1;
    return;
  }
  if (!cel) throw new Error('Brakuje celu, np.: node hue.mjs ' + polecenie + ' pokoj:Salon');
  const akcja = akcje[polecenie]();
  if (przejscie !== undefined) akcja.przejscie = przejscie;
  console.log('OK — ' + await wykonaj(k, s, cel, akcja));
}

// uruchamiane tylko wprost z konsoli — import (np. z testów) nic nie wykonuje
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch((e) => { console.error('\n' + e.message); process.exitCode = 1; });
}

export { hexNaXy, budujAkcje, poraNaDzien, porySlonca, znajdzCel, zbierzDiagnostyke, wPrzedziale, dzisiajPasuje, bezOgonkow };
