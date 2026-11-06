'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('../flutter_app/rules_tests/node_modules/playwright');
const target=process.argv[2]||'http://127.0.0.1:8199/';
let progress='opening backup screen';
if(!['localhost','127.0.0.1','mybibleplan.web.app','bible-plan-boshkamal-20261101.web.app'].includes(new URL(target).hostname))throw Error('Unexpected target');
(async()=>{
 const browser=await chromium.launch({channel:'chrome',headless:true});
 try{
  const page=await browser.newPage({viewport:{width:390,height:844}}),errors=[];
  await page.addInitScript(()=>{window.__csp=[];window.addEventListener('securitypolicyviolation',e=>window.__csp.push(e.effectiveDirective));});
  page.on('pageerror',e=>errors.push(e.message));
  await page.goto(target);await page.waitForFunction(()=>!document.getElementById('app-loading'));
  await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
  const click=async text=>{
    progress='activating '+text;
    await page.waitForTimeout(100);
    const node=page.getByText(text,{exact:true}).first();
    const until=Date.now()+15000;
    while(!(await node.isEnabled())){if(Date.now()>until)throw Error('Control stayed busy: '+text);await page.waitForTimeout(50);}
    await node.evaluate(e=>e.click());
  };
  await click('الإعدادات');
  for(let i=0;i<10 && !(await page.getByText('تصدير واسترجاع البيانات',{exact:false}).count());i++){
   await page.mouse.move(190,600);await page.mouse.wheel(0,460);await page.waitForTimeout(200);
  }
  await page.getByText('تصدير واسترجاع البيانات',{exact:false}).evaluate(e=>e.click());
  async function readDownload(wait){const stream=await (await wait).createReadStream(),chunks=[];for await(const chunk of stream)chunks.push(chunk);return Buffer.concat(chunks);}
  async function exported(){const wait=page.waitForEvent('download');await click('تصدير نسخة احتياطية');return JSON.parse((await readDownload(wait)).toString());}
  const backup=await exported();
  const savedNotes=()=>page.evaluate(()=>{
    let value=JSON.parse(localStorage.getItem('flutter.jb-v1')||'{}');
    // SharedPreferencesWeb JSON-encodes string values in localStorage.
    if(typeof value==='string')value=JSON.parse(value);
    return value.notes||{};
  });
  assert.equal(backup.format,'bible-journey-backup');assert.equal(backup.data.setup,null);
  backup.data.notes={'0:1:1':'Synthetic restore verification'};
  const file={name:'synthetic-backup.json',mimeType:'application/json',buffer:Buffer.from(JSON.stringify(backup))};
  let wait=page.waitForEvent('filechooser');await click('استرجاع من ملف');
  await (await wait).setFiles(file);
  await page.getByText('استرجاع النسخة دي؟',{exact:true}).waitFor({state:'attached'});await click('إلغاء');
  assert.deepEqual(await savedNotes(),{});
  wait=page.waitForEvent('filechooser');await click('استرجاع من ملف');await (await wait).setFiles(file);
  await page.getByText('استرجاع النسخة دي؟',{exact:true}).waitFor({state:'attached'});await click('استرجاع');
  await page.getByText('تم استرجاع بياناتك.',{exact:true}).waitFor({state:'attached'});
  assert.deepEqual(await savedNotes(),backup.data.notes);
  await click('تصدير نسخة مشفرة بكلمة مرور');
  const password='Synthetic test password 2026';
  await page.getByLabel('كلمة المرور',{exact:true}).fill(password);
  await page.getByLabel('تأكيد كلمة المرور',{exact:true}).fill(password);
  wait=page.waitForEvent('download');await click('متابعة');
  let encrypted;
  try{encrypted=await readDownload(wait);}catch(error){
    console.log(JSON.stringify({screen:await page.locator('body').innerText(),fields:await page.locator('input').evaluateAll(es=>es.map(e=>({type:e.type,label:e.getAttribute('aria-label')})))}));
    throw error;
  }
  const envelope=JSON.parse(encrypted.toString());
  assert.equal(envelope.format,'bible-journey-encrypted-backup');
  const crypto=require('node:crypto');
  const key=crypto.pbkdf2Sync(password,Buffer.from(envelope.salt,'base64'),600000,32,'sha256');
  const decipher=crypto.createDecipheriv('aes-256-gcm',key,Buffer.from(envelope.nonce,'base64'));
  decipher.setAuthTag(Buffer.from(envelope.tag,'base64'));decipher.setAAD(Buffer.from(envelope.format+':1'));
  const decrypted=Buffer.concat([decipher.update(Buffer.from(envelope.ciphertext,'base64')),decipher.final()]);
  assert.deepEqual(JSON.parse(decrypted).data.notes,backup.data.notes);
  wait=page.waitForEvent('filechooser');await click('استرجاع من ملف');
  await (await wait).setFiles({name:'encrypted.json',mimeType:'application/json',buffer:encrypted});
  await page.getByLabel('كلمة المرور',{exact:true}).fill(password);await click('متابعة');
  await page.getByText('استرجاع النسخة دي؟',{exact:true}).waitFor({state:'attached'});await click('استرجاع');
  await page.getByText('تم استرجاع بياناتك.',{exact:true}).waitFor({state:'attached'});
  assert.deepEqual(await savedNotes(),backup.data.notes);
  const csp=await page.evaluate(()=>window.__csp);assert.deepEqual(csp,[]);
  assert.deepEqual(errors,[]);
  const result={target,plainExport:true,filePickerRegistered:true,restorePreview:true,cancelPreservedData:true,restoreCompleted:true,encryptedRoundTrip:true,nodeCryptoInteroperability:true,cspViolations:csp,pageErrors:errors,scope:'Isolated guest with synthetic data; no account writes.'};
  fs.writeFileSync(path.join(__dirname,'browser-backup-smoke.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result));
 }finally{await browser.close();}
})().catch(e=>{console.error('Backup browser check failed at '+progress+':',e.message);process.exitCode=1;});
