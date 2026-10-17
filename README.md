# Coastal Foundation

Current source baseline: **v0.35.0**, first-person gameplay with the upright two-hand sword hold, Mana Lance aim control, Dash Reach upgrades uppercut dash attacks with a vertical mana wave, a steerable first-person Mana Sea Dragon, and Flowing Counter, Measured Recovery, Breaker and Undertow.

The GitHub repository has separate **`alpha`** and **`beta`** branches. This checkout is **Beta**: the title selects the meadow, wolf packs and castle town by default. The Alpha branch defaults to Alpha 2 — The Hollow Bell; original Alpha remains available. Both retain the shared engine, map builder, other mode selector and separate saves.

**World Rise:** choose World Rise — Floor 1 on the title for a fresh first-person character on a 480m floating floor. A central arrival platform overlooks substantial hills and valleys, boar herds, northwest wolf woodland, treasure and a metallic abyss rim. Its save is separate. See [World Rise](docs/WORLD-RISE.md).

**Alpha 2:** [The Hollow Bell](docs/ALPHA2.md) is a separate first-person Advanced exploration adventure: nine linked areas, companion quests, hidden equipment, checkpoints and a new Bellkeeper boss. Choose an Alpha or Beta save to copy your character into the campaign; the source save stays untouched. Target playtime is around an hour, depending on imported power and exploration.

For cloning, Git LFS, Windows builds and branch editing, read [GitHub setup](docs/GITHUB.md). Large editable models and runtime art are stored through Git LFS; generated releases, player saves, caches and local toolchain paths are excluded. Third-party assets retain their credits and licences; see [asset credits](docs/ASSET-CREDITS.md).

v0.23.0 adds a full-world Advanced graphics profile: CC0 scanned woodland vegetation/rocks, photographed terrain/roads, detailed roofs/interiors, wet slime surfaces, a scanned-stone guardian and a denser heroine mesh on the existing rig. Forward+ is the desktop default. Original art remains selectable and its editable sources are preserved. All 14 areas and the standalone builder share the new scenery. See docs/ENVIRONMENT-ASSET-INTEGRATION.md and docs/ASSET-CREDITS.md.

The project includes a runnable Windows game foundation: an elevated orthographic 3D world rendered at full window resolution with 8x MSAA, or in Detailed (960 x 540), Fine (640 x 360), or Chunky (320 x 180) mode, smooth diagonal movement, sprinting/stamina, oversized sword combat with timed parries and a flowing three-hit light combo, rushing wind-up bonuses, selectable water sweeps or a charged, interruptible armor-breaking lance, eight connected maps, illustrated conversations, an alchemical-core quest for Mother, four permanent enemy encounters, a death/respawn screen, XP/levels with a Strength / Form / Mana skill tree with ranked roots and equipable attack choices, and versioned saving.

**Play:** double-click `Play.cmd` or the desktop shortcut. The current executable and shareable ZIP are in the release folder selected by `game/content/release.json`. The exported game needs no Godot, Blender, or Python installation. Only the release selected by `game/content/release.json` is retained. Read `docs/CURRENT-BASELINE.md` before changing the game.

The desktop **Coastal Foundation** shortcut uses the custom coastal sword-and-gem icon. `tools/install_desktop_shortcut.ps1` updates it for this checkout; the Windows archive includes **Install Desktop Shortcut.cmd** for another computer. Keep the ICO beside the executable. Icon artwork and its exact prompt are in `game/assets/ui/`; `tools/icon_assets.py` packages ten Windows sizes using Pillow.

See [Menagery and shared sketch codes](docs/MENAGERY.md) for the western scenery catalog, eight practice creature buttons and later area-layout notation.

See [player controls](docs/PLAY.md) and [editing recipes](docs/EDITING.md). Open `game/project.godot` in the pinned Godot editor to inspect scenes and scripts.

See [XP and starter skills](docs/PROGRESSION.md) for the Strength, Form and Mana branches and the reusable stone guardian kit.

## Reuse that is already implemented

- One Blender master with a 16-bone humanoid rig and nineteen shared clips, including secondary hair/dress motion, dragging, three combo attacks, water sweep and two-handed lance poses, and braced parry.
- Bob/short/headscarf hair, dress/tunic/workdress, boots/bare feet, and human/prosthetic left arm modules.
- A separate oversized greatsword, back carry, grip-aligned combat motion, and pooled ground scrape marks.
- Semantic palette overrides in character JSON; no model export for recolors.
- Seeded GridMap terrain, modular scenery, batched grass, and map JSON.
- Schema validation, reference checks, source/export/build caches, and a Windows packaging command.
- Headless integration checks and real renderer screenshot/animation captures.

The rig is a simple reusable starting asset, with modest procedural geometry rather than a finished high-detail character. New body proportions or unusual outfits can require additional rigging work.

## Small local tool interface

Run these from this project folder in PowerShell:

```powershell
.\tools\platform.cmd validate
.\tools\platform.cmd verify
.\tools\platform.cmd capture
.\tools\platform.cmd build
.\tools\platform.cmd run
```

`build` validates definitions, rebuilds only changed source assets, and exports Windows when the runtime source has changed. `run` builds if needed and launches the executable. `verify` never writes the player's real save. `capture` runs the renderer in a hidden test window and writes images/metrics to `output/verification/`.

## Files to change

| Task | First file/location |
| --- | --- |
| Change the heroine's colors | `game/content/characters/hero.json` |
| Add a compatible character | `game/content/characters/` |
| Move props or extend the world | `game/content/maps/` |
| Camera, walk speed, initial map, pixel density | `game/content/platform.json` |
| New geometry or animation | `art/source/humanoid-v1.blend` or `tools/build_character.py` |
| Rig/module contract | `art/rig-spec.json` and `schemas/character.schema.json` |
| Scenery shapes/materials | `game/scripts/props.gd` |
| Movement | `game/scripts/actor.gd` |
| Attack timing/damage/health/slime balance | `game/content/combat.json` |
| Sprint, rushing, stamina, parry, water and mouse hold threshold | `game/content/combat.json` |
| Desktop icon artwork | `game/assets/ui/launcher-icon-v1.png` |
| Authored sword grip/blade trajectory | `game/content/sword_motion.json` |
| Enemy behavior | `game/scripts/slime.gd` |
| Dialogue/camera/UI/map travel | `game/scripts/main.gd` |

See [combat editing and animation contracts](docs/COMBAT.md). The mother matches the wrapped/exposed prosthetic concepts from **Create two character variants**; these runtime modules use native editable geometry.

Editable sources are outside the Godot import tree. Runtime GLB exports are in `game/assets/characters/`. The original illustrations are preserved in `output/imagegen/`.

## Pinned authoring environment

Godot **4.5.1**, Blender **4.5.3 LTS**, jsonschema **4.25.1**, and Pillow **12.3.0** are used here. Portable tools are cached in `%USERPROFILE%\.cache\comic-art-platform`; executable paths are in `tools/toolchain.local.json`. The existing Codex bundled Python runs the tools. Authoring binaries and transient Godot caches are excluded from version control.

To set up the toolchain again on a machine with Python, run `python tools/bootstrap_runtime.py`. It downloads the pinned official Godot release/template and Blender release from the Berkeley Blender distribution mirror and installs validation dependencies into that local cache. It does not change global PATH. Godot archive digests are checked against release metadata when supplied; archive digests are recorded locally.

Use one writer at a time for Blender files in the local checkout. Preserve source assets and the known working Windows export when making larger changes.

Northern goblin campaign and Windstep equipment: [docs/GOBLIN-CAMPAIGN.md](docs/GOBLIN-CAMPAIGN.md).

Magic equipment: [catalog, slots and set bonuses](docs/MAGIC-ITEMS.md). Menagerie [M] > Magic items provides 35 test specimens; equip in Inventory [I].


Monster cores v0.22.0: see [drop/healing/quest rules](docs/MONSTER-CORES.md). Warden, Queen Slime and Goblin Foreman add 300, 800 and 250 XP boss bonuses respectively; prior base rewards remain. Mother now removes one canonical golem core from inventory; consumption is quest locked until completion.

Alpha 2 v0.32.1 has distinct shipwreck coast, marsh, winding forest and coastal bluff routes; salvage and a bell-note puzzle vary the three ward objectives. Collected animated wolves, rats, boars, spiders and crabs replace the old campaign goblins/wardens. The living Bellkeeper has new melee, roots and grown-thornseed patterns. Shore wading, drowning and progressively revealed constellation skills are documented in docs/ALPHA2.md.
