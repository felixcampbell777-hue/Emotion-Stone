# World Rise weapons

World Rise retains the three existing greatsword tiers and adds Field Spear, Duelist Rapier and Hunting Bow. Corin sells the new weapons through the ordinary weapons shop on both floors. Current initial costs are 80cp / 100cp / 75cp at level one. Wooden Arrows cost 1cp each, with a 99-arrow stack limit. These are configurable initial values for the new weapons; existing greatsword balance is unchanged.

R draws/stows the equipped weapon. Spear and rapier use the existing primary attack input for dedicated thrusts. Spear has the longest physical melee tip reach; rapier has a shorter, quicker action and more mobile drawn gait. Their contacts sweep the actual steel against enemy capsules and reject scenery-obstructed hits. Right click/F retains timed Parry. Dodge remains vulnerable.

Hold primary attack to draw the bow; release to fire a physical arrow. A small white trajectory line and circle show the first predicted collision. Preview and live flight use the same fixed-step ballistic equations, actual nock/tip socket and collision queries. Eye-to-tip obstruction rejects spawning an arrow beyond nearby scenery. Arrows are finite: a release consumes one, while cancellation consumes none. A missed arrow remains on the ground for nearby E recovery until its bounded pickup lifetime expires. In-flight and recovered ammunition are never duplicated in equipment saves.

## Ownership

- `game/content/world_rise/weapons.json`: explicit new-weapon timing, damage, stamina, movement, dimensions and ballistic tuning. Greatsword's profile is a compatibility adapter.
- `weapon_profiles.gd`: item identity and profile selection.
- `weapon_motion.gd`: deterministic grip, hand and steel trajectories.
- `weapon_models.gd`: original wood/steel/brass weapon meshes and shared bow/nock/tip sockets. No donor model or animation downloads are required.
- `weapon_runtime.gd`: actor-owned action/resources integration, real grips, bounded shoulder protraction without arm-bone scaling, contact and presentation hooks.
- `steel_contact.gd`: shared swept steel versus capsule geometry for native and authoritative combat.
- `arrow_ballistics.gd`, `physical_arrow.gd`, `bow_preview.gd`: flight, finite recovery and presentation.
- `magic_items.gd`, `inventory.gd`, `rise_guild.gd`, `main.gd`, `save_store.gd`: ordinary equipment, shops, interactions and strict saved IDs.

The existing heroine and rig source files are preserved. New poses fit the retained runtime skeleton, with compact grips and shortened rear geometry to avoid camera intrusion; frozen character generation and model-review state are not altered. View and observer palms are checked against actual weapon sockets. Greatsword-only passives and kill requirements do not receive new-weapon kills or apply to the new weapons.

Online clients send primary input edges. The authority derives bow charge from its accepted Actor clock and owns ammunition, projectile creation and damage. Visible clients update bow prediction as presentation only; prediction shadows do not create a duplicate preview.

## Focused verification

Run from the checkout root with pinned Godot 4.5.1 and disposable userdata:

```sh
./tools/platform.sh validate
./tools/platform.sh check-script scripts/weapon_checks.gd
./tools/platform.sh check-script scripts/weapon_game_checks.gd
```

The focused module fixture covers continuous real steel, short targets, steep ballistic pitch, wall/ground impact agreement, blocked muzzle, repeated bow shots, cancellation, carry transitions and camera/observer reentrancy. The actual-game fixture purchases through Corin, attacks actual enemies, checks skinned view and observer palm contact, recovers a physical miss through E, and exercises strict saves, reused-Actor equipment restoration and floor travel. Its optional `--weapon-render` user argument produces actual Advanced first-person and observer frames under `output/weapon-review/native/`; run it through the portable isolated launcher with Forward+ rendering. `weapon_model_capture.gd` provides a separate static model review. These checks do not certify the unrelated broad suite or resolve the documented historical uphill fixture failures.

Latest local acceptance: schema/content validation passed; the focused weapon module fixture passed; actual-game headless checks passed 80 assertions, and the final Advanced Forward+ capture run passed 95 including nine image writes and six checks that active visible weapon geometry stays at least 25 cm ahead of the eye. Both actual-game runs completed with observed audio playback draining and no engine/resource errors. Current images are in `output/weapon-review/native/`. These results cover the new weapons and their integration; online visible preview is additionally exercised by the multiplayer/UI owners.

The final slim spear, smaller rapier pommel and compact bow hand/depth presentation were reviewed and accepted for the initial game style. Weapon art and tuning are frozen pending bug fixes; this acceptance is not a release certification. Player projectile queries use the shared pose-based combat hurt volumes for the visible body and head, select the nearest anatomy/scenery/enemy hit, and exclude the owner. Preview, eye-to-muzzle clearance, live flight and authoritative flight share that query.
