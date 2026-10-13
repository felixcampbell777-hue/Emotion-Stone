"""Read-only personal model intake; reuse the established PBR baker and motion library."""
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
import beta_rig

source=(Path(__file__).parent/'export_personal_heroine_static.py').read_text(encoding='utf-8')
changes={
    'import bpy, bmesh, sys, os, json, hashlib, traceback, tempfile, array':'import bpy, bmesh, sys, os, json, hashlib, traceback, tempfile, array\nimport beta_rig',
    'heroine-standalone.glb':'heroine-beta.glb',
    'standalone-export.json':'beta-heroine-export.json',
    'heroine_static_export_status.json':'heroine_beta_export_status.json',
    "assert bpy.app.version[:2]==(5,2), 'Use the user Blender 5.2, not project Blender 4.5'":"assert bpy.app.version[:2] in [(4,5),(5,2)]",
    'original_hash=sha(SOURCE)':'original_hash=sha(SOURCE)\n    beta_rig.prepare()',
    'and not o.hide_render]':"and not o.hide_render and not o.name.startswith(('Equipped Sword','Back sword'))]",
    'collection.objects.link(obj);meshes.append(obj)':'collection.objects.link(obj);meshes.append(obj);beta_rig.weights(obj,source)',
    "bpy.context.scene.render.engine='CYCLES'":"rig,clips=beta_rig.create(meshes,factor,bottom)\n    bpy.context.scene.render.engine='CYCLES'",
    "resolution=2048 if name in ['Human.body','Human.punkduck_black_cocktail_dress'] else 1024 if name.startswith('Human.') else 256":"resolution=1024 if name in ['Human.body','Human.punkduck_black_cocktail_dress'] else 512 if name.startswith('Human.') or 'hair' in name.lower() else 256",
    'OUTPUT.parent.mkdir(parents=True,exist_ok=True)':'rig.select_set(True)\n        bpy.context.view_layer.objects.active=rig\n        OUTPUT.parent.mkdir(parents=True,exist_ok=True)',
    'export_animations=False,export_skins=False':"export_animations=True,export_animation_mode='NLA_TRACKS',export_skins=True",
    "'static':True":"'static':False",
    "'animations':0,'skins':0":"'animations':clips,'skins':1,'method':'Existing canonical movement/combat actions, consolidated saved MakeHuman weights; no new hand-authored motion'",
    "REPORT.write_text(json.dumps(report,indent=2),encoding='utf-8');record(stage='complete',**report)":"REPORT.write_text(json.dumps(report,indent=2),encoding='utf-8')\n    for obj in list(bpy.data.objects):\n        if obj not in meshes and obj!=rig:bpy.data.objects.remove(obj,do_unlink=True)\n    bpy.context.preferences.filepaths.save_version=0\n    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/source/beta-heroine.blend'))\n    record(stage='complete',**report)",
}
for before,after in changes.items():
    if before not in source:raise ValueError('Baker contract changed: '+before)
    source=source.replace(before,after)
exec(compile(source,__file__,'exec'),globals())
