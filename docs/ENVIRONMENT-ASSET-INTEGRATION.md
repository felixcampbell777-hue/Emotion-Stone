# Advanced environment integration

The Advanced profile now applies to every bundled area and custom/builder area. The current release is selected by game/content/release.json. Original procedural scenery, character meshes and editable Blender masters are preserved separately and selected through Pause > World art > Original.

The art direction is a consistent grounded woodland: conifer canopies, restrained green-brown undergrowth, weathered stone, old cobbles, rustic timber and cool haze. The raw scans come from Poly Haven under CC0; tiled roofs and ruin modules come from the Quaternius Medieval Village Standard CC0 kit. See ASSET-CREDITS.md. No paid asset, vendor sample scene or downloaded executable/add-on is required.

## Ownership and reuse

- game/scripts/environment_art.gd: shared visual adapter, materials, foliage, batching and light setup.
- game/shaders/realistic_ground.gdshader: softly blended photographed soil/trail/cobble surfaces, world-space UVs and macro variation.
- scanned_foliage.gdshader: real needle colour/alpha atlas, cutout shadows and backlighting.
- slime_surface.gdshader: menu-paused creature-clock gel ripple, wet coat and varied surface.
- character_surface.gdshader: unified semantic palette with fabric/skin response.
- art/environment/source: complete licensed raw source packages and official file/hash intake.
- art/environment/runtime-manifest.json: the selected current meshes, face budgets and architecture.
- tools/fetch_polyhaven.py: official public metadata and whitelisted data URLs, official MD5 plus recorded SHA256.
- tools/prepare_environment.py: bounded runtime mesh optimization; firs use 25k faces plus shared needle cards.
- tools/prepare_character_detail.py: derives a denser rounded humanoid from CURRENT humanoid-v1.blend, with identical bind poses and bone names. No replacement animation set.
- tools/prune_environment_runtime.py: removes unselected/superseded runtime asset variants while keeping raw source kits reusable.

Existing map JSON, terrain heights, stable Menagerie codes and encounter anchors remain authoritative. The adapter replaces art without changing actor, sword or projectile collision masks. Trunks/rocks/house walls use their existing solid collision; enlarged canopy clearance stays on layer 8. Ground detail and distant hills receive no gameplay collision. The builder shows the same current assets and allows Original preview. Templates do not depend on Blender or this assistant to load.

## Gameplay preservation

Warden's Hollow keeps its cobbled route, paired boars, stone_warden, exposed-core armor/parry behavior, one-time remains/core loot, map ID herb_glade and Mother's quest. The other areas keep their exits, creatures, fortifications, secrets and save IDs. Art switching snapshots the current encounter state and retains XP, inventory and quest progress. Saving persists the explicit profile. Legacy saves adopt Advanced + Full without resetting gameplay.

The new humanoid swaps only mesh/skin resources onto the same canonical skeleton. Original and Advanced sword-clearance and walking-skirt checks are cached independently against current input hashes. The source models, trajectories and clips must never be reconstructed from old releases.

## Renderer and verification

Forward+ is the chosen desktop default: shadowed scanned foliage, SSAO, sky reflections and volumetric haze. GL Compatibility remains available with --rendering-method gl_compatibility and ordinary fog. Full, Detailed, Fine and Chunky remain resolution presets independent of the art profile.

Run tools/platform.cmd verify-environment, verify, verify-builder and verify-windows. Native capture-windows --view environment records every area under environment-forward_plus and environment-gl_compatibility. Inspect menus, camera, combat and builder captures after integration. Reports include wall frame times, measured GPU/CPU render time, draw calls, VRAM, resolution, GPU and window focus. Background-window frame caps must be reported explicitly, never represented as uncapped gameplay performance.

Only selected runtime resources ship. Build/verify do not overwrite the player's save. Successful replacement verification purges the previous release and keeps current indexed visual evidence. Refresh the desktop shortcuts after release verification.
