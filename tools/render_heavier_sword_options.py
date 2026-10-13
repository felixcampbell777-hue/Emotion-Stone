"""Original Blender review concepts only; never writes current game/source assets."""
import bpy,math,json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'art/character/sword-options';OUT.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=True
scene.world=bpy.data.worlds.new('Options studio');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.16,.19,.24,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
def mat(name,color,metal=0,rough=.6):
    m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough;return m
steel=mat('Satin steel',(.48,.55,.62),1,.27);edge=mat('Polished edge',(.67,.73,.80),1,.2);guard=mat('Forged hilt',(.2,.24,.28),1,.32);leather=mat('Dark brown leather',(.045,.018,.009),0,.75);blue=mat('Small blue accent',(.025,.13,.3),.3,.2);ink=mat('Ink',(.68,.77,.88));silhouette=mat('Heroine scale silhouette',(.035,.062,.095),0,.85)
def objmesh(name,verts,faces,material):
    data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update();obj=bpy.data.objects.new(name,data);scene.collection.objects.link(obj);data.materials.append(material);return obj
def bevel(obj,width=.001):
    mod=obj.modifiers.new('Forged corners','BEVEL');mod.width=width;mod.segments=3;obj.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
def rod(name,a,b,r,material):
    a,b=Vector(a),Vector(b);bpy.ops.mesh.primitive_cylinder_add(vertices=20,radius=r,depth=(b-a).length,location=(a+b)/2);obj=bpy.context.object;obj.name=name;obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();obj.data.materials.append(material);bevel(obj);return obj
def ball(name,at,scale,material):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=10,location=at);obj=bpy.context.object;obj.name=name;obj.scale=scale;obj.data.materials.append(material);return obj
def text(label,at,size=.04):
    data=bpy.data.curves.new(label,'FONT');data.body=label;data.size=size;data.align_x='CENTER';obj=bpy.data.objects.new(label,data);scene.collection.objects.link(obj);obj.location=at;obj.rotation_euler=(math.pi/2,0,0);data.materials.append(ink)
def blade(x,width,thickness,style):
    # Clear bevel faces and a substantial center thickness, including side-on cues.
    sections=[(0,0,0),(.10,width*.23,thickness*.36),(.32,width*.43,thickness*.48),(1.0,width*.5,thickness*.5),(1.17,width*.5,thickness*.5)]
    if style=='A':sections=[(0,0,0),(.10,width*.31,thickness*.32),(.30,width*.46,thickness*.47),(1.0,width*.5,thickness*.5),(1.17,width*.5,thickness*.5)]
    verts=[]
    for z,w,d in sections:
        for xx,yy in [(w,0),(w*.56,-d),(-w*.56,-d),(-w,0),(-w*.56,d),(w*.56,d)]:verts.append((x+xx,yy,z))
    faces=[]
    for j in range(len(sections)-1):
        for i in range(6):faces.append((j*6+i,j*6+(i+1)%6,(j+1)*6+(i+1)%6,(j+1)*6+i))
    faces.append(tuple(range(24,30)));obj=objmesh(style+' broad blade',verts,faces,steel);obj.data.materials.append(edge)
    for index,p in enumerate(obj.data.polygons):p.material_index=1 if index%6 in [0,2,3,5] else 0
    # A subtle physical central fuller provides a visible broad-flat war-sword cue.
    if style=='A':rod('A recessed fuller highlight',(x,-thickness*.515,.25),(x,-thickness*.515,1.12),.004,guard)
    return obj
options=[{'id':'A','title':'Broad war sword','width_cm':8,'spine_mm':9,'reference':'https://art.thewalters.org/object/51.479/'},{'id':'B','title':'Highland claymore','width_cm':10,'spine_mm':12,'reference':'https://www.metmuseum.org/art/collection/search/27515'},{'id':'C','title':'Italian greatsword','width_cm':12,'spine_mm':15,'reference':'https://www.metmuseum.org/art/collection/search/22002'}]
# Real current equipment is appended read-only for an honest size comparison.
with bpy.data.libraries.load(str(ROOT/'art/source/beta-greatsword.blend'),link=False) as (src,dst):dst.objects=src.objects
for obj in dst.objects:
    if obj and obj.type=='MESH':scene.collection.objects.link(obj);obj.scale*=1.472;obj.location+=Vector((-.82,0,1.17))
text('CURRENT',(-.82,-.03,1.74),.054);text('6 cm / 6 mm',(-.82,-.03,-.14),.035)
for option,x in zip(options,[-.20,.42,1.04]):
    style=option['id'];w=option['width_cm']/100;t=option['spine_mm']/1000;blade(x,w,t,style)
    rod(style+' leather grip',(x,0,1.20),(x,0,1.495),.0185,leather)
    for z in [1.198,1.487]:rod(style+' steel ferrule',(x,0,z-.005),(x,0,z+.005),.020,guard)
    for i in range(22):
        z=1.216+i*.012;rod(style+' grip wrap',(x-.017,-.010,z),(x+.017,-.010,z+.005),.001,guard)
    if style=='B':
        for sign in [-1,1]:
            rod('B angled quillon',(x,0,1.17),(x+sign*.17,0,1.105),.010,guard)
            # Restrained quatrefoil terminals echo the historical Highland hilt.
            for dx,dz in [(0,.008),(0,-.008),(.008,0),(-.008,0)]:ball('B clover end',(x+sign*.17+dx,0,1.105+dz),(.008,.006,.008),guard)
    else:
        rod(style+' crossguard',(x-.15 if style=='A' else x-.20,0,1.17),(x+.15 if style=='A' else x+.20,0,1.17),.012,guard)
    if style=='C':
        for sign in [-1,1]:rod('C blade shoulder lug',(x+sign*.045,0,1.02),(x+sign*.095,0,.97),.009,guard)
        for sign in [-1,1]:
            bpy.ops.mesh.primitive_torus_add(major_segments=32,minor_segments=8,location=(x,sign*.025,1.18),rotation=(math.pi/2,0,0),major_radius=.048,minor_radius=.005)
            bpy.context.object.name='C protective hilt ring';bpy.context.object.data.materials.append(guard)
    ball(style+' pommel',(x,0,1.525),(.044,.022,.050),guard);ball(style+' blue inset',(x,-.022,1.525),(.012,.004,.012),blue)
    text(style+'  '+option['title'],(x,-.03,1.74),.046);text(f"{option['width_cm']} cm / {option['spine_mm']} mm",(x,-.03,-.14),.035)
    # Side thickness comparison is deliberately kept at the same scale.
    rod(style+' spine profile',(x+.18,0,.18),(x+.18,0,1.00),t*.5,steel)
    text('edge view',(x+.18,-.03,.10),.026)
# Actual current heroine, rendered as a quiet silhouette rather than a generic adult.
with bpy.data.libraries.load(str(ROOT/'art/source/beta-heroine.blend'),link=False) as (src,dst):dst.objects=src.objects
hero=[obj for obj in dst.objects if obj]
for obj in hero:
    if obj.type not in ['MESH','ARMATURE']:continue
    scene.collection.objects.link(obj)
    if obj.type=='ARMATURE':obj.data.pose_position='REST';obj.location.x-=1.60
    elif obj.parent is None:obj.location.x-=1.60
    if obj.type=='MESH':
        obj.data.materials.clear();obj.data.materials.append(silhouette)
        for p in obj.data.polygons:p.material_index=0
text('HEROINE',(-1.60,-.03,1.74),.052);text('1.67 m',(-1.60,-.03,-.14),.035)
text('Original game concepts - all swords about 1.57 m overall',(-.28,-.04,1.88),.044)
text('Proposed blade width / spine thickness; exaggerated from the museum references',(-.28,-.04,-.27),.038)
def aim(obj,at):obj.rotation_euler=(Vector(at)-obj.location).to_track_quat('-Z','Y').to_euler()
for name,position,energy,size in [('Key',(-2,-3,3),300,3),('Edge',(2,1,1.5),400,2),('Steel strip',(0,-1.3,.6),80,1.5)]:
    data=bpy.data.lights.new(name,'AREA');data.energy=energy;data.size=size;obj=bpy.data.objects.new(name,data);scene.collection.objects.link(obj);obj.location=position;aim(obj,(0,0,.8))
data=bpy.data.cameras.new('Options camera');camera=bpy.data.objects.new('Options camera',data);scene.collection.objects.link(camera);scene.camera=camera;data.type='ORTHO';data.ortho_scale=3.7
camera.location=(.05,-7,2.15);aim(camera,(-.24,0,.81))
scene.render.resolution_x=1800;scene.render.resolution_y=1100;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'heavier-sword-options.blend'))
scene.render.filepath=str(OUT/'heavier-sword-options.png');bpy.ops.render.render(write_still=True)
(OUT/'options.json').write_text(json.dumps({'status':'concepts awaiting user selection','installed':False,'overall_length_m':1.575,'game_dimensions_not_museum_measurements':True,'original_concepts_license':'CC0-1.0','options':options},indent=2)+'\n',encoding='utf-8')
print('SWORD_OPTIONS_RENDERED')
