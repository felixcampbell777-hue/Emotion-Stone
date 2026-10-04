"""Re-export the saved Blender sources without rebuilding or overwriting them."""
import bpy
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
for name in ['humanoid-v1','greatsword-v1']:
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/source'/f'{name}.blend'))
    options={'filepath':str(ROOT/'game/assets/characters'/f'{name}.glb'),'export_format':'GLB','export_animations':name=='humanoid-v1','export_animation_mode':'ACTIONS','export_frame_range':False,'export_force_sampling':True,'export_yup':True,'export_def_bones':True}
    valid={p.identifier for p in bpy.ops.export_scene.gltf.get_rna_type().properties}
    bpy.ops.export_scene.gltf(**{k:v for k,v in options.items() if k in valid})
print('SOURCE_EXPORT_OK')
