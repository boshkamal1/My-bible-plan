'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('../flutter_app/rules_tests/node_modules/playwright');
const target=process.argv[2]||'http://127.0.0.1:8199/';
const fallback=process.argv.includes('--js-fallback');
if(!['localhost','127.0.0.1','mybibleplan.web.app','bible-plan-boshkamal-20261101.web.app'].includes(new URL(target).hostname))throw Error('Unexpected target');
(async()=>{
 const browser=await chromium.launch({channel:'chrome',headless:true});
 try {
  const page=await browser.newPage({viewport:{width:390,height:844}}),errors=[],requests=[];
  page.on('pageerror',e=>errors.push(e.message));
  page.on('request',r=>requests.push(new URL(r.url()).pathname));
  await page.addInitScript(()=>{window.__csp=[];window.addEventListener('securitypolicyviolation',e=>window.__csp.push({directive:e.effectiveDirective,blocked:e.blockedURI}));});
  if(fallback)await page.route('**/flutter_bootstrap.js*',async route=>{
   const response=await route.fetch();
   const body=(await response.text()).replace('config: {forceSingleThreadedSkwasm: true}','config: {renderer: "canvaskit", forceSingleThreadedSkwasm: true}');
   await route.fulfill({response,body});
  });
  const click=async text=>{await page.getByText(text,{exact:true}).first().evaluate(e=>e.click());};
  await page.goto(target,{waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>!document.getElementById('app-loading'));
  await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
  assert.equal(requests.some(p=>p.includes('/firebasejs/')),false,'Guest must not download Firebase before account use');
  await click('الأسفار');await page.waitForTimeout(250);
  // ExpansionTile keeps offscreen semantics during animation: use the visible
  // 390px mobile group and book tap targets verified by the layout screenshot.
  await page.mouse.click(190,100);await page.waitForTimeout(400);
  await page.mouse.click(190,150);
  await page.getByText('1',{exact:true}).waitFor();
  const opened=performance.now();await click('1');
  await page.getByText('التكوين 1',{exact:true}).waitFor();
  await page.getByText(/فِي الْبَدْءِ خَلَقَ اللهُ/).waitFor();
  const chapterOpenMs=performance.now()-opened;
  await page.waitForTimeout(800);
  assert.ok(requests.includes('/assets/assets/bible/chapters/svd-0-2.json'),'Next chapter must be prefetched');
  const next=performance.now();
  await page.getByText('الأصحاح التالي',{exact:true}).evaluate(e=>e.click());
  await page.getByText('التكوين 2',{exact:true}).waitFor();
  const prefetchedNextMs=performance.now()-next;
  await click('مقارنة الترجمات');
  await page.getByText('مقارنة الترجمات',{exact:true}).waitFor();
  assert.ok((await page.locator('body').innerText()).includes('فان دايك + يسوعية'));
  await page.screenshot({path:path.join(__dirname,`comparison-${fallback?'js':'wasm'}.png`)});
  const csp=await page.evaluate(()=>window.__csp);
  assert.deepEqual(csp,[]);assert.deepEqual(errors,[]);
  const result={target,renderer:fallback?'JavaScript CanvasKit fallback':'WebAssembly Skwasm',chapterOpenMs,prefetchedNextMs,
   guestFirebaseDeferred:true,nextChapterPrefetched:true,comparisonOpened:true,cspViolations:csp,pageErrors:errors};
  fs.writeFileSync(path.join(__dirname,`browser-smoke-${fallback?'js':'wasm'}.json`),JSON.stringify(result,null,2)+'\n');
  console.log(JSON.stringify(result));
 }finally{await browser.close();}
})().catch(e=>{console.error('Release smoke check failed:',e.message);process.exitCode=1;});
