# World Rise — development handoff

**Current game: v0.41.4. Prepared October 18, 2026.**

This is the **`codex/world-rise-handoff`** branch of Coastal Foundation, created from the latest Alpha commit `7af7e89` for continued World Rise development on another computer.

**Read [START-HERE-WORLD-RISE.md](START-HERE-WORLD-RISE.md) first.** It contains the exact Git LFS clone command, editor and Windows build setup, and a prompt to give your AI. Then read [the current development handoff](docs/WORLD-RISE-HANDOFF.md) and [AGENTS.md](AGENTS.md).

World Rise is an Advanced-graphics, first-person action RPG with a shared character across floating floors:

- **Floor One:** large hills and boar valleys, wolf forest, guild vendors/contracts, western bridge-island chain with Ashfang and two-headed wolves, and a concealed Elder boss chamber.
- **Floor Two:** 101 small swamp islands joined by winding shallows, green mist/deadly deep water, splitting giant slimes, a Sticky Slime, rest crystals and a small guild trading raft.
- Shared sword combat, timed parries, stamina, jumping, dodge/dash, three-category World Rise progression, inventory, equipment, item drops, day/night cycle, saves and discovered-only fast travel.

Latest changes: Elder 500 repeatable XP + 1000 first-victory XP; Ashfang +200 first-victory XP; giant slimes 36 damage; more aggressive small-slime leaps; D10 Sticky Slime; level-10 Water Walkers sold on Floor Two for 450cp and 15 residues. Floor One guild-direction signs are removed. See the handoff for precise current behavior and known limitations.

## Quick start

```powershell
git lfs install
git clone --single-branch --branch codex/world-rise-handoff https://github.com/felixcampbell777-hue/Emotion-Stone.git WorldRise
Set-Location WorldRise
git lfs pull
py -3 tools/check_checkout.py
```

Open `game/project.godot` in **Godot 4.5.1 standard**, allow the first import to finish, then run. Select **World Rise — Floor 1** on the title and Start New Game. The shared project currently defaults to Alpha 2; this branch preserves its gameplay settings. Blender is not needed to play in the editor. Windows export setup is in the start guide.

## Included source and assets

Runtime GDScript, JSON and shaders are under `game/`; runtime GLBs/textures under `game/assets/`. Editable Blender files are in `art/source/`, donor library/provenance in `art/library/` and `art/environment/`, generation/build tools in `tools/`, schemas in `schemas/`. Large files use Git LFS. Finish downloading them before import; GitHub Download ZIP may not materialize LFS assets.

The full shared project and its standalone map builder are included so dependencies remain intact. Alpha, Alpha 2 and Beta still exist with separate saves. Develop World Rise on this branch; use `alpha`/`beta` only when deliberately integrating changes.

Player saves, machine-specific tool paths, installed tools, `.godot` caches, generated Windows packages and test artifacts are excluded. Your friend starts with their own local save. Current gameplay export version is selected by `game/content/release.json`; builds are generated locally, not stored as source in Git.

## Main references

- [Setup and collaboration](docs/GITHUB.md)
- [Current state, file ownership and known issues](docs/WORLD-RISE-HANDOFF.md)
- [Newest baseline](docs/CURRENT-BASELINE.md)
- [Floor Two terrain](docs/WORLD-RISE-FLOOR-2.md)
- [Permanent Floor Two island codes](docs/maps/FLOOR-02-REFERENCE.md)
- [Map builder](docs/MAP-BUILDER.md)
- [First-person sword](docs/FIRST-PERSON-SWORD.md)
- [Asset credits and licences](docs/ASSET-CREDITS.md)

Older documents contain historical designs and balances. The newest baseline, handoff and current code/content take precedence. The whole game is not represented as having a single blanket open-source licence; retain all third-party notices.
