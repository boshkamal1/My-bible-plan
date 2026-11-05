const {test}=require('node:test');const assert=require('node:assert/strict');const fs=require('node:fs');const path=require('node:path');const crypto=require('node:crypto');
const root=path.join(__dirname,'..','assets','bible','gna');const report=JSON.parse(fs.readFileSync(path.join(__dirname,'gna_import_report.json')));
test('GNA preserves all 31,070 original verse strings in order',()=>{
 const books=report.books.map(b=>[b.code,JSON.parse(fs.readFileSync(path.join(root,`${b.b}.json`))).flat().filter(v=>v!=='')]);
 assert.equal(books.length,66);assert.equal(books.reduce((n,b)=>n+b[1].length,0),31070);
 assert.equal(crypto.createHash('sha256').update(JSON.stringify(books)).digest('hex'),report.verseTextSha256);
 assert.ok(fs.readFileSync(path.join(root,'LICENSE.txt'),'utf8').includes('CC BY-NC-ND 4.0'));
});
test('Joel and Malachi keep existing plan chapter boundaries without dropping words',()=>{
 const read=b=>JSON.parse(fs.readFileSync(path.join(root,`${b}.json`)));
 assert.deepEqual(read(33).map(c=>c.length),[20,32,21]);
 assert.deepEqual(read(43).map(c=>c.length),[14,17,18,6]);
});
