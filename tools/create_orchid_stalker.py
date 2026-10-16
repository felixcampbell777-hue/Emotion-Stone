"""Original Orchid Stalker source and runtime mesh. No external scripts/assets."""
import bpy, math, random
from mathutils import Vector
from mathutils.noise import noise_vector
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'game/assets/dreadmore';OUT.mkdir(parents=True,exist_ok=True)
SOURCE=ROOT/'art/source/environments/dreadmore'
bpy.context.preferences.filepaths.save_version=0
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
random.seed(46)
def material(name,color,rough=.6,metal=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
 return m
chitin=material('Ridged jade chitin',(.055,.13,.11),.52,.16)
under=material('Flexible dark connective tissue',(.025,.045,.036),.85)
petal=material('Weathered orchid burgundy',(.26,.075,.12),.65)
edge=material('Old ivory hook edges',(.39,.39,.23),.65)
eye=material('Amber compound eye',(.9,.45,.08),.3)
p=eye.node_tree.nodes.get('Principled BSDF');p.inputs['Emission Color'].default_value=(.8,.24,.025,1);p.inputs['Emission Strength'].default_value=.65
# Original small-scale variegation survives glTF through a real image map.
image=bpy.data.images.new('Original chitin mottling',width=512,height=512)
pixels=[]
for y in range(512):
 for x in range(512):
  n=noise_vector(Vector((x/36,y/36,.4))).x*.5+.5
  ridge=.7+.3*math.sin(x*.22+math.sin(y*.04)*3)**4
  pixels.extend((.12+n*.10,.22+n*.15,.16+n*.12,1))
image.pixels=pixels;image.filepath_raw=str(OUT/'orchid-chitin.png');image.file_format='PNG';image.save()
tex=chitin.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image
chitin.node_tree.links.new(tex.outputs['Color'],chitin.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
root=bpy.data.objects.new('OrchidStalker',None);bpy.context.collection.objects.link(root)
def attach(obj,parent):
 obj.parent=parent;return obj
def ell(name,at,scale,mat,parent=root):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=16,location=at)
 o=bpy.context.object;o.name=name;o.scale=scale;o.data.materials.append(mat)
 for f in o.data.polygons:f.use_smooth=True
 return attach(o,parent)
def link(name,a,b,r1,r2,mat,parent=root):
 a,b=Vector(a),Vector(b);d=b-a
 bpy.ops.mesh.primitive_cone_add(vertices=20,radius1=r1,radius2=r2,depth=d.length,location=(a+b)/2)
 o=bpy.context.object;o.name=name;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();o.data.materials.append(mat)
 for f in o.data.polygons:f.use_smooth=True
 bevel=o.modifiers.new('Worn plate edges','BEVEL');bevel.width=.025;bevel.segments=2
 return attach(o,parent)
def joint(name,at,parent=root):
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=at;o.parent=parent;return o
ell('Thorax',(0,0,2.15),(.48,.32,.70),under)
for i in range(5):
 z=1.55+i*.25;ell('Overlapping thorax plate '+str(i),(0,-.08,z),(.47-.025*abs(i-2),.35,.19),chitin)
ell('Long tapered abdomen',(0,.15,1.15),(.30,.28,.65),chitin)
for i in range(6):ell('Abdominal ring '+str(i),(0,-.06,.85+i*.15),(.24,.23,.07),under)
head=joint('Head',(0,-.04,2.85))
ell('Insect face',(0,-.04,.08),(.25,.23,.34),chitin,head)
for s in [-1,1]:
 ell('Compound eye '+str(s),(s*.16,-.23,.13),(.075,.055,.12),eye,head)
 link('Mandible',(s*.13,-.14,-.03),(s*.20,-.32,-.23),.07,.025,edge,head)
 link('Mandible hook',(s*.20,-.32,-.23),(s*.05,-.38,-.28),.025,.002,edge,head)
 # Four arms, independently articulated at shoulder and elbow.
 for level in range(2):
  arm=joint('Arm_%s_%d'%('L' if s<0 else 'R',level),(s*.36,.02,2.50-level*.53))
  elbow=(s*(.62 if level==0 else .48),.09,-.32 if level==0 else -.50)
  link('Upper carapace',(.0,0,0),elbow,.16,.10,chitin,arm)
  ell('Shoulder plate',(.02*s,0,0),(.22,.19,.25),chitin,arm)
  fore=joint('Fore_%s_%d'%('L' if s<0 else 'R',level),elbow,arm)
  end=(s*.34,-.21,-.60 if level==0 else -.53)
  link('Long ridged forearm',(0,0,0),end,.11,.055,chitin,fore)
  for n in range(3):
   at=Vector(end)*(.25+n*.24);link('Forearm thorn',at,at+Vector((s*.18,.04,.14)),.055,.001,edge,fore)
  ell('Claw palm',end,(.12,.13,.17),under,fore)
  for digit in range(3):
   a=Vector(end)+Vector(((digit-1)*.08,-.05,-.06))
   b=a+Vector((s*.06,-.16,-.22));c=b+Vector((-s*.025,-.10,.10))
   link('Grasping talon',a,b,.045,.028,edge,fore);link('Hooked talon tip',b,c,.028,.001,edge,fore)
 leg=joint('Leg_'+('L' if s<0 else 'R'),(s*.24,.07,1.28))
 knee=(s*.40,-.10,-.52);ankle=(s*.50,.24,-1.02)
 link('Powerful digitigrade thigh',(0,0,0),knee,.18,.12,chitin,leg)
 link('Long reverse shin',knee,ankle,.12,.045,chitin,leg)
 for n in range(3):link('Ground claw',ankle,(ankle[0]+(n-1)*.1,ankle[1]-.4,ankle[2]-.22),.05,.002,edge,leg)
 # Veined orchid crest: curved blade-like petals, no flat billboard.
 for i in range(4):
  vertices=[];faces=[]
  for j in range(13):
   t=j/12;center=Vector((s*(.12+t*(.35+i*.12)),.05+math.sin(t*math.pi)*.25,.15+t*(.85-i*.08)))
   width=math.sin(math.pi*t)**.7*(.14+i*.018)
   vertices.extend([tuple(center+Vector((0,-width,0))),tuple(center+Vector((0,width,0)))])
  for j in range(12):faces.append((j*2,j*2+1,j*2+3,j*2+2))
  mesh=bpy.data.meshes.new('Veined orchid crest');mesh.from_pydata(vertices,[],faces);mesh.update()
  o=bpy.data.objects.new('Orchid crest petal',mesh);bpy.context.collection.objects.link(o);o.parent=head;o.data.materials.append(petal)
  solid=o.modifiers.new('Petal thickness','SOLIDIFY');solid.thickness=.025
  bevel=o.modifiers.new('Petal edges','BEVEL');bevel.width=.02;bevel.segments=2
  link('Petal vein',(s*.12,.05,.15),(s*(.47+i*.12),.05,1-i*.08),.015,.001,edge,head)
# Rough dorsal scales and hooked silhouette spines.
for i in range(9):
 z=1.1+i*.20;link('Dorsal spine',(0,.25,z),(0,.60+.06*math.sin(i),z+.24),.10,.003,chitin)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'orchid-stalker.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'orchid-stalker.glb'),export_format='GLB',export_yup=True,export_apply=True)
print('ORIGINAL ORCHID STALKER:',len(bpy.data.objects),'model parts; editable source, custom chitin and GLB saved')
