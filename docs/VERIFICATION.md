# Prototype verification

Verified October 4, 2026 with Godot 4.5.1, Blender 4.5.3 LTS, Windows x64, and the Compatibility renderer.

## Functional checks

The source project and exported `CoastalFoundation.exe` both passed **31 integration checks**. The suite exercises the actual imported character rig, shared animation resources, module visibility, material recoloring, mapped movement inputs, fixed actor height, cardinal movement, house/water collision, sign dialogue, suspended movement during dialogue, both map exits, and versioned save/load restoration. Invalid save coordinates, unknown maps, water/building positions, and unsupported editing inputs are rejected.

The suite uses a separate temporary save and leaves the player's save untouched. Reports are in `output/verification/integration-report.json` and `output/verification/export-integration-report.json`. Verification invokes engine input actions; it does not automate a physical keyboard or mouse.

## Render checks

Real renderer captures were inspected for both maps, dialogue, character appearance, and four walking directions. The exported Windows executable also rendered successfully at **1366 × 768**, preserving a **1280 × 720 game image at 2× integer pixel scale** with borders. Text remains in a separate readable UI layer.

The heroine preserves the brown bob, blue dress, belt, socks/boots, and blue-gem sword. The sword uses a separate attachment and stays clear of the ground. The reusable model is a simplified prototype asset; new garments and skeleton families need their own animation/deformation checks.

The exported-game sample on this machine recorded approximately **169 FPS average**, **6.33 ms frame time at the 95th percentile**, over **180 frames after loading**. Hardware: NVIDIA GeForce RTX 5070 Laptop GPU, Intel Core i7-14700HX. This is a short local sample, rather than a performance guarantee for other hardware or larger maps. Raw metrics are in `output/verification/windows-render/render-metrics.json`.

## Reuse and packaging

- Recolor/module changes retain the same imported animation resource.
- A map-definition alteration creates a prop without gameplay code changes.
- Geometry cache hits were observed after routine data checks.
- A repeated unchanged build reported both geometry and Windows export cache hits.
- The character-only preview command was run successfully.
- Python tool scripts compiled successfully.
- The native executable embeds its game data. The Windows ZIP includes the executable, player instructions, and Godot/third-party notices.

Use `tools/platform.cmd verify` after engine/rig changes and inspect the relevant rendered views. For routine palette changes, use `capture --view characters`; for map/camera changes, use `capture --view world`.
