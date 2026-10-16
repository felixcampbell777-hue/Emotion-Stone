# Dreadmore Canyon and Stillroot Grove

Integrated in v0.34.0 for the latest Alpha 2 campaign. The user selected C — Orchid Stalker. The runtime model is original locally authored geometry with custom chitin, not the concept painting itself. No heroine model/animation changes or new external downloads.

## Route

Forked Pilgrim Road north → two raised bluff shoulders around a dark cleft → **Enter Dreadmore Canyon?** confirmation with Enter / Stay → root-hung canyon switchbacks → Fiend’s wall-clinging arena on the right-hand route → enclosed woodland grove → woodland attunement stone.

The canyon floor remains near level. Sixteen-metre near-vertical bluffs physically divide adjacent paths. Rounded dressing must stay outside collision faces so jumps and T dash cannot cut between corridors. Tops are inaccessible; no climb mechanic or hidden invisible maze walls. Long panels, corners and end caps share the same rock material and can be reused by the map builder after integration.

The maze has a readable main route and two purposeful dead ends: a weathered survey cache and a sheltered spring pocket. An old stone trail and occasional root markings indicate progress without a quest-arrow maze. The final right-hand branch opens into a 24m Fiend court; no side branch bypasses it. Daylight through foliage beyond its exit reveals the grove.

## Encounters

1. Dripping Bend: two ledge slimes, wet root drips as warning, landing tells and room to retreat.
2. Resin Fork: sticky projectile across one branch followed by a rear drop; a dry shoulder prevents unavoidable slow-lock.
3. Fern Sluice: four concealed melee drops with sticky/moss pairs firing from ahead and behind, followed by the sheltered spring branch.
4. Canyon Fiend: concealed fog-covered ledge overhead, dust before a marked drop; climbing reposition, ground melee recovery and a ranged wall attack. Player body remains vulnerable during remote magic. Boss XP/core and persistent defeat must use existing reward/save systems.

Slimes must use actual landing damage and collision-aware navigation, not simply appear at floor level. The selected boss has its own articulated four-arm model and dedicated behavior; no recycled Warden.

## Grove

A roughly 30m clearing framed by overlapping colliding trunks, roots and dense bushes, with the canyon as its only entrance. Keep a clear stone approach and breathing room inside the ring. No enemies spawn here. Move the woodland attunement objective here while preserving earned wards and stable save IDs; resolve the existing Heartwood bell puzzle intentionally during integration rather than silently erasing progress.

## Fiend choices

- **A — Rootclaw:** lean moss-covered simian predator, four long climbing limbs, grasping hands, bark-like plates. Strong readable wall-to-ground silhouette.
- **B — Thornback:** broad stone-plated lizard, powerful digging foreclaws, low weighty stance and whipping tail. Rockier and heavier.
- **C — Orchid Stalker:** tall four-armed insectoid with hooked climbing limbs and a fern/flower-shaped head crest. More alien and agile.

C is implemented at approximately four metres including its petal crest, with articulated shoulder/elbow groups, compound eyes, hooked claws and digitigrade legs. A/B remain concept alternatives only.

## Authoring and verification

`game/content/dreadmore.json` owns the solid cliff runs and route sketch; `tools/create_dreadmore_content.py` regenerates these maps and their campaign references without changing existing ward IDs. `dreadmore.gd` owns reusable eroded cliff geometry, canopy/ferns, physical gate, entry confirmation and atmosphere. `canyon_fiend.gd` owns the new boss state machine; `orchid_thorn.gd` owns real claw-origin 3D shots and reflections. Builder category **Impassable bluffs**, code **1H**, places the same solid wall geometry with normal rotation/scale controls.

The boss grants 350 base + 700 bonus XP and always drops an Orchid Stalker Core (65% maximum-HP healing). Landing warnings last 1.4 seconds; drop recovery, melee recoveries and reflected-thorn knockdowns expose it. Defeat persists and removes the thorn gate. The grove stone grants the existing woodland ward and its 250 XP exactly once. Earlier earned woodland wards are retained via layout revision 4 and `wood_ward_legacy`, without requiring a retroactive boss kill. Earlier world positions relocate safely on layout migration; original Alpha/Beta save files are read only during tests.

The canyon uses reduced sunlight, dark overlapping upper-rim mist, faint moving floor wisps and Forward+ fog banks near the ground. Compatibility rendering retains the transparent atmospheric sheets. The grove remains brighter. Threat tells and floor paths must stay readable; inspect first-person captures when adjusting lighting.

Run `verify-dreadmore` for focused travel/physical-wall/ambush/boss/reward/save cases; `verify-alpha2` and exported `verify-windows --suite alpha2` retain campaign coverage. Capture `--view dreadmore --art-profile darkwood` and `--view builder`. Automated route traversal does not establish a measured human playthrough or final difficulty balance.


### v0.34.1 corrections

The canyon now uses a single opaque, double-sided union surface: only exposed grid edges are extruded to a continuous 16m rim, with shared coordinates and no warped independent slabs or internal faces. Collision retains the existing route footprints. The boss waits hidden on a physical ledge in dense local fog, emerging for its marked drop. All drop-slimes and their shadows remain hidden until falling. Before the sheltered spring, four green slimes drop while sticky/moss pairs at about 7m ahead and behind reveal together and fire real projectiles. Canyon slimes reset after player death, while boss defeat, loot and attunement persist. Other regions retain their existing persistence.

Canyon distance fog density .065 / Forward+ volume .055 fades long corridor ends into gray-green mist while retaining the existing stone albedo and normal textures.
