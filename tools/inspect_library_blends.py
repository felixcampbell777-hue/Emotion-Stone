"""Read-only source inventory. Run Blender with --factory-startup --disable-autoexec."""
import json
import sys
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art/library/source'
report = ROOT/'art/library/BLENDER-INVENTORY.json'
quaternius_only = '--quaternius-only' in sys.argv
rows = [r for r in json.loads(report.read_text(encoding='utf-8')) if not r['file'].startswith('quaternius-')] if quaternius_only else []
paths = [p for p in sorted(SOURCE.rglob('*.blend')) if not quaternius_only or p.relative_to(SOURCE).parts[0].startswith('quaternius-')]
for path in paths:
    row = {'file': str(path.relative_to(SOURCE))}
    try:
        bpy.ops.wm.open_mainfile(filepath=str(path), load_ui=False, use_scripts=False)
        meshes = [o for o in bpy.data.objects if o.type == 'MESH']
        rigs = [o for o in bpy.data.objects if o.type == 'ARMATURE']
        row.update({
            'opened_with_autoexec_disabled': True,
            'source_modified': False,
            'mesh_objects': len(meshes),
            'triangles_before_modifiers': sum(max(0,len(p.vertices)-2) for o in meshes for p in o.data.polygons),
            'armatures': [{'name':o.name,'bones':len(o.data.bones)} for o in rigs],
            'actions': [{'name':a.name,'frames':list(a.frame_range)} for a in bpy.data.actions],
            'embedded_text_blocks_not_executed': [t.name for t in bpy.data.texts],
            'embedded_text_review': [{'name':t.name,'looks_like_python':bool(__import__('re').search(r'(^|\n)\s*(import |from |def |class |exec\(|eval\()', t.as_string())),'license_text':t.as_string() if 'lic' in t.name.lower() else None} for t in bpy.data.texts],
            'objects_with_drivers': [o.name for o in bpy.data.objects if o.animation_data and o.animation_data.drivers],
            'images': [{'name':im.name,'packed':bool(im.packed_file),'path':im.filepath,'size':list(im.size)} for im in bpy.data.images if im.type == 'IMAGE'],
            'materials': [m.name for m in bpy.data.materials],
            'integration_status':'not exported, rendered, retargeted, or tested in the game; legacy materials may need rebuilding'
        })
    except Exception as exc:
        row['error'] = str(exc)
    rows.append(row)
    print('READ_ONLY_ASSET', path.parent.name, row.get('triangles_before_modifiers'), len(row.get('actions',[])), flush=True)
for path in ([] if quaternius_only else sorted((SOURCE/'crab').rglob('*.fbx'))):
    row = {'file':str(path.relative_to(SOURCE))}
    try:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.fbx(filepath=str(path))
        row.update({'source_modified':False,'mesh_objects':[o.name for o in bpy.data.objects if o.type == 'MESH'],'armatures':[{'name':o.name,'bones':len(o.data.bones)} for o in bpy.data.objects if o.type == 'ARMATURE'],'actions':[{'name':a.name,'frames':list(a.frame_range)} for a in bpy.data.actions],'images':[{'name':im.name,'path':im.filepath,'size':list(im.size)} for im in bpy.data.images],'integration_status':'read-only FBX import; no export or game integration'})
    except Exception as exc:
        row['error']=str(exc)
    rows.append(row)
report.write_text(json.dumps(rows,indent=2)+'\n',encoding='utf-8')
