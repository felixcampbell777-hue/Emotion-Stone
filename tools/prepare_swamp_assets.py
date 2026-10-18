import bpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'art/environment/source/quaternius_stylized_nature_cc0/glTF';dest=ROOT/'game/assets/environment/swamp';dest.mkdir(parents=True,exist_ok=True)
for original,name in [('TwistedTree_2','twisted-tree'),('DeadTree_3','dead-tree'),('Grass_Wispy_Tall','reeds')]:
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(source/(original+'.gltf')))
 bpy.ops.export_scene.gltf(filepath=str(dest/(name+'.glb')),export_format='GLB',export_animations=False,export_yup=True)
 print('SWAMP_ASSET',name)
