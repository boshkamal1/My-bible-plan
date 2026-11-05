const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {execFileSync} = require('node:child_process');
const {clean} = require('./import_web');
const asset = b => path.join(__dirname, '..', 'assets', 'bible', 'web', `${b}.json`);

test('normal and nested word attributes preserve words and punctuation', () => {
  assert.equal(clean(String.raw`\wj “\+w Be|strong="G3756"\+w* \+w careful|strong="G4337"\+w*, don’\+w t|strong="G3588"\+w*.\wj*`), '“Be careful, don’t.');
  assert.equal(clean(String.raw`\w God|strong="H430"\w* is good.\f + \ft A note\f*`), 'God is good.');
});
test('all 76 books contain no USFM markers or lexical attributes', () => {
  for (let b = 0; b < 76; b++) {
    const chapters = JSON.parse(fs.readFileSync(asset(b)));
    for (const [c, verses] of chapters.entries()) for (const [v, text] of verses.entries()) {
      assert.doesNotMatch(text, /\\|\||strong=|lemma=/, `${b}:${c+1}:${v+1}`);
    }
  }
});
test('Matthew 6 reads as plain English including the reported verse', () => {
  const chapter = JSON.parse(fs.readFileSync(asset(49)))[5];
  assert.equal(chapter.length, 34);
  assert.equal(chapter[0], '“Be careful that you don’t do your charitable giving before men, to be seen by them, or else you have no reward from your Father who is in heaven.');
  assert.match(chapter[1], /^Therefore, when you do merciful deeds, don’t/);
});
test('chapter and verse numbering is preserved from the previous import', () => {
  for (let b = 0; b < 76; b++) {
    const previous = JSON.parse(execFileSync('git', ['show', `866af75:flutter_app/assets/bible/web/${b}.json`], {maxBuffer: 4*1024*1024}));
    const current = JSON.parse(fs.readFileSync(asset(b)));
    assert.deepEqual(current.map(c=>c.length), previous.map(c=>c.length), `book ${b}`);
    current.forEach((c,i)=>c.forEach((v,j)=>assert.equal(Boolean(v),Boolean(previous[i][j]), `${b}:${i+1}:${j+1}`)));
  }
});
