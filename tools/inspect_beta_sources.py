import bpy,json,os
from pathlib import Path
ROOT=Path('C:/Games/CoastalFoundation')
meshes=[]
for o in bpy.data.objects:
    if o.type=='MESH' and o.visible_get() and not o.hide_render:
        if not len(o.data.vertices): continue
        coords=[o.matrix_world@v.co for v in o.data.vertices]
        meshes.append({'name':o.name,'vertices':len(o.data.vertices),'bounds':[[min(v[i] for v in coords),max(v[i] for v in coords)] for i in range(3)],'groups':[g.name for g in o.vertex_groups],'modifiers':[(m.name,m.type,getattr(getattr(m,'object',None),'name',None)) for m in o.modifiers],'materials':[m.name if m else None for m in o.data.materials]})
report={'blender':bpy.app.version_string,'file':bpy.data.filepath,'meshes':meshes,'rigs':[{'name':o.name,'matrix':[list(r) for r in o.matrix_world],'bones':[{'name':b.name,'parent':b.parent.name if b.parent else None,'head':list(b.head_local),'tail':list(b.tail_local)} for b in o.data.bones]} for o in bpy.data.objects if o.type=='ARMATURE']}
(ROOT/'art/character/beta-source-inspection.json').write_text(json.dumps(report,indent=2))
print('BETA_SOURCE_INSPECTED',len(meshes),[r['name'] for r in report['rigs']])
