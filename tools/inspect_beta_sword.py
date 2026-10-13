import bpy, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'art/library/source/quandtum-knights-trust/LongSword_KnightsTrust_Quandtum.blend'
bpy.ops.wm.open_mainfile(filepath=str(source),load_ui=False,use_scripts=False)
report={'texts':[t.name for t in bpy.data.texts], 'drivers':[], 'objects':[]}
for o in bpy.data.objects:
    if o.animation_data and o.animation_data.drivers: report['drivers'].append(o.name)
    if o.type=='MESH':
        report['objects'].append({'name':o.name,'dimensions':list(o.dimensions),'rotation':list(o.rotation_euler),'location':list(o.location),'vertices':len(o.data.vertices),'bounds_local':[[min(v.co[i] for v in o.data.vertices),max(v.co[i] for v in o.data.vertices)] for i in range(3)],'materials':[m.name if m else '' for m in o.data.materials]})
out=ROOT/'art/character/beta-sword-review'; out.mkdir(parents=True,exist_ok=True)
(out/'donor-inspection.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))
o=bpy.data.objects['Sword.LoPoly']
levels={}
for v in o.data.vertices:
    key=round(v.co.z,3); levels.setdefault(key,[]).append(tuple(v.co))
print(json.dumps([{ 'z':z,'x':max(abs(v[0]) for v in vs),'y':max(abs(v[1]) for v in vs),'count':len(vs)} for z,vs in sorted(levels.items())]))
(out/'donor-mesh.json').write_text(json.dumps({'vertices':[list(v.co) for v in o.data.vertices],'faces':[list(p.vertices) for p in o.data.polygons]}))
