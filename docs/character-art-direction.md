# Main character: reduced 3D pixel-art direction

Prepared October 4, 2026. Proposed art direction for the reusable game platform.

## References

- Identity/costume source: `output/imagegen/main-character-coastal-bluff-greatsword-v6.png`.
- New reduced reference: `output/imagegen/main-character-pixel-3d-reference-v1.png`.
- Exact generation prompt: `output/imagegen/main-character-pixel-3d-reference-v1.prompt.txt`.

The reduced reference was generated with the built-in image generation tool using the earlier illustration as a reference. It depicts a possible low-poly, pixelated appearance. It is concept art, rather than a mesh, rig, animation sheet, or measured engine render.

## Preserve identity through large shapes

Keep her short, slightly tousled chestnut bob, warm light skin, blue-gray collared shirt dress with rolled sleeves, brown belt, light socks, and brown calf boots. Keep the oversized straight silver sword, brown grip, and blue teardrop pommel gem as a separate recognizable accessory.

Use approximately four-and-a-half-heads-tall stylized proportions for the initial modeling experiment. Preserve the source's youthful face and understated expression; the larger head is a readability proposal, not a change in identity.

At normal play scale, prioritize these five cues: brown bob silhouette, blue dress, brown waist stripe, dark boots, and a bright blue sword accent. Freckles, laces, tiny buttons, flyaway strands, and cloth grain can disappear at that scale. The new concept has more hair and fabric detail than the final small model should need.

## Initial model and material proposals

Start with a modest humanoid mesh and distinct modules for bob hair, dress, boots, and sword. Use a few large hair masses rather than individual strands. Suggest dress folds with geometry and a few color blocks. Avoid cloth simulation for the first model; test skinning and a small garment-bone setup only if simple deformation fails.

Trial visual budget: roughly 1,000–3,000 triangles for the body and outfit, with separate modest hair/equipment budgets. This is a starting production constraint, not a requirement or measured performance threshold. Favor clean deformation and readable silhouettes over a strict count.

Use semantic palette slots. The following hexadecimal colors are proposed swatches interpreted from the illustration, not exact sampled source colors:

| Slot | Trial colors |
| --- | --- |
| Hair | Shadow `#50382A`, base `#865E3D`, highlight `#B98C5C` |
| Dress | Shadow `#354553`, base `#617688`, highlight `#92A4B0` |
| Leather | Shadow `#3D2A20`, base `#725136`, highlight `#A37A50` |
| Skin | Shadow `#B97F5B`, base `#E6B78D`, highlight `#F4D2AA` |
| Metal | Shadow `#747C87`, base `#BDC4CE`, highlight `#E8EDF0` |
| Blue gem | Shadow `#174174`, base `#247BCB`, highlight `#84D9F4` |
| Socks | Shadow `#ADA89A`, base `#D6D0BF` |

Try flat matte shading and low-resolution textures. Pixel density comes from the game's world render and texture settings; painting a detailed model and applying a coarse filter is not a substitute for silhouette design.

## Animation and sword considerations

The sword planted beside her works for an idle reference pose. A walking carry pose must keep its tip clear of the ground and keep her visible from the elevated camera. Test a raised one-handed carry and a stowed socket before deciding which fits the model; the greatsword's scale may require a distinct carry override.

Keep the sword mesh independent, with documented socket offsets. An ordinary NPC can reuse the same locomotion without equipment. A two-handed grip or combat motion would be additional animation work.

Her dress is the main deformation risk. Test the front/back hem during a full walk loop before making more outfits from it. Belt accessories should use simple attachments or skinning; avoid physics-driven straps at this stage.

## Game-scale acceptance views

Capture the actual model from the gameplay camera in all four cardinal facing directions, both idle and walking. Test approximately 40–56 pixels of character height at the trial 640 × 360 world resolution, and adjust the camera scale based on readability.

Check foot contact, dress/leg intersections, sword/ground clearance, silhouette separation from vegetation and buildings, and stable hair edges during camera movement. A front/side/back concept board helps modeling but does not replace these elevated engine views.

Preserve the original illustration and save later experiments under new versioned filenames.
