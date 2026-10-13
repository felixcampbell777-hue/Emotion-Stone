"""Fit the official CC0 Junglebook hair; save a review candidate, never the main."""
import bpy,bmesh,sys,os,json,traceback,hashlib,math
sys.path.insert(0,os.path.dirname(__file__))
from personal_heroine_smile import SOURCE,OUTPUT,studio,render_face
from personal_heroine_appearance import color,fingerprint
from personal_heroine_face import ASSET_ROOT,FACIAL_ASSETS
from bl_ext.blender_org.mpfb.services.humanservice import HumanService
from bl_ext.blender_org.mpfb.services.clothesservice import ClothesService
from bl_ext.blender_org.mpfb.entities.clothes.mhclo import Mhclo
ROOT=r'C:\Games\CoastalFoundation\art\source\heroine-hair-study\hair\sonntag78_junglebook_hair'
CANDIDATE=os.path.join(os.environ['TEMP'],'heroine-hair-fix.blend')
STATUS=os.path.join(os.environ['TEMP'],'heroine_hair_fix_status.json')
def status(**r):
    with open(STATUS,'w') as f:json.dump(r,f,indent=2)
try:
    assert bpy.app.version[:2]==(5,2)
    sha=hashlib.sha256(open(SOURCE,'rb').read()).hexdigest()
    body=bpy.data.objects['Human']
    protected={o.name for o in bpy.data.objects if o.name not in FACIAL_ASSETS and o.name!='Human'}
    before=fingerprint(protected)
    # Withdraw the forced smile. A mild smile preserves the natural mouth shape.
    weights={'mouthSmileLeft':.45,'mouthSmileRight':.45,'cheekSquintLeft':.12,'cheekSquintRight':.12,'eyeSquintLeft':.08,'eyeSquintRight':.08,'browOuterUpLeft':.02,'browOuterUpRight':.02}
    for k in body.data.shape_keys.key_blocks:
        if k.name.startswith('!ex-'):k.value=weights.get(k.name[4:],0)
        if k.name in ['cheek-raiser','mouth-corner-puller','mouth-upperlip-ext-up','mouth-lowerlip-ext-up']:k.value=0
    tint=body.active_material.node_tree.nodes['Natural warm rose lips']
    tint.inputs[2].default_value=color('a9645d')
    for link in tint.inputs[0].links:
        if link.from_node.type=='MATH':link.from_node.inputs[1].default_value=.45
    for name,(cat,asset) in FACIAL_ASSETS.items():
        if cat=='hair':continue
        ob=bpy.data.objects.get(name)
        if ob:
            mh=Mhclo();mh.load(os.path.join(ASSET_ROOT,cat,asset,asset+'.mhclo'));mh.clothes=ob
            world=ob.matrix_world.copy();ClothesService.fit_clothes_to_human(ob,body,mh,set_parent=False);ob.matrix_world=world
    groups=set(g.name for g in body.vertex_groups);mods=set(m.name for m in body.modifiers)
    hair=HumanService.add_mhclo_asset(os.path.join(ROOT,'sonntag78_junglebook_hair.mhclo'),body,asset_type='Hair',subdiv_levels=1,material_type='MAKESKIN',set_up_rigging=False,import_subrig=False,import_weights=False)
    for m in list(body.modifiers):
        if m.name not in mods:body.modifiers.remove(m)
    for g in list(body.vertex_groups):
        if g.name not in groups:body.vertex_groups.remove(g)
    hair.name='Heroine relaxed layered hair';hair.hide_render=False;hair.hide_set(False)
    # Keep the authored fringe; give the lower layers a small irregular wave.
    for v in hair.data.vertices:
        weight=max(0,min(1,(1.07-v.co.z)/.16))
        v.co.x+=.006*weight*math.sin(v.co.z*47+v.co.x*26)
        v.co.y+=.005*weight*math.sin(v.co.z*39+v.co.x*31)
    # Explicit texture/alpha wiring avoids the old asset's obsolete opacity=0 setting.
    mat=bpy.data.materials.new('Chestnut layered hair');mat.use_nodes=True
    nodes=mat.node_tree.nodes;links=mat.node_tree.links;nodes.clear()
    out=nodes.new('ShaderNodeOutputMaterial');p=nodes.new('ShaderNodeBsdfPrincipled')
    tex=nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(os.path.join(ROOT,'Hairblackseamless2png.png'),check_existing=True);tex.image.pack()
    lum=nodes.new('ShaderNodeRGBToBW');links.new(tex.outputs['Color'],lum.inputs[0])
    ramp=nodes.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].color=color('28160e');ramp.color_ramp.elements[1].color=color('825333');ramp.color_ramp.elements[1].position=.13
    links.new(lum.outputs[0],ramp.inputs[0]);links.new(ramp.outputs[0],p.inputs['Base Color']);links.new(tex.outputs['Alpha'],p.inputs['Alpha'])
    p.inputs['Roughness'].default_value=.78;p.inputs['Specular IOR Level'].default_value=.10
    bump=nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.16;bump.inputs['Distance'].default_value=.0002;links.new(lum.outputs[0],bump.inputs['Height']);links.new(bump.outputs[0],p.inputs['Normal']);links.new(p.outputs[0],out.inputs['Surface'])
    hair.data.materials.clear();hair.data.materials.append(mat)
    for poly in hair.data.polygons:poly.material_index=0
    # Fit a scalp backing from the actual head topology beneath the hair cards.
    # This closes the donor crown seams without changing the human's geometry.
    ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ev.to_mesh();rest=me.attributes['Heroine skin rest position'].data
    faces=[list(p.vertices) for p in me.polygons if all(rest[i].vector.z>1.68 for i in p.vertices)]
    used=sorted({i for f in faces for i in f});mapping={i:j for j,i in enumerate(used)}
    points=[body.matrix_world@(me.vertices[i].co+me.vertices[i].normal*.003) for i in used]
    mesh=bpy.data.meshes.new('Fitted hair crown backing');mesh.from_pydata(points,[],[[mapping[i] for i in f] for f in faces]);mesh.update();ev.to_mesh_clear()
    cap=bpy.data.objects.new('Heroine fitted hair crown',mesh);bpy.context.scene.collection.objects.link(cap)
    cm=bpy.data.materials.new('Chestnut crown backing');cm.use_nodes=True;cp=cm.node_tree.nodes['Principled BSDF'];cp.inputs['Base Color'].default_value=color('44291a');cp.inputs['Roughness'].default_value=.85;cp.inputs['Specular IOR Level'].default_value=.08;cap.data.materials.append(cm)
    for p in cap.data.polygons:p.use_smooth=True
    # Seal only the donor's open crown boundary using its existing outline.
    bm=bmesh.new();bm.from_mesh(hair.data)
    crown_edges=[e for e in bm.edges if e.is_boundary and all(v.co.z>1.14 for v in e.verts)]
    if crown_edges:bmesh.ops.holes_fill(bm,edges=crown_edges,sides=0)
    top=[v for v in bm.verts if v.co.z>1.13]
    for iteration in range(3):bmesh.ops.smooth_vert(bm,verts=top,factor=.5,use_axis_x=True,use_axis_y=True,use_axis_z=True)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(hair.data);bm.free()
    # Opaque root shading prevents the old donor alpha texture from opening
    # holes in the crown; the textured lower layers retain their fine tips.
    roots=mat.copy();roots.name='Chestnut opaque hair roots';rp=roots.node_tree.nodes.get('Principled BSDF')
    for link in list(rp.inputs['Alpha'].links):roots.node_tree.links.remove(link)
    rp.inputs['Alpha'].default_value=1;hair.data.materials.append(roots)
    for poly in hair.data.polygons:
        if all(hair.data.vertices[i].co.z>1.115 for i in poly.vertices):poly.material_index=1
    # Replace the donor's folded crown silhouette with a smooth fitted crown,
    # using its strand texture and opaque roots. Preserve all fringe/lower hair.
    pts=[];faces=[];rings=12;segments=64
    for j in range(rings+1):
        theta=.003+j/rings*1.08
        for i in range(segments):
            phi=i/segments*math.tau
            pts.append((-.004+.068*math.sin(theta)*math.cos(phi),-.014+.064*math.sin(theta)*math.sin(phi),1.120+.055*math.cos(theta)))
    for j in range(rings):
        for i in range(segments):
            n=(i+1)%segments;a=j*segments+i;b=j*segments+n;faces.append((a,a+segments,b+segments,b))
    dome=bpy.data.meshes.new('Fitted textured hair crown');dome.from_pydata(pts,[],faces);dome.update();uv=dome.uv_layers.new(name='Root strands')
    for p in dome.polygons:
        p.use_smooth=True
        for loop in p.loop_indices:
            idx=dome.loops[loop].vertex_index;uv.data[loop].uv=((idx%segments)/segments,(idx//segments)/rings*.50+.20)
    crownob=bpy.data.objects.new('Heroine smooth textured crown',dome);bpy.context.scene.collection.objects.link(crownob);dome.materials.append(roots)
    old=bpy.data.objects['Human.elvs_wavy_bob'];bpy.data.objects.remove(old,do_unlink=True)
    assert fingerprint(protected)==before,'Outfit/sword/rig changed'
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=CANDIDATE,check_existing=False)
    status(stage='saved_candidate',candidate=CANDIDATE,source_sha256=sha,weights=weights)
    scene,cam,aim=studio();render_face(os.path.join(OUTPUT,'hair-fix-review.png'),scene,cam,aim,.44)
    from mathutils import Vector
    cam.location=Vector((.65,-1.5,1.05));aim(cam,Vector((0,0,1.03)));scene.render.filepath=os.path.join(OUTPUT,'hair-fix-three-quarter.png');bpy.ops.render.render(write_still=True)
    status(stage='preview_complete',candidate=CANDIDATE,source_sha256=sha,weights=weights,protected_geometry_unchanged=True,hair_license='CC0 per official current hair01 catalog (legacy header predates relicensing)',hair_author='sonntag78')
except Exception:status(stage='error',error=traceback.format_exc());raise




