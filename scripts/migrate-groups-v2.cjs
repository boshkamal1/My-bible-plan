'use strict';
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const {spawnSync}=require('node:child_process');
const {records,project}=require('./project-backup.cjs');
const {clients,quiet}=require('./lib/firebase_cli.cjs');
const repo=path.resolve(__dirname,'..');
const prefix=`projects/${project}/databases/(default)/documents/`;
function decode(v) {
  if('nullValue'in v)return null;if('stringValue'in v)return v.stringValue;
  if('integerValue'in v)return Number(v.integerValue);if('doubleValue'in v)return v.doubleValue;
  if('booleanValue'in v)return v.booleanValue;if('timestampValue'in v)return v.timestampValue;
  if('arrayValue'in v)return(v.arrayValue.values||[]).map(decode);
  if('mapValue'in v)return Object.fromEntries(Object.entries(v.mapValue.fields||{}).map(([k,x])=>[k,decode(x)]));
  throw Error('Unsupported source value; migration stopped');
}
function encode(v) {
  if(v===null)return{nullValue:null};if(typeof v==='string')return{stringValue:v};
  if(typeof v==='boolean')return{booleanValue:v};if(typeof v==='number')return{integerValue:String(v)};
  if(Array.isArray(v))return{arrayValue:{values:v.map(encode)}};
  return{mapValue:{fields:Object.fromEntries(Object.entries(v).map(([k,x])=>[k,encode(x)]))}};
}
const fields=value=>Object.fromEntries(Object.entries(value).map(([k,v])=>[k,encode(v)]));
const digest=async file=>{const h=crypto.createHash('sha256');for await(const c of fs.createReadStream(file))h.update(c);return h.digest('hex');};
async function prepare(file) {
  const documents=new Map();
  for await(const r of records(file))if(r.kind==='firestore')documents.set(r.document.name,r.document);
  const groups=[...documents.values()].filter(d=>/^groups\/[^/]+$/.test(d.name.slice(prefix.length)));
  const legacy=groups.filter(d=>decode(d.fields.schemaVersion||{integerValue:'1'})!==2);
  const input=[];
  for(const doc of documents.values())if(/^users\/[^/]+$/.test(doc.name.slice(prefix.length)))input.push({kind:'user',data:Object.fromEntries(Object.entries(doc.fields||{}).map(([k,v])=>[k,decode(v)]))});
  legacy.forEach((g,index)=>input.push({kind:'group',index,setup:decode(g.fields.setup)}));
  const located=spawnSync('where.exe',['dart'],{encoding:'utf8',windowsHide:true});
  const batch=located.stdout.trim().split(/\r?\n/).find(p=>p.endsWith('.bat'));
  if(!batch)throw Error('Dart SDK not found');
  const dart=path.join(path.dirname(batch),'cache/dart-sdk/bin/dart.exe');
  const validation=spawnSync(dart,['run','tools/validate_state_stream.dart'],{
    cwd:path.join(repo,'flutter_app'),input:input.map(v=>JSON.stringify(v)).join('\n')+'\n',encoding:'utf8',windowsHide:true,maxBuffer:16*1024*1024});
  const resultRow=validation.stdout.split(/\r?\n/).find(l=>l.includes('{"validatedUsers"'));
  const resultLine=resultRow?.slice(resultRow.indexOf('{"validatedUsers"'));
  if(!resultLine||validation.status!==0){
    const safe=resultLine?JSON.parse(resultLine):null;
    fs.writeFileSync(path.join(repo,'security-audit/migration-validation-summary.json'),JSON.stringify({
      processStatus:validation.status,validatedUsers:safe?.validatedUsers,invalidRecords:safe?.invalidRecords,
      issues:safe?.issues,compilerDiagnostic:safe?undefined:validation.stderr.slice(0,800)},null,2)+'\n');
    throw Error('Source validation failed; no changes made');
  }
  const validationResult=JSON.parse(resultLine);
  const writes=[];
  function put(name,value,rawFields={}) {
    const old=documents.get(name);
    writes.push({update:{name,fields:{...fields(value),...rawFields}},currentDocument:old?{updateTime:old.updateTime}:{exists:false}});
  }
  const owners=new Map();
  for(const group of groups) {
    const code=group.name.slice(prefix.length).split('/')[1],owner=decode(group.fields.owner);
    if(!/^[A-HJ-NP-Z2-9]{6}$/.test(code))throw Error('Legacy code needs manual review');
    if(!owners.has(owner))owners.set(owner,{});owners.get(owner)[code]=true;
  }
  legacy.forEach((group,index)=>{
    const name=group.name,code=name.slice(prefix.length).split('/')[1],owner=decode(group.fields.owner);
    const setup=validationResult.groups.find(g=>g.index===index)?.setup;
    if(!setup)throw Error('Validated setup missing');
    put(name,{name:decode(group.fields.name),owner,closed:false,schemaVersion:2},{created:group.fields.created});
    put(`${name}/private/plan`,{setup});
    const members=[...documents.values()].filter(d=>d.name.startsWith(`${name}/members/`)&&d.name.slice(`${name}/members/`.length).indexOf('/')<0);
    for(const member of members) {
      const uid=member.name.slice(`${name}/members/`.length);
      const next={...member.fields,uid:{stringValue:uid}};
      if(!next.status)next.status={stringValue:uid===owner?'approved':'pending'};
      if(!next.role)next.role={stringValue:uid===owner?'admin':'member'};
      writes.push({update:{name:member.name,fields:next},currentDocument:{updateTime:member.updateTime}});
      const link=`${prefix}users/${uid}/groupLinks/${code}`;
      if(!documents.has(link))put(link,{code},{created:group.fields.created});
    }
  });
  for(const [owner,codes]of owners) {
    if(Object.keys(codes).length>20)throw Error('Legacy group quota needs review before migration');
    const name=`${prefix}users/${owner}/security/groupLimits`;
    if(!documents.has(name))put(name,{codes,last:Object.keys(codes)[0]});
  }
  if(writes.length>400)throw Error('Migration exceeds reviewed atomic batch limit');
  return{writes,summary:{legacyGroups:legacy.length,validatedUserSnapshots:validationResult.validatedUsers,
    plannedWrites:writes.length,sourceDocuments:documents.size,backupSha256:await digest(file)}};
}
async function main() {
  const file=path.resolve(process.argv[2]||'');
  if(!fs.existsSync(file))throw Error('Provide the approved encrypted backup file');
  const prepared=await prepare(file);
  fs.writeFileSync(path.join(repo,'security-audit/groups-migration-dry-run.json'),JSON.stringify(prepared.summary,null,2)+'\n');
  if(!process.argv.includes('--apply')){console.log(JSON.stringify({...prepared.summary,applied:false}));return;}
  const verification=JSON.parse(fs.readFileSync(path.join(repo,'security-audit/project-restore-verification.json'),'utf8'));
  if(!verification.firestoreRestoreVerified||verification.backupSha256!==prepared.summary.backupSha256)throw Error('A matching verified local restore is required');
  const resultFile=path.join(repo,'security-audit/groups-migration-result.json');
  if(fs.existsSync(resultFile)) {
    const old=JSON.parse(fs.readFileSync(resultFile,'utf8'));
    if(old.applied&&old.backupSha256===prepared.summary.backupSha256){console.log('Migration already recorded; no writes repeated.');return;}
  }
  if(prepared.writes.length) {
    const c=await clients();
    await c.firestore.post(`/projects/${project}/databases/(default)/documents:commit`,{writes:prepared.writes},quiet());
  }
  const result={...prepared.summary,applied:true,appliedAt:new Date().toISOString(),preconditions:'All updates require the backed-up updateTime; new paths require nonexistence.'};
  fs.writeFileSync(resultFile,JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result));
}
if(require.main===module)main().catch(()=>{console.error('Group migration stopped safely; review validation and preconditions. No sensitive records printed.');process.exitCode=1;});
module.exports={prepare,decode,encode};
