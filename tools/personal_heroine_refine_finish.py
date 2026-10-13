"""Finish static smile and clean sleeve hems on current personal draft."""
import bpy,bmesh,sys,os,gzip,json,traceback
sys.path.insert(0,os.path.dirname(__file__))
from personal_heroine_appearance import SOURCE,OUTPUT,render_review
from personal_heroine_face import TARGET_ROOT
from bl_ext.blender_org.mpfb.services.targetservice import TargetService
STATUS=os.path.join(os.environ['TEMP'],'heroine_refine_status.json')
def status(**r):
    with open(STATUS,'w') as f:json.dump(r,f,indent=2)
try:
    body=bpy.data.objects['Human']
    for name,value in [('mouth-corner-puller',.55),('cheek-raiser',.12)]:
        path=os.path.join(TARGET_ROOT,'expression','units','caucasian',name+'.target.gz')
        if not os.path.exists(path):continue
        with gzip.open(path,'rt') as f:txt=f.read()
        k=TargetService.target_string_to_shape_key(txt,TargetService.filename_to_shapekey_name(path),body,reuse_existing=True);k.value=value
    ob=bpy.data.objects['Denim short shirt sleeves'];bm=bmesh.new();bm.from_mesh(ob.data)
    # Close gaps in the donor shoulder cut by slightly overlapping the yoke.
    for v in bm.verts:
        if abs(v.co.x)<.115:v.co.x*=.95
    # The cut is planar, so the sleeve gets an even finished hem rather than
    # retaining the donor's irregular triangle silhouettes under subdivision.
    for side in [-1,1]:
        boundary=[v for v in bm.verts if v.is_boundary and side*v.co.x>.19]
        for v in boundary:v.co.x=side*.222
        edges=[e for e in bm.edges if e.is_boundary and all(side*v.co.x>.19 for v in e.verts)]
        if edges:
            result=bmesh.ops.extrude_edge_only(bm,edges=edges)
            for v in result['geom']:
                if isinstance(v,bmesh.types.BMVert):v.co.x+=side*.006
    bm.to_mesh(ob.data);bm.free();ob.data.update()
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=SOURCE,check_existing=False)
    report={'stage':'saved','source':SOURCE,'sword_enlarged_percent':15,'expression':'gentle closed-mouth smile','sleeves':'short denim sleeves','lips':'reduced volume and height','animations_changed':False,'game_release_changed':False}
    render_review(report,status)
    with open(os.path.join(OUTPUT,'refinement-checks.json'),'w') as f:json.dump(report,f,indent=2)
except Exception:
    status(stage='error',error=traceback.format_exc());raise
