"""Separate, user-requested static anime face study. Never overwrite main draft."""
import bpy, os, sys, json, hashlib, traceback
from mathutils import Vector
sys.path.insert(0, os.path.dirname(__file__))
import personal_heroine_face as face
import personal_heroine_appearance as appearance
from heroine_anime_style import manga_eyes,simplify_face_skin,graphic_lids

SOURCE=appearance.SOURCE
DRAFT=r'C:\Users\felix\OneDrive\Documents\heroinedraft-anime.blend'
OUTPUT=r'C:\Games\CoastalFoundation\output\verification\user-heroine-anime-draft'
STATUS=r'C:\Users\felix\AppData\Local\Temp\heroine_anime_status.json'
WEIGHTS={name:0.0 for name in face.WEIGHTS}
WEIGHTS.update({
    'cartoon/spamrakuen_toon_eyes_and_slim_body_head_only':.65,
    'cartoon/spamrakuen_anime_stylized_enhanced_head_only':.20,
    'cartoon/spamrakuen_sr_anime_female_lips_01':.20,
    'nose/nose-scale-depth-decr':.30,
})
PRESET_ROOT=r'C:\Games\CoastalFoundation\art\source\heroine-anime-presets\cartoon01\targets\cartoon'
TARGET_FILES={name:os.path.join(PRESET_ROOT,name.split('/')[-1]+'.target') for name in WEIGHTS if name.startswith('cartoon/')}
EYE_DELTA_SCALE=Vector((1,1,1))

def status(**record):
    os.makedirs(OUTPUT,exist_ok=True)
    with open(STATUS,'w') as f:json.dump(record,f,indent=2)

def richer_colors():
    # Correct the color after the existing textures; keep their UVs and detail.
    settings={
        'Human':(1.12,1.02),
        'Human.elvs_wavy_bob':(1.16,1.06),
        'Human.punkduck_black_cocktail_dress':(1.30,1.06),
        'Human.maciekg_leather_boots':(1.10,1.03),
        'Human.high-poly':(1.15,1.03),
    }
    edited={}
    for object_name,(saturation,value) in settings.items():
        obj=bpy.data.objects[object_name]
        for material in obj.data.materials:
            if not material or material.name in edited:continue
            nodes=material.node_tree.nodes;links=material.node_tree.links
            for bsdf in [n for n in nodes if n.type=='BSDF_PRINCIPLED']:
                base=bsdf.inputs['Base Color']
                old=next((link.from_socket for link in base.links),None)
                tint=nodes.new('ShaderNodeHueSaturation');tint.name='Anime draft richer color'
                tint.label='Anime alternate only: modest saturation and value'
                tint.inputs['Saturation'].default_value=saturation
                tint.inputs['Value'].default_value=value
                if old:links.new(old,tint.inputs['Color'])
                else:tint.inputs['Color'].default_value=base.default_value
                links.new(tint.outputs['Color'],base)
            edited[material.name]={'saturation':saturation,'value':value}
    return edited

def create():
    assert os.path.normcase(os.path.abspath(DRAFT))!=os.path.normcase(os.path.abspath(SOURCE))
    assert bpy.app.version[:2]==(5,2)
    # Reuse the face-fitting/audit recipe, with isolated file and evidence paths.
    face.CANDIDATE=DRAFT;face.STATUS=STATUS;face.OUTPUT=OUTPUT
    appearance.OUTPUT=OUTPUT
    face.WEIGHTS=WEIGHTS;face.EYE_DELTA_SCALE=EYE_DELTA_SCALE
    face.TARGET_FILES=TARGET_FILES
    # Apply the complete lower-face target, fading only through the neck.
    # The original narrower mask clipped the cartoon chin and mouth deformation.
    face.FACE_MASK_START=1.36;face.FACE_MASK_FADE=.04
    report=face.edit()
    colors=richer_colors()
    irises=manga_eyes()
    skin=simplify_face_skin()
    lids=graphic_lids()
    untouched_materials=set(report['original_materials'])-set(colors)
    # Compare unchanged shaders to the main draft before and after loading below.
    untouched_hash=appearance.shader_fingerprint(untouched_materials)
    all_names={o.name for o in bpy.data.objects}
    all_materials={m.name for m in bpy.data.materials if m.users}
    body=bpy.data.objects['Human']
    body['Heroine draft variant']='Separate anime face study; main draft remains authoritative'
    notes=bpy.data.texts.get('Heroine facial shaping');notes.clear()
    notes.write(json.dumps({'variant':'anime face alternate','main_source':SOURCE,'appearance_age':16,
        'weights':WEIGHTS,'eye_delta_axis_scale':list(EYE_DELTA_SCALE),'richer_material_colors':colors,'anime_irises':irises,'graphic_lids':lids,'simplified_skin':skin,
        'scope':'Face morphs, dependent facial attachments and modest material colors only',
        'approval':'Static review only; user verification precedes animation/game integration'},indent=2))
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=DRAFT,check_existing=False)
    report.update(variant='anime face alternate',draft=DRAFT,output=OUTPUT,
        richer_material_colors=colors,anime_irises=irises,graphic_lids=lids,simplified_skin=skin,untouched_materials=sorted(untouched_materials),
        untouched_materials_sha256=untouched_hash,
        draft_names=sorted(all_names),draft_geometry_sha256=appearance.fingerprint(all_names),
        draft_materials=sorted(all_materials),draft_materials_sha256=appearance.shader_fingerprint(all_materials))
    # Reopen actual saved draft, check complete saved state before rendering.
    bpy.ops.wm.open_mainfile(filepath=DRAFT);body=bpy.data.objects['Human']
    assert appearance.fingerprint(all_names)==report['draft_geometry_sha256']
    assert appearance.shader_fingerprint(all_materials)==report['draft_materials_sha256']
    assert face.original_keys_hash(body,set(report['original_keys']))==report['original_keys_sha256']
    assert face.original_keys_hash(body,{item['shape_key'] for item in report['targets']})==report['face_keys_sha256']
    assert body['Heroine intended facial age']==16
    assert hashlib.sha256(open(SOURCE,'rb').read()).hexdigest()==report['original_sha256'],'Main source changed'
    report['draft_sha256']=hashlib.sha256(open(DRAFT,'rb').read()).hexdigest()
    report['stage']='verified_saved_separate';status(**report)
    face.previews(report)
    assert hashlib.sha256(open(SOURCE,'rb').read()).hexdigest()==report['original_sha256']
    assert hashlib.sha256(open(DRAFT,'rb').read()).hexdigest()==report['draft_sha256']
    # Confirm the unaffected materials also match the original file, without saving it.
    bpy.ops.wm.open_mainfile(filepath=SOURCE)
    assert appearance.shader_fingerprint(untouched_materials)==untouched_hash
    report.update(stage='verified_complete',main_draft_unchanged=True,saved_draft_reopened=True)
    status(**report)
    with open(os.path.join(OUTPUT,'saved-model-checks.json'),'w') as f:json.dump(report,f,indent=2)

if __name__=='__main__':
    try:create()
    except Exception:status(stage='error',error=traceback.format_exc());raise
