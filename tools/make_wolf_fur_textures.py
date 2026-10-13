"""Original deterministic coat maps and tapered fur cards; no remote inputs."""
from pathlib import Path
import json,hashlib,random
import numpy as np
from PIL import Image,ImageDraw,ImageFilter
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'game/assets/creatures/wolf-fur';DEST.mkdir(parents=True,exist_ok=True)
rng=random.Random(27011); size=1024
base=Image.new('L',(size,size),110);draw=ImageDraw.Draw(base)
for i in range(35000):
    x=rng.randrange(size);y=rng.randrange(size);length=rng.randint(7,40)
    shade=rng.randint(55,210)
    draw.line([(x,y),(x+rng.uniform(-2,2),y+length*.55),(x+rng.uniform(-4,4),y+length)],fill=shade,width=1)
height=base.filter(ImageFilter.GaussianBlur(.45))
noise=np.random.default_rng(27).normal(0,1,(size,size))
small=Image.fromarray(np.uint8(np.random.default_rng(28).uniform(40,200,(32,32)))).resize((size,size),Image.Resampling.BICUBIC)
h=np.asarray(height,dtype=float)/255
variation=(np.asarray(small,dtype=float)/255-.5)*.20+(h-.45)*.16+noise*.009
colors=np.clip(np.array([.46,.45,.415])[None,None,:]+variation[:,:,None],0,1)
Image.fromarray(np.uint8(colors*255)).save(DEST/'coat-albedo.png')
dy,dx=np.gradient(h);normal=np.stack([-dx*1.1,-dy*1.1,np.ones_like(h)],axis=2)
normal/=np.linalg.norm(normal,axis=2)[:,:,None]
Image.fromarray(np.uint8((normal*.5+.5)*255)).save(DEST/'coat-normal.png')
Image.fromarray(np.uint8(np.clip(.88+(h-.5)*.08,0,1)*255)).save(DEST/'coat-roughness.png')
card=Image.new('RGBA',(256,512),(0,0,0,0));cd=ImageDraw.Draw(card)
for i in range(42):
    x=rng.randint(12,243);tip=rng.randint(35,270);shift=rng.randint(-24,24)
    tint=rng.randint(90,170)
    cd.polygon([(x-2,511),(x+3,511),(x+shift+1,tip+40),(x+shift,tip)],fill=(tint,int(tint*.98),int(tint*.90),rng.randint(160,245)))
card.save(DEST/'fur-tuft.png')
record={'license':'CC0-1.0','author':'Coastal Foundation project','seed':27011,'recipe':'tools/make_wolf_fur_textures.py','files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in DEST.glob('*.png')}}
(ROOT/'art/library/wolf-fur-textures.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
print('WOLF_FUR_TEXTURES',list(record['files']))
