"""User-requested age-16 facial review using installed MakeHuman face targets."""
import bpy,os,sys,json,hashlib,traceback,math,gzip
from mathutils import Vector
from mathutils.bvhtree import BVHTree
sys.path.insert(0,os.path.dirname(__file__))
from personal_heroine_appearance import SOURCE,STORE,OUTPUT,fingerprint,shader_fingerprint,render_review
from bl_ext.blender_org.mpfb.services.targetservice import TargetService
from bl_ext.blender_org.mpfb.services.clothesservice import ClothesService
from bl_ext.blender_org.mpfb.entities.clothes.mhclo import Mhclo

CANDIDATE=r'C:\Users\felix\AppData\Local\Temp\heroine-face-review.blend'
STATUS=r'C:\Users\felix\AppData\Local\Temp\heroine_face_status.json'
TARGET_ROOT=STORE+r'\extensions\blender_org\mpfb\data\targets'
ASSET_ROOT=STORE+r'\extensions\.user\blender_org\mpfb\data'
APPEARANCE_AGE=16
TARGET_FILES={}
FACE_MASK_START=1.40
FACE_MASK_FADE=.055
WEIGHTS={
    'head/head-age-decr':.65,
    'head/head-fat-incr':.04,
    'cheek/l-cheek-volume-incr':.04,
    'cheek/r-cheek-volume-incr':.04,
    'cheek/l-cheek-volume-decr':.12,
    'cheek/r-cheek-volume-decr':.12,
    'chin/chin-bones-decr':.05,
    'chin/chin-width-decr':.18,
    'chin/chin-height-decr':.24,
    'chin/chin-prominent-decr':.12,
    'nose/nose-scale-depth-decr':.28,
    'nose/nose-scale-vert-decr':.25,
    'nose/nose-hump-decr':.12,
    'mouth/mouth-scale-horiz-decr':.07,
    'eyes/l-eye-scale-incr':.85,
    'eyes/r-eye-scale-incr':.85,
}
# Widen the openings and their matching eye helpers more than their height/depth.
# This is a reproducible per-axis adjustment to the installed native eye targets.
EYE_DELTA_SCALE=Vector((1,.65,.65))
FACIAL_ASSETS={
    'Human.high-poly':('eyes','high-poly'),
    'Human.eyebrow006':('eyebrows','eyebrow006'),
    'Human.eyelashes03':('eyelashes','eyelashes03'),
    'Human.teeth_base':('teeth','teeth_base'),
    'Human.tongue01':('tongue','tongue01'),
    'Human.elvs_wavy_bob':('hair','elvs_wavy_bob'),
}

def status(**data):
    with open(STATUS,'w') as f:json.dump(data,f,indent=2)

def target_path(name):
    return TARGET_FILES.get(name,os.path.join(TARGET_ROOT,name.replace('/',os.sep)+'.target.gz'))

def mix_coordinates(body):
    key=body.shape_key_add(name='temporary_face_audit',from_mix=True)
    coords=[v.co.copy() for v in key.data];body.shape_key_remove(key)
    return coords

def original_keys_hash(body,names):
    records=[]
    for k in body.data.shape_keys.key_blocks:
        if k.name in names:records.append([k.name,k.value,[list(v.co) for v in k.data]])
    return hashlib.sha256(json.dumps(records).encode()).hexdigest()

def edit():
    assert bpy.app.version[:2]==(5,2)
    source_sha=hashlib.sha256(open(SOURCE,'rb').read()).hexdigest()
    body=bpy.data.objects['Human']
    protected_names={o.name for o in bpy.data.objects if o.name not in FACIAL_ASSETS}
    protected_geometry=fingerprint(protected_names)
    materials={m.name for m in bpy.data.materials if m.users};materials_hash=shader_fingerprint(materials)
    intended_names={TargetService.filename_to_shapekey_name(target_path(name)) for name in WEIGHTS}
    keys=set(k.name for k in body.data.shape_keys.key_blocks if k.name not in intended_names);keys_hash=original_keys_hash(body,keys)
    before=mix_coordinates(body);basis=body.data.shape_keys.key_blocks['Basis']
    status(stage='editing',source=SOURCE,appearance_age=APPEARANCE_AGE)
    applied=[]
    for name,weight in WEIGHTS.items():
        path=target_path(name)
        key_name=TargetService.filename_to_shapekey_name(path)
        with (gzip.open(path,'rt',encoding='utf-8') if path.endswith('.gz') else open(path,'r',encoding='utf-8')) as f:target_text=f.read()
        key=TargetService.target_string_to_shape_key(target_text,key_name,body,reuse_existing=True);key.value=weight
        # Limit the age pass to head/face. Fade to zero above the unchanged neck.
        for idx,point in enumerate(key.data):
            rest=basis.data[idx].co
            mask=max(0,min(1,(rest.z-FACE_MASK_START)/FACE_MASK_FADE));mask=mask*mask*(3-2*mask)
            if abs(rest.x)>.16:mask=0
            delta=point.co-rest
            if name.startswith('eyes/') and '-eye-scale-' in name:
                delta=Vector(tuple(delta[i]*EYE_DELTA_SCALE[i] for i in range(3)))
            point.co=rest+delta*mask
        applied.append({'target':name,'shape_key':key.name,'weight':weight,'delta_axis_scale':list(EYE_DELTA_SCALE) if name.startswith('eyes/') and '-eye-scale-' in name else [1,1,1]})
    bpy.context.view_layer.update()
    after=mix_coordinates(body)
    unchanged=max((a-b).length for i,(a,b) in enumerate(zip(before,after)) if basis.data[i].co.z<=FACE_MASK_START)
    assert unchanged<1e-7,('Body below face changed',unchanged)
    assert original_keys_hash(body,keys)==keys_hash,'Existing MPFB sliders changed'
    # Fit all dependent face meshes to the new shape using their original MHCLO.
    refit=[]
    for object_name,(category,asset) in FACIAL_ASSETS.items():
        obj=bpy.data.objects.get(object_name)
        if obj is None:continue
        path=os.path.join(ASSET_ROOT,category,asset,asset+'.mhclo')
        mhclo=Mhclo();mhclo.load(path);mhclo.clothes=obj
        old_matrix=obj.matrix_world.copy()
        ClothesService.fit_clothes_to_human(obj,body,mhclo,set_parent=False)
        obj.matrix_world=old_matrix
        refit.append(object_name)
    bpy.context.view_layer.update()
    assert fingerprint(protected_names)==protected_geometry,'Protected body base, clothing, sword or rig changed'
    assert shader_fingerprint(materials)==materials_hash,'Existing appearance materials changed'
    assert original_keys_hash(body,keys)==keys_hash
    # The small hair refit must still clear the unchanged mounted sword.
    hair=bpy.data.objects['Human.elvs_wavy_bob'];ev=hair.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
    tree=BVHTree.FromPolygons([hair.matrix_world@v.co for v in mesh.vertices],[tuple(p.vertices) for p in mesh.polygons]);ev.to_mesh_clear()
    intersections=0
    for ob in bpy.data.objects:
        if ob.type!='MESH' or not ob.name.startswith('Equipped Sword'):continue
        for e in ob.data.edges:
            a,b=[ob.matrix_world@ob.data.vertices[i].co for i in e.vertices];delta=b-a
            if delta.length>1e-8 and tree.ray_cast(a,delta.normalized(),delta.length)[0] is not None:intersections+=1
    assert intersections==0,('Hair intersects sword after refit',intersections)
    body['Heroine intended facial age']=APPEARANCE_AGE
    notes=bpy.data.texts.get('Heroine facial shaping') or bpy.data.texts.new('Heroine facial shaping');notes.clear()
    notes.write(json.dumps({'intended_appearance_age':APPEARANCE_AGE,'method':'Installed MakeHuman facial shape targets, neck-masked; eye scale emphasizes width; facial attachments refitted via original MHCLO','weights':WEIGHTS,'eye_delta_axis_scale':list(EYE_DELTA_SCALE),'body_below_neck':'unchanged','existing_macro_sliders':'preserved','animations':'unchanged; user approval required'},indent=2))
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=CANDIDATE)
    face_keys_hash=original_keys_hash(body,{entry['shape_key'] for entry in applied})
    report=dict(stage='saved_review',source=SOURCE,candidate=CANDIDATE,original_sha256=source_sha,appearance_age=APPEARANCE_AGE,protected_names=sorted(protected_names),protected_geometry_sha256=protected_geometry,original_materials=sorted(materials),other_materials_sha256=materials_hash,original_keys=sorted(keys),original_keys_sha256=keys_hash,face_keys_sha256=face_keys_hash,targets=applied,refitted_face_assets=refit,body_below_neck_max_displacement=unchanged,max_face_displacement=max((a-b).length for a,b in zip(before,after)),sword_hair_intersections=intersections)
    status(**report)
    return report

def previews(report):
    render_review(dict(report),status)
    scene=bpy.context.scene;camera=scene.camera
    # Keep the collar review current after the changed face.
    camera.data.ortho_scale=.43;target=Vector((0,-.03,.915))
    camera.location=target+Vector((.35,-2,.07));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.resolution_x=1100;scene.render.resolution_y=1100
    scene.render.filepath=os.path.join(OUTPUT,'collar-close.png');bpy.ops.render.render(write_still=True)
    # Extra front and profile views establish proportions without perspective distortion.
    human=bpy.data.objects['Human'];dg=bpy.context.evaluated_depsgraph_get();ev=human.evaluated_get(dg);mesh=ev.to_mesh();rest=mesh.attributes['Heroine skin rest position'].data
    face=[human.matrix_world@v.co for v,a in zip(mesh.vertices,rest) if 1.46<a.vector.z<1.60 and abs(a.vector.x)<.08 and a.vector.y<-.10]
    ev.to_mesh_clear();center=sum(face,Vector())/len(face)+Vector((0,0,.015))
    camera.data.ortho_scale=.34
    for name,offset in [('face-front',(0,-2,.02)),('face-profile',(2,-.20,.02))]:
        camera.location=center+Vector(offset);camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=os.path.join(OUTPUT,name+'.png');bpy.ops.render.render(write_still=True)
    # Diagnostic profile without the obstructing hair, never saved to the model.
    hair=bpy.data.objects['Human.elvs_wavy_bob'];hair.hide_render=True
    scene.render.filepath=os.path.join(OUTPUT,'face-profile-uncovered.png');bpy.ops.render.render(write_still=True)
    hair.hide_render=False
    report['stage']='preview_complete';status(**report)

if __name__=='__main__':
    try:previews(edit())
    except Exception:status(stage='error',error=traceback.format_exc());raise
