# World Rise modular mountain backdrop

Original reusable 3D asset, prepared for the future World Rise floor. Eight identical 45° units surround the floor in a continuous 360° mountain panorama. Three radial layers provide foothills, blue stone ridges and pale alpine peaks. The full-ring prefab includes an optional slow cloud sheet beneath the world. No downloads were used; surface detail reuses the existing credited Poly Haven CC0 rock-face image.

## Use in Godot

Drag `res://assets/environment/world_rise_backdrop/ring.tscn` into the floor scene. Put its root at the floor center and reference ground height. It includes all eight units and SunnyCloudSea. The ring has no collision, shadows or distance-culling cutoff. The camera must have a far plane of at least 6,000m for the default size; the current game's 90m first-person far plane is deliberately unchanged. Future World Rise should configure its own far plane alongside scenery LOD. Scene geometry stays at sensible scale and the panorama requires no high-detail playable terrain outside the rim.

For individual placement, use `unit.tscn`. Its origin is the floor center, not the center of the mountain cluster. Keep eight copies at the same position and scale and rotate them around Y by 0°, 45°, 90°, 135°, 180°, 225°, 270° and 315°. Do not translate successive units side by side. Their edges match both positions and smooth normals. Uniformly scaling the full ring changes its distance while retaining the joins; height haze uses mesh-local height so floor elevation does not break it. Do not independently randomize sector scale or height.

Three mesh layers sit at approximately 1,800m / 2,800m / 3,900m radius. Each has depth, ridged geometry, vertex-painted elevation colors and textured stone shading. Keep the far background visible when nearby foliage/detail distance is reduced. Mountains are scenic, not accessible areas. SunnyCloudSea can be hidden if the floor uses a different cloud/abyss system.

## Editable source and regeneration

- `art/source/environments/world-rise/world-rise-backdrop.blend`: one original editable sector, all three layers and portable vertex colors.
- `tools/create_world_rise_backdrop.py`: deterministic Blender recipe, seam/normal checks and runtime export.
- `art/source/environments/world-rise/runtime-assets.json`: source/export hashes, geometry budget and seam errors.
- `mountain-unit.glb`: runtime geometry, no animations/colliders/embedded scripts.
- `mountains.gdshader`: textured rock, directional shading and baked-distance color separation; background fog is self-contained so local gameplay fog does not erase the panorama.
- `clouds.gdshader`: optional procedural cloud sheet; no external images or downloads.

Run the recipe with the pinned Blender from tools/toolchain.local.json. Source history and .blend backup copies remain disabled. Geometry budget is **9,216 triangles per unit, 73,728 for all eight**, in 24 mountain mesh instances. This is an asset budget, not a measured whole-floor frame-rate promise.

## Preview and checks

Open `res://assets/environment/world_rise_backdrop/preview.tscn` as a standalone scene, or run `tools/platform.cmd capture-windows --view world-rise-backdrop`. It produces north, join, west and full-ring views and a JSON check confirming eight sectors, 24 mountain meshes and no collision. The simple grass disk/metal ring in this scene is a scale reference only, not the finished first floor.

The authoring recipe verifies rotated edge positions/normals for all three bands. Automatic mesh LOD generation is disabled for this fixed-budget background so adjacent sectors cannot simplify their shared edges differently. Native preview checks placement around 360°. Current game modes, saves and combat are unaffected. World Rise's terrain, mode menu, packs and progression remain future implementation work.
