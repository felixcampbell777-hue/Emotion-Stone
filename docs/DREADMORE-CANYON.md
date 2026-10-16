# Dreadmore Canyon — staged design

The current playable release remains v0.33.7. These are editable terrain and route precursors, not an installed or playtested campaign update. The Canyon Fiend appearance is awaiting the user’s requested choice.

## Route

Forked Pilgrim Road north → two raised bluff shoulders around a dark cleft → **Enter Dreadmore Canyon?** confirmation with Enter / Stay → root-hung canyon switchbacks → Fiend’s wall-clinging arena on the right-hand route → enclosed woodland grove → woodland attunement stone.

The canyon floor remains near level. Fourteen-to-eighteen-metre near-vertical bluffs physically divide adjacent paths. Rounded dressing must stay outside collision faces so jumps and T dash cannot cut between corridors. Tops are inaccessible; no climb mechanic or hidden invisible maze walls. Long panels, corners and end caps share the same rock material and can be reused by the map builder after integration.

The maze has a readable main route and two purposeful dead ends: a weathered survey cache and a sheltered spring pocket. An old stone trail and occasional root markings indicate progress without a quest-arrow maze. The final right-hand branch opens into a 24m Fiend court; no side branch bypasses it. Daylight through foliage beyond its exit reveals the grove.

## Encounters

1. Dripping Bend: two ledge slimes, wet root drips as warning, landing tells and room to retreat.
2. Resin Fork: sticky projectile across one branch followed by a rear drop; a dry shoulder prevents unavoidable slow-lock.
3. Fern Sluice: three staggered drops into a wider pocket, then a quiet approach with wall claw marks.
4. Canyon Fiend: visible clinging silhouette overhead, dust before a marked drop; climbing reposition, ground melee recovery and a ranged wall attack. Player body remains vulnerable during remote magic. Boss XP/core and persistent defeat must use existing reward/save systems.

Slimes must use actual landing damage and collision-aware navigation, not simply appear at floor level. The new boss will be authored after its visual choice; there is no placeholder recycled Warden.

## Grove

A roughly 30m clearing framed by overlapping colliding trunks, roots and dense bushes, with the canyon as its only entrance. Keep a clear stone approach and breathing room inside the ring. No enemies spawn here. Move the woodland attunement objective here while preserving earned wards and stable save IDs; resolve the existing Heartwood bell puzzle intentionally during integration rather than silently erasing progress.

## Fiend choices

- **A — Rootclaw:** lean moss-covered simian predator, four long climbing limbs, grasping hands, bark-like plates. Strong readable wall-to-ground silhouette.
- **B — Thornback:** broad stone-plated lizard, powerful digging foreclaws, low weighty stance and whipping tail. Rockier and heavier.
- **C — Orchid Stalker:** tall four-armed insectoid with hooked climbing limbs and a fern/flower-shaped head crest. More alien and agile.

All options fit the same canyon court and drop reveal. Final rig, attack reach, tells and collision will be sized to the chosen creature.

## Integration and verification still required

Register canyon/grove maps, confirmation modal and pause gating; place slime triggers; implement the selected boss; preserve woodland ward migration; add the reusable bluff palette entry; traverse with the actual capsule/jump/dash and enemy navigation; inspect first-person native captures; verify rewards, saves, menus and Windows release; purge the superseded release only after success. Concept art is direction, not a promise of an already matching runtime mesh.
