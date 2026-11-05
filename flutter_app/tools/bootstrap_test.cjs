const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
function bootstrap(controlled){
 const events={},storage=new Map();let reloads=0;
 const code=fs.readFileSync('web/flutter_bootstrap.js','utf8').replace(/\{\{flutter_(js|build_config)\}\}/g,'');
 const context={_flutter:{buildConfig:{builds:[]},loader:{load(){}}},document:{getElementById(){return null;}},
 navigator:{serviceWorker:{controller:controlled?{}:null,addEventListener(name,fn){events[name]=fn;}}},
 window:{addEventListener(){}},setTimeout(){return 1;},clearTimeout(){},console,
 location:{reload(){reloads++;}},sessionStorage:{getItem:k=>storage.get(k),setItem:(k,v)=>storage.set(k,v)}};
 vm.runInNewContext(code,context);return {change:events.controllerchange,reloads:()=>reloads};
}
test('first worker installation does not reload a newly opened app',()=>{
 const b=bootstrap(false);b.change();assert.equal(b.reloads(),0);
});
test('an old controlled app reloads once for a new release',()=>{
 const b=bootstrap(true);b.change();b.change();assert.equal(b.reloads(),1);
});
