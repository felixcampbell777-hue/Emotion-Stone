# Beta wolf packs — v0.27.0

Two woodland packs contain four wolves each. The existing woodland_wolf_1 and woodland_wolf_2 encounter IDs remain the pack leaders, so old defeated encounters stay defeated. The six new followers have stable individual IDs and the existing permanent-defeat/save/XP rules. Each wolf still has 80 health, deals 12 contact damage and uses Medium recoil. Wolves are beasts and do not drop monster cores.

Each pack patrols a rectangle around its own woodland center, with a loose follower formation and a 5.5m territory radius. Seeing the player within 6.5m through clear scenery alerts that pack. The living wolves move to separate positions on a rotating circle about 3.1m from the player. Waves alternate one and two attackers, with a map-wide limit of two committed windups/lunges. The supplied Attack clip provides the windup and bite; the lunge has a short visible hop. Aim locks for the final .35 seconds of windup, allowing dodges. Contact resolves once, supports natural parry and respects solid scenery. Recovery gives each wolf time before it returns to circling.

The first attack delay is 1.65s; waves are 3.3s apart. Windup lasts .85s, the 7.8m/s leap lasts .50s and recovery lasts 1.5s. These are prototype balance values. Leaving 12m from the territory center, losing sight for 4.5s or player death dismisses the pursuit. Wolves return to their patrol instead of chasing into the meadow indefinitely. Terrain/scenery collision remains authoritative; rotating destinations and separation help avoid crowding. This uses collision sliding rather than a new navigation mesh.

Tuning: game/content/beta.json, wolf_packs; placement/group membership: game/content/maps/beta_meadow.json, enemies[].pack. wolf_packs.gd owns decisions, actor gating freezes its clock, and beta_enemy.gd owns movement, animation, contact and recoil. Menu/title/death simulation gating remains shared. Loading/replacing a map rebuilds the director; dead wolves are excluded. Patrol/circle phase is transient rather than new save data.

## Art and provenance

The already collected/scanned local Quaternius wolf is the donor: art/library/source/quaternius-animals/glTF/Wolf.gltf. No new download was needed. The rig and all twelve supplied clips remain; Walk is used on patrol and ordinary circling, Gallop during faster travel. The derived coat has welded/subdivided smooth geometry, original deterministic albedo/normal/roughness maps and weighted narrow fur tufts. They use alpha scissor and fixed skin weights, without expensive strand simulation. Per-wolf tints and injury/parry flashes are local materials. It is an improved stylized woodland wolf, not a scanned animal.

Editable source: art/source/beta-wolf.blend. Runtime: game/assets/creatures/beta-wolf.glb. Recipe tools/build_beta_wolf.py initially derives from the donor; do not use it to export manual source edits. tools/export_beta_wolf.py reopens the saved derived source for export and refreshes hashes. tools/make_wolf_fur_textures.py creates the original CC0 maps. The legacy donor CC0 notice/current Quaternius license remain in art/library; the adapted model is embedded in the game, not distributed as a standalone source kit. art/library/beta-wolf-customization.json records source/export/donor hashes and budgets. No downloaded scripts are executed.

## Verification

Run platform validate, verify-beta, verify and verify-windows. wolf_pack_checks.gd exercises patrol bounds, shared detection, ring separation/rotation, actual single/pair waves/leaps, global attacker limit, scenery occlusion, one-hit contact, natural parry, leash, dead members, paused clocks and skinned textured materials. Existing Beta rat/slime/camera/save checks remain.

Inspect capture-windows --view beta: wolves-patrol, wolves-circle, wolves-single/pair-windup/leap and beta_wolf closeup/attack. wolves-capture.json records actual simulated states and lift at each native capture. The existing combat/motion evidence remains required after animation-related changes. Tests use fixture saves; neither player save is written.
