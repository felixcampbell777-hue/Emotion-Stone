# Native server floor runtime

The multiplayer authority uses `game/scripts/network/wr_floor_runtime.gd` for live
floor collision and enemy controllers. Each occupied floor has a separate
`SubViewport` / `World3D`; source floor construction retains terrain triangles,
guild collision, trees, western islands and bridges, raft, cave and Vault shell.
A single player's travel cannot free another floor. Departure detaches that character from all floor registries before its owned Actor is freed; committed enemy contacts are canceled and projectiles bound to that departing character are removed instead of switching targets. Visuals are hidden on the
server; physics bodies remain. The data adapter is for encounter definitions and
candidate validation, and its sampled fallback is not a replacement for live
physics collision.

The runtime invokes the existing wolf, boar, twin, Ashfang, Elder and slime
controllers, preserving their attack states and telegraphs. It selects a living
player on the same floor when an enemy is free and retains that player through a
committed action. Pack decisions select targets per pack; actual pack coordination
and boar turn rules are shared with offline play. Projectiles bind their target at
creation so advancing another pack cannot redirect a flying stone to another
player. Elder strikes and sticky puddles apply their existing geometry to every
eligible player body. Production sessions use the actual playable Actor through `wr_actor_bridge.gd`; lightweight matching-capsule proxies remain only for isolated runtime fixtures. Native action state has a safe scalar/vector capture/restore interface for server checkpoints. A restored attack whose saved participant is absent enters recovery rather than striking a different character.

Online menus never stop this runtime. Client overlays block only the player's
commands; their authoritative body remains vulnerable. Offline menu behavior is
unchanged. The client consumes acknowledged native enemy state through
`worldrise.apply_authoritative_enemies()` and disables local enemy simulation and
reward mutation.

Ordinary encounters may reset after **30 gameplay seconds** with their area empty.
The area is the authored pack leash or enemy aggro distance, at least 18m, plus
12m. A connected player in that area prevents resetting, including when a different
player rests or dies. Busy attacks against a nearby living participant also block
reset. Each accepted reset advances the encounter generation for reward identity.
Bosses never use this reset path; the authority owns their existing 1080-second
cooldowns and Ashfang's night gate. These online defaults do not change offline
local rest/death resets.

Nearby participating players use the authority's 40m reward radius, personal XP
and independently rolled personal loot. Guild rolls reuse the offline tables,
including exact Floor Two split rewards and no core drops. The portable profile
holds personal boss bonus claims; server visitor state holds guild contracts.

Wooden arrows cost **1 copper each**, bought singly or in tens from Corin. The
finite stack cap is 99. Initial level-one Corin recipes sell Field Spear for 80cp, Duelist Rapier for 100cp and Hunting Bow for 75cp, without materials. These initial acquisition defaults are explicit because
the planning document did not fix prices. Server transactions validate the actual
vendor interaction position within 4m, item stack, recipe floor, Elder access,
level, materials and purse before one durable commit. Rejected requests leave all
balances unchanged. Recovered arrows use the ammunition stack; online recovery
claims remain server-owned and single-use.

Focused executable checks:

- `wr_native_effect_view_checks.gd`: actual native projectile/hazard visuals are passive, reuse nodes, never apply local damage/sticky states, and clear after server removal.
- `wr_floor_lifecycle_checks.gd`: detach-before-free, late freed/queued actors, committed target cleanup and bound-effect cancellation. The independent real same-session server A → fresh B → A probe additionally verifies clean exports and rejoin without freed-reference errors.
- `wr_world_adapter_checks.gd`: authored identities, both floors, boss rewards and
  cooldowns, exact slime splits/coins and obstacle sampling.
- `wr_floor_runtime_checks.gd`: actual collision worlds, simultaneous distinct
  floors, native enemy damage/targets, occupied/empty reset behavior and multi-body
  Elder slam contact.
- `wr_native_session_checks.gd`: 39 checks passed with the lossless network Store: production Authority, canonical Actor bridges and partial native checkpoints across distinct floors, personal kill settlement and loot claims, protected/empty encounters, shared Vault, boss cooldown and restart. Reopen checks release the prior writer first; a deterministic legitimate loot roll prevents random no-drop outcomes from bypassing claim persistence coverage.
- `wr_economy_checks.gd`: finite purchase cost/count, rejected stack/distance
  requests, accepted hunt progression and duplicate turn-in denial.

Run these through the portable tooling or pinned Godot with disposable user data.
They do not certify exported clients, eight-client load, Internet latency, full
combat parity, microphone behavior or the historical uphill fixture failures.
