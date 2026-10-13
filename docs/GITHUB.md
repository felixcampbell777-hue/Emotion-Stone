# GitHub source and branches

Repository: https://github.com/felixcampbell777-hue/Emotion-Stone

`alpha` holds the existing adventure, starting upstairs at home. `beta` holds the meadow/woodland and castle-town prototype. The branches start from the same verified v0.31.2 game source and shared assets, and can now evolve independently. Alpha retains its existing default; Beta's `coastal/default_game_mode` setting in `game/project.godot` selects Beta on the title. The title selector and separate Alpha/Beta save files remain available on both branches; no quests, combat or assets have been stripped to separate them.

## Clone and run

Install Git with Git LFS, then use PowerShell:

```powershell
git lfs install
git clone --branch alpha https://github.com/felixcampbell777-hue/Emotion-Stone.git
Set-Location Emotion-Stone
git lfs pull
```

Use `--branch beta` instead for Beta. Open `game/project.godot` in Godot **4.5.1** and run the project. Runtime GLBs/textures are included, so Blender is unnecessary just to play from the editor. Git LFS must finish downloading before Godot imports the assets.

For the tested Windows packaging/authoring toolchain, install Python 3 and run:

```powershell
py -3 tools/bootstrap_runtime.py
.\tools\platform.cmd validate
.\tools\platform.cmd build
.\tools\platform.cmd run
```

The bootstrap prepares pinned Godot 4.5.1, Blender 4.5.3 LTS and Python dependencies. It writes the ignored `tools/toolchain.local.json` for this machine. The first build recreates ignored caches and Windows output. `Play.cmd` requires that Windows build. The standalone map builder uses the same assets and build toolchain.

## Editing and verification

Read `AGENTS.md`, `docs/CURRENT-BASELINE.md` and `docs/EDITING.md`. On other machines, interpret the canonical `C:\Games\CoastalFoundation` path as your checkout root; do not recreate the superseded OneDrive checkout. Use the current editable Blender assets, content JSON and recipes rather than old exports.

The v0.31.2 gameplay baseline passed **1,342 source and Windows checks** before publication. The branch startup setting is isolated from private `--verify` / `--capture` fixtures so they continue to start Alpha and explicitly enter Beta when needed.

```powershell
.\tools\platform.cmd verify-beta
.\tools\platform.cmd verify
.\tools\platform.cmd verify-windows
```

Native rendered evidence and builds remain local under ignored `output/verification/` and `output/windows/`; generate captures with `tools/platform.cmd capture-windows` after building. User saves live in Godot's user-data directory and are never uploaded.

For a shared fix, commit it on the branch you are working on and cherry-pick that commit onto the other branch. Keep that branch's `coastal/default_game_mode` and README identity. Avoid a wholesale branch merge that accidentally changes the selected mode.

## Asset licences

This is a game repository, not a standalone third-party asset pack. Attribution, intake hashes and source licences are retained in `art/` and `docs/ASSET-CREDITS.md`. Third-party material retains its original licence; publishing this repository does not relicense it or imply one blanket open-source licence for the whole game. Large asset files use Git LFS. No tool binaries, credentials, local Python packages or obsolete release folders are committed.
