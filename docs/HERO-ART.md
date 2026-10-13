# Remade heroine

Current static draft awaits user approval before animation work. The generated hero-detailed.blend and animation-free humanoid-hero-preview.glb reflect the latest realistic, lean proportions, high-waisted denim outfit and shoulder-length hair. The following animation/release description applies to verified v0.23.2, not this unapproved draft. Use `tools/platform.cmd capture --draft --model-only --view hero` for review. art/character/model-review.json is the gate; record approval only from the user.

Advanced uses humanoid-hero-v1.glb for the hero and inventory preview. This is a complete body rebuild from Blender's CC0 GEO-body_female_realistic anatomical mesh. The previous head/hand graft onto primitive body parts has been removed from the recipe. Original humanoid-v1.blend and its separate graphics profile remain intact; NPCs keep their existing rounded shared model.

The early character art guides the chestnut bob, brown eyes, freckles, blue-gray collared dress, rolled cuffs, leather belt and lace-up boots. The requested RPG image guides anatomy and material detail. This remains a custom prototype character, not an acquired finished production character.

The body determines joint placement. The derived rig has new shoulder, elbow, palm, hip, knee, ankle, neck and head rests, retaining the sixteen stable bone names. tools/remake_hero.py regenerates nineteen hero clips using the CURRENT authored phase/body/IK logic from tools/build_character.py and sword_motion.json against those fitted rests. No vendor rig, driver, script or animation is imported. Presentation scale stays .92; standing body/hair height is approximately 1.67m. Do not force this model back onto the Original bone rests or swap only the new mesh.

The fitted skeleton, matching skin binds and retargeted animation library switch together in environment_art.gd. Original switching restores all three together. Actor clocks, combat input, sword trajectories, damage and resource costs remain authoritative. The full body includes both arms; disable the old separate left_arm_human module for this Advanced heroine only.

Retargeted joints use sign-continuous quaternion keys with linear interpolation. This prevents the fitted elbow from taking an Euler detour between solved poses. The fitted draw hand holds the wooden grip behind the guard; draw/sheath and parry recovery use fitted elbow poles outside the blade. Preserve these retargeting adjustments independently of the Original animations.

The blouse follows the body's connected shoulder/arm surface. A separate pleated skirt has weighted secondary motion. Closed rounded boots replace exposed anatomical toe shapes. Curved fine locks, a scalp surface, brows, actual sclera/iris geometry and restrained freckles provide the face/hair details. Palette tint and custom/verified CC0 fabric/leather maps remain available.

Only verified mesh datablocks from Blender's Human Base Meshes CC0 bundle are loaded with automatic Python execution disabled. Bundle hash/licensing and Defender results are recorded under art/character. The official archive is reference data, not executable code. Source: https://www.blender.org/download/demo-files/

prepare_character_detail.py saves art/source/hero-detailed.blend and exports the runtime hero. Edit remake_hero.py for reproducible body/rig/clothing changes; direct derived-source edits are not automatically ingested. Cache keys include the complete remake, animation-author and motion recipes. Unchanged data-only edits reuse geometry/audit caches. No Blender source histories or backup files are created.

hero_surface.gdshaderinc shares cloth, skin, hair, leather and eye shading between gameplay and inventory. The separate hero_preview.gdshader excludes screen-space scattering in the menu viewport to avoid its black-material rendering problem. Equipment recolors preserve the surface shaders.

Run verify-environment, verify, verify-windows and native hero/combat/menu captures. Inspect actual front/side/back, face, forest, equipment, walk, parry, draw, dodge and water/lance views. The actual derived mesh undergoes the full subframe blade-rail audit and its own covered-leg skirt audit. The preliminary --quick audit writes a separate report and cannot satisfy release gates. Player saves remain separate from fixtures. Purge superseded releases only after the replacement passes native checks.

Renderer diagnostic: v0.23.2 Compatibility hero captures render the model and preview, but Godot 4.5.1 logs two 349,524-byte GL texture leaks at process shutdown. Closing inventory before quit did not remove the engine diagnostic. The strict capture command correctly fails; do not report a clean Compatibility pass. Forward+ is the tested default. The diagnostic is retained in art/character/compatibility-render-diagnostic.log; the corresponding native images are diagnostic evidence, not a passed renderer gate.
