"""Export the user's saved non-anime model, evaluated and material-baked, without animation."""
import bpy, bmesh, sys, os, json, hashlib, traceback, tempfile, array
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:\Games\CoastalFoundation')
SOURCE=Path(r'C:\Users\felix\OneDrive\Documents\heroinedraft1.blend')
OUTPUT=ROOT/'game/assets/characters/heroine-standalone.glb'
REPORT=ROOT/'art/character/standalone-export.json'
STATUS=Path(os.environ['TEMP'])/'heroine_static_export_status.json'
HEIGHT=1.67

def record(**data): STATUS.write_text(json.dumps(data,indent=2),encoding='utf-8')
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def export():
    assert bpy.app.version[:2]==(5,2), 'Use the user Blender 5.2, not project Blender 4.5'
    assert Path(bpy.data.filepath).resolve()==SOURCE.resolve()
    original_hash=sha(SOURCE)
    original=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.visible_get() and not o.hide_render]
    assert any(o.name=='Human' for o in original)
    assert not any(o.name.startswith('Anime') for o in original)
    dg=bpy.context.evaluated_depsgraph_get()
    collection=bpy.data.collections.new('Standalone export');bpy.context.scene.collection.children.link(collection)
    meshes=[];materials={}
    for source in original:
        data=bpy.data.meshes.new_from_object(source.evaluated_get(dg),preserve_all_data_layers=True,depsgraph=dg)
        if not data.polygons: continue
        data.transform(source.matrix_world)
        for i,material in enumerate(data.materials):
            if material:
                if material.name not in materials: materials[material.name]=material.copy()
                data.materials[i]=materials[material.name]
        # One material per mesh makes baking independent of other surface slots.
        for slot in sorted({p.material_index for p in data.polygons}):
            part=data.copy();bm=bmesh.new();bm.from_mesh(part)
            bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.material_index!=slot],context='FACES')
            bm.to_mesh(part);bm.free()
            mat=data.materials[slot];part.materials.clear();part.materials.append(mat)
            for p in part.polygons:p.material_index=0
            obj=bpy.data.objects.new('Static_'+source.name+'_'+str(slot),part);collection.objects.link(obj);meshes.append(obj)
        bpy.data.meshes.remove(data)
    for source in bpy.context.scene.objects:
        if source not in meshes: source.hide_render=True;source.hide_set(True)
    # Never use the oversized sword to determine human stature or ground contact.
    person=[o for o in meshes if o.name.startswith(('Static_Human_','Static_Human.maciekg_leather_boots_','Static_Human.elvs_wavy_bob_'))]
    coords=[v.co for o in person for v in o.data.vertices]
    bottom=min(v.z for v in coords);top=max(v.z for v in coords)
    factor=HEIGHT/(top-bottom)
    for obj in meshes:
        for v in obj.data.vertices: v.co=Vector((v.co.x*factor,v.co.y*factor,(v.co.z-bottom)*factor))
    bpy.context.scene.render.engine='CYCLES';bpy.context.scene.cycles.samples=1
    bpy.context.scene.cycles.use_denoising=False
    bpy.context.scene.render.bake.margin=12
    bpy.ops.object.select_all(action='DESELECT')
    for obj in meshes:
        obj.hide_set(False)
        if not obj.data.uv_layers:
            obj.select_set(True);bpy.context.view_layer.objects.active=obj
            bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
            bpy.ops.uv.smart_project(island_margin=.025);bpy.ops.object.mode_set(mode='OBJECT');obj.select_set(False)
    baked=[]
    with tempfile.TemporaryDirectory(prefix='heroine-static-') as temporary:
        for index,(name,material) in enumerate(materials.items()):
            record(stage='baking',material=name,index=index+1,total=len(materials))
            nodes=material.node_tree.nodes;links=material.node_tree.links
            bsdf=next((n for n in nodes if n.type=='BSDF_PRINCIPLED'),None)
            if bsdf is None: raise ValueError('Unsupported material '+name)
            users=[o for o in meshes if material in o.data.materials[:]]
            resolution=2048 if name in ['Human.body','Human.punkduck_black_cocktail_dress'] else 1024 if name.startswith('Human.') else 256
            output=next(n for n in nodes if n.type=='OUTPUT_MATERIAL' and n.is_active_output)
            surface=output.inputs['Surface'].links[0].from_socket
            emission=nodes.new('ShaderNodeEmission');links.new(emission.outputs[0],output.inputs['Surface'])
            texture=nodes.new('ShaderNodeTexImage');nodes.active=texture
            def bake_socket(socket,kind):
                image=bpy.data.images.new('Standalone '+name+' '+kind,width=resolution,height=resolution,alpha=True)
                image.colorspace_settings.name='sRGB' if kind=='color' else 'Non-Color'
                texture.image=image
                for link in list(emission.inputs['Color'].links): links.remove(link)
                if socket.is_linked: links.new(socket.links[0].from_socket,emission.inputs['Color'])
                else:
                    value=socket.default_value
                    emission.inputs['Color'].default_value=tuple(value) if hasattr(value,'__len__') else (value,value,value,1)
                bpy.ops.object.select_all(action='DESELECT')
                for n,obj in enumerate(users):
                    obj.select_set(True);bpy.context.view_layer.objects.active=obj
                    bpy.context.scene.render.bake.use_clear=n==0
                    bpy.ops.object.bake(type='EMIT');obj.select_set(False)
                return image
            albedo=bake_socket(bsdf.inputs['Base Color'],'color')
            alpha=bsdf.inputs['Alpha']
            has_alpha=alpha.is_linked or alpha.default_value<.999
            if has_alpha:
                opacity=bake_socket(alpha,'alpha')
                pixels=array.array('f',[0])*(resolution*resolution*4)
                other=array.array('f',[0])*len(pixels)
                albedo.pixels.foreach_get(pixels);opacity.pixels.foreach_get(other)
                for i in range(3,len(pixels),4): pixels[i]=other[i-3]
                albedo.pixels.foreach_set(pixels);albedo.update();bpy.data.images.remove(opacity)
            roughness=bsdf.inputs['Roughness'].default_value
            rough_image=bake_socket(bsdf.inputs['Roughness'],'roughness') if bsdf.inputs['Roughness'].is_linked else None
            metallic=bsdf.inputs['Metallic'].default_value
            normal_image=None
            links.new(surface,output.inputs['Surface'])
            if bsdf.inputs['Normal'].is_linked:
                normal_image=bpy.data.images.new('Standalone '+name+' normal',width=resolution,height=resolution)
                normal_image.colorspace_settings.name='Non-Color';texture.image=normal_image
                for n,obj in enumerate(users):
                    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
                    bpy.context.scene.render.bake.use_clear=n==0;bpy.ops.object.bake(type='NORMAL');obj.select_set(False)
            nodes.clear();shader=nodes.new('ShaderNodeBsdfPrincipled');out=nodes.new('ShaderNodeOutputMaterial')
            links.new(shader.outputs[0],out.inputs['Surface'])
            shader.inputs['Roughness'].default_value=roughness;shader.inputs['Metallic'].default_value=metallic
            shader.inputs['Specular IOR Level'].default_value=.25
            for image,slot in [(albedo,'Base Color'),(rough_image,'Roughness')]:
                if image:
                    node=nodes.new('ShaderNodeTexImage');node.image=image;links.new(node.outputs['Color'],shader.inputs[slot])
            # Alpha is baked into albedo for every surface; opaque surfaces remain 1.
            node=next(n for n in nodes if n.type=='TEX_IMAGE' and n.image==albedo)
            if has_alpha:
                links.new(node.outputs['Alpha'],shader.inputs['Alpha'])
                material.surface_render_method='DITHERED'
            if normal_image:
                node=nodes.new('ShaderNodeTexImage');node.image=normal_image
                normal=nodes.new('ShaderNodeNormalMap');links.new(node.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],shader.inputs['Normal'])
            for kind,image in [('color',albedo),('roughness',rough_image),('normal',normal_image)]:
                if image:
                    image.filepath_raw=str(Path(temporary)/(str(index)+'-'+kind+'.png'));image.file_format='PNG';image.save();image.pack()
            baked.append({'material':name,'resolution':resolution,'normal':normal_image is not None,'roughness':rough_image is not None})
        record(stage='exporting')
        bpy.ops.object.select_all(action='DESELECT')
        for obj in meshes: obj.select_set(True)
        OUTPUT.parent.mkdir(parents=True,exist_ok=True)
        bpy.ops.export_scene.gltf(filepath=str(OUTPUT),export_format='GLB',use_selection=True,export_animations=False,export_skins=False,export_morph=False,export_yup=True,export_cameras=False,export_lights=False)
    assert sha(SOURCE)==original_hash,'Original Blender file changed'
    report={'source':str(SOURCE),'source_sha256':original_hash,'export':str(OUTPUT.relative_to(ROOT)),'export_sha256':sha(OUTPUT),'recipe_sha256':sha(Path(__file__)),'blender':bpy.app.version_string,'static':True,'target_height_m':HEIGHT,'source_height_m':top-bottom,'scale_factor':factor,'ground_offset':bottom,'meshes':len(meshes),'triangles':sum(len(p.vertices)-2 for o in meshes for p in o.data.polygons),'materials':baked,'animations':0,'skins':0,'main_unchanged':True}
    REPORT.write_text(json.dumps(report,indent=2),encoding='utf-8');record(stage='complete',**report)

if __name__=='__main__':
    try: export()
    except Exception: record(stage='error',error=traceback.format_exc());raise
