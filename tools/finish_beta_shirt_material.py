"""Use the existing trusted seamless denim maps rather than crossing atlas seams."""
import bpy,json,hashlib,numpy as np
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];SOURCE=ROOT/'art/source/beta-heroine.blend'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE),load_ui=False,use_scripts=False)
bpy.context.preferences.filepaths.save_version=0
panel=bpy.data.objects['Denim continuous back and shoulder panel']
material=bpy.data.materials.new('Continuous back denim');material.use_nodes=True
nodes=material.node_tree.nodes;links=material.node_tree.links;p=nodes.get('Principled BSDF')
base=ROOT/'art/source/heroine-draft-materials/denim_fabric_05'
def texture(name,linear=False):
    image=bpy.data.images.load(str(base/name),check_existing=False);image.scale(1024,1024)
    if linear:image.colorspace_settings.name='Non-Color'
    image.pack();node=nodes.new('ShaderNodeTexImage');node.image=image;return node
color=texture('denim_fabric_05_diff_2k.png')
# Match the actual existing baked cloth colors, preserving seamless weave detail.
old=bpy.data.objects['Static_Human.punkduck_black_cocktail_dress_0'].data.materials[0]
old_image=next(node.image for node in old.node_tree.nodes if node.type=='TEX_IMAGE' and 'color' in node.image.name.lower())
pixels=np.asarray(old_image.pixels[:],dtype=np.float32).reshape(-1,4)
valid=(pixels[:,2]>pixels[:,0]*1.15)&(pixels[:,1]>pixels[:,0]*1.06)&(pixels[:,2]>.015)
target=np.median(pixels[valid,:3],axis=0)
raw=np.asarray(color.image.pixels[:],dtype=np.float32).reshape(-1,4)
denim_median=np.median(raw[:,:3],axis=0)
raw[:,:3]=np.clip(raw[:,:3]/np.maximum(denim_median,.001)*target,0,1);raw[:,3]=1
matched=bpy.data.images.new('Continuous matching denim albedo',width=1024,height=1024,alpha=True)
matched.pixels.foreach_set(raw.ravel());matched.pack();color.image=matched
links.new(color.outputs['Color'],p.inputs['Base Color'])
rough=texture('denim_fabric_05_rough_2k.png',True);links.new(rough.outputs['Color'],p.inputs['Roughness'])
normal=texture('denim_fabric_05_nor_gl_2k.png',True);nm=nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.75;links.new(normal.outputs['Color'],nm.inputs['Color']);links.new(nm.outputs[0],p.inputs['Normal'])
panel.data.materials.clear();panel.data.materials.append(material)
for poly in panel.data.polygons:
    for index in poly.loop_indices:
        at=panel.data.vertices[panel.data.loops[index].vertex_index].co
        panel.data.uv_layers.active.data[index].uv=(at.x*1.7+.5,at.z*1.7)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
path=ROOT/'art/character/shirt-review/coverage.json';report=json.loads(path.read_text(encoding='utf-8'));report.update(source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),panel_material=material.name,original_denim_material_reused=False,existing_seamless_denim_maps='art/source/heroine-draft-materials/denim_fabric_05',atlas_crossing_removed=True);path.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('CONTINUOUS_DENIM_UV_READY',target.tolist())
