# Menagery catalog and sketch language

Walk west (left) from Village Green or Coastal Path through the signed gate. The new area has a scenery gallery on the west and a practice clearing on the east. Press M or click Menagery catalog to spawn a creature. Buttons replace that code's current specimen; all eight can fight together. Clear creatures and Restore health & stamina are available in the catalog. Escape closes it. Combat and hazards pause while menus are open.

These practice encounters grant fixed XP for kills, but no quest items or permanent story defeat records. Respawn fresh specimens to grind; clearing/replacing them grants no XP. Leaving clears creatures/projectiles/sticky sap. Your normal save may retain your location, but practice creatures are not saved. Regular story encounters are unchanged.

## Shared sketch syntax

Codes remain stable as assets improve. A = trees, B = rocks, C = wilderness, D = paths, E = creatures, F = terrain, G = cave features. Write codes directly on a sketch. North is up (-Z), east is right (+X), and one coordinate unit is one meter. For exact placement use `2A@(4,-3) r=90 s=1.2`: broad oak at X=4,Z=-3, rotated 90 degrees, scaled to 120%. Optional rotation/scale default to 0/1. A line such as `2D:(0,0)->(0,-8) width=2` means an old cobbled path connecting those endpoints. This is our design notation for later edits, not a runtime text-entry console. Creature codes designate encounter placements; give a count if more than one is intended. Example: `4E@(8,-2) count=2`.

Map prop entries reuse `kind: catalog_feature`, `catalog_code`, `at`, `rotation` and `scale`. Geometry and collision come from the reusable kit. Catalog metadata/tuning lives in game/content/menagery.json; map placements live in game/content/maps/menagery.json; geometry in menagery_kit.gd and abilities in menagery_enemy.gd. No Blender rebuild is needed for placement or stat changes.

## Scenery legend

| Code | Feature | Appearance |
| --- | --- | --- |
| 1A | Layered fir | Narrow evergreen, layered canopy |
| 2A | Broad oak | Wide branching crown |
| 3A | White birch | Pale marked trunk and light leaves |
| 4A | Weeping willow | Drooping leaf curtains |
| 1B | Pebble cluster | Small rounded stones |
| 2B | Slate shard | Tall angular split stone |
| 3B | Heavy boulder | Large squat faceted rock |
| 4B | Moss rock | Medium stone with moss cap |
| 5B | Rock tumble | Mixed stacked stones |
| 1C | Fallen log | Hollow fallen timber |
| 2C | Cut stump | Tree stump with rings |
| 3C | Fern bed | Spreading woodland ferns |
| 4C | Mushroom cluster | Mixed caps and stalks |
| 5C | Deadwood | Bare branches and broken trunk |
| 6C | Berry thicket | Dense shrub with berries |
| 7C | Reed bed | Tall damp-ground rushes |
| 8C | Forest pool | Shallow water with stone rim |
| 1D | Dirt trail | Narrow worn-earth path |
| 2D | Old cobbles | Irregular mossy paving |
| 3D | Gravel trail | Light gravel with rough edges |
| 4D | Stepping stones | Spaced flat stones |
| 5D | Trail fork | Y-shaped junction |
| 6D | Log crossing | Rustic timber crossing |
| 1F | Rolling knoll | Gentle rounded walkable rise; 1.8m summit |
| 2F | Twin rolling ridge | Linked hilltops and a traversable saddle; 2.2m |
| 3F | Ramp bluff | Rock faces block the sides/back; broad southern walk-up |
| 4F | Terraced bluff | Two grassy shelves with a continuous walk-up |
| 1G | Cave mouth | Framed rock entrance; demo doorway in northern gallery |
| 2G | Rock arch | Walk-through natural stone arch |
| 3G | Stalagmite cluster | Pointed cave formations with movement collision |
| 4G | Glow crystals | Blue crystal cluster and local cool light |

## Creature legend

| Code | Creature | Attack / ability |
| --- | --- | --- |
| 1E | Moss slime | Two-bounce lunge; moss regrowth while resting |
| 2E | Resin slime | Throws sticky sap puddles that slow movement |
| 3E | Bramble slime | Telegraphed fan of three parryable thorn seeds |
| 4E | Briar piglet | Pawing wind-up followed by a straight tusk charge |
| 5E | Sapwing bat | Circles the target then dives across its flank |
| 6E | Thorn hare | Sidesteps then dashes twice on alternating angles |
| 7E | Acorn squirrel | Retreats to range and throws a reflectable acorn |
| 8E | Puffcap | Telegraphs a local spore burst; approach after it fades |

Resin sap slows movement to 45% for as long as you stand in a spot, with a short .15s exit grace. Spots expire after five seconds; multiple spots do not multiply the penalty. Acorns and thorn seeds can be reflected with timed right-click parries. Creature size controls sword/slam knockback.

## Terrain gallery and cave

Head north from the scenery gallery to the F terrain examples. 1F is a gentle knoll; 2F is a linked ridge. Walk up the marked southern slopes of 3F/4F to reach their tops. Stone side/back faces and abrupt drops block movement; no jumping is required. Press E at 1G in the northeast to enter the cave. Follow the arch and winding passage into its crystal chamber; use E at the southern doorway to return. C switches follow/overhead views; overhead hides the cave ceiling and foreground wall visuals. Placement rotation and uniform scale also apply to terrain height and collision.

Grounding is deliberately horizontal navigation with height following the surface. Cliff drops are blocked, and this demo does not introduce jumping or climbing. Hills, bluffs and cave modules are original native geometry; they remain inexpensive to place or recolor. `tools/platform.cmd verify-terrain` checks actual movement, bluff blocking, save heights, impact placement and cave traversal. Capture with `capture-windows --view terrain`.

Current v0.18.17: all eight creature kills grant fixed XP (see PROGRESSION.md). Spawn buttons support repeat grinding; clearing/replacing a live specimen grants none. The resin slime now lobs gloop, whose splash creates sap; entering it triggers a long charged dash with an aim-lock warning. No story defeat flags are changed by Menagery fights.

## Jungle annex / current catalog additions

| Code | Piece |
|---|---|
| 5A | Jungle canopy tree with hanging vines |
| 9C | Tropical undergrowth and flowers |
| 10C | Root and vine arch, walk-through center |
| 7D | Mossy jungle stepping stones |
| 5F | Sloped slime basin, walkable shallow floor and rolling rim |
| 9E | Original green slime, 35 XP |
| 10E | Queen slime: brood splashes, marked jumps, charges; 400 XP |

The western annex holds scenery samples. Spawn creatures tab scrolls to show all ten specimens. The main encounter is west of Slime Forest through Jungle Hollow.


Magic items tab: browse/filter 35 item definitions and claim individual specimens or all for testing. Equipment changes live in Inventory [I], including two ring slots and necklace. Claims are session ownership saved only by explicit Save; this does not create campaign loot automatically. See MAGIC-ITEMS.md.
