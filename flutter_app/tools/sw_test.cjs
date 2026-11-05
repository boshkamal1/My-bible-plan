const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
function worker() {
  const handlers = {}, entries = new Map(), requests = [], opened = [];
  const cache = {match: async k => entries.get(typeof k === 'string' ? k : k.url),
    put: async (k,v) => entries.set(typeof k === 'string' ? k : k.url,v)};
  vm.runInNewContext(fs.readFileSync('web/sw.js','utf8'), {
    URL, Response, self: {location: new URL('https://mybibleplan.web.app/sw.js'),
      addEventListener: (name,fn) => handlers[name]=fn},
    caches: {open:async()=>cache}, clients:{openWindow:async u=>opened.push(u)},
    fetch:async r=>{requests.push(r.url);return new Response('new');}
  });
  async function request(path, mode='cors') {
    let response; const pending=[];
    handlers.fetch({request:{url:'https://mybibleplan.web.app'+path,method:'GET',mode},
      respondWith:p=>response=p,waitUntil:p=>pending.push(p)});
    const result=await response;await Promise.all(pending);return result;
  }
  return {handlers,entries,requests,opened,request};
}
test('repeat static requests use release cache without network',async()=>{
  const w=worker();await w.request('/assets/bible/svd/20.json');
  assert.equal(await (await w.request('/assets/bible/svd/20.json')).text(),'new');
  assert.equal(w.requests.length,1);
});
test('bootstrap checks network on every visit',async()=>{
  const w=worker();await w.request('/flutter_bootstrap.js?v=19');
  await w.request('/flutter_bootstrap.js?v=19');assert.equal(w.requests.length,2);
});
test('auth helpers and unknown endpoints bypass caching',async()=>{
  const w=worker();assert.equal(await w.request('/__/auth/handler','navigate'),undefined);
  assert.equal(await w.request('/private.json'),undefined);assert.equal(w.requests.length,0);
});
test('notification cannot navigate to an outside origin',async()=>{
  const w=worker();let done;
  w.handlers.notificationclick({notification:{close(){},data:{url:'https://evil.example/'}},waitUntil:p=>done=p});
  await done;assert.deepEqual(w.opened,['https://mybibleplan.web.app/']);
});
