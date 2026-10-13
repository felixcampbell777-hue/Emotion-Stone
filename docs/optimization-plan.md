# Current platform optimization plan

The Windows game is implemented in Godot 4.5.1 with GDScript, using shared Blender 4.5.3 LTS sources and exported GLB models. Gameplay movement stays on the horizontal plane. Faceted 3D supports reusable characters, diagonal movement, lighting and animated clothing; graphics presets include native resolution and reduced pixel modes.

For inexpensive routine edits, change validated definitions under game/content rather than duplicating scripts or characters. Palette and module changes reuse geometry and animations. Balance, placements, quest definitions and skill values remain data-driven. Cache keys distinguish geometry changes from routine content changes.

The humanoid precursor shares 16 bones and 17 clips. Recolor characters through semantic material slots. Shared sword_motion.json drives both Blender hand IK and runtime equipment, keeping body/blade poses synchronized. Regenerate geometry only when generator, rig, source or motion changes require it. Keep one current editable source per asset.

Read AGENTS.md, CURRENT-BASELINE.md, EDITING.md and the affected feature manual before editing. Preserve baseline gameplay and animations. Use validation and relevant integration checks; inspect actual rendered scenes for animation changes. Tests use separate saves.

The sole release selector is game/content/release.json. Play.cmd and the project desktop shortcut read it. After a replacement passes source/export checks and rendered inspection, run tools/clean_obsolete.ps1. Retain only the current release, current editable assets and current verification evidence; automatic source history and Blender backup copies are disabled. Original illustration references remain art references, not alternative game implementations.
