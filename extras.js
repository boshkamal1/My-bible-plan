(function(){
'use strict';
const EN=LANG==='en';
const D={
reader:['قراءة','Read'],stats:['الإنجاز','Progress'],more:['المزيد','More'],
search:['بحث','Search'],searchHint:['ابحث في النص…','Search the text…'],noRes:['مفيش نتائج','No results'],
notes:['ملاحظاتي','My notes'],fav:['المفضلة','Favorites'],hl:['التمييز','Highlights'],
plans:['خطط جاهزة','Ready plans'],groups:['المجموعات','Groups'],settings:['الإعدادات والحساب','Settings & account'],privacy:['سياسة الخصوصية','Privacy policy'],
close:['إغلاق','Close'],prev:['السابق','Previous'],next:['التالي','Next'],markDone:['تم القراءة','Mark as read'],done:['تمت','Done'],
listen:['استماع','Listen'],stop:['إيقاف','Stop'],tr:['الترجمة','Translation'],svd:['فان دايك','Van Dyck'],kjv:['KJV','KJV'],
fs:['حجم الخط','Font size'],note:['ملاحظة','Note'],copy:['نسخ','Copy'],share:['مشاركة','Share'],copied:['اتنسخ','Copied'],save:['حفظ','Save'],del:['حذف','Delete'],cancel:['إلغاء','Cancel'],
deutNote:['النص العربي لهذا السفر غير متاح، بيظهر KJV.','Arabic text unavailable here; showing KJV.'],
streak:['أيام متتالية','Day streak'],best:['أطول سلسلة','Best streak'],chRead:['أصحاحات مقروءة','Chapters read'],books:['أسفار كاملة','Books done'],
mins:['دقيقة قراءة','Reading minutes'],last30:['آخر ٣٠ يوم','Last 30 days'],badges:['الأوسمة','Badges'],shareProg:['شارك إنجازك','Share progress'],
rem:['تذكير يومي (والموقع مفتوح)','Daily reminder (while the site is open)'],risk:['تنبيه السلسلة المسائي','Evening streak alert'],remTime:['وقت التذكير','Reminder time'],
remNote:['التذكيرات في الموقع بتشتغل بس والموقع مفتوح.','Web reminders only fire while the site is open.'],
notifTitle:['وقت القراءة','Reading time'],notifBody:['قراية النهارده مستنياك','Today\'s reading is waiting'],riskTitle:['السلسلة في خطر','Streak at risk'],riskBody:['لسه ما قريتش النهارده.','You haven\'t read today.'],
account:['الحساب','Account'],signGoogle:['الدخول بحساب جوجل','Continue with Google'],email:['البريد','Email'],pass:['كلمة المرور','Password'],signIn:['دخول','Sign in'],register:['إنشاء حساب','Create account'],signOut:['خروج','Sign out'],
syncNow:['زامن الآن','Sync now'],synced:['اتزامن','Synced'],noCloud:['المزامنة السحابية مش مفعّلة (محتاج firebase-config.js).','Cloud sync is not configured (needs firebase-config.js).'],
delAcc:['حذف الحساب وبياناتي','Delete account and my data'],delConfirm:['هيتم حذف حسابك وبياناتك السحابية نهائيًا. متأكد؟','Your account and cloud data will be permanently deleted. Sure?'],
wipe:['مسح بيانات الجهاز (الملاحظات والتمييز)','Erase on-device notes & highlights'],wipeConfirm:['هتتمسح الملاحظات والتمييز والمفضلة من الجهاز. متأكد؟','Notes, highlights and favorites will be erased from this device. Sure?'],
dispName:['الاسم المعروض','Display name'],
createG:['إنشاء مجموعة','Create group'],joinG:['انضمام بكود','Join with code'],gName:['اسم المجموعة','Group name'],gCode:['كود المجموعة','Group code'],members:['الأعضاء','Members'],leave:['مغادرة','Leave'],useGPlan:['استخدم خطة المجموعة','Use group plan'],needSign:['سجّل الدخول الأول من الإعدادات.','Sign in first from Settings.'],
applyPlan:['تطبيق الخطة دي هيستبدل خطتك الحالية. متأكد؟','This replaces your current plan. Sure?'],applied:['اتطبقت الخطة','Plan applied'],
chapters:['أصحاح','chapters'],ps:['مزمور','Psalm'],
b_first:['أول أصحاح','First chapter'],b_s3:['٣ أيام متتالية','3-day streak'],b_s7:['أسبوع كامل','7-day streak'],b_s30:['شهر كامل','30-day streak'],b_s100:['١٠٠ يوم','100-day streak'],
b_c50:['٥٠ أصحاح','50 chapters'],b_c250:['٢٥٠ أصحاح','250 chapters'],b_c1000:['١٠٠٠ أصحاح','1000 chapters'],b_b1:['أول سفر كامل','First full book'],b_b10:['١٠ أسفار','10 books'],b_plan:['خلصت الخطة','Plan completed'],
cloudErr:['حصلت مشكلة','Something went wrong'],
};
const X=k=>{const v=D[k];return v?(EN?v[1]:v[0]):k};
const q=id=>document.getElementById(id);
const esc=s=>String(s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const nf=n=>{n=String(n);return EN?n:n.replace(/\d/g,d=>'٠١٢٣٤٥٦٧٨٩'[d])};
const HLC=['#ffe680','#a8e6a1','#a6d4ff','#ffb3c1'];
const XK='ot-extras-v1';
let E={notes:{},hl:{},fav:[],secs:{},hist:[],groups:[],set:{tr:EN?'kjv':'svd',fs:20,rem:false,rh:8,rm:0,risk:true,name:''}};
try{const r=JSON.parse(localStorage.getItem(XK)||'null');if(r){E=Object.assign(E,r);E.set=Object.assign({tr:EN?'kjv':'svd',fs:20,rem:false,rh:8,rm:0,risk:true,name:''},r.set||{})}}catch(e){}
const saveE=()=>{try{localStorage.setItem(XK,JSON.stringify(E))}catch(e){}};
const bump=()=>{S.t=Date.now();saveLocal();saveE();schedulePush()};
const bname=b=>BOOKS[b][0];

const css=document.createElement('style');
css.textContent=`
.xov{position:fixed;inset:0;z-index:60;background:var(--bg);overflow:auto;display:flex;flex-direction:column}
.xov[hidden]{display:none}
.xhead{position:sticky;top:0;z-index:2;background:var(--paper);border-bottom:1.5px solid var(--gold);display:flex;align-items:center;gap:8px;padding:10px 12px}
.xhead h2{flex:1;margin:0;font-family:var(--f-display);font-size:1.2rem;text-align:center}
.xbody{flex:1;width:100%;max-width:780px;margin-inline:auto;padding:14px 16px 90px}
.xfoot{position:sticky;bottom:0;background:var(--paper);border-top:1.5px solid var(--gold);display:flex;gap:8px;align-items:center;justify-content:center;padding:8px 12px}
.xb{font-family:var(--f-label);background:var(--paper2);color:var(--ink);border:1.5px solid var(--gold);border-radius:6px;padding:7px 12px;font-size:.92rem;cursor:pointer}
.xb.pri{background:var(--lapis);color:#fff;border-color:var(--lapis)}
.xb.on{background:var(--gold-soft)}
.xb:disabled{opacity:.4;cursor:not-allowed}
.xv{display:block;padding:6px 8px;margin:2px 0;border-radius:8px;cursor:pointer;line-height:1.9}
.xv:hover{background:var(--paper2)}
.xv .n{color:var(--gold);font-weight:700;font-size:.7em;margin-inline-end:8px}
.xv .nt{display:block;font-size:.8em;color:var(--ink2);font-style:italic}
.xv.pl{background:var(--gold-soft)}
.xnote{background:var(--gold-soft);border:1px solid var(--gold);border-radius:6px;padding:8px;text-align:center;font-size:.85rem;margin-bottom:10px}
.xsheet{position:fixed;inset-inline:0;bottom:0;z-index:70;background:var(--paper);border-top:2px solid var(--gold);border-radius:14px 14px 0 0;padding:14px 16px 22px;box-shadow:0 -8px 24px #0003}
.xsheet[hidden]{display:none}
.xsheet .r{display:flex;gap:8px;justify-content:center;flex-wrap:wrap;margin-top:10px}
.xdot{width:34px;height:34px;border-radius:50%;border:2px solid #0002;cursor:pointer}
.xdot.sel{border:3px solid #333}
.xgrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(100px,1fr));gap:10px}
.xc{background:var(--paper);border:1.5px solid var(--line);border-radius:10px;padding:12px 8px;text-align:center}
.xc b{display:block;font-size:1.5rem;color:var(--lapis)}
.xc small{color:var(--ink2)}
.xbadge{opacity:.3}.xbadge.on{opacity:1}
.xbadge .e{font-size:2rem}
.xlist button.item{display:block;width:100%;text-align:start;background:var(--paper);border:1.5px solid var(--line);border-radius:10px;padding:14px;margin:8px 0;font-family:var(--f-body);font-size:1.1rem;color:var(--ink);cursor:pointer}
.xlist .item small{display:block;color:var(--ink2)}
.xin{width:100%;font-family:var(--f-body);font-size:1rem;padding:9px;border:1.5px solid var(--gold);border-radius:6px;background:var(--paper);color:var(--ink);margin:4px 0}
.xrow{display:flex;gap:8px;flex-wrap:wrap;align-items:center;margin:8px 0}
.xh{color:var(--gold);font-family:var(--f-label);margin:18px 0 6px}
.xread{font-size:.8rem;margin-inline-start:8px;padding:1px 8px;background:var(--lapis-soft);border:1px solid var(--lapis);border-radius:10px;color:var(--lapis);cursor:pointer;vertical-align:middle}
.xhit{padding:10px;border-bottom:1px solid var(--line);cursor:pointer}
.xhit b{color:var(--gold)}
.xpre{white-space:pre-wrap;line-height:1.9}
`;
document.head.appendChild(css);
const dirAttr=EN?'ltr':'rtl';

const bookCache={};
async function fetchJ(p){try{const r=await fetch(p);if(!r.ok)return null;return await r.json()}catch(e){return null}}
async function loadBook(tr,b){
  const k=tr+'/'+b;
  if(k in bookCache)return bookCache[k];
  const j=await fetchJ('bible/'+tr+'/'+b+'.json');
  bookCache[k]=j;
  return j;
}
async function getChapter(b,c,tr){
  if(tr==='svd'){
    let bk=await loadBook('svd',b);
    if(!bk)bk=await loadBook('ar_extra',b);
    if(bk&&bk[c-1]&&bk[c-1].length)return{v:bk[c-1],tr:'svd',fb:false};
    const k=await loadBook('kjv',b);
    if(k&&k[c-1])return{v:k[c-1],tr:'kjv',fb:true};
    return null;
  }
  const k=await loadBook('kjv',b);
  if(k&&k[c-1])return{v:k[c-1],tr:'kjv',fb:false};
  return null;
}
const normAr=s=>s.replace(/[ً-ٰٟـ]/g,'').replace(/[أإآٱ]/g,'ا').replace(/ى/g,'ي').replace(/ة/g,'ه').toLowerCase();

function mkOverlay(id){
  let o=q(id);
  if(!o){o=document.createElement('div');o.id=id;o.className='xov';o.hidden=true;o.setAttribute('dir',dirAttr);document.body.appendChild(o)}
  return o;
}
function openOv(o){o.hidden=false;document.body.classList.add('lock')}
function closeOv(o){o.hidden=true;if(![...document.querySelectorAll('.xov')].some(x=>!x.hidden))document.body.classList.remove('lock')}

let rd={b:0,c:1,queue:null,tr:E.set.tr,data:null,sv:null,t0:0,playing:false,cur:-1,scrollV:null};
const ro=mkOverlay('xr');
const sheet=document.createElement('div');sheet.className='xsheet';sheet.hidden=true;sheet.setAttribute('dir',dirAttr);document.body.appendChild(sheet);

function addSecs(){
  if(!rd.t0)return;
  const s=Math.min(1800,Math.round((Date.now()-rd.t0)/1000));
  rd.t0=0;
  if(s<=0)return;
  const d=str(nowNum());
  E.secs[d]=(E.secs[d]||0)+s;
  bump();
}
function title(b,c){return (b===PSB?X('ps'):bname(b))+' '+nf(c)}
async function openReader(b,c,queue,verse){
  rd.b=b;rd.c=c;rd.queue=queue||null;rd.scrollV=verse||null;rd.tr=E.set.tr;
  rd.t0=Date.now();
  openOv(ro);
  await drawReader();
}
async function drawReader(){
  const key=rd.b+':'+rd.c;
  ro.innerHTML='<div class="xhead"><button class="xb" id="xrClose">✕</button><h2>'+esc(title(rd.b,rd.c))+'</h2><button class="xb" id="xrTr">'+(rd.tr==='svd'?'KJV':'SVD')+'</button><button class="xb" id="xrFm">A−</button><button class="xb" id="xrFp">A+</button></div><div class="xbody" id="xrBody">…</div><div class="xfoot"><button class="xb" id="xrPrev">‹</button><button class="xb pri" id="xrDone"></button><button class="xb" id="xrNext">›</button></div>';
  const data=await getChapter(rd.b,rd.c,rd.tr);
  rd.data=data;
  const body=q('xrBody');
  if(!data){body.textContent=X('cloudErr')}
  else{
    const rtl=data.tr==='svd';
    body.setAttribute('dir',rtl?'rtl':'ltr');
    body.style.fontSize=E.set.fs+'px';
    body.style.fontFamily=rtl?'var(--f-body)':"'Lora','Cormorant Garamond',serif";
    body.innerHTML=(data.fb?'<div class="xnote">'+X('deutNote')+'</div>':'')+data.v.map((t,i)=>vHtml(i+1,t)).join('');
    if(rd.scrollV){const el=body.querySelector('[data-v="'+rd.scrollV+'"]');if(el)el.scrollIntoView({block:'center'});rd.scrollV=null}
  }
  updFoot();
}
function vHtml(v,t){
  const k=rd.b+':'+rd.c+':'+v;
  const h=E.hl[k];
  const st=h!==undefined?' style="background:'+HLC[h]+'88"':'';
  return '<span class="xv" data-v="'+v+'"'+st+'><span class="n">'+nf(v)+'</span>'+esc(t)+(E.fav.includes(k)?' ★':'')+(E.notes[k]?' 📝':'')+(E.notes[k]?'<span class="nt">'+esc(E.notes[k])+'</span>':'')+'</span>';
}
function updFoot(){
  const key=rd.b+':'+rd.c;
  const d=q('xrDone');if(!d)return;
  d.textContent=(isDone(key)?'✓ '+X('done'):X('markDone'));
  const [hp,hn]=nav(false);
  q('xrPrev').disabled=!hp;q('xrNext').disabled=!hn;
}
function nav(go){
  let p=null,n=null;
  if(rd.queue){
    const i=rd.queue.findIndex(x=>x[0]===rd.b&&x[1]===rd.c);
    if(i>0)p=rd.queue[i-1];
    if(i>=0&&i<rd.queue.length-1)n=rd.queue[i+1];
  }
  if(!rd.queue||(!p&&!n&&rd.queue.findIndex(x=>x[0]===rd.b&&x[1]===rd.c)<0)){
    p=rd.c>1?[rd.b,rd.c-1]:(rd.b>0?[rd.b-1,BOOKS[rd.b-1][1]]:null);
    n=rd.c<BOOKS[rd.b][1]?[rd.b,rd.c+1]:(rd.b<BOOKS.length-1?[rd.b+1,1]:null);
  }
  return [p,n];
}
function go(dir){
  const [p,n]=nav();
  const t=dir<0?p:n;
  if(!t)return false;
  addSecs();rd.t0=Date.now();
  rd.b=t[0];rd.c=t[1];
  drawReader();
  return true;
}
ro.addEventListener('click',e=>{
  const t=e.target;
  if(t.closest('#xrClose')){addSecs();sheet.hidden=true;closeOv(ro);return}
  if(t.closest('#xrTr')){E.set.tr=rd.tr=rd.tr==='svd'?'kjv':'svd';saveE();drawReader();return}
  if(t.closest('#xrFm')){E.set.fs=Math.max(14,E.set.fs-2);saveE();q('xrBody').style.fontSize=E.set.fs+'px';return}
  if(t.closest('#xrFp')){E.set.fs=Math.min(40,E.set.fs+2);saveE();q('xrBody').style.fontSize=E.set.fs+'px';return}
  if(t.closest('#xrPrev')){go(-1);return}
  if(t.closest('#xrNext')){go(1);return}
  if(t.closest('#xrDone')){
    const key=rd.b+':'+rd.c;
    const was=isDone(key);
    setKeys([key],!was);
    if(!was&&rd.queue)go(1);else updFoot();
    return;
  }
  const v=t.closest('.xv');
  if(v)openSheet(+v.dataset.v);
});
function openSheet(v){
  const k=rd.b+':'+rd.c+':'+v;
  const txt=rd.data.v[v-1];
  const ref=title(rd.b,rd.c)+':'+nf(v);
  const cur=E.hl[k];
  sheet.hidden=false;
  sheet.innerHTML='<b>'+esc(ref)+'</b><div class="r">'+HLC.map((c,i)=>'<span class="xdot'+(cur===i?' sel':'')+'" data-hl="'+i+'" style="background:'+c+'"></span>').join('')+'<button class="xb" data-a="nohl">⌀</button></div><div class="r"><button class="xb'+(E.fav.includes(k)?' on':'')+'" data-a="fav">★ '+X('fav')+'</button><button class="xb" data-a="note">📝 '+X('note')+'</button><button class="xb" data-a="copy">'+X('copy')+'</button><button class="xb" data-a="share">'+X('share')+'</button><button class="xb" data-a="x">✕</button></div>';
  sheet.onclick=async ev=>{
    const el=ev.target.closest('[data-hl],[data-a]');if(!el)return;
    const a=el.dataset.a;
    if(el.dataset.hl!==undefined){const i=+el.dataset.hl;if(E.hl[k]===i)delete E.hl[k];else E.hl[k]=i;bump();refreshVerse(v);openSheet(v);return}
    if(a==='nohl'){delete E.hl[k];bump();refreshVerse(v);openSheet(v);return}
    if(a==='fav'){const i=E.fav.indexOf(k);if(i<0)E.fav.push(k);else E.fav.splice(i,1);bump();refreshVerse(v);openSheet(v);return}
    if(a==='note'){
      sheet.innerHTML='<b>'+esc(ref)+'</b><textarea class="xin" id="xnt" rows="4">'+esc(E.notes[k]||'')+'</textarea><div class="r"><button class="xb pri" data-a="ns">'+X('save')+'</button>'+(E.notes[k]?'<button class="xb" data-a="nd">'+X('del')+'</button>':'')+'<button class="xb" data-a="x">'+X('cancel')+'</button></div>';
      return;
    }
    if(a==='ns'){const t=q('xnt').value.trim();if(t)E.notes[k]=t;else delete E.notes[k];bump();refreshVerse(v);sheet.hidden=true;return}
    if(a==='nd'){delete E.notes[k];bump();refreshVerse(v);sheet.hidden=true;return}
    if(a==='copy'){try{await navigator.clipboard.writeText(txt+'\n— '+ref);toast(X('copied'))}catch(e){}sheet.hidden=true;return}
    if(a==='share'){const t=txt+'\n— '+ref;sheet.hidden=true;if(navigator.share){try{await navigator.share({text:t})}catch(e){}}else{try{await navigator.clipboard.writeText(t);toast(X('copied'))}catch(e){}}return}
    if(a==='x'){sheet.hidden=true}
  };
}
function refreshVerse(v){
  const el=document.querySelector('#xrBody [data-v="'+v+'"]');
  if(!el||!rd.data)return;
  const tmp=document.createElement('div');
  tmp.innerHTML=vHtml(v,rd.data.v[v-1]);
  el.replaceWith(tmp.firstChild);
}

function dayQueue(k){return DAYS[k]?DAYS[k].ks.map(x=>[x[0]%100,x[1]]):null}
function decorate(){
  document.querySelectorAll('#plan .seg,#hero .seg').forEach(seg=>{
    const nm=seg.querySelector('.segname');
    if(!nm||nm.querySelector('.xread'))return;
    const inp=seg.querySelector('input[data-key]');
    if(!inp)return;
    const [b,c]=inp.dataset.key.split(':').map(Number);
    const bb=b%100;
    const btn=document.createElement('button');
    btn.type='button';btn.className='xread';btn.textContent='📖 '+X('reader');
    btn.dataset.xb=bb;btn.dataset.xc=c;
    const day=seg.closest('details.day');
    if(day)btn.dataset.xk=day.dataset.k;
    nm.appendChild(btn);
  });
  document.querySelectorAll('#booksPanel .book').forEach(bk=>{
    if(bk.querySelector('.xread'))return;
    const b=+bk.id.replace('book-','');
    if(isNaN(b))return;
    const btn=document.createElement('button');
    btn.type='button';btn.className='xread';btn.textContent='📖 '+X('reader');
    btn.dataset.xb=b;btn.dataset.xc=1;btn.dataset.book='1';
    bk.querySelector('b').appendChild(btn);
  });
}
document.addEventListener('click',e=>{
  const b=e.target.closest('.xread');
  if(!b)return;
  e.preventDefault();e.stopPropagation();
  let queue=null;
  if(b.dataset.xk!==undefined&&b.dataset.xk!==''){queue=dayQueue(+b.dataset.xk)}
  else if(!b.dataset.book&&!b.dataset.xk){
    const seg=b.closest('.seg');
    if(seg)queue=[...seg.querySelectorAll('input[data-key]')].map(i=>{const a=i.dataset.key.split(':').map(Number);return [a[0]%100,a[1]]});
  }
  openReader(+b.dataset.xb,+b.dataset.xc,queue);
},true);
new MutationObserver(()=>{clearTimeout(decorate.t);decorate.t=setTimeout(decorate,60)}).observe(document.body,{childList:true,subtree:true});

const tabs=document.querySelector('.tabs');
const spacer=tabs.querySelector('.spacer');
const mkTab=(id,label)=>{const b=document.createElement('button');b.className='tab';b.setAttribute('role','tab');b.setAttribute('aria-selected','false');b.dataset.tab=id;b.textContent=label;tabs.insertBefore(b,spacer);return b};
mkTab('xstats','📈 '+X('stats'));
mkTab('xmore','☰ '+X('more'));
const pStats=document.createElement('div');pStats.id='xStats';pStats.hidden=true;
const pMore=document.createElement('div');pMore.id='xMore';pMore.hidden=true;
q('booksPanel').after(pStats);pStats.after(pMore);
document.addEventListener('click',e=>{
  const b=e.target.closest('[data-tab]');if(!b)return;
  const t=b.dataset.tab;
  pStats.hidden=t!=='xstats';pMore.hidden=t!=='xmore';
  if(t==='xstats')renderStats();
  if(t==='xmore')renderMore();
});

function chaptersDone(){return Object.keys(S.done).length}
function booksDone(){let n=0;BOOKS.forEach((b,i)=>{if(typeof bookStats==='function'&&bookStats(i)===b[1])n++});return n}
function badgesList(){
  const st=streakInfo();const n=chaptersDone();const bk=booksDone();
  return[['first','🌱',n>=1],['s3','🔥',st.best>=3],['s7','🔥',st.best>=7],['s30','🏅',st.best>=30],['s100','🏆',st.best>=100],['c50','📖',n>=50],['c250','📚',n>=250],['c1000','👑',n>=1000],['b1','✅',bk>=1],['b10','🎖️',bk>=10],['plan','🎉',TOTAL>0&&doneCount()>=TOTAL]];
}
function last30(){
  const m={};Object.values(S.done).forEach(d=>m[d]=(m[d]||0)+1);
  const t=nowNum();const out=[];
  for(let i=29;i>=0;i--)out.push(m[str(t-i)]||0);
  return out;
}
function renderStats(){
  const st=streakInfo();
  const mins=Math.round(Object.values(E.secs).reduce((a,b)=>a+b,0)/60);
  const pct=TOTAL?Math.round(doneCount()/TOTAL*100):0;
  const v=last30();const mx=Math.max(1,...v);
  const bars=v.map((x,i)=>{const h=x?Math.max(6,x/mx*100):3;return '<rect x="'+(i*10+1)+'" y="'+(100-h)+'" width="8" height="'+h+'" rx="2" fill="'+(x?'#b0802a':'#e5dbbf')+'"/>'}).join('');
  pStats.setAttribute('dir',dirAttr);
  pStats.innerHTML='<div class="xgrid"><div class="xc"><b>🔥 '+nf(st.cur)+'</b><small>'+X('streak')+'</small></div><div class="xc"><b>🏆 '+nf(st.best)+'</b><small>'+X('best')+'</small></div><div class="xc"><b>'+nf(chaptersDone())+'</b><small>'+X('chRead')+'</small></div><div class="xc"><b>'+nf(booksDone())+'</b><small>'+X('books')+'</small></div><div class="xc"><b>'+nf(mins)+'</b><small>'+X('mins')+'</small></div><div class="xc"><b>'+nf(pct)+'%</b><small>'+(EN?'of plan':'من الخطة')+'</small></div></div>'
    +'<h3 class="xh">'+X('last30')+'</h3><svg viewBox="0 0 300 100" width="100%" height="110" preserveAspectRatio="none">'+bars+'</svg>'
    +'<h3 class="xh">'+X('badges')+'</h3><div class="xgrid">'+badgesList().map(b=>'<div class="xc xbadge'+(b[2]?' on':'')+'"><span class="e">'+b[1]+'</span><br><small>'+X('b_'+b[0])+'</small></div>').join('')+'</div>'
    +'<div class="xrow" style="justify-content:center;margin-top:18px"><button class="xb pri" id="xShare">📤 '+X('shareProg')+'</button></div>';
  q('xShare').onclick=shareImage;
}
async function shareImage(){
  const st=streakInfo();
  const c=document.createElement('canvas');c.width=720;c.height=900;
  const g=c.getContext('2d');
  const gr=g.createLinearGradient(0,0,720,900);gr.addColorStop(0,'#1f2a44');gr.addColorStop(1,'#3a4a78');
  g.fillStyle=gr;g.beginPath();g.roundRect?g.roundRect(0,0,720,900,48):g.rect(0,0,720,900);g.fill();
  g.textAlign='center';g.fillStyle='#e9c46a';g.font='700 56px Amiri,serif';g.fillText(EN?'Bible Journey':'رحلة الكتاب المقدس',360,120);
  const pct=TOTAL?doneCount()/TOTAL:0;
  g.lineWidth=28;g.strokeStyle='#ffffff30';g.beginPath();g.arc(360,370,150,0,Math.PI*2);g.stroke();
  g.strokeStyle='#e9c46a';g.lineCap='round';g.beginPath();g.arc(360,370,150,-Math.PI/2,-Math.PI/2+Math.PI*2*pct);g.stroke();
  g.fillStyle='#fff';g.font='700 92px Amiri,serif';g.fillText(nf(Math.round(pct*100))+'%',360,402);
  const items=[['🔥',nf(st.cur),X('streak')],['📖',nf(chaptersDone()),X('chRead')],['🎖️',nf(booksDone()),X('books')]];
  items.forEach((it,i)=>{const x=130+i*230;g.font='54px sans-serif';g.fillText(it[0],x,650);g.fillStyle='#fff';g.font='700 52px Amiri,serif';g.fillText(it[1],x,720);g.fillStyle='#ffffffb0';g.font='28px Amiri,serif';g.fillText(it[2],x,765)});
  const blob=await new Promise(r=>c.toBlob(r,'image/png'));
  const f=new File([blob],'progress.png',{type:'image/png'});
  try{
    if(navigator.canShare&&navigator.canShare({files:[f]})){await navigator.share({files:[f]});return}
  }catch(e){if(e&&e.name==='AbortError')return}
  const a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download='progress.png';a.click();
}

function renderMore(){
  pMore.setAttribute('dir',dirAttr);
  const it=(id,ic,t)=>'<button class="item" data-x="'+id+'">'+ic+' '+t+'</button>';
  pMore.innerHTML='<div class="xlist">'+it('search','🔎',X('search'))+it('notes','📝',X('notes')+' / '+X('fav')+' / '+X('hl'))+it('plans','✨',X('plans'))+it('groups','👥',X('groups'))+it('settings','⚙️',X('settings'))+it('privacy','🔒',X('privacy'))+'</div>';
}
pMore.addEventListener('click',e=>{
  const b=e.target.closest('[data-x]');if(!b)return;
  ({search:openSearch,notes:openNotes,plans:openPlans,groups:openGroups,settings:openSettings,privacy:openPrivacy})[b.dataset.x]();
});
const so=mkOverlay('xo');
function panel(titleTxt,html){
  so.innerHTML='<div class="xhead"><button class="xb" id="xoClose">✕</button><h2>'+esc(titleTxt)+'</h2><span style="width:42px"></span></div><div class="xbody">'+html+'</div>';
  q('xoClose').onclick=()=>closeOv(so);
  openOv(so);
  return so.querySelector('.xbody');
}

let allText={};
async function openSearch(){
  const body=panel(X('search'),'<div class="xrow"><input class="xin" id="xq" placeholder="'+esc(X('searchHint'))+'" style="flex:1"><button class="xb pri" id="xqg">🔎</button></div><div id="xqr"></div>');
  const run=async()=>{
    const qs=q('xq').value.trim();
    if(qs.length<2)return;
    const tr=/[\u0600-\u06FF]/.test(qs)?'svd':'kjv';const out=q('xqr');
    out.textContent='…';
    const needle=tr==='svd'?normAr(qs):qs.toLowerCase();
    const hits=[];
    for(let b=0;b<BOOKS.length&&hits.length<200;b++){
      let t=tr,bk=await loadBook(t,b);
      if(!bk&&t==='svd')bk=await loadBook('ar_extra',b);
      if(!bk){t='kjv';bk=await loadBook('kjv',b);if(!bk||/[؀-ۿ]/.test(qs))continue}
      for(let c=0;c<bk.length&&hits.length<200;c++){
        const vs=bk[c];
        for(let v=0;v<vs.length;v++){
          const x=t==='svd'?normAr(vs[v]):vs[v].toLowerCase();
          if(x.includes(needle)){hits.push([b,c+1,v+1,vs[v]]);if(hits.length>=200)break}
        }
      }
    }
    out.innerHTML=hits.length?hits.map(h=>'<div class="xhit" data-b="'+h[0]+'" data-c="'+h[1]+'" data-v="'+h[2]+'"><b>'+esc(title(h[0],h[1]))+':'+nf(h[2])+'</b><br>'+esc(h[3])+'</div>').join(''):X('noRes');
  };
  q('xqg').onclick=run;
  q('xq').onkeydown=e=>{if(e.key==='Enter')run()};
  q('xqr').onclick=e=>{const h=e.target.closest('.xhit');if(h){openReader(+h.dataset.b,+h.dataset.c,null,+h.dataset.v)}};
  q('xq').focus();
}
function openNotes(){
  const sortK=a=>a.slice().sort((x,y)=>{const p=x.split(':').map(Number),r=y.split(':').map(Number);return p[0]-r[0]||p[1]-r[1]||p[2]-r[2]});
  const row=(k,extra)=>{const p=k.split(':').map(Number);return '<div class="xhit" data-b="'+p[0]+'" data-c="'+p[1]+'" data-v="'+p[2]+'"><b>'+esc(title(p[0],p[1]))+':'+nf(p[2])+'</b>'+(extra?'<br>'+esc(extra):'')+'</div>'};
  const hlRows=sortK(Object.keys(E.hl)).map(k=>'<div class="xhit" data-b="'+k.split(':')[0]+'" data-c="'+k.split(':')[1]+'" data-v="'+k.split(':')[2]+'" style="background:'+HLC[E.hl[k]]+'66"><b>'+esc(title(+k.split(':')[0],+k.split(':')[1]))+':'+nf(k.split(':')[2])+'</b></div>').join('');
  const body=panel(X('notes'),'<h3 class="xh">'+X('notes')+'</h3>'+(sortK(Object.keys(E.notes)).map(k=>row(k,E.notes[k])).join('')||X('noRes'))+'<h3 class="xh">'+X('fav')+'</h3>'+(sortK(E.fav).map(k=>row(k)).join('')||X('noRes'))+'<h3 class="xh">'+X('hl')+'</h3>'+(hlRows||X('noRes')));
  body.onclick=e=>{const h=e.target.closest('.xhit');if(h)openReader(+h.dataset.b,+h.dataset.c,null,+h.dataset.v)};
}

const SKIPKEEP=(keep,pool)=>pool.filter(b=>!keep.includes(b));
const PLANS=[
  [['الكتاب المقدس في سنة','Whole Bible in a year'],['العهد القديم ثم الجديد، ٣٦٥ يوم','Old then New Testament, 365 days'],{scope:'all',mode:'seq',days:365,skip:[]}],
  [['القديم والجديد معًا في سنة','Both testaments daily, one year'],['كل يوم من القديم ومن الجديد','A bit of each testament daily'],{scope:'all',mode:'mix',days:365,skip:[]}],
  [['الكتاب المقدس في ٩٠ يوم','Whole Bible in 90 days'],['وتيرة مكثفة','Intensive pace'],{scope:'all',mode:'seq',days:90,skip:[]}],
  [['العهد الجديد في ٣٠ يوم','New Testament in 30 days'],['شهر مع العهد الجديد','A month in the New Testament'],{scope:'nt',mode:'seq',days:30,skip:[]}],
  [['العهد الجديد في ٩٠ يوم','New Testament in 90 days'],['وتيرة هادئة','Calm pace'],{scope:'nt',mode:'seq',days:90,skip:[]}],
  [['العهد القديم في سنة','Old Testament in a year'],['بالأسفار القانونية الثانية','With deuterocanon'],{scope:'ot',mode:'seq',days:365,skip:[]}],
  [['الأناجيل وأعمال الرسل','Gospels & Acts'],['٣٠ يوم','30 days'],{scope:'nt',mode:'seq',days:30,skip:'nt:49,50,51,52,53'}],
  [['المزامير والأمثال','Psalms & Proverbs'],['٦٠ يوم','60 days'],{scope:'ot',mode:'seq',days:60,skip:'ot:20,21'}],
  [['أسفار موسى الخمسة','The Pentateuch'],['٦٠ يوم','60 days'],{scope:'ot',mode:'seq',days:60,skip:'ot:0,1,2,3,4'}],
];
function setupOf(p){
  let skip=p.skip;
  if(typeof skip==='string'){const [k,l]=skip.split(':');const keep=l.split(',').map(Number);skip=SKIPKEEP(keep,k==='nt'?NT_ORDER:PLAN_ORDER)}
  return{scope:p.scope,ot:{b:-1,c:0,p:0},nt:{b:-1,c:0},skip,mode:p.mode,days:p.days,end:null,repeats:1};
}
function applySetup(su){
  if(!confirm(X('applyPlan')))return false;
  const first=S.setup&&S.setup.first?S.setup.first:str(nowNum());
  S.setup=Object.assign({},su,{repeats:1,start:str(nowNum()),first});
  S.plan=null;
  save();buildPlan();closeSetup();VIEW=null;openDays.clear();schedule();
  const k=currentK();if(k>=0)openDays.add(k);
  render();
  document.querySelector('[data-tab="plan"]').click();
  window.scrollTo(0,0);
  toast(X('applied'),'gold');
  return true;
}
function openPlans(){
  const body=panel(X('plans'),'<div class="xlist">'+PLANS.map((p,i)=>'<button class="item" data-i="'+i+'">'+esc(p[0][EN?1:0])+'<small>'+esc(p[1][EN?1:0])+'</small></button>').join('')+'</div>');
  body.onclick=e=>{const b=e.target.closest('[data-i]');if(!b)return;if(applySetup(setupOf(PLANS[+b.dataset.i][2])))closeOv(so)};
}

function openPrivacy(){
  const ar='سياسة الخصوصية\n\n١. ما الذي نجمعه\n- بيانات القراءة: الأصحاحات المقروءة، الملاحظات، التمييز، المفضلة، وقت القراءة، إعدادات الخطة.\n- إذا سجّلت الدخول: بريدك واسمك المعروض ومعرّف الحساب.\n- إذا انضممت إلى مجموعة: اسمك المعروض وعدد الأصحاحات وسلسلة الأيام ونسبة الإنجاز تظهر لأعضاء المجموعة.\n\n٢. أين تُحفظ البيانات\n- على جهازك دائمًا.\n- في Firebase التابع لـ Google عند تسجيل الدخول فقط، للمزامنة بين أجهزتك.\n\n٣. ما لا نفعله\n- لا نبيع بياناتك ولا نعرض إعلانات ولا نتتبّعك.\n\n٤. حقوقك\n- يمكنك حذف حسابك وبياناتك السحابية من الإعدادات.\n- يمكنك مسح بيانات الجهاز.\n- يمكنك استخدام الموقع بدون حساب.';
  const en='Privacy policy\n\n1. What we collect\n- Reading data: chapters read, notes, highlights, favorites, reading time, plan settings.\n- If you sign in: your email, display name and account ID.\n- If you join a group: your display name, chapters read, streak and progress are visible to group members.\n\n2. Where data lives\n- Always on your device.\n- In Google Firebase only if you sign in, to sync between your devices.\n\n3. What we do not do\n- We do not sell your data, show ads or track you.\n\n4. Your rights\n- Delete your account and cloud data from Settings.\n- Erase on-device data.\n- You can use the site without an account.';
  panel(X('privacy'),'<div class="xpre">'+esc(EN?en:ar)+'</div>');
}

let fb=null,fuser=null,pushT=0,lastSync=0;
const cfg=window.FIREBASE_CONFIG;
function loadScript(u){return new Promise((res,rej)=>{const s=document.createElement('script');s.src=u;s.onload=res;s.onerror=rej;document.head.appendChild(s)})}
async function initFirebase(){
  if(!cfg)return;
  try{
    const v='10.12.2';
    await loadScript('https://www.gstatic.com/firebasejs/'+v+'/firebase-app-compat.js');
    await loadScript('https://www.gstatic.com/firebasejs/'+v+'/firebase-auth-compat.js');
    await loadScript('https://www.gstatic.com/firebasejs/'+v+'/firebase-firestore-compat.js');
    firebase.initializeApp(cfg);
    fb={auth:firebase.auth(),db:firebase.firestore()};
    fb.auth.onAuthStateChanged(u=>{fuser=u;if(u){cloud={set:async()=>{schedulePush()}};syncNow()}else{cloud=null}if(!so.hidden&&so.dataset.p==='settings')openSettings()});
  }catch(e){fb=null}
}
function planOut(){return S.plan?S.plan.map(d=>d.join(',')):null}
function docOut(){return{done:S.done,hist:E.hist||[],delays:S.delays,pb:S.pb||[],plan:planOut(),setup:S.setup||null,t:S.t,notes:E.notes,hl:E.hl,fav:E.fav,secs:E.secs}}
function applyRemote(r){
  S={done:clean(r.done),delays:r.delays||[],t:r.t||0,setup:r.setup||S.setup||null,plan:Array.isArray(r.plan)?r.plan.map(x=>typeof x==='string'?(x?x.split(','):[]):x):null,pb:r.pb||[]};
  E.notes=r.notes||{};E.hl=r.hl||{};E.fav=r.fav||[];E.secs=r.secs||{};E.hist=r.hist||[];
  saveLocal();saveE();
  if(S.setup){buildPlan();closeSetup();}
  render();
}
function schedulePush(){
  if(!fuser)return;
  clearTimeout(pushT);
  pushT=setTimeout(()=>pushNow().catch(()=>{}),900);
}
async function pushNow(){
  if(!fuser)return;
  const ref=fb.db.collection('users').doc(fuser.uid);
  const o=docOut();
  Object.keys(o).forEach(k=>{if(o[k]===undefined)o[k]=null});
  await ref.set(JSON.parse(JSON.stringify(o)));
  lastSync=Date.now();
  await pushMember();
}
async function syncNow(){
  if(!fuser)return;
  try{
    const ref=fb.db.collection('users').doc(fuser.uid);
    const snap=await ref.get();
    if(snap.exists){
      const r=snap.data();
      if((r.t||0)>S.t){applyRemote(r);lastSync=Date.now();await pushMember();return}
    }
    await pushNow();
  }catch(e){}
}
function myName(){return E.set.name||(fuser&&(fuser.displayName||(fuser.email||'').split('@')[0]))||'—'}
async function pushMember(){
  if(!fuser||!E.groups.length)return;
  const st=streakInfo();
  for(const c of E.groups){
    try{await fb.db.collection('groups').doc(c).collection('members').doc(fuser.uid).set({name:myName(),done:doneCount(),pct:TOTAL?Math.round(doneCount()/TOTAL*100):0,streak:st.cur,readDay:st.readToday?str(nowNum()):'',updated:firebase.firestore.FieldValue.serverTimestamp()})}catch(e){}
  }
}
function openSettings(){
  const s=E.set;
  const acct=!cfg?'<p>'+X('noCloud')+'</p>':!fb?'<p>…</p>':fuser?'<p>'+esc(fuser.displayName||fuser.email||'')+(lastSync?' · '+X('synced'):'')+'</p><label>'+X('dispName')+'<input class="xin" id="xsn" value="'+esc(s.name)+'"></label><div class="xrow"><button class="xb" id="xsync">'+X('syncNow')+'</button><button class="xb" id="xso">'+X('signOut')+'</button><button class="xb" id="xdel" style="color:#a3342b">'+X('delAcc')+'</button></div>':'<button class="xb pri" id="xgo">'+X('signGoogle')+'</button><input class="xin" id="xem" type="email" placeholder="'+X('email')+'"><input class="xin" id="xpw" type="password" placeholder="'+X('pass')+'"><div class="xrow"><button class="xb" id="xin">'+X('signIn')+'</button><button class="xb" id="xreg">'+X('register')+'</button></div><p id="xerr" style="color:#a3342b;font-size:.8rem"></p>';
  const body=panel(X('settings'),'<h3 class="xh">'+X('tr')+'</h3><div class="xrow"><button class="xb'+(s.tr==='svd'?' on':'')+'" data-tr="svd">'+X('svd')+'</button><button class="xb'+(s.tr==='kjv'?' on':'')+'" data-tr="kjv">'+X('kjv')+'</button></div><h3 class="xh">'+X('fs')+'</h3><input type="range" id="xfs" min="14" max="36" value="'+s.fs+'" style="width:100%"><h3 class="xh">'+X('rem')+'</h3><div class="xrow"><label><input type="checkbox" id="xrem"'+(s.rem?' checked':'')+'> '+X('rem')+'</label></div><div class="xrow"><label>'+X('remTime')+' <input type="time" id="xrt" value="'+String(s.rh).padStart(2,'0')+':'+String(s.rm).padStart(2,'0')+'"></label></div><div class="xrow"><label><input type="checkbox" id="xrisk"'+(s.risk?' checked':'')+'> '+X('risk')+'</label></div><small>'+X('remNote')+'</small><h3 class="xh">'+X('account')+'</h3>'+acct+'<h3 class="xh"></h3><div class="xrow"><button class="xb" id="xwipe" style="color:#a3342b">'+X('wipe')+'</button></div>');
  so.dataset.p='settings';
  body.onclick=async e=>{
    const t=e.target;
    const tb=t.closest('[data-tr]');if(tb){E.set.tr=tb.dataset.tr;saveE();openSettings();return}
    if(t.id==='xgo'){try{await fb.auth.signInWithPopup(new firebase.auth.GoogleAuthProvider())}catch(er){q('xerr').textContent=er.message}}
    if(t.id==='xin'||t.id==='xreg'){try{const f=t.id==='xin'?'signInWithEmailAndPassword':'createUserWithEmailAndPassword';await fb.auth[f](q('xem').value.trim(),q('xpw').value)}catch(er){q('xerr').textContent=er.message}}
    if(t.id==='xso'){await fb.auth.signOut()}
    if(t.id==='xsync'){await syncNow();openSettings()}
    if(t.id==='xdel'&&confirm(X('delConfirm'))){
      try{
        const u=fuser;
        await fb.db.collection('users').doc(u.uid).delete();
        for(const c of E.groups){try{await fb.db.collection('groups').doc(c).collection('members').doc(u.uid).delete()}catch(er){}}
        await u.delete();
      }catch(er){alert(er.code==='auth/requires-recent-login'?(EN?'Sign in again, then retry':'سجّل الدخول من جديد وحاول تاني'):er.message)}
    }
    if(t.id==='xwipe'&&confirm(X('wipeConfirm'))){E.notes={};E.hl={};E.fav=[];E.secs={};E.groups=[];bump();openSettings()}
  };
  body.oninput=e=>{
    const t=e.target;
    if(t.id==='xfs'){E.set.fs=+t.value;saveE()}
    if(t.id==='xsn'){E.set.name=t.value;saveE()}
  };
  body.onchange=async e=>{
    const t=e.target;
    if(t.id==='xrem'){
      if(t.checked&&'Notification' in window&&Notification.permission==='default'){try{await Notification.requestPermission()}catch(er){}}
      E.set.rem=t.checked;saveE();
    }
    if(t.id==='xrisk'){
      if(t.checked&&'Notification' in window&&Notification.permission==='default'){try{await Notification.requestPermission()}catch(er){}}
      E.set.risk=t.checked;saveE();
    }
    if(t.id==='xrt'){const [h,m]=t.value.split(':').map(Number);E.set.rh=h||0;E.set.rm=m||0;saveE()}
  };
}

async function openGroups(){
  if(!cfg||!fb||!fuser){panel(X('groups'),'<p>'+(cfg?X('needSign'):X('noCloud'))+'</p>');return}
  const body=panel(X('groups'),'<div class="xrow"><button class="xb pri" id="xgc">'+X('createG')+'</button><button class="xb" id="xgj">'+X('joinG')+'</button></div><div id="xgl">…</div>');
  const draw=async()=>{
    const out=q('xgl');
    let html='';
    for(const c of E.groups){
      let info=null,mem=[];
      try{const d=await fb.db.collection('groups').doc(c).get();info=d.exists?d.data():null;const m=await fb.db.collection('groups').doc(c).collection('members').get();mem=m.docs.map(x=>x.data())}catch(e){}
      mem.sort((a,b)=>(b.done||0)-(a.done||0));
      const today=str(nowNum());
      html+='<div class="xc" style="text-align:start;margin:10px 0"><b style="font-size:1.2rem">'+esc(info?info.name:c)+'</b><div>'+X('gCode')+': <b style="letter-spacing:2px">'+esc(c)+'</b></div>'+mem.map(m=>'<div>'+(m.readDay===today?'✅':'⚪')+' '+esc(m.name||'—')+' · '+nf(m.done||0)+' '+X('chapters')+' · 🔥 '+nf(m.streak||0)+'</div>').join('')+'<div class="xrow">'+(info&&info.setup?'<button class="xb" data-gp="'+esc(c)+'">'+X('useGPlan')+'</button>':'')+'<button class="xb" data-gl="'+esc(c)+'">'+X('leave')+'</button></div></div>';
    }
    out.innerHTML=html||'';
    out.__g=out.__g||{};
  };
  await draw();
  body.onclick=async e=>{
    const t=e.target;
    if(t.id==='xgc'){
      const n=prompt(X('gName'));if(!n||!n.trim())return;
      const a='ABCDEFGHJKLMNPQRSTUVWXYZ23456789';let code='';for(let i=0;i<6;i++)code+=a[Math.floor(Math.random()*a.length)];
      try{await fb.db.collection('groups').doc(code).set({name:n.trim(),owner:fuser.uid,setup:S.setup||null,created:firebase.firestore.FieldValue.serverTimestamp()});E.groups.push(code);saveE();await pushMember();await draw()}catch(er){alert(er.message)}
    }
    if(t.id==='xgj'){
      const c=(prompt(X('gCode'))||'').trim().toUpperCase();if(!c)return;
      try{const d=await fb.db.collection('groups').doc(c).get();if(!d.exists){alert(X('noRes'));return}if(!E.groups.includes(c))E.groups.push(c);saveE();await pushMember();await draw()}catch(er){alert(er.message)}
    }
    const gl=t.closest('[data-gl]');
    if(gl){const c=gl.dataset.gl;try{await fb.db.collection('groups').doc(c).collection('members').doc(fuser.uid).delete()}catch(er){}E.groups=E.groups.filter(x=>x!==c);saveE();await draw()}
    const gp=t.closest('[data-gp]');
    if(gp){
      const d=await fb.db.collection('groups').doc(gp.dataset.gp).get();
      const su=d.data().setup;
      if(su){const o=Object.assign({},su);delete o.start;delete o.first;if(applySetup(o))closeOv(so)}
    }
  };
}

function nowParts(){const d=new Date();return{h:d.getHours(),m:d.getMinutes(),day:str(nowNum())}}
async function notify(title,body,tag){
  try{
    if(!('Notification' in window)||Notification.permission!=='granted')return;
    const reg=navigator.serviceWorker&&await navigator.serviceWorker.getRegistration();
    if(reg&&reg.showNotification)await reg.showNotification(title,{body,tag,icon:'icons/icon-192.png'});
    else new Notification(title,{body,tag,icon:'icons/icon-192.png'});
  }catch(e){}
}
function tick(){
  const s=E.set;
  if(!S.setup)return;
  const p=nowParts();
  const st=streakInfo();
  const L=(()=>{try{return JSON.parse(localStorage.getItem('ot-notif')||'{}')}catch(e){return{}}})();
  const wr=(k)=>{L[k]=p.day;try{localStorage.setItem('ot-notif',JSON.stringify(L))}catch(e){}};
  if(s.rem&&!st.readToday&&!st.frozenToday&&L.d!==p.day&&(p.h>s.rh||(p.h===s.rh&&p.m>=s.rm))){
    wr('d');
    const k=typeof currentK==='function'?currentK():-1;
    notify(X('notifTitle'),X('notifBody')+(k>=0&&DAYS[k]?': '+rangeText(DAYS[k]):''),'daily');
  }
  if(s.risk&&st.cur>0&&!st.readToday&&!st.frozenToday&&L.r!==p.day&&(p.h>20||(p.h===20&&p.m>=30))){
    wr('r');
    notify(X('riskTitle'),X('riskBody'),'risk');
  }
}
setInterval(tick,30000);
document.addEventListener('visibilitychange',()=>{if(!document.hidden){tick();syncNow()}});

decorate();
tick();
initFirebase();
})();
