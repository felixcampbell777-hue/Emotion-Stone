# World Rise development roadmap

Prepared October 18, 2026 against `codex/world-rise-handoff`, commit `06f9372`, gameplay v0.41.4. **Historical planning snapshot.** This roadmap originally authorized planning only; the human subsequently authorized implementing its scope and the companion tree. The original proposals below remain historical, not proof of implementation, final tuning or verification. Current behavior, reviewable defaults and acceptance limits are recorded in the [implementation status](WORLD-RISE-IMPLEMENTATION-STATUS.md), [integration contract](WORLD-RISE-INTEGRATION-CONTRACT.md) and newest [baseline entry](CURRENT-BASELINE.md). The companion [agent task tree](WORLD-RISE-AGENT-TREE.md) contains assignments, dependencies and dispatch instructions.

Repair first-person locomotion and swings first, establish shared weapon and simulation interfaces, then develop weapons, appearance and audio alongside an early dedicated-server prototype. Integrate multiplayer continuously: leaving it until the end would require reworking combat, saves, floor streaming and nearly every interaction.

## Requested scope and decisions

| Area | Direction |
| --- | --- |
| Weapons | Add bow, spear and rapier, with first-person and observer-visible animations. Bow fires physical arrows with a small white trajectory line and impact circle. Spear has the longest melee reach. Rapier emphasizes quick thrusts and agility. |
| Animation repairs | Diagnose and correct uncontrolled running-hand movement and unsatisfactory swings. Preserve visible steel matching real contacts. |
| Multiplayer | User-owned Linux Docker dedicated servers, 2–8 friends, cooperative persistent world and opt-in PvP. |
| Appearance | Accessible during play; face, hair, skin tone, body options and colors. No stat resets, renaming or voice selection in this screen. |
| Audio | Complete World Rise sound coverage and reusable shared infrastructure, plus in-game voice. Preserve other modes; their full content-specific sound pass is not silently included. |
| Assets | Open-license models, skins, animations and sound are allowed. Quality, style, redistribution rights and compatibility must be checked. |
| Agents | GPT-6.1-sol, medium reasoning, for research and future coding. Lead coordinates design, ownership, review and acceptance. |

The user also confirmed the following decisions during planning:

| Decision | Accepted direction |
| --- | --- |
| Multiplayer character ownership | The same character and equipment travel between servers, like Valheim. Progression, inventory, copper and appearance belong to the portable character; each connected server controls the live session. Existing offline saves remain untouched. |
| Voice channels | Push-to-talk proximity voice plus a separate group channel. |
| Online menus and appearance | World continues; local controls stop and the character remains vulnerable. Appearance opens anywhere. Offline overlays retain their existing pause behavior. |
| Player platforms | Windows and macOS clients; Linux x86_64 Docker server initially. Linux desktop and ARM64 servers need separate export/dependency verification if added. |
| Bow ammunition | Finite arrows bought from vendors; missed arrows can be recovered. |
| Cooperative rewards | Nearby participating players each receive XP and their own loot. |
| Multiplayer encounter resets | Rest/death never reset another player's fight. Reset an encounter only when its area is empty and nobody is fighting it. |

Detailed tuning remains for later review: weapon acquisition/prices/levels and arrow prices; bow defense; weapon-specific skill applicability; participation distance/contribution; reset delay; disconnect protection; PvP toggle timing; Vault participation; and whether personal first-kill claims travel globally. Concrete defaults appear below. These details do not prevent completing the plan; dependent coding packets must resolve them before changing gameplay.

## What the current code changes about the plan

| Finding | Consequence |
| --- | --- |
| `main.gd` owns one player, one current map, one enemy collection and one economy; `load_map()` destroys the previous world. | Multiplayer requires concurrent world instances and player state separation, not just adding RPCs. |
| `input_enabled` currently freezes simulation and also prevents damage. | Online UI must use a different control gate. Otherwise opening a menu becomes immunity or pauses everyone. |
| Actor actions, weapon geometry, grips, stat application and kill attribution assume a greatsword. | A shared weapon profile and damage-source contract must precede the three weapon implementations. |
| First-person steel is real gameplay geometry, driven partly through the camera. | Animation polish changes combat contacts. The server must reproduce those trajectories without a camera or rendered skeleton. |
| Running hands use elapsed clock multiplied by a changing gait rate. | Sprint transitions can change phase abruptly; this is a strong code hypothesis, not a reproduced diagnosis. |
| The active heroine uses a separate imported skin and generated first-person arm mesh. | Editing canonical palette data alone will not implement customization. Both render paths need the same appearance adapter. |
| Current export recipes disable appearance morph export; grip code assumes particular morph indexes. | Face/body morphs require deliberate asset work and named channels that coexist with gripping. |
| No playback code, audio assets or bus layout were found in the inspected runtime. | Sound needs a complete system and content pass. This was code inspection, not an audible runtime test. |
| Some important GLB and Blender files are still LFS pointers here. | Finish LFS materialization before importing, previewing, rig validation or recording a baseline. No assets were downloaded in this planning pass. |
| Existing bootstrap/validation tooling assumes Windows paths and executables. | Add a portable implementation/testing route and actual Linux server export while preserving `platform.cmd` as the Windows entry point. |

The existing handoff reports 64 passing packaged swamp checks and three unresolved broader Windows uphill-physics failures. These are historical baseline results, not checks run for this roadmap. Diagnose the failures before claiming the entire suite passes.

## Delivery sequence and milestone gates

1. **Establish a usable baseline.** Materialize assets, confirm pinned Godot 4.5.1 and Blender 4.5.3 LTS where needed, establish platform tooling, capture the reported motion faults and classify the known slope failures.
2. **Repair motion and agree interfaces.** Fix reproduced gait/swing problems in small changes. Define weapon/action/contact IDs, input commands, simulation authority, appearance profiles and presentation events. Run small headless-combat and voice compatibility experiments early.
3. **Deliver playable slices.** Greatsword remains equivalent under the shared weapon layer. Add spear, rapier and bow in that order; introduce the first complete sound slice and an appearance editor using the default model. A separate server with two clients must already run movement and combat during this stage.
4. **Complete cooperative persistence.** Concurrent floors, multi-target AI, reward transactions, reconnects and saved encounters work together. Add approved PvP and voice rules; complete reviewed art variants and audio coverage.
5. **Accept the complete release.** Eight-client Internet-condition testing, real microphone tests, backup/restore, container lifecycle, exported client visuals and regressions. Publish only after implementation is authorized and acceptance succeeds.

The largest uncertainty is multiplayer combat and world separation. Estimate delivery dates after the two networking spikes, actual asset inspection and motion reproduction; the task tree is an execution order, not a fixed schedule. Do not parallelize work by allowing several agents to edit `main.gd`, `actor.gd` or save handling at once.

## First-person animation repairs

Reproduce sheathed/unarmed and drawn movement independently. Capture real input sequences: idle → walk → sprint → stop; strafe/diagonal and turn; sharp pitch changes; uphill/downhill; sprint → draw/parry/attack; focus loss; menu entry. Repeat gait transitions near session times 0, 60 and 600 seconds, and at representative capped frame rates. Stable pose screenshots alone miss timing faults.

`unarmed_hands.gd` computes `sin(clock * rate)` while blending rate from walk to sprint. A continuously integrated gait phase, advanced once per simulation update, is the leading repair candidate. Repeated rendering or pose sampling must not advance it. Test resets, pausing and interrupted motion explicitly. Drawn idle sway has a similar abrupt rate switch, but its amplitude is small and may not explain the larger complaint.

For swings, isolate weapon trajectory, camera movement, shoulder/arm fitting and wrist orientation before changing them. Per-key smoothstep interpolation produces zero velocity at each key; camera sampling also includes authored body/head movement during attacks. Either could contribute to the observed feel. Revise only the demonstrated cause, then inspect actual moving sequences and contact timing.

Retain forward two-hand greatsword ready, continuous grips and combo joins, outside-body parry routing, actor-owned action clocks/resources/glow and steel restoration after water attacks. Preserve the current no-roll-immunity rule. Existing grip checks include wrist bend below 38 degrees, skinned grip gap below 18 mm and bounded adjacent pose rotation; retain them while adding transition coverage. Numerical checks complement visual approval.

## Shared weapons and the three new types

A weapon profile should define stable type/item IDs, supported actions, grip/carry/nock sockets, damaging segments, timings/costs, motion samples, projectile configuration and applicable effects. Keep current greatsword data and behavior as the first adapter. Actor simulation owns action time, resources and interrupts; presentation consumes that state. A pure pose/contact sampler must be usable by offline play, local first-person views, remote characters and the headless authority. Verify equivalence of blade base, tip, transverse basis/width, ground fitting and world transform across pitch/yaw, compressed rush timing, combo joins and moving/sloped terrain. Matching grip and tip positions alone is insufficient.

Use one active weapon through the current inventory for the first release. A hotbar, dual wielding, spear throwing, shield system and three new skill trees are additional scope. Preserve existing skill ranks and tree version 4. General passives continue to apply; agree an explicit applicability table for Greatsword-specific bonuses rather than accidentally granting them to arrows or silently removing learned effects. Only confirmed greatsword kills increment `greatsword_kills`.

| Weapon | Planned behavior and animation set | Acceptance distinction |
| --- | --- | --- |
| Spear | Forward ready; draw/stow; spaced two-hand grips; long straight thrust; stronger committed thrust; recovery, parry, locomotion and hurt/death transitions. | Longest actual melee contact reach across all supported equipment/scales, including existing greatswords. Shaft is not automatically damaging steel. Walls and close targets still matter. |
| Rapier | One-hand guard with free-hand pose; quick thrust sequence; committed thrust; parry; short recoveries; responsive transitions into existing legal dodges. | Faster attack/recovery feel than greatsword, shorter reach than spear. Agility must not introduce invulnerability, free cancels or evade stamina rules. |
| Bow | Carry/equip; nock; draw; held aim; release and recoil; reload; canceled draw; movement, hurt and death transitions. Separate bow-hand and string-hand targets. | Physical arrows, bounded flight and collision, accurate preview, exact ammo/cost accounting, readable remote release. |

Retain existing key meanings where applicable: R draw/stow, left click attack, right click/F defense, T Dash, Shift/Ctrl dodge and Space jump. Bow left hold draws and release fires; focus loss or UI entry cancels an uncommitted shot. **Proposed bow defense:** right click/F safely cancels the draw into an authored defensive action; exact parry capability must be approved before coding, not silently rebound to aim. Damage, stamina, rate, reach, recoil and prices need reviewed tuning values rather than arbitrary numbers in agent prompts.

**Bow aiming:** show a short, thin white trajectory line and a small white circle at the first predicted collision. A subtle outline keeps white legible in bright scenes. During draw, update from the same projectile specification used for live flight: nock position, draw strength, initial speed, gravity, segment collision, maximum range and lifetime. The prediction has no target-lock or through-wall information. For a flight with no collision within the limit, use a clearly distinct range endpoint rather than claiming a guaranteed hit.

Resolve screen aim through the camera, then launch from the real bow/nock socket. Check the near-wall path so looking over cover cannot spawn an arrow on its far side. Sweep each flight segment to prevent tunneling. Account for low targets, steep aim, raft/bridge collisions and floor travel. A moving target can leave the predicted point; the circle describes the current trajectory, not a promise of damage.

**Accepted ammunition economy:** finite inventory arrows bought from vendors, consumed once on accepted release; missed arrows can be recovered. A stopped recoverable arrow becomes one server-owned pickup with a unique claim ID, so replayed requests cannot duplicate ammunition. Bound active projectiles and pickups; decide recovery ownership, lifetime, inaccessible-water behavior, starter supply, price and draw-strength effects before the bow packet. Canceled or denied releases consume no arrow. Never add a hidden infinite-ammo rule to normal gameplay for test convenience.

Each weapon slice must use normal equipment/save paths and cover sprint-to-equip/attack, held-input cancellation, damage interruption, pause/focus loss, death, equipment change, floor travel, low targets and steep pitch. Compare local and observer poses and server/client contacts, including parry. Bow release uses accepted aim and an authoritative release tick; reconcile predicted arrows against that identity. Test static preview agreement separately from moving-target prediction error.

Save stable inventory/equipped IDs and bounded ammo counts. Old saves default to their current greatsword; validate supplied IDs strictly. Transient draw state and flying projectiles do not get resurrected by ordinary character loading. Server restart policy for live projectiles is handled explicitly by world persistence.

## Multiplayer architecture and player rules

Use an authoritative Godot 4.5.1 Linux headless simulation, with Godot ENet/UDP transport as the initial candidate. Clients send input and interaction requests; the server validates and resolves them. Godot provides RPC and replication primitives, but movement prediction, combat validation and persistence are project work. See [Godot multiplayer](https://docs.godotengine.org/en/4.5/tutorials/networking/high_level_multiplayer.html).

| Server owns | Client owns |
| --- | --- |
| Movement/collision, stamina, action clocks, damage/parry, PvP eligibility and projectiles | Input collection, immediate predicted motion/presentation and reconciliation |
| AI targets, hazards, encounters, bosses, day/night and world lifecycle | Camera, first-person arms, interpolation of remote actors and visual/audio effects |
| Inventory, purchases, loot, XP, skills, bonuses and authoritative save state | Validated requests and acknowledged UI display |
| Floor instances, access rules, entity identity and relevant observers | Rendering the current floor and local preferences |
| Membership, permissions, rate limits, backup and administration | Appearance draft preview, microphone capture and voice playback |

Separate `WorldSession`, player registry, floor/chamber runtimes, simulation, network adapters and presentation. Retain collision/terrain on the server while stripping unnecessary visuals. First-person camera-derived attack paths must become deterministic functions of accepted actor state and aim, without substituting broad damage cones for swept steel.

Begin with existing 60 Hz physics and measure candidate input/snapshot rates. Predict the local player's commands, acknowledge sequence numbers, replay pending inputs after correction and interpolate remote actors. Do not assume Godot physics is identical across platforms. Store bounded combat history for a latency experiment: short parry windows and fast rapier contacts need fair, repeatable handling of delayed commands. Reject stale/future input and preserve scenery obstruction. Choose compensation limits and hit/parry precedence only after tests at realistic latency.

Run Floor One, Floor Two and the Vault concurrently when occupied. Streaming interest is the union of players on each floor. One person's travel or distance cannot destroy another person's enemies, collision or encounter. Replace single-target AI with validated target selection and collision against all relevant players; retain sleep distances, bounded spawning and current population rules. Propose one shared Vault per world initially. Before implementing it, settle entry during an active fight, ramp sealing, eligible participants, late join/reconnect, party wipe and reset behavior; private party instances are additional scope.

The following combines confirmed multiplayer rules with explicitly marked proposals for remaining details. Offline behavior remains as documented in AGENTS.md.

Historical-table note: the later authorized implementation resolves defaults in the [current status](WORLD-RISE-IMPLEMENTATION-STATUS.md). In particular, earned loot has no expiry; visible limits of 64 personal claims and 32 arrows do not delete earned state, and first-victory bonus claims travel with the portable character. The original proposal wording below is retained as planning history, not an outstanding authorization or current acceptance claim.

| Topic | Rule or remaining proposal |
| --- | --- |
| Menus | Confirmed: local commands stop; simulation and damage continue. Cancel uncommitted input; already committed actions resolve normally. No menu immunity. |
| PvP | Confirmed opt-in. Proposed details: default off, both players must opt in, visible status, disabling only after an agreed out-of-combat delay, no PvP XP/copper farming rewards. |
| Friendly projectiles | Friendly non-PvP players take no damage or recoil; decide whether their bodies intercept arrows before locking collision rules. |
| Character identity | Persistent portable character UUID and owner credential, independent of display name and temporary connection ID; reject duplicate live logins to the same server. |
| Progression | Confirmed portable character/equipment. Server is authoritative during its session; transfers carry validated character data, not foreign world state. Proposed shared world boss/floor unlocks; exact newcomer floor-access eligibility remains a decision. |
| Rewards | Confirmed: nearby participants each receive XP and personal loot. Keep existing per-recipient values; define contribution/range and personal loot eligibility/expiry. No automatic player-count scaling. Proposed first-kill bonus claims follow the character globally so server travel does not reset a one-time bonus; settle this explicitly. |
| Rest/death | Confirmed: never reset another player's fight; reset only after the encounter area is empty and unengaged. Proposed rest heals/sets that player's checkpoint, death respawns there; define area boundary and reset delay. |
| Clock | Proposed: shared day/night advances while at least one player is connected, freezes when empty. Keep existing boss cooldown durations and night restrictions. |
| Disconnect | Preserve authoritative state; clear pending commands; reconnect to a fresh snapshot. Proposed brief visible-body grace and safe return rules need review; cannot treat network loss as an instant combat escape. |

Portable profiles carry character identity, XP/ranks, equipment/inventory, copper/materials and appearance. World UUIDs namespace clocks, floor unlocks, stable enemy IDs/generations, health/split state, shared victories and world loot, plus each visitor's discoveries/checkpoints/last safe position. A new world uses a valid arrival spawn; joining it does not import foreign defeated enemies, map discoveries or coordinates. Keep personal first-kill claim scope explicit and separate from shared world victories. Local graphics/camera/audio preferences remain local. Any future import of an existing offline character reads a copy through an explicit workflow; this plan does not mutate those saves.

While connected, the server is authoritative and accepts commands rather than arbitrary client inventory replacements. Persist world changes and portable character deltas together. Reward keys include world UUID, encounter generation and recipient so legitimate respawns can pay once again while duplicate claims cannot. Nearby participants receive independent drop rolls/claims under the approved personal-loot rule. Recoverable missed arrows are single physical claims, not one ammunition grant per party member.

Define the durable commit point before acknowledging purchases/rewards as persisted. Use a versioned checkpoint with a flushed journal or a transactional store, and test flush/atomic replacement/recovery on actual host platforms. Atomic replacement alone prevents torn snapshots; it does not establish power-loss durability. Define the maximum allowed loss of uncommitted simulation time. On disk-full/read-only errors, stop accepting durable mutations and report the failure instead of displaying successful purchases backed only by memory.

Return versioned durable character checkpoints to the owning client for atomic installation. Clean departure closes the session and exports its final checkpoint. Reconnecting to an interrupted session first recovers that server's latest authoritative record, never blindly overwrites it with an older local file. When returning after legitimate play on another server, validate the checkpoint lineage and import the newer branch; do not let an old server mirror erase the carried progress. Retain parent hashes/revisions and server receipts to detect stale copies and forks, with explicit recovery choices instead of silently merging or deleting equipment.

This is a trusted-friends portability model. Without a central trusted character service, a player can copy or roll back files, use forks on different servers, or visit an owner-modified world. Credentials and receipts establish ownership/provenance, not legitimate progression. Validate format, bounds, catalog and session operations, but do not promise global duplication prevention or quietly replace portability with server-bound characters.

Authenticate membership and use authenticated encrypted transport for credentials/voice, or explicitly supported private-VPN hosting. Ordinary ENet creation alone does not supply that security; [ENetConnection DTLS support](https://docs.godotengine.org/en/4.5/classes/class_enetconnection.html) needs a tested handshake and identity design. Validate sender ownership, finite values, ranges, positions, timing, equipment, distance and rate for every client request. Bound message sizes, entities and queues; disable arbitrary object/resource deserialization. Server owners remain trusted administrators of their own worlds; this is not a competitive anti-cheat service.

## Docker hosting and operations

Deliver a real versioned Linux server export and image, a Compose example, configuration reference, administrator guide and client Join screen with address/port, credentials, connection status and useful mismatch/error messages. Direct join and recent servers are sufficient initially; automatic discovery, public matchmaking, relay hosting and mod support are separate work. The game client should not require Docker.

Run as non-root with a read-only application and persistent `/data` volume; keep secrets separate, cap logs, expose documented UDP ports and implement health/readiness checks. On shutdown, stop new joins, settle/save consistently and exit within the configured grace period. Plain Docker health checks do not themselves restart unhealthy processes; configure and test the intended restart mechanism. A persistent volume is not a backup.

Create consistent rolling backups, verify restore, retain a pre-upgrade snapshot and reject incompatible protocol/content/save versions. Pin engine/export/dependency versions; avoid silent `latest` upgrades. Linux x86_64 is the first server target, with ARM64 as a later verified build if wanted. No GPU/display/audio device should be required on the server.

Document LAN play, firewall rules, manual UDP forwarding and public address/DNS. Docker does not solve NAT or CGNAT: private VPN or a VPS are alternatives when forwarding is unavailable. Keep first-release admin functions local: whitelist, kick/ban, status, save and orderly restart. No public unauthenticated administration endpoint.

References: [Godot dedicated exports](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_dedicated_servers.html), [Docker ports](https://docs.docker.com/engine/network/port-publishing/), [volumes](https://docs.docker.com/engine/storage/volumes/), [restart policies](https://docs.docker.com/engine/containers/start-containers-automatically/) and [Compose service configuration](https://docs.docker.com/reference/compose-file/services/).

## Voice chat

Provide the confirmed push-to-talk proximity voice plus a separate group channel. Proximity eligibility uses authoritative floor/position. Include microphone/device selection, input meter and mic test, speaking indicators, per-player volume/mute, deafen and administrator mute. Missing microphone or denied permission must not prevent joining. Focus loss or closing/disconnecting stops capture transmission. No recording by default.

Clients capture/encode Opus; the server relays bounded frames to eligible peers; clients buffer/decode/play. The headless server needs no sound device or decoder for this relay design. Voice uses separate unreliable traffic, strict bandwidth limits and stale-frame dropping to protect gameplay traffic. It still shares CPU and uplink capacity: measure combat degradation with simultaneous talkers and a constrained connection. Test voice spam/oversized frames, device removal, background audio, lost packets and floor/channel changes without disconnecting gameplay. Voice audio has its own bus and optional restrained music ducking.

Early feasibility test: pin and build a codec extension against **Godot 4.5.1 on every selected client OS**. [Godot-Opus](https://github.com/Godot-Opus/libopus-gdnative) is a minimal candidate; [TwoVoip](https://github.com/goatchurchprime/two-voip-godot-4) has more voice plumbing but its current branch targets Godot 4.6. Neither is accepted until the exact pinned binaries, licenses, latency and export behavior pass. Do not silently upgrade the engine to make an add-on work. Check wrapper and transitive notices, including [Opus licensing](https://opus-codec.org/license/).

Start measurements around mono 48 kHz, 20 ms frames and approximately 24 kbps per speaker, with bounded jitter buffers and packet-loss concealment. These are prototype settings. Eight simultaneous speakers relayed to seven others are approximately 1.34 Mbps server payload egress before overhead. Proximity reduces ordinary traffic but is not a substitute for stress tests. Self-hosted relay is not end-to-end private from the server owner; avoid making that promise.

## Appearance screen and asset design

Preserve the five inventory tabs. Add Appearance within Equipment & Items and as a pause-menu button. The proposed screen follows the current subdued woodland/gold styling:

```text
Appearance                                      Preview only until Apply
┌──────────────┬─────────────────────────────┬─────────────────────────┐
│ Face         │                             │ Presets / bounded       │
│ Hair         │    Neutral-lit character    │ controls for selected   │
│ Skin         │    Rotate and zoom          │ category                │
│ Body         │    Face / Body framing      │                         │
│ Colors       │    Front / Side / Back      │ Labeled color swatches  │
├──────────────┴─────────────────────────────┴─────────────────────────┤
│ Randomize     Reset to Default                    Cancel     Apply  │
└─────────────────────────────────────────────────────────────────────┘
```

Opening creates a separate draft and preview scene. Controls never mutate the live player, save or network until Apply. Cancel/Escape discards the draft and returns to the invoking overlay. Randomize uses compatible authored combinations; Reset restores the existing heroine default in the draft. Apply validates once, preserves all gameplay state and persists through the ordinary save lifecycle without bypassing current save restrictions. Online, send one accepted profile revision rather than streaming every slider. If an active action prevents a safe mesh swap, defer only the visual replacement to a safe action boundary.

Provide keyboard focus, readable labels, swatches distinguishable without color alone, and layout checks at 960×540 plus normal desktop sizes. Preview clicks must never leak into attacks. Preview has its own lighting/world and never becomes the gameplay audio listener.

Keep the current heroine as the exact default. Use an approved catalog of face/hair/body options and controlled material palettes, with bounded body silhouettes and garment corrective shapes. Preserve rig rests, limb lengths, hand/foot anchors, stature and gameplay capsule. Height/reach-changing sliders require a separate combat/collision design; unrestricted body morphs are not safe to add casually.

Create an appearance profile with its own version, catalog version, stable base/face/hair/skin/body IDs, bounded colors and named morphs. Never accept client resource paths or scripts. Missing fields in old saves map to the exact current appearance. Maintain explicit aliases/migrations for retired IDs and report incompatible data without deleting progression. Named grip channels must coexist with appearance morphs in the full body and extracted first-person arms. Invalidate skin/preview caches by appearance revision; duplicate materials per player to prevent color changes leaking between actors. Across every allowed appearance combination, verify unchanged hand/nock/carry anchors and contact geometry, including bow string-hand motion and spear grip spacing.

**Model review remains required before fitting new models to animations.** Root AGENTS.md preserves that gate, and `art/character/model-review.json` records “get my verification once you have a model before begining animations.” Prepare static face/body/hair sheets first. Record any new approval against the actual candidate files/hashes; do not mark the old rejected draft as approved. Existing approved assets can be reused while new options await review.

## Complete World Rise audio system

Build a shared audio director with a semantic event catalog, bounded player pools, one gameplay listener, surface resolution, ambience/music state and user preferences. Use separate Master, Game and Voice branches; Game contains Music, Ambience, SFX and UI. Preview scenes remain silent. Refer to [Godot audio buses](https://docs.godotengine.org/en/4.5/tutorials/audio/audio_buses.html) and [positional audio](https://docs.godotengine.org/en/4.5/classes/class_audiostreamplayer3d.html).

| Coverage | Required sounds |
| --- | --- |
| Player movement | Surface-specific walk/sprint steps, jump/land, dodge/dash, cloth/gear, water entry/exit/wading and drowning transition. Resolve raft/bridge support before underlying water. |
| All four weapons | Draw/stow, swishes/thrusts, bow nock/string/release/flight/impact, successful parry, armor/gel/flesh/stone contacts, interrupted actions. |
| Combat feedback | Damage, death, stamina denial, confirmed hit, heavy ground impact and current World Rise abilities. No dormant Mana skills reintroduced. |
| Ordinary enemies | Wolf/boar notice, tells, attack, movement, pain/death; both heads of twin wolves; small/giant slime movement, leap, landing and split. |
| Bosses and hazards | Ashfang howl/attacks, Elder formation/sweeps/slam/rush/stone/reflect; resin launch/puddle/trap/release. |
| World | Floor One hills/forest/guild/west islands; cave/Vault; Floor Two water/insects/raft; smooth day/night layers and restrained exploration/combat/boss music. |
| Interaction and UI | Separate rest/travel/discovery cues, pickups/equip/potions, trades/denials, quests/level-up, menu focus/confirm/back and appearance controls. |
| Accessibility | Volume categories, mute, quiet dynamic range, mono option and visual equivalents for important cues without revealing hidden content. |

Drive sounds from accepted action markers and resolved outcomes, not random animation frames. The actor manually seeks animations, so phase-crossing markers must fire once even after a skipped frame, and stop on cancellation. Footsteps derive from actual gait/travel, not camera bob; no walking sounds against an immovable wall. Impacts occur only after confirmed collision/damage outcomes. Audio never drives damage, AI or rewards.

Offline pause explicitly freezes action/world cues using the existing simulation gate; UI remains audible and music may continue at a quieter paused mix. Do not queue a burst for menu close. Online audio follows continuing server simulation. World/floor generation and stable action/event IDs prevent duplicated predicted/confirmed sounds, late-join victory playback and stale effects after travel.

Start profiling with bounded budgets such as 32 world one-shots, 8 loop emitters, 8 local/UI sounds and two music crossfade tracks; tune against actual hardware. Reserve capacity for parry, damage and boss tells. Use modest variant/pitch variation, mono positional clips, streamed long tracks and limited low-rate occlusion checks. No unbounded ambient sources or per-frame raycasts for every sound.

Acceptance includes captured audio and headphone/speaker listening, not only screenshots. Verify mix headroom in the busiest fights, audible direction and tells, settings persistence, no microphone feedback, lifecycle cleanup, no duplicate events and performance with eight players. Fully voiced NPC dialogue, bespoke soundtrack composition and gameplay driven by noise are separate scope.

## Open-license asset shortlist

Candidates are researched, not downloaded, auditioned, visually accepted or proven on the current rig. Preserve exact source/version/hash/license/author and modifications in the asset manifest and `docs/ASSET-CREDITS.md`; use Git LFS for large art. Prefer coherent adaptation over combining visibly incompatible art styles.

| Need | Candidate and qualification |
| --- | --- |
| Bow/spear models | [KayKit Fantasy Weapons Bits](https://kaylousberg.itch.io/fantasy-weapons-bits), CC0; free and paid/source tiers differ. [Quaternius medieval weapons](https://quaternius.com/packs/medievalweapons.html) is another CC0 source. Bow-string rigging still needs inspection. |
| Rapier model | [MrLeap Low Poly Weapon Pack](https://mrleap.itch.io/low-poly-weapon-pack), CC0 rapier/spear with Blender source. Style and geometry need review. |
| Bow and melee body motion | [KayKit Character Animations](https://kaylousberg.itch.io/kaykit-character-animations), CC0, includes bows and melee; editable source tier differs. [Quaternius Universal Animation Library 2](https://quaternius.com/packs/universalanimationlibrary2.html) is an alternative with different free/full tiers. |
| Skin/body/hair sources | [MakeHuman/MPFB licensing](https://static.makehumancommunity.org/about/license.html), [Skins 01](https://static.makehumancommunity.org/assets/assetpacks/skins01.html) and [Hair 02](https://static.makehumancommunity.org/assets/assetpacks/hair02.html). Core art and community entries have different licenses; hair can require attribution and optimization. Software licenses are distinct from generated art. |
| Surface materials | [Poly Haven](https://polyhaven.com/license), CC0 assets, useful for garment/leather materials rather than ready avatars. |
| Foley and impacts | [Kenney RPG Audio](https://kenney.nl/assets/rpg-audio) and [Impact Sounds](https://kenney.nl/assets/impact-sounds), CC0. Select after audition and mix review. |
| Music starting point | [Fantasy Rising Moon by RandomMind](https://opengameart.org/content/fantasy-rising-moon), specific CC0 upload; a candidate for night exploration, not an accepted soundtrack. Verify every further track individually. |

Retarget imported animations in isolation using [Godot 4.5 humanoid retargeting](https://docs.godotengine.org/en/4.5/tutorials/assets_pipeline/retargeting_3d_skeletons.html), then fit approved first-person hands and weapon contacts. Matching names is insufficient; rest axes, translation tracks and proportions matter. Do not globally alter the current heroine's rest/import settings. [Godot import guidance](https://docs.godotengine.org/en/4.5/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html) also applies to morph exports.

Free proprietary libraries are not automatically open-license. Mixamo is therefore not the default choice. Audio libraries that prohibit redistribution of source effects cannot be casually committed to this shared source repository. No asset is selected merely because it is free to download.

## Release acceptance

Use disposable test data and the established platform wrapper; add portable/new feature checks deliberately. Do not run fixtures against personal saves. No gameplay version bump or package is needed for this planning handoff.

The implementation acceptance sequence is:

1. Baseline/content validation and meaningful checks for changed systems; old/new save validation and default behavior.
2. Actual World Rise Advanced gameplay sequences for gait, all weapon transitions, contacts, appearance variants and observer poses; required menu captures.
3. Separate Linux server plus two clients; simultaneous floors, independent overlays, interactions, attacks, rest/death and reconnect.
4. Eight clients together at night/in bosses and spread across floors; record server tick time, bandwidth, memory, voice queues and client frame time against the existing 60 FPS target on declared hardware.
5. LAN plus 60/120/200 ms RTT, jitter, packet loss/reordering, outage and reconnect. Demonstrate no session-level duplicated rewards or invalid hits and recovery to authoritative state; define numerical tolerances after prototypes. Separately test portable departure, interrupted export, server A → B → A travel, stale/forked profiles and explicit conflict recovery. Do not confuse these checks with impossible global duplicate prevention across independent servers.
6. Simultaneous PvP opt-in/opt-out, arrows already in flight, parry precedence, death, disconnect and floor travel; no economy rewards from PvP farming.
7. Voice on real devices across target platforms; mute/channel/focus/privacy behavior and voice-disabled fallback.
8. Graceful stop, forced kill, full disk, corrupted checkpoint, restore, version mismatch and upgrade/rollback. Never let an older server silently write a newer save schema.
9. Focused Floor Two checks (`validate`, `inspect-swamp`, then packaged `inspect-swamp --windows --render`), relevant combat/unarmed/World Rise regressions, and separately resolved or explicitly reported uphill failures.
10. Gated build, accepted current screenshots/audio/evidence, then obsolete-release cleanup. `build --skip-tests` is packaging only and must be labeled unvalidated.

Source anchors and individual coding packets are in the [agent task tree](WORLD-RISE-AGENT-TREE.md). New commands, modules and schemas named there are planned work, not existing capabilities.
