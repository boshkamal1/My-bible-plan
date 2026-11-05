// Rebuild Arabic book assets from St-Takla's vocalized Van Dyck / old Jesuit text.
// Source: https://st-takla.org/Holy-Bible_.html
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..', 'assets', 'bible');
const cache = path.join(__dirname, 'cache', 'st_takla');
fs.mkdirSync(cache, {recursive: true});
const counts = JSON.parse(fs.readFileSync(path.join(root, 'counts.json'), 'utf8'));
const extra = new Map([[16, 17], [17, 18], [24, 27], [25, 28], [29, 32], [44, 48], [45, 49], [47, 35], [48, 20]]);
function siteId(b) {
  if (extra.has(b)) return extra.get(b);
  if (b <= 15) return b + 1;
  if (b === 18) return 19;
  if (b === 19) return 21;
  if (b === 20) return 22;
  if (b >= 21 && b <= 23) return b + 3;
  if (b >= 26 && b <= 28) return b + 3;
  if (b === 30) return 33;
  if (b === 31) return 34;
  if (b >= 32 && b <= 43) return b + 4;
  if (b >= 49) return b + 1;
  throw Error(`No St-Takla ID for ${b}`);
}
const ids = [...Array(76).keys()].filter(b => b !== 46);
const dec = s => s.replace(/&#(x[0-9a-f]+|\d+);/gi, (_, x) => String.fromCodePoint(x[0] === 'x' ? parseInt(x.slice(1), 16) : +x))
  .replace(/&nbsp;/g, ' ').replace(/&quot;/g, '"').replace(/&amp;/g, '&')
  .replace(/&lt;/g, '<').replace(/&gt;/g, '>');
async function get(b) {
  const id = siteId(b);
  const from = b === 47 ? 3 : b === 48 ? 10 : 1;
  const to = b === 47 ? 14 : b === 48 ? 16 : b === 20 ? 150 : counts[b][0];
  const file = path.join(cache, `${b}.html`);
  if (fs.existsSync(file)) return fs.readFileSync(file, 'utf8');
  const url = `https://st-takla.org/Bibles/BibleSearch/showChapters.php?book=${id}&from=${from}&to=${to}`;
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const r = await fetch(url, {headers: {'User-Agent': 'Mozilla/5.0'}});
      if (!r.ok) throw Error(`${r.status}`);
      const html = await r.text();
      if (!html.includes('data-usfm=')) throw Error('No verses');
      fs.writeFileSync(file, html);
      return html;
    } catch (e) {
      if (attempt === 2) throw Error(`${b} ${url}: ${e.message}`);
      await new Promise(resolve => setTimeout(resolve, 1000 * (attempt + 1)));
    }
  }
}
function parse(html, b) {
  const chapterMap = new Map();
  const re = /data-usfm="[^"]+?\.(\d+)\.(\d+)"[^>]*>([\s\S]*?)<\/div>/g;
  for (const m of html.matchAll(re)) {
    const c = +m[1], v = +m[2];
    if (!chapterMap.has(c)) chapterMap.set(c, new Map());
    const value = dec(m[3].replace(/<[^>]*>/g, '')).replace(/\s+/g, ' ').trim();
    if (value && !chapterMap.get(c).has(v)) chapterMap.get(c).set(v, value);
  }
  const chapterNums = b === 47 ? [3, 13, 14] :
    b === 48 ? [10, 11, 12, 13, 14, 15, 16] :
    [...Array(b === 20 ? 150 : counts[b][0]).keys()].map(i => i + 1);
  const chapters = chapterNums.map(c => {
    const verses = chapterMap.get(c);
    if (!verses) throw Error(`${b} chapter ${c} missing`);
    const max = Math.max(...verses.keys());
    const arr = Array.from({length: max}, (_, i) => verses.get(i + 1) || '');
    if (arr.some(v => !v) && !(b === 25 && c === 29)) {
      throw Error(`${b} chapter ${c} has missing verses`);
    }
    return arr;
  });
  if (!chapters.flat().some(v => /[\u064b-\u065f]/u.test(v))) throw Error(`${b} has no diacritics`);
  return chapters;
}
(async () => {
  const pending = process.argv.length > 2 ? process.argv.slice(2).map(Number).filter(b => b < 76) : [...ids];
  const results = [];
  await Promise.all(Array.from({length: 5}, async () => {
    while (pending.length) {
      const b = pending.shift();
      try {
        const chapters = parse(await get(b), b);
        const oldFile = path.join(root, b === 20 && false ? 'ar_extra' : extra.has(b) ? 'ar_extra' : 'svd', `${b}.json`);
        const old = fs.existsSync(oldFile) ? JSON.parse(fs.readFileSync(oldFile, 'utf8')) : null;
        results.push({b, chapters: chapters.length, verses: chapters.flat().length, oldVerses: old?.flat().length || null});
        const outDir = path.join(root, extra.has(b) ? 'ar_extra' : 'svd');
        fs.writeFileSync(path.join(outDir, `${b}.json`), JSON.stringify(chapters));
        console.log('OK', b, chapters.length, chapters.flat().length);
      } catch (e) { console.error('FAILED', b, e.message); process.exitCode = 1; }
    }
  }));
  fs.writeFileSync(path.join(__dirname, 'st_takla_import_report.json'), JSON.stringify(results.sort((a,b) => a.b - b.b), null, 2));
  if (!process.argv.slice(2).length || process.argv.includes('151')) {
    const url = 'https://st-takla.org/Bibles/BibleSearch/showChapter.php?book=23&chapter=1';
    const html = await (await fetch(url, {headers: {'User-Agent': 'Mozilla/5.0'}})).text();
    const psalm = parse(html, 46)[0];
    fs.writeFileSync(path.join(root, 'ar_extra', '151.json'), JSON.stringify([psalm]));
    console.log('OK Psalm 151', psalm.length);
  }
})();
