"""User-selected A: edit the CURRENT Beta sword into a substantial broad war sword."""
import bpy,json,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];SOURCE=ROOT/'art/source/beta-greatsword.blend';SCALE=1.472
bpy.ops.wm.open_mainfile(filepath=str(SOURCE),load_ui=False,use_scripts=False)
bpy.context.preferences.filepaths.save_version=0
blade=bpy.data.objects['SwordBlade'];steel=blade.data.materials[0];edge=steel.copy();edge.name='SteelEdge'
edge.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.66,.72,.78,1)
edge.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.22
fuller=bpy.data.materials.new('SteelFuller');fuller.use_nodes=True;p=fuller.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(.35,.41,.46,1);p.inputs['Metallic'].default_value=1;p.inputs['Roughness'].default_value=.31
# A real recessed fuller in both faces, flat center planes and broad edge bevels.
profile=[(1,0),(.62,-1),(.20,-1),(.12,-.45),(-.12,-.45),(-.20,-1),(-.62,-1),(-1,0),(-.62,1),(-.20,1),(-.12,.45),(.12,.45),(.20,1),(.62,1)]
sections=[(.025*SCALE,.10,.012),(.12,.10,.012),(.60,.096,.011),(1.16,.082,.009),(1.26,.075,.0085),(1.36,.023,.003)]
verts=[];faces=[];slots=[]
for distance,width,thickness in sections:
    for x,y in profile:verts.append((x*width*.5/SCALE,y*thickness*.5/SCALE,-distance/SCALE))
for section in range(len(sections)-1):
    for index in range(len(profile)):
        faces.append((section*14+index,section*14+(index+1)%14,(section+1)*14+(index+1)%14,(section+1)*14+index))
        slots.append(1 if index in [0,6,7,13] else 2 if index in [2,3,4,9,10,11] else 0)
tip=len(verts);verts.append((0,0,-1.40/SCALE))
for index in range(14):faces.append((70+index,70+(index+1)%14,tip));slots.append(1 if index in [0,6,7,13] else 0)
faces.append(tuple(reversed(range(14))));slots.append(0)
data=bpy.data.meshes.new('Broad war sword steel with recessed fuller');data.from_pydata(verts,[],faces);data.update()
for material in [steel,edge,fuller]:data.materials.append(material)
for poly,slot in zip(data.polygons,slots):poly.material_index=slot
blade.data=data
# A plain strong crossguard, keeping the existing leather handle and small blue pommel.
guard=bpy.data.objects['SwordGuard'];mat=guard.data.materials[0]
w=.15/SCALE;d=.010/SCALE;h=.012/SCALE
vs=[(x,y,z) for z in [-.008-h,-.008+h] for y in [-d,d] for x in [-w,w]]
fs=[(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)]
data=bpy.data.meshes.new('Straight broad war sword guard');data.from_pydata(vs,[],fs);data.materials.append(mat);data.update();guard.data=data
for modifier in list(guard.modifiers):guard.modifiers.remove(modifier)
mod=guard.modifiers.new('Rounded forged corners','BEVEL');mod.width=.002;mod.segments=4
mod=guard.modifiers.new('Weighted steel normals','WEIGHTED_NORMAL');mod.keep_sharp=True
bpy.context.view_layer.objects.active=guard;guard.select_set(True)
for modifier in list(guard.modifiers):bpy.ops.object.modifier_apply(modifier=modifier.name)
scene=bpy.context.scene;scene['sword_style']='User-selected A: oversized broad war sword';scene['blade_length_m']=1.40;scene['blade_width_m']=.10;scene['blade_thickness_m']=.012
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
path=ROOT/'art/character/beta-sword-review/customization.json';report=json.loads(path.read_text(encoding='utf-8'))
report.update(blade_length_m=1.40,blade_width_m=.10,blade_thickness_m=.012,guard_width_m=.30,blade_tip_local_y=-1.40/SCALE,reach_m=1.40+.10*SCALE,overall_length_m=1.40+.275*SCALE,style='Broad war sword A',reference_url='https://art.thewalters.org/object/51.479/',note='User selected the broad war sword, then explicitly requested size/mass that justifies dragging: 1.805m overall, 1.40m blade, 10cm broad steel and 12mm maximum spine; original stylized geometry with a real recessed fuller.',new_blade_geometry='Original CC0 project geometry; prior Quandtum-derived hilt retained',source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),saved_source_reopened=False)
path.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('BROAD_WAR_SWORD_SOURCE_SAVED',report['overall_length_m'])
