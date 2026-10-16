"""Stage reusable inaccessible bluffs and the canyon shell; no live-map mutation.

Run with the configured Blender --background --factory-startup --python.
The user selects the Fiend before campaign integration.
"""
import bpy
import json
import math
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'art/source/environments/dreadmore'
PLAN = json.loads((DEST / 'layout.json').read_text(encoding='utf-8'))
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

material = bpy.data.materials.new('Existing CC0 mossy canyon rock')
material.use_nodes = True
nodes = material.node_tree.nodes
links = material.node_tree.links
shader = nodes.get('Principled BSDF')
shader.inputs['Roughness'].default_value = .94
coords = nodes.new('ShaderNodeTexCoord')
scale = nodes.new('ShaderNodeVectorMath')
scale.operation = 'SCALE'
scale.inputs[3].default_value = 5
links.new(coords.outputs['Generated'], scale.inputs[0])
image = nodes.new('ShaderNodeTexImage')
image.image = bpy.data.images.load(str(ROOT / 'game/assets/alpha2/rock_face/albedo.jpg'))
image.image.pack()
image.projection = 'BOX'
image.projection_blend = .25
links.new(scale.outputs['Vector'], image.inputs['Vector'])
links.new(image.outputs['Color'], shader.inputs['Base Color'])

def bluff(name, x, y, width, depth, height, seed):
    """Closed eight-sided prism: vertical lower faces, inaccessible high top.

    The -col suffix is reserved for Godot's static trimesh import convention.
    Bevel-like outline corners stay inside the footprint; no walk-up slope.
    """
    rng = random.Random(seed)
    cut = min(width, depth) * .12
    outline = [(cut, 0), (width-cut, 0), (width, cut), (width, depth-cut),
               (width-cut, depth), (cut, depth), (0, depth-cut), (0, cut)]
    vertices = [(x+a, y+b, -.35) for a, b in outline]
    vertices += [(x+a, y+b, height+rng.uniform(-.5, .5)) for a, b in outline]
    faces = [tuple(reversed(range(8))), tuple(range(8, 16))]
    faces += [(i, (i+1)%8, (i+1)%8+8, i+8) for i in range(8)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name+'-col', mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    obj['intended_collision'] = 'static solid; actor/combat layer 1, not camera-only'
    obj['inaccessible_top'] = True
    # Every edge must belong to exactly two faces in this closed source shell.
    counts = {}
    for face in faces:
        for i, a in enumerate(face):
            edge = tuple(sorted((a, face[(i+1) % len(face)])))
            counts[edge] = counts.get(edge, 0)+1
    assert all(count == 2 for count in counts.values())
    return obj

def distance(p, a, b):
    dx, dz = b[0]-a[0], b[1]-a[1]
    t = max(0, min(1, ((p[0]-a[0])*dx+(p[1]-a[1])*dz)/max(.001, dx*dx+dz*dz)))
    return math.hypot(p[0]-a[0]-t*dx, p[1]-a[1]-t*dz)

scene = bpy.context.scene
scene.name = 'Dreadmore canyon terrain precursor'
walls = 0
for ix, x in enumerate(range(-36, 36, 4)):
    for iz, z in enumerate(range(-60, 60, 4)):
        p = (x+2, z+2)
        route = any(distance(p, a, b)<4 for line in PLAN['routes'] for a, b in zip(line, line[1:]))
        arena = 4 < p[0] < 32 and -50 < p[1] < -22
        if route or arena:
            continue
        # 10cm overlaps close corner seams between inaccessible cells.
        bluff('CanyonWall_%02d_%02d' % (ix, iz), x-.05, -z-4.05, 4.1, 4.1,
              14+2*(math.sin(ix*.7)+math.cos(iz*.6))*.5, ix*97+iz)
        walls += 1

bpy.ops.mesh.primitive_plane_add(size=2, location=(0, 0, -.05))
floor = bpy.context.object
floor.name = 'Canyon floor layout reference'
floor.scale = (36, 60, 1)
floor['integration_note'] = 'Replace with authored Godot walkable ground; retain wall shell footprint.'
floor_mat = bpy.data.materials.new('Damp earth reference')
floor_mat.diffuse_color = (.12, .16, .10, 1)
floor.data.materials.append(floor_mat)

modules = bpy.data.scenes.new('Reusable inaccessible bluff modules')
original_scene = bpy.context.window.scene
bpy.context.window.scene = modules
bluff('Long_Bluff', -8, -3, 16, 6, 16, 1)
bluff('Corner_Bluff', 16, -5, 10, 10, 15, 2)
bluff('Bluff_Endcap', 34, -3, 6, 6, 14, 3)
bpy.context.window.scene = original_scene
scene['status'] = PLAN['status']
scene['wall_count'] = walls
scene['coordinate_contract'] = 'Blender (x,-game_z,game_y); metres; vertical wall faces'
bpy.ops.wm.save_as_mainfile(filepath=str(DEST / 'dreadmore-bluffs.blend'))
print('STAGED DREADMORE:', walls, 'closed cliff shells; 3 reusable modules; live game unchanged')
