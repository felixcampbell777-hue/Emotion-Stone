# Alpha 2 region authoring

Authoritative layout: `game/content/alpha2_regions.json`. Run
`tools/create_alpha2_content.py` to rebuild map JSON without changing stable
enemy IDs, quest rewards, exits or checkpoints. The recipe reserves continuous
3.4m routes, wider tree clearances, interaction spurs and encounter floors.
Do not restore the former evenly spaced spawn list or broad plant scattering.

Movement: first person, grounded capsule, optional jump and T dash. No route
requires an upgrade. The controller accepts slopes up to its existing 1.1
rise/run threshold; steep rendered Alpha 2 triangles also have physical actor
collision, so jumping does not bypass escarpments. Walk-up slopes remain
camera-layer terrain. Sea shelves retain shoulder-depth drowning. Flooded
marsh beds are cut by actual dry causeways, not decorative paths over water.

## Journey and situations

* Crossroads: a sheltered fire splits the journey. Feeding beasts occupy the
  west spur; a coordinated hunt pressures the east bend. The northern root
  cutting hides a warned nest. The cache spur is optional.
* Saltwind: a dune spine hides the wreck until the sheltered western loop.
  The exposed shore passes a territorial shell feeding ground. Gnawed cargo
  leads around the hull to scavengers and medicine; sand mounds warn of the
  chime nest. Salvage and the northern ward provide different objectives.
* Fen: the dry causeway links refuge, courier island and the eastern road.
  Silk marks the reed ambush; the flooded cargo detour is optional. Rescuing
  Jun makes him return to the village, preserving the existing consequence.
* Bluffs: a switchback climbs to the sentinel court. The longer seaward route
  passes the buried watch and an optional lookout, then reconnects above.
  Patrol guards hold their court; rock cover breaks ranged aim. Returning a
  sentinel shot still exposes its armor. The watch ledger pays off the detour.
* Heartwood: a dividing spine separates the wolf hunting bowl from the silk
  hollow. Wolves flank and take attack turns; the eastern nest emerges only
  when approached. An outer root loop leads to memory and treasure. Beyond
  the final watchers, the listening-bell grove and chapel release pressure.
* Buried Watch: the two-room survey vault bends around structural walls.
  Gnawed supplies warn of concealed rats; the ledger and cache remain.
* Chapel: a small roofless refuge between woodland and the final trial.
* Belfry: an open melee court between raised shoulders, with broken masonry
  providing limited cover against the Bellkeeper's ranged attacks.

`alpha2_encounters.gd` owns bounded groups, emergence, pack flanks, guard
patrol goals and attack turns. The existing enemy owns its windup, committed
strike direction, damage, parry, knockback and XP/core rewards. Static physics
and walkable height feed a cached AStar grid. Retreat beyond the leash sends
survivors home without healing them. Defeated IDs remain defeated through
travel/save/load; clearing a pocket leaves its route safe. No random respawn.
Clues and physical nest/cargo traces appear before engagement, while existing
notes/NPCs explain the wreck, surveyors and former keepers.

## Verification

`alpha2_layout_checks.gd` drives the actual capsule along the authored routes,
checks static-navigation reach, group triggers/flanking/leash/pause, cliff
jump blocking and dry causeways. `alpha2_checks.gd` retains quest/import/reward/
save/death and legacy-mode coverage. Native first-person Alpha 2 captures
review the approaches, landmarks, threats and route readability after dressing.
v0.33.0 source and exported Windows suites both pass 206 checks. The native
first-person capture set retains 44 evidence files covering all nine areas,
nest warning/emergence, the seaward alternative, root discovery, existing
quests, conversation, equipment journal and skill UI. Inspection caught and
fixed a beach-path sign obstruction, cliff-crossing route segments, a floating
lookout, the generic material overwrite and overlapping ocean surfaces.
Static graphics samples span 129–166 FPS on the local RTX 5070 Laptop GPU
(45 frames per area); this is not a combat or full-session benchmark.
The capsule stops at the forest escarpment during a jump; route traversal,
group attack turns, emergence, retreat, pause and save migration pass.
Full human playthrough duration remains unmeasured.

Revision 3 loads older Alpha 2 saves at the current map entrance while
preserving character, loot, defeated enemies, quest flags and checkpoint.
This prevents old coordinates from landing inside a newly authored ridge.

No new downloads, animation regeneration or replacement of Original art.
