"""Commit the visually reviewed static appearance without overwriting concurrent edits."""
import bpy,json,hashlib,traceback,os,sys
sys.path.insert(0,os.path.dirname(__file__))
from personal_heroine_appearance import SOURCE,CANDIDATE,STATUS,OUTPUT,fingerprint,shader_fingerprint
RESULT=r'C:\Users\felix\AppData\Local\Temp\heroine_appearance_commit_status.json'
try:
    report=json.load(open(STATUS))
    assert bpy.app.version[:2]==(5,2)
    assert report['stage']=='preview_complete'
    assert hashlib.sha256(open(SOURCE,'rb').read()).hexdigest()==report['original_sha256'],'Source changed during review'
    assert fingerprint(set(report['original_names']))==report['geometry_sha256']
    assert shader_fingerprint(set(report['original_materials']))==report['other_materials_sha256']
    assert bpy.data.objects.get('Human.elvs_short_daisy_hair') is None
    assert bpy.data.objects.get('Human.elvs_inverted_curly_bob') is None
    assert bpy.data.objects.get('Human.elvs_wavy_bob') is not None
    assert report['sword_hair_intersections']==0
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=SOURCE,check_existing=False)
    bpy.ops.wm.open_mainfile(filepath=SOURCE)
    assert fingerprint(set(report['original_names']))==report['geometry_sha256']
    assert shader_fingerprint(set(report['original_materials']))==report['other_materials_sha256']
    assert 'Heroine skin rest position' in bpy.data.objects['Human'].data.attributes
    result=dict(stage='verified_saved',source=SOURCE,version=bpy.app.version_string,hair='ELVS Wavy Bob',skin='warm outdoor tan and procedural nose/cheek freckles',other_geometry_and_rig_unchanged=True,other_materials_unchanged=True,sword_hair_intersections=0,sha256=hashlib.sha256(open(SOURCE,'rb').read()).hexdigest())
    with open(os.path.join(OUTPUT,'saved-model-checks.json'),'w') as f:json.dump(result,f,indent=2)
    with open(os.path.join(OUTPUT,'appearance-checks.json'),'w') as f:json.dump(report,f,indent=2)
    with open(os.path.join(OUTPUT,'static-review-checks.json'),'w') as f:json.dump(report,f,indent=2)
except Exception:result=dict(stage='error',error=traceback.format_exc())
with open(RESULT,'w') as f:json.dump(result,f,indent=2)
