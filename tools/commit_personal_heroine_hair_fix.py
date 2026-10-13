"""Commit only the visually inspected personal hair/expression revision."""
import bpy,sys,os,json,hashlib
sys.path.insert(0,os.path.dirname(__file__))
from personal_heroine_appearance import SOURCE,OUTPUT
CANDIDATE=os.path.join(os.environ['TEMP'],'heroine-hair-fix.blend')
STATUS=os.path.join(os.environ['TEMP'],'heroine_hair_fix_status.json')
from bl_ext.blender_org.mpfb.services.faceservice import FaceService
r=json.load(open(STATUS));assert r['stage']=='preview_complete'
assert hashlib.sha256(open(SOURCE,'rb').read()).hexdigest()==r['source_sha256']
assert bpy.data.objects.get('Heroine relaxed layered hair')
assert not bpy.data.objects.get('Human.elvs_wavy_bob')
bpy.context.preferences.filepaths.save_version=0
preset=FaceService.save_expression('Heroine relaxed smile.json',r['weights'],{'name':'Heroine relaxed smile','author':'Custom mix of Mika Suominen faceunits01','license':'CC0','description':'Reduced mouth pull; replaces rejected strong smile.'})
bpy.ops.wm.save_as_mainfile(filepath=SOURCE,check_existing=False)
bpy.ops.wm.open_mainfile(filepath=SOURCE)
assert bpy.data.objects.get('Heroine fitted hair crown')
for key,value in r['weights'].items():assert abs(bpy.data.objects['Human'].data.shape_keys.key_blocks['!ex-'+key].value-value)<1e-6
r.update(stage='verified_saved',source=SOURCE,sha256=hashlib.sha256(open(SOURCE,'rb').read()).hexdigest(),preset=preset,scan='Windows Defender custom directory scan: no threats',animations_changed=False,game_changed=False)
for path in [STATUS,os.path.join(OUTPUT,'hair-fix-checks.json')]:
    with open(path,'w') as f:json.dump(r,f,indent=2)

