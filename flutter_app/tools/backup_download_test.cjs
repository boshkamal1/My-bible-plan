const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
test('browser backup download keeps UTF-8 data, JSON type and chosen filename',async()=>{
 const script=fs.readFileSync('web/downloads.js','utf8');
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
test('progress PNG downloads use binary Blob URLs and keep them alive for the browser',async()=>{
 const script=fs.readFileSync('web/downloads.js','utf8');
 const bytes=new Uint8Array([137,80,78,71,13,10,26,10,0,255]);
 let file,revoked=false,later,clicked=false;
 const link={click(){clicked=true;},remove(){}};
 const context={Blob,URL:{createObjectURL(blob){file=blob;return 'blob:progress';},revokeObjectURL(url){assert.equal(url,'blob:progress');revoked=true;}},
 document:{createElement(){return link;},body:{appendChild(){}}},setTimeout(fn,ms){later=fn;assert.equal(ms,60000);}};
 vm.runInNewContext(script,context);
 context.downloadProgressImage(bytes);
 assert.equal(file.type,'image/png');
 assert.deepEqual(new Uint8Array(await file.arrayBuffer()),bytes);
 assert.equal(link.href,'blob:progress');assert.equal(link.download,'bible-plan-progress.png');
 assert.ok(clicked);assert.equal(revoked,false);later();assert.equal(revoked,true);
});
