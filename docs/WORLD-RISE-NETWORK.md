# World Rise sessions and portable characters

The desktop client connects to a separately exported Godot 4.5.1 Linux server.
Docker packaging and local administration are documented under `hosting/`.
The server is authoritative; its `wr_actor_bridge.gd` runs the existing Actor,
BetaHero retargeting, first-person frame, weapon contacts, equipment/stat builders,
combat skills and real floor physics. `wr_floor_runtime.gd` runs existing enemy
controllers in a separate physics world per occupied floor. Rendering is hidden,
not used as a substitute for collision.

## Boundaries

`wr_session.gd` owns the ENet peer, authentication, bounded requests, snapshots,
dedicated voice transport, connection lifecycle and local administration. `wr_authority.gd`
owns player/world records, canonical actor bridges, transactions and floor
instances. `wr_store.gd` commits one world/character checkpoint through the
included Python filesystem helper. The packaged Linux server includes that
helper; installed Windows/macOS clients do not require Python.

This transport is for a trusted LAN/private VPN. Ordinary ENet is not encrypted.
Publish both configured UDP ports only through the trusted network; neither
transport provides TLS/DTLS encryption. Voice packets are authenticated, not encrypted.
The client/server prove portable-character ownership using a per-connection
challenge and the owner's RSA key. Password-file configuration fails closed
when the file is missing or empty. The server also checks protocol and content
fingerprints. Object deserialization and direct peer relay are disabled.

Clients submit movement/look and action requests; transforms, damage, equipment
ownership, prices and rewards come from the server. Local menus stop commands
while the real actor remains vulnerable and committed actions continue. The
server preserves the existing contact trajectories and native enemy actions.
Player combat contacts use the approved rig's posed torso and head plus its
existing lower-body capsule. The movement capsule and terrain collision are
unchanged. Melee, live arrows and the bow preview share those combat volumes;
nearest scenery or an enemy still occludes a farther player. All regions apply
the same accepted weapon damage, without a new headshot multiplier.
Online admission, travel and respawn use a bounded search for a position clear
of retained terrain, native enemy solids and other player bodies. Respawn checks
clearance before restoring health or resources; a fully blocked checkpoint
returns an explicit failure and preserves the defeated character's state.
Prediction uses consumed-input and applied-action acknowledgements, not merely
packet receipt.

After the native connection succeeds, both endpoints configure ENet's RTT
reference interval to 1000 ms, throttle acceleration to 32 and deceleration to 2,
before character authentication starts. This retains native congestion decrease
while recovering promptly after RTT jitter. The default 5000/2/2 policy was
measured dropping enough bounded control packets to produce 0.3-second input
expiry; the server accepted every input packet it actually received. Input
expiry remains 0.3 seconds, input requests remain capped at 90 per second and
1 KiB, and snapshots publish at 20 Hz with bounded chunk sizes. Reliable ENet
congestion control and retransmission remain enabled. See the
[Godot 4.5 ENet throttle API](https://docs.godotengine.org/en/4.5/classes/class_enetpacketpeer.html#class-enetpacketpeer-method-throttle-configure).

## Portable checkpoint rules

The private owner key and portable checkpoint live under the client's isolated
`user://world-rise-portable/` directory. Private keys never go to the server.
Characters carry progression, equipment, materials, copper, appearance, active
loadout and resources. A world UUID namespaces floor access, encounters, loot,
visits, discoveries, checkpoints and return positions. Hunt contracts are
world-specific. Personal boss first-victory bonuses follow the character;
shared world victory/floor-unlock flags stay with that world.

The connected server owns the live state. A new server validates an imported
checkpoint's schema, allowlisted content and owner proof. Returning to a previous
server accepts a descendant checkpoint, preserving legitimate A → B → A progress.
Short recent ancestry is bounded; per-world handoff anchors retain prior server
heads across longer visits. An explicit recovery option selects the destination
server's latest durable record when the local copy is stale. Divergent histories
are rejected with an actionable conflict message; equipment is never silently
merged or deleted.

Hashes use canonical numeric JSON so in-memory integers and integral floats
have identical digests. On disk, a versioned JSON envelope contains a checksummed
base64 Godot binary dictionary; floating-point values never pass through JSON
numeric parsing. Both server saves and installed-client checkpoints preserve
float64 bits exactly. Readers bound file/base64/raw sizes before decoding, disable
object decoding, and then apply the existing strict schemas. Character payloads
are limited to 256 KiB and world payloads to 64 MiB; oversized writes fail before
replacing accepted data, retaining pending settlement. Legacy plain-JSON candidate
network checkpoints are rejected and preserved for explicit migration/recovery,
with no automatic backup fallback. Existing ordinary offline saves are unaffected. Each mutation's parent is the actual previously
accepted checkpoint, not the modified proposal. Signatures and receipts establish
ownership/provenance, not legitimately earned progression. With no central
character service, file copying, rollback, simultaneous forks and owner-modified
worlds cannot be prevented globally.

Purchases, recipients, reward claims and encounter settlement commit together.
Before reading or creating world state, the helper acquires an OS-held exclusive
writer lock for that directory and acknowledges ownership to Godot. A second
server sharing the volume fails clearly; process termination releases the lock.
The server flushes the pending file, replaces it atomically, preserves a complete
prior checkpoint and syncs the directory through its trusted local helper. A
failed reward commit freezes further settlement and retains the identical rolled
proposal; saving/exporting cannot persist an unpaid death. Disk errors never
produce successful purchase acknowledgements. The persistent local helper avoids
Python startup on every write; requests use atomic private files and responses
use a pipe. An error or lost acknowledgement freezes writes until explicit
restart reloads disk state, because replacement may already have happened.
Clients install validated pending
files with a prior backup and atomic replacement using native Godot APIs. Client
directory-fsync/power-loss durability is not claimed; the server retains a durable
recovery copy. A failed client installation remains actionable and retryable.

A clean departure keeps the body vulnerable for fifteen gameplay seconds, then
exports the final durable profile. The client acknowledges successful local
installation before the server confirms closure. Accidental disconnects retain
an equally vulnerable body briefly; reconnecting reattaches that existing body
and resets command sequences. Initial join/profile failures never activate or
overwrite an offline session.

## Reviewed operational defaults

- Eight authenticated players maximum, including a local host when used.
- PvP defaults off; both participants must opt in. Disabling requires ten seconds
  out of combat, measured on a monotonic gameplay clock across day rollover.
  PvP grants no XP/copper or farmable personal drops.
- Nearby participating players receive independent XP/copper and personal loot.
  The current eligibility radius is forty metres. Actual damaging contribution
  or being targeted is recorded by the authority; empty-area resets clear it.
- Ordinary encounters reset only when their actual area is empty and unengaged
  for thirty gameplay seconds. One player's rest/death never resets another fight.
- Crystals require personal discovery, nearby source and no nearby active aggro.
  Rest and travel are distinct; Floor Two still requires the Elder world unlock.
- Missed arrows create one physical, atomically claimed pickup. Full stacks leave
  the pickup available. A friendly non-PvP body can physically intercept an arrow
  without damage or recoil, leaving one recoverable arrow. A valid player parry
  also blocks a PvP arrow using the existing Actor contact predicate; this does
  not add reflected damage or a new ranged counter target. Active arrows are bounded to 128. Missed-arrow recovery lasts ninety gameplay
  seconds. Earned personal item loot persists until claimed, with no timed
  expiry. Only the nearest 64 personal item and 32 arrow claims create client presentation
  nodes; other earned claims remain available as nearer claims are collected. Durable records
  can grow with unclaimed loot. Disk failures stop settlement rather than
  discarding promised items.
- Shared time advances during active bodies/sessions and freezes when empty;
  existing 600/480 day/night and 1080-second boss cooldowns are retained.
- Voice uses a separate UDP socket (default game port + 1), ephemeral 256-bit
  session keys, HMAC-SHA256 packet authentication and replay windows. Endpoint
  registration must match the authenticated ENet address. Packets are capped at
  512 bytes, and the relay retains per-peer rate limits and authoritative
  positions: nearby peers on one floor or the separate group channel. No
  recording is enabled by default. Explicit custom ports must be distinct;
  game port 65535 requires a valid separately configured voice port.

These defaults are implementation choices for the authorized systems, not new
weapon prices or balance changes. Server owners remain trusted administrators.

## Verification and remaining acceptance

Use disposable test data through `tools/platform.sh` / `tools/platform.cmd`.
`wr_portability_checks.gd` exercises real durable stores and A → B → A lineage.
`wr_store_lock_checks.gd` and `tools/network/verify_world_lock.py` cover exclusive
ownership, losing-writer safety and recovery after writer/parent crashes.
`wr_checkpoint_checks.gd` rejects malformed world shapes before floor loading.
`wr_store_worker_checks.gd` verifies worker reuse, bounded failure, durable
recovery and warm-commit timing. `wr_transaction_checks.gd` injects settlement failures and tests staged retry,
reward deduplication, day-rollover combat timing and full-stack claim retention.
`tools/verify_network_processes.py` launches separate server/client processes;
it is not a substitute for authored combat, rendering, audio or Internet tests.
Native actor/steel, floor/AI and voice fixtures are maintained by their respective
owners. Record actual results separately; the presence of a fixture is not a pass.

Protocol 3 uses a versioned WRZ1 header, bounded-size Zstandard decompression
and a digest over declared size plus compressed bytes. Raw snapshots are capped
at 2 MiB and transmitted packets at 128 chunks of 900 bytes. Object decoding is
disabled; malformed headers, sizes, payloads and snapshot schemas are rejected.
Snapshots are split into bounded unreliable chunks with stale
assembly rejection. Profile ancestry stays on the checkpoint lane rather than
being sent twenty times per second. Readiness includes measured physics/interval,
commit, serialization/compression and bandwidth counters. Dedicated-server CPU,
uplink, eight-client jitter/loss, voice throughput, shutdown and restore must be
measured on declared hardware. Independent lossless tests covered more than 40,000 timer, resource and random
float samples without a digest change after disk reload. The permanent storage
codec fixture also covers versions, checksums, size bounds and object rejection.
The persistent helper removes Python startup on every write. Current-format
filesystem and encoding costs must be measured on the target host; isolated
commit timings vary and are not an eight-player Docker performance result. Exact bone pose serialization occurs once per network publication, not
every actor simulation step. Synchronous filesystem work can still cause a tick
stall; do not claim a 60 Hz service budget from a parser or pure-unit test.
