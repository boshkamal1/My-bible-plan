const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
test('browser backup download keeps UTF-8 data, JSON type and chosen filename',async()=>{
 const html=fs.readFileSync('web/index.html','utf8');
 const script=html.match(/<script>([\s\S]*?)<\/script>/)[1];
 let file,clicked=false,removed=false,revoked=false,later;
 const link={click(){clicked=true;},remove(){removed=true;}};
 const context={Blob,URL:{createObjectURL(blob){file=blob;return 'blob:backup';},revokeObjectURL(url){assert.equal(url,'blob:backup');revoked=true;}},
 document:{createElement(tag){assert.equal(tag,'a');return link;},body:{appendChild(node){assert.equal(node,link);}}},setTimeout(fn){later=fn;}};
 vm.createContext(context);vm.runInContext(script,context);
 context.downloadBibleBackup('{"note":"تأمل — Note"}','journey.json');
 assert.equal(file.type,'application/json;charset=utf-8');
 assert.deepEqual(JSON.parse(await file.text()),{note:'تأمل — Note'});
 assert.equal(link.download,'journey.json');assert.equal(link.href,'blob:backup');
 assert.ok(clicked&&removed);assert.equal(revoked,false);later();assert.equal(revoked,true);
});
