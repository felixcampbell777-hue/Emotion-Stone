"""Two fitted CC0 hair previews; main Blender source is never saved here."""
import bpy,sys,os,json,hashlib,traceback
sys.path.insert(0,os.path.dirname(__file__))
from personal_heroine_smile import SOURCE,OUTPUT,studio,render_face
from personal_heroine_appearance import color
from bl_ext.blender_org.mpfb.services.humanservice import HumanService
ROOT=r'C:\Games\CoastalFoundation\art\source\heroine-hair-study'
STATUS=os.path.join(os.environ['TEMP'],'heroine_hair_study_status.json')
def status(**r):
    with open(STATUS,'w') as f:json.dump(r,f,indent=2)
try:
    assert bpy.app.version[:2]==(5,2)
    sha=hashlib.sha256(open(SOURCE,'rb').read()).hexdigest()
    b=bpy.data.objects['Human'];old=bpy.data.objects['Human.elvs_wavy_bob'];old.hide_render=True
    scene,cam,aim=studio();samples=[]
    for asset in ['cortu_shaggy_green_hair','cortu_short_messy_hair']:
        groups=set(g.name for g in b.vertex_groups);mods=set(m.name for m in b.modifiers)
        status(stage='fitting',asset=asset)
        path=os.path.join(ROOT,'hair',asset,asset+'.mhclo')
        hair=HumanService.add_mhclo_asset(path,b,asset_type='Hair',subdiv_levels=0,material_type='MAKESKIN',set_up_rigging=False,import_subrig=False,import_weights=False)
        for m in list(b.modifiers):
            if m.name not in mods:b.modifiers.remove(m)
        for g in list(b.vertex_groups):
            if g.name not in groups:b.vertex_groups.remove(g)
        hair.hide_render=False;hair.hide_set(False)
        for mat in hair.data.materials:
            nodes=mat.node_tree.nodes;links=mat.node_tree.links;p=nodes.get('Principled BSDF')
            tex=next((n for n in nodes if n.type=='TEX_IMAGE' and n.image and ('diffuse' in n.name.lower() or n.name=='Image Texture')),None)
            if p and tex:
                lum=nodes.new('ShaderNodeRGBToBW');links.new(tex.outputs['Color'],lum.inputs[0])
                ramp=nodes.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].color=color('24150e');ramp.color_ramp.elements[1].color=color('906344')
                ramp.color_ramp.elements[1].position=.6;links.new(lum.outputs[0],ramp.inputs[0]);links.new(ramp.outputs[0],p.inputs['Base Color'])
                p.inputs['Roughness'].default_value=.72;p.inputs['Specular IOR Level'].default_value=.20
        out=os.path.join(OUTPUT,'hair-'+asset+'.png');render_face(out,scene,cam,aim,.47)
        samples.append({'asset':asset,'author':'Cortu','license':'CC0','render':out,'vertices':len(hair.data.vertices),'fit':'MPFB native fit to current personal face/body; recoloured chestnut','altered_source':False})
        bpy.data.objects.remove(hair,do_unlink=True)
    assert hashlib.sha256(open(SOURCE,'rb').read()).hexdigest()==sha
    report={'stage':'complete','source':SOURCE,'source_sha256':sha,'samples':samples,'main_hair_unchanged':True,'animations_changed':False,'game_changed':False}
    status(**report)
    with open(os.path.join(OUTPUT,'hair-study.json'),'w') as f:json.dump(report,f,indent=2)
except Exception:status(stage='error',error=traceback.format_exc());raise
