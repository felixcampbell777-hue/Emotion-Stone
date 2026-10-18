# GitHub source and branches

Repository: https://github.com/felixcampbell777-hue/Emotion-Stone

As of October 18, 2026:

| Branch | Purpose |
|---|---|
| `alpha` | Main evolving shared game, currently including Alpha 2 and World Rise |
| `beta` | Older independently maintained Beta prototype; do not merge it over newer World Rise |
| `codex/world-rise-handoff` | Current World Rise collaborator handoff, based on Alpha `7af7e89` / gameplay v0.41.4 |

Read [the start guide](../START-HERE-WORLD-RISE.md) for a new computer and [the handoff](WORLD-RISE-HANDOFF.md) for exact gameplay state and known issues.

## Clone with assets

```powershell
git lfs install
git clone --single-branch --branch codex/world-rise-handoff https://github.com/felixcampbell777-hue/Emotion-Stone.git WorldRise
Set-Location WorldRise
git lfs pull
py -3 tools/check_checkout.py
```

Git LFS downloads the editable models and runtime images/models. GitHub's Download ZIP is not a reliable replacement for an LFS clone. Private repositories require account access; pushing requires write permission or a fork. Authenticate on your own computer using your own account. No credentials are distributed in this branch.

## Run or build

Open `game/project.godot` in Godot **4.5.1 standard** and run the project; choose World Rise on the title. Pre-exported runtime GLBs/textures are included, so Blender is unnecessary for editor play. No .NET runtime or online service is required.

For Windows packaging with Python 3's `py` launcher:

```powershell
py -3 tools/bootstrap_runtime.py
.\tools\platform.cmd validate
.\tools\platform.cmd build --skip-tests
```

Bootstrap downloads Godot 4.5.1/templates and Blender 4.5.3 LTS, installs Python validation dependencies into the user cache and writes ignored local tool paths. `build --skip-tests` only packages; it does not certify gameplay. Use focused verification for the changed system. Builds/caches are recreated locally; a missing build cache is supported on this branch.

## Working together

Read `AGENTS.md`, `WORLD-RISE-HANDOFF.md` and the latest `CURRENT-BASELINE.md`. Use your checkout root in place of historic `C:\Games\CoastalFoundation` paths; the old OneDrive project is obsolete. Preserve current source assets, IDs, floor travel and save migrations.

Commit small coherent changes on this branch or create your own branch based on it. Push and send Felix the branch/commit for review or open a pull request into the agreed destination. Do not force-push or replace newer game code with old Beta exports. Two independent checkouts can be edited simultaneously; Git merges are the integration point. Coordinate before changing the same Blender binary.

Verification commands isolate temporary userdata and remove fixture saves. Keep current evidence and small audit caches; don't commit test data or a player's save. Known v0.41.4 verification limits are in the handoff; do not reuse the historical v0.31.x check count as a current pass.

## Asset licences

This is a game repository, not a separately relicensed third-party asset pack. Keep intake hashes, attribution and licence files under `art/` and `docs/ASSET-CREDITS.md`. Large assets use LFS; installed authoring tools, credentials, private saves and generated releases stay excluded.
