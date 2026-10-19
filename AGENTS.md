# World Rise collaborator instructions

This branch is `codex/world-rise-handoff`, prepared October 18, 2026 from Alpha commit `7af7e89` / gameplay release `0.41.4`. Start with `START-HERE-WORLD-RISE.md` and `docs/WORLD-RISE-HANDOFF.md`, then read the newest entry in `docs/CURRENT-BASELINE.md`. Older version entries are historical; current code/content and the newest baseline take precedence.

## Scope and working directory

- Focus on **World Rise**, using Advanced graphics. The October 18 follow-up explicitly authorizes a first/third-person toggle, Cyberpunk 2077-inspired attribute/perk progression, simple cosmetic blood on damage, measured rendering/performance improvements, and separate downloadable game/server releases after checks. These requests supersede the original first-person-only and tree-version-4-only scope. Alpha, Alpha 2 and Beta remain because runtime systems/assets are shared. Preserve canonical first-person combat trajectories, avoid rear-drag first-person sword poses, and keep Mana in older modes only.
- Run commands from **this checkout root**. The original machine uses `C:\Games\CoastalFoundation`; another computer may use any local checkout path. Never recreate or launch the superseded OneDrive copy.
- Implement the human's explicit request without reconfirming it. Obtain approval for additional gameplay/balance/design alterations outside that request. Keep the friend’s changes on this branch or a new branch based on it; avoid rewriting `alpha`/`beta` history.
- No private player saves, credentials, machine tool paths, tool binaries or generated release folders belong in Git. Large art is Git LFS; finish `git lfs pull` before Godot imports it.

## Source ownership

- Runtime: `game/project.godot`, `game/scripts/`, `game/content/`, `game/shaders/`, `game/assets/`.
- Editable art: `art/source/`; imported donor assets/licences: `art/library/`, `art/environment/`, `docs/ASSET-CREDITS.md`.
- Recipes/tooling: `tools/`; schemas: `schemas/`. Do not reconstruct current behavior from older exports or historical chat instructions.
- World Rise state/streaming: `world_rise.gd`, `swamp_campaign.gd`; terrain: `rise_floor.gd`, `rise_shape.gd`, `swamp_floor.gd`, `swamp_shape.gd`, `west_islands.gd`; tuning: `game/content/world_rise/`.
- Floor Two island IDs/codes are permanent: `docs/maps/floor-02-island-codes.json`. G9 means F2-G9. Edit the encounter generator `tools/configure_swamp_encounters.py` when changing those authored placements; keep generated JSON and map enemy allowlists synchronized. Do not regenerate the terrain just to move one encounter.
- Stats use a separate World Rise profile. `skills.json`, `world_rise_stats.gd` and `world_rise_skill_menu.gd` own it; follow the newest baseline for the current version and attribute/perk rules. Preserve XP, equipment, existing tree-version-4 learned effects and strict save/network migration. Mana belongs only to older modes.

## Preserve these contracts

- Inventory I: Equipment & Items, Skills, Level Up, Quests, Map. P opens Level Up. Escape closes overlays before toggling pause. Right click/F is Parry; T is Dash; Shift sprint/tap-dodge, Ctrl dodge, Space baseline jump. Drawn sword is held forward in first person.
- Overlays gate simulation consistently, including attacks, projectiles, hazards, enemies and gameplay timers. Focus loss cancels pending mouse input safely. Do not give rolls damage immunity.
- World Rise fresh characters start on Floor One. Defeating the Elder unlocks Floor Two. E/Map at arrival platforms travels between floors; character/inventory/XP/copper are shared, encounter/discovery/checkpoint state is per floor. Loading returns to the last saved floor. Preserve strict save validation and stable IDs/migrations.
- Unvisited crystals are absent from the map, with no labels/grey markers. Nearby source crystal and no nearby active aggro are required for travel. Rest and teleport are separate operations.
- Elder: 500 repeatable XP + one-time 1000 XP; Ashfang: normal XP + one-time 200 XP. Bonuses persist in flags; do not reward on streaming/respawn. Elder existing victories migrate as already paid. Both boss cooldowns are 1080 gameplay seconds; Ashfang appears only at night. Day/night is 600/480 seconds with smooth 90-second transitions; night ordinary packs double.
- Floor Two: seven giants at G9/I8/I9/K6/D10/E6/I3, 128 HP / 36 damage; each splits once into four 45 HP / 8 damage greens worth 18 XP, 5–6cp and independent residue/potion drops. D10 also has a Sticky Slime. No Floor Two core drops. Partial fights persist across save/travel; rest/death resets the local encounters.
- Water Walkers: Fen vendor only, level 10 / 450cp / 15 Green Slime Residue. Water gait multiplier 1.2 instead of terrain drag; sticky hazards remain separate. Do not turn this into drowning immunity.
- Render budget: default 60 FPS; retain capped options, distant scenery streaming/LOD, sleeping distant enemies, bounded spawn work and ground collision. Never hide collision walls/terrain as a performance workaround.
- Visible equipment accessories were deferred to Blender. Keep equipment bonuses/slots and sword variants working; do not recreate procedural skin overlays.
- Personal animated heroine source is `art/source/beta-heroine.blend`; sword `beta-greatsword.blend`, wolf `beta-wolf.blend`, two-headed wolf `two-headed-wolf.blend`. Original shared rig sources remain `humanoid-v1.blend` / `greatsword-v1.blend`. Do not regenerate any character/animation for a data-only change. The model-review approval gate remains intentional. Old absolute OneDrive paths in art provenance are historical, not setup requirements.
- Actor owns action clocks/resources and sword glow. First-person motion/steel contacts share authored trajectories; retain hand/wrist continuity, real swept steel hit tests, outside-body parry routing and steel restoration after water attacks. Read `docs/FIRST-PERSON-SWORD.md` and `docs/COMBAT.md` before combat animation work.

## Setup, verification and cleanup

- Pinned tools: Godot 4.5.1, Blender 4.5.3 LTS. Runtime GLBs/textures are included; Blender is unnecessary for ordinary editor play. Windows authoring setup is `py -3 tools/bootstrap_runtime.py`; paths are generated into ignored `tools/toolchain.local.json`.
- Use `tools/platform.cmd` for validation, assets, checks, captures, build and run. It isolates test userdata. Never run gameplay fixtures against the human's save.
- Run focused checks for the changed system. Floor Two: `validate`, `inspect-swamp`, then after packaging `inspect-swamp --windows --render`. Inspect actual gameplay images after visual changes. Menu changes: inspect `capture-windows --view menus`. Do not recheck every unrelated heroine animation.
- Known verification limit from v0.41.4: packaged focused swamp inspection passed 64 checks. A broader Windows World Rise attempt reported three uphill-physics fixture failures. Diagnose before claiming the whole suite passes; see the handoff for exact context.
- `build --skip-tests` packages without validation/audits; report it honestly. `build` is the gated asset-validation path. Do not erase failing tests to make a release green.
- Tests/captures use disposable APPDATA/LOCALAPPDATA, removed on success/failure/timeout. Retain only the latest compact outcome, relevant failure log, accepted current screenshots and reusable hash caches. No growing fixture-save/report history. Player saves and user-authored map fragments/drafts are never test garbage.
- `game/content/release.json` selects the single local Windows release. After a replacement is accepted, use `tools/clean_obsolete.ps1`; keep current sources/evidence, refresh shortcuts via `tools/install_desktop_shortcut.ps1`. Tooling/documentation-only handoffs do not need a new gameplay version or animation renders.
