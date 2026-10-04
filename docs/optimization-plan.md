# Reusable game platform: optimization plan

Original plan prepared October 4, 2026. The implementation status is recorded below.

**Implementation update:** the user subsequently authorized construction. The first reusable prototype is now implemented; see `README.md` and `docs/EDITING.md`. The original analysis below is retained as the planning record. Godot 4.5.1 and Blender 4.5.3 LTS are pinned for this build.

## Recommendation

Build a Windows desktop exploration platform in **Godot 4 with GDScript**, using **low-poly 3D characters and modular 3D scenery rendered into a low-resolution image**. Author and animate the reusable character kit in **Blender**, export explicit **GLB** assets, and keep gameplay on a horizontal plane. Use a fixed, elevated orthographic camera and a grid-based world construction kit.

The user confirmed Windows desktop first. The engine and art workflow are recommendations based on the current requirements, rather than additional user constraints. Here, “platform” means a reusable game foundation and content pipeline.

The largest upfront investment should be in a working asset pipeline, reusable modules, and a few proven editing recipes. High initial usage alone does not guarantee inexpensive future changes. A small validated foundation is more valuable than speculative systems for every possible future game.

Godot provides 3D scene import, reusable animation libraries, import automation, and command-line builds. It is MIT licensed. These capabilities support the proposed workflow; the judgment that it is the best fit for this project is my recommendation. [Import and animation documentation](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.html), [command-line documentation](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html), [license](https://godotengine.org/license/).

## What “3D pixelated” should mean

Use genuine 3D geometry for depth, occlusion, rotation, and animation. Give it simple shapes and small textures, then render the world at a fixed low resolution. This produces a Pokémon-like elevated exploration view while avoiding the need to draw each character from every direction.

Start the visual experiment at a **640 × 360 world viewport**, with **320 × 180** as a deliberately chunkier comparison. These are trial values, not final requirements. Enlarge with nearest-neighbor sampling and an integer scale; use borders when a window size does not fit exactly. Keep dialogue and accessibility text in a separate, legible UI layer. Godot documents integer scaling and low-resolution viewport rendering. [Resolution documentation](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html).

Use a fixed camera orientation initially. A freely rotating camera would increase environment, occlusion, and art validation work. Start with simple matte shading, restrained lighting, and a contact shadow. Try the Compatibility renderer first because the proposed visuals do not require advanced effects; benchmark on the actual machine before locking it. Godot identifies Compatibility as a candidate for simple 3D and broad hardware support. [Renderer comparison](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html).

Low resolution alone is insufficient for convincing pixel art. Test camera movement, silhouette stability, edge flicker, contrast, and texture aliasing in motion. Keep simulation positions smooth; if a projected pixel snap is needed, apply it to the visual camera/model presentation rather than the collision position. Quantize camera movement in its screen-space basis, rather than rounding arbitrary world coordinates.

## Compare the art workflows

The relative costs below are engineering judgments, not measured usage figures.

| Workflow | Initial work | Later character changes | Fit for this project |
| --- | --- | --- | --- |
| Low-poly 3D, low-resolution rendering | Rig, skinning, modular meshes, export, camera tuning | Palette and compatible module changes can reuse animation | Recommended balance of real depth and scalable character creation |
| 2D sprites in a 3D world | Sprite system, directional art, consistent scale and lighting | Palette swaps are cheap; new silhouettes require directional frame work | Strong alternative if precise hand-authored pixels matter most |
| Fully 2D tile/sprite game | Usually the smallest engine and art pipeline | Simple recolors are cheap; new animation designs still cost work | Efficient, but less aligned with the requested real depth |
| Voxel or cuboid 3D | Reusable block construction and animation/export workflow | Very systematic when the art direction embraces blocks | Good for an intentionally blocky aesthetic; weaker match for the existing girl |

For illustration, a four-direction sprite character with two animations of eight frames has 64 frame slots. Recoloring an existing indexed sheet can update them all cheaply. A different coat, hairstyle, or sword pose can require changes across many slots. A compatible 3D rig uses the same animation clips while the engine rotates the character.

**Blender is an asset editor, not the game engine or the graphics style.** It is suitable for the recommended rigged 3D workflow. It becomes unnecessary overhead if we choose hand-drawn 2D sprites, where Aseprite is the more focused tool. Aseprite supports batch export and palette changes. [Aseprite CLI](https://www.aseprite.org/docs/cli/).

Blockbench is a credible alternative for low-poly modeling, pixel textures, and keyframe animation; it also supports mesh modeling beyond cubes. It could be preferable for a more block-like art direction. For this girl's deforming dress and a reusable humanoid rig, I favor Blender's broader scripting and asset pipeline. Validate any alternative's animation export before committing. [Blockbench features](https://blockbench.net/).

## Compare the engine choices

| Candidate | Evaluation |
| --- | --- |
| Godot + GDScript | Recommended. A compact built-in editor and scene/resource workflow, with explicit asset imports and CLI automation. |
| Unity | Viable, especially with an existing Unity project or team. Its prefab system supports reusable objects. Starting this small platform there does not currently offer a clear project-specific advantage over Godot. [Unity prefabs](https://docs.unity3d.com/Manual/Prefabs.html). |
| Unreal | Viable, but its advanced rendering and larger editor workflow do not solve the central need for cheap small content edits. Reconsider if requirements grow toward complex cinematic 3D. This is a scope judgment, not a claim that Unreal cannot be automated. |
| Custom browser/WebGL engine | Useful when instant browser access is the main requirement. For Windows desktop first, building extra editor, asset, and packaging infrastructure would dilute the upfront investment. |

Pin the exact tested Godot, Blender, and exporter versions during implementation. Store executable paths and versions in a local toolchain record. Upgrade deliberately after export/import verification rather than automatically following the latest release.

## Evaluate the suggested optimizations

### A hard instruction manual

Useful, but it should be short and supported by executable rules. A large prose manual still consumes context, can become stale, and cannot reliably enforce a bone name or export setting.

Use a small `AGENTS.md` as an entry point, a compact decision record, and task-specific recipes. Enforce structural contracts with schemas and validators once the platform exists. Future edits should load the relevant definition and recipe instead of rereading the entire project history.

### Saved Blender precursors and walking animations

This is a strong idea if “precursor” means a maintained master rig, compatible mesh modules, and shared clips. Save one original Blender source with a reproducible export script. Keep animation separate from character definitions so a color or hair change does not create another animation library.

Recoloring alone produces variants, not a complete character creation system. Use three layers of reuse:

1. **Palette:** skin, hair, clothing, leather, metal, and accents.
2. **Modules:** hair, clothing, footwear, and attached equipment.
3. **Rig family:** shared proportions, skeleton hierarchy, rest pose, skin bindings, and animation paths.

Begin with one humanoid family. Add another only when requested body shapes cannot reasonably fit it. Reusing animation across different skeletons may require retargeting and manual correction. Different leg lengths, bulky clothes, and two-handed equipment can cause foot sliding, clipping, or pose changes even when bone names match.

### Prebuilding lots of animation

Start with **idle and walk** plus a simple interaction pose. Add a carry override for the existing sword only if needed for walking. Expand with run, sit, combat, or other states when gameplay requires them. A large speculative animation library would spend usage before its requirements are known.

Keep locomotion in place and let gameplay own world translation. Match animation playback speed to movement speed. Maintain a single canonical skeleton hierarchy and explicit rest pose; bake supported deform-bone animation for export. The production frame rate and animation sampling rate are separate decisions.

## The reusable foundation to build

### Character kit

- One master humanoid rig with stable bone names, parent hierarchy, rest pose, scale, and documented facing direction.
- A small set of swappable hair, clothing, and footwear modules bound to that rig.
- Semantic color slots or a tested shared palette material, so routine recolors can happen in engine without reopening Blender.
- Equipment sockets with explicit offsets; keep the greatsword separate from the body mesh.
- One locomotion animation library, reusable actor scene, and consistent animation track paths. A palette-only character variant should reference the same model and clips.
- One short Blender Python export recipe and reproducible GLB outputs. Source `.blend` files live outside the Godot import tree; runtime uses exported assets.

Godot recommends glTF and supports explicit GLB imports. Direct `.blend` import works by invoking Blender; using explicit exports here makes the build dependency and output easier to control. [Supported formats](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html).

### World kit

- Stable IDs for terrain and props, consistent cell dimensions, pivots, rotation increments, and simple collision shapes.
- A compact map definition listing terrain cells, prop instances, spawn points, and interaction IDs.
- Terrain and static repeated geometry through GridMap/MeshLibrary where appropriate; NPCs, doors, triggers, and animated objects as ordinary reusable scenes.
- Shared materials and instancing for repeated props when profiling shows a benefit.
- Hand-authored playable layouts initially. Decorative variation can use stored random seeds. Add broader procedural generation only if it reduces an observed repeated task.

Godot's GridMap is for meshes, collision, and navigation; it does not preserve arbitrary interactive child nodes. This distinction prevents doors and NPC behavior from being lost during library export. [GridMap documentation](https://docs.godotengine.org/en/stable/tutorials/3d/using_gridmaps.html).

### Movement and gameplay boundaries

Use **X/Z for horizontal movement and Y for visual height**. There are still three coordinates in the renderer, but only two player-controlled movement axes. The initial playable surface has a fixed actor height and no jump, fall, or gravity mechanics.

Begin with four cardinal movement directions and continuous collision movement, rather than tile-by-tile stepping. This is a proposed Pokémon-like default; tile stepping or diagonals can be added later. Keep camera angle and movement mapping consistent. Trees, roofs, and cliffs can have visual height without adding elevation gameplay.

Multi-level paths, bridges over paths, slopes, and stairs would require explicit navigation/layer rules even without jumping. Treat those as a later feature rather than assuming that removing jumping eliminates all height complexity.

Core reusable components should cover movement, facing, camera follow, animation selection, interaction, dialogue, map loading, and save/load. Keep them separate from character art and story data. Defer combat rules until the intended combat system is specified.

### Repeatable editing and build tools

Implement a small set of commands with stable arguments: validate a content definition, create a compatible character variant, export a changed mesh, rebuild a map, run the relevant smoke scene, and export Windows.

These commands are planned interfaces, not available commands today. Prefer straightforward scripts and the engine editor over a new custom editor or domain-specific language.

Record source hashes, palette/module dependencies, exporter versions, and export options. Rebuild only affected assets. A palette-only change should avoid mesh export; a new map should avoid character rebuild; a shared rig change should deliberately invalidate its dependents. Cache hits must depend on the complete input/version record.

Use version control for source, definitions, recipes, and toolchain versions. Keep generated exports reproducible, and retain a known working release. Exclude transient engine caches from synchronization/version control. The workspace is in OneDrive: use a single active writer for binary Blender sources and avoid syncing regenerable caches where possible.

## Implementation sequence and completion gates

| Stage | Upfront work | Gate before expanding |
| --- | --- | --- |
| 1. Prove the look | Tiny visual test scene, candidate world resolutions, camera, simplified heroine silhouette | Girl reads clearly at actual game scale; moving edges are acceptable; UI remains legible |
| 2. Prove rig reuse | Master rig, idle/walk, dress deformation, separate sword, a compatible second appearance | Both appearances use the same clips; feet, dress, and sword behave acceptably from all movement directions |
| 3. Prove cheap content edits | Character/map definitions, validation, incremental export/build scripts, concise recipes | Recolor, hair-module swap, and a small map change work without rewriting gameplay |
| 4. Build the minimal playable platform | Small connected test areas, collision, interaction, dialogue, loading, versioned save data, Windows build | Character explores, talks, changes areas, saves, and reloads in the exported executable |
| 5. Expand content | Requested environments, characters, animation, and gameplay | Existing change recipes remain usable; add new tooling only for demonstrated repetition |

The visual and rig tests are a small vertical slice. They should happen before constructing a large content library because camera scale and rig incompatibility are expensive to discover late.

Target 60 FPS for the initial test scene on the actual Windows machine, then record that machine's hardware and measured frame times. This is an acceptance target, not a present performance claim. Headless checks verify data and builds; rendered smoke scenes verify pixels, animation, and input behavior.

## How to verify that later usage is lower

Track model usage when available, number of files touched, rebuild time, manual repairs, and the checks needed for these representative requests:

| Later request | Expected scope after setup | Relative model work |
| --- | --- | --- |
| Change dress or hair color | One character palette definition and visual check | Very low |
| Add an NPC using existing compatible modules | One character definition and map spawn | Low |
| Move a building or change a path | Map data and targeted collision check | Low |
| Add a new hairstyle or garment | One module, binding/export validation, game-scale view | Medium |
| Add a different body family or unique animation | Rig/animation work and integration | High |
| Add elevation gameplay, combat, or a new camera model | System changes and broader verification | High |

Measure one recolor, one compatible NPC, and one map alteration after the pipeline works. Compare these with the initial setup and keep the recipes/logs. No fixed token savings can honestly be promised before measurement; the mechanism is replacing repeated reasoning and asset generation with local deterministic work.

## Current deliverables and next construction step

The workspace originally contained illustration PNGs, including the latest heroine reference, but no game project or editable character model. Godot and Blender were not found on PATH or in the checked standard locations; installation elsewhere remains possible.

This planning stage adds this plan, a compact machine-readable proposal, a short project instruction entry point, and a reduced heroine reference with its art direction and generation prompt. The reference image is visual guidance; a rigged model still needs to be constructed and validated.

The first construction step is Stage 1: a small Godot visual experiment with the proposed camera and a simple heroine representation. Its result should determine the final pixel density and modeling detail before the reusable asset library grows.
