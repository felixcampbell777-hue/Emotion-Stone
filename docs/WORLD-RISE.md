# World Rise — Floor One implementation plan

Planning only. The playable release remains v0.34.3. User confirmed: **fresh characters only**, with no character/equipment import. Inspiration is themed floors and persistent level progression; setting, characters, assets and quests are original.

## Floor identity and scale

**Floor 1: The Verdant Reach.** A sunlit circular grassland suspended above a bright abyss, encircled by a worn metallic rise. Broad hills reveal sheltered valleys and distant landmarks. A substantial northwest woodland changes visibility and tactics. Mountains appear beyond the abyss as distant scenery.

Interpret “20 times larger” as surface area, not twenty times each dimension. Current map bounds: Dreadmore 8,640 m², Beta meadow/town 5,508 m². A 480m-diameter disk is approximately 180,956 m²: 20.9 times Dreadmore and 32.9 times Beta. The wooded eighth targets approximately 22,620 m², a contiguous irregular region roughly 150m across. Hills increase actual surface area slightly; these comparisons use horizontal footprint.

Current base walking speed is 2.4m/s and normal sprint speed 4.6m/s; drawn movement and stamina slow travel. A level 480m crossing is about 3m20s at base walking speed before terrain, combat or stops. The goal is substantial explorable space, not travel time inflated by empty ground. Initial content target: 45–90 minutes to explore and clear the floor; this is a design target, not measured gameplay.

## Geographic composition

- **South: Arrival Commons.** Small safe settlement with a visible floor number, starting equipment, three useful NPCs, a checkpoint and a view into the first valley. First-person Advanced is the default. The current heroine, sword, combat and inventory remain the foundation.
- **South-central: Sunfold Valleys.** Gentle hills and grazing boars establish group combat. The first encounters have two animals, room to retreat and no overlap with the settlement.
- **Center: The Longback Hills.** Large connected hills, broad saddles, rocky shoulders and hollows. Ridge routes trade longer exposed travel for visibility; valley routes offer direct travel past boar territories. Terrain must be one coherent height surface with matching collision, not stacks of independent wall props.
- **Northwest eighth: Elderwood.** Tall thick trunks, a darker canopy, ferns, fallen logs and clearings. A peripheral trail allows cautious exploration; interior routes offer better rewards and wolf territories. Forest density is concentrated here rather than sprinkled evenly across the whole floor.
- **East: The Silver Verge.** A route toward the metallic rise, an overlook and a surveyor’s cache. The contrast between grass, weathered metal and bright empty space establishes the floating floor.
- **North/northeast: Broken aqueduct and ascent gate.** A distant silhouette visible from hilltops, with an optional ruin loop and the first floor guardian beyond. Routes converge here without forcing a single corridor through the whole map.

All regions belong to one continuous outdoor floor. No loading doors between hills, woodland and rim. Reserve small instanced interiors for later, if useful. The accompanying SVG is a schematic of relationships, not an approved terrain heightmap or exact placement file.

## Rim, abyss and mountains

Build the rim as a continuous opaque annular mesh, with shared segment endpoints and collision. Its grassy inner approach rises about 2–4m over a walkable 10–15m shoulder into worn metal; local approaches make it reachable even before learning Jump. The outer face falls vertically into sunlit cloud and haze. No outer invisible wall, blanket floor collider or position clamp may prevent falling.

Beyond the outer lip, gravity continues normally. A plane well below the lowest playable surface triggers the existing death/respawn screen. Prevent softlocks on the underside; no invisible ledges catch the player. Save/load rejects positions already in the abyss and returns them safely to the checkpoint. Test walking, jumping, rolling, dashing and attack momentum over the edge. Edge terrain is sampled as absent, rather than clamped back to the last valid height.

Distant mountains and sky stay visible as low-cost background scenery. They are outside the playable floor and need no actor collision. Use bright atmospheric separation, subtle clouds below the rim, and a restrained metal material; preserve useful horizon silhouettes across graphics settings.

## Encounters

Start with approximately **16–20 boar territories**, each containing **2–4 boars**. They occupy useful grazing valleys, water hollows and saddles, not a uniform spawn grid. Start pack centers roughly 45–70m apart where layout permits; measure spacing along traversable routes and break sightlines with hills. Leave quiet connecting ground and alternative routes. Mix pairs, trios and quartets, with two-animal groups near arrival.

Boars visibly graze/root until alerted. Nearby members react as a group, but stagger their charges; do not synchronize every animal into one unavoidable hit. Terrain, charge commitment and recovery create opportunities to separate the group. Territories prevent the whole floor joining one fight. Main roads avoid most home ranges, though some encounters can pressure a crossing.

Elderwood begins with approximately **4–5 wolf packs**, each **3–4 animals**. Reuse current wolf art and coordinated pack behavior: patrol, circle, alternate pressure, flank, recover and retreat. Give packs distinct clearings and scent/track evidence, separated by quieter forest. A fallen trunk or rock shoulder can protect a flank. Distant howls warn of territory without revealing exact positions.

These are starting authoring budgets. Place and play the terrain before committing final numbers. Regular packs return after checkpoint rest/death, with no respawn inside an active fight or on top of the player. Unloading a chunk must never refill a damaged enemy or reroll loot. Boss defeat and quest rewards remain permanent. Boars and wolves are beasts: retain the existing rule that they do not drop monster cores.

## Fresh progression, quests and floor completion

World Rise gets its own fresh character/save namespace. Start at level 1 with basic equipment and the existing skill system. XP and unlocks carry forward between World Rise floors; entering another floor does not reset the character. Alpha/Beta/Alpha 2 saves remain independent.

Provisional floor tuning: lowland entry levels 1–3, larger boar groups 3–6, interior woodland 5–8, guardian recommended around 8–10. These are encounter recommendations, not hard area locks or level requirements. Strong players may attempt the guardian earlier. Existing XP thresholds put level 8 at 1,900 XP and level 10 at 3,200 XP. Balance the intended route against those actual thresholds; a full clear and optional quests can put the player above the main-route recommendation.

Give the three settlement NPCs distinct functions:

1. A provisioner asks for help recovering a supply cart from a boar hollow. Introduces group combat and awards useful provisions/XP.
2. A field naturalist investigates wolves moving toward the forest edge. Tracks lead to a disturbed den and an optional magic item, with more than one approach route.
3. A surveyor follows old metal markings toward the rim and aqueduct. Discoveries reveal how the floor was maintained and lead to a cache or shortcut, rather than another kill quota.

Use discoveries, conversations and exploration alongside combat XP. Place roughly 5–7 authored treasure sites with distinct clues: a hollow tree, aqueduct maintenance niche, overlooked ridge, rim drainage chamber, abandoned campsite. Use existing item systems; a few chosen items should change a build rather than flood the inventory with duplicates. No mandatory three-key collection loop.

Proposed original guardian: **Crown-Tusk**, a massive plated boar guardian in the northern gate clearing. Its silhouette/materials should clearly distinguish it from ordinary boars. Long committed charges, ground-scraping windups, tusk sweeps and exposed recovery reward parry/dodge/positioning. Ruined stone piers create tactical options. As a beast, it grants a guardian trophy, a magic reward and a large XP reward rather than a monster core. Exact art and mechanics remain a proposal for the floor content phase.

Defeating the guardian activates the ascent gate and permanently records Floor 1 completion. Until Floor 2 exists, the gate explicitly reports that it is not available; it must not send players into an empty or broken map. The player can continue exploring Floor 1. Future floors reuse the framework but have genuinely different terrain, inhabitants and progression.

## Technical approach

Current world.gd builds a 1m GridMap across map bounds, constructs the entire map up front and adds four outer wall colliders. environment_art.gd has visibility distances on some scenery but does not provide world streaming. wolf_packs.gd currently uses Beta-only gating and fixed territory data. These are integration constraints, not a ready-made large-world framework.

Create a World Rise path with a dedicated floor renderer/streamer instead of scaling up those nested whole-map loops. Share combat, actors, menus, save validation and item systems. Keep the current small-map path working.

Proposed ownership:

- `world_rise.gd`: mode entry, fresh session, floor progression, quest/checkpoint state and save adapter.
- `floor_world.gd`: coherent heightfield, disk/rim geometry, terrain sampling and fall boundary.
- `floor_streamer.gd`: chunk activation, scenery LOD and bounded incremental loading.
- `floor_encounters.gd`: stable pack IDs, sleeping/active encounter states and respawn rules; adapt existing wolf pack logic to floor-owned data.
- `content/world_rise/floor_01.json`: seed, dimensions, authored hill/valley shapes, biome mask, routes, pack territories, landmarks, quests and rewards.
- `user://world-rise-save-v1.json`: character plus current floor, per-floor discoveries, boss completion, checkpoint and encounter state. Validate content IDs/version, preserve private test saves and save atomically.

Use approximately 64m terrain chunks within an 8×8 grid clipped to the 480m disk. One deterministic heightfield supplies neighboring borders, normals, collision, AI ground sampling and props. Author major hills and routes first; use restrained noise only for surface variation. Suggested broad hills: 12–30m relief over 60–120m footprints, walkable valley shoulders and saddles, occasional explicit steep rocky faces. Avoid random jagged cliffs as the default landscape.

Keep a coarse continuous terrain/rim representation visible across the floor. Stream high-detail terrain/scenery around the camera, so reducing detail never opens a visual hole. Use spatially bounded tree/rock MultiMesh batches with several detail levels. Retain larger silhouettes farther away; fade small grass and ground litter earlier. Forest collision is tied to nearby playable chunks, with terrain support and advance loading covering the fastest legal dash/jump/attack movement. Never let a player fall through an unloaded chunk.

Initial tuning hypotheses, to measure rather than promises:

| Layer | Initial distance/budget |
| --- | --- |
| Grass/small litter | 25–45m |
| Detailed trees/rocks | 70–100m, then simpler forms |
| Nearby terrain detail | about 96m |
| Simplified vegetation silhouettes | about 180–240m |
| Terrain silhouette, rim, landmark proxies | whole floor |
| Full enemy decision/animation | initially 70–90m, with combat/projectile safety overrides |
| Collision preloading | player neighborhood plus movement-direction lookahead; keep coarse support underneath |

Do not instantiate every enemy on the floor and merely hide it. Keep persistent lightweight pack state at distance and activate actors when appropriate. Do not deactivate an engaged enemy, destroy a live projectile or clear its damage state because a distance threshold was crossed. Save state before releasing a chunk. Pause menus freeze streaming-side gameplay clocks as well as enemies, projectiles and respawn timers. Incremental work per frame and shared material/model caches are essential to avoid boundary hitches.

Keep render distance and quality controls in the existing pause graphics menu. Target stable 60fps on the current RTX 5070 Laptop test machine at the selected native profile, then offer lower-distance settings. Measure frame-time percentiles, worst chunk-boundary hitch, VRAM/RAM, load time and simultaneous pack load. No performance claim is valid until measured in the dense forest, at a hilltop and during multi-enemy combat.

## Build order and acceptance gates

1. **Mode and foundation.** Add World Rise to mode selection with fresh New/Load, a separate save and one floor definition. Build a rough 480m disk, smooth hills, metallic rim, abyss death and distant mountains. First deliverable: a traversable floor, not a fully decorated world. Verify spawn, edge falls, pause and save/reload.
2. **Streaming proof.** Implement chunk detail, coarse terrain continuity, foliage batches and sleeping encounter records. Stress the densest intended forest and maximum movement before scattering content. Verify no seams, holes, collision gaps or state resets across chunk borders; profile repeated loops.
3. **Playable valley/woodland sample.** Build one finished hill/valley with a 2–4 boar group, one finished forest clearing with coordinated wolves, and a rim overlook. Inspect actual first-person gameplay. This establishes the art, travel and performance standard before extending it across the disk.
4. **Complete the floor.** Place the remaining purposeful territories, settlement NPCs, paths, optional discoveries, checkpoints and level-tuned quest rewards. Check route choice and quiet intervals. Adapt reusable terrain/pack definitions for the builder after their runtime format is stable.
5. **Guardian and ascent.** Make the original boss, readable arena, reward and persistent ascent unlock. Test ranged/melee builds, parries, death/rest respawn, beast loot rules and early attempts below the recommended level.
6. **Release.** Playtest a fresh progression route, verify pauses and private save round trips, capture real first-person views and record performance. Build the Windows release, update the launcher, retain current evidence and remove superseded releases after verification. Existing modes keep their current content and saves.

## Completion checks

Walk the actual lowland, ridge, forest and rim routes without debug travel. Verify that hills create route choices, pack territories cannot all chain aggro, wolf flanking works around tree collision, and the forest occupies roughly one eighth of the floor. Check every chunk border during walk/sprint/dash/jump/knockback and while saving/loading. Validate falling from multiple rim angles, resource/encounter persistence, floor completion, and menu gating. Run only changed-system checks plus necessary shared integration coverage; do not re-audit every unchanged heroine animation.

As of this plan, all World Rise runtime, performance and full-playthrough acceptance checks are pending. No new assets downloaded and no game runtime changed.
