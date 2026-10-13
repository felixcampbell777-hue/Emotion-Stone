"""Save the reviewed facial pass while preserving concurrent user changes."""
import bpy,os,sys,json,hashlib,traceback
sys.path.insert(0,os.path.dirname(__file__))
from personal_heroine_face import SOURCE,CANDIDATE,STATUS,OUTPUT,APPEARANCE_AGE,fingerprint,shader_fingerprint,original_keys_hash
RESULT=r'C:\Users\felix\AppData\Local\Temp\heroine_face_commit_status.json'
try:
    report=json.load(open(STATUS));body=bpy.data.objects['Human']
    assert bpy.app.version[:2]==(5,2)
    assert report['stage']=='preview_complete'
    assert hashlib.sha256(open(SOURCE,'rb').read()).hexdigest()==report['original_sha256'],'Source changed during facial review'
    assert fingerprint(set(report['protected_names']))==report['protected_geometry_sha256']
    assert shader_fingerprint(set(report['original_materials']))==report['other_materials_sha256']
    assert original_keys_hash(body,set(report['original_keys']))==report['original_keys_sha256']
    face_keys={item['shape_key'] for item in report['targets']}
    current_face_hash=original_keys_hash(body,face_keys)
    if 'face_keys_sha256' in report:assert current_face_hash==report['face_keys_sha256']
    assert report['body_below_neck_max_displacement']<1e-7
    assert report['sword_hair_intersections']==0
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=SOURCE,check_existing=False)
    bpy.ops.wm.open_mainfile(filepath=SOURCE);body=bpy.data.objects['Human']
    assert fingerprint(set(report['protected_names']))==report['protected_geometry_sha256']
    assert shader_fingerprint(set(report['original_materials']))==report['other_materials_sha256']
    assert original_keys_hash(body,set(report['original_keys']))==report['original_keys_sha256']
    assert original_keys_hash(body,face_keys)==current_face_hash
    assert body['Heroine intended facial age']==APPEARANCE_AGE
    result=dict(stage='verified_saved',source=SOURCE,version=bpy.app.version_string,intended_facial_appearance_age=APPEARANCE_AGE,method='Adjustable neck-masked MakeHuman face targets with width-emphasized eye scale and refitted facial attachments',body_below_neck_outfit_sword_rig_and_materials_unchanged=True,original_macro_shape_keys_unchanged=True,sword_hair_intersections=0,sha256=hashlib.sha256(open(SOURCE,'rb').read()).hexdigest())
    for name,data in [('saved-model-checks.json',result),('face-checks.json',report),('static-review-checks.json',report)]:
        with open(os.path.join(OUTPUT,name),'w') as f:json.dump(data,f,indent=2)
except Exception:result=dict(stage='error',error=traceback.format_exc())
with open(RESULT,'w') as f:json.dump(result,f,indent=2)
