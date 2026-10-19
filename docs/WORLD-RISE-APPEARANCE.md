# World Rise appearance

The Appearance screen is available from Inventory and Pause during World Rise.
It edits appearance only: face, hair, skin tone, body silhouette and colors.
Progression, equipment slots, names, voice, camera height, collision and weapon
reach are not part of the profile.

The independent preview has no Actor, physics, input commands or save hooks.
Dragging rotates it; the wheel zooms; Front, Side and Back restore useful views.
Changes remain a draft until Apply. Cancel discards the draft. Reset restores the
original profile; Randomize uses the reviewed options and authored color swatches.
Applied changes persist through the next normal game save or floor-travel save.
Online Apply waits for the host's authoritative result. A rejection or disconnect
keeps the draft available and does not change the accepted appearance.

## Reviewed options and default

The human approved the shown options on October 18, 2026: **“Approve these options”**.
The approval, static comparison images, editable candidate and exact hashes are in
`art/character/appearance-review/`. This is a separate asset-specific approval;
`art/character/model-review.json` still records the older rejected draft's gate.

| Category | Stable IDs |
| --- | --- |
| Face | `default`, `soft_cheeks` |
| Hair | `chestnut_layers`, `short_layers` |
| Skin | `default_freckled`, with skin color |
| Body | `default`, `subtle_shape` |
| Colors | Skin, hair/brows, iris, clothing, leather |

All eight face/hair/body combinations preserve the existing sixteen-bone rests,
skin weights, hand and foot anchors, height and nineteen existing animation clips.
Face and body changes occupy separate height regions; hair is a separate mesh.
The short-layer fit retains the original fringe/hairline and changes the lower
layers. The existing dragon support-hand mesh and first-person view arms rebuild
from the accepted surface, preserving the authored grip system.

The original `beta-heroine.blend` and `heroine-beta.glb` bytes remain unchanged.
The original profile uses its original mesh resources exactly. An intentional,
non-destructive material bug fix replaces black dress-atlas background sampled by
the sleeve UVs with the existing matching denim, for the original shape and all
variants. Iris tint changes colored iris pixels while preserving the sclera,
pupil and the original material's lighting settings. A CPU Image resource preserves the exact
original eye pixels without requiring compressed GPU texture readback on an ASTC
export or dedicated host. White color restores each
original baked color, with the denim material fix retained.

## Ownership and serialization

- `appearance_profile.gd`: the shared allowlist, normalization, snapshots and
  stable profile key used by editor, saves and network.
- `game/content/world_rise/appearance.json`: reviewed options and color swatches.
- `appearance_geometry.gd`: reviewed surface formulas, finite normal correction
  and a cache bounded by the eight possible geometry combinations.
- `character_appearance.gd`: geometry/material application, isolated material
  copies and a bounded iris texture cache. Imported materials are never mutated.
- `appearance_menu.gd` / `appearance_preview.gd`: draft workflow and cosmetic-only
  preview. `main.gd` owns accepted state, revision, persistence and host result.
- `beta_hero.gd`, `first_person_visuals.gd`, `equipment_preview.gd`: presentation
  reconstruction and shared appearance application.
- `schemas/appearance_profile.schema.json` and `appearance_catalog.schema.json`:
  corresponding content contracts.

Appearance version remains 1; catalog version is 2. The original catalog-1 IDs
migrate to catalog 2 without changing the profile's choices. Saves lacking the
field restore the original profile. Unknown IDs/keys, unsupported versions,
unapproved numeric morphs and invalid RGB strings are rejected. Neither clients
nor saves supply resource paths. The profile's `morphs` object must be empty;
reviewed geometry is represented by the preset IDs.

The authoring reference GLB in the review directory records reviewed morph data
and reuses the original textures. Runtime deliberately bakes the same bounded
formulas from original CPU vertex arrays: Godot 4.5's headless dummy renderer
cannot retrieve imported GPU morph arrays. No renderer-dependent morph lookup or
replacement rig is needed by a dedicated host.

## Focused verification

Run from the checkout root after normal tool setup:

```text
tools/platform.cmd verify-appearance
tools/platform.cmd capture --view appearance --renderer forward_plus
```

On macOS/Linux, use `./tools/platform.sh` with the same arguments. The focused
checks and captures use disposable user data. Native menu captures cover 1280×720
and 960×540. The capture fixture checks preview isolation, cancellation,
authoritative rejection retaining a draft, Apply, unchanged progression/equipment,
validated save/reload, all reviewed geometry IDs and old-save default migration.
Separate geometry checks exercise all eight combinations, finite surfaces,
unchanged skin weights/rests/anchors, visible option changes and exact original
mesh restoration. Inspect the actual images before accepting a visual change.

Latest focused implementation acceptance: 21 profile/material/iris checks, 199
geometry checks across all eight combinations, and 23 actual Forward+ capture
checks passed. Captures include the approved face/hair closeup, 960×540 controls,
matching selected body and first-person skin, save/reload, old-save migration and
host-rejection draft retention. This focused result does not claim the unrelated
full gameplay suite passes.
