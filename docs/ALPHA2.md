# Alpha 2 — The Hollow Bell

An exploration and treasure adventure in advanced first person, separate from original Alpha and Beta. Select **Alpha 2 — The Hollow Bell** on the title screen. Choose an Alpha or Beta save as the character source, then Start New Game. Load Saved Game resumes the existing Alpha 2 expedition instead.

Import copies validated XP, learned/equipped skills, worn and owned equipment, stacked consumables, owned monster cores, the selected heavy/spell options, and the permanent XP potion if owned. It does not import old quest flags, defeated encounters, world pickups or old map coordinates. Three Spring Elixirs are added as expedition supplies. The original save is read only. If the selected source is unusable, the title explicitly warns that a fresh adventurer will be used (Dodge, Jump and three remedies). New Game never writes any save automatically.

`user://alpha2-save-v1.json` is the only Alpha 2 player save. F5 or Pause → Save writes it atomically. The ordinary Alpha and Beta save files remain separate. Verification uses private files and checks the real files are unchanged.

## Adventure

Mother's old compass reveals the way into a lost royal vault. Three attuned ward-stones unlock its guardian. The adventure offers two final choices: reveal further lost roads or light the village trails. Both finish the chapter and grant a unique equipment keepsake; subsequent exploration and optional quest turn-ins remain available.

Nine areas form a connected loop:

| Area | Connections and purpose |
| --- | --- |
| Hearthmere | Village hub, Mother, Mara, Ada, Oren, returning Jun; north to crossroads |
| Pilgrim Roads | West to mill, east to quarry, north to wood; concealed boots |
| Drowned Mill | First ward, resin/moss slimes, medicine chest, waterwheel and millrace; north to fen |
| Lantern Fen | Courier rescue, slime hazards and pools; east to wood |
| Ashen Quarry | Second ward, goblin defenses and foreman; north to wood, south-east side cave |
| Buried Watch | Optional cave, royal treasure ledger and equipment cache |
| Witness Wood | Third ward and armored guardian, listening-root clue; connects fen/quarry/crossroads and chapel |
| Chapel of the Unheard | Sable's advice, rest, final ward gate |
| Rootbound Belfry | Aurek boss, compass-heart, return to village |

There are 46 persistent authored enemies, four optional companion quests, six equipment reliquaries, four remedy caches, lore clues and seven rest points. Optional quest objects appear in the Inventory quest category until returned. Early discoveries can be turned in after accepting their quests. Rewards and kill XP are deduplicated. Defeated enemies stay defeated; no quest requires waiting for respawns.

Mara recovers her medicine, Ada retrieves her courier and royal ledger, and Oren finds his treasure-hunting brother's message. Jun leaves the fen and appears in Hearthmere once rescued. The journal includes a route guide and individual objectives; the unobtrusive compass marks cardinal direction and ward count. Trail markers require E.

Estimated first exploration: **45–75 minutes**, including conversations, side quests, combat, secrets and the boss. This is an authoring target, not a measured human playthrough. Imported power, route familiarity and optional exploration can shorten it substantially. There are no artificial waiting gates or inflated timer requirements.

## Combat and rewards

Aurek, the Rootbound Bellkeeper, is a new giant guardian assembled from the existing scanned stone kit, with a bronze/root crown, hanging chimes and a living blue heart. It alternates a reflectable stone, a marked area slam with an expanding low ring, and an aimed rush. Timed right-click parries open its shell. Ordinary armored damage is reduced to 22%; an open shell takes full damage; Mana Lance breaches it. Slam/rush recovery also exposes the heart. Below half health the slam sends a second delayed ring. Leave the amber area; jump or avoid the low rings. Rolls remain damageable. Menus freeze every tell, ring, rock and damage clock.

The boss awards 400 base + 900 boss XP, guarantees a Bellkeeper Core (70% maximum-HP healing), and unlocks the quest heart. The quest heart is a separate, non-consumable story item. Its recovery and the final conversation grant additional one-time XP.

New equipment uses the existing visible socket/effect system: Lanternglass Ring (+15 HP, +5 parry stamina), Wayfinder Boots (+12% speed, 50% sticky resistance), Royal Tide Compass (water damage +25%, lance charge +10%), and Bellward Explorer Coat (+20 HP, 12% damage reduction). Existing rings, necklaces and armor provide other exploration rewards. Everything equips through Inventory, with ordinary skill/passive/stat rebuilding intact.

Amber pilgrim fires restore health/stamina only when nearby threats are clear and set the death checkpoint. They do **not** silently save. Death retains discoveries and defeated foes. The boss resets its health when re-entering alive, for a coherent retry. Its defeat persists.

## Editing and verification

- `game/content/alpha2.json`: stable action IDs, quest rewards, guardians, map list, boss tuning.
- `game/content/maps/a2_*.json`: authoritative editable maps. Edit directly or deliberately regenerate from `tools/create_alpha2_content.py`; regeneration resets these maps to its authored layout.
- `alpha2_campaign.gd`: import, narrative/dialogue, quest flags, checkpoint, journal, discovery rewards and strict save validation.
- `alpha2_scenery.gd`: reusable material-based mill wheel, water, quarry structures, belfry and atmosphere. Existing licensed assets only; no new downloads or executed external scripts.
- `bellkeeper.gd`: new guardian behavior, tell and ring collisions. Existing heroine animations remain unchanged.
- `schemas/alpha2.schema.json` and CLI validation enforce references, action uniqueness, isolated maps, existing treasures and route connectivity.

Run `tools/platform.cmd validate`, `verify-alpha2`, `capture-windows --view alpha2 --art-profile darkwood`, `capture-windows --view menus --art-profile darkwood`, then `verify-windows --suite alpha2`. The focused suite exercises real import, all map/arrival positions, collision-aware access to interactions, reward deduplication, companion branches, checkpoints, boss armor/parry/rings/phase/pause, endings, invalid saves and both legacy modes. It does not retest every unchanged animation. Retain current native evidence and only the manifest release; refresh desktop launchers after verification.
