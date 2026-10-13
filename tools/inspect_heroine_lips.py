import bpy,sys,os,gzip,json
sys.path.insert(0,os.path.dirname(__file__))
from personal_heroine_face import TARGET_ROOT
b=bpy.data.objects['Human'];basis=b.data.shape_keys.key_blocks['Basis']
out={}
for name in ['mouth-upperlip-volume-decr','mouth-lowerlip-volume-decr','mouth-upperlip-height-decr']:
    with gzip.open(os.path.join(TARGET_ROOT,'mouth',name+'.target.gz'),'rt') as f:rows=[line.split() for line in f if line.strip() and not line.startswith('#')]
    ids=[int(r[0]) for r in rows if len(r)==4]
    coords=[basis.data[i].co for i in ids]
    out[name]={'count':len(ids),'bounds':[[min(c[a] for c in coords),max(c[a] for c in coords)] for a in range(3)],'examples':[[i,list(basis.data[i].co)] for i in ids[:6]]}
out['keys']=[[k.name,k.value] for k in b.data.shape_keys.key_blocks if k.value and ('mouth' in k.name or 'cheek' in k.name)]
with open(os.path.join(os.environ['TEMP'],'heroine_lip_inspection.json'),'w') as f:json.dump(out,f,indent=2)
