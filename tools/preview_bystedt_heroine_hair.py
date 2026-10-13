"""Static external hair fitting study; never saves the personal main file."""
import bpy,os,sys,json,hashlib,traceback
from mathutils import Vector,Matrix
sys.path.insert(0,os.path.dirname(__file__))
from personal_heroine_smile import SOURCE,OUTPUT,studio,render_face
from personal_heroine_appearance import color
LIB=r'C:\Games\CoastalFoundation\art\source\heroine-hair-study\bystedt\hair-styles.blend'
STATUS=os.path.join(os.environ['TEMP'],'heroine_bystedt_status.json')
def status(**r):
    with open(STATUS,'w') as f:json.dump(r,f,indent=2)
try:
    sha=hashlib.sha256(open(SOURCE,'rb').read()).hexdigest()
    original_materials=set(m.name for m in bpy.data.materials)
    with bpy.data.libraries.load(LIB,link=False) as (src,dst):dst.collections=['Long hair']
    collection=dst.collections[0];bpy.context.scene.collection.children.link(collection)
    bpy.context.view_layer.update()
    info=[]
    for o in collection.all_objects:
        info.append({'name':o.name,'type':o.type,'location':list(o.location),'scale':list(o.scale),'bounds':[[min(c[i] for c in o.bound_box),max(c[i] for c in o.bound_box)] for i in range(3)],'hide_render':o.hide_render,'surface':o.data.surface.name if o.type=='CURVES' and o.data.surface else None})
    hero=bpy.data.objects['Human'];ev=hero.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ev.to_mesh()
    rest=me.attributes['Heroine skin rest position'].data
    scalp=[hero.matrix_world@v.co for v,a in zip(me.vertices,rest) if 1.59<a.vector.z<1.80 and abs(a.vector.x)<.10 and -.10<a.vector.y<.12]
    lo=Vector([min(p[i] for p in scalp) for i in range(3)]);hi=Vector([max(p[i] for p in scalp) for i in range(3)]);ev.to_mesh_clear()
    growth=bpy.data.objects['long hair growth mesh'];source_pts=[growth.matrix_world@Vector(c) for c in growth.bound_box]
    slo=Vector([min(p[i] for p in source_pts) for i in range(3)]);shi=Vector([max(p[i] for p in source_pts) for i in range(3)])
    scale=(hi.x-lo.x)/(shi.x-slo.x)*1.03
    source_anchor=Vector(((shi.x+slo.x)/2,(shi.y+slo.y)/2,shi.z))
    target_anchor=Vector(((hi.x+lo.x)/2,(hi.y+lo.y)/2-.018,hi.z-.012))
    transform=Matrix.Translation(target_anchor)@Matrix.Diagonal((scale,scale,scale,1))@Matrix.Translation(-source_anchor)
    objects=list(collection.all_objects);worlds={o.name:o.matrix_world.copy() for o in objects}
    for ob in objects:
        ob.parent=None;ob.matrix_world=transform@worlds[ob.name]
        ob.hide_render=ob.name not in ['long hair main','long hair strands']
    bpy.data.objects['Human.elvs_wavy_bob'].hide_render=True
    for mat in [m for m in bpy.data.materials if m.name not in original_materials]:
            mat.use_nodes=True;nodes=mat.node_tree.nodes;links=mat.node_tree.links;nodes.clear()
            out=nodes.new('ShaderNodeOutputMaterial');p=nodes.new('ShaderNodeBsdfPrincipled')
            p.inputs['Base Color'].default_value=color('41271a');p.inputs['Roughness'].default_value=.65;p.inputs['Specular IOR Level'].default_value=.15
            links.new(p.outputs[0],out.inputs['Surface'])
    bpy.context.view_layer.update()
    scene,cam,aim=studio();render_face(os.path.join(OUTPUT,'hair-bystedt-wavy-preview.png'),scene,cam,aim,.47)
    assert hashlib.sha256(open(SOURCE,'rb').read()).hexdigest()==sha
    status(stage='preview_complete',objects=info,source_sha256=sha,fit_scale=scale,hero_scalp=[list(lo),list(hi)],main_unchanged=True,license='CC-BY-SA, Daniel Bystedt',render=os.path.join(OUTPUT,'hair-bystedt-wavy-preview.png'))
except Exception:status(stage='error',error=traceback.format_exc());raise
