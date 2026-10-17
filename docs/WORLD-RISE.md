# World Rise — The Verdant Reach

Playable foundation in v0.35.1. On the title choose **World Rise — Floor 1**, then Start New Game. This mode begins with a fresh level-one character, existing basic equipment and three Spring Elixirs; no Alpha/Beta imports. Load uses its own `user://world-rise-save-v1.json`. Other modes and their saves remain available.

## The floor

A continuous 480m-diameter disk (180,956m² horizontal area, about 21 times Dreadmore Canyon), floating above sunlit cloud. The arrival platform is at the exact center: a flat 36m-wide metal plaza at elevation 26m, ring inlays, four luminous pylons and a rest crystal. Terrain gently joins its perimeter.

Eight large authored hills and grazing hollows produce elevations from 2m to 76.5m. Broad ridges, steep rocky shoulders and traversable saddles provide alternative valley/ridge approaches. The actual player capsule is checked along four connected routes: Sunfold Spring, Elderwood Refuge, eastern lookout and northern ascent. A broken aqueduct marks the northern route. Landmarks are exploration destinations, not a new story campaign.

Elderwood is an ellipse centered northwest at (-105,-100), radii 88m/82m: 12.5% of the floor. It has 236 tall 15–23m conifers with persistent colliding trunks, textured crowns, clear corridors and wolf clearings. Meadow/forest detail reuses the existing licensed Poly Haven CC0 models and textures. No downloads or changes to heroine models/animation.

The outer shoulder rises 4m into a continuous worn metallic rim. There is no invisible perimeter wall. Walking, jumping or attack momentum past the physical edge leads to gravity, a death screen below -65m and respawn at the last rest crystal. Loading an unsafe off-rim position falls back to that checkpoint. Saving is blocked off solid ground. The existing eight-sector mountain panorama and cloud sea surround the disk, without collision.

## Encounters and discoveries

- Eighteen boar herds of two to four animals. Early herds have lower health/damage; later territories increase them. Boars wander their hollow, engage together within territory and take turns charging. Damaging one alerts its herd within the leash. Hills interrupt line of sight; the floor does not chain every herd into one fight.
- Five wolf packs of three/four in Elderwood. Current animated Beta wolves retain patrol, encirclement, alternating attack waves, sight checks and retreat.
- Both beasts grant established XP and no monster cores. Defeat is recorded once until rest/death; unloading cannot duplicate kill XP or refill damage.
- Arrival, Sunfold Spring and Elderwood Refuge crystals heal, set respawn and reset regular packs. Discovery flags, items and XP persist. Rest is blocked near living enemies.
- Silver Verge cache grants Windstep and 100 XP; deep forest cache grants three remedies and 100 XP. Both reward once per character.
- Northern ascent gate is dormant. Floor 2, a floor guardian, settlement NPCs and a complete quest campaign remain future work from the earlier plan.

## Ownership and performance

`game/content/world_rise/floor_01.json` owns hills, territories, forest records and landmarks. `maps/wr_floor_01.json` owns stable enemy IDs and mode/map metadata. Edit current data instead of creating alternative copies.

`rise_shape.gd` owns cached terrain height and the triangular interpolation used by the rendered/colliding 4m mesh. `rise_floor.gd` owns terrain chunks, circular edge/side faces, plaza and falling. Lightweight ground/collision remains loaded across the whole floor; scenery unloading cannot remove it.

32m vegetation chunks load within 110m and unload after 145m, closest first and one per update. Grass uses MultiMesh batches. Low-cost textured crowns remain visible when trunk detail is distant or pending. Actor territories activate within 85m of the player or guided Sea Dragon and unload beyond 145m after combat; records preserve health/position. All gameplay clocks freeze behind overlays. Distance budgets are authored defaults, not new menu sliders.

`world_rise.gd` owns territory state, saves/checkpoints/caches, reset rules, daylight and mode-specific far clip. Default lighting/far clip is restored on leaving. Existing progression, skills, inventory and combat remain their current shared implementations.

## Verification

Run `tools/platform.cmd verify-world-rise`, `verify-alpha2` and `verify-beta`, then `capture-windows --view world-rise --art-profile darkwood`, `--view menus`, `--view title` and `verify-windows --suite world-rise`. Focused tests use private saves and compare all real mode saves byte for byte.

Coverage includes actual capsule routes across slopes/seams, relief, pack sizing/streaming, retained damage, coordinated wolves, XP, one-time caches, high-elevation saves, malformed state, off-rim fallback, physical fall/death, checkpoint respawn and title pause/import rules. Native frames cover plaza, ridges, boars, forest/wolves, rim, ruins, title and journal. `world-rise-performance.json` records stationary rendered frame times at arrival, hilltop and forest; AI is disabled for repeatable rendering samples. It is not a full combat/travel benchmark or a full-floor playthrough.

Refresh the desktop shortcut and purge superseded releases after verification. Preserve the manifest-selected release, current sources and rendered evidence.

Validation results: World Rise source suite passes 41 checks; The prior v0.35.0 Alpha 2 source suite passed 256. Beta passed 220/223; the same three draw/unarmed-visibility assertions also fail identically in the previously verified v0.34.4 executable (retained comparison log), so this map update does not claim to repair those older test expectations. Existing heroine sources are unchanged. Native stationary Full/Forward+ v0.35.1 samples were approximately 6–12ms median, 9–15ms p95 on the RTX 5070 Laptop test machine; these isolated rendering samples do not establish full-combat performance.

Slope fix v0.35.1: World Rise raises the bottom capsule hemisphere to meet the slope across its footprint, rather than embedding it and letting recovery push actors downhill. Grounded motion and a 62-degree slope limit cover the unchanged hills (maximum approximately 57 degrees). True physics tests move the player at 2.4m/s and real boar AI at 1.2m/s across three inclines, check idle stability and actual wall blocking. First-person native uphill captures record actual distance/rise; other maps retain their floating movement mode.
