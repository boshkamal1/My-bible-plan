// Generate estimated reading minutes from the bundled verse text.
const fs = require('fs');
const path = require('path');
const root = path.join(__dirname, '..', 'assets', 'bible');
const counts = JSON.parse(fs.readFileSync(path.join(root, 'counts.json'), 'utf8'));
const read = (translation, book) => {
  const file = path.join(root, translation, `${book}.json`);
  return fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : null;
};
const minutes = (verses, wordsPerMinute) => {
  const words = verses.join(' ').trim().split(/\s+/u).length;
  return Math.max(0.25, words / wordsPerMinute);
};
const lines = [];
for (let b = 0; b < counts.length; b++) {
  const ar = read('svd', b) || read('ar_extra', b);
  const en = read('kjv', b);
  const row = [];
  for (let c = 0; c < counts[b][0]; c++) {
    const a = ar?.[c];
    const e = en?.[c];
    const estimate = a && e
      ? (minutes(a, 130) + minutes(e, 160)) / 2
      : a ? minutes(a, 130)
      : e ? minutes(e, 160)
      : Math.max(0.25, counts[b][1] / counts[b][0] * 0.12);
    row.push(estimate.toFixed(2));
  }
  if (b === 20) {
    const extra = read('ar_extra', 151)?.[0];
    row[150] = extra ? minutes(extra, 130).toFixed(2) : row[150];
  }
  lines.push(`  [${row.join(', ')}],`);
}
const output = '// Generated from assets/bible by tools/gen_chapter_lengths.js.\n'
  + 'const List<List<double>> kChapterMinutes = [\n'
  + lines.join('\n') + '\n];\n';
fs.writeFileSync(path.join(__dirname, '..', 'lib', 'core', 'chapter_lengths.dart'), output);
