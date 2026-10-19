# World Rise — start here

**For the next human and AI developer. Prepared October 18, 2026.**

**Current source candidate:** implementation was subsequently authorized and now includes new weapons, approved appearance options, audio/voice and dedicated multiplayer. The latest follow-up keeps Strength / Agility / Greatsword with Cyberpunk-inspired perk trees (tree 6/protocol 5), C to toggle first/third person, screen-only cosmetic blood feedback and measured performance improvements; read current status for the verification gate before treating these additions as accepted. Gameplay metadata now selects v0.42.0. Local source acceptance and separate mandatory native publication gates are recorded in the status; consult the exact reports/checksums shipped with each download. Start with the newest [baseline entry](docs/CURRENT-BASELINE.md), [implementation status](docs/WORLD-RISE-IMPLEMENTATION-STATUS.md) and [integration contract](docs/WORLD-RISE-INTEGRATION-CONTRACT.md). The setup/released-baseline material below remains useful, while original planning snapshots and older behavior descriptions are historical.

Branch: **`codex/world-rise-handoff`**. Gameplay: **v0.41.4**, based on Alpha commit **`7af7e89`**. This branch contains the full shared project, both World Rise floors, editable art, runtime assets, shaders, content, map builder, recipes and licences. Other modes remain to preserve shared dependencies.

## Get the complete source

Install Git **with Git LFS**, then run PowerShell:

```powershell
git lfs install
git clone --single-branch --branch codex/world-rise-handoff https://github.com/felixcampbell777-hue/Emotion-Stone.git WorldRise
Set-Location WorldRise
git lfs pull
py -3 tools/check_checkout.py
```

Use a local folder outside OneDrive. The final checkout check requires Python 3 with the `py` launcher; skip that one command if you are starting with Godot only. GitHub's page preview is enough to read code; use the LFS clone above for development. Do not rely on Download ZIP for large assets. If the repository is private, Felix must give your GitHub account access first. To push from your computer, authenticate as yourself and have write permission, or use your own fork.

## Fastest way to play and edit

1. Install **Godot 4.5.1 standard** (GDScript; no .NET requirement).
2. Import/open **`game/project.godot`** after LFS finishes. Let Godot complete its first asset import, then run with F6/F5 as appropriate (F5 runs the whole project).
3. On the title screen choose **World Rise — Floor 1**, then Start New Game. The editor/shared project defaults to Alpha 2; the dedicated World Rise client download defaults its title selection to World Rise. Other title choices remain available.

Blender and Python are unnecessary to run the game in Godot. No exported Windows EXE is committed. Your new local character starts at level one; Floor Two unlocks after the Elder. Existing player saves from Felix's computer are intentionally excluded.

## Windows build/tooling setup

Install Python 3 with the `py` launcher, then run from the checkout root:

```powershell
py -3 tools/bootstrap_runtime.py
.\tools\platform.cmd validate
.\tools\platform.cmd build --skip-tests
```

Bootstrap downloads the pinned Godot 4.5.1 engine/export templates and Blender 4.5.3 LTS and installs validation dependencies into your user cache. It creates your own ignored `tools/toolchain.local.json`. The packaging command above skips tests/asset audits; it does **not** certify gameplay. Launch the resulting `output/windows/v0.42.0/CoastalFoundation.exe`, or double-click `Play.cmd` after building. `platform.cmd run` uses the gated build path and can run expensive asset audits on the first machine setup.

For validation of gameplay changes, use the focused commands documented in the handoff. Terrain regeneration additionally needs NumPy in the Python environment running `tools/create_swamp_floor.py`; it is not required for editor play or JSON/GDScript edits. Do not regenerate terrain merely to place an enemy.

## macOS and Linux tooling

Use `python3 tools/bootstrap_runtime.py`, then `./tools/platform.sh validate`. The portable wrapper preserves the Windows commands and isolates fixture userdata on each host. Add `--with-blender` only for art authoring; ordinary editor play and source checks need only the pinned Godot. See [portable tools](docs/PORTABLE-TOOLS.md) and [dedicated hosting](docs/DEDICATED-SERVER.md) for export/container setup and its acceptance limits.

## Give your AI this instruction

> Work on World Rise in this checkout. Read AGENTS.md, docs/WORLD-RISE-HANDOFF.md and the newest docs/CURRENT-BASELINE.md entry before editing. Gameplay baseline is v0.41.4 / Alpha 7af7e89. Preserve saves, canonical first-person sword/hand combat trajectories in both camera views, floor travel and performance budgets; use current attribute/perk progression and its legacy migration. Use current sources rather than older history. Ask me what to build next; don't invent unrelated balance changes. Keep commits on this branch or a branch based on it.

The detailed [handoff](docs/WORLD-RISE-HANDOFF.md) describes the current maps, balance, file ownership, save boundaries and known test issues. [Island codes](docs/maps/FLOOR-02-REFERENCE.md) and the [machine-readable registry](docs/maps/floor-02-island-codes.json) let you give exact Floor Two placement instructions.
