const { chromium } = require('playwright-core');
const fs = require('fs');
const M = '/home/user/Jacek/marka/';

const JOBS = [
  ['mbs-logo.svg',       'mbs-logo-40.png',   40],
  ['mbs-logo.svg',       'mbs-logo-80.png',   80],
  ['mbs-logo.svg',       'mbs-logo-160.png',  160],
  ['mbs-logo-dark.svg',  'mbs-logo-dark-80.png', 80],
  ['mbs-logo-mono.svg',  'mbs-logo-mono-80.png', 80],
  ['mbs-znak.svg',       'mbs-znak-512.png',  512],
  ['mbs-znak.svg',       'mbs-znak-256.png',  256],
  ['mbs-znak.svg',       'mbs-znak-64.png',   64],
  ['mbs-znak.svg',       'mbs-znak-32.png',   32],
];

(async () => {
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
  for (const [src, out, h] of JOBS) {
    const svg = fs.readFileSync(M + src, 'utf8');
    const vb = svg.match(/viewBox="0 0 ([\d.]+) ([\d.]+)"/);
    const w = Math.round(h * parseFloat(vb[1]) / parseFloat(vb[2]));
    const p = await b.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 2 });
    await p.setContent(`<style>html,body{margin:0;padding:0;background:transparent}svg{display:block;width:${w}px;height:${h}px}</style>` + svg);
    await p.waitForTimeout(120);
    await p.screenshot({ path: M + out, omitBackground: true });
    console.log(out.padEnd(24), w + 'x' + h, '(2x =', w*2 + 'x' + h*2 + ')', fs.statSync(M + out).size + ' B');
    await p.close();
  }
  await b.close();
})();
