"""Commit a visually reviewed collar candidate, keeping the original scene setup."""
import bpy,os,sys,json,hashlib,traceback
sys.path.insert(0,os.path.dirname(__file__))
from personal_heroine_collar import SOURCE,CANDIDATE,STATUS,OUTPUT,fingerprint,shader_fingerprint
RESULT=r'C:\Users\felix\AppData\Local\Temp\heroine_collar_commit_status.json'
try:
    report=json.load(open(STATUS))
    assert bpy.app.version[:2]==(5,2)
    assert report['stage']=='preview_complete'
    assert hashlib.sha256(open(SOURCE,'rb').read()).hexdigest()==report['original_sha256'],'Personal draft changed during review'
    assert fingerprint(set(report['original_names']))==report['geometry_sha256'],'Original geometry/rig changed'
    assert shader_fingerprint(set(report['original_materials']))==report['other_materials_sha256'],'Existing materials changed'
    assert report['sword_collar_intersections']==0
    assert bpy.data.objects.get('Human.male_casualsuit01') is None
    assert bpy.data.objects.get('Denim open shirt collar and fitted yoke') is not None
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=SOURCE,check_existing=False)
    bpy.ops.wm.open_mainfile(filepath=SOURCE)
    assert fingerprint(set(report['original_names']))==report['geometry_sha256']
    assert shader_fingerprint(set(report['original_materials']))==report['other_materials_sha256']
    assert len([o for o in bpy.data.objects if o.name.startswith('Shirt button ')])==4
    result=dict(stage='verified_saved',source=SOURCE,version=bpy.app.version_string,collar='Fitted CC0 male_casualsuit01 open collar/yoke with four-button placket',hair='ELVS Wavy Bob',skin='Warm outdoor tan and freckles',original_body_dress_equipment_and_rig_unchanged=True,existing_materials_unchanged=True,sword_collar_intersections=0,sha256=hashlib.sha256(open(SOURCE,'rb').read()).hexdigest())
    for name,data in [('saved-model-checks.json',result),('collar-checks.json',report),('static-review-checks.json',report)]:
        with open(os.path.join(OUTPUT,name),'w') as f:json.dump(data,f,indent=2)
except Exception:result=dict(stage='error',error=traceback.format_exc())
with open(RESULT,'w') as f:json.dump(result,f,indent=2)
