'use strict';
const fs=require('node:fs'),path=require('node:path');
const {clients,project,quiet}=require('./lib/firebase_cli.cjs');
const repo=path.resolve(__dirname,'..'),number='765669491597',app='1:765669491597:web:af8d38bce20479fabe73c4';
const hosts=['mybibleplan.web.app','bible-plan-boshkamal-20261101.web.app'];
async function main() {
  if(process.argv.includes('--enforce'))throw Error('Enforcement is not authorized: monitoring only');
  const c=await clients();
  const {Client}=require(path.join(process.env.APPDATA,'npm/node_modules/firebase-tools/lib/apiv2'));
  const billing=new Client({urlPrefix:'https://cloudbilling.googleapis.com',apiVersion:'v1'});
  const info=await billing.get(`/projects/${project}/billingInfo`,quiet());
  if(info.body.billingEnabled)throw Error('This workflow requires the no-billing Spark project');
  const service=new Client({urlPrefix:'https://serviceusage.googleapis.com',apiVersion:'v1'});
  for (const api of ['recaptchaenterprise.googleapis.com','firebaseappcheck.googleapis.com']) {
    const name=`projects/${number}/services/${api}`;
    const status=await service.get(`/${name}`,quiet());
    if(status.body.state!=='ENABLED') {
      const operation=await service.post(`/${name}:enable`,{},quiet());
      if(operation.body.name) {
        for(let i=0;i<60;i++) {
          const result=await service.get(`/${operation.body.name}`,quiet());
          if(result.body.error)throw Error('Free service setup failed');
          if(result.body.done)break;
          await new Promise(r=>setTimeout(r,1000));
        }
      }
    }
  }
  const recaptcha=new Client({urlPrefix:'https://recaptchaenterprise.googleapis.com',apiVersion:'v1'});
  const existing=await recaptcha.get(`/projects/${project}/keys?pageSize=100`,quiet());
  let key=existing.body.keys?.find(k=>k.displayName==='My Bible Plan web protection');
  if(!key)key=(await recaptcha.post(`/projects/${project}/keys`,{displayName:'My Bible Plan web protection',
    webSettings:{allowedDomains:hosts,allowAllDomains:false,integrationType:'SCORE'}},quiet())).body;
  const siteKey=key.name.split('/').pop();
  const configName=`projects/${number}/apps/${app}/recaptchaEnterpriseConfig`;
  await c.appCheck.patch(`/${configName}?updateMask=siteKey,tokenTtl`,{name:configName,siteKey,tokenTtl:'86400s'},quiet());
  const serviceName=`projects/${number}/services/firestore.googleapis.com`;
  const mode='UNENFORCED';
  await c.appCheck.patch(`/${serviceName}?updateMask=enforcementMode`,{name:serviceName,enforcementMode:mode},quiet());
  const final=await c.appCheck.get(`/${serviceName}`,quiet());
  fs.writeFileSync(path.join(repo,'flutter_app/lib/core/app_check_config.dart'),
    `// Public site key, restricted to the two production hosts. Not a secret.\nconst kAppCheckSiteKey = '${siteKey}';\n`);
  const result={billingEnabled:false,provider:'reCAPTCHA Enterprise Essentials',siteKey,allowedDomains:hosts,
    tokenTtlSeconds:86400,enforcementMode:final.body.enforcementMode,
    freeLimit:'10,000 monthly assessments; requests fail at quota with billing disabled',updatedAt:new Date().toISOString()};
  fs.writeFileSync(path.join(repo,'security-audit/app-check-configured.json'),JSON.stringify(result,null,2)+'\n');
  console.log(JSON.stringify(result));
}
if(require.main===module)main().catch(e=>{console.error('App Check setup stopped; no billing changes performed.',e.status||e.name);process.exitCode=1;});
