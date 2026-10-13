"""Fit CC0 MakeHuman shirt collar/yoke/placket to the active personal draft."""
import bpy,bmesh,os,sys,json,hashlib,traceback,math
from mathutils import Vector
from mathutils.bvhtree import BVHTree
sys.path.insert(0,os.path.dirname(__file__))
from personal_heroine_appearance import SOURCE,STORE,OUTPUT,fingerprint,shader_fingerprint,render_review,color
from bl_ext.blender_org.mpfb.services.humanservice import HumanService
CANDIDATE=r'C:\Users\felix\AppData\Local\Temp\heroine-collar-review.blend'
STATUS=r'C:\Users\felix\AppData\Local\Temp\heroine_collar_status.json'
ASSET=STORE+r'\extensions\.user\blender_org\mpfb\data\clothes\male_casualsuit01\male_casualsuit01.mhclo'

def status(**data):
    with open(STATUS,'w') as f:json.dump(data,f,indent=2)

def uv_density(mesh,filter_top=False):
    uv=mesh.uv_layers.active.data;worldarea=0;uvarea=0
    for p in mesh.polygons:
        if filter_top and not .74<sum(mesh.vertices[i].co.z for i in p.vertices)/len(p.vertices)<.89:continue
        coords=[Vector(uv[i].uv) for i in p.loop_indices]
        area=0
        for i in range(1,len(coords)-1):
            a=coords[i]-coords[0];b=coords[i+1]-coords[0];area+=abs(a.x*b.y-a.y*b.x)*.5
        worldarea+=p.area;uvarea+=area
    return math.sqrt(uvarea/max(worldarea,1e-12))

def edit():
    assert bpy.app.version[:2]==(5,2)
    source_sha=hashlib.sha256(open(SOURCE,'rb').read()).hexdigest()
    names=set(o.name for o in bpy.data.objects);mats=set(m.name for m in bpy.data.materials if m.users)
    geometry=fingerprint(names);materials=shader_fingerprint(mats)
    human=bpy.data.objects['Human'];dress=bpy.data.objects['Human.punkduck_black_cocktail_dress']
    body_groups=set(g.name for g in human.vertex_groups);body_mods=set(m.name for m in human.modifiers)
    donor=HumanService.add_mhclo_asset(ASSET,human,subdiv_levels=0,import_subrig=False,import_weights=False)
    for m in list(human.modifiers):
        if m.name not in body_mods:human.modifiers.remove(m)
    for g in list(human.vertex_groups):
        if g.name not in body_groups:human.vertex_groups.remove(g)
    donor.name='Denim open shirt collar and fitted yoke'
    status(stage='fitting',source=SOURCE)
    bm=bmesh.new();bm.from_mesh(donor.data)
    # Clip the donor to its collar and central upper yoke, retaining a narrow
    # front button-placket down to the high belt. Discard sleeves, lower shirt,
    # trousers and every unused vertex instead of hiding a complete outfit.
    bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=(0,0,.727),plane_no=(0,0,1),clear_inner=True,clear_outer=False)
    for x,normal in [(.1115,(1,0,0)),(-.1115,(-1,0,0))]:
        bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=(x,0,0),plane_no=normal,clear_outer=True,clear_inner=False)
    # Split at the bottom of the chest yoke before removing lower sections.
    bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=(0,0,.862),plane_no=(0,0,1),clear_inner=False,clear_outer=False)
    for x in [-.009,.009]:
        bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=(x,0,0),plane_no=(1,0,0),clear_inner=False,clear_outer=False)
    discard=[]
    for f in bm.faces:
        c=f.calc_center_median()
        if c.z<.862-1e-6 and (abs(c.x)>.0091 or c.y>-.035):discard.append(f)
    bmesh.ops.delete(bm,geom=discard,context='FACES')
    loose=[v for v in bm.verts if not v.link_faces]
    if loose:bmesh.ops.delete(bm,geom=loose,context='VERTS')
    bm.to_mesh(donor.data);bm.free();donor.data.update()
    # Match existing dress surfaces where the retained shirt overlaps it.
    tree=BVHTree.FromPolygons([v.co for v in dress.data.vertices],[tuple(p.vertices) for p in dress.data.polygons])
    ev=human.evaluated_get(bpy.context.evaluated_depsgraph_get());body_mesh=ev.to_mesh()
    skin_tree=BVHTree.FromPolygons([human.matrix_world@v.co for v in body_mesh.vertices],[tuple(p.vertices) for p in body_mesh.polygons]);ev.to_mesh_clear()
    fitted=0
    for v in donor.data.vertices:
        is_collar=v.co.z>.934 and abs(v.co.x)<.101
        # Relax the donor's side-pointing collar ends forward/down onto the chest.
        if v.co.z>.949 and v.co.y<-.005:
            q=max(0,min(1,(abs(v.co.x)-.04)/.04))
            v.co.x*=1-.12*q;v.co.y-=.038*q;v.co.z-=.027*q
        radial=Vector((v.co.x,v.co.y+.025,0))
        if radial.length<1e-5:continue
        radial.normalize();origin=Vector((0,-.025,v.co.z))
        hit,normal,face,distance=tree.ray_cast(origin+radial*.5,-radial)
        if hit is not None and not is_collar:
            seam=max(0,min(1,(v.co.z-.862)/.012))
            v.co=hit+radial*(.0005+.0010*seam);fitted+=1
        skin_hit=skin_tree.ray_cast(origin+radial*.5,-radial)[0]
        if skin_hit is not None:
            needed=(skin_hit-origin).dot(radial)+.0032
            current=(v.co-origin).dot(radial)
            if current<needed:v.co=origin+radial*needed
    donor.data.update()
    # Same material plus matched texel density; donor UVs retain their unwrap.
    factor=uv_density(dress.data,True)/uv_density(donor.data)
    for value in donor.data.uv_layers.active.data:value.uv*=factor
    donor.data.materials.clear();donor.data.materials.append(dress.active_material)
    for p in donor.data.polygons:p.material_index=0;p.use_smooth=True
    sub=donor.modifiers.new('Soft collar folds','SUBSURF');sub.levels=1;sub.render_levels=1
    thick=donor.modifiers.new('Denim fabric thickness','SOLIDIFY');thick.thickness=.0008;thick.offset=0
    collection=bpy.data.collections.new('Denim collar details');bpy.context.scene.collection.children.link(collection)
    for c in list(donor.users_collection):c.objects.unlink(donor)
    collection.objects.link(donor)
    buttons=bpy.data.materials.new('Denim shirt dark buttons');buttons.use_nodes=True
    p=buttons.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=color('39342e');p.inputs['Roughness'].default_value=.43;p.inputs['Metallic'].default_value=.08
    thread=bpy.data.materials.new('Denim collar stitching');thread.use_nodes=True
    p=thread.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=color('71808a');p.inputs['Roughness'].default_value=.86
    # Buttons follow the fitted front surface and stop above the belt.
    positions=[]
    for index,z in enumerate([.865,.825,.785,.746]):
        hit=tree.ray_cast(Vector((0,-.5,z)),Vector((0,1,0)))[0]
        assert hit is not None
        loc=Vector((0,hit.y-.0033,z));positions.append(list(loc))
        bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=10,radius=1,location=loc)
        ob=bpy.context.object;ob.name='Shirt button '+str(index+1);ob.scale=(.0028,.0010,.0028)
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        for c in list(ob.users_collection):c.objects.unlink(ob)
        collection.objects.link(ob);ob.data.materials.append(buttons)
        for poly in ob.data.polygons:poly.use_smooth=True
    # Subtle topstitching makes the fitted overlay read as a constructed yoke.
    curve=bpy.data.curves.new('Denim placket double stitching','CURVE');curve.dimensions='3D';curve.bevel_depth=.00018;curve.bevel_resolution=2
    for x in [-.0065,.0065]:
        for j in range(35):
            a=.732+j*.0037;b=a+.0016
            spline=curve.splines.new('POLY');spline.points.add(1)
            for i,z in enumerate([a,b]):
                hit=tree.ray_cast(Vector((x,-.5,z)),Vector((0,1,0)))[0]
                spline.points[i].co=(x,hit.y-.0025,z,1)
    ob=bpy.data.objects.new(curve.name,curve);collection.objects.link(ob);curve.materials.append(thread)
    rig=bpy.data.objects['Human.rig']
    for ob in collection.objects:
        if ob==donor:continue
        world=ob.matrix_world.copy();ob.parent=rig;ob.matrix_parent_inverse=rig.matrix_world.inverted();ob.matrix_world=world
    bpy.context.view_layer.update()
    assert fingerprint(names)==geometry,'Original body/outfit/rig was altered'
    assert shader_fingerprint(mats)==materials,'Original skin/hair/outfit materials were altered'
    # New collar and yoke must clear the existing back-mounted weapon.
    ev=donor.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
    collar_tree=BVHTree.FromPolygons([donor.matrix_world@v.co for v in mesh.vertices],[tuple(p.vertices) for p in mesh.polygons]);ev.to_mesh_clear()
    intersections=0
    for ob in bpy.data.objects:
        if ob.type!='MESH' or not ob.name.startswith('Equipped Sword'):continue
        for e in ob.data.edges:
            a,b=[ob.matrix_world@ob.data.vertices[i].co for i in e.vertices];d=b-a
            if d.length>1e-8 and collar_tree.ray_cast(a,d.normalized(),d.length)[0] is not None:intersections+=1
    assert intersections==0,('New shirt intersects sword',intersections)
    credits=bpy.data.texts.get('Heroine collar sources') or bpy.data.texts.new('Heroine collar sources');credits.clear()
    credits.write('Donor: MakeHuman system male_casualsuit01, CC0 (explicit release September 2020; source .mhclo header). Retained collar/yoke/placket only; existing dress/body/rig preserved. Shared Poly Haven CC0 Denim Fabric 05 material, with donor UV density matched to dress. Buttons/stitching are custom additions. Static review, no animation changes.\n')
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=CANDIDATE)
    report=dict(stage='saved_review',source=SOURCE,candidate=CANDIDATE,original_sha256=source_sha,original_names=sorted(names),original_materials=sorted(mats),geometry_sha256=geometry,other_materials_sha256=materials,donor='male_casualsuit01',license='CC0',retained_vertices=len(donor.data.vertices),fitted_vertices=fitted,uv_density_scale=factor,buttons=positions,sword_collar_intersections=intersections)
    status(**report)
    return report

def previews(report):
    # Studio setup is in memory only; the candidate was saved before rendering.
    render_review(dict(report),status)
    scene=bpy.context.scene;camera=scene.camera;camera.data.ortho_scale=.43
    target=Vector((0,-.03,.915));camera.location=target+Vector((.35,-2,.07));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.resolution_x=1100;scene.render.resolution_y=1100
    scene.render.filepath=os.path.join(OUTPUT,'collar-close.png');bpy.ops.render.render(write_still=True)
    report['stage']='preview_complete';status(**report)

if __name__=='__main__':
    try:previews(edit())
    except Exception:status(stage='error',error=traceback.format_exc());raise
