const fs = require('fs');
const { chromium } = require('playwright-core');

const RANGE = {
  latin: "U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,U+0304,U+0308,U+0329,U+2000-206F,U+20AC,U+2122,U+2191-2193,U+2212,U+2215,U+FEFF,U+FFFD",
  'latin-ext': "U+0100-02BA,U+02BD-02C5,U+02C7-02CC,U+02CE-02D7,U+02DD-02FF,U+0304,U+0308,U+0329,U+1D00-1DBF,U+1E00-1E9F,U+1EF2-1EFF,U+2020,U+20A0-20AB,U+20AD-20C0,U+2113,U+2C60-2C7F,U+A720-A7FF"
};

const FACES = [
  ['Archivo', 'archivo', [400, 600, 700]],
  ['Source Sans 3', 'source-sans-3', [400, 600]],
  ['IBM Plex Mono', 'ibm-plex-mono', [400, 500]],
];

let css = '', total = 0;
for (const [family, pkg, weights] of FACES) {
  for (const w of weights) {
    for (const sub of ['latin', 'latin-ext']) {
      const f = `node_modules/@fontsource/${pkg}/files/${pkg}-${sub}-${w}-normal.woff2`;
      if (!fs.existsSync(f)) { console.log('BRAK:', f); continue; }
      const b = fs.readFileSync(f);
      total += b.length;
      css += `@font-face{font-family:"${family}";font-style:normal;font-weight:${w};font-display:block;` +
             `src:url(data:font/woff2;base64,${b.toString('base64')}) format("woff2");` +
             `unicode-range:${RANGE[sub]}}\n`;
    }
  }
}
console.log('osadzone kroje:', Math.round(total / 1024), 'KB');

let html = fs.readFileSync('/home/user/Jacek/dist/oferta.html', 'utf8');
const before = html.length;
// wywalamy pobieranie z sieci, wstawiamy kroje osadzone w pliku
html = html.replace(/<link rel="preconnect"[^>]*>\s*/g, '')
           .replace(/<link rel="stylesheet" href="https:\/\/fonts\.googleapis\.com[^>]*>\s*/g, '')
           .replace('<style>', '<style>\n' + css);
if (/fonts\.googleapis|preconnect/.test(html)) throw new Error('zostalo odwolanie do sieci');

// Arkusz tylko dla PDF - na ekranie strona zostaje bez zmian.
// Szerokosc A4 jest wezsza niz zalozenia ekranowe, wiec siatki trzeba przestawic recznie,
// a puste pola do uzupelnienia nie moga trafic do dokumentu wysylanego klientowi.
const PRINT = `
@media print {
  .prices { grid-template-columns: repeat(3, 1fr) !important; gap: .6rem !important; }
  .price { padding: .9rem !important; }
  .price .amt { font-size: 1.5rem !important; }
  .trust { grid-template-columns: repeat(2, 1fr) !important; gap: .6rem !important; }
  .dirs { grid-template-columns: repeat(2, 1fr) !important; gap: .6rem !important; }
  .card .li:has(.ph), .card .nm:has(.ph) { display: none !important; }
  .hook { padding: 1rem 1.2rem !important; }
  section { margin-top: 1rem !important; }
  .sheet { padding-bottom: 0 !important; }
  .fine { margin-top: 1rem !important; }
  .close { margin-top: 1.5rem !important; padding-top: 1rem !important; }
}`;
html = html.replace('</style>', PRINT + '\n</style>');
console.log('rozmiar HTML:', Math.round(before/1024), 'KB ->', Math.round(html.length/1024), 'KB');
fs.writeFileSync('oferta-druk.html', html);

(async () => {
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
  const p = await b.newPage();
  const errs = []; p.on('pageerror', e => errs.push(e.message));
  await p.goto('file:///' + process.cwd() + '/oferta-druk.html');
  await p.emulateMedia({ media: 'print', colorScheme: 'light' });
  await p.waitForTimeout(900);

  // kontrola: czy krój faktycznie sie zaladowal, a nie zastepczy
  const ok = await p.evaluate(async () => {
    await document.fonts.ready;
    return { wczytane: document.fonts.size, archivo: document.fonts.check('700 24px Archivo') };
  });
  console.log('kroje w dokumencie:', ok.wczytane, '| Archivo dostepny:', ok.archivo);

  await p.pdf({
    path: '/home/user/Jacek/dist/MBS-oferta-KSeF.pdf',
    format: 'A4', printBackground: true,
    margin: { top: '14mm', bottom: '14mm', left: '13mm', right: '13mm' }
  });
  console.log('bledy:', errs.length ? errs.join(';') : 'brak');
  const pdf = fs.readFileSync('/home/user/Jacek/dist/MBS-oferta-KSeF.pdf');
  const stron = (pdf.toString('latin1').match(/\/Type\s*\/Page[^s]/g) || []).length;
  const zastepcze = [...new Set((pdf.toString('latin1').match(/\/BaseFont\s*\/[A-Z]{6}\+([A-Za-z0-9\-]+)/g) || [])
    .map(x => x.split('+')[1]))].filter(f => !/Archivo|SourceSans|IBMPlex/.test(f));
  console.log('stron:', stron, '| kroje zastepcze:', zastepcze.length ? zastepcze.join(', ') : 'brak');
  await b.close();
})();
