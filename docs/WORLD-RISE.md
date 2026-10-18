v0.40.8: Fix save rejection introduced by checkpoint_layout. Godot JSON reads numbers as floats; Array membership [1,2] rejected parsed2.0. Validate numeric finite layout then numeric equality to1/2, retaining strict known versions. Existing actual player save accepted by Save.read in read-only diagnosis with disposable appdata; no save changes, no general tests/captures. Keep v0.40.7 secret map, build --skip-tests, purge superseded release.

v0.40.7: Approved World Rise map secrecy. Undiscovered checkpoints have no marker, hit target or list entry. No location names, numbered markers, compass text or legend; select discovered circles directly on full-width map, selected ring highlighted, generic Travel/status controls only. No destination sidebar. Unlock/save/aggro/rest rules and user all-six-unlocked save unchanged. Build --skip-tests per user; purge superseded release, keep sources.

v0.40.6: Approved World Rise discovery gate. Checkpoints unlock on visiting within6m, independent of resting/combat; new characters start with arrival only. Snapshot unlocked_checkpoints persists on explicit save, validated against six unique known IDs. Legacy saves keep arrival and their rested site; user current save explicitly granted all six. Locked destinations remain grey/selectable for explanation but cannot travel; runtime enforces unlock independently of UI. Preserve six-site layout, rest/aggro/pause rules. User requests no tests/captures; build --skip-tests, mark untested, purge obsolete release. Future changes still require approval.

v0.40.5: Six checkpoint sites: Central Platform (0,0), Guild Hill Overlook (119,111), Ashfang Approach (-376,65), Elderwood East Refuge (-89,-49), Elderwood West Refuge (-123,-101), Veiled Vault Entrance (local approach beside cave). Platform activates after standing still1s within2m of centre, once until leaving; other crystals use E. Rest restores resources, sets respawn and resets ordinary packs. Inventory → Map displays all six sites, terrain, woods, trails, bridges and player. Select a marker or destination then Travel; requires source within6m and no aggressive enemy within30m, even while enemies are paused by inventory. Destinations require visiting within6m; new characters start with Central Platform only. Teleporting preserves damage, loot and progress; arrival at the central platform can then trigger its normal rest. Old saved checkpoint coordinates migrate with checkpoint_layout2; existing player position/XP/equipment remain. Current pack/performance and combat changes retained. Manual playtest pending; no tests or captures were run.

v0.40.4 approved update (manual playtest pending): Night pack spawning is spread across physics frames; dead pack nodes retire, distant idle animals sleep beyond60m, animations update at10Hz beyond24m, and wolf/boar coordination runs at10Hz while attack physics remains full rate. Ground support uses local triangle slopes rather than80 repeated height samples. Night population stays doubled. World Rise roll stand recovery is.08s and base parry window0–.18s; other modes retain their timing. The Elder stone reflects using swept contact. Ashfang has no orange windup circle. The guild clerk sells Healing Potion stacks for25cp each, instant25HP without regen. The cave mouth is buried into a broad grass-covered physical hill mass with a stone lip and an open approach; no rails/stairs. No automated gameplay or visual checks were run at user request.

# World Rise — The Verdant Reach

v0.37.0 adds the [Veiled Vault](VEILED-VAULT.md): a concealed cave in northwest Elderwood leads to a separate crystal-lit floating boss chamber. The arena is empty pending boss selection. E enters/returns; falling from its unrailed island is lethal and respawns at the current rest crystal.

Playable foundation in v0.36.1. On the title choose **World Rise — Floor 1**, then Start New Game. This mode begins with a fresh level-one character, existing basic equipment and three Spring Elixirs; no Alpha/Beta imports. Load uses its own `user://world-rise-save-v1.json`. Other modes and their saves remain available.

## The floor

A continuous 480m-diameter disk (180,956m² horizontal area, about 21 times Dreadmore Canyon), floating above sunlit cloud. The arrival platform is at the exact center: a flat 18m-wide metal plaza at elevation 26m, ring inlays, four luminous pylons and a rest crystal. Terrain gently joins its perimeter.

Eight large authored hills and grazing hollows produce elevations from 2m to 76.5m. Broad ridges, steep rocky shoulders and traversable saddles provide alternative valley/ridge approaches. The actual player capsule is checked along four connected routes: Sunfold Spring, Elderwood Refuge, eastern lookout and northern ascent. A broken aqueduct marks the northern route. Landmarks are exploration destinations, not a new story campaign.

Elderwood is an ellipse centered northwest at (-105,-100), radii 88m/82m: 12.5% of the floor. It has 236 tall 15–23m conifers with persistent colliding trunks, textured crowns, clear corridors and wolf clearings. Meadow/forest detail reuses the existing licensed Poly Haven CC0 models and textures. No downloads or changes to heroine models/animation.

The outer shoulder rises 4m into a continuous worn metallic rim. There is no invisible perimeter wall. Walking, jumping or attack momentum past the physical edge leads to gravity, a death screen below -65m and respawn at the last rest crystal. Loading an unsafe off-rim position falls back to that checkpoint. Saving is blocked off solid ground. The existing eight-sector mountain panorama and cloud sea surround the disk, without collision.

## Encounters and discoveries

- Eighteen boar herds of two to four animals. Early herds have lower health/damage; later territories increase them. Boars wander their hollow, engage together within territory and take turns charging. Damaging one alerts its herd within the leash. Hills interrupt line of sight; the floor does not chain every herd into one fight.
- Five wolf packs of three/four in Elderwood. Current animated Beta wolves retain patrol, encirclement, alternating attack waves, sight checks and retreat.
- Both beasts grant established XP and no monster cores. Defeat is recorded once until rest/death; unloading cannot duplicate kill XP or refill damage.
- Arrival, Sunfold Spring and Elderwood Refuge crystals heal, set respawn and reset regular packs. Discovery flags, items and XP persist. Rest is blocked near living enemies.
- Previous hidden item caches are removed. Silver Verge and the hollow tree remain scenic discoveries without free magic items. Existing owned equipment is preserved.
- Northern ascent gate is dormant. Floor 2, a floor guardian and a complete quest campaign remain future work from the earlier plan.

## Adventurers’ Guild

The cobbled trail leads southeast to (146,146), at the edge opposite Elderwood. A steep slate roof, crossed-blade crest and covered lantern porch mark the lodge. Stone lower walls, half-timber plaster bays and framed leaded windows enclose the hall. Exposed roof trusses, reception counter, communal tables, hearth, notice boards, forge and sword displays distinguish its services. Roof tiles and direct static decoration are batched. The controller is tested through the 3.2m doorway and around the counters.

Boars drop 2–4 copper, wolves 1–5. Each beast independently rolls 35% for its hide and 8% for a tusk/fang. Copper goes straight into the purse on death; E collects only the item/material sack when an item drops. Old saved sacks credit their coins once on load. Materials appear as counted stacks in Inventory → Ingredients; the purse appears in inventory and trade. The clerk buys hides for 5cp and tusks/fangs for 22cp (rarity-weighted). 100cp = 1gp.

| Item | Requirements | Effect |
| --- | --- | --- |
| Boar Hide Armor (torso) | Level5, 5 boar hides, 100cp | 2% damage reduction |
| Wolf Hide Leggings | Level7, 8 wolf hides, 200cp | 3% damage reduction |
| Cruel Charm (necklace) | 2 wolf fangs, 1 boar tusk, 300cp | +2% all attack damage |

Equip in Apparel after crafting. Boar torso armor and wolf leggings can be worn together for 5% damage reduction. The saved wolf item ID remains `wolf_hide_armor`; old torso equips move to leggings if free, otherwise remain owned without displacing existing leggings. Cosmetic equipment remains deferred to the future Blender update. Corin exclusively sells the level-five Improved Standard Greatsword for 300cp; equip purchased weapons in Inventory → Weapons. Bram retains armor, charm and shield crafting.

The clerk offers two **non-repeatable** contracts, independently accepted: ten boars pays 75cp +107XP; ten wolves pays 125cp +133XP. Kills count only after acceptance. Return to claim once; completion stays saved. XP is rounded one third of the XP needed to advance from level5 and level6 respectively (320/3 and 400/3), independent of the player’s turn-in level.

World Rise kill XP uses `guild.json`'s `kill_xp_multiplier` of 0.25, rounded after the base reward and boss bonus are combined: boars 16XP, wolves (including Ashfang helpers) 8XP, Ashfang 125XP, Elder 250XP. Quest XP, level thresholds, previously earned XP/skills and other adventure modes are unchanged. This balance change was approved by the user before implementation.

`world_rise/guild.json` owns rates, prices, recipes and contract rewards. `rise_guild.gd` owns transactions, interactions and `world_rise.economy` saves. Old saves default to empty economy; rest/death retains currency, materials, pending sacks and contract completion. Invalid/unknown material and contract fields are rejected. `rise_guild_house.gd` owns architecture; `floor_01.json` guild.solids mirrors collision footprints for safe load positions.

## Ownership and performance

`game/content/world_rise/floor_01.json` owns hills, territories, forest records and landmarks. `maps/wr_floor_01.json` owns stable enemy IDs and mode/map metadata. Edit current data instead of creating alternative copies.

`rise_shape.gd` owns cached terrain height and the triangular interpolation used by the rendered/colliding 4m mesh. `rise_floor.gd` owns terrain chunks, circular edge/side faces, plaza and falling. Lightweight ground/collision remains loaded across the whole floor; scenery unloading cannot remove it.

32m vegetation chunks load within 110m and unload after 145m, closest first and one per update. Grass uses MultiMesh batches. Low-cost textured crowns remain visible when trunk detail is distant or pending. Actor territories activate within 85m of the player or guided Sea Dragon and unload beyond 145m after combat; records preserve health/position. All gameplay clocks freeze behind overlays. Distance budgets are authored defaults, not new menu sliders.

`world_rise.gd` owns territory state, saves/checkpoints/caches, reset rules, daylight and mode-specific far clip. Default lighting/far clip is restored on leaving. Existing progression, skills, inventory and combat remain their current shared implementations.

## Verification

Run `tools/platform.cmd verify-world-rise`, `verify-alpha2` and `verify-beta`, then `capture-windows --view world-rise --art-profile darkwood`, `--view menus`, `--view title` and `verify-windows --suite world-rise`. Focused tests use private saves and compare all real mode saves byte for byte.

Coverage includes actual capsule routes across slopes/seams, relief, pack sizing/streaming, retained damage, coordinated wolves, XP, guild circulation, loot rates, trades/crafting, one-time contracts, economy persistence, high-elevation saves, malformed state, off-rim fallback, physical fall/death, checkpoint respawn and title pause/import rules. Native frames cover plaza, ridges, boars, forest/wolves, rim, ruins, title and journal. `world-rise-performance.json` records stationary rendered frame times at arrival, hilltop and forest; AI is disabled for repeatable rendering samples. It is not a full combat/travel benchmark or a full-floor playthrough.

Refresh the desktop shortcut and purge superseded releases after verification. Preserve the manifest-selected release, current sources and rendered evidence.

Validation results: World Rise source suite passes 88 checks; The prior v0.35.0 Alpha 2 source suite passed 256. Beta passed 220/223; the same three draw/unarmed-visibility assertions also fail identically in the previously verified v0.34.4 executable (retained comparison log), so this map update does not claim to repair those older test expectations. Existing heroine sources are unchanged. Native stationary Full/Forward+ v0.35.1 samples were approximately 6–12ms median, 9–15ms p95 on the RTX 5070 Laptop test machine; these isolated rendering samples do not establish full-combat performance.

Slope fix v0.35.1: World Rise raises the bottom capsule hemisphere to meet the slope across its footprint, rather than embedding it and letting recovery push actors downhill. Grounded motion and a 62-degree slope limit cover the unchanged hills (maximum approximately 57 degrees). True physics tests move the player at 2.4m/s and real boar AI at 1.2m/s across three inclines, check idle stability and actual wall blocking. First-person native uphill captures record actual distance/rise; other maps retain their floating movement mode.

Beast response v0.36.1: boar attack turns run on the physics clock and remain available until a real windup. Engaged approach is 1.8m/s; detection20m/leash42m, range5.5m, windup/lunge0.8s, recovery1.1s. World Rise wolves detect12m/leash32m; circle2.8m with first attack after0.7s and subsequent waves every2.2s; windup0.7s/recovery1s. They alternate one and two committed attackers, including when the player stands very close. Raised sight rays still block at walls. Focused tests observe repeated real charges/leaps and actual player damage, including a hillside attack; Beta retains its original pack cadence.
