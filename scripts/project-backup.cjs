'use strict';
// Encrypted streaming export. No user records, hashes, keys or plaintext files
// are logged. The machine key is DPAPI-protected outside the repository/OneDrive.
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const {spawnSync}=require('node:child_process');
const readline=require('node:readline');
const {clients,project,quiet}=require('./lib/firebase_cli.cjs');
const repo=path.resolve(__dirname,'..');
const backupDir=path.join(process.env.LOCALAPPDATA,'MyBiblePlan','Backups');
const keyDir=path.join(process.env.LOCALAPPDATA,'MyBiblePlan','BackupKeys');
const keyFile=path.join(keyDir,`${project}.dpapi`);
function dpapi(bytes,protect) {
  const operation=protect?'Protect':'Unprotect';
  const script=`Add-Type -AssemblyName System.Security; $b=[Convert]::FromBase64String([Console]::In.ReadToEnd()); [Console]::Write([Convert]::ToBase64String([Security.Cryptography.ProtectedData]::${operation}($b,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)))`;
  const result=spawnSync('powershell.exe',['-NoProfile','-NonInteractive','-Command',script],{input:bytes.toString('base64'),encoding:'utf8',windowsHide:true});
  if(result.status!==0)throw Error('Windows backup key protection failed');
  return Buffer.from(result.stdout.trim(),'base64');
}
function machineKey(create=false) {
  if(!fs.existsSync(keyFile)) {
    if(!create)throw Error('The separate backup key is required');
    fs.mkdirSync(keyDir,{recursive:true});
    fs.writeFileSync(keyFile,dpapi(crypto.randomBytes(32),true),{flag:'wx',mode:0o600});
  }
  const key=dpapi(fs.readFileSync(keyFile),false);
  if(key.length!==32)throw Error('Invalid backup key');
  return key;
}
function header(file) {
  const fd=fs.openSync(file,'r'),first=Buffer.alloc(2048);
  const count=fs.readSync(fd,first,0,first.length,0);fs.closeSync(fd);
  const end=first.subarray(0,count).indexOf(10);
  if(end<0)throw Error('Invalid backup header');
  const bytes=first.subarray(0,end+1),data=JSON.parse(bytes.toString());
  if(data.format!=='mybibleplan-project-backup' || data.version!==1 || data.project!==project || data.algorithm!=='AES-256-GCM')throw Error('Unsupported backup');
  return {data,bytes,start:end+1};
}
async function* records(file) {
  const h=header(file),size=fs.statSync(file).size;
  if(size<h.start+17)throw Error('Incomplete backup');
  const fd=fs.openSync(file,'r'),tag=Buffer.alloc(16);fs.readSync(fd,tag,0,16,size-16);fs.closeSync(fd);
  function decrypt() {
    const decipher=crypto.createDecipheriv('aes-256-gcm',machineKey(),Buffer.from(h.data.nonce,'base64'));
    decipher.setAAD(h.bytes);decipher.setAuthTag(tag);
    return fs.createReadStream(file,{start:h.start,end:size-17}).pipe(decipher);
  }
  // Verify authentication before any recovered record can be used for a write.
  for await(const chunk of decrypt()){ /* authenticated integrity pass */ }
  const lines=readline.createInterface({input:decrypt(),crlfDelay:Infinity});
  for await(const line of lines)if(line)yield JSON.parse(line);
}
async function backup() {
  fs.mkdirSync(backupDir,{recursive:true});
  const c=await clients(),nonce=crypto.randomBytes(12);
  const bytes=Buffer.from(JSON.stringify({format:'mybibleplan-project-backup',version:1,project,
    algorithm:'AES-256-GCM',nonce:nonce.toString('base64')})+'\n');
  const name=`${new Date().toISOString().replace(/[:.]/g,'-')}.bpbak`;
  const partial=path.join(backupDir,name+'.partial'),final=path.join(backupDir,name);
  const fd=fs.openSync(partial,'wx',0o600),cipher=crypto.createCipheriv('aes-256-gcm',machineKey(true),nonce);
  cipher.setAAD(bytes);fs.writeSync(fd,bytes);
  const write=record=>fs.writeSync(fd,cipher.update(JSON.stringify(record)+'\n','utf8'));
  const manifest={project,createdAt:new Date().toISOString(),version:1};
  write({kind:'manifest',...manifest});
  let documents=0,missingParents=0,users=0,passwordHashes=0,stage='firestore-collections';
  const prefix=`projects/${project}/databases/(default)/documents`;
  async function visit(parent) {
    let pageToken;
    do {
      stage='firestore-collections';
      const response=await c.firestore.post(`/${parent}:listCollectionIds`,{pageSize:100,...(pageToken?{pageToken}:{})},quiet());
      for(const collection of response.body.collectionIds||[]) {
        let nextPageToken;
        do {
          const query=new URLSearchParams({pageSize:'100',showMissing:'true',...(nextPageToken?{pageToken:nextPageToken}:{})});
          stage='firestore-documents';
          const r=await c.firestore.get(`/${parent}/${encodeURIComponent(collection)}?${query}`,quiet());
          for(const doc of r.body.documents||[]) {
            if(++documents>20000)throw Error('Backup document safety limit reached');
            if(doc.createTime || doc.fields)write({kind:'firestore',document:doc});
            else {missingParents++;write({kind:'missing-parent',name:doc.name});}
            await visit(doc.name);
          }
          nextPageToken=r.body.nextPageToken;
        }while(nextPageToken);
      }
      pageToken=response.body.nextPageToken;
    }while(pageToken);
  }
  try {
    await visit(prefix);
    stage='auth-users';
    let nextPageToken;
    do {
      const query=new URLSearchParams({maxResults:'1000',...(nextPageToken?{nextPageToken}:{})});
      const r=await c.auth.get(`/projects/${project}/accounts:batchGet?${query}`,quiet());
      for(const user of r.body.users||[]){users++;if(user.passwordHash)passwordHashes++;write({kind:'auth-user',user});}
      nextPageToken=r.body.nextPageToken;
    }while(nextPageToken);
    stage='auth-config';
    const config=await c.authConfig.get(`/projects/${project}/config`,quiet());
    write({kind:'auth-config',config:config.body});
    stage='rules';
    const releases=await c.rules.listAllReleases(project);
    for(const release of releases){write({kind:'rules',release,files:await c.rules.getRulesetContent(release.rulesetName)});}
    write({kind:'summary',documents,missingParents,users,passwordHashes});
    fs.writeSync(fd,cipher.final());fs.writeSync(fd,cipher.getAuthTag());fs.closeSync(fd);
    fs.renameSync(partial,final);
  } catch(error) {try{fs.closeSync(fd);}catch{} const failure=Error('Encrypted backup did not complete; no source data changed'); failure.safeStage=stage; failure.safeCode=error.status||error.code||error.name; failure.safeFrames=String(error.stack).split('\n').slice(1,3).join('\n'); throw failure;}
  let verified=0;
  for await(const record of records(final))if(record.kind==='firestore')verified++;
  const digest=crypto.createHash('sha256');for await(const chunk of fs.createReadStream(final))digest.update(chunk);
  const summary={...manifest,file:final,sha256:digest.digest('hex'),documents:verified,missingParents,users,passwordHashes,
    integrityVerified:true,keyProtection:'Windows DPAPI CurrentUser; separate from exported file'};
  fs.writeFileSync(path.join(backupDir,name+'.manifest.json'),JSON.stringify(summary,null,2)+'\n');
  fs.mkdirSync(path.join(repo,'security-audit'),{recursive:true});
  fs.writeFileSync(path.join(repo,'security-audit/project-backup-summary.json'),JSON.stringify(summary,null,2)+'\n');
  console.log(JSON.stringify(summary));return final;
}
async function verifyRestore(file) {
  const endpoint='http://127.0.0.1:8187/v1/projects/demo-bible-restore/databases/(default)/documents/';
  const original=`projects/${project}/databases/(default)/documents/`;
  const canonical=v=>Array.isArray(v)?v.map(canonical):v&&typeof v==='object'?Object.fromEntries(Object.keys(v).sort().map(k=>[k,canonical(v[k])])):v;
  let count=0,auth=0,config=false,authHashRecoveryParametersPresent=false;
  for await(const record of records(file)) {
    if(record.kind==='auth-user'){auth++;continue;}
    if(record.kind==='auth-config'){config=true;const h=record.config?.signIn?.hashConfig;authHashRecoveryParametersPresent=!!(h?.algorithm&&h?.signerKey&&h?.saltSeparator&&h?.rounds!==undefined&&h?.memoryCost!==undefined);continue;}
    if(record.kind!=='firestore')continue;
    if(!record.document.name.startsWith(original))throw Error('Out-of-project path');
    const target=endpoint+record.document.name.slice(original.length).split('/').map(encodeURIComponent).join('/');
    const restored=await fetch(target,{method:'PATCH',headers:{'content-type':'application/json'},body:JSON.stringify({fields:record.document.fields||{}})});
    if(!restored.ok)throw Error('Local restore write failed');
    const read=await fetch(target);if(!read.ok)throw Error('Local restore read failed');
    const back=await read.json();
    if(JSON.stringify(canonical(back.fields||{}))!==JSON.stringify(canonical(record.document.fields||{})))throw Error('Restored document mismatch');
    count++;
  }
  const hash=crypto.createHash('sha256');for await(const chunk of fs.createReadStream(file))hash.update(chunk);
  const result={backupSha256:hash.digest('hex'),verifiedFirestoreDocuments:count,authRecordsIntegrityChecked:auth,authConfigPresent:config,authHashRecoveryParametersPresent,
    firestoreRestoreVerified:true,authImportExecuted:false,target:'local demo-bible-restore only'};
  fs.writeFileSync(path.join(repo,'security-audit/project-restore-verification.json'),JSON.stringify(result,null,2)+'\n');
  console.log(JSON.stringify(result));
}
if(require.main===module){
  const command=process.argv[2]||'backup';
  (command==='backup'?backup():command==='verify-local'&&process.argv[3]?verifyRestore(path.resolve(process.argv[3])):Promise.reject(Error('Use backup or verify-local <file>')))
    .catch(error=>{console.error('Project backup/verification failed; no live data was changed.',error.safeStage||'setup',error.safeCode||error.name);console.error(error.safeFrames||String(error.stack).split('\n').slice(1,3).join('\n'));process.exitCode=1;});
}
module.exports={backup,records,project};
