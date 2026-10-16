"""Original periodic 45-degree mountain unit. Run with pinned Blender -b --python."""
import bpy, math, json, hashlib
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'art/source/environments/world-rise';OUT=ROOT/'game/assets/environment/world_rise_backdrop'
SRC.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
for text in list(bpy.data.texts):bpy.data.texts.remove(text)
ANGLE=math.pi/4;N=128;M=12
root=bpy.data.objects.new('WorldRise_Backdrop_45deg',None);bpy.context.collection.objects.link(root)
mat=bpy.data.materials.new('Painted alpine stone');mat.use_nodes=True
nodes=mat.node_tree.nodes;bsdf=nodes.get('Principled BSDF');bsdf.inputs['Roughness'].default_value=1
color=nodes.new('ShaderNodeVertexColor');color.layer_name='MountainColor';mat.node_tree.links.new(color.outputs['Color'],bsdf.inputs['Base Color'])
LAYERS=[('Near',1800,380,500,(.09,.21,.14),(.29,.35,.34),.08),('Middle',2800,500,860,(.19,.32,.37),(.35,.43,.48),.24),('Far',3900,650,1250,(.32,.46,.55),(.52,.59,.65),.43)]
def ridge(t,band):
 a=t*math.tau
 # Periodic angular terms make the first/last boundary identical under rotation.
 return .24+.48*(.5+.5*math.cos(a*2+.7*band))+.20*(.5+.5*math.cos(a*5+band))**2+.08*math.sin(a*11+band)
def point(theta,v,band,radius,depth,height):
 t=(theta+ANGLE/2)/ANGLE
 r=radius+(v-.5)*depth*2
 envelope=max(0,math.sin(math.pi*v))**1.15
 ribs=1+.10*math.sin(t*math.tau*13+v*9+band)*math.sin(v*math.pi)
 z=-360+height*ridge(t+.035*math.sin(v*math.pi)*math.sin(t*math.tau*2),band)*envelope*ribs
 return Vector((math.sin(theta)*r,-math.cos(theta)*r,z))
def lerp(a,b,t):return tuple(x*(1-t)+y*t for x,y in zip(a,b))
seams=[];triangles=0
for band,(name,radius,depth,height,green,stone,haze) in enumerate(LAYERS):
 vertices=[];normals=[];colors=[];faces=[]
 for i in range(N+1):
  theta=-ANGLE/2+ANGLE*i/N
  for j in range(M+1):
   v=j/M;at=point(theta,v,band,radius,depth,height);vertices.append(tuple(at))
   da=point(theta+.0005,v,band,radius,depth,height)-point(theta-.0005,v,band,radius,depth,height)
   dr=point(theta,v+.0005,band,radius,depth,height)-point(theta,v-.0005,band,radius,depth,height)
   normal=dr.cross(da).normalized();normals.append(tuple(normal))
   rock=max(0,min(1,(at.z+180)/(height*.42)));c=lerp(green,stone,rock)
   snow=max(0,min(1,(at.z-(height*.62))/(height*.12)))*max(0,min(1,(normal.z-.35)/.45))
   c=lerp(c,(.89,.93,.94),snow);c=lerp(c,(.69,.79,.84),haze);colors.append((*c,1))
 for i in range(N):
  for j in range(M):
   a=i*(M+1)+j;b=(i+1)*(M+1)+j
   faces.extend([(a,a+1,b),(b,a+1,b+1)])
 mesh=bpy.data.meshes.new(name+' mountain ridge');mesh.from_pydata(vertices,[],faces);mesh.update()
 for f in mesh.polygons:f.use_smooth=True
 mesh.normals_split_custom_set_from_vertices(normals)
 attr=mesh.color_attributes.new(name='MountainColor',type='FLOAT_COLOR',domain='POINT')
 for i,c in enumerate(colors):attr.data[i].color=c
 obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);obj.parent=root;mesh.materials.append(mat)
 # Compare both positional and authored-normal joins after one exact unit turn.
 from mathutils import Matrix
 rotate=Matrix.Rotation(ANGLE,3,'Z')
 error=max((rotate@Vector(vertices[j])-Vector(vertices[N*(M+1)+j])).length for j in range(M+1))
 normal_error=max((rotate@Vector(normals[j])-Vector(normals[N*(M+1)+j])).length for j in range(M+1))
 assert error<.002 and normal_error<.001,(name,error,normal_error)
 seams.append({'layer':name,'position_error_m':error,'normal_error':normal_error});triangles+=len(faces)
assert triangles<=10000
bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'world-rise-backdrop.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'mountain-unit.glb'),export_format='GLB',export_yup=True,export_apply=True)
files=['art/source/environments/world-rise/world-rise-backdrop.blend','game/assets/environment/world_rise_backdrop/mountain-unit.glb']
record={'origin':'Original locally authored 3D mountain terrain and vertex colors. No downloads.','unit_angle_degrees':45,'repeat_count':8,'triangles_per_unit':triangles,'triangles_full_ring':triangles*8,'layers':3,'radii_m':[1800,2800,3900],'seam_checks':seams,'embedded_scripts':len(bpy.data.texts),'drivers':sum(len(o.animation_data.drivers) for o in bpy.data.objects if o.animation_data),'recipe':'tools/create_world_rise_backdrop.py','files':{n:hashlib.sha256((ROOT/n).read_bytes()).hexdigest() for n in files}}
(SRC/'runtime-assets.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
print('BACKDROP VERIFIED:',triangles,'triangles per unit;',triangles*8,'per full ring; periodic position/normal seams pass')
