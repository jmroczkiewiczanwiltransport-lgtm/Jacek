#!/usr/bin/env node
/* Generator kluczy licencyjnych. Uzycie: node tools/keygen.js [ile]
   Ten sam algorytm siedzi w src/app.js (funkcje fnv / sum4 / keyValid). */
var AL = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
var SALT = 'mbs-2ca34d3cea05d6b4c72f42c56ab5f1c794bfd1c9';

function fnv(s) {
  var h = 0x811c9dc5, i;
  for (i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 0x01000193) >>> 0; }
  return h >>> 0;
}
function sum4(payload) {
  var h = fnv(payload + '|' + SALT), o = '', i;
  for (i = 0; i < 4; i++) o += AL[(h >>> (i * 5)) & 31];
  return o;
}
function rnd(n) {
  var b = require('crypto').randomBytes(n), o = '', i;
  for (i = 0; i < n; i++) o += AL[b[i] % AL.length];
  return o;
}
function makeKey() {
  var body = rnd(8);
  return 'KSU-' + body.slice(0, 4) + '-' + body.slice(4, 8) + '-' + sum4(body);
}
function valid(raw) {
  var k = String(raw).toUpperCase().replace(/[^A-Z0-9]/g, '');
  if (k.indexOf('KSU') !== 0 || k.length !== 15) return false;
  var b = k.slice(3);
  return sum4(b.slice(0, 8)) === b.slice(8, 12);
}

/* Sol musi byc identyczna w aplikacji i w generatorze. Jesli sie rozjada, generator
   wypusci klucze, ktorych aplikacja nie przyjmie - i wyszlo by to dopiero u klienta.
   Dlatego sprawdzamy to przy kazdym uruchomieniu, zamiast liczyc na pamiec. */
(function checkSalt() {
  var fs = require('fs'), path = require('path');
  var appPath = path.join(__dirname, '..', 'src', 'app.js');
  var m;
  try {
    m = fs.readFileSync(appPath, 'utf8').match(/var SALT = '([^']*)';/);
  } catch (e) {
    console.error('OSTRZEZENIE: nie znaleziono ' + appPath + ' - nie sprawdzono zgodnosci soli.');
    return;
  }
  if (!m) {
    console.error('OSTRZEZENIE: nie odczytano soli z src/app.js - nie sprawdzono zgodnosci.');
    return;
  }
  if (m[1] !== SALT) {
    console.error('BLAD: sol w src/app.js rozni sie od soli w generatorze.');
    console.error('  aplikacja: ' + m[1]);
    console.error('  generator: ' + SALT);
    console.error('Klucze z tego generatora nie zostalyby przyjete. Ujednolic obie wartosci.');
    process.exit(1);
  }
})();

var arg = process.argv[2];
if (arg && !/^\d+$/.test(arg)) {
  console.log(arg + ' -> ' + (valid(arg) ? 'POPRAWNY' : 'NIEPOPRAWNY'));
} else {
  var n = parseInt(arg || '5', 10), i, k;
  for (i = 0; i < n; i++) { k = makeKey(); if (!valid(k)) throw new Error('blad generatora'); console.log(k); }
}
