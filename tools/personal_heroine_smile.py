"""Static facial review using CC0 authored MakeHuman ARKit smile shapes."""
import bpy,sys,os,json,hashlib,traceback,gzip,math
from mathutils import Vector
sys.path.insert(0,os.path.dirname(__file__))
from personal_heroine_appearance import SOURCE,STORE,OUTPUT,color,fingerprint
from personal_heroine_face import TARGET_ROOT,FACIAL_ASSETS,ASSET_ROOT
from bl_ext.blender_org.mpfb.services.targetservice import TargetService
from bl_ext.blender_org.mpfb.services.clothesservice import ClothesService
from bl_ext.blender_org.mpfb.entities.clothes.mhclo import Mhclo
ROOT=r'C:\Games\CoastalFoundation\art\source\heroine-expression-study'
CANDIDATE=os.path.join(os.environ['TEMP'],'heroine-smile-review.blend')
STATUS=os.path.join(os.environ['TEMP'],'heroine_smile_status.json')
WEIGHTS={'mouthSmileLeft':.70,'mouthSmileRight':.70,'cheekSquintLeft':.30,'cheekSquintRight':.30,'eyeSquintLeft':.12,'eyeSquintRight':.12,'browOuterUpLeft':.08,'browOuterUpRight':.08}
def status(**data):
    with open(STATUS,'w') as f:json.dump(data,f,indent=2)
def studio():
    scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE'
    scene.render.resolution_x=800;scene.render.resolution_y=800;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
    scene.view_settings.view_transform='AgX'
    world=bpy.data.worlds.new('Face review world');world.use_nodes=True;scene.world=world
    world.node_tree.nodes['Background'].inputs[0].default_value=(.16,.18,.21,1)
    world.node_tree.nodes['Background'].inputs[1].default_value=.35
    for ob in scene.objects:
        if ob.type=='LIGHT':ob.hide_render=True
    def aim(ob,where):ob.rotation_euler=(where-ob.location).to_track_quat('-Z','Y').to_euler()
    for name,loc,power,size in [('key',(-1.2,-1.5,2.4),190,1.5),('fill',(1.2,-1.1,1.7),100,1.5),('rim',(0,1,2),150,1)]:
        light=bpy.data.lights.new(name,'AREA');light.energy=power;light.size=size
        ob=bpy.data.objects.new(name,light);scene.collection.objects.link(ob);ob.location=loc;aim(ob,Vector((0,0,.9)))
    cd=bpy.data.cameras.new('Static facial review');cam=bpy.data.objects.new(cd.name,cd);scene.collection.objects.link(cam);scene.camera=cam;cd.type='ORTHO'
    return scene,cam,aim
def render_face(path,scene,cam,aim,scale=.35):
    b=bpy.data.objects['Human'];ev=b.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ev.to_mesh()
    rest=me.attributes['Heroine skin rest position'].data
    points=[b.matrix_world@v.co for v,a in zip(me.vertices,rest) if 1.46<a.vector.z<1.60 and abs(a.vector.x)<.08 and a.vector.y<-.10]
    center=sum(points,Vector())/len(points)+Vector((0,0,.015));ev.to_mesh_clear()
    cam.data.ortho_scale=scale;cam.location=center+Vector((.08,-2,.02));aim(cam,center)
    scene.render.filepath=path;bpy.ops.render.render(write_still=True)
def edit():
    assert bpy.app.version[:2]==(5,2)
    b=bpy.data.objects['Human'];keys=b.data.shape_keys.key_blocks
    protected={o.name for o in bpy.data.objects if o.name not in FACIAL_ASSETS}
    before=fingerprint(protected);sha=hashlib.sha256(open(SOURCE,'rb').read()).hexdigest()
    for key in keys:
        if key.name in ['mouth-corner-puller','mouth-upperlip-ext-up','mouth-lowerlip-ext-up'] or key.name.startswith('!ex-'):key.value=0
    # Existing artist-authored shapes replace the old isolated corner pull.
    for name,value in WEIGHTS.items():
        path=os.path.join(ROOT,'faceunits01','targets','faceunits',name+'.target')
        with open(path) as f:txt=f.read()
        key=TargetService.target_string_to_shape_key(txt,'!ex-'+name,b,reuse_existing=True);key.value=value
    # Colour only the lip topology affected by the native lip-volume targets.
    attr=b.data.attributes.get('Heroine natural lip tint') or b.data.attributes.new('Heroine natural lip tint','FLOAT','POINT')
    values={}
    for name in ['mouth-upperlip-volume-decr','mouth-lowerlip-volume-decr']:
        with gzip.open(os.path.join(TARGET_ROOT,'mouth',name+'.target.gz'),'rt') as f:
            for line in f:
                row=line.split()
                if len(row)!=4 or row[0].startswith('#'):continue
                idx=int(row[0]);d=math.sqrt(sum(float(x)**2 for x in row[1:]))
                values[idx]=max(values.get(idx,0),d)
    maximum=max(values.values())
    for idx,point in enumerate(attr.data):point.value=min(1,values.get(idx,0)/maximum*2.0)
    mat=b.active_material;nodes=mat.node_tree.nodes;links=mat.node_tree.links;p=nodes['Principled BSDF']
    old=next(link.from_socket for link in p.inputs['Base Color'].links)
    tint=nodes.get('Natural warm rose lips') or nodes.new('ShaderNodeMixRGB');tint.name='Natural warm rose lips'
    tint.blend_type='MIX';tint.inputs[2].default_value=color('aa5d58')
    mask=nodes.new('ShaderNodeAttribute');mask.attribute_name=attr.name;mask.name='Lip tint follows facial topology'
    amount=nodes.new('ShaderNodeMath');amount.operation='MULTIPLY';amount.inputs[1].default_value=.70
    links.new(mask.outputs['Fac'],amount.inputs[0]);links.new(amount.outputs[0],tint.inputs[0]);links.new(old,tint.inputs[1]);links.new(tint.outputs[0],p.inputs['Base Color'])
    bpy.context.view_layer.update()
    refitted=[]
    for objname,(category,asset) in FACIAL_ASSETS.items():
        if category=='hair':continue
        ob=bpy.data.objects.get(objname)
        if ob is None:continue
        mh=Mhclo();mh.load(os.path.join(ASSET_ROOT,category,asset,asset+'.mhclo'));mh.clothes=ob
        matrix=ob.matrix_world.copy();ClothesService.fit_clothes_to_human(ob,b,mh,set_parent=False);ob.matrix_world=matrix;refitted.append(objname)
    assert fingerprint(protected)==before,'Unrelated model geometry changed'
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=CANDIDATE)
    report={'stage':'saved_review','source':SOURCE,'source_sha256':sha,'candidate':CANDIDATE,'weights':WEIGHTS,'refitted':refitted,'unrelated_geometry_unchanged':True,'animations_changed':False,'game_changed':False,'preset_source':'Mika Suominen, CC0 faceunits01 authored ARKit smile/cheek shapes','tutorial':'https://studio.blender.org/training/stylized-character-workflow/5da0599be2e7bac4cc81bd61/','lip_tint':'muted warm rose, topology mask'}
    status(**report)
    scene,cam,aim=studio();render_face(os.path.join(OUTPUT,'smile-review.png'),scene,cam,aim)
    report['stage']='preview_complete';status(**report)
if __name__=='__main__':
    try:edit()
    except Exception:status(stage='error',error=traceback.format_exc());raise
