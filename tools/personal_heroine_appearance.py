"""Static, user-authorized MPFB draft skin and Wavy Bob review; Blender 5.2 only."""
import bpy, os, json, hashlib, traceback, math
from mathutils import Vector
from mathutils.bvhtree import BVHTree

SOURCE=r'C:\Users\felix\OneDrive\Documents\heroinedraft1.blend'
CANDIDATE=r'C:\Users\felix\AppData\Local\Temp\heroine-appearance-review.blend'
STATUS=r'C:\Users\felix\AppData\Local\Temp\heroine_appearance_status.json'
OUTPUT=r'C:\Games\CoastalFoundation\output\verification\user-heroine-draft'
STORE=r'C:\Users\felix\AppData\Local\Packages\BlenderFoundation.Blender_ppwjx1n5r4v9t\LocalCache\Roaming\Blender Foundation\Blender\5.2'
ASSET=STORE+r'\extensions\.user\blender_org\mpfb\data\hair\elvs_wavy_bob\elvs_wavy_bob.mhclo'

def status(**record):
    with open(STATUS,'w') as f: json.dump(record,f,indent=2)

def color(h):
    values=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in values)+(1,)

def fingerprint(names):
    records=[]
    for o in bpy.data.objects:
        if o.name not in names:continue
        rec=[o.name,o.type,[list(r) for r in o.matrix_world],[(m.name,m.type) for m in o.modifiers]]
        if o.type=='MESH':
            rec.extend([[list(v.co) for v in o.data.vertices],[list(p.vertices) for p in o.data.polygons],[[[g.group,g.weight] for g in v.groups] for v in o.data.vertices],[(u.name,[list(v.uv) for v in u.data]) for u in o.data.uv_layers]])
        if o.type=='ARMATURE':rec.append([(b.name,[list(r) for r in b.matrix_local],b.parent.name if b.parent else None) for b in o.data.bones])
        records.append(rec)
    return hashlib.sha256(json.dumps(records).encode()).hexdigest()

def shader_fingerprint(names):
    records=[]
    for m in bpy.data.materials:
        if m.name not in names:continue
        rec=[m.name,list(m.diffuse_color),[]]
        for n in m.node_tree.nodes:
            vals=[]
            for s in n.inputs:
                if hasattr(s,'default_value') and s.type in ['RGBA','VECTOR','VALUE','INT','BOOLEAN']:
                    v=s.default_value;vals.append((s.name,list(v) if hasattr(v,'__len__') else v))
            rec[2].append([n.name,n.type,vals,n.image.filepath if n.type=='TEX_IMAGE' and n.image else None])
        rec.append([(l.from_node.name,l.from_socket.name,l.to_node.name,l.to_socket.name) for l in m.node_tree.links]);records.append(rec)
    return hashlib.sha256(json.dumps(records).encode()).hexdigest()

def add_appearance():
    from bl_ext.blender_org.mpfb.services.humanservice import HumanService
    human=bpy.data.objects['Human']
    old=bpy.data.objects.get('Human.elvs_short_daisy_hair')
    original_names={o.name for o in bpy.data.objects if o!=old}
    original_mats={m.name for m in bpy.data.materials if m.users and m!=human.active_material and (not old or m not in list(old.data.materials))}
    geometry=fingerprint(original_names);materials=shader_fingerprint(original_mats)
    original_sha=hashlib.sha256(open(SOURCE,'rb').read()).hexdigest()
    status(stage='editing',source=SOURCE,original_sha256=original_sha)
    groups=set(g.name for g in human.vertex_groups);mods=set(m.name for m in human.modifiers)
    hair=HumanService.add_mhclo_asset(ASSET,human,asset_type='Hair',subdiv_levels=1,material_type='MAKESKIN',set_up_rigging=True,interpolate_weights=True,import_subrig=False,import_weights=False)
    # The hairstyle needs no body delete mask; retain the original body setup.
    for m in list(human.modifiers):
        if m.name not in mods:human.modifiers.remove(m)
    for g in list(human.vertex_groups):
        if g.name not in groups:human.vertex_groups.remove(g)
    if old:bpy.data.objects.remove(old,do_unlink=True)
    hair.hide_set(False);hair.hide_render=False;hair.hide_viewport=False
    material=hair.active_material;nodes=material.node_tree.nodes;links=material.node_tree.links
    bsdf=nodes.get('Principled BSDF');tex=nodes.get('diffuseTexture')
    luminance=nodes.new('ShaderNodeRGBToBW');luminance.name='Hair strand brightness'
    ramp=nodes.new('ShaderNodeValToRGB');ramp.name='Chestnut brown Wavy Bob'
    ramp.color_ramp.elements[0].position=0;ramp.color_ramp.elements[0].color=color('28170e')
    ramp.color_ramp.elements[1].position=.26;ramp.color_ramp.elements[1].color=color('89603c')
    mid=ramp.color_ramp.elements.new(.065);mid.color=color('57351f')
    links.new(tex.outputs['Color'],luminance.inputs[0]);links.new(luminance.outputs[0],ramp.inputs[0]);links.new(ramp.outputs['Color'],bsdf.inputs['Base Color'])
    bsdf.inputs['Roughness'].default_value=.72;bsdf.inputs['Specular IOR Level'].default_value=.20
    bsdf.inputs['Sheen Weight'].default_value=.07;bsdf.inputs['Sheen Roughness'].default_value=.65
    bsdf.inputs['Sheen Tint'].default_value=color('70492d')
    if 'Weight' in bsdf.inputs:bsdf.inputs['Weight'].default_value=1
    material.diffuse_color=color('68452e')
    for n in nodes:
        if n.type=='TEX_IMAGE' and n.image:n.image.pack()

    skin=human.active_material;nodes=skin.node_tree.nodes;links=skin.node_tree.links;p=nodes['Principled BSDF']
    current=next(l.from_socket for l in p.inputs['Base Color'].links)
    tan=nodes.new('ShaderNodeMixRGB');tan.name='Warm outdoor tan';tan.label='Warm outdoor tan, keep skin detail';tan.blend_type='MULTIPLY';tan.inputs[0].default_value=1
    tan.inputs[2].default_value=(.73,.57,.43,1);links.new(current,tan.inputs[1])
    # Store undeformed coordinates for attached freckles that follow future deformation.
    attribute=human.data.attributes.get('Heroine skin rest position') or human.data.attributes.new('Heroine skin rest position','FLOAT_VECTOR','POINT')
    for v,a in zip(human.data.vertices,attribute.data):a.vector=v.co
    rest=nodes.new('ShaderNodeAttribute');rest.attribute_name=attribute.name;rest.name='Freckles follow skin'
    def math_node(operation,a,b=None,label=''):
        n=nodes.new('ShaderNodeMath');n.operation=operation;n.label=label
        for idx,value in enumerate([a,b]):
            if value is None:continue
            if isinstance(value,(int,float)):n.inputs[idx].default_value=value
            else:links.new(value,n.inputs[idx])
        return n.outputs[0]
    def ellipse(center,scales):
        sub=nodes.new('ShaderNodeVectorMath');sub.operation='SUBTRACT';links.new(rest.outputs['Vector'],sub.inputs[0]);sub.inputs[1].default_value=center
        scale=nodes.new('ShaderNodeVectorMath');scale.operation='MULTIPLY';links.new(sub.outputs['Vector'],scale.inputs[0]);scale.inputs[1].default_value=tuple(1/s for s in scales)
        length=nodes.new('ShaderNodeVectorMath');length.operation='LENGTH';links.new(scale.outputs['Vector'],length.inputs[0])
        fade=math_node('SUBTRACT',1,length.outputs['Value']);fade=math_node('MULTIPLY',fade,2.4)
        return math_node('MINIMUM',math_node('MAXIMUM',fade,0),1)
    cheeks=[ellipse((s*.039,-.138,1.516),(.044,.049,.026)) for s in [-1,1]]
    nose=ellipse((0,-.160,1.519),(.021,.036,.024))
    mask=math_node('MAXIMUM',math_node('MAXIMUM',cheeks[0],cheeks[1]),nose)
    separate=nodes.new('ShaderNodeSeparateXYZ');links.new(rest.outputs['Vector'],separate.inputs[0])
    project=nodes.new('ShaderNodeCombineXYZ');links.new(separate.outputs['X'],project.inputs['X']);links.new(separate.outputs['Z'],project.inputs['Y'])
    cells=nodes.new('ShaderNodeTexVoronoi');cells.name='Irregular tiny freckles';cells.voronoi_dimensions='2D';cells.distance='EUCLIDEAN';cells.inputs['Scale'].default_value=460;links.new(project.outputs[0],cells.inputs['Vector'])
    random_size=nodes.new('ShaderNodeRGBToBW');links.new(cells.outputs['Color'],random_size.inputs['Color'])
    radius=math_node('ADD',math_node('MULTIPLY',random_size.outputs[0],.14),.13)
    specks=math_node('SUBTRACT',radius,cells.outputs['Distance']);specks=math_node('MULTIPLY',specks,26);specks=math_node('MINIMUM',math_node('MAXIMUM',specks,0),1)
    strength=math_node('MULTIPLY',math_node('MULTIPLY',specks,mask),.74)
    freckles=nodes.new('ShaderNodeMixRGB');freckles.name='Sun freckles across nose and cheeks';freckles.blend_type='MIX'
    links.new(strength,freckles.inputs[0]);links.new(tan.outputs['Color'],freckles.inputs[1]);freckles.inputs[2].default_value=color('855638')
    links.new(freckles.outputs['Color'],p.inputs['Base Color'])
    p.inputs['Roughness'].default_value=.64;p.inputs['Specular IOR Level'].default_value=.3
    p.inputs['Subsurface Weight'].default_value=.055;p.inputs['Subsurface Scale'].default_value=.002
    if 'Weight' in p.inputs:p.inputs['Weight'].default_value=1
    skin.diffuse_color=color('c29a7a')
    bpy.context.view_layer.update()
    assert fingerprint(original_names)==geometry,'Unrelated geometry or rig changed'
    assert shader_fingerprint(original_mats)==materials,'Unrelated materials changed'
    # Check the unchanged sword against the replacement hair as well.
    ev=hair.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
    tree=BVHTree.FromPolygons([hair.matrix_world@v.co for v in mesh.vertices],[tuple(p.vertices) for p in mesh.polygons]);ev.to_mesh_clear()
    intersections=0
    for ob in bpy.data.objects:
        if not ob.name.startswith('Equipped Sword') or ob.type!='MESH':continue
        for edge in ob.data.edges:
            a,b=[ob.matrix_world@ob.data.vertices[i].co for i in edge.vertices];d=b-a
            if d.length>1e-8 and tree.ray_cast(a,d.normalized(),d.length)[0] is not None:intersections+=1
    assert intersections==0,('Sword intersects new hair',intersections)
    credit=bpy.data.texts.get('Heroine appearance notes') or bpy.data.texts.new('Heroine appearance notes');credit.clear()
    credit.write('Wavy Bob by Elvaerwyn, CC-BY. https://static.makehumancommunity.org/assets/assetpacks/hair02.html\nWarm tan preserves the existing skin texture. Freckles are a custom procedural material, attached using undeformed point coordinates. No body, garment, sword or rig geometry changed. Static review; no new animations.\n')
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=CANDIDATE)
    return dict(stage='saved_review',source=SOURCE,candidate=CANDIDATE,original_sha256=original_sha,original_names=sorted(original_names),original_materials=sorted(original_mats),geometry_sha256=geometry,other_materials_sha256=materials,sword_hair_intersections=intersections,hair=hair.name,version=bpy.app.version_string)

def render_review(report,write_status=status):
    os.makedirs(OUTPUT,exist_ok=True)
    scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE'
    scene.render.resolution_x=800;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
    world=bpy.data.worlds.new('Appearance review world');world.use_nodes=True;scene.world=world
    world.node_tree.nodes['Background'].inputs[0].default_value=(.16,.18,.21,1);world.node_tree.nodes['Background'].inputs[1].default_value=.35
    scene.view_settings.view_transform='AgX'
    meshes=[o for o in scene.objects if o.type=='MESH' and o.visible_get() and not o.hide_render]
    dg=bpy.context.evaluated_depsgraph_get();points=[o.matrix_world@Vector(c) for o in meshes for c in o.evaluated_get(dg).bound_box]
    lo=Vector([min(p[i] for p in points) for i in range(3)]);hi=Vector([max(p[i] for p in points) for i in range(3)])
    center=(lo+hi)/2;height=hi.z-lo.z
    def aim(o,target):o.rotation_euler=(target-o.location).to_track_quat('-Z','Y').to_euler()
    for o in scene.objects:
        if o.type=='LIGHT':o.hide_render=True
    for name,offset,energy,size in [('key',(-1.1,-1.5,1.5),140,1.2),('fill',(1.4,-.7,.6),65,1.5),('rim',(0,1,1.3),180,1.1)]:
        light=bpy.data.lights.new('Review '+name,'AREA');light.energy=energy;light.shape='DISK';light.size=size
        o=bpy.data.objects.new(light.name,light);scene.collection.objects.link(o);o.location=center+Vector(offset)*height;aim(o,center)
    cd=bpy.data.cameras.new('Appearance review camera');camera=bpy.data.objects.new(cd.name,cd);scene.collection.objects.link(camera);scene.camera=camera;cd.type='ORTHO'
    cd.ortho_scale=max(height*1.14,(hi.x-lo.x)*1.35*1.25)
    for name,offset in [('front',(0,-3,.02)),('threequarter',(1.4,-3,.05)),('back',(1.4,3,.05)),('side',(3,0,.05))]:
        camera.location=center+Vector(offset)*height;aim(camera,center);scene.render.filepath=os.path.join(OUTPUT,name+'.png');bpy.ops.render.render(write_still=True)
        report['stage']='rendering';report['last_render']=name;write_status(**report)
    # Face center from evaluated facial vertices, avoiding hair/weapon bounds.
    human=bpy.data.objects['Human'];ev=human.evaluated_get(dg);me=ev.to_mesh()
    rest=me.attributes['Heroine skin rest position'].data
    face=[human.matrix_world@v.co for v,a in zip(me.vertices,rest) if 1.46<a.vector.z<1.60 and abs(a.vector.x)<.08 and a.vector.y<-.10]
    ev.to_mesh_clear();fc=sum(face,Vector())/len(face)
    cd.ortho_scale=.35;scene.render.resolution_x=1100;scene.render.resolution_y=1100
    camera.location=fc+Vector((.24,-2,.04));aim(camera,fc+Vector((0,0,.015)))
    scene.render.filepath=os.path.join(OUTPUT,'face-close.png');bpy.ops.render.render(write_still=True)
    cd.ortho_scale=.62;camera.location=Vector((.6,-2,.75));aim(camera,Vector((0,-.03,.67)))
    scene.render.filepath=os.path.join(OUTPUT,'fabric-close.png');bpy.ops.render.render(write_still=True)
    report['stage']='preview_complete';write_status(**report)

if __name__=='__main__':
    try:
        assert bpy.app.version[:2]==(5,2),bpy.app.version_string
        report=add_appearance();status(**report);render_review(report)
    except Exception:
        status(stage='error',error=traceback.format_exc());raise
