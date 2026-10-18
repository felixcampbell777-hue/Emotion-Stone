# World Rise: Floor Two — The Drowned Labyrinth

A playable terrain baseline for later custom quests and encounters. This extends World Rise with the same character and save. No new boss or quest chain has been added for this milestone.

## Playing and saving

After the first Elder victory, stand on Floor One's arrival platform and press E, or open Inventory → Map. Choose Floor 2. The matching platform near Floor Two's southeastern edge returns to Floor One. Floor travel requires being within six metres of the arrival and no actively aggressive enemy within thirty metres. Transitions autosave progress; Load resumes on the last visited floor.

Character, skills, equipment, inventory, copper, XP, day/night clock and Floor One boss cooldowns carry across. Each floor keeps separate ordinary enemy health/defeats, rest point and discovered crystals. Arrival plus three scattered refuges support local travel. Undiscovered sites have no markers; the map has no location labels. Rest/death rearms only that floor's ordinary encounters. Legacy saves default to an unvisited Floor Two.

## Terrain

The 480m circular floor retains the metal rim and mountain backdrop. A deterministic jittered graph creates 101 small irregular islands, 119 winding shallow crossings and 19 independent loops. All islands connect, with alternate approaches and short dead ends. Dry surfaces sit roughly 0.85m above water; rest sites have clear centres.

A connected fast network reaches 76 of 101 islands through 75 of the existing links. Its ankle-deep crossings sit around 0.18m submerged and allow 85% of dry-land speed, shown as paler gold-green water. The remaining 44 crossings stay around 0.65m submerged. Leaving the pale green routes descends toward a 3.6m-deep bed. Movement progressively slows to 28% of normal in deeper shallows. Water darkens around the 1.35m shoulder immersion limit; reaching that depth causes death through the normal respawn flow. Jump height is respected. Geometry, collision, water colour and map derive from the same 2m height grid. Water samples exact height-map texel centres. The outer rim still permits a fatal fall.

The arrival platform now shares Floor One's exact etched silver material and metal settings, with four teal crystal pedestals. Distance fog hides routes after a few islands; animated low mist covers the water. That general mist remains unchanged. A separate green cloud layer heavily obscures deep-water sightlines, feathered by a generated depth mask. It integrates 24 samples per pixel over at most 72m, stays below 6.5m and avoids engine volumetric fog. Lighting shares the day/night cycle. Existing local CC0 twisted/dead trees, reeds, ferns, grass, mossy rocks and stumps form the palette. Warm donor foliage becomes olive green. Ground and bark reuse Poly Haven textures. Mountains receive fog on this floor only.

## Starter encounters

78 daytime placements stream locally; ordinary encounters double at night. Arrival and refuge islands are clear. Existing slime abilities remain, with independent initial level 8–12 tuning:

| Variant | HP | Contact/projectile damage | Final kill XP |
|---|---:|---:|---:|
| Green | 160 | 16 | 18 |
| Moss | 210 | 18 | 23 |
| Resin | 175 | 16 | 22 |
| Bramble | 160 | 20 | 25 |

Resin puddles appear above water. Monster cores use existing loot. Slimes float at the surface and avoid unsafe deep channels. Health and positions survive streaming/floor travel; rest/death rearms encounters. These are baseline values for playtesting, not final balance.

## Editing and performance

- `tools/create_swamp_floor.py` regenerates graph, islands, height/depth and deep-fog masks, water tiers, map and encounters. Use bundled Python with numpy/Pillow. Edit the recipe instead of duplicating exports.
- `tools/prepare_swamp_assets.py` converts three existing local Quaternius models through Blender; it downloads nothing and executes no donor scripts.
- `game/content/world_rise/floor_02.json` owns generated topology, height samples, encounters and refuges.
- `swamp_shape.gd` supplies shared terrain queries; `swamp_floor.gd` builds terrain/dressing/water; `swamp_campaign.gd` owns streaming/save/travel; `swamp_slime.gd` adapts enemies.
- Scenery streams in 32m chunks up to 85m, shorter on lower presets, using MultiMesh batches. One chunk/model is prepared per update/frame. Enemies spawn within 50m, retire beyond 90m; stale distant queued spawns are rejected. Ground collision stays loaded. Foliage/mist cast no shadows; sun shadows stop at 48m. No costly volumetric fog or reflections. Existing FPS cap and presets remain authoritative.
- Additive `world_rise.swamp` save data holds enemy states, four allowed discovery IDs and its own checkpoint. Root map records the last floor. Other campaigns remain separate.

## Focused inspection

`tools/platform.cmd inspect-swamp` checks graph connectivity, crossing depths, actual capsule traversal on four winding routes, pause gating, floor unlock/return, final XP deduplication, night companions, aggro travel blocking, discovery, strict save roundtrip, legacy migration, unsafe-save fallback, drowning and same-floor respawn. Existing player save is read only for compatibility. All writes use temporary userdata deleted after execution.

`tools/platform.cmd inspect-swamp --windows --render` runs the checks in the selected Windows release and captures arrival, island network, shallow/deep boundary, night mist and Map/travel. Inspect these native images after relevant changes. Do not rerun unrelated heroine animation audits for floor-content edits. Keep only current accepted evidence and the selected release.

Current v0.41.1 inspection: content validation passed; 45 focused checks passed in the packaged Forward+ Windows build. Seven native views inspected over repeated material/lighting/traversal iterations. Full unrelated animation suites were not rerun. The existing player-save SHA256 stayed unchanged.
