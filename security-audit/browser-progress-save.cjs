'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('../flutter_app/rules_tests/node_modules/playwright');
const target=process.argv[2]||'http://127.0.0.1:8199/?refresh=20261106-34#/?tab=3';
const fallback=process.argv.includes('--js-fallback');
if(!['127.0.0.1','mybibleplan.web.app','bible-plan-boshkamal-20261101.web.app'].includes(new URL(target).hostname))throw Error('Unexpected test target');
(async()=>{
 const browser=await chromium.launch({channel:'chrome',headless:true});
 try{
  const page=await browser.newPage({viewport:{width:575,height:532}}),errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  await page.addInitScript(()=>{
   const data={setup:{scope:'all',mode:'seq',days:100,start:'2026-11-06',first:'2026-11-06',end:null,
    ot:{b:-1,c:0,p:0},nt:{b:-1,c:0},skip:[],selectedBooks:[0],bookOrder:[],reserveWithinDuration:true},
    done:{'0:1':'2026-11-06','0:2':'2026-11-06','0:3':'2026-11-06'},t:1,plannerVersion:14,
    plan:null,hist:[],delays:[],pb:[],notes:{},hl:{},fav:[],secs:{},badgeDates:{},groups:[],conflicts:{},
    settings:{lang:'ar',tr:'svd',fs:20,theme:0,rem:true,risk:true,rh:8,rm:0,welcome:true,name:''}};
   localStorage.setItem('flutter.jb-v1',JSON.stringify(JSON.stringify(data)));
   window.__saveCsp=[];window.addEventListener('securitypolicyviolation',e=>window.__saveCsp.push(e.effectiveDirective));
  });
  if(fallback)await page.route('**/flutter_bootstrap.js*',async route=>{
   const response=await route.fetch(),body=(await response.text()).replace('config: {forceSingleThreadedSkwasm: true}','config: {renderer: "canvaskit", forceSingleThreadedSkwasm: true}');
   await route.fulfill({response,body});
  });
  await page.goto(target);await page.waitForFunction(()=>!document.getElementById('app-loading'));
  await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
  await page.getByText('شارك إنجازك',{exact:true}).evaluate(e=>e.click());
  const save=page.getByText('حفظ الصورة',{exact:true});
  await save.waitFor({state:'attached'});
  for(let i=0;!(await save.isEnabled());i++){if(i>200){await page.screenshot({path:'flutter_app/test_artifacts/save-failure.png'});console.log(await page.locator('flt-semantics-host').innerText());throw Error('Save image never became ready');}await page.waitForTimeout(50);}
  await page.evaluate(()=>{const original=window.downloadProgressImage;window.downloadProgressImage=function(bytes){window.__saveInfo={active:navigator.userActivation.isActive,type:Object.prototype.toString.call(bytes),length:bytes.length};return original(bytes);};});
  await page.mouse.move(287,300);await page.mouse.wheel(0,1600);await page.waitForTimeout(250);
  const waiting=page.waitForEvent('download');
  await page.mouse.click(287,492);
  const download=await waiting,stream=await download.createReadStream(),chunks=[];
  for await(const chunk of stream)chunks.push(chunk);
  const png=Buffer.concat(chunks);
  assert.equal(download.suggestedFilename(),'bible-plan-progress.png');
  assert.equal(png.subarray(0,8).toString('hex'),'89504e470d0a1a0a');
  assert.equal(png.readUInt32BE(16),960);assert.ok(png.readUInt32BE(20)>1000);
  const info=await page.evaluate(()=>window.__saveInfo);
  assert.equal(info.active,true,'Download must run inside the real user tap');
  assert.equal(info.type,'[object Uint8Array]');assert.equal(info.length,png.length);
  assert.deepEqual(errors,[]);assert.deepEqual(await page.evaluate(()=>window.__saveCsp),[]);
  const artifact=path.resolve(__dirname,'../flutter_app/test_artifacts');fs.mkdirSync(artifact,{recursive:true});
  fs.writeFileSync(path.join(artifact,`progress-${fallback?'js':'wasm'}.png`),png);
  const proof={target,renderer:fallback?'JavaScript fallback':'WebAssembly',downloaded:true,filename:download.suggestedFilename(),bytes:png.length,width:png.readUInt32BE(16),height:png.readUInt32BE(20),userActivationPreserved:true,binaryBlob:true,pageErrors:errors,scope:'Isolated synthetic guest plan; real pointer tap at 575x532'};
  fs.writeFileSync(path.join(__dirname,`progress-save-${fallback?'js':'wasm'}.json`),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify(proof));
 }finally{await browser.close();}
})().catch(e=>{console.error('Progress image save verification failed:',e.message);process.exitCode=1;});
