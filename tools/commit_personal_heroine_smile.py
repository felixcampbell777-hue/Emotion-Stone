"""Commit the inspected facial candidate and save its reusable MPFB preset."""
import bpy,sys,os,json,hashlib,traceback,shutil
sys.path.insert(0,os.path.dirname(__file__))
from personal_heroine_smile import SOURCE,ROOT,STATUS,OUTPUT
from personal_heroine_face import ASSET_ROOT
from bl_ext.blender_org.mpfb.services.faceservice import FaceService
try:
    report=json.load(open(STATUS));assert report['stage']=='preview_complete'
    assert hashlib.sha256(open(SOURCE,'rb').read()).hexdigest()==report['source_sha256'],'Source changed during review'
    assert bpy.app.version[:2]==(5,2)
    for section in ['targets','packs']:
        shutil.copytree(os.path.join(ROOT,'faceunits01',section),os.path.join(ASSET_ROOT,section),dirs_exist_ok=True)
    preset=FaceService.save_expression('Heroine relaxed smile.json',report['weights'],{'name':'Heroine relaxed smile','description':'Relaxed smile using authored CC0 ARKit smile/cheek shapes, with subtle lower eyelid lift and brow relaxation.','tags':['smile','heroine'],'author':'Custom mix of Mika Suominen faceunits01','license':'CC0','homepage':'https://static.makehumancommunity.org/assets/assetpacks/faceunits01.html'})
    FaceService.load_expression(preset)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=SOURCE,check_existing=False)
    bpy.ops.wm.open_mainfile(filepath=SOURCE)
    b=bpy.data.objects['Human']
    for name,weight in report['weights'].items():assert abs(b.data.shape_keys.key_blocks['!ex-'+name].value-weight)<1e-6
    assert b.active_material.node_tree.nodes.get('Natural warm rose lips')
    report.update(stage='verified_saved',preset=preset,sha256=hashlib.sha256(open(SOURCE,'rb').read()).hexdigest(),hair_changed=False)
    with open(os.path.join(OUTPUT,'smile-checks.json'),'w') as f:json.dump(report,f,indent=2)
    with open(STATUS,'w') as f:json.dump(report,f,indent=2)
except Exception:
    with open(STATUS,'w') as f:json.dump({'stage':'error','error':traceback.format_exc()},f,indent=2)
    raise
