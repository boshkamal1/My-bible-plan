const { readFileSync } = require('node:fs');
const { test, before, after, beforeEach } = require('node:test');
const { initializeTestEnvironment, assertSucceeds: yes, assertFails: no } = require('@firebase/rules-unit-testing');
const { doc, collection, getDoc, getDocs, setDoc, updateDoc, deleteDoc, serverTimestamp, Timestamp, deleteField } = require('firebase/firestore');
let env;
const setup = {scope:'all', ot:{b:-1,c:0,p:0},nt:{b:-1,c:0},skip:[0,6],mode:'mix',days:365,end:null,start:'2026-11-04',first:'2026-11-04'};
const member = (status='pending', role='member') => ({name:'Reader',status,role,done:0,streak:0,pct:0,readDay:''});
const db = uid => uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
const ref = (uid,path) => doc(db(uid),path);
const seed = async (path,data) => env.withSecurityRulesDisabled(c => setDoc(doc(c.firestore(),path),data));
const group = () => seed('groups/ABC234',{name:'Study',owner:'owner',setup,created:Timestamp.now()});
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-bible-rules',firestore:{host:'127.0.0.1',port:8187,rules:readFileSync(require('node:path').join(__dirname,'../firestore.rules'),'utf8')}});});
beforeEach(async()=>env.clearFirestore());
after(async()=>env?.cleanup());
test('client create, join, review, stats, list, leave flows',async()=>{
 await yes(setDoc(ref('owner','groups/ABC234'),{name:'Study',owner:'owner',setup,created:serverTimestamp()}));
 await yes(setDoc(ref('owner','groups/ABC234/members/owner'),member('approved','admin')));
 await yes(getDoc(ref('reader','groups/ABC234')));
 await yes(setDoc(ref('reader','groups/ABC234/members/reader'),member()));
 await no(getDocs(collection(db('reader'),'groups/ABC234/members')));
 await yes(updateDoc(ref('owner','groups/ABC234/members/reader'),{status:'approved'}));
 await yes(setDoc(ref('reader','groups/ABC234/members/reader'),{done:10,pct:1,streak:2,readDay:'2026-11-04',updated:serverTimestamp()},{merge:true}));
 await yes(getDocs(collection(db('reader'),'groups/ABC234/members')));
 await yes(deleteDoc(ref('reader','groups/ABC234/members/reader')));
});
test('orphan ACL cannot read/list/write and client cannot delete parent to reuse code',async()=>{
 await seed('groups/ABC234/members/attacker',member('approved','admin'));
 await no(getDocs(collection(db('attacker'),'groups/ABC234/members')));
 await no(getDoc(ref('attacker','groups/ABC234/members/attacker')));
 await no(updateDoc(ref('attacker','groups/ABC234/members/attacker'),{done:1}));
 await no(setDoc(ref('reader','groups/ABC234/members/reader'),member()));
 await group();
 await no(deleteDoc(ref('owner','groups/ABC234')));
 await no(setDoc(ref('attacker','groups/ABC234'),{name:'Takeover',owner:'attacker',setup,created:serverTimestamp()}));
 await yes(deleteDoc(ref('attacker','groups/ABC234/members/attacker')));
});
test('missing status fails closed, roles cannot self escalate, owner protected',async()=>{
 await group(); const legacy=member('approved','admin'); delete legacy.status;
 await seed('groups/ABC234/members/legacy',legacy);
 await no(getDocs(collection(db('legacy'),'groups/ABC234/members')));
 await seed('groups/ABC234/members/reader',member());
 await no(updateDoc(ref('reader','groups/ABC234/members/reader'),{status:'approved',role:'admin'}));
 await no(updateDoc(ref('legacy','groups/ABC234/members/reader'),{status:'approved'}));
 await seed('groups/ABC234/members/admin',member('approved','admin'));
 await seed('groups/ABC234/members/owner',member('approved','admin'));
 await no(updateDoc(ref('admin','groups/ABC234/members/owner'),{status:'rejected'}));
 await yes(updateDoc(ref('admin','groups/ABC234/members/reader'),{status:'approved'}));
 await no(updateDoc(ref('admin','groups/ABC234/members/reader'),{done:100}));
});
test('private legacy and current reading sync, ownership and schema',async()=>{
 const r=ref('reader','users/reader');
 await yes(setDoc(r,{done:{'gen-1':'2026-11-04'},setup:null,t:1}));
 await yes(updateDoc(r,{setup,hist:['2026-11-04'],notes:{'gen-1':'Note'},hl:{'gen-1':2},fav:['gen-1'],secs:{'gen-1':10},badgeDates:{},delays:[],pb:[],plan:['gen-1,gen-2'],plannerVersion:14}));
 await no(getDoc(ref('other','users/reader')));
 await no(setDoc(ref('other','users/reader'),{done:{},setup:null,t:1}));
 await no(getDocs(collection(db('reader'),'users')));
 for(const invalid of [{t:'bad'},{done:[]},{notes:'bad'},{admin:true},{setup:deleteField()}]) await no(updateDoc(r,invalid));
 await yes(deleteDoc(r));
});
test('unauthenticated, unknown paths and group enumeration denied',async()=>{
 await group();
 await no(getDoc(ref(null,'groups/ABC234')));
 await no(getDocs(collection(db(null),'groups')));
 await no(getDocs(collection(db('reader'),'groups')));
 await no(setDoc(ref('reader','unknown/x'),{x:1}));
});
test('group owner/created immutable and nested validation applies on update',async()=>{
 await group(); const r=ref('owner','groups/ABC234');
 await yes(updateDoc(r,{name:'Renamed'}));
 for(const invalid of [{owner:'other'},{created:Timestamp.fromMillis(0)},{name:'x'.repeat(61)},{setup:{...setup,skip:['0']}},{setup:{...setup,days:-1}},{setup:{...setup,ot:{b:'bad',c:0,p:0}}}]) await no(updateDoc(r,invalid));
 await no(setDoc(ref('reader','groups/XYZ234'),{name:'Bad',owner:'owner',setup,created:serverTimestamp()}));
});
test('member create and update reject malformed data and omitted status',async()=>{
 await group(); const r=ref('reader','groups/ABC234/members/reader');
 await no(setDoc(r,{...member(),status: 'approved'}));
 await yes(setDoc(r,member()));
 for(const invalid of [{status:deleteField()},{role:deleteField()},{name:'x'.repeat(101)},{done:-1},{done:40001},{pct:101},{streak:'1'},{readDay:'x'.repeat(100)},{updated:'bad'},{extra:true}]) await no(updateDoc(r,invalid));
});
const subscription = endpoint => ({subscription:{endpoint,expirationTime:null,keys:{p256dh:'A'.repeat(87),auth:'A'.repeat(22)}},zone:'Africa/Cairo',hour:8,minute:0,enabled:true,nextAt:Timestamp.now()});
test('push providers accepted; SSRF hosts, spoofed authorities, malformed keys denied',async()=>{
 const r=ref('reader','pushSubscriptions/reader/devices/device');
 for(const host of ['fcm.googleapis.com','updates.push.services.mozilla.com','web.push.apple.com','wns.notify.windows.com']) await yes(setDoc(r,subscription(`https://${host}/send/token`)));
 for(const endpoint of ['https://127.0.0.1/x','https://evil.example/x','https://other.push.services.mozilla.com/x','https://fcm.googleapis.com.evil.example/x','https://fcm.googleapis.com@evil.example/x','https://fcm.googleapis.com:443/x','http://fcm.googleapis.com/x','https://fcm.googleapis.com/a b','https://fcm.googleapis.com/x#fragment']) await no(setDoc(r,subscription(endpoint)));
 await no(updateDoc(r,{'subscription.keys.auth':'x'}));
 await no(updateDoc(r,{'subscription.keys.extra':'x'}));
 await no(updateDoc(r,{hour:24}));
 await no(getDoc(ref('other','pushSubscriptions/reader/devices/device')));
 await yes(deleteDoc(r));
});
