// Import the official public-domain World English Bible Classic USFM release.
// Download: https://ebible.org/Scriptures/eng-web_usfm.zip
const fs = require('fs');
const path = require('path');
const source = path.join(__dirname, 'web_usfm');
const output = path.join(__dirname, '..', 'assets', 'bible', 'web');
fs.mkdirSync(output, {recursive: true});
const codes = [
  'GEN','EXO','LEV','NUM','DEU','JOS','JDG','RUT','1SA','2SA','1KI','2KI','1CH','2CH','EZR','NEH',
  'TOB','JDT','EST','JOB','PSA','PRO','ECC','SNG','WIS','SIR','ISA','JER','LAM','BAR','EZK','DAN',
  'HOS','JOL','AMO','OBA','JON','MIC','NAM','HAB','ZEP','HAG','ZEC','MAL','1MA','2MA','MAN','DAG','ESG',
  'MAT','MRK','LUK','JHN','ACT','ROM','1CO','2CO','GAL','EPH','PHP','COL','1TH','2TH','1TI','2TI',
  'TIT','PHM','HEB','JAS','1PE','2PE','1JN','2JN','3JN','JUD','REV',
];
const files = fs.readdirSync(source);
function clean(s) {
  return s
    .replace(/\\f\s[\s\S]*?\\f\*/g, '')
    .replace(/\\x\s[\s\S]*?\\x\*/g, '')
    .replace(/\\w\s([^|\\]+?)\|[^\\]*?\\w\*/g, '$1')
    .replace(/\\\+?\w+\*/g, '')
    .replace(/\\\w+\s?/g, '')
    .replace(/\s+/g, ' ').trim();
}
function parse(code) {
  const file = files.find(f => f.endsWith(`${code}eng-web.usfm`));
  if (!file) throw Error(`Missing ${code}`);
  const raw = fs.readFileSync(path.join(source, file), 'utf8');
  const matches = [...raw.matchAll(/\\c\s+(\d+)|\\v\s+(\d+(?:-\d+)?)\s/g)];
  const chapters = [];
  let c = 0;
  for (let i = 0; i < matches.length; i++) {
    const m = matches[i];
    if (m[1]) {
      c = +m[1];
      chapters[c - 1] ||= [];
      continue;
    }
    const verse = +m[2].split('-')[0];
    const end = i + 1 < matches.length ? matches[i + 1].index : raw.length;
    let body = raw.slice(m.index + m[0].length, end);
    body = body.split(/\r?\n\\(?:s\d?|ms\d?|is\d?|cl|d|r|rem)\b/)[0];
    const text = clean(body);
    if (text) chapters[c - 1][verse - 1] = text;
  }
  return chapters.map(ch => Array.from({length: ch.length}, (_, i) => ch[i] || ''));
}
const report = [];
for (let b = 0; b < codes.length; b++) {
  let chapters = parse(codes[b]);
  // The source prints Psalm 151 as its own book.
  if (b === 20) chapters.push(...parse('PS2'));
  // The app keeps Daniel's Greek portions in a separate three-chapter book.
  if (b === 47) chapters = [chapters[2], chapters[12], chapters[13]];
  if (chapters.length === 0 || chapters.some(ch => ch.length === 0)) {
    throw Error(`${b} ${codes[b]}: missing chapters`);
  }
  const gaps = chapters.flat().filter(v => !v).length;
  if (gaps) console.warn(`${b} ${codes[b]}: ${gaps} unnumbered verse slots`);
  fs.writeFileSync(path.join(output, `${b}.json`), JSON.stringify(chapters));
  report.push({b, code: codes[b], chapters: chapters.length, verses: chapters.flat().length});
  console.log(b, codes[b], chapters.length, chapters.flat().length);
}
fs.writeFileSync(path.join(__dirname, 'web_import_report.json'), JSON.stringify(report, null, 2));
