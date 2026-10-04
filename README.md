# Coastal Foundation

The project now includes a runnable Windows game foundation: an elevated orthographic 3D world rendered at 640 × 360 or 320 × 180, four-direction walking, the simplified heroine, a compatible NPC, two connected maps, interactions, and versioned saving.

**Play:** double-click `Play.cmd`, or `output/windows/CoastalFoundation.exe`. A shareable archive is in `output/windows/CoastalFoundation-Windows.zip`. The exported game needs no Godot, Blender, or Python installation.

See [player controls](docs/PLAY.md) and [editing recipes](docs/EDITING.md). Open `game/project.godot` in the pinned Godot editor to inspect scenes and scripts.

## Reuse that is already implemented

- One Blender master with a 14-bone humanoid rig and idle, walk, and interaction clips.
- Bob/short hair and dress/tunic modules, with shared body/boot geometry.
- A separate greatsword source/export and a chest attachment for walking.
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
| Dialogue/camera/UI/map travel | `game/scripts/main.gd` |

Editable sources are outside the Godot import tree. Runtime GLB exports are in `game/assets/characters/`. The original illustrations are preserved in `output/imagegen/`.

## Pinned authoring environment

Godot **4.5.1**, Blender **4.5.3 LTS**, and jsonschema **4.25.1** are used here. Portable tools are cached in `%USERPROFILE%\.cache\comic-art-platform`; executable paths are in `tools/toolchain.local.json`. The existing Codex bundled Python runs the tools. Authoring binaries and transient Godot caches are excluded from version control.

To set up the toolchain again on a machine with Python, run `python tools/bootstrap_runtime.py`. It downloads the pinned official Godot release/template and Blender release from the Berkeley Blender distribution mirror and installs validation dependencies into that local cache. It does not change global PATH. Godot archive digests are checked against release metadata when supplied; archive digests are recorded locally.

Use one writer at a time for Blender files in the OneDrive workspace. Preserve source assets and the known working Windows export when making larger changes.
