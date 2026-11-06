'use strict';
// Exercise the actual release application and Cloud.sync against demo emulators.
// Browser interception is test-only; remote Auth/Firestore requests are blocked.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('../flutter_app/rules_tests/node_modules/playwright');
const origin='http://127.0.0.1:8200';
(async()=>{
 const browser=await chromium.launch({channel:'chrome',headless:true});
 let page;const blocked=[],failures=[],browserErrors=[];
 try{
  const context=await browser.newContext({viewport:{width:390,height:844},serviceWorkers:'block'});
  page=await context.newPage();
  page.on('requestfailed',r=>{const u=new URL(r.url());failures.push({host:u.host,path:u.pathname,error:r.failure()?.errorText});});
  page.on('console',m=>{if(m.type()==='error')browserErrors.push(m.text().replace(/([?&]key=)[^\s&]+/g,'$1[redacted]'));});
  await page.addInitScript(()=>{window.__integrationCsp=[];window.addEventListener('securitypolicyviolation',e=>window.__integrationCsp.push({directive:e.effectiveDirective,blocked:e.blockedURI.split('?')[0]}));});
  await page.route('**/*',async route=>{
   const request=route.request(),url=new URL(request.url());
   if(['identitytoolkit.googleapis.com','securetoken.googleapis.com','firestore.googleapis.com'].includes(url.hostname)){
    blocked.push(url.hostname);return route.abort();
   }
   if(url.origin===origin && url.pathname==='/firebase_loader.js'){
    const response=await route.fetch();let body=(await response.text()).replace(/\r\n/g,'\n');
    const original=`    window.firebase_auth = auth;
    window.firebase_firestore = firestore;
    window.firebase_app_check = appCheck;
    // Publish core last: FlutterFire treats this as the readiness signal.
    window.firebase_core = core;`;
    assert.ok(body.includes(original),'Known loader assignment required');
    body=body.replace(original,`    const connectedAuth=new WeakSet(),connectedDb=new WeakSet();
    window.firebase_auth={...auth,getAuth(app){const value=auth.getAuth(app);if(!connectedAuth.has(value)){auth.connectAuthEmulator(value,'http://127.0.0.1:9099',{disableWarnings:true});connectedAuth.add(value);}return value;}};
    function connectDb(value){if(!connectedDb.has(value)){firestore.connectFirestoreEmulator(value,'127.0.0.1',8187);connectedDb.add(value);}return value;}
    window.firebase_firestore={...firestore,getFirestore(app){return connectDb(firestore.getFirestore(app));},initializeFirestore(app,settings){return connectDb(firestore.initializeFirestore(app,settings));}};
    window.firebase_app_check=appCheck;
    window.firebase_core={...core,initializeApp(options,name){return core.initializeApp({...options,apiKey:'synthetic-emulator-api-key',projectId:'demo-bible-integration',authDomain:'demo-bible-integration.firebaseapp.com'},name);}};`);
    return route.fulfill({response,body});
   }
   return route.continue();
  });
  await page.goto(origin+'/?refresh=20261106-33');
  await page.waitForFunction(()=>!document.getElementById('app-loading'));
  await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
  const click=async text=>{await page.waitForTimeout(100);await page.getByText(text,{exact:true}).first().evaluate(e=>e.click());};
  await click('تسجيل الدخول / إنشاء حساب');
  await page.waitForFunction(()=>window.firebase_core?.getApps().length>0);
  await page.evaluate(async()=>{
   const app=window.firebase_core.getApp();
   if(app.options.projectId!=='demo-bible-integration')throw Error('Demo project required');
   const auth=window.firebase_auth.getAuth(app);
   if(auth.emulatorConfig?.host!=='127.0.0.1')throw Error('Local Auth emulator required');
   const result=await window.firebase_auth.createUserWithEmailAndPassword(auth,'synthetic-sync@example.invalid','Synthetic test password 2026');
   window.__syncTest={uid:result.user.uid,db:window.firebase_firestore.getFirestore(app)};
  });
  async function server(){return page.evaluate(async()=>{const s=window.__syncTest,f=window.firebase_firestore;return(await f.getDoc(f.doc(s.db,'users',s.uid))).data()||null;});}
  async function waitRevision(n){for(let i=0;i<100;i++){const data=await server();if(data?.revision===n)return data;await page.waitForTimeout(200);}throw Error('Expected local revision '+n);}
  await waitRevision(1);
  await page.evaluate(async()=>{
   const f=window.firebase_firestore,s=window.__syncTest,ref=f.doc(s.db,'users',s.uid),snap=await f.getDoc(ref),data=snap.data();
   const fields=['done','hist','delays','pb','plan','plannerVersion','setup','t','notes','hl','fav','secs','badgeDates','conflicts'];
   const canonical=v=>Array.isArray(v)?v.map(canonical):v&&typeof v==='object'?Object.fromEntries(Object.keys(v).sort().map(k=>[k,canonical(v[k])])):v;
   async function hash(d){const payload=canonical(Object.fromEntries(fields.map(k=>[k,d[k]])));return[...new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(JSON.stringify(payload))))].map(n=>n.toString(16).padStart(2,'0')).join('');}
   if(await hash(data)!==data.contentHash)throw Error('SDK/Dart hash mismatch');
   const next={...data,notes:{'0:1:1':'Remote emulator edit'},t:Date.now()};
   await f.updateDoc(ref,{notes:next.notes,t:next.t,contentHash:await hash(next),revision:data.revision+1,updatedAt:f.serverTimestamp()});
  });
  await click('الإعدادات');
  for(let i=0;i<10&&!(await page.getByText('زامن الآن',{exact:true}).count());i++){
   await page.mouse.move(190,600);await page.mouse.wheel(0,360);await page.waitForTimeout(200);
  }
  await click('زامن الآن');await page.waitForTimeout(1200);
  const data=await server();assert.equal(data.revision,2,'Pull must not write an unchanged remote snapshot');
  // Restore a second local edit through the production UI, causing another real
  // Cloud.sync transaction to read Firestore's typed Timestamp metadata.
  for(let i=0;i<10&&!(await page.getByText('تصدير واسترجاع البيانات',{exact:false}).count());i++){
   await page.mouse.move(190,600);await page.mouse.wheel(0,360);await page.waitForTimeout(200);
  }
  await page.getByText('تصدير واسترجاع البيانات',{exact:false}).evaluate(e=>e.click());
  const fields=['done','hist','delays','pb','plan','plannerVersion','setup','t','notes','hl','fav','secs','badgeDates','conflicts'];
  const state=Object.fromEntries(fields.map(k=>[k,data[k]]));
  state.notes={...state.notes,'0:1:2':'Local emulator edit'};state.groups=[];
  state.settings={lang:'ar',tr:'svd',fs:20,theme:0,rem:true,risk:true,rh:8,rm:0,welcome:false,name:''};
  const chooser=page.waitForEvent('filechooser');await click('استرجاع من ملف');
  await(await chooser).setFiles({name:'synthetic-sync.json',mimeType:'application/json',buffer:Buffer.from(JSON.stringify({format:'bible-journey-backup',version:1,createdAt:new Date().toISOString(),data:state}))});
  await page.getByText('استرجاع النسخة دي؟',{exact:true}).waitFor({state:'attached'});await click('استرجاع');
  const final=await waitRevision(3);
  assert.deepEqual(final.notes,{'0:1:1':'Remote emulator edit','0:1:2':'Local emulator edit'});
  assert.deepEqual(blocked,[],'No production data API may be contacted');
  const proof={release:'20261106-33',project:'demo-bible-integration',backend:'localhost Auth + Firestore emulators only',realReleaseApp:true,
   initialSync:true,typedTimestampPull:true,unchangedPullDidNotWrite:true,subsequentLocalEditSynced:true,finalRevision:3,productionApiRequests:0,verifiedAt:new Date().toISOString()};
  fs.writeFileSync(path.join(__dirname,'cloud-sdk-integration.json'),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify(proof));
 }catch(error){console.log(JSON.stringify({blocked,failures,browserErrors,csp:page?await page.evaluate(()=>window.__integrationCsp):[]}));throw error;}
 finally{await browser.close();}
})().catch(e=>{console.error('Local release cloud integration failed:',e.message);process.exitCode=1;});
