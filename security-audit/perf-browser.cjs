'use strict';
const fs = require('node:fs');
const path = require('node:path');
const {chromium} = require(path.resolve(__dirname, '../flutter_app/rules_tests/node_modules/playwright'));
const target = process.argv[3] || 'https://mybibleplan.web.app/?refresh=20261105-31';
const label = process.argv[2] || 'baseline';
if (!['baseline','after','local'].includes(label) ||
    !['mybibleplan.web.app','bible-plan-boshkamal-20261101.web.app','localhost','127.0.0.1'].includes(new URL(target).hostname)) throw Error('Unexpected benchmark target');
(async()=>{
  const browser=await chromium.launch({channel:'chrome',headless:true});
  try {
    const context=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
    const page=await context.newPage();
    const pageErrors=[];page.on('pageerror',e=>pageErrors.push(e.message));
    const cdp=await context.newCDPSession(page);
    await cdp.send('Network.enable');
    await cdp.send('Network.emulateNetworkConditions',{offline:false,latency:150,downloadThroughput:200000,uploadThroughput:100000,connectionType:'cellular3g'});
    await cdp.send('Emulation.setCPUThrottlingRate',{rate:4});
    await page.addInitScript(()=>{window.__csp=[];window.addEventListener('securitypolicyviolation',e=>window.__csp.push({directive:e.effectiveDirective,blocked:e.blockedURI}));window.__bibleFirstFrame=0;window.addEventListener('flutter-first-frame',()=>{window.__bibleFirstFrame=performance.now();},{once:true});});
    let requests=new Map(),bytes=0,failed=0;
    cdp.on('Network.requestWillBeSent',r=>{const u=new URL(r.request.url);requests.set(r.requestId,{host:u.hostname,path:u.pathname,bytes:0});});
    cdp.on('Network.loadingFinished',r=>{bytes+=r.encodedDataLength;if(requests.has(r.requestId))requests.get(r.requestId).bytes=r.encodedDataLength;});
    cdp.on('Network.loadingFailed',()=>{failed++;});
    const runs=[];
    for(const type of ['cold','warm']) {
      requests=new Map();bytes=0;failed=0;
      if(type==='cold')await page.goto(target,{waitUntil:'domcontentloaded',timeout:120000});
      else await page.reload({waitUntil:'domcontentloaded',timeout:120000});
      await page.waitForFunction(()=>window.__bibleFirstFrame>0,{timeout:120000});
      await page.waitForFunction(()=>!document.getElementById('app-loading'),{timeout:120000});
      const firstFrameMs=await page.evaluate(()=>window.__bibleFirstFrame);
      await page.waitForTimeout(1200);
      const rows=[...requests.values()].sort((a,b)=>b.bytes-a.bytes);
      runs.push({type,firstFrameMs,encodedNetworkBytes:bytes,failedRequests:failed,cspViolations:await page.evaluate(()=>window.__csp),pageErrors:[...pageErrors],resources:rows});
      if(type==='cold'){
        await page.screenshot({path:path.join(__dirname,`startup-${label}.png`),fullPage:false});
        await page.evaluate(async()=>{if('serviceWorker' in navigator)await navigator.serviceWorker.ready;});
      }
    }
    const result={target,label,viewport:'390x844',cpuSlowdown:4,latencyMs:150,downloadBytesPerSecond:200000,runs};
    fs.writeFileSync(path.join(__dirname,`startup-${label}.json`),JSON.stringify(result,null,2)+'\n');
    console.log(JSON.stringify({label,runs:runs.map(({type,firstFrameMs,encodedNetworkBytes,failedRequests})=>({type,firstFrameMs,encodedNetworkBytes,failedRequests}))}));
  } finally {await browser.close();}
})().catch(e=>{console.error('Browser benchmark failed:',e.message);process.exitCode=1;});
