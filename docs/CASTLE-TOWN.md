# Beta castle town — v0.29.0

Follow the road east from the meadow spawn, through the open western gate. The continuous Beta map now includes a walled town with four corner towers, nine two-storey houses, a market square with striped stalls, a well and benches, and a northern castle courtyard and keep. Streets and the five-metre gate are walkable; house and keep interiors are closed scenery for now. Road and courtyard signs explain the route.

Layout: game/content/maps/beta_meadow.json. Modular walls/towers/gate/keep/stalls: game/scripts/castle_kit.gd. Existing Props house templates provide the homes. Castle surfaces use already verified CC0 Quaternius brick and roof assets and Poly Haven timber maps; no downloads or new executable assets. Native roof colliders use camera layer 8; solid walls and buildings use scenery layer 1.

Original meadow spawn, forest encounter IDs, both wolf patrol territories, combat, heroine and sword sources remain intact. Expanded bounds preserve existing Beta save positions. A new private-save test restores a market street position; navigation checks exercise actual movement through the gate and blocking at the outer wall. Alpha maps are unchanged.

Run tools/platform.cmd verify-beta, verify, verify-windows and capture-windows --view beta. Inspect castle-town-overview, gate, market, keep and street-first-person. Standard camera/combat/menu evidence remains required before cleanup. The castle capture changes only its fixture camera; gameplay camera settings are unchanged.
