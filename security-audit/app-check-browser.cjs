'use strict';
// Isolated, signed-out browser. One permitted free assessment; never log tokens.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('../flutter_app/rules_tests/node_modules/playwright');
const repo=path.resolve(__dirname,'..'),root=path.join(repo,'flutter_app/build/web');
const origin='https://mybibleplan.web.app',preview=process.argv.includes('--local-preview');
const policy=JSON.parse(fs.readFileSync(path.join(repo,'firebase.json'))).hosting.headers[0].headers;
(async()=>{
 const browser=await chromium.launch({channel:'chrome',headless:true});
 try{
  const context=await browser.newContext({viewport:{width:390,height:844},serviceWorkers:'block'}),page=await context.newPage();
  const exchanges=[];page.on('response',async r=>{
    if(new URL(r.url()).hostname.includes('appcheck')){
      const entry={path:new URL(r.url()).pathname,status:r.status()};exchanges.push(entry);
      try{const body=await r.json();if(body.error)entry.error={status:body.error.status,message:body.error.message};}catch(_){}
    }
  });
  await page.addInitScript(()=>{window.__csp=[];window.addEventListener('securitypolicyviolation',e=>window.__csp.push({directive:e.effectiveDirective,blocked:e.blockedURI}));});
  if(preview)await page.route(origin+'/**',async route=>{
   const url=new URL(route.request().url()),file=path.resolve(root,'.'+(url.pathname==='/'?'/index.html':url.pathname));
   if(!file.startsWith(root+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile())return route.continue();
   const type={'.html':'text/html','.js':'text/javascript','.mjs':'text/javascript','.json':'application/json','.wasm':'application/wasm','.png':'image/png','.ttf':'font/ttf'}[path.extname(file)]||'application/octet-stream';
   await route.fulfill({status:200,headers:{...Object.fromEntries(policy.map(h=>[h.key,h.value])),'Content-Type':type},body:fs.readFileSync(file)});
  });
  await page.goto(origin+'/?refresh=20261106-33');
  await page.waitForFunction(()=>!document.getElementById('app-loading'));
  await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
  await page.getByText('تسجيل الدخول / إنشاء حساب',{exact:true}).evaluate(e=>e.click());
  try {
    await page.waitForFunction(()=>window.firebase_core&&window.firebase_app_check,null,{timeout:20000});
  } catch (_) {
    console.log(JSON.stringify(await page.evaluate(()=>({
      body:document.body.innerText.slice(0,1200),csp:window.__csp,
      loader:typeof window.biblePrepareFirebase,core:typeof window.firebase_core,check:typeof window.firebase_app_check
    }))));
    throw Error('Firebase account screen did not initialize');
  }
  await page.waitForTimeout(1500);

  await page.waitForFunction(()=>{try{return window.firebase_core._getProvider(window.firebase_core.getApp(),'app-check').isInitialized();}catch(_){return false;}},null,{timeout:10000});
  const result=await page.evaluate(async()=>{
   try{
    const app=window.firebase_core.getApp();
    const check=window.firebase_core._getProvider(app,'app-check').getImmediate();
    const value=await window.firebase_app_check.getToken(check,false);
    return{tokenAcquired:typeof value.token==='string'&&value.token.length>100};
   }catch(e){return{tokenAcquired:false,errorCode:e.code||e.name,httpStatus:e.customData?.httpStatus};}
  });
  const csp=await page.evaluate(()=>window.__csp);
  assert.deepEqual(csp,[],'CSP must allow the official sign-in and assessment flow');
  await page.waitForTimeout(500);
  console.log(JSON.stringify({result,exchanges}));
  assert.ok(result.tokenAcquired,JSON.stringify(result));
  const summary={origin,preview,tokenAcquired:true,signedIn:false,enforcementMode:'UNENFORCED',cspViolations:csp,
   testedAt:new Date().toISOString(),scope:'Real reCAPTCHA/App Check token issuance; no account sign-in or Firestore write.'};
  fs.writeFileSync(path.join(__dirname,'app-check-browser-verification.json'),JSON.stringify(summary,null,2)+'\n');console.log(JSON.stringify(summary));
 }finally{await browser.close();}
})().catch(e=>{console.error('App Check browser verification failed:',e.message);process.exitCode=1;});
