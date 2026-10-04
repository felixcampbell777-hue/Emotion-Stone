# Low-usage editing recipes

Start with the relevant content definition, apply one small change, validate, then build and inspect the affected view. Existing palettes and modules require no new illustration generation or Blender export.

All commands below run from the project root. `tools/platform.cmd` uses the bundled Python when available and falls back to `py -3`.

## Recolor the heroine

```powershell
.\tools\platform.cmd recolor hero 'dress=#6B728E' 'hair=#79563C'
.\tools\platform.cmd capture --view characters
.\tools\platform.cmd build
```

This changes only `game/content/characters/hero.json`. The original baseline is dress `#617688`, hair `#865E3D`. Color slots are skin, hair, dress, leather, metal, gem, and socks. Base/dark/light shading derives from each slot.

The same cached model and animation remain in use. Build output should show `ASSET CACHE HIT`; the Windows executable is repackaged because its content changed. Inspect the character from the game camera after recoloring.

## Create a compatible character

```powershell
.\tools\platform.cmd variant hero violet_keeper --name 'Violet keeper' --hair crop --outfit tunic --equipment none --color 'dress=#7B6A91'
.\tools\platform.cmd validate
```

Add an NPC entry to a map's `npcs` list:

```json
{"id":"violet_keeper_spawn","character":"violet_keeper","at":[3,3],"dialogue":["Hello from the coast."]}
```

Then build and inspect. A character definition alone does not spawn the character. Existing module choices are bob/crop hair, dress/tunic clothing, and none/greatsword equipment. The new character still references `humanoid_v1` and shares its animation resources.

## Move a prop

```powershell
.\tools\platform.cmd move-prop coastal_path bench 4.2 2.1
.\tools\platform.cmd validate
.\tools\platform.cmd build
```

This changes one map definition. Restore the original bench position with `3.8 1.8`. Check nearby walking and camera visibility. Map terrain uses integer X/Z cells; prop positions can be fractional. Angles are degrees around Y. Water and map edges block movement.

## Add or extend a map

Copy an existing map JSON, change its filename and `id` together, then modify bounds, terrain regions, props, NPCs, interactions, and exits. IDs must be unique inside the map. Exit destinations must exist, and exit spawn coordinates must be inside the destination's bounds.

Terrain regions apply in list order, with later regions overriding earlier ones. Supported terrain: grass, path, sand, water. Supported props: tree, house, wall, rock, flowers, bench, well. Interactive signs use `interactions`; NPCs use `npcs`. Static GridMap entries cannot contain arbitrary door/NPC behavior.

Keep spawn positions clear of solid props and NPCs. Run `verify` after changes to collision or navigation boundaries. The integration suite has fixtures for the two sample maps; if intentionally removing those sample objects, update the fixture checks to exercise equivalent behaviors.

## Edit a Blender source

Open `art/source/humanoid-v1.blend` in the pinned Blender. Keep bone names, hierarchy, bind pose, scale, animation names, and mesh module names stable for compatible edits. Hide the alternate modules while inspecting the chosen outfit. Animation source names are `idle_loop`, `walk_loop`, and `interact`; Godot's importer strips loop suffixes, and the actor maps those imported names back to the canonical keys.

Save the `.blend`, then run:

```powershell
.\tools\platform.cmd assets
.\tools\platform.cmd verify
.\tools\platform.cmd capture
.\tools\platform.cmd build
```

The asset command detects source changes and exports the saved file without rewriting it. Changing the procedural generator or rig spec regenerates the precursor; existing `.blend` files are copied into `art/source/history/` first. `assets --regenerate` explicitly requests a generator rebuild with the same backup behavior.

For a new module, update the generator or editable source, the rig/module contract, character schema, and module visibility rules. Run the imported-rig checks and inspect every facing direction during walking. Distinct skeleton families or two-handed actions are additional rig/animation work.

## Checks and cache behavior

```powershell
.\tools\platform.cmd validate
.\tools\platform.cmd verify
.\tools\platform.cmd capture
.\tools\platform.cmd build
```

Validation checks schemas, references, bounds, IDs, and supported module/color values. Integration checks exercise the imported animation, shared resources, movement, collision, interactions, travel, and save round trips. Render captures check appearance separately and record frame times after loading.

Geometry cache keys include generator/spec inputs, Blender version, editable sources, and export recipe. Windows cache keys include runtime source/content and engine/template version. A palette or map-only edit should retain the geometry cache; a completely unchanged build should retain the Windows cache too.

Use `capture --view characters` for quick character recolor/module checks. Use `capture --view world` for map/camera/UI checks. The default `capture` produces both sets. Inspect only the views affected by the change.

Avoid loading the full illustration history or regenerating concept images for routine edits. Read this recipe, the relevant JSON, and any affected gameplay script. Use the saved render views to judge visual changes.
