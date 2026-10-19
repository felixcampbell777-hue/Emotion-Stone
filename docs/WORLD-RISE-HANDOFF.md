# World Rise development handoff

Prepared **October 18, 2026**. Branch `codex/world-rise-handoff`, game release `0.41.4`, based on the pushed Alpha commit `7af7e89`. This document records the released offline baseline at handoff. Implementation of the later roadmap/tree was subsequently authorized; current sources include new weapons, approved appearance, audio/voice and dedicated multiplayer, with acceptance still incomplete. Read the newest [baseline entry](CURRENT-BASELINE.md), [implementation status](WORLD-RISE-IMPLEMENTATION-STATUS.md) and [integration contract](WORLD-RISE-INTEGRATION-CONTRACT.md) before treating behavior below as current. Gameplay release metadata remains v0.41.4.

## What exists now

World Rise is a first-person Advanced-graphics action RPG mode in a shared Godot project. The runtime is **GDScript + Godot shaders + JSON content**; Python scripts generate/build assets and packages; Blender holds editable models. C++/.NET/Unity are not required. No game server, database, API key or subscription service is needed to run the local game.

The full project is retained because World Rise uses the shared player, inventory, equipment, combat, NPC dialogue and asset library. Do not attempt to copy only `floor_01.json` into an empty Godot project. Other campaigns have separate save profiles and should retain their behavior.

### Floor One — The Verdant Reach

- Approximately 480m-wide floating circular mainland with large walkable hills, metallic lethal outer rim and mountain backdrop. Central arrival/rest platform. Northwest forest; southeast guild lodge at (146,146).
- Boar herds and wolf packs; night doubles ordinary pack membership. Four smaller western islands form a zigzag chain with level bridges and metal edges. A two-headed wolf pair occupies the second island. Ashfang waits at the last grove at night.
- Six discovered-only rest/travel sites. No labels, grey undiscovered dots or hidden-destination spoilers on the in-game map. Guild-direction road signs were removed in v0.41.4; the guild building placard remains.
- Hidden northwest forest cave leads into the separate Veiled Vault boss chamber. The Elder forms on entry, removes the ramp during battle, attacks across the whole platform and restores the ramp after victory. Reflectable stones, frontal sweeps, slam and charge have authored tells. Temporary Elder attack outlines remain enabled.
- Elder grants **500 repeatable XP + 1000 one-time first-kill XP**. Existing saved Elder victories migrate as already awarded. Elder returns 1080 gameplay seconds after defeat. Ashfang's usual reward gains a **200 XP one-time first-kill bonus**; its saved 1080-second cooldown is additionally gated by night. No automatic retroactive XP deductions or save edits are part of this branch.
- Shared cycle: 600s day / 480s night; 90s smooth dawn/dusk, centred on boundaries. Menus, death and closing the game stop gameplay time.

### Floor Two — The Drowned Labyrinth

- Same floating rim/mountains, near-edge metallic crystal arrival at F2-H11 (72,180).
- **101** small low islands, **119** winding connections, **19** independent loops. Permanent code registry maps F2-A1 etc to stable island IDs; letters initially west-to-east, rows north-to-south. Never reassign island codes after moving terrain.
- Connected ankle-deep shoals reach **76 islands** through 75 links at roughly 85% dry speed. Other crossings wade at reduced speed. Dark deep water drowns above the 1.35m shoulder immersion limit. Dense green cloud obscures deep-water sightlines; general mist remains separate.
- Seven giant green slimes: **G9, I8, I9, K6, D10, E6, I3**. The duplicated E6 in the original request is one encounter. Mother-slime-sized, **128 HP / 36 damage**, telegraphed leap up to 9m; parent gives zero XP and splits once into four small greens.
- Each small green: **45 HP / 8 damage / 18 XP / 5–6cp**, independent 30% Green Slime Residue and 10% Minor Healing Potion. Small greens now approach at 2.5m/s, trigger at 3.6m and lunge at 7m/s for 0.32s. No Floor Two cores. Partial parent/child defeats persist across streaming, travel and saving; local rest/death resets the encounter.
- **D10** also has a **Sticky Slime** (`resin_slime`, 100 HP / 16 damage / 18 XP) beside the giant; it lobs sticky goop and charges trapped targets. Current drops reuse the green-slime table. It does not split.
- Discovered crystals include arrival, D2, I4, B8 and the added D11 refuge. E11 has an attached small trading raft, level gangplank, guild clerk/vendor and golden lantern beacon faintly visible from arrival H11.
- Corin's Fen vendor sells **Water Walkers**: boots, purchase level 10, **450cp + 15 Green Slime Residue**. Equipped boots replace terrain water drag with **1.2x land gait speed**, for walking and sprinting. Sticky hazard slowdown still multiplies separately; drowning is unchanged. The recipe is Floor Two-only.
- No authored Floor Two boss/quest chain yet; it is the baseline for the next content work. Old documents listing 78 mixed slime encounters/night duplication describe a superseded terrain milestone.

## Shared progression, equipment and menus

- Fresh World Rise character only; no Alpha/Beta import. Strength / Agility / Greatsword are the three current skill categories, with prerequisites and ranks. World Rise has no Mana ability branch; older mode Mana systems remain in shared code.
- `game/content/world_rise/skills.json`, the shared `game/content/progression.json` level thresholds and `world_rise_stats.gd` are authoritative. Enemy kill XP generally uses the guild's .25 multiplier, with explicit overrides and Floor Two final rewards. Quests are separate. Levels/available points derive from XP; do not hand-edit the displayed level alone.
- Base weapon damage comes from the equipped sword's `effects.weapon_base`; stat boosts multiply weapon damage. Current committed catalog still names the starter **Standard Greatsword**, multiplier 1.0; Improved Standard is level 5 / 1.6; Wolf's Bane is level 7 / 2.1 and adds 18% canine damage. The earlier requested Training/level-3 weapon tier and higher damage progression are **not present in this committed baseline**. Do not claim those are implemented. `game/content/magic_items.json`, `main.gd` contact calculation and combat tuning are authoritative; old item descriptions contain encoding problems and are not a substitute for the formula.
- Wolf Hide Armor's stable ID `wolf_hide_armor` is **leggings**, level 7, 8 hides + 200cp, 3% DR. Boar armor is a torso, level 5, 5 hides + 100cp, 2% DR. Existing torso-slot wolf saves migrate safely. Copper is paid automatically on kills; material/potion sacks require E pickup. Guild clerk sells 25 HP Healing Potions for 25cp and two nonrepeatable hunt contracts. Material stacks are counted, not duplicate entries.
- I opens Equipment & Items / Skills / Level Up / Quests / Map. P opens Level Up. Escape closes overlays then pauses. Graphics, FPS choices and Save/Load live in pause. Basic Space jump is available; dodge and T-dash need their skills. Left click light/held-heavy, right click/F timed Parry, R draw/sheathe, Shift sprint/tap dodge, Ctrl dodge. Read live skill/menu data when equipping heavy variants.
- First-person hands/sword use the upright two-hand grip and authored transitions. Do not restore rear dragging in first person. Armor accessory visuals are deferred; equipped bonuses and sword variants still apply.

## Where to edit

| Concern | Primary files |
|---|---|
| Startup, input, reward dispatch, map replacement | `game/scripts/main.gd`, `title_screen.gd` |
| World Rise state, clocks, packs and bosses | `world_rise.gd`, `wolf_packs.gd` |
| Floor One terrain/layout | `game/content/world_rise/floor_01.json`, `rise_shape.gd`, `rise_floor.gd` |
| Western islands/bridges | `game/scripts/west_islands.gd` |
| Guild/vendors/loot/contracts | `game/content/world_rise/guild.json`, `rise_guild.gd`, `rise_guild_house.gd` |
| Elder/chamber/telegraphs | `elder_boss.gd`, `elder_motion.gd`, `elder_attack_lines.gd`, `rise_chamber.gd` |
| Ashfang, ordinary and two-headed wolves | `ashfang.gd`, `beta_enemy.gd`, `wolf_packs.gd`, `twin_wolf.gd` |
| Floor Two topology/height samples | `game/content/world_rise/floor_02.json`, `swamp_shape.gd`, `swamp_floor.gd` |
| Floor Two authored encounters and allowlists | `tools/configure_swamp_encounters.py`, `game/content/maps/wr_floor_02.json`, `swamp_campaign.gd` |
| Slime leap, puddles and projectiles | `giant_green_slime.gd`, `swamp_slime.gd`, `menagery_enemy.gd`, `resin_gloop.gd`, `menagery_hazard.gd` |
| Floor Two raft | `swamp_raft.gd` |
| Island editing identities | `docs/maps/floor-02-island-codes.json` |
| Crystals, floor transitions and map | `rise_checkpoints.gd`, `rise_map.gd`, `swamp_campaign.gd`, `inventory.gd` |
| Skill rules/stat application/menu | `game/content/world_rise/skills.json`, `game/content/progression.json`, `world_rise_stats.gd`, `world_rise_skill_menu.gd`, `progression.gd` |
| Items/effects and weapon multipliers | `game/content/magic_items.json`, `magic_items.gd`, `main.gd` |
| Player/combat/grips | `actor.gd`, `first_person_sword.gd`, `first_person_visuals.gd`, `game/content/combat.json`, `first_person_motion.json` |
| Rendering/performance | `game/content/render_budget.json`, `render_budget.gd`, `game/shaders/swamp_*.gdshader` |
| Standalone map builder | `map_builder.gd`, `world_pack.gd`, `docs/MAP-BUILDER.md` |
| Save validation/migration | `save_store.gd`, `world_rise.gd`, `swamp_campaign.gd`, `magic_items.gd`, `progression.gd` |

Script names without a directory above are in `game/scripts/`. Use `rg` to trace the relevant owner before editing. Keep JSON schemas in sync with new fields and generator output in sync with recipes.

## Assets, generation and portability

Git LFS includes runtime GLB/texture resources and editable `.blend` sources. `py -3 tools/check_checkout.py` checks that the working files are materialized and tracked, and that literal `res://` dependencies resolve. Keep licence/provenance files with imported assets. Credits are in `ASSET-CREDITS.md`, `art/library/` and `art/environment/`; do not assume the entire game is under a single open-source licence.

The active personal heroine is `art/source/beta-heroine.blend` / `game/assets/characters/heroine-beta.glb`; active sword `beta-greatsword.blend` / `greatsword-beta.glb`; wolf `beta-wolf.blend`; twin `two-headed-wolf.blend`. Original shared sources remain intact. Historical OneDrive paths inside art reports refer to intake provenance, not a missing runtime download. The older static standalone export is already included; don't run its old machine-specific re-export recipe for normal gameplay work.

Handoff portability inspection reopened those four active Blender sources with automatic scripts disabled: every file had **zero unpacked FILE images and zero linked external Blender libraries**. Their textures are packed, so those models do not need Felix's local asset folders to open. The read-only checkout scan found 339 resolved literal runtime dependencies, all tracked, and Git LFS object integrity passed before publication.

`art/character/model-review.json` intentionally freezes old generated character/animation sources while allowing the already authorized personal heroine integration. Preserve the gate. Recolouring/content changes need no Blender rebuild. Character/animation changes require explicit user scope, correct saved source/export hashes and focused visual inspection.

`create_swamp_floor.py` regenerates the complete terrain and masks, using NumPy/Pillow, then applies current encounter configuration. It may overwrite direct JSON terrain changes. Prefer local content edits for small requests; synchronize the recipe when making a change intended to survive regeneration. Do not rerun acquisition scripts or download more assets just to start development.

Pinned Windows setup regenerates local tool paths; these are ignored. Godot's `.godot` import cache and `output/build-cache.json` are also ignored. The build tool now starts with an empty cache when absent on a fresh clone. No binaries, test saves, personal save or cache copy is required from Felix.

## Saves and safe testing

World Rise save: `%APPDATA%\Godot\app_userdata\Coastal Foundation\world-rise-save-v1.json`. It includes one shared character/economy, last map/position and per-floor state. Floor travel autosaves; normal F5/Save persists your session. Fresh Game does not intentionally overwrite an existing save until explicit saving/travel. Save/load validates IDs, positions, resources, progression and equipment.

Player saves are private and **not included**. Do not put them in the repository to make tests convenient. Platform tooling runs fixtures in disposable APPDATA/LOCALAPPDATA and cleans them. The friend can create a new local game; for Floor Two development use focused isolated swamp inspection instead of altering a personal save. ALLOOTNOW exists as a developer item grant (does not itself grant levels); don't confuse that with a production progression rule.

## Verification status and next developer cautions

- Gameplay v0.41.4 content validation passed. Packaged Forward+ Floor Two inspection completed **64 checks**, including split reload, loot, vendor, traversal, floor travel, pause, drowning and private save validation. Eleven current native swamp captures were produced and inspected selectively; these are local generated evidence, not files required to run the game.
- A broader `verify-windows --suite world-rise` attempt reported **three uphill physics fixture errors**, including `Standing on a slope does not push Player downhill` at `(18,-20)` and messages involving `(92,80)` / `(-35,15)` with null travel metrics. Cause was not diagnosed. Treat this as an unresolved suite failure, not proof that hills are fixed or that the complete suite is green.
- Prior-turn tests for Water Walkers check recipe cost and equipped effect value, but do not constitute a full timed sprint/sticky-puddle playtest. First-kill XP tests exist in `elder_rewards_checks.gd` / `western_route_checks.gd`; inspect persistent flags and migration before changing rewards.
- Existing Elder saves are grandfathered as already paid when their defeated-ID is still present. The migration currently checks that ledger; a legacy save whose cooldown has already cleared the ID but retains `elder_defeated` merits review before any reward migration work. Do not silently change a human's XP as part of this handoff.
- `AGENTS.md` now gives portable, current instructions. Older docs retain historical balances/camera modes; this handoff, the newest baseline and current JSON override them. No new story/content requests have been assigned to the friend yet.

Useful commands from the root after setup:

```powershell
py -3 tools/check_checkout.py
.\tools\platform.cmd validate
.\tools\platform.cmd inspect-swamp
.\tools\platform.cmd build --skip-tests
.\tools\platform.cmd inspect-swamp --windows --render
.\tools\platform.cmd verify-world-rise
.\tools\platform.cmd verify-windows --suite world-rise
```

Use the broader suites when the changed system warrants them; investigate the known fixture failures before declaring a complete pass. Do not repeat unrelated animation audits after a small content edit. Keep current evidence and only the manifest-selected local release. `tools/clean_obsolete.ps1` cleans superseded builds after acceptance. Do not delete source models, licences or user drafts.

## Collaboration tonight

Start with the user's next requested feature, make a small coherent change, validate only relevant behavior, document exact changes/limits and commit. Push to this handoff branch or a new branch based on it. Tell Felix the branch and commit when ready for integration. Do not force-push or wholesale merge older `beta` over this newer game. A GitHub branch contains source, not a live shared editing session; separate machines/checkouts keep simultaneous edits isolated until Git integration.
