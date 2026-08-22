const ot = require('opentype.js');
const fs = require('fs');

const FDIR = 'node_modules/@fontsource/archivo/files/';
const load = w => ot.parse(fs.readFileSync(FDIR + `archivo-latin-${w}-normal.woff`).buffer);
const F800 = load(800), F600 = load(600);

// ---- tekst na obrysy, z kontrolowanym swiatlem miedzy literami ----
// Nie uzywamy Path.toSVG() z opentype.js: potrafi wypisac NaN w pojedynczej
// wspolrzednej i nie domyka konturow literą Z, co rozsypuje glif przy renderowaniu.
// Skladamy dane sciezki z listy komend, gdzie mamy pelna kontrole.
function num(v) {
  if (!Number.isFinite(v)) throw new Error('wspolrzedna nie jest liczba: ' + v);
  return String(Math.round(v * 100) / 100);
}

// opentype nie wysyla komendy Z - kontury sa domkniete domyslnie. Przy wypelnieniu
// przegladarka domyka je sama, ale domykamy jawnie, zeby plik byl poprawny takze
// dla programow graficznych i konwerterow.
function cmdsToD(commands) {
  let d = '';
  for (const c of commands) {
    if (c.type === 'M') d += (d ? 'Z' : '') + 'M' + num(c.x) + ' ' + num(c.y);
    else if (c.type === 'L') d += 'L' + num(c.x) + ' ' + num(c.y);
    else if (c.type === 'Q') d += 'Q' + num(c.x1) + ' ' + num(c.y1) + ' ' + num(c.x) + ' ' + num(c.y);
    else if (c.type === 'C') d += 'C' + num(c.x1) + ' ' + num(c.y1) + ' ' + num(c.x2) + ' ' + num(c.y2) + ' ' + num(c.x) + ' ' + num(c.y);
    else if (c.type === 'Z') d += 'Z';
    else throw new Error('nieznana komenda sciezki: ' + c.type);
  }
  return d ? (d.endsWith('Z') ? d : d + 'Z') : d;
}

function textPath(font, str, capHeight, x, baseline, trackingEm) {
  const upem = font.unitsPerEm;
  const cap = font.tables.os2.sCapHeight || upem * 0.72;
  const size = capHeight * upem / cap;
  const track = (trackingEm || 0) * size;
  let cx = x, d = '';
  for (const ch of str) {
    const g = font.charToGlyph(ch);
    if (!Number.isFinite(g.advanceWidth)) throw new Error('brak szerokosci glifu dla ' + JSON.stringify(ch));
    d += cmdsToD(g.getPath(cx, baseline, size).commands);
    cx += g.advanceWidth / upem * size + track;
  }
  return { d: d, width: cx - x - track };
}

// ---- kwadrat z wyciętym znakiem równości; dziury przez evenodd,
// ---- zeby znak dzialal na dowolnym tle, a nie tylko na bialym ----
function tile(s) {
  const r = 8 * s / 100;                    // narożnik ledwo zmiękczony - to ma być precyzyjne
  const S = s, k = r;
  const outer =
    `M ${k} 0 H ${S - k} A ${k} ${k} 0 0 1 ${S} ${k} V ${S - k} ` +
    `A ${k} ${k} 0 0 1 ${S - k} ${S} H ${k} A ${k} ${k} 0 0 1 0 ${S - k} V ${k} ` +
    `A ${k} ${k} 0 0 1 ${k} 0 Z`;
  const bw = 56 * s / 100, bh = 12 * s / 100, bx = 22 * s / 100;
  const y1 = 31 * s / 100, y2 = 57 * s / 100;
  const bar = (y) => `M ${bx} ${y} H ${bx + bw} V ${y + bh} H ${bx} Z`;
  return `${outer} ${bar(y1)} ${bar(y2)}`;
}

const TEAL = '#0F6E64', TEAL_L = '#39B39F', INK = '#151C1E', PAPER = '#FFFFFF';

function svg(w, h, body, title) {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${r2(w)} ${r2(h)}" width="${r2(w)}" height="${r2(h)}" role="img" aria-label="${title}">
<title>${title}</title>
${body}
</svg>
`;
}
const r2 = n => Math.round(n * 100) / 100;

// ═══ pełny lockup: znak + MBS + deskryptor ═══
function primary(markColor, textColor) {
  const S = 100, gap = 26, tx = S + gap;
  const mbs = textPath(F800, 'MBS', 68, tx, 68, 0.03);
  const desc = textPath(F600, 'BUSINESS SOLUTIONS', 17, tx, 100, 0.16);
  const w = tx + Math.max(mbs.width, desc.width);
  const body =
    `<path d="${tile(S)}" fill="${markColor}" fill-rule="evenodd"/>\n` +
    `<path d="${mbs.d}" fill="${textColor}"/>\n` +
    `<path d="${desc.d}" fill="${textColor}" opacity="0.72"/>`;
  return svg(w, S, body, 'MBS Business Solutions');
}

// ═══ wersja zwarta: znak + MBS ═══
function compact(markColor, textColor) {
  const S = 100, gap = 24, tx = S + gap, capH = 62;
  const mbs = textPath(F800, 'MBS', capH, tx, (S - capH) / 2 + capH, 0.03);
  const body =
    `<path d="${tile(S)}" fill="${markColor}" fill-rule="evenodd"/>\n` +
    `<path d="${mbs.d}" fill="${textColor}"/>`;
  return svg(tx + mbs.width, S, body, 'MBS');
}

// ═══ sam znak ═══
function markOnly(color) {
  return svg(100, 100, `<path d="${tile(100)}" fill="${color}" fill-rule="evenodd"/>`, 'MBS');
}

const OUT = '/home/user/Jacek/marka/';
const files = {
  'mbs-kompakt-mono.svg':  compact('#000000', '#000000'),
  'mbs-logo.svg':          primary(TEAL, INK),        // podstawowa, na jasnym
  'mbs-logo-dark.svg':     primary(TEAL_L, PAPER),    // na ciemnym
  'mbs-logo-mono.svg':     primary('#000000', '#000000'),
  'mbs-logo-white.svg':    primary(PAPER, PAPER),
  'mbs-kompakt.svg':       compact(TEAL, INK),
  'mbs-kompakt-dark.svg':  compact(TEAL_L, PAPER),
  'mbs-znak.svg':          markOnly(TEAL),
  'mbs-znak-mono.svg':     markOnly('#000000'),
  'mbs-znak-white.svg':    markOnly(PAPER),
};
let bledy = 0;
for (const [n, c] of Object.entries(files)) {
  // kontrola, ktorej zabraklo poprzednio - zepsuty plik nie moze wyjsc z generatora
  // liczymy tylko w danych sciezek - slowo "MBS" w tytule i opisie tez zawiera M
  const dOnly = (c.match(/ d="[^"]*"/g) || []).join('');
  const nan = (dOnly.match(/NaN|undefined|Infinity/g) || []).length;
  const subs = (dOnly.match(/M/g) || []).length;
  const zamk = (dOnly.match(/Z/g) || []).length;
  const ok = nan === 0 && zamk === subs;
  if (!ok) bledy++;
  fs.writeFileSync(OUT + n, c);
  console.log((ok ? '  OK  ' : ' BLAD ') + n.padEnd(24) +
              String(c.length).padStart(6) + ' B  | podsciezek ' + String(subs).padStart(3) +
              ' | domkniec ' + String(zamk).padStart(3) + ' | NaN ' + nan);
}
if (bledy) { console.error('\nPLIKI Z BLEDAMI: ' + bledy); process.exit(1); }
console.log('\nWszystkie pliki poprawne.');
