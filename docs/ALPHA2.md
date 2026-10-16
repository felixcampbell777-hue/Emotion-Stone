Current region authoring and encounter behavior: [ALPHA2-REGIONS.md](ALPHA2-REGIONS.md).

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
| The Forked Pilgrim Road | Winding routes to the shore, bluffs and forest; concealed boots |
| Saltwind Strand | Sand dunes, sea, scanned coastal cliffs and rocks; wreckshell crabs; work the salvage winch, recover the bronze chime, ring the northern ward; medicine cargo |
| Reedwater Marsh | Willow islands, pools and weavers; rescue Jun; east to Heartwood |
| Skyglass Bluffs | Walk-up bluff plateau, lookout tower; burrow sentinel guarding the sky chime; reflect its shell-stone to expose it; side cave |
| Buried Watch | Optional cave, weavers/crabs, royal treasure ledger and equipment cache |
| Heartwood | Dense forest and winding trails; timber wolves, bristlebacks, amberwood weavers; ring LOW → HIGH → MIDDLE from the carved verse/listening-root clue |
| The Open-Sky Chapel | Roofless sanctuary, Sable's advice, rest, final ward gate |
| The Living Bell Court | Textured forest-creature Bellkeeper, compass-heart, sea outlook and return to village |

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
- `alpha2_scenery.gd`: reusable region-specific scanned cliffs/rocks/foliage, wreck, ruins, blended terrain, sea and atmosphere. Existing licensed assets only; no new downloads or executed external scripts.
- `library_enemy.gd` / `alpha2_creatures.json`: distinct lunge, skitter/pounce and burrow/reflect encounters.
- `library_model.gd`: donor rigs/clips/materials; parent-only fitting and skin rest-space correction prevent FBX scale explosions.
- `tools/prepare_alpha2_library.py`: derived runtime meshes from collected Blender/FBX/glTF, auto-execution disabled; source files never saved. Runtime provenance/hashes: `art/library/ALPHA2-RUNTIME-ASSETS.json`.
- `bellkeeper.gd`: forest-monster art, guardian behavior, tell and ring collisions. Existing heroine animations remain unchanged.
- `schemas/alpha2.schema.json` and CLI validation enforce references, action uniqueness, isolated maps, existing treasures and route connectivity.

Run `tools/platform.cmd validate`, `verify-alpha2`, `capture-windows --view alpha2 --art-profile darkwood`, `capture-windows --view menus --art-profile darkwood`, then `verify-windows --suite alpha2`. The focused suite exercises real import, all map/arrival positions, collision-aware access to interactions, reward deduplication, companion branches, checkpoints, boss armor/parry/rings/phase/pause, endings, invalid saves and both legacy modes. It does not retest every unchanged animation. Retain current native evidence and only the manifest release; refresh desktop launchers after verification.

## Save compatibility in layout revision 2

All original encounter/action IDs remain valid. Earned shore/forest wards migrate to the corresponding new discovery flags without bonus XP. Old Alpha 2 locations outside Hearthmere move to their new authored arrival, retaining quests, defeated encounters, inventory and equipment. New saves validate discovery dependencies. The winch/chime and forest harmony cannot be repeatedly farmed. Original Alpha and Beta retain their own art/maps/saves.

## Living guardian, water and skills

Aurek uses the collected forest-monster donor with its own 2048px skin/normal maps, rough moss/bark tint and exposed blue heart. Its five-pattern cycle includes paired frontal claw sweeps, a thornseed growing from the soil and lifting before launch, marked delayed root eruptions, a shock-ring slam, and a committed rushing claw. Below half health tells tighten, roots add a fourth strike and slams emit a delayed second ring. Returned thornseeds and recovery openings expose the heart. Attack timing, roots, pods and rings freeze with overlays; ground markings precede damage. This replaces the old instant boulder throw in Alpha 2 only.

The Beta wolf appears in woodland; Beta rats hide around the shipwreck cargo. Existing stable encounter IDs are retained. All use their own donor rigs, clips and textures; the original source assets stay untouched.

Alpha 2 sea/marsh maps enable `wading: true`. Shelves descend smoothly from the shoreline; speed reduces with depth toward 25% of land speed. Water above the 1.35m shoulder threshold kills through armor/hurt invulnerability, using the existing death/checkpoint system. Jump height is respected; menus freeze drowning. Saves/spawns reject deep water. The on-screen water cue warns before the lethal depth. The original Alpha/Beta water policy is unchanged.

Level Up now uses original star/constellation artwork over the blurred game, inspired by Skyrim's constellation layout (Bethesda official manual: https://assets.ctfassets.net/rporu91m20dc/2VLVwistnGywCKuO8CUwCE/12180919f2102d4253bb034b0bb4b632/manual_skyrim-le_pc_en-int.pdf ). Strength, Form and Mana remain the branches, with Active/Passive/Capacity filters. A later skill appears only after every prerequisite is learned; learned skills always remain discoverable for upgrades. The equip menu follows the same reveal rule. No Bethesda graphics were copied. Existing points, ranks, costs, active/passive slots and save IDs are unchanged.

Imported action sampling advances the AnimationPlayer blend clock before seeking, so attack transitions cannot remain on the old idle. Zero-delta pose review uses no crossfade. Focused checks compare actual bone transforms at two attack phases and guard skin-rest scale across new actors.
