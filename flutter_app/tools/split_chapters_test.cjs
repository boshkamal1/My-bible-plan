const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.join(__dirname,'..','assets','bible');
test('all generated chapter assets preserve every source verse and numbering slot',()=>{
  let count=0;
  for(const tr of ['svd','ar_extra','kjv','web']){
    for(const name of fs.readdirSync(path.join(root,tr)).filter(n=>/^\d+\.json$/.test(n))){
      const source=JSON.parse(fs.readFileSync(path.join(root,tr,name)));
      source.forEach((verses,i)=>{
        const chapter=JSON.parse(fs.readFileSync(path.join(root,'chapters',`${tr}-${name.slice(0,-5)}-${i+1}.json`)));
        assert.deepEqual(chapter,verses,`${tr}/${name}/${i+1}`);count++;
      });
    }
  }
  assert.ok(count>4000);
  console.log(`Verified ${count} chapter assets against original texts.`);
});
