# Reference-led heroine rebuild: research and implementation specification

Superseding decision (2026-10-10): the procedural static draft was rejected and modeling stopped. Read HERO-ASSET-SHORTLIST.md for the new asset-selection research. The construction recommendation below is historical and does not authorize another procedural rebuild. No model/animation work is currently authorized; static-model approval remains required before animation fitting.

Research date: 2026-10-10. This is a design specification, not a completed model update. The playable release remains v0.23.2. The latest user turnaround is authoritative for identity and proportions: `art/reference/hero-proportion-target.png`. The earlier RPG screenshot establishes material/detail ambition, not a replacement costume. Subsequent user directions below supersede earlier proportion assumptions.

Subsequent user clarification: `art/reference/hero-clothing-proportions-texture-target.png` now guides CLOTHING FIT, BODY PROPORTIONS and TEXTURE FINISH. Retain the original denim dress and high-waisted brown belt; do not import the pictured black cape/outfit or its ponytail. Hair must be shoulder-length chestnut hair. This overrides earlier short-bob/whole-proportion instructions wherever they conflict. Read the current character-art-direction.md before continuing. Static modeling has resumed. Latest direction explicitly requests comparable realistic human proportions and a lean, strong build without bulk. The static model must be shown and approved BEFORE animation fitting. Read art/character/model-review.json; tools/platform.cmd capture --draft --model-only --view hero creates an animation-free review. Do not regenerate clips, build or publish until explicit approval. No replacement Windows release has been built.

## Recommendation

Create a custom stylized character in Blender, starting with a coherent whole-body shape study, then fit the skeleton and retarget the current combat. Use the verified CC0 anatomical mesh as optional topology scaffolding, not as the final appearance. Rebuild the face, hair, clothing silhouette and boots deliberately from the reference. Higher texture resolution or uniform scale cannot repair these design differences.

Blender remains suitable. Godot remains suitable for the runtime. An engine migration would not correct the character's proportions or resemblance. The strongest evidence for the authoring workflow is Blender Studio's character-development material: whole-body and head sculpting, outfit construction, expression testing, clean topology and visual turntables. Its course primarily addresses film topology, so its mesh density and subdivision assumptions must be adapted for a game.

## Findings from the current project

Inspection of the native v0.23.2 front render and `tools/remake_hero.py` identifies four concrete problems:

- The donor face is substantially unmodified. Small donor-position eyes, a realistic nose/jaw and added freckles do not reproduce the illustrated identity.
- Hair is a scalp plus 88 thin, similar strands and 22 loose curves. This creates a straight, sparse fringe instead of the reference's layered, broad, tousled bob.
- Boot geometry consists of smoothed elliptical rings. Long rounded toe volumes and tall shafts produce a bulky silhouette without the reference's distinct sole, toe box, tongue and folded sock cuff.
- Body, skirt, boots, eyes and hair use independently hard-coded dimensions. Changing height or the skeleton alone does not change these parts coherently. The blouse also closely follows the donor's bust rather than the loose shirt construction in the reference.

The animation/export infrastructure is valuable and should be retained: fitted rests, matching skin binds, nineteen current clips, sign-continuous quaternion keys, authored sword paths, actual mesh clearance audits, menu previews and the separate Original profile.

## Alternatives evaluated

| Approach | Fit for this character | Decision |
| --- | --- | --- |
| Increase texture size/subdivide the current model | Improves surface detail while preserving the wrong silhouette and face | Insufficient |
| Import another finished free character | May improve craftsmanship, but its identity, outfit, proportions and rig still require adaptation | Use only if a genuinely close, licensed asset is found |
| Customize the trusted anatomical base | Saves some topology work; requires substantial head/body reshaping and new clothing/hair/boots | Recommended where topology remains useful |
| Build a bespoke head/body mesh or sculpt and retopologize | Highest control over resemblance and deformation; more upfront modeling work | Preferred for the head and any incompatible body region |
| Image-to-3D service | Can provide a draft from multiple views; resemblance, hidden surfaces, equipment separation and current combat compatibility still need inspection | Optional experiment, not the authoritative production route |

Meshy's official API supports multiple input images. That establishes availability, not a demonstrated match to this reference. No service was used, no images were uploaded and no generated mesh was benchmarked in this research. Its actual quality for this character remains untested.

## Construction sequence and visual gates

1. Establish consistent front, side and back comparison cameras. Measure crown, chin, shoulders, waist, skirt hem, knee, ankle and sole relative to total height. Treat the drawn views as artistic references, not perfectly calibrated orthographic scans. Use their shared proportions and check the large three-quarter image for facial character. Do not infer a fixed age or physical height from the drawing.
2. Build an untextured whole-body shape study with the costume and hair masses. The reference calls for a larger head relative to the body, soft cheek volume, narrow shoulders, a fuller bob, loose blouse, defined belted waist, pleated knee-length skirt and compact boots. Reshape the entire lower body and outfit together; do not simply shorten the shin or uniformly shrink the character. Inspect front/side/back silhouettes before polishing or retargeting.
3. Model the face specifically: large brown almond-shaped eyes with proper lid coverage, distinct upper lids, subtle brows, soft cheeks, a small nose, short tapered chin and a restrained mouth. Match spacing, profile and expression. Avoid exposed round eyeballs and a generic adult donor face. Add freckles after the facial shapes work. Keep useful eye/mouth loops for deformation and possible future expressions.
4. Model hair as layered, overlapping sculpted locks with varied width, taper, curved profiles and controlled asymmetry. Establish crown, parting, broken fringe, side locks and neck-length ends first. Blender curves with custom cross-sections are a practical authoring tool; convert the result to exportable meshes. Restrict fine strands to silhouette accents. Keep the existing secondary-motion system initially; add controls only where visible testing justifies them.
5. Rebuild the boots with separate sole, compact toe/vamp, ankle, tongue, laces and folded socks. Construct blouse folds and major skirt pleats in geometry where they affect the silhouette. Use normal/roughness maps for fine fabric/leather detail. Match the reference's shapes while retaining believable lighting and material response.
6. Fit shoulder, elbow, palm, pelvis, knee, ankle, neck and head rests to the established body. Regenerate the current nineteen clips against those rests. Preserve combat clocks and phase timing. Audit grips, foot plants, dress coverage, equipment sockets and sword clearance in motion; correct affected authored poses or contact targets where necessary. A proportion change cannot be assumed to preserve blade clearance.
7. Bake fine sculpt detail to tangent-space normal maps on a practical game mesh. Use custom face/hair color maps where needed and the verified CC0 cloth/leather maps where appropriate. Texture resolution and triangle budgets should follow close-up gameplay and inventory captures, not tree texture dimensions. Do not bake fixed scene lighting into skin or clothes.
8. Inspect actual Godot gameplay and inventory renders, including walking, draw/sheath, parry, all combo stages, dodge, both water attacks and equipped armor. Complete geometry audits and source/Windows verification, then replace the release and purge superseded exports. Preserve Original and player saves.

Visual gates establish resemblance before integration, rather than treating a technically passing build as evidence of artistic success. Automated tests cannot establish likeness. The next deliverable should be actual front/side/back shape renders and a face close-up, not another texture-only release.

## Lower-cost future edits

Centralize meaningful design controls: body landmarks, head/eye/cheek proportions, skirt rings and pleats, shoe dimensions and explicit authored hair lock controls. Derive clothing and rig anchors from the same landmarks. Keep color/material parameters separate from geometry so recolors remain inexpensive.

The current `hero-detailed.blend` is generated and overwritten by the recipe. If the rebuild introduces hand-authored meshes, shape keys or curve guides, store them as a distinct canonical design input under `art/source/` and make the build read it. Never silently overwrite that input. Keep only one current design source, its generated runtime output and current visual evidence, alongside the deliberately preserved Original source.

Retain hash-based geometry/audit caching. Run inexpensive shape previews during modeling and the full release tests once the design is stable. Preserve the current runtime shader/preview sharing and stable material semantics. No downloaded add-ons are required for the proposed Blender workflow.

## Licensing and download handling

The existing official Blender base-mesh bundle is CC0 and already has recorded hashes/intake scans. Its licence does not extend automatically to every Blender Studio character or lesson asset; check any new asset individually. Prefer the trusted local bundle and built-in Blender tools. If new assets are needed, obtain them from official publishers, verify licences/hashes, scan locally and load only needed data with automatic script execution disabled. Antivirus checks reduce risk; they cannot prove an asset is absolutely malware-free. No new executable, plug-in or asset download occurred during this research.

## Primary sources

- [Blender Studio: Stylized Character Workflow](https://studio.blender.org/training/stylized-character-workflow/) — design, sculpting, expression tests, body/outfit/hair topology and turntables.
- [Blender Studio: Rain retopology](https://studio.blender.org/training/stylized-character-workflow/5d52987f1afa2dafe69820c9/) — full-body-first construction, clothing topology and modeled large folds.
- [Blender Studio: workflow introduction](https://studio.blender.org/training/stylized-character-workflow/5d3a1a214bc3ff1bb9513d30/) — author explains differences between film and game topology, baked details and texture packing.
- [Blender 4.5: remeshing and retopology](https://docs.blender.org/manual/en/4.5/modeling/meshes/retopology.html) — automatic remeshing typically does not produce suitable animation topology.
- [Blender 4.5: Curve to Mesh](https://docs.blender.org/manual/en/4.5/modeling/geometry_nodes/curve/operations/curve_to_mesh.html) — custom profiles and per-point scale for authored lock geometry.
- [Blender 4.5: render baking](https://docs.blender.org/UATEST/manual/en/4.5/render/cycles/baking.html) — high-to-low baking and tangent-space normals for animated meshes.
- [Godot: skeleton retargeting](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html) — bone names alone are insufficient; rests, transforms and movement scale matter.
- [Godot: available 3D formats](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html) — recommended glTF/GLB pipeline and Blender integration.
- [Blender: official demo and asset bundles](https://www.blender.org/download/demo-files/) — CC0 human base meshes; other assets carry individual licences.
- [Meshy: multi-image-to-3D API](https://docs.meshy.ai/en/api/multi-image-to-3d) — alternative draft-generation capability, not a validated quality result.

Some direct Blender manual fetches failed. Relevant indexed official documentation was available through search; no inaccessible video was treated as watched, and no course model was imported.
