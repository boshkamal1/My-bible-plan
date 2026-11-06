const {readFileSync}=require('node:fs');
const {test,before,after,beforeEach}=require('node:test');
const {initializeTestEnvironment,assertSucceeds:yes,assertFails:no}=require('@firebase/rules-unit-testing');
const {doc,collection,getDoc,getDocs,setDoc,updateDoc,deleteDoc,writeBatch,query,where,limit,serverTimestamp,Timestamp,deleteField}=require('firebase/firestore');
let env;
const setup={scope:'all',selectedBooks:[0,20,49],bookOrder:[49,20,0],reserveWithinDuration:true,
 ot:{b:-1,c:0,p:0},nt:{b:-1,c:0},skip:[75],mode:'seq',days:100,end:null,start:'2026-11-05',first:'2026-11-05'};
const member=(uid,status='pending',role='member')=>({uid,name:'Reader',status,role,done:0,streak:0,pct:0,readDay:''});
const db=(uid,claims={})=>uid?env.authenticatedContext(uid,{auth_time:Math.floor(Date.now()/1000),...claims}).firestore():env.unauthenticatedContext().firestore();
const ref=(uid,path)=>doc(db(uid),path);
const seed=(path,data)=>env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),path),data));
const group=()=>seed('groups/ABC234',{name:'Study',owner:'owner',created:Timestamp.now(),closed:false,schemaVersion:2});
const seedMember=async(uid,status='pending',role='member')=>{await seed(`groups/ABC234/members/${uid}`,member(uid,status,role));await seed(`users/${uid}/groupLinks/ABC234`,{code:'ABC234',created:Timestamp.now()});};
const snapshot=(revision=1)=>({done:{},setup:null,t:1,hist:[],delays:[],pb:[],plan:null,plannerVersion:14,notes:{},hl:{},fav:[],secs:{},badgeDates:{},conflicts:{},contentHash:'a'.repeat(64),syncVersion:2,revision,updatedAt:serverTimestamp()});
async function addMember(uid,status='pending',role='member') {
 const d=db(uid),b=writeBatch(d);b.set(doc(d,`groups/ABC234/members/${uid}`),member(uid,status,role));
 b.set(doc(d,`users/${uid}/groupLinks/ABC234`),{code:'ABC234',created:serverTimestamp()});return b.commit();
}
async function createGroup(code='ABC234',owner='owner',extra={}) {
 const d=db(owner),b=writeBatch(d);b.set(doc(d,`users/${owner}/security/groupLimits`),{codes:{[code]:true},last:code});
 b.set(doc(d,`groups/${code}`),{name:'Study',owner,created:serverTimestamp(),closed:false,schemaVersion:2,...extra});return b.commit();
}
async function markDeleting(uid='owner') {return setDoc(ref(uid,`users/${uid}/security/lifecycle`),{state:'deleting',requestedAt:serverTimestamp()});}
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-bible-rules',firestore:{host:'127.0.0.1',port:8187,rules:readFileSync(require('node:path').join(__dirname,'../firestore.rules'),'utf8')}});});
beforeEach(async()=>env.clearFirestore());after(async()=>env?.cleanup());

test('v2 client create, private plan, join, approve, stats, index and leave',async()=>{
 await yes(createGroup());await yes(setDoc(ref('owner','groups/ABC234/private/plan'),{setup}));
 await yes(addMember('owner','approved','admin'));await yes(getDoc(ref('reader','groups/ABC234')));
 await yes(addMember('reader'));await no(getDoc(ref('reader','groups/ABC234/private/plan')));
 await no(getDocs(collection(db('reader'),'groups/ABC234/members')));
 await yes(updateDoc(ref('owner','groups/ABC234/members/reader'),{status:'approved'}));
 await yes(getDoc(ref('reader','groups/ABC234/private/plan')));
 await yes(updateDoc(ref('reader','groups/ABC234/members/reader'),{done:10,pct:1,streak:2,readDay:'2026-11-05',updated:serverTimestamp()}));
 await yes(getDocs(collection(db('reader'),'groups/ABC234/members')));
 await yes(getDocs(query(collection(db('reader'),'users/reader/groupLinks'),limit(100))));
 const d=db('reader'),b=writeBatch(d);b.delete(doc(d,'groups/ABC234/members/reader'));b.delete(doc(d,'users/reader/groupLinks/ABC234'));await yes(b.commit());
});
test('join preview contains no plan and unapproved or rejected users cannot read private plan',async()=>{
 await group();await seed('groups/ABC234/private/plan',{setup});
 for(const uid of ['outsider','pending','rejected']) {
  if(uid!=='outsider')await seedMember(uid,uid==='pending'?'pending':'rejected');
  const preview=await yes(getDoc(ref(uid,'groups/ABC234')));if('setup' in preview.data())throw Error('plan leaked');
  await no(getDoc(ref(uid,'groups/ABC234/private/plan')));
  await no(getDocs(collection(db(uid),'groups/ABC234/private')));
 }
 await no(getDoc(ref(null,'groups/ABC234')));
});
test('private snapshots enforce identity schema bounds revisions and reject legacy overwrite',async()=>{
 const r=ref('reader','users/reader');await yes(setDoc(r,snapshot()));await yes(updateDoc(r,snapshot(2)));
 for(const uid of [null,'other']) {await no(getDoc(ref(uid,'users/reader')));await no(setDoc(ref(uid,'users/reader'),snapshot(3)));await no(deleteDoc(ref(uid,'users/reader')));}
 for(const bad of [{revision:2},{notes:[]},{contentHash:'x'.repeat(65)},{role:'admin'},{syncVersion:1},{updatedAt:Timestamp.fromMillis(0)}]) await no(updateDoc(r,{...snapshot(3),...bad}));
 await no(setDoc(r,{done:{},setup:null,t:1}));await no(deleteDoc(r));await no(getDocs(collection(db('reader'),'users')));
});
test('group Setup accepts actual app shape on create and update; malformed fields fail both',async()=>{
 await group();const r=ref('owner','groups/ABC234/private/plan');await yes(setDoc(r,{setup}));
 const invalid=[{ot:{b:100,c:0,p:0}},{nt:{b:4,c:1}},{start:'2026-99-99'},{start:'2025-02-29'},{end:'2026-02-30'},
  {selectedBooks:[76]},{skip:['0']},{skip:[1,1]},{bookOrder:[0,0]},{reserveWithinDuration:'yes'},{days:3651},{admin:true}];
 for(const change of invalid) {await no(setDoc(r,{setup:{...setup,...change}}));await no(updateDoc(r,{setup:{...setup,...change}}));}
 await yes(setDoc(r,{setup:{...setup,start:'2024-02-29',first:'2024-02-29',skip:[49,75]}}));
});
test('group owner and creation time immutable; plans cannot return to preview documents',async()=>{
 await group();const r=ref('owner','groups/ABC234');await yes(updateDoc(r,{name:'Renamed'}));
 for(const bad of [{owner:'other'},{created:Timestamp.fromMillis(0)},{setup},{name:'x'.repeat(61)},{closed:true},{schemaVersion:1}])await no(updateDoc(r,bad));
 await no(deleteDoc(r));await no(createGroup('XYZ234','reader',{owner:'owner'}));
});
test('roles cannot self escalate; rejected admins and ordinary members cannot change others',async()=>{
 await group();await seedMember('reader','approved');await seedMember('other');await seedMember('owner','approved','admin');
 await no(updateDoc(ref('reader','groups/ABC234/members/reader'),{role:'admin'}));
 await no(updateDoc(ref('reader','groups/ABC234/members/other'),{status:'approved'}));
 await seedMember('badadmin','rejected','admin');await no(updateDoc(ref('badadmin','groups/ABC234/members/other'),{status:'approved'}));
 await seedMember('admin','approved','admin');await yes(updateDoc(ref('admin','groups/ABC234/members/other'),{status:'approved'}));
 await no(updateDoc(ref('admin','groups/ABC234/members/owner'),{role:'member'}));
 await no(updateDoc(ref('admin','groups/ABC234/members/other'),{done:99}));
});
test('membership creation is coupled to the private index; invalid values and omitted role fail',async()=>{
 await group();await no(setDoc(ref('reader','groups/ABC234/members/reader'),member('reader')));
 await no(addMember('reader','approved','admin'));await yes(addMember('reader'));
 const r=ref('reader','groups/ABC234/members/reader');
 for(const bad of [{uid:'other'},{role:deleteField()},{status:deleteField()},{name:'x'.repeat(101)},{pct:101},{done:-1},{readDay:'2026-02-30'},{extra:true}])await no(updateDoc(r,bad));
 await no(deleteDoc(ref('reader','users/reader/groupLinks/ABC234')));
 await no(getDocs(query(collection(db('other'),'users/reader/groupLinks'),limit(100))));
});
test('orphan ACLs are inert without a parent; existing parents cannot be deleted or replaced',async()=>{
 await seed('groups/ABC234/members/attacker',member('attacker','approved','admin'));
 await no(getDoc(ref('attacker','groups/ABC234/members/attacker')));
 await no(getDocs(collection(db('attacker'),'groups/ABC234/members')));
 await no(updateDoc(ref('attacker','groups/ABC234/members/attacker'),{done:1}));
 await group();await no(deleteDoc(ref('owner','groups/ABC234')));await no(createGroup('ABC234','attacker'));
});
test('deletion needs fresh reauth; tombstone blocks writes and resurrection permanently',async()=>{
 await yes(setDoc(ref('reader','users/reader'),snapshot()));
 const stale=doc(db('reader',{auth_time:0}),'users/reader/security/lifecycle');
 await no(setDoc(stale,{state:'deleting',requestedAt:serverTimestamp()}));
 await yes(getDoc(ref('reader','users/reader')));await yes(markDeleting('reader'));
 await no(setDoc(ref('reader','users/reader'),snapshot(2)));await yes(deleteDoc(ref('reader','users/reader')));
 await no(setDoc(ref('reader','users/reader'),snapshot()));
 await no(deleteDoc(ref('reader','users/reader/security/lifecycle')));
 await no(updateDoc(ref('reader','users/reader/security/lifecycle'),{state:'active'}));
 await yes(updateDoc(ref('reader','users/reader/security/lifecycle'),{state:'data-deleted'}));
});
test('account cleanup closes owned groups and atomically removes members and indexes',async()=>{
 await group();await seed('groups/ABC234/private/plan',{setup});await seedMember('owner','approved','admin');await seedMember('reader','approved');
 await yes(markDeleting());await yes(updateDoc(ref('owner','groups/ABC234'),{closed:true}));
 await no(getDoc(ref('reader','groups/ABC234/private/plan')));await no(getDoc(ref('reader','groups/ABC234')));
 const d=db('owner'),b=writeBatch(d);for(const uid of ['owner','reader']){b.delete(doc(d,`groups/ABC234/members/${uid}`));b.delete(doc(d,`users/${uid}/groupLinks/ABC234`));}await yes(b.commit());
 await yes(deleteDoc(ref('owner','groups/ABC234/private/plan')));
 await yes(updateDoc(ref('owner','groups/ABC234'),{name:'Deleted group'}));
 await no(deleteDoc(ref('owner','groups/ABC234')));await no(getDocs(query(collection(db('reader'),'groups'),where('owner','==','owner'),limit(100))));
});
test('group quota reservation cannot be forged or reset; 21st created group denied',async()=>{
 await no(setDoc(ref('owner','users/owner/security/groupLimits'),{codes:{ABC234:true},last:'ABC234'}));
 const chars='ABCDEFGHJKLMNPQRSTUVWXYZ',codes={};for(let i=0;i<20;i++){const code='AAA'+chars[i].repeat(3);codes[code]=true;await seed(`groups/${code}`,{name:'Study',owner:'owner',created:Timestamp.now(),closed:false,schemaVersion:2});}
 await seed('users/owner/security/groupLimits',{codes,last:Object.keys(codes)[0]});
 const d=db('owner'),b=writeBatch(d);b.set(doc(d,'users/owner/security/groupLimits'),{codes:{...codes,ZZZZZZ:true},last:'ZZZZZZ'});b.set(doc(d,'groups/ZZZZZZ'),{name:'Study',owner:'owner',created:serverTimestamp(),closed:false,schemaVersion:2});await no(b.commit());
 await no(deleteDoc(ref('owner','users/owner/security/groupLimits')));
});
const subscription=endpoint=>({subscription:{endpoint,expirationTime:null,keys:{p256dh:'A'.repeat(87),auth:'A'.repeat(22)}},zone:'Africa/Cairo',hour:8,minute:0,enabled:true,nextAt:Timestamp.now()});
test('push providers, SSRF guards, ownership and bounded device reservations',async()=>{
 const uid='reader',id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',d=db(uid),b=writeBatch(d),r=doc(d,`pushSubscriptions/${uid}/devices/${id}`);
 b.set(doc(d,`users/${uid}/security/deviceLimits`),{ids:{[id]:true},last:id});b.set(r,subscription('https://fcm.googleapis.com/send/token'));await yes(b.commit());
 for(const host of ['updates.push.services.mozilla.com','web.push.apple.com','wns.notify.windows.com'])await yes(setDoc(r,subscription(`https://${host}/token`)));
 for(const endpoint of ['https://127.0.0.1/x','https://evil.example/x','https://fcm.googleapis.com.evil.example/x','https://fcm.googleapis.com@evil.example/x','http://fcm.googleapis.com/x','https://fcm.googleapis.com/a b','https://fcm.googleapis.com/x#fragment'])await no(setDoc(r,subscription(endpoint)));
 await no(updateDoc(r,{'subscription.keys.auth':'x'}));await no(getDoc(ref('other',`pushSubscriptions/${uid}/devices/${id}`)));
 await yes(getDocs(query(collection(d,`pushSubscriptions/${uid}/devices`),limit(100))));await yes(deleteDoc(r));
});


test('group cleanup resumes safely in batches within rule access limits',async()=>{
 await group();await seed('groups/ABC234/private/plan',{setup});
 for(let i=0;i<12;i++)await seedMember('member'+i,'approved');
 await markDeleting();await yes(updateDoc(ref('owner','groups/ABC234'),{closed:true}));
 const d=db('owner');let removed=0;
 while(true){
  const rows=await yes(getDocs(query(collection(d,'groups/ABC234/members'),limit(5))));
  if(rows.empty)break;
  const batch=writeBatch(d);
  for(const row of rows.docs){batch.delete(row.ref);batch.delete(doc(d,`users/${row.id}/groupLinks/ABC234`));}
  await yes(batch.commit());removed+=rows.size;
  // The deletion marker also blocks writes between interrupted cleanup steps.
  await no(setDoc(ref('owner','users/owner'),snapshot()));
 }
 if(removed!==12)throw Error('Incomplete cleanup');
 await yes(deleteDoc(ref('owner','groups/ABC234/private/plan')));
 await yes(updateDoc(ref('owner','groups/ABC234'),{name:'Deleted group'}));
 await no(getDoc(ref('member0','groups/ABC234')));
});


test('current full private snapshot with all book selectors and valid pointers fits rule budget',async()=>{
 const all=Array.from({length:76},(_,i)=>i);
 const current={...setup,selectedBooks:all,bookOrder:[...all].reverse(),skip:[],ot:{b:20,c:151,p:151},nt:{b:75,c:22}};
 const r=ref('reader','users/reader');
 await yes(setDoc(r,{...snapshot(),setup:current,plan:Array(93).fill('0:1')}));
 await yes(updateDoc(r,{...snapshot(2),setup:current,plan:Array(93).fill('0:1')}));
 await group();await yes(setDoc(ref('owner','groups/ABC234/private/plan'),{setup:current}));
});


test('legacy preview containing a plan is denied during the migration window',async()=>{
 await seed('groups/ABC234',{name:'Legacy',owner:'owner',created:Timestamp.now(),setup});
 await seedMember('reader','approved');
 for(const uid of ['outsider','reader'])await no(getDoc(ref(uid,'groups/ABC234')));
});
