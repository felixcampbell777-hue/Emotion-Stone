# The Veiled Vault — World Rise Floor One

The empty boss chamber is reached from a hidden cave at (-168,-125) in northwest Elderwood, opposite the southeast guild. A small cleared threshold at the base of the existing forest hill keeps the approach walkable. Existing surrounding forest remains. Press E at the cave mouth to enter; the same control at the arrival arch returns to the forest. No boss is chosen or spawned by this update.

Route: Elderwood hillside → recessed rock mouth and blue crystal → area transition → 6m-wide arrival shelf → 46m by 50m fighting island. The shelf is the only narrow stretch; the island is open for the eventual boss encounter. Return via the arrival arch. No additional enemies, pickups or quest requirements are added.

The island floats above an actual gravity fall. It tapers to a rock underside; there are no edge colliders or invisible railings. Falling below -24m kills through normal hurt invulnerability, returning to the player's existing Floor One rest crystal. Jump, attack momentum and ordinary movement can all carry the player off the edge. XP, equipment and economy follow existing death rules.

A continuous 114m-wide cavern shell encloses the gulf, with a sloped roof from approximately 27m centrally to 9m at the sides. Opaque double-sided rock meshes and matching collision use the existing licensed rock-face texture. Fourteen blue wall-crystal clusters provide actual point lights; sunlight is disabled. Blue atmospheric fog and three translucent mist layers obscure the lower void. These effects use no external downloads. Outdoor lighting is restored on return.

`game/scripts/rise_chamber.gd` owns cave construction, chamber geometry, movement, edge checks and lighting. `wr_boss_chamber.json` is the separate map; `world_rise.gd` owns travel integration. Floor terrain is unchanged except the small cave threshold in `rise_shape.gd`, with trees cleared inside 10m. Mode/save validation accepts the chamber; invalid saved chamber positions return to its arrival shelf. Cave travel preserves streamed Floor One enemy state.

Verification: `tools/platform.cmd verify-world-rise`, `verify-windows --suite world-rise`; native `capture-windows --view boss-chamber --renderer forward_plus --art-profile darkwood`. The focused suite covers physical cave approach, empty chamber entry, continuous shell, real crystal lighting/fog, traversing the shelf, private save/load, return lighting, lethal falling and rest-crystal respawn. Player saves remain untouched. Native frames cover exterior, arrival, arena, ceiling, edge and return.

Related repair: the earlier hit-flash update connected to a player `damaged` signal that did not exist. Actor now declares and emits it only after accepted damage, using actual HP lost after defense. This fixes startup and makes the existing flash respond to real hits.
