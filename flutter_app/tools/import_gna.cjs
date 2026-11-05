// Import the licensed GNA2025 verse text without editing any verse strings.
// Source: https://bible.helloao.org/api/arb_gna/complete.simple.json
const fs=require('node:fs');const path=require('node:path');const crypto=require('node:crypto');
const input=path.join(__dirname,'cache','gna2025-source.json');
const base=path.join(__dirname,'..','assets','bible');const out=path.join(base,'gna');fs.mkdirSync(out,{recursive:true});
const raw=fs.readFileSync(input);const data=JSON.parse(raw);
if(data.translation.id!=='arb_gna'||data.translation.licenseUrl!=='https://creativecommons.org/licenses/by-nc-nd/4.0/')throw Error('Unexpected source/license');
const codes=['GEN','EXO','LEV','NUM','DEU','JOS','JDG','RUT','1SA','2SA','1KI','2KI','1CH','2CH','EZR','NEH','TOB','JDT','EST','JOB','PSA','PRO','ECC','SNG','WIS','SIR','ISA','JER','LAM','BAR','EZK','DAN','HOS','JOL','AMO','OBA','JON','MIC','NAM','HAB','ZEP','HAG','ZEC','MAL','1MA','2MA','MAN','DAG','ESG','MAT','MRK','LUK','JHN','ACT','ROM','1CO','2CO','GAL','EPH','PHP','COL','1TH','2TH','1TI','2TI','TIT','PHM','HEB','JAS','1PE','2PE','1JN','2JN','3JN','JUD','REV'];
let verses=0;const report=[];
for(const book of data.books){const b=codes.indexOf(book.id);if(b<0)throw Error('Unknown book '+book.id);
 let chapters=[];
 for(const ch of book.chapters){const arr=[];for(const v of ch.chapter.content.filter(v=>v.type==='verse')){if(typeof v.number!=='number'||typeof v.text!=='string'||arr[v.number-1]!==undefined)throw Error('Invalid/duplicate verse');arr[v.number-1]=v.text;verses++;}chapters[ch.chapter.number-1]=Array.from({length:arr.length},(_,i)=>arr[i]??'');}
 // Preserve the app's existing plan/progress keys. Only chapter boundaries move;
 // no words are rewritten. The UI identifies the original source numbering.
 if(book.id==='JOL'){if(chapters.length!==4||chapters[1].length!==27)throw Error('Unexpected Joel');chapters=[chapters[0],[...chapters[1],...chapters[2]],chapters[3]];}
 if(book.id==='MAL'){if(chapters.length!==3||chapters[2].length!==24)throw Error('Unexpected Malachi');chapters=[chapters[0],chapters[1],chapters[2].slice(0,18),chapters[2].slice(18)];}
 fs.writeFileSync(path.join(out,`${b}.json`),JSON.stringify(chapters));report.push({b,code:book.id,chapters:chapters.length,verseSlots:chapters.flat().length});
}
if(data.books.length!==66||verses!==31070)throw Error('Unexpected coverage');
fs.writeFileSync(path.join(out,'LICENSE.txt'),`Good News Arabic 2025 / الترجمة العربية المشتركة\nBible Society in Lebanon\nCC BY-NC-ND 4.0: https://creativecommons.org/licenses/by-nc-nd/4.0/\nSource: https://app.library.bible/content/fd5704b4b8ddef79\nDistribution: https://bible.helloao.org/api/arb_gna/complete.simple.json\nNon-commercial redistribution. Verse strings are unchanged. JSON presentation and Joel/Malachi chapter boundaries follow the application's existing plan keys; source numbering is explained in the reader. Supplements are separately attributed to their actual sources and are not represented as GNA text.\n`);
fs.writeFileSync(path.join(__dirname,'gna_import_report.json'),JSON.stringify({translation:data.translation,sourceSha256:crypto.createHash('sha256').update(raw).digest('hex'),verseTextSha256:crypto.createHash('sha256').update(JSON.stringify(data.books.map(b=>[b.id,b.chapters.flatMap(c=>c.chapter.content.filter(v=>v.type==='verse').map(v=>v.text))]))).digest('hex'),books:report,sourceVerseCount:verses},null,2));
console.log(JSON.stringify({books:data.books.length,verses,source:'GNA2025',license:data.translation.licenseUrl}));
