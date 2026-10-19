"""Append reviewed, rig-preserving morphs to the actual approved runtime GLB.

Base vertex/index/skin/animation/material bytes are retained verbatim. No rig or
animation is generated. Formula coordinates match prepare_appearance_review.py.
"""
from pathlib import Path
import hashlib
import json
import math
import struct
import io
import os
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'game/assets/characters/heroine-beta.glb'
DEST=ROOT/'art/character/appearance-review/heroine-morph-reference.glb'
REPORT=ROOT/'art/character/appearance-review/runtime-export.json'
CHANNELS=['soft_cheeks','short_layers','subtle_shape']

def bell(v,c,r):return max(0.0,1.0-abs(v-c)/r)**2

def deform(v,channel,name):
    x,y,z=v;sy=-z;sz=y
    if channel=='soft_cheeks' and name=='base.002':
        w=bell(sz,1.515,.075)*bell(abs(x),.055,.045)
        if sy<.05 and sz<1.548:x*=1+.10*w
    elif channel=='short_layers' and name=='junglebookhair.002' and sz<1.48:
        weight=min(1.0,(1.48-sz)/.18);x*=1-.32*weight
        limit=.13+.025*max(0,min(1,(sz-1.4)/.18));x=max(-limit,min(limit,x))
        sz=1.48+(sz-1.48)*.45
    elif channel=='subtle_shape' and name not in ['junglebookhair.002','junglebookhair.003','Fitted textured hair crown.002','high-poly.002','teeth_base.002','tongue01.002','eyebrow006.002','eyelashes03.002']:
        if abs(x)<.22:x*=1-.055*bell(sz,1.03,.17)+.025*bell(sz,.82,.16)
    return (x,sz,-sy)

def sub(a,b):return tuple(x-y for x,y in zip(a,b))
def cross(a,b):return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def dot(a,b):return sum(x*y for x,y in zip(a,b))

def normal(v,n,channel,name):
    columns=[];epsilon=1e-5
    for axis in range(3):
        a=list(v);b=list(v);a[axis]+=epsilon;b[axis]-=epsilon
        columns.append(tuple(d/(2*epsilon) for d in sub(deform(a,channel,name),deform(b,channel,name))))
    a,b,c=columns;det=dot(a,cross(b,c))
    if abs(det)<1e-7:return n
    cofactors=[cross(b,c),cross(c,a),cross(a,b)]
    result=tuple(sum(cofactors[j][i]*n[j] for j in range(3))/det for i in range(3))
    length=math.sqrt(dot(result,result))
    return tuple(x/length for x in result) if length>1e-7 else n

raw=SOURCE.read_bytes();assert raw[:4]==b'glTF'
size,kind=struct.unpack_from('<II',raw,12);document=json.loads(raw[20:20+size])
binary_size,binary_kind=struct.unpack_from('<II',raw,20+size)
binary=bytearray(raw[28+size:28+size+binary_size]);original_binary=bytes(binary)

# Bake the separately reviewed material repair into ordinary runtime maps.
def image_at(index):
    view=document['bufferViews'][document['images'][index]['bufferView']]
    return Image.open(io.BytesIO(original_binary[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']])).convert('RGB')
cloth=image_at(8);fallback=image_at(1);normal_image=image_at(7);roughness=image_at(9)
pixels=cloth.load();tile=fallback.load();normal_pixels=normal_image.load();rough_pixels=roughness.load()
repaired_pixels=0
def linear(v):
    value=v/255.0
    return value/12.92 if value<=.04045 else ((value+.055)/1.055)**2.4
for y in range(cloth.height):
    for x in range(cloth.width):
        color=pixels[x,y]
        if sum(linear(color[i])*weight for i,weight in enumerate((.2126,.7152,.0722)))<.006:
            pixels[x,y]=tile[x%fallback.width,y%fallback.height]
            normal_pixels[x,y]=(128,128,255);rough_pixels[x,y]=(184,184,184);repaired_pixels+=1
for suffix,image in [('color',cloth),('normal',normal_image),('roughness',roughness)]:
    target=SOURCE.parent/('heroine-appearance-denim-'+suffix+'.png')
    stream=io.BytesIO();image.save(stream,format='PNG');data=stream.getvalue()
    if not target.exists() or target.read_bytes()!=data:target.write_bytes(data)

def vectors(index):
    accessor=document['accessors'][index];view=document['bufferViews'][accessor['bufferView']]
    assert accessor['componentType']==5126 and accessor['type']=='VEC3'
    start=view.get('byteOffset',0)+accessor.get('byteOffset',0);stride=view.get('byteStride',12)
    return [struct.unpack_from('<3f',binary,start+i*stride) for i in range(accessor['count'])]

def append_vectors(values):
    while len(binary)%4:binary.append(0)
    start=len(binary)
    for value in values:binary.extend(struct.pack('<3f',*value))
    view=len(document['bufferViews']);document['bufferViews'].append({'buffer':0,'byteOffset':start,'byteLength':len(values)*12,'target':34962})
    index=len(document['accessors']);document['accessors'].append({'bufferView':view,'componentType':5126,'count':len(values),'type':'VEC3','min':[min(v[i] for v in values) for i in range(3)],'max':[max(v[i] for v in values) for i in range(3)]})
    return index

counts={channel:0 for channel in CHANNELS}
for mesh in document['meshes']:
    name=mesh['name'];mesh.setdefault('extras',{})['targetNames']=CHANNELS;mesh['weights']=[0,0,0]
    for primitive in mesh['primitives']:
        positions=vectors(primitive['attributes']['POSITION']);normals=vectors(primitive['attributes']['NORMAL']) if 'NORMAL' in primitive['attributes'] else None
        primitive['targets']=[]
        for channel in CHANNELS:
            displacements=[sub(deform(v,channel,name),v) for v in positions]
            counts[channel]+=sum(dot(v,v)>1e-16 for v in displacements)
            target={'POSITION':append_vectors(displacements)}
            if normals:
                changes=[sub(normal(v,n,channel,name),n) if dot(delta,delta)>1e-16 else (0,0,0) for v,n,delta in zip(positions,normals,displacements)]
                target['NORMAL']=append_vectors(changes)
            primitive['targets'].append(target)
# Reuse the already-shipped texture resources; do not duplicate40MB of extracted
# maps or allocate a second set of identical materials' textures for morph data.
for image in document['images']:
    relative='heroine-beta_'+image['name']+'.png'
    assert (SOURCE.parent/relative).is_file(),relative
    image.pop('bufferView',None);image.pop('mimeType',None);image['uri']=os.path.relpath(SOURCE.parent/relative,DEST.parent).replace(os.sep,'/')
document['buffers'][0]['byteLength']=len(binary)
assert bytes(binary[:len(original_binary)])==original_binary
json_bytes=json.dumps(document,separators=(',',':')).encode()
json_bytes+=b' '*((-len(json_bytes))%4);binary+=b'\0'*((-len(binary))%4)
result=struct.pack('<4sII',b'glTF',2,12+8+len(json_bytes)+8+len(binary))+struct.pack('<II',len(json_bytes),0x4e4f534a)+json_bytes+struct.pack('<II',len(binary),0x004e4942)+binary
DEST.write_bytes(result)
sha=lambda data:hashlib.sha256(data).hexdigest()
assert sha(SOURCE.read_bytes())==sha(raw)
review=json.loads((REPORT.parent/'review.json').read_text())
report={'source':str(SOURCE.relative_to(ROOT)),'source_sha256':sha(raw),'export':str(DEST.relative_to(ROOT)),'export_sha256':sha(result),'reviewed_source_sha256':review['candidate_sha256'],'reviewed_render_sha256':review['render_sha256'],'approval':{'instruction':'Approve these options','scope':'Shown softer cheeks, shorter tapered layers and subtle silhouette; animation fitting and inclusion authorized by human in current Codex session','date':'2026-10-18'},'morphs':CHANNELS,'changed_export_vertices':counts,'base_buffer_bytes_unchanged':True,'textures_reused_from_original':True,'runtime_geometry_module':'game/scripts/appearance_geometry.gd','runtime_method':'Same reviewed bounded surface formulas baked from original CPU vertex arrays; no GPU morph dependency on headless server','bones':len(document['skins'][0]['joints']),'animations':len(document.get('animations',[])),'new_animations':0,'coordinates':'Raw runtime mesh Y equals reviewed Blender mesh Z','default_weights':[0,0,0],'denim_repair_scope':'Non-destructive material bug fix for original and all variant profiles; source and original GLB bytes remain unchanged.','denim_repaired_pixels':repaired_pixels,'denim_maps':{suffix:sha((SOURCE.parent/('heroine-appearance-denim-'+suffix+'.png')).read_bytes()) for suffix in ['color','normal','roughness']}}
report['runtime_fit_correction']='Short-layer shortening is restricted below sourceZ1.48 to preserve the original fringe and hairline while retaining the reviewed lower-end height; no rig/bone/height/grip change.'
REPORT.write_text(json.dumps(report,indent=2)+'\n')
print('APPEARANCE_EXPORT',json.dumps(report))
