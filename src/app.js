/* KSeF Uzgodnienia — logika aplikacji. Wszystko dzieje sie lokalnie, zero wysylki na serwer. */
(function () {
  'use strict';

  /* ---------- stale i funkcje pomocnicze ---------- */

  var KSEF_FMT = /^\d{10}-\d{8}-[0-9A-F]{12}-[0-9A-F]{2}$/i;
  var FREE_ROWS = 100;
  var AL = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  var SALT = 'ksef-uzgodnienia-v1';
  var MAX_RENDER = 500;

  var PAT = {
    nip: /\bnip\b|identyfikator\s*(sprzedawcy|nabywcy|podmiotu)|nr\s*ident|tax\s*id|vat\s*id/i,
    inv: /nr\s*fakt|numer\s*fakt|nr\s*dokument|numer\s*dokument|invoice\s*(nr|no|number)|supplier\s*invoice|\bnr\s*fv\b|\bfaktura\b|dokument\s*zakupu/i,
    ksef: /ksef/i
  };

  function txt(v) { return v === null || v === undefined ? '' : String(v).trim(); }
  function normInv(v) { return txt(v).toUpperCase().replace(/\s+/g, ''); }
  function alnum(v) { return txt(v).toUpperCase().replace(/[^A-Z0-9]/g, ''); }
  function normNip(v) { return txt(v).replace(/\D/g, ''); }
  function colLetter(i) { var s = ''; i++; while (i > 0) { var m = (i - 1) % 26; s = String.fromCharCode(65 + m) + s; i = (i - m - 1) / 26; } return s; }
  function esc(s) { return txt(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;'); }
  function uniq(a) { var seen = {}, out = [], i; for (i = 0; i < a.length; i++) { if (!seen[a[i]]) { seen[a[i]] = 1; out.push(a[i]); } } return out; }
  function $(id) { return document.getElementById(id); }
  function plural(n, one, few, many) {
    n = Math.abs(n);
    if (n === 1) return one;
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) return few;
    return many;
  }

  /* ---------- licencja ---------- */

  function fnv(s) { var h = 0x811c9dc5, i; for (i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 0x01000193) >>> 0; } return h >>> 0; }
  function sum4(payload) { var h = fnv(payload + '|' + SALT), o = '', i; for (i = 0; i < 4; i++) { o += AL[(h >>> (i * 5)) & 31]; } return o; }
  function keyValid(raw) {
    var k = txt(raw).toUpperCase().replace(/[^A-Z0-9]/g, '');
    if (k.indexOf('KSU') !== 0 || k.length !== 15) return false;
    var body = k.slice(3);
    return sum4(body.slice(0, 8)) === body.slice(8, 12);
  }

  var S = {
    licensed: false,
    files: { A: null, B: null },
    ksefRef: null,
    regRef: null,
    result: null
  };

  try { S.licensed = keyValid(localStorage.getItem('ksefu.key') || ''); } catch (e) { S.licensed = false; }

  function paintLicense() {
    var el = $('licState');
    el.textContent = S.licensed ? 'Licencja aktywna' : 'Wersja demonstracyjna — eksport do ' + FREE_ROWS + ' wierszy';
    el.className = 'lic-state' + (S.licensed ? ' on' : '');
  }

  /* ---------- wczytywanie plikow uzytkownika ---------- */

  function readFile(file) {
    return new Promise(function (res, rej) {
      var fr = new FileReader();
      fr.onerror = function () { rej(new Error('Nie udało się odczytać pliku.')); };
      fr.onload = function () {
        try {
          var wb = XLSX.read(new Uint8Array(fr.result), { type: 'array', cellFormula: true, cellStyles: false, raw: true });
          if (!wb.SheetNames.length) throw new Error('brak arkuszy');
          res({ name: file.name, size: file.size, wb: wb });
        } catch (e) {
          rej(new Error('Nie udało się otworzyć „' + file.name + '”. Czy to na pewno arkusz Excela lub CSV?'));
        }
      };
      fr.readAsArrayBuffer(file);
    });
  }

  /* Arkusz moze miec pusty margines na gorze albo z lewej - wtedy SheetJS liczy
     wiersze od pierwszego uzytego, a nie od pierwszego w pliku. Wymuszamy zakres
     od A1, zeby indeks tablicy zawsze odpowiadal numerowi wiersza w Excelu. */
  function aoaOf(wb, sheetName) {
    var ws = wb.Sheets[sheetName];
    if (!ws) return [];
    var opts = { header: 1, raw: true, defval: null, blankrows: true };
    if (ws['!ref']) {
      var rng = XLSX.utils.decode_range(ws['!ref']);
      rng.s.r = 0;
      rng.s.c = 0;
      opts.range = XLSX.utils.encode_range(rng);
    }
    return XLSX.utils.sheet_to_json(ws, opts);
  }

  function hasFormulas(wb, sheetName) {
    var ws = wb.Sheets[sheetName], a;
    if (!ws) return false;
    for (a in ws) { if (a.charAt(0) !== '!' && ws[a] && ws[a].f) return true; }
    return false;
  }

  /* ---------- automatyczne rozpoznawanie ---------- */

  function ksefScoreOfSheet(aoa) {
    var best = 0, cols = 0, i, r, c;
    for (i = 0; i < Math.min(aoa.length, 400); i++) cols = Math.max(cols, (aoa[i] || []).length);
    for (c = 0; c < cols; c++) {
      var hit = 0, tot = 0;
      for (r = 0; r < Math.min(aoa.length, 400); r++) {
        var v = txt((aoa[r] || [])[c]);
        if (!v) continue;
        tot++;
        if (KSEF_FMT.test(v)) hit++;
      }
      if (tot >= 3 && hit / tot > best) best = hit / tot;
    }
    return best;
  }

  function pickSheet(wb) {
    if (wb.SheetNames.indexOf('Supplier data') >= 0) return 'Supplier data';
    var best = wb.SheetNames[0], bestN = -1;
    wb.SheetNames.forEach(function (n) {
      var ws = wb.Sheets[n];
      if (!ws || !ws['!ref']) return;
      var rng = XLSX.utils.decode_range(ws['!ref']);
      var size = (rng.e.r - rng.s.r) * Math.max(1, rng.e.c - rng.s.c + 1);
      if (size > bestN) { bestN = size; best = n; }
    });
    return best;
  }

  function detectHeaderRow(aoa) {
    var best = 1, bestScore = -1, r, c;
    for (r = 0; r < Math.min(aoa.length, 25); r++) {
      var row = aoa[r] || [], sc = 0, filled = 0;
      for (c = 0; c < row.length; c++) {
        var v = txt(row[c]);
        if (!v) continue;
        filled++;
        if (PAT.nip.test(v)) sc += 3;
        if (PAT.inv.test(v)) sc += 3;
        if (PAT.ksef.test(v)) sc += 3;
      }
      if (filled >= 2) sc += 1;
      if (sc > bestScore) { bestScore = sc; best = r + 1; }
    }
    return bestScore > 1 ? best : 1;
  }

  function guessCols(aoa, headerRow, kind) {
    var hdr = aoa[headerRow - 1] || [], cols = 0, i;
    for (i = 0; i < aoa.length; i++) cols = Math.max(cols, (aoa[i] || []).length);

    function byHeader(pat, skip) {
      var c;
      for (c = 0; c < cols; c++) {
        if (skip !== undefined && c === skip) continue;
        if (pat.test(txt(hdr[c]))) return c;
      }
      return -1;
    }
    function ratio(c, test) {
      var hit = 0, tot = 0, r;
      for (r = headerRow; r < Math.min(aoa.length, headerRow + 400); r++) {
        var v = txt((aoa[r] || [])[c]);
        if (!v) continue;
        tot++;
        if (test(v)) hit++;
      }
      return tot >= 3 ? hit / tot : 0;
    }
    function isKsef(v) { return KSEF_FMT.test(v); }
    function isNip(v) { return normNip(v).length === 10 && !KSEF_FMT.test(v); }

    var cands = [];
    for (i = 0; i < cols; i++) {
      var isH = PAT.ksef.test(txt(hdr[i]));
      var rt = ratio(i, isKsef);
      if (isH || rt > 0.3) cands.push({ c: i, s: (isH ? 1 : 0) + rt * 2 });
    }
    cands.sort(function (a, b) { return b.s - a.s; });
    var kc = cands.length ? cands[0].c : -1;

    var nc = byHeader(PAT.nip, kc);
    if (nc < 0) {
      var bn = -1, bs = 0;
      for (i = 0; i < cols; i++) {
        if (i === kc) continue;
        var rn = ratio(i, isNip);
        if (rn > bs && rn > 0.6) { bs = rn; bn = i; }
      }
      nc = bn;
    }

    var ic = byHeader(PAT.inv, kc);
    if (ic < 0) {
      var bi = -1, bsc = 0, r, seen, tot, dist, v;
      for (i = 0; i < cols; i++) {
        if (i === kc || i === nc) continue;
        seen = {}; tot = 0; dist = 0;
        for (r = headerRow; r < Math.min(aoa.length, headerRow + 300); r++) {
          v = txt((aoa[r] || [])[i]);
          if (!v || v.length < 3) continue;
          tot++;
          if (!seen[v]) { seen[v] = 1; dist++; }
        }
        if (tot >= 3 && dist / tot > bsc) { bsc = dist / tot; bi = i; }
      }
      if (bsc > 0.7) ic = bi;
    }

    var fc = -1;
    if (kind === 'reg') {
      for (i = 0; i < cols; i++) {
        if (i !== kc && /ksef3\b|flag|typ\b|rodzaj/i.test(txt(hdr[i]))) { fc = i; break; }
      }
    }

    return { nip: nc, inv: ic, ksef: kc, flag: fc, cols: cols, guessed: { nip: nc >= 0, inv: ic >= 0, ksef: kc >= 0, flag: fc >= 0 } };
  }

  function buildRef(file, kind) {
    var sheet = kind === 'reg' ? pickSheet(file.wb) : file.wb.SheetNames[0];
    var aoa = aoaOf(file.wb, sheet);
    var hr = detectHeaderRow(aoa);
    return { file: file, kind: kind, sheet: sheet, aoa: aoa, headerRow: hr, map: guessCols(aoa, hr, kind) };
  }

  function classifyPair(a, b) {
    var aSup = a.wb.SheetNames.indexOf('Supplier data') >= 0;
    var bSup = b.wb.SheetNames.indexOf('Supplier data') >= 0;
    if (aSup && !bSup) return { ksef: b, reg: a };
    if (bSup && !aSup) return { ksef: a, reg: b };
    var sa = ksefScoreOfSheet(aoaOf(a.wb, a.wb.SheetNames[0]));
    var sb = ksefScoreOfSheet(aoaOf(b.wb, b.wb.SheetNames[0]));
    return sa >= sb ? { ksef: a, reg: b } : { ksef: b, reg: a };
  }

  /* ---------- uzgodnienie ---------- */

  function reconcile(ksefRef, regRef) {
    var km = {}, am = {}, byNip = {}, ksefSet = {}, ksefRows = [];
    var K = ksefRef.map, R = regRef.map;
    var r, row, nip, inv, num, key;

    for (r = ksefRef.headerRow; r < ksefRef.aoa.length; r++) {
      row = ksefRef.aoa[r] || [];
      num = txt(row[K.ksef]);
      if (!num) continue;
      nip = normNip(row[K.nip]);
      inv = row[K.inv];
      ksefSet[num] = 1;
      ksefRows.push({ excel: r + 1, nip: nip, nipRaw: txt(row[K.nip]), inv: txt(inv), num: num });
      key = nip + ' ' + normInv(inv);
      (km[key] = km[key] || []).push(num);
      key = nip + ' ' + alnum(inv);
      (am[key] = am[key] || []).push(num);
      (byNip[nip] = byNip[nip] || []).push([alnum(inv), num]);
    }

    var out = {
      filled: [], corrections: [], unclear: [], ok: [], unmatched: [], onlyKsef: [],
      stats: { rows: 0, ksefRows: ksefRows.length, ok: 0, okAlt: 0, exact: 0, fuzzy: 0, corr: 0, unclear: 0, ambig: 0, none: 0 },
      firstDataRow: regRef.headerRow + 1,
      lastDataRow: regRef.headerRow,
      fillByRow: {},
      used: {}
    };

    for (r = regRef.headerRow; r < regRef.aoa.length; r++) {
      row = regRef.aoa[r] || [];
      var invRaw = txt(row[R.inv]), nipRaw = txt(row[R.nip]), cur = txt(row[R.ksef]);
      var flag = R.flag >= 0 ? txt(row[R.flag]) : '';
      if (!invRaw && !nipRaw && !cur) continue;

      var excel = r + 1;
      out.lastDataRow = excel;
      out.stats.rows++;
      nip = normNip(nipRaw);
      var exact = uniq(km[nip + ' ' + normInv(invRaw)] || []);
      var base = { excel: excel, nip: nipRaw, inv: invRaw };

      if (cur) {
        if (exact.length) {
          if (exact.indexOf(cur) >= 0) {
            out.stats.ok++;
            out.used[cur] = 1;
            out.ok.push({ excel: excel, nip: nipRaw, inv: invRaw, num: cur, note: 'zgodny z KSeF' });
          } else {
            out.stats.corr++;
            out.used[exact[0]] = 1;
            out.corrections.push({ excel: excel, nip: nipRaw, inv: invRaw, was: cur, num: exact[0] });
            out.fillByRow[excel] = exact[0];
          }
        } else if (ksefSet[cur]) {
          out.stats.okAlt++;
          out.used[cur] = 1;
          out.ok.push({ excel: excel, nip: nipRaw, inv: invRaw, num: cur, note: 'numer istnieje w KSeF, inna pisownia nr faktury' });
        } else {
          var note = 'numeru nie ma w pliku KSeF';
          if (!KSEF_FMT.test(cur)) note += ' — niepoprawny format';
          else if (nip && cur.slice(0, 10) !== nip) note += ' — NIP w numerze KSeF inny niż NIP dostawcy';
          out.stats.unclear++;
          out.unclear.push({ excel: excel, nip: nipRaw, inv: invRaw, was: cur, note: note });
        }
      } else if (exact.length === 1) {
        out.stats.exact++;
        out.used[exact[0]] = 1;
        out.filled.push({ excel: excel, nip: nipRaw, inv: invRaw, num: exact[0], how: 'dokładne', approx: false });
        out.fillByRow[excel] = exact[0];
      } else if (exact.length > 1) {
        out.stats.ambig++;
        /* Faktura jest w rejestrze - problem jest w KSeF (kilka numerow na ten sam
           klucz). Oznaczamy wszystkie kandydatury jako odnalezione, zeby nie
           trafily do zestawienia "brak w rejestrze". */
        exact.forEach(function (n) { out.used[n] = 1; });
        out.unmatched.push({ excel: excel, nip: nipRaw, inv: invRaw, flag: flag, note: 'niejednoznaczne: ' + exact.join(' | ') });
      } else {
        var m = uniq(am[nip + ' ' + alnum(invRaw)] || []);
        if (!m.length) {
          var a2 = alnum(invRaw), lst = byNip[nip] || [], acc = [], q;
          if (a2) {
            for (q = 0; q < lst.length; q++) {
              var ki = lst[q][0];
              if (ki && (a2.indexOf(ki) >= 0 || ki.indexOf(a2) >= 0)) acc.push(lst[q][1]);
            }
          }
          m = uniq(acc);
        }
        if (m.length === 1) {
          out.stats.fuzzy++;
          out.used[m[0]] = 1;
          out.filled.push({ excel: excel, nip: nipRaw, inv: invRaw, num: m[0], how: 'przybliżone — sprawdź', approx: true });
          out.fillByRow[excel] = m[0];
        } else {
          out.stats.none++;
          if (m.length > 1) m.forEach(function (n) { out.used[n] = 1; });
          out.unmatched.push({ excel: excel, nip: nipRaw, inv: invRaw, flag: flag, note: m.length > 1 ? 'kilku kandydatów: ' + m.join(' | ') : '' });
        }
      }
    }

    var seenNum = {}, i, kr;
    for (i = 0; i < ksefRows.length; i++) {
      kr = ksefRows[i];
      if (out.used[kr.num] || seenNum[kr.num]) continue;
      seenNum[kr.num] = 1;
      out.onlyKsef.push(kr);
    }
    return out;
  }

  /* ---------- kroki ---------- */

  function goStep(n) {
    [1, 2, 3].forEach(function (i) {
      $('tab-' + i).setAttribute('aria-selected', i === n ? 'true' : 'false');
      $('panel-' + i).hidden = i !== n;
    });
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }
  function enableStep(n, on) { $('tab-' + n).disabled = !on; }

  [1, 2, 3].forEach(function (i) {
    $('tab-' + i).addEventListener('click', function () { if (!this.disabled) goStep(i); });
  });

  /* ---------- etap 1 ---------- */

  function paintDrop(slot) {
    var d = $('drop-' + slot), f = S.files[slot];
    var nameEl = d.querySelector('.hint') || d.querySelector('.fname');
    var meta = d.querySelector('.fmeta');
    if (!f) {
      d.className = 'drop';
      d.querySelector('.role').textContent = slot === 'A' ? 'Plik pierwszy' : 'Plik drugi';
      nameEl.className = 'hint';
      nameEl.textContent = 'Przeciągnij tutaj albo kliknij, żeby wybrać';
      if (meta) meta.remove();
      return;
    }
    d.className = 'drop loaded';
    d.querySelector('.role').textContent = f.role || 'Wczytany';
    nameEl.className = 'fname';
    nameEl.textContent = f.name;
    if (!meta) { meta = document.createElement('span'); meta.className = 'fmeta'; d.appendChild(meta); }
    meta.textContent = f.wb.SheetNames.length + ' ' + plural(f.wb.SheetNames.length, 'arkusz', 'arkusze', 'arkuszy') + ' · ' + Math.round(f.size / 1024) + ' KB';
  }

  function afterLoad() {
    var a = S.files.A, b = S.files.B;
    $('reset1').hidden = !(a || b);
    if (!(a && b)) {
      $('goMap').disabled = true;
      $('detect1').innerHTML = '';
      paintDrop('A'); paintDrop('B');
      return;
    }
    var c = classifyPair(a, b);
    S.ksefRef = buildRef(c.ksef, 'ksef');
    S.regRef = buildRef(c.reg, 'reg');
    c.ksef.role = 'Eksport z KSeF';
    c.reg.role = 'Twój rejestr';
    paintDrop('A'); paintDrop('B');
    var okK = S.ksefRef.map.ksef >= 0 && S.ksefRef.map.nip >= 0 && S.ksefRef.map.inv >= 0;
    $('detect1').innerHTML =
      '<div class="callout' + (okK ? '' : ' is-warning') + '">' +
      '<strong>' + (okK ? 'Pliki rozpoznane' : 'Pliki rozpoznane, ale kolumny wymagają sprawdzenia') + '</strong>' +
      '<span><span class="mono">' + esc(c.ksef.name) + '</span> → eksport z KSeF &nbsp;·&nbsp; <span class="mono">' + esc(c.reg.name) + '</span> → rejestr' +
      (okK ? '' : ' — nie wszystkie kolumny udało się rozpoznać, wskaż je w następnym kroku.') +
      '</span></div>';
    $('goMap').disabled = false;
    enableStep(2, true);
  }

  function handleFiles(slot, fileList) {
    var files = Array.prototype.slice.call(fileList || []);
    if (!files.length) return;
    $('busy1').innerHTML = '<span class="busy"><span class="spin"></span>Czytam...</span>';
    var slots = files.length >= 2 ? ['A', 'B'] : [slot];
    Promise.all(files.slice(0, 2).map(readFile)).then(function (res) {
      res.forEach(function (f, i) { S.files[slots[i]] = f; });
      $('busy1').innerHTML = '';
      afterLoad();
    })['catch'](function (e) {
      $('busy1').innerHTML = '';
      $('detect1').innerHTML = '<div class="callout is-critical"><strong>Nie udało się wczytać</strong><span>' + esc(e.message) + '</span></div>';
    });
  }

  ['A', 'B'].forEach(function (slot) {
    var d = $('drop-' + slot);
    d.querySelector('input[type=file]').addEventListener('change', function () { handleFiles(slot, this.files); });
    ['dragenter', 'dragover'].forEach(function (ev) {
      d.addEventListener(ev, function (e) { e.preventDefault(); d.classList.add('over'); });
    });
    ['dragleave', 'drop'].forEach(function (ev) {
      d.addEventListener(ev, function (e) { e.preventDefault(); d.classList.remove('over'); });
    });
    d.addEventListener('drop', function (e) { handleFiles(slot, e.dataTransfer.files); });
  });

  $('reset1').addEventListener('click', function () {
    S.files = { A: null, B: null };
    S.ksefRef = S.regRef = S.result = null;
    enableStep(2, false);
    enableStep(3, false);
    ['A', 'B'].forEach(function (s) {
      var i = $('drop-' + s).querySelector('input[type=file]');
      if (i) i.value = '';
    });
    afterLoad();
  });

  $('goMap').addEventListener('click', function () { renderMapping(); goStep(2); });
  $('back1').addEventListener('click', function () { goStep(1); });
  $('swapFiles').addEventListener('click', function () {
    if (!S.ksefRef || !S.regRef) return;
    var oldKsef = S.ksefRef.file, oldReg = S.regRef.file;
    S.ksefRef = buildRef(oldReg, 'ksef');
    S.regRef = buildRef(oldKsef, 'reg');
    S.ksefRef.file.role = 'Eksport z KSeF';
    S.regRef.file.role = 'Twój rejestr';
    paintDrop('A'); paintDrop('B'); renderMapping();
  });

  /* ---------- etap 2 ---------- */

  function colOptions(ref, sel) {
    var hdr = ref.aoa[ref.headerRow - 1] || [], o = '<option value="-1">— nie ma takiej kolumny —</option>', c;
    for (c = 0; c < ref.map.cols; c++) {
      var h = txt(hdr[c]);
      o += '<option value="' + c + '"' + (c === sel ? ' selected' : '') + '>' + colLetter(c) + (h ? ' · ' + esc(h.slice(0, 40)) : '') + '</option>';
    }
    return o;
  }

  function mapCard(ref, title, fields) {
    var h = '<div class="mapcard"><header><span class="which">' + title + '</span><span class="src">' +
      esc(ref.file.name) + ' › ' + esc(ref.sheet) + '</span></header><div class="mapbody">';
    h += '<div class="field"><span>Arkusz</span><select data-ref="' + ref.kind + '" data-k="sheet">' +
      ref.file.wb.SheetNames.map(function (n) {
        return '<option' + (n === ref.sheet ? ' selected' : '') + '>' + esc(n) + '</option>';
      }).join('') + '</select></div>';
    h += '<div class="field"><span>Wiersz z nagłówkami</span><input type="number" min="1" value="' + ref.headerRow +
      '" data-ref="' + ref.kind + '" data-k="headerRow"></div>';
    fields.forEach(function (f) {
      h += '<div class="field"><span>' + f.label +
        (ref.map.guessed[f.k] ? ' <span class="guessed">rozpoznane</span>' : '') +
        (f.note ? ' <span class="note">' + f.note + '</span>' : '') + '</span>' +
        '<select data-ref="' + ref.kind + '" data-k="' + f.k + '">' + colOptions(ref, ref.map[f.k]) + '</select></div>';
    });
    return h + '</div></div>';
  }

  function renderMapping() {
    $('mapgrid').innerHTML =
      mapCard(S.ksefRef, 'Eksport z KSeF', [
        { k: 'nip', label: 'NIP sprzedawcy' },
        { k: 'inv', label: 'Numer faktury' },
        { k: 'ksef', label: 'Numer KSeF' }
      ]) +
      mapCard(S.regRef, 'Twój rejestr', [
        { k: 'nip', label: 'NIP dostawcy' },
        { k: 'inv', label: 'Numer faktury' },
        { k: 'ksef', label: 'Kolumna na numer KSeF', note: '— tu program wpisuje wynik' },
        { k: 'flag', label: 'Kolumna z flagą', note: '— opcjonalnie, np. BFK/DI' }
      ]);

    Array.prototype.forEach.call($('mapgrid').querySelectorAll('select,input'), function (el) {
      el.addEventListener('change', function () {
        var ref = this.getAttribute('data-ref') === 'ksef' ? S.ksefRef : S.regRef;
        var k = this.getAttribute('data-k');
        if (k === 'sheet') {
          ref.sheet = this.value;
          ref.aoa = aoaOf(ref.file.wb, ref.sheet);
          ref.headerRow = detectHeaderRow(ref.aoa);
          ref.map = guessCols(ref.aoa, ref.headerRow, ref.kind);
          renderMapping();
          return;
        }
        if (k === 'headerRow') {
          ref.headerRow = Math.max(1, parseInt(this.value, 10) || 1);
          ref.map = guessCols(ref.aoa, ref.headerRow, ref.kind);
          renderMapping();
          return;
        }
        ref.map[k] = parseInt(this.value, 10);
        ref.map.guessed[k] = false;
        validateMap();
        renderPreview();
      });
    });
    validateMap();
    renderPreview();
  }

  function validateMap() {
    var K = S.ksefRef.map, R = S.regRef.map, bad = [];
    if (K.nip < 0 || K.inv < 0 || K.ksef < 0) bad.push('W eksporcie z KSeF muszą być wskazane wszystkie trzy kolumny: NIP, numer faktury i numer KSeF.');
    if (R.nip < 0 || R.inv < 0) bad.push('W rejestrze muszą być wskazane kolumny NIP i numer faktury.');
    if (R.ksef < 0) bad.push('W rejestrze wskaż kolumnę, w której mają wylądować numery KSeF.');
    $('mapWarn').innerHTML = bad.length
      ? '<div class="callout is-warning"><strong>Brakuje przypisania</strong><span>' + bad.map(esc).join('<br>') + '</span></div>'
      : '';
    $('goRun').disabled = bad.length > 0;
    return !bad.length;
  }

  function renderPreview() {
    var ref = S.regRef, hdr = ref.aoa[ref.headerRow - 1] || [], m = ref.map, tag = {}, c, r;
    tag[m.nip] = 'NIP'; tag[m.inv] = 'Faktura'; tag[m.ksef] = 'KSeF';
    if (m.flag >= 0) tag[m.flag] = 'Flaga';
    var cols = Math.min(m.cols, 14);
    var h = '<table><thead><tr><th></th>';
    for (c = 0; c < cols; c++) h += '<th>' + colLetter(c) + (tag[c] ? ' · ' + tag[c] : '') + '</th>';
    h += '</tr></thead><tbody>';
    var start = Math.max(0, ref.headerRow - 1);
    for (r = start; r < Math.min(ref.aoa.length, start + 7); r++) {
      h += '<tr' + (r === ref.headerRow - 1 ? ' class="hdr"' : '') + '><td class="rn">' + (r + 1) + '</td>';
      for (c = 0; c < cols; c++) h += '<td>' + esc(txt((ref.aoa[r] || [])[c]).slice(0, 60)) + '</td>';
      h += '</tr>';
    }
    $('previewReg').innerHTML = h + '</tbody></table>';
  }

  $('goRun').addEventListener('click', function () {
    if (!validateMap()) return;
    $('busy2').innerHTML = '<span class="busy"><span class="spin"></span>Uzgadniam...</span>';
    setTimeout(function () {
      try {
        S.result = reconcile(S.ksefRef, S.regRef);
        $('busy2').innerHTML = '';
        enableStep(3, true);
        renderResult();
        goStep(3);
      } catch (e) {
        $('busy2').innerHTML = '';
        $('mapWarn').innerHTML = '<div class="callout is-critical"><strong>Uzgodnienie się nie udało</strong><span>' + esc(e.message) + '</span></div>';
      }
    }, 30);
  });

  /* ---------- etap 3 ---------- */

  var CATS = [
    {
      id: 'corrections', name: 'Korekty', sig: 'critical',
      cols: ['Wiersz', 'NIP', 'Nr faktury', 'Wpisany numer', 'Poprawny numer'],
      row: function (x) {
        return '<td class="r">' + x.excel + '</td><td class="k">' + esc(x.nip) + '</td><td class="wide">' + esc(x.inv) +
          '</td><td class="was">' + esc(x.was) + '</td><td class="now">' + esc(x.num) + '</td>';
      },
      empty: 'Brak korekt — wszystkie wpisane numery zgadzają się z KSeF.'
    },
    {
      id: 'onlyKsef', name: 'W KSeF, brak w rejestrze', sig: 'info',
      cols: ['Wiersz KSeF', 'NIP', 'Nr faktury', 'Numer KSeF'],
      row: function (x) {
        return '<td class="r">' + x.excel + '</td><td class="k">' + esc(x.nipRaw || x.nip) + '</td><td class="wide">' +
          esc(x.inv) + '</td><td class="k">' + esc(x.num) + '</td>';
      },
      empty: 'Każda faktura z KSeF ma odpowiednik w rejestrze.'
    },
    {
      id: 'filled', name: 'Uzupełnione', sig: 'good',
      cols: ['Wiersz', 'NIP', 'Nr faktury', 'Wpisany numer KSeF', 'Dopasowanie'],
      row: function (x) {
        return '<td class="r">' + x.excel + '</td><td class="k">' + esc(x.nip) + '</td><td class="wide">' + esc(x.inv) +
          '</td><td class="now">' + esc(x.num) + '</td><td><span class="pill ' + (x.approx ? 'warning' : 'good') + '">' + esc(x.how) + '</span></td>';
      },
      empty: 'Nie było czego uzupełniać.'
    },
    {
      id: 'unclear', name: 'Do wyjaśnienia', sig: 'warning',
      cols: ['Wiersz', 'NIP', 'Nr faktury', 'Wpisany numer', 'Uwaga'],
      row: function (x) {
        return '<td class="r">' + x.excel + '</td><td class="k">' + esc(x.nip) + '</td><td class="wide">' + esc(x.inv) +
          '</td><td class="k">' + esc(x.was) + '</td><td>' + esc(x.note) + '</td>';
      },
      empty: 'Nie ma numerów budzących wątpliwości.'
    },
    {
      id: 'unmatched', name: 'Bez dopasowania', sig: '',
      cols: ['Wiersz', 'NIP', 'Nr faktury', 'Flaga', 'Uwaga'],
      row: function (x) {
        return '<td class="r">' + x.excel + '</td><td class="k">' + esc(x.nip) + '</td><td class="wide">' + esc(x.inv) +
          '</td><td>' + esc(x.flag || '') + '</td><td>' + esc(x.note || '') + '</td>';
      },
      empty: 'Wszystkie pozycje rejestru zostały dopasowane.'
    },
    {
      id: 'ok', name: 'Zgodne', sig: 'good',
      cols: ['Wiersz', 'NIP', 'Nr faktury', 'Numer KSeF', 'Uwaga'],
      row: function (x) {
        return '<td class="r">' + x.excel + '</td><td class="k">' + esc(x.nip) + '</td><td class="wide">' + esc(x.inv) +
          '</td><td class="k">' + esc(x.num) + '</td><td>' + esc(x.note) + '</td>';
      },
      empty: 'Brak wcześniej wpisanych numerów.'
    }
  ];

  var activeCat = 'corrections';

  function renderResult() {
    var R = S.result, st = R.stats;

    $('runMeta').textContent = 'Rejestr: ' + st.rows + ' ' + plural(st.rows, 'wiersz', 'wiersze', 'wierszy') +
      ' (wiersze ' + R.firstDataRow + '–' + R.lastDataRow + ') · Eksport z KSeF: ' + st.ksefRows + ' ' +
      plural(st.ksefRows, 'faktura', 'faktury', 'faktur');

    var tiles = [
      { v: st.exact + st.fuzzy, k: st.fuzzy ? 'Uzupełnione numery — w tym ' + st.fuzzy + ' przybliżone' : 'Uzupełnione numery', c: 'is-good' },
      { v: st.corr, k: 'Korekty — błędny numer', c: 'is-critical' },
      { v: R.onlyKsef.length, k: 'W KSeF, brak w rejestrze', c: 'is-info' },
      { v: st.unclear, k: 'Do wyjaśnienia', c: 'is-warning' },
      { v: st.none + st.ambig, k: 'Bez dopasowania', c: '' },
      { v: st.ok + st.okAlt, k: 'Już zgodne', c: '' }
    ];
    $('tiles').innerHTML = tiles.map(function (t) {
      return '<div class="tile ' + t.c + '"><span class="v">' + t.v + '</span><span class="k">' + t.k + '</span></div>';
    }).join('');

    var hl = [];
    if (st.corr) {
      hl.push('<div class="callout is-critical"><strong>' + st.corr + ' ' +
        plural(st.corr, 'błędny numer KSeF', 'błędne numery KSeF', 'błędnych numerów KSeF') +
        ' w rejestrze</strong><span>Plik z KSeF jest źródłem prawdy, więc te numery są nieprawidłowe. Popraw je również w programie księgowym — inaczej wrócą przy następnym eksporcie.</span></div>');
    }
    if (R.onlyKsef.length) {
      hl.push('<div class="callout is-info"><strong>' + R.onlyKsef.length + ' ' +
        plural(R.onlyKsef.length, 'faktura z KSeF nie ma', 'faktury z KSeF nie mają', 'faktur z KSeF nie ma') +
        ' odpowiednika w rejestrze</strong><span>Każda z nich to potencjalnie nieodliczony VAT i niezaksięgowany koszt. Sprawdź je przed zamknięciem miesiąca.</span></div>');
    }
    if (st.fuzzy) {
      hl.push('<div class="callout is-warning"><strong>' + st.fuzzy + ' ' +
        plural(st.fuzzy, 'numer wpisano', 'numery wpisano', 'numerów wpisano') +
        ' na podstawie przybliżonego dopasowania</strong><span>Numer faktury w rejestrze różni się zapisem od numeru w KSeF. Dopasowanie było jednoznaczne, ale warto je obejrzeć — są oznaczone w raporcie.</span></div>');
    }
    if (!st.corr && !R.onlyKsef.length && !st.unclear) {
      hl.push('<div class="callout"><strong>Bez zastrzeżeń</strong><span>Rejestr zgadza się z KSeF. Nie znaleziono błędnych numerów ani faktur pominiętych w księgowaniu.</span></div>');
    }
    $('headlines').innerHTML = hl.join('');

    $('subtabs').innerHTML = CATS.map(function (c) {
      return '<button class="subtab' + (c.sig ? ' sig-' + c.sig : '') + '" role="tab" data-cat="' + c.id +
        '" aria-selected="' + (c.id === activeCat) + '">' + c.name + '<span class="cnt">' + R[c.id].length + '</span></button>';
    }).join('');
    Array.prototype.forEach.call($('subtabs').querySelectorAll('.subtab'), function (b) {
      b.addEventListener('click', function () {
        activeCat = this.getAttribute('data-cat');
        renderCat();
        paintSubtabs();
      });
    });
    renderCat();

    paintExportUi();
    $('dlMsg').textContent = '';
    buildPasteColumn();
    paintLicense();
  }

  function paintSubtabs() {
    Array.prototype.forEach.call($('subtabs').querySelectorAll('.subtab'), function (b) {
      b.setAttribute('aria-selected', b.getAttribute('data-cat') === activeCat ? 'true' : 'false');
    });
  }

  function renderCat() {
    var c = CATS.filter(function (x) { return x.id === activeCat; })[0];
    var rows = S.result[c.id];
    if (!rows.length) {
      $('catBody').innerHTML = '<div class="empty">' + esc(c.empty) + '</div>';
      return;
    }
    var shown = rows.slice(0, MAX_RENDER);
    var h = '<div class="tablewrap"><table class="data"><thead><tr>' +
      c.cols.map(function (x) { return '<th>' + x + '</th>'; }).join('') + '</tr></thead><tbody>' +
      shown.map(function (x) { return '<tr>' + c.row(x) + '</tr>'; }).join('') + '</tbody></table>';
    if (rows.length > shown.length) {
      h += '<div class="trunc">Na ekranie widać ' + shown.length + ' z ' + rows.length + ' pozycji — wszystkie są w raporcie .xlsx.</div>';
    }
    $('catBody').innerHTML = h + '</div>';
  }

  /* ---------- eksporty ---------- */

  /* Z dysku plik zapisujemy wprost przez SheetJS. Na stronie opublikowanej
     przegladarkowy podglad blokuje pobieranie inicjowane skryptem - tam plik
     trzeba oddac przez kanal gospodarza, ktory nie przyjmuje .xlsx. Dlatego
     w tym trybie raport wychodzi jako CSV, a zapis calego rejestru jest
     niedostepny (zostaje kolumna do wklejenia, ktora i tak jest bezpieczniejsza). */
  var DL = null;

  function initDownloads() {
    if (!window.claude || typeof window.claude.use !== 'function') return;
    var p;
    try { p = window.claude.use('downloads'); } catch (e) { return; }
    if (!p || typeof p.then !== 'function') return;
    p.then(function (ns) {
      if (ns && typeof ns.save === 'function') { DL = ns; paintExportUi(); }
    }, function () { });
  }

  /* Jedno miejsce decydujace o wygladzie sekcji eksportu - wolane i przy starcie
     (gdy rozstrzygnie sie tryb), i po kazdym uzgodnieniu. */
  function paintExportUi() {
    $('dlReport').textContent = DL ? 'Pobierz raport .csv' : 'Pobierz raport .xlsx';
    var btn = $('dlFilled'), note = $('fillNote');
    if (!btn || !note) return;
    if (DL) {
      btn.disabled = true;
      note.innerHTML = 'Niedostępne na tej stronie — nie może ona nadpisać pliku na Twoim dysku. ' +
        'Użyj kolumny do wklejenia; przy plikach z formułami jest to i tak bezpieczniejsza droga. ' +
        'Zapis całego arkusza działa w wersji uruchamianej z dysku.';
      return;
    }
    btn.disabled = false;
    note.innerHTML = (S.result && hasFormulas(S.regRef.file.wb, S.regRef.sheet))
      ? '<strong style="color:var(--warning)">Uwaga:</strong> ten rejestr zawiera formuły lub łącza zewnętrzne. Zapis przez przeglądarkę może je uszkodzić. Jeśli plik idzie pod JPK — użyj kolumny do wklejenia.'
      : 'Twój plik rejestru z wpisanymi numerami KSeF.';
  }

  function csvCell(v) {
    var t = v === null || v === undefined ? '' : String(v);
    return /[";\r\n]/.test(t) ? '"' + t.replace(/"/g, '""') + '"' : t;
  }

  function csvFrom(sections) {
    var out = [];
    sections.forEach(function (sec, i) {
      if (i) out.push('');
      out.push(csvCell('== ' + sec.name + ' =='));
      out.push(sec.header.map(csvCell).join(';'));
      sec.rows.forEach(function (r) { out.push(r.map(csvCell).join(';')); });
    });
    /* BOM, zeby Excel w polskiej lokalizacji poprawnie odczytal ogonki */
    return '\uFEFF' + out.join('\r\n') + '\r\n';
  }

  function dlSay(kind, text) {
    var el = $('dlMsg');
    el.className = 'licmsg ' + kind;
    el.textContent = text;
  }

  function saveHosted(base, sections) {
    var text = csvFrom(sections);
    function attempt(ext) {
      return DL.save({ filename: base + '.' + ext, data: text });
    }
    dlSay('', 'Przygotowuję plik...');
    attempt('csv').then(function () {
      dlSay('ok', 'Zapisano raport .csv');
    }, function (err) {
      var code = err && err.code;
      if (code === 'extension_not_enabled' || code === 'rejected_extension') {
        attempt('txt').then(function () {
          dlSay('ok', 'Zapisano raport .txt (kolumny rozdzielone średnikiem)');
        }, function (e2) { dlSay('bad', dlWhy(e2 && e2.code)); });
        return;
      }
      dlSay('bad', dlWhy(code));
    });
  }

  function dlWhy(code) {
    if (code === 'declined') return 'Zapis anulowany.';
    if (code === 'rate_limited') return 'Za dużo próśb o zapis — spróbuj za chwilę.';
    if (code === 'too_large') return 'Raport jest za duży na zapis ze strony — użyj wersji uruchamianej z dysku.';
    return 'Zapis się nie udał. Skorzystaj z kolumny do wklejenia albo z wersji uruchamianej z dysku.';
  }


  function cap(rows) {
    if (S.licensed) return { rows: rows, cut: 0 };
    return { rows: rows.slice(0, FREE_ROWS), cut: Math.max(0, rows.length - FREE_ROWS) };
  }

  function sheetFrom(header, body, widths) {
    var ws = XLSX.utils.aoa_to_sheet([header].concat(body));
    ws['!cols'] = widths.map(function (w) { return { wch: w }; });
    if (body.length) {
      ws['!autofilter'] = { ref: XLSX.utils.encode_range({ s: { r: 0, c: 0 }, e: { r: body.length, c: header.length - 1 } }) };
    }
    return ws;
  }

  function stamp() {
    var d = new Date(), p = function (n) { return (n < 10 ? '0' : '') + n; };
    return d.getFullYear() + p(d.getMonth() + 1) + p(d.getDate()) + '_' + p(d.getHours()) + p(d.getMinutes());
  }

  function reportSections() {
    var R = S.result, st = R.stats;
    return [
      {
        name: 'Podsumowanie', header: ['Pozycja', 'Liczba'], widths: [42, 46],
        rows: [
          ['Wiersze rejestru', st.rows],
          ['Faktury w eksporcie KSeF', st.ksefRows],
          ['Uzupełnione — dopasowanie dokładne', st.exact],
          ['Uzupełnione — dopasowanie przybliżone', st.fuzzy],
          ['Korekty (błędny numer w rejestrze)', st.corr],
          ['Do wyjaśnienia', st.unclear],
          ['Bez dopasowania', st.none + st.ambig],
          ['Już zgodne', st.ok + st.okAlt],
          ['W KSeF, brak w rejestrze', R.onlyKsef.length],
          [],
          ['Plik KSeF', S.ksefRef.file.name],
          ['Plik rejestru', S.regRef.file.name + ' › ' + S.regRef.sheet],
          ['Zakres wierszy rejestru', R.firstDataRow + '-' + R.lastDataRow]
        ]
      },
      {
        name: 'Korekty', header: ['Wiersz', 'NIP', 'Nr faktury', 'Wpisany numer', 'Poprawny numer KSeF'],
        widths: [9, 15, 28, 40, 40],
        rows: R.corrections.map(function (x) { return [x.excel, x.nip, x.inv, x.was, x.num]; })
      },
      {
        name: 'W KSeF brak w rejestrze', header: ['Wiersz KSeF', 'NIP', 'Nr faktury', 'Numer KSeF'],
        widths: [12, 15, 28, 40],
        rows: R.onlyKsef.map(function (x) { return [x.excel, x.nipRaw || x.nip, x.inv, x.num]; })
      },
      {
        name: 'Uzupełnione', header: ['Wiersz', 'NIP', 'Nr faktury', 'Numer KSeF', 'Dopasowanie'],
        widths: [9, 15, 28, 40, 24],
        rows: R.filled.map(function (x) { return [x.excel, x.nip, x.inv, x.num, x.how]; })
      },
      {
        name: 'Do wyjaśnienia', header: ['Wiersz', 'NIP', 'Nr faktury', 'Wpisany numer', 'Uwaga'],
        widths: [9, 15, 28, 40, 56],
        rows: R.unclear.map(function (x) { return [x.excel, x.nip, x.inv, x.was, x.note]; })
      },
      {
        name: 'Bez dopasowania', header: ['Wiersz', 'NIP', 'Nr faktury', 'Flaga', 'Uwaga'],
        widths: [9, 15, 28, 14, 40],
        rows: R.unmatched.map(function (x) { return [x.excel, x.nip, x.inv, x.flag || '', x.note || '']; })
      },
      {
        name: 'Zgodne', header: ['Wiersz', 'NIP', 'Nr faktury', 'Numer KSeF', 'Uwaga'],
        widths: [9, 15, 28, 40, 46],
        rows: R.ok.map(function (x) { return [x.excel, x.nip, x.inv, x.num, x.note]; })
      }
    ];
  }

  /* Limit wersji demonstracyjnej dotyczy tylko eksportu - podsumowanie zostaje cale. */
  function cappedSections() {
    return reportSections().map(function (sec) {
      if (sec.name === 'Podsumowanie') return sec;
      var c = cap(sec.rows);
      var rows = c.rows;
      if (c.cut) {
        rows = rows.concat([[]], [['Wersja demonstracyjna — pominięto ' + c.cut + ' dalszych pozycji. Klucz licencyjny zdejmuje limit.']]);
      }
      return { name: sec.name, header: sec.header, widths: sec.widths, rows: rows };
    });
  }

  $('dlReport').addEventListener('click', function () {
    var sections = cappedSections();
    var base = 'RAPORT_KSeF_' + stamp();
    if (DL) { saveHosted(base, sections); return; }
    var wb = XLSX.utils.book_new();
    sections.forEach(function (sec) {
      XLSX.utils.book_append_sheet(wb, sheetFrom(sec.header, sec.rows, sec.widths), sec.name.slice(0, 31));
    });
    XLSX.writeFile(wb, base + '.xlsx');
    dlSay('ok', 'Zapisano raport .xlsx');
  });

  function buildPasteColumn() {
    var R = S.result, lines = [], n = 0, r, v;
    for (r = R.firstDataRow; r <= R.lastDataRow; r++) {
      v = R.fillByRow[r] || '';
      if (v) {
        n++;
        if (!S.licensed && n > FREE_ROWS) v = '';
      }
      lines.push(v);
    }
    var text = lines.join('\n');
    $('pasteCol').value = text;
    return { text: text, total: n, capped: !S.licensed && n > FREE_ROWS };
  }

  $('showCol').addEventListener('click', function () {
    var t = $('pasteCol');
    t.hidden = !t.hidden;
    this.textContent = t.hidden ? 'Pokaż' : 'Ukryj';
  });

  $('copyCol').addEventListener('click', function () {
    var d = buildPasteColumn(), msg = $('copyMsg');
    function done(ok) {
      msg.className = 'licmsg ' + (ok ? 'ok' : 'bad');
      msg.textContent = ok
        ? 'Skopiowano — wklej do komórki ' + colLetter(S.regRef.map.ksef) + S.result.firstDataRow +
          (d.capped ? ' (demo: tylko pierwsze ' + FREE_ROWS + ')' : '')
        : 'Kopiowanie zablokowane — użyj „Pokaż” i skopiuj ręcznie.';
    }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(d.text).then(function () { done(true); }, function () { done(false); });
    } else {
      var t = $('pasteCol');
      t.hidden = false;
      t.select();
      try { done(document.execCommand('copy')); } catch (e) { done(false); }
    }
  });

  $('dlFilled').addEventListener('click', function () {
    var ref = S.regRef, wb = ref.file.wb, ws = wb.Sheets[ref.sheet];
    var col = ref.map.ksef, R = S.result, n = 0, r, v, addr;
    for (r = R.firstDataRow; r <= R.lastDataRow; r++) {
      v = R.fillByRow[r];
      if (!v) continue;
      n++;
      if (!S.licensed && n > FREE_ROWS) break;
      addr = XLSX.utils.encode_cell({ r: r - 1, c: col });
      ws[addr] = { t: 's', v: v };
    }
    if (ws['!ref']) {
      var rng = XLSX.utils.decode_range(ws['!ref']);
      if (col > rng.e.c) { rng.e.c = col; ws['!ref'] = XLSX.utils.encode_range(rng); }
    }
    XLSX.writeFile(wb, ref.file.name.replace(/\.[^.]+$/, '') + '_UZUPELNIONY.xlsx');
  });

  /* ---------- licencja: interfejs ---------- */

  $('licApply').addEventListener('click', function () {
    var v = $('licKey').value, msg = $('licMsg');
    if (keyValid(v)) {
      S.licensed = true;
      try { localStorage.setItem('ksefu.key', v.trim().toUpperCase()); } catch (e) { }
      msg.className = 'licmsg ok';
      msg.textContent = 'Licencja aktywna — limit eksportu zdjęty.';
      paintLicense();
      if (S.result) buildPasteColumn();
    } else {
      msg.className = 'licmsg bad';
      msg.textContent = 'Ten klucz jest nieprawidłowy. Sprawdź zapis: KSU-XXXX-XXXX-XXXX.';
    }
  });
  $('licKey').addEventListener('keydown', function (e) { if (e.key === 'Enter') $('licApply').click(); });

  $('back2').addEventListener('click', function () { goStep(2); });
  $('resetAll').addEventListener('click', function () { $('reset1').click(); goStep(1); });

  paintLicense();
  initDownloads();
})();
