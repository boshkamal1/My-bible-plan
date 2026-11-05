// Small reading assets; whole-book assets remain available for full-text search.
// Run before a web build: node tools/split_chapters.cjs
const fs = require('node:fs');
const path = require('node:path');
const {gzipSync} = require('node:zlib');
const base = path.join(__dirname, '..', 'assets', 'bible');
const output = path.join(base, 'chapters');
fs.mkdirSync(output, {recursive: true});
let count = 0;
for (const tr of ['svd', 'ar_extra', 'kjv', 'web']) {
  for (const file of fs.readdirSync(path.join(base, tr))) {
    if (!/^\d+\.json$/.test(file)) continue;
    const book = file.slice(0, -5);
    const chapters = JSON.parse(fs.readFileSync(path.join(base, tr, file)));
    if (!Array.isArray(chapters)) throw Error(`Invalid book: ${tr}/${file}`);
    chapters.forEach((verses, i) => {
      if (!Array.isArray(verses) || verses.some(v => typeof v !== 'string')) throw Error(`Invalid chapter: ${tr}/${book}/${i+1}`);
      fs.writeFileSync(path.join(output, `${tr}-${book}-${i+1}.json`), JSON.stringify(verses));
      count++;
    });
  }
}
console.log(`Generated ${count} chapter assets.`);
for (const [tr, b, c] of [['svd', 20, 119], ['svd', 0, 1], ['web', 49, 6]]) {
  const book = fs.readFileSync(path.join(base, tr, `${b}.json`));
  const chapter = fs.readFileSync(path.join(output, `${tr}-${b}-${c}.json`));
  console.log(JSON.stringify({tr,b,c,bookBytes:book.length,chapterBytes:chapter.length,
    bookGzip:gzipSync(book).length,chapterGzip:gzipSync(chapter).length}));
}
