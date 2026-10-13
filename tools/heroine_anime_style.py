"""Fit the reviewed CC0 Manga Eye data and clean graphic lids to the static draft."""
import bpy,math,os
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from personal_heroine_appearance import color
EYE_SOURCE=r'C:\Games\CoastalFoundation\art\source\heroine-anime-presets\mngeye_base.blend'

def manga_eyes():
    eye=bpy.data.objects['Human.high-poly']
    original_uv=eye.data.uv_layers.active
    with bpy.data.libraries.load(EYE_SOURCE,link=False) as (available,loaded):
        assert 'mngeye_base' in available.materials
        loaded.materials=['mngeye_base']
    material=loaded.materials[0];material.name='CC0 Manga Eye - heroine study'
    nodes=material.node_tree.nodes;links=material.node_tree.links
    bsdf=nodes['Principled BSDF']
    if 'Weight' in bsdf.inputs:bsdf.inputs['Weight'].default_value=1
    uvnode=nodes.new('ShaderNodeUVMap');uvnode.uv_map='Anime front projection'
    links.new(uvnode.outputs['UV'],nodes['Mapping'].inputs['Vector'])
    # Preserve the author's native graphic iris/pupil/ring graph.
    nodes['Value.007'].outputs[0].default_value=1.4
    nodes['Value.002'].outputs[0].default_value=1.18
    nodes['Value.005'].outputs[0].default_value=3.0
    nodes['Value.004'].outputs[0].default_value=1.0
    nodes['RGB.001'].outputs[0].default_value=color('431b22')
    nodes['RGB.002'].outputs[0].default_value=color('a85743')
    nodes['Normal'].outputs[0].default_value=(.25,-.93,.25)
    # A small graphic catchlight stays stable across Blender versions and views.
    old_color=bsdf.inputs['Base Color'].links[0].from_socket
    distance=nodes.new('ShaderNodeVectorMath');distance.operation='DISTANCE'
    links.new(uvnode.outputs['UV'],distance.inputs[0]);distance.inputs[1].default_value=(.60,.62,0)
    dot=nodes.new('ShaderNodeMath');dot.operation='LESS_THAN'
    links.new(distance.outputs['Value'],dot.inputs[0]);dot.inputs[1].default_value=.045
    catchlight=nodes.new('ShaderNodeMixRGB');catchlight.name='Small graphic iris catchlight'
    links.new(dot.outputs[0],catchlight.inputs[0]);links.new(old_color,catchlight.inputs[1]);catchlight.inputs[2].default_value=(1,1,1,1)
    links.new(catchlight.outputs[0],bsdf.inputs['Base Color'])
    clear=bpy.data.materials.new('Anime corneal shell transparent');clear.use_nodes=True
    clear.node_tree.nodes.clear();transparent=clear.node_tree.nodes.new('ShaderNodeBsdfTransparent');output=clear.node_tree.nodes.new('ShaderNodeOutputMaterial')
    clear.node_tree.links.new(transparent.outputs[0],output.inputs['Surface'])
    eye.data.materials.clear();eye.data.materials.append(material);eye.data.materials.append(clear)
    projected=eye.data.uv_layers.new(name='Anime front projection')
    globe_polygons=[]
    for polygon in eye.data.polygons:
        uvs=[original_uv.data[i].uv for i in polygon.loop_indices]
        cornea=all(uv.x>.80 and uv.y<.20 for uv in uvs)
        polygon.material_index=1 if cornea else 0
        if not cornea:globe_polygons.append(polygon)
    centers={}
    for sign in [-1,1]:
        indices={i for p in globe_polygons for i in p.vertices if eye.data.vertices[i].co.x*sign>0}
        points=[eye.data.vertices[i].co for i in indices]
        x0,x1=min(p.x for p in points),max(p.x for p in points)
        z0,z1=min(p.z for p in points),max(p.z for p in points)
        centers[sign]=((x0+x1)/2,(z0+z1)/2,x1-x0,z1-z0)
    for loop in eye.data.loops:
        point=eye.data.vertices[loop.vertex_index].co;cx,cz,w,h=centers[1 if point.x>0 else -1]
        projected.data[loop.index].uv=((point.x-cx)/w+.5,(point.z-cz)/h+.5)
    # Original atlas stays available; explicit UVMap chooses only the anime layer.
    eye.data.uv_layers.active=original_uv
    return {'source':EYE_SOURCE,'material':material.name,'method':'Appended CC0 native procedural graph with fitted planar globe UVs; transparent outer shells','corneal_polygons':sum(p.material_index==1 for p in eye.data.polygons),'globe_polygons':len(globe_polygons)}

def simplify_face_skin():
    material=bpy.data.objects['Human'].active_material;nodes=material.node_tree.nodes;links=material.node_tree.links
    bsdf=nodes['Principled BSDF'];old=bsdf.inputs['Base Color'].links[0].from_socket
    attribute=nodes.new('ShaderNodeAttribute');attribute.attribute_name='Heroine skin rest position'
    sep=nodes.new('ShaderNodeSeparateXYZ');links.new(attribute.outputs['Vector'],sep.inputs[0])
    mask=nodes.new('ShaderNodeMapRange');mask.clamp=True;mask.interpolation_type='SMOOTHSTEP'
    links.new(sep.outputs['Z'],mask.inputs['Value']);mask.inputs['From Min'].default_value=1.39;mask.inputs['From Max'].default_value=1.47
    freckles=nodes['Sun freckles across nose and cheeks']
    graphic=nodes.new('ShaderNodeMixRGB');graphic.name='Simple warm face and restrained freckles'
    strength=nodes.new('ShaderNodeMath');strength.operation='MULTIPLY';links.new(freckles.inputs[0].links[0].from_socket,strength.inputs[0]);strength.inputs[1].default_value=.25
    links.new(strength.outputs[0],graphic.inputs[0]);graphic.inputs[1].default_value=color('ceaa8b');graphic.inputs[2].default_value=color('a77a57')
    blend=nodes.new('ShaderNodeMixRGB');blend.name='Anime head shading only'
    links.new(mask.outputs['Result'],blend.inputs[0]);links.new(old,blend.inputs[1]);links.new(graphic.outputs[0],blend.inputs[2]);links.new(blend.outputs[0],bsdf.inputs['Base Color'])
    bsdf.inputs['Roughness'].default_value=.78;bsdf.inputs['Specular IOR Level'].default_value=.15
    for link in list(bsdf.inputs['Normal'].links):links.remove(link)
    return {'flat_head_color':'ceaa8b','freckle_strength':.25,'photo_texture':'preserved below head mask'}

def graphic_lids():
    old=bpy.data.objects['Human.eyelashes03'];old.hide_render=True;old.hide_set(True)
    # Trace visible globe/skin contacts. MakeHuman sockets are closed internally,
    # so their visible opening is not a topological boundary edge.
    body=bpy.data.objects['Human'];ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
    skin=BVHTree.FromPolygons([body.matrix_world@v.co for v in mesh.vertices],[tuple(p.vertices) for p in mesh.polygons])
    ev.to_mesh_clear()
    eye=bpy.data.objects['Human.high-poly'];ev=eye.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
    coords=[eye.matrix_world@v.co for v in mesh.vertices]
    polygons=[tuple(p.vertices) for p in mesh.polygons if p.material_index==0]
    globe=BVHTree.FromPolygons(coords,polygons)
    groups=[]
    for sign in [-1,1]:
        indices={i for p in polygons for i in p if coords[i].x*sign>0};points=[coords[i] for i in indices]
        x0,x1=min(v.x for v in points),max(v.x for v in points);z0,z1=min(v.z for v in points),max(v.z for v in points)
        rim=[]
        for ix in range(65):
            x=x0+(x1-x0)*ix/64;top=None
            for iz in range(161):
                z=z0+(z1-z0)*iz/160;origin=Vector((x,-1,z));direction=Vector((0,1,0))
                e=globe.ray_cast(origin,direction,2)[0];s=skin.ray_cast(origin,direction,2)[0]
                if e is not None and (s is None or e.y<s.y-.00005):top=e.copy()
            if top is not None:rim.append(top)
        assert len(rim)>8,('Eye not visible',sign,len(rim))
        groups.append(rim)
    ev.to_mesh_clear()
    ink=bpy.data.materials.new('Anime upper lash ink');ink.diffuse_color=color('201319');ink.use_nodes=True
    p=ink.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=ink.diffuse_color;p.inputs['Roughness'].default_value=.9
    if 'Weight' in p.inputs:p.inputs['Weight'].default_value=1
    collection=bpy.data.collections.new('Anime graphic eye rims');bpy.context.scene.collection.children.link(collection)
    for points in groups:
        cx=sum(v.x for v in points)/len(points)
        upper=sorted([v.copy() for v in points],key=lambda v:v.x)
        vertices=[]
        for i,v in enumerate(upper):
            t=i/(len(upper)-1);outer=t if cx>0 else 1-t
            thickness=.0006+.0038*math.sin(math.pi*t)**.7+.0008*outer
            v.y-=.0006;above=v+Vector((0,-.00015,thickness))
            hit=skin.ray_cast(Vector((above.x,-1,above.z)),Vector((0,1,0)),2)[0]
            if hit is not None:above.y=min(above.y,hit.y-.0008)
            vertices.extend([v.copy(),above])
        faces=[(2*i,2*i+1,2*i+3,2*i+2) for i in range(len(upper)-1)]
        index=len(upper)-1 if cx>0 else 0;outer=vertices[2*index]
        vertices.append(outer+Vector((.0035 if cx>0 else -.0035,-.0001,.0019)))
        faces.append((2*index,2*index+1,len(vertices)-1))
        data=bpy.data.meshes.new('Tapered upper eyelid ribbon');data.from_pydata(vertices,[],faces);data.materials.append(ink)
        obj=bpy.data.objects.new('Anime upper lash '+('L' if cx>0 else 'R'),data);collection.objects.link(obj)
        obj['Static facial study']=True
    return {'actual_skin_eye_boundaries':2,'old_lower_lashes':'hidden in alternate only','upper_lashes':'tapered ribbons fitted to opening, with outer wing'}
