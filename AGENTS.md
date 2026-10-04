# Project entry point

This project contains a reusable Windows desktop game foundation with a pixelated 3D map and no jumping. The user authorized implementation of the optimization plan.

- For routine edits, read `docs/EDITING.md` and the affected definition under `game/content/`. Use `README.md` for the file map. Runtime settings are in `game/content/platform.json`.
- The tested toolchain is Godot 4.5.1/GDScript and Blender 4.5.3 LTS. Paths are in `tools/toolchain.local.json`; binaries are cached outside OneDrive. `docs/platform-proposal.json` records the decisions and implementation state.
- For the heroine, read `docs/character-art-direction.md` and inspect the referenced artwork. Preserve original PNGs; save new variants separately.
- Use `tools/platform.cmd` for validate, assets, verify, capture, build, and run. Recolor/variant/move-prop commands perform small validated data edits. Palette/map-only changes should retain the geometry cache. Preview only affected views with `capture --view characters` or `capture --view world`.
- Keep editable source assets separate from exported runtime assets. Pin tested tool versions during implementation. Verify gameplay visuals in a rendered scene; headless checks cannot establish visual correctness.
- Editable character sources are under `art/source/`; shared GLBs are under `game/assets/characters/`. Generator rebuilds back up existing Blender sources into `art/source/history/`.
- Integration verification uses a separate save file. Playable output is `output/windows/CoastalFoundation.exe`, launched by `Play.cmd`. Never replace the player's real save during verification.
