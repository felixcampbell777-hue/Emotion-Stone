"""Small static outfit/face pass; no animation or game release changes."""
import bpy,bmesh,sys,os,json,gzip,traceback,math
from mathutils import Vector,Matrix
sys.path.insert(0,os.path.dirname(__file__))
from personal_heroine_appearance import SOURCE,OUTPUT,render_review
from personal_heroine_face import TARGET_ROOT
from personal_heroine_collar import ASSET,uv_density
from bl_ext.blender_org.mpfb.services.targetservice import TargetService
from bl_ext.blender_org.mpfb.services.humanservice import HumanService
STATUS=os.path.join(os.environ['TEMP'],'heroine_refine_status.json')
def status(**r):
    with open(STATUS,'w') as f:json.dump(r,f,indent=2)
try:
    assert bpy.app.version[:2]==(5,2)
    human=bpy.data.objects['Human'];dress=bpy.data.objects['Human.punkduck_black_cocktail_dress']
    weights={'mouth-upperlip-volume-decr':.42,'mouth-lowerlip-volume-decr':.48,'mouth-upperlip-height-decr':.23,'mouth-lowerlip-height-decr':.25,'mouth-upperlip-ext-up':.25,'mouth-lowerlip-ext-up':.30}
    for name,value in weights.items():
        path=os.path.join(TARGET_ROOT,'mouth',name+'.target.gz')
        with gzip.open(path,'rt') as f:txt=f.read()
        key=TargetService.target_string_to_shape_key(txt,TargetService.filename_to_shapekey_name(path),human,reuse_existing=True);key.value=value
    # Scale the full weapon about its back contact rather than separating parts.
    sword=[o for o in bpy.data.objects if o.name.startswith('Equipped Sword') and o.type=='MESH']
    dg=bpy.context.evaluated_depsgraph_get()
    pts=[o.matrix_world@Vector(c) for o in sword for c in o.evaluated_get(dg).bound_box]
    pivot=Vector((0,sum(p.y for p in pts)/len(pts),.78))
    transform=Matrix.Translation(pivot)@Matrix.Diagonal((1.15,1.15,1.15,1))@Matrix.Translation(-pivot)
    for o in sword:o.matrix_world=transform@o.matrix_world
    groups=set(g.name for g in human.vertex_groups);mods=set(m.name for m in human.modifiers)
    donor=HumanService.add_mhclo_asset(ASSET,human,subdiv_levels=0,import_subrig=False,import_weights=False)
    for m in list(human.modifiers):
        if m.name not in mods:human.modifiers.remove(m)
    for g in list(human.vertex_groups):
        if g.name not in groups:human.vertex_groups.remove(g)
    donor.name='Denim short shirt sleeves'
    bm=bmesh.new();bm.from_mesh(donor.data)
    # Donor shirt already fitted by MPFB. Retain shoulders/upper arms only.
    for x,n in [(.23,(1,0,0)),(-.23,(-1,0,0))]:
        bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=(x,0,0),plane_no=n,clear_outer=True)
    remove=[f for f in bm.faces if abs(f.calc_center_median().x)<.102 or f.calc_center_median().z<.79]
    bmesh.ops.delete(bm,geom=remove,context='FACES')
    loose=[v for v in bm.verts if not v.link_faces]
    if loose:bmesh.ops.delete(bm,geom=loose,context='VERTS')
    bm.to_mesh(donor.data);bm.free();donor.data.update()
    factor=uv_density(dress.data,True)/uv_density(donor.data)
    for uv in donor.data.uv_layers.active.data:uv.uv*=factor
    donor.data.materials.clear();donor.data.materials.append(dress.active_material)
    for p in donor.data.polygons:p.material_index=0;p.use_smooth=True
    sub=donor.modifiers.new('Soft short sleeve folds','SUBSURF');sub.levels=1
    thick=donor.modifiers.new('Denim sleeve thickness','SOLIDIFY');thick.thickness=.001
    bpy.context.view_layer.update()
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=SOURCE,check_existing=False)
    report={'stage':'saved','sword_scale':1.15,'lip_targets':weights,'sleeve_vertices':len(donor.data.vertices),'source':SOURCE,'animations_changed':False}
    status(**report)
    render_review(report,status)
except Exception:
    status(stage='error',error=traceback.format_exc());raise
