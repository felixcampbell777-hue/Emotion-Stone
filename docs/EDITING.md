v0.31.5 (2026-10-13): Beta gameplay recognizes the ordered MAGICNOW key sequence (four seconds between letters) and grants the existing Everfull Experience Potion. Ownership uses well_gift_stage=potion_owned, so Inventory > Potions, unlimited 1,000 XP drinks and existing save validation remain authoritative. No automatic save, duplicate item, free quest XP or Alpha shortcut. Matched prefix presses protect Inventory I; wrong letters, timeout, focus loss, overlays, new game and load clear progress. Native potion capture includes Beta code reward/inventory; run focused/full source and Windows verification, menus/potion capture, refresh launcher and purge superseded releases.

v0.31.4 (2026-10-13): learning Mana/Water Slash then Flowing Splash permanently unlocks the mana-empowered dash swing. Only an actual queued dash opener arms dash_water_pending. Its existing moving swing gathers hilt-to-tip blue energy over phases .40-.72, then releases exactly one real Water Slash on follow-through (.72), before the .74 normal combo join. The normal return/spin chain stays available. Water Slash damage/range/falloff and CURRENT stamina cost apply; the Flowing Splash stamina discount still requires its passive slot. The Q special remains independent. Insufficient stamina skips the wave with denial feedback and steel restored; damage/focus loss/reset cancel pending energy, and overlays freeze action clocks/projectiles. Actor alone owns pending/release/steel restoration; main rebuilds unlock from learned IDs. No new save fields, input binding, Blender changes or asset downloads. Run focused/full source and Windows verification; inspect native progression mana-dash-attack frames, skills-mana-dash, camera and menus; refresh launcher and purge superseded release.

v0.31.3 (2026-10-13): Dash Reach is a three-rank Form active upgrade requiring Dash; each rank adds 25% to both minimum/charged dash distance (maximum +75%), with unchanged charge timing/cost. Hold T with sword drawn and press left-click or J to queue one opening cut. The actor preloads the existing first-person opening pose during charge/travel, then enters the matching .28 phase at dash exit with explicit .16s body/steel blending; no ready reset. Normal opening damage, swing stamina, real steel rails and further combo links remain authoritative. Actor owns dash_attack_queued/blend and dash_distance_multiplier; main routes mouse/keyboard and rebuilds distance from learned ranks. Pause freezes the queued action, a T release waits for resume, focus loss/damage/reset clear the swing, and insufficient stamina rejects it safely. No new save fields, Blender changes, downloads, immunity or visible arcs. Read FIRST-PERSON-SWORD.md; run verify-beta, source/Windows verification, inspect native progression dash-attack frames and Dash Reach/menu captures, then refresh the launcher and purge superseded releases.

v0.31.2 (2026-10-13): charged Mana/Water Lance adds irregular, escalating yaw/pitch view kicks. follow_camera.gd reads only the actor charge clock, so repeated sword/view sampling is idempotent, pause freezes the motion, and the real beam follows the kicked aim. Mouse look remains available to counter it; saved mouse angles never drift. Release keeps the final aim continuous and settles over the first 38% of recovery; stagger/death/reset remove it. Existing Mana Lance Control now adds 25% kick reduction/rank (three ranks, 75% maximum) alongside its existing 15% shorter charge/rank. main.apply_skill_stats rebuilds actor.lance_stability from learned ranks; no new save fields or equipped slots. Camera strengths live in platform.json follow_camera first_person_lance_yaw/pitch_degrees. Preserve v0.31.1 upright two-hand hold and all source art. Inspect native camera lance-control motion frames/JSON and progression/menus captures; verify source/Windows and purge superseded release.

v0.31.1 (2026-10-13): first-person ready matches the supplied upright two-hand reference: blade above screen right, right palm near guard and left palm near pommel. first_person_motion.json ready and every neutral action endpoint share the new hold. Both hands stay on the hilt through the opener and return cut; linked steel paths, combat clocks/resources and existing body assets remain unchanged. first_person_visuals.gd uses the imported personal palm Y/Z plane and X normal for grip fitting, curls fingers along X/Y while preserving their separation, folds the thumb and rebuilds skin normals. Original faceted palm calibration is preserved. Reference projection and continuous physical hilt contact are checked alongside the 648-phase arm/steel audit. Read FIRST-PERSON-SWORD.md; inspect native first-person camera/action evidence, verify source/Windows, refresh shortcut and purge superseded release. No Blender files or downloads changed.

v0.31.0 (2026-10-12): first-person sword carry is forward-ready with persistent skinned hands, not rear drag. Read docs/FIRST-PERSON-SWORD.md. first_person_motion.json owns camera-space grip/direction paths; first_person_sword.gd places the ACTOR-OWNED real weapon, so steel rails/hits/slam/lance endpoints match the visible blade. first_person_visuals.gd derives a dedicated arm-only rig and fitted/curling grips from current saved skins without editing/exporting Blender. Free armed/unarmed/walk/run/jump/dash hands remain visible; draw/stow/roll/overhead are natural visibility exceptions. One-handed opener, returning two-hand cut, spin/hammer, heavy, thrust charge/slide, water cut/lance, parry and recovery connect to forward ready. Damage/costs/timings/XP/skills/saves stay intact; looking down aims melee and lance in 3D. Parry follows current mouse yaw; committing a held attack faces current view. Hilt aura is actor-parented and scaled/translucent for first person; wind avoids the camera near plane. No rear scraping; source harness/carry remains for sheathing. Existing camera gait/parry attenuation stays intact. Headless arm-volume checks sample 648 phases with steel center/edge rails; palms, joins, live low-rat contact, aim, aura and pause are tested. Only first-person native graphics QA: capture-windows --view camera --art-profile darkwood includes first-person action frames and sheet. Original/personal editable sources are preserved; no downloads/regeneration. Run verify-beta, verify, verify-windows, native camera and menus, refresh launcher and purge superseded releases.

# Low-usage editing recipes

Hero anatomy: read HERO-ART.md. Edit tools/remake_hero.py for the complete Advanced body, fitted rests, weights, clothing and hair. prepare_character_detail.py calls it and regenerates nineteen clips using CURRENT build_character.py movement/IK logic. Do not graft new meshes onto Original rests. actor_quality switches rig, binds and clip library together; Original remains separate. Cache inputs cover every recipe and motion source. Run native hero/combat/menu captures, full verification and actual derived blade/skirt audits before replacing a release.

Advanced world art: environment_art.gd adapts existing map props and stable Menagerie codes; original constructors remain authoritative. Move/place scenery in existing JSON or the standalone builder without exporting Blender. Existing A/B/C/G/F codes retain their collisions and semantics; Advanced supplies fir/sapling/rock/undergrowth surfaces around those anchors. Textures and reusable scans live in assets/environment/polyhaven_cc0; the selected architectural scenes live in quaternius_medieval_village_cc0. Source licences/hashes and current model budgets are in art/environment. prepare_environment.py optimizes a chosen scanned asset; fetch_polyhaven.py fetches only official CC0 data and verifies official hashes. Never execute downloaded scripts. Changing the shared humanoid automatically derives its Advanced mesh once; recolors reuse both models. Native construction and clips are never reconstructed from exports. Run verify-environment and inspect both renderer captures after art changes. Audits use input hashes so future data-only edits skip Blender geometry work.

Monster cores: edit game/content/monster_cores.json for monster classification, drop_rate, generic/variant, conditional variant_chance, boss_bonus and healing_percent. Schema/CLI reject beast profiles and non-guaranteed bosses. Keep saved core IDs stable. monster_cores.gd owns pickups, stacks, percentage healing, saves and quest-lock popup; existing enemy reward callbacks own kill deduplication/XP. Menagerie test grants never award XP. Read MONSTER-CORES.md. No Blender work.

HUD feedback: main.gd builds/layouts bars; hud_feedback.gd owns the denial pulse and health threshold, low_health.gdshader owns edge falloff. actor.stamina_denied is gameplay feedback, not a text toast. Potion recipes use consumable effects in magic_items.json; magic_items.gd owns timers/consumption/save validation. Run verify-magic, native hud/menus captures and full verify-windows; no Blender work.

Magic equipment: edit game/content/magic_items.json (IDs/codes, category, palette, variant, effects and complete-set rules). Never rename saved IDs. Adding an effect requires magic_items.gd and its schema; visible geometry lives in equipment_visuals.gd. Windstep belongs in necklace, and legacy goblin charm fields are migration only. Run verify-magic and verify-goblins; inspect capture-windows --view magic/menus, then verify-windows. All previews/actors use the same native cosmetics; no Blender rebuild.
Menu layout lives in inventory.gd (Inventory categories plus Skills, embedded Level Up and Quests), skill_tree.gd, and pause_menu.gd (graphics and Save/Load). Inventory item cards are presentation only: equipment must continue through magic_items.gd and core consumption through monster_cores.gd. The eight-cell raster icon atlas is assets/ui/inventory/skyrim-inventory-icons-v1.png; keep its 4 x 2 order stable unless icon_for is updated with it. main.gd owns I/P/Escape routing and simulation gating. Run verify-magic, verify-cores, verify and capture-windows --view menus, inspect the inventory's category rail and all top tabs, then verify-windows. No geometry/animation regeneration is required.

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

Then build and inspect. A character definition alone does not spawn the character. Modules include bob/crop/headscarf hair, dress/tunic/workdress clothing, none/greatsword equipment, human/prototype left arms, and boots/bare feet. The new character references `humanoid_v1` and shares its animation resources. See `docs/COMBAT.md` for sword actions and the mother's removable wrap.

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

Keep spawn positions clear of solid props and NPCs. Run `verify` after changes to collision or navigation boundaries. The integration suite has fixtures for the three sample maps; if intentionally removing those sample objects, update the fixture checks to exercise equivalent behaviors.

## Edit a Blender source

Open `art/source/humanoid-v1.blend` in the pinned Blender. Keep bone names, hierarchy, bind pose, scale, animation names, and mesh module names stable for compatible edits. Hide the alternate modules while inspecting the chosen outfit. Animation source names are `idle_loop`, `walk_loop`, and `interact`; Godot's importer strips loop suffixes, and the actor maps those imported names back to the canonical keys.

Save the `.blend`, then run:

```powershell
.\tools\platform.cmd assets
.\tools\platform.cmd verify
.\tools\platform.cmd capture
.\tools\platform.cmd build
```

The asset command detects source changes and exports the saved file without rewriting it. Changing the procedural generator or rig spec regenerates the current precursor in place. `assets --regenerate` explicitly requests a rebuild. Automatic history and Blender backup copies are disabled; retain only the current editable sources.

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

## Follow camera

Tune platform.json `follow_camera` for distance, orbit pitch limits, field of view and follow response. Keep saved camera validation limits in save_store.gd synchronized if changing zoom or pitch ranges. No Blender export is needed. Runtime follow_camera.gd owns orbit/collision; actor.gd maps input and Dodge into camera-relative directions. Middle drag, wheel, V and C leave right-click Parry untouched. Camera-only scenery uses layer 8, excluded from player/enemy/projectile masks. Obstructed views first rise above low scenery, then pull forward; they ease back when clear. Run verify, capture-windows --view camera, inspect village/coast/forest frames, then verify-windows.

Home opening v0.15.0: New Game begins beside the upstairs bed (home_upstairs), with a morning message, then stairs to home_downstairs. Mother's morning farewell choice unlocks the front door; quest acceptance remains separate. Both floors have reusable rustic furnishings, cutaway walls, timber floors and a flickering hearth. Press E at the coastal west cottage door to return home. Mother now lives downstairs; there is no outdoor duplicate. home_intro_complete saves the farewell; legacy saves default true. Verification/capture startup still uses coastal fixtures, never player saves. Run capture-windows --view home and home_checks.gd for wake-up, floor travel, door gating, conversation and save compatibility. Home furnishings/footprints: home_props.gd; map placements: the two home JSON files.

Home v0.16.0: both floors are now 10 x 10m (55% less floor area). Full-height colliding timber/plaster walls enclose the rooms; foreground upper walls cut away only in overhead mode. The upstairs stairwell has an actual floor opening and descending treads, guard rails and collision; downstairs stairs ascend toward the back wall. Stair landings remain automatic travel, but the framed hinged front door uses E to leave, gated by Mother farewell. Saved home_layout 2 marks current coordinates; earlier home saves safely move to the new room spawn with all progress retained. Home positions/captures/fixtures use the compact layout.

Sword recoil v0.16.0: knockback.json owns Small / Medium / Large / Giant profiles and deceleration. Light / strong speeds are 6 / 8, 3.8 / 5.4, 1.7 / 2.8 and 0 / 0 m/s. Giant strong weakspot speed is 2.2 m/s. Slime and both boars are Medium; Warden is Giant. Small (e.g. a future bat) and Large are supported categories; this update adds no new encounter. main._attack_contact uses take_sword_damage; only Heavy and Driving Thrust mark strong. An exposed Warden takes light damage without recoil; armored hits reject damage/recoil. Collision-aware horizontal movement decays to rest, and parry/rock reflection remains independent. Existing Water Cut/Lance behavior and all heroine clips/trajectories remain intact. Run knockback_checks and capture-windows --view knockback.

Combo v0.17.0: opener remains unchanged. The return cut rises from its kneel, cuts back across ahead of the torso and buries the tip outside the right leg at phase .74; the spin starts at that exact grip/tip and matching hip/chest pose. Return/spin momentum is .75/.65, with bounded inherited carry; only forward camera-relative input adds drawn walking speed during spin. Sword damage uses swept rendered steel rails against mob capsules during active windows, with one hit per strike and scenery occlusion; former range/cone values remain compatibility tuning only. Walking skirt sway is .20/.12 radians with a roomier lower hem; tools/audit_walk_skirt.py gates covered leg vertices during both gaits. Inspect perspective walk frames and front/side return/spin sheets in combat captures.

Use tools/platform.cmd verify-combat for quick combo movement, blade contacts, cloth motion and animation continuity checks during iteration. It uses a fresh fixture session and does not save the player journey. It does not replace full verify, Windows verification, or visual combat captures before shipping an animation change.

## Reuse Menagery scenery and creatures

Use codes from docs/MENAGERY.md. Add `{"id":"oak_1","kind":"catalog_feature","catalog_code":"2A","at":[4,-3],"rotation":90,"scale":1.2}` to a map props list. No model regeneration is needed. Four tree silhouettes, rocks/wilderness/path kits reuse the native constructors and cached batches. Catalog metadata and creature tuning live in game/content/menagery.json; keep codes stable. New abilities use menagery_enemy.gd, menagery_hazard.gd and menagery_projectile.gd. Practice defeats remain separate from story/XP. Run validate, verify-windows, capture-windows --view menagery and menus; inspect labels and ability effects.

## Rolling terrain and cave examples

F/G codes are documented in MENAGERY.md. Add terrain through catalog_feature props; rotation/scale affect both rendering and world.ground_height. terrain_kit.gd generates faceted triangles and samples those same triangles for actors; steep faces/edges are blocked instead of adding a jump axis. world.move_grounded handles character/enemy locomotion. Props/NPCs/vegetation and impact/sap roots inherit height. Cave modules live in cave_kit.gd and menagery_cave.json; keep ceiling/foreground-wall cutaway visuals separate from collision. Run verify-terrain for movement/save checks and capture-windows --view terrain for hill/cave renders, then normal verification and cleanup.

