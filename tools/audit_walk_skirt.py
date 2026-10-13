"""Check covered leg vertices stay inside the dress during both walk cycles."""
import bpy, json, hashlib, sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/source/humanoid-v1.blend'))
advanced='--advanced' in sys.argv
if advanced:
 sys.path.insert(0,str(ROOT/'tools'))
 from prepare_character_detail import apply_detail
 apply_detail()
rig=bpy.data.objects['Humanoid'];body=bpy.data.objects['module_body'];dress=bpy.data.objects['outfit_dress']
leg_groups={g.index for g in body.vertex_groups if g.name.startswith('thigh.')}
indices=[v.index for v in body.data.vertices if any(g.group in leg_groups and g.weight>.5 for g in v.groups)]
failures=[];count=0
for clip in ['walk_loop','drag_walk_loop']:
 rig.animation_data.action=bpy.data.actions[clip]
 for sample in range(121):
  frame=1+sample/120*(rig.animation_data.action.frame_range[1]-1)
  bpy.context.scene.frame_set(int(frame),subframe=frame-int(frame))
  graph=bpy.context.evaluated_depsgraph_get()
  skin=body.evaluated_get(graph).to_mesh();cloth=dress.evaluated_get(graph).to_mesh()
  tree=BVHTree.FromPolygons([v.co for v in cloth.vertices],[list(p.vertices) for p in cloth.polygons])
  for index in indices:
   point=skin.vertices[index].co
   if not .72<point.z<.94: continue
   # A horizontal ray through the open-ended skirt has odd parity inside it.
   origin=point.copy();crossings=0
   for attempt in range(8):
    hit=tree.ray_cast(origin,Vector((1,0,0)),2)[0]
    if hit is None: break
    crossings+=1;origin=hit+Vector((.0001,0,0))
   count+=1
   if crossings%2==0: failures.append({'clip':clip,'phase':sample/120,'vertex':index,'point':list(point)})
  body.evaluated_get(graph).to_mesh_clear();dress.evaluated_get(graph).to_mesh_clear()
report={'passed':not failures,'covered_vertices':count,'failures':failures,'source_hash':hashlib.sha256((ROOT/'art/source/humanoid-v1.blend').read_bytes()).hexdigest(),'recipe_hash':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
if advanced:
 report['detail_recipe_hash']=hashlib.sha256((ROOT/'tools/prepare_character_detail.py').read_bytes()).hexdigest()
 report['hero_recipe_hash']=hashlib.sha256((ROOT/'tools/remake_hero.py').read_bytes()).hexdigest()
(ROOT/('output/verification/advanced-walk-skirt.json' if advanced else 'output/verification/walk-skirt.json')).write_text(json.dumps(report,indent=2))
print('WALK_SKIRT',count,'covered vertices;',len(failures),'outside skirt')
if failures: raise RuntimeError('Covered legs escape the walking skirt envelope')
