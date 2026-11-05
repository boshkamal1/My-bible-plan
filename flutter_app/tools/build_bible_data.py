import json,re,sys,os
src=sys.argv[1]
out=sys.argv[2]
idx=sys.argv[3]
svd=json.load(open(os.path.join(src,'svd.json'),encoding='utf-8-sig'))
kjv=json.load(open(os.path.join(src,'kjv.json'),encoding='utf-8-sig'))
kjva=json.load(open(os.path.join(src,'kjva.json'),encoding='utf-8-sig'))['books']
names=json.load(open(idx,encoding='utf-8'))
ap={b['name']:b for b in kjva}
def ch_texts(b):
    return [[v['text'].strip() for v in c['verses']] for c in b['chapters']]
def verses_of(book,c,lo=1,hi=999):
    ch=[x for x in book['chapters'] if x['chapter']==c][0]
    return [v['text'].strip() for v in ch['verses'] if lo<=v['verse']<=hi]
canon_idx=[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,18,19,20,21,22,23,26,27,28,30,31,32,33,34,35,36,37,38,39,40,41,42,43]+list(range(49,76))
assert len(canon_idx)==66
for i,k in enumerate(canon_idx):
    json.dump([c for c in svd[i]['chapters']],open(f'{out}/svd/{k}.json','w',encoding='utf-8'),ensure_ascii=False,separators=(',',':'))
    json.dump([c for c in kjv[i]['chapters']],open(f'{out}/kjv/{k}.json','w',encoding='utf-8'),ensure_ascii=False,separators=(',',':'))
def save(k,chs):
    json.dump(chs,open(f'{out}/kjv/{k}.json','w',encoding='utf-8'),ensure_ascii=False,separators=(',',':'))
for k,n in ((16,'Tobit'),(17,'Judith'),(24,'Wisdom'),(25,'Sirach'),(29,'Baruch'),(44,'I Maccabees'),(45,'II Maccabees'),(46,'Prayer of Manasses')):
    save(k,ch_texts(ap[n]))
save(47,[verses_of(ap['Prayer of Azariah'],1),verses_of(ap['Susanna'],1),verses_of(ap['Bel and the Dragon'],1)])
E=ap['Additions to Esther']
save(48,[[('' if v['text'].strip() == '…' else v['text'].strip()) for v in c['verses']] for c in E['chapters'] if 10 <= c['chapter'] <= 16])
counts=[]
for k in range(76):
    chs=json.load(open(f'{out}/kjv/{k}.json',encoding='utf-8'))
    counts.append([len(chs),sum(len(c) for c in chs)])
    if k<66 or True:
        pass
json.dump(counts,open(f'{out}/counts.json','w'))
print(counts)
