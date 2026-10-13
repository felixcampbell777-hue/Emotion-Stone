"""Remove old overlapping rear cloth faces beneath the continuous back panel."""
import bpy,bmesh,json,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];SOURCE=ROOT/'art/source/beta-heroine.blend'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE),load_ui=False,use_scripts=False)
bpy.context.preferences.filepaths.save_version=0
removed={}
for name in ['Static_Denim open shirt collar and fitted yoke_0','Static_Denim short shirt sleeves_0','Static_Human.punkduck_black_cocktail_dress_0']:
    obj=bpy.data.objects[name];indices=[]
    for poly in obj.data.polygons:
        p=poly.center
        if 1.007<=p.z<=1.390 and abs(p.x)<=.267 and (abs(p.x)<=.164 or p.z>=1.197) and (p.y>=.008 or (abs(p.x)>.147 and p.y>=-.055 and p.z>=1.197)):
            indices.append(poly.index)
    bm=bmesh.new();bm.from_mesh(obj.data);bm.faces.ensure_lookup_table();bmesh.ops.delete(bm,geom=[bm.faces[i] for i in indices],context='FACES_ONLY');bm.to_mesh(obj.data);bm.free();removed[name]=len(indices)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
path=ROOT/'art/character/shirt-review/coverage.json';report=json.loads(path.read_text(encoding='utf-8'));report.update(source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),overlapping_old_back_faces_removed=removed);path.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('TIDIED_BACK_SEAMS',removed)
