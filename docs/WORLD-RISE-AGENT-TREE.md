# World Rise agent task tree

Planning handoff for the [development roadmap](WORLD-RISE-ROADMAP.md), October 18, 2026. Baseline: `codex/world-rise-handoff` at `06f9372`, gameplay v0.41.4. **Historical planning snapshot:** the request at preparation time authorized planning only. The human subsequently authorized implementation of this roadmap/tree. Read the current [implementation status](WORLD-RISE-IMPLEMENTATION-STATUS.md), [integration contract](WORLD-RISE-INTEGRATION-CONTRACT.md) and newest [baseline entry](CURRENT-BASELINE.md) for implemented behavior, ownership and outstanding acceptance; this original task tree is not verification evidence.

All future coding agents use **`gpt-6.1-sol`, reasoning `medium`**. The lead assigns bounded tasks, resolves interfaces and product decisions, reviews results and directs integration. Use explicit context packets when selecting this model; in this environment that means `fork_turns: none`. Do not create sidebar chats to perform subtasks. Never treat a proposed interface, file name or balance value below as already implemented or approved.

## Dependency tree

```text
Lead — scope, decisions, interfaces, evidence and acceptance
│
├── A  Baseline and contracts
│   ├── A0  Materialized assets and portable verification
│   ├── A1  Motion reproduction and known slope failures
│   ├── A2  Simulation, weapon, event and save contracts
│   ├── N0  Headless combat and latency experiment
│   └── V0  Godot 4.5.1 voice compatibility experiment
│
├── M  First-person motion [A0, A1]
│   ├── M1  Walk/sprint hand continuity
│   ├── M2  Swing path, camera and grip correction
│   └── M3  Visual/contact acceptance
│
├── F  Shared foundations [A2, N0, M3 integration]
│   ├── F1  Input commands, simulation and presentation separation
│   ├── F2  Weapon profiles and unchanged greatsword adapter
│   └── F3  Stable events, damage sources and profile validation
│
├── W  New weapons [F2, F3]
│   ├── W0  Reviewed models and animation intake
│   ├── W1  Spear slice
│   ├── W2  Rapier slice
│   ├── W3  Bow, physical arrows and white trajectory preview
│   └── W4  Equipment, stats, saves and observer animations
│
├── C  Appearance [A0, A2]
│   ├── C0  Actual rig inspection and static option review
│   ├── C1  Profile/catalog and renderer adapter
│   ├── C2  Appearance editor and persistence
│   └── C3  Approved fitted assets and combination verification
│
├── S  Sound [A2, F3]
│   ├── S0  Sound catalog, buses, pools and settings
│   ├── S1  Player, weapon, wolf and slime sound slice
│   └── S2  Complete World Rise coverage, ambience and mix
│
├── N  Multiplayer [F1, F3, N0]
│   ├── N1  Sessions, movement and early greatsword combat
│   ├── N2  Concurrent floors, streaming and multi-player AI
│   ├── N3  Portable characters, durable economy and reconnect
│   ├── N4  Authoritative four-weapon combat and opt-in PvP
│   └── N5  Appearance/audio adapters and late-join behavior
│
├── V  Voice [V0, N1, S0]
│   └── V1  PTT, routing, playback, settings and moderation
│
├── D  Dedicated hosting [N1, N3]
│   └── D1  Linux export, Docker, backup/admin and join UX
│
└── Q  Integrated acceptance [M, W, C, S, N, V, D]
    ├── Q1  Eight clients, latency, persistence and regression
    └── Q2  Visual/audio acceptance and release handoff
```

Tree branches describe ownership, not permission to start all children at once. N1 begins with two players and authoritative greatsword damage/parry as soon as F1/F3 exist; it must not wait for finished art or all weapons. W1 is the first new-weapon reference implementation; W2/W3 branch from its proven interfaces. Every weapon slice integrates through normal equipment/save paths as it lands; W4 consolidates the four-weapon result. S0 and catalog planning can begin before F3, but gameplay wiring waits for its event contract. D1 can prototype its image/export early; persistence/restore acceptance waits for N3. W0 static/license intake begins after A0; socket and animation fitting wait for F2 and required model review.

## Shared contracts to settle in A2

| Contract | Required contents and boundaries |
| --- | --- |
| Input command | Player identity from authenticated connection; sequence/tick; bounded movement/look; action edges. No direct global input access in the reusable simulation. |
| Actor state | Mode/session/floor, authoritative movement/resources, equipped profile, action ID/phase, gait state, status and revision. Local UI/camera/preferences are separate. |
| Weapon action | Stable action identity; supported inputs; accepted start/cancel; costs and recovery; pure pose/contact samples; grip/nock/carry sockets; known event markers. |
| Damage source | Stable attacker, weapon type/item, action/projectile ID, strike index, encounter generation and validated contact. Preserve armor, recoil, parry and dedup rules. |
| Presentation event | Stable owner/action/event/generation IDs; timestamp/phase; semantic cue and position. No authoritative damage encoded in a client sound/effect request. |
| Appearance | Versioned allowlisted IDs, bounded colors/morphs and revision. Same validator for menu, save and network. No resource paths. |
| World/player save | Confirmed portable characters with world-specific state; authenticated session authority, checkpoint lineage/import/export/conflict rules, durable acknowledgement/recovery and per-recipient reward settlement. Existing offline saves remain isolated. |
| Overlay mode | Confirmed offline simulation pause versus online command suppression while vulnerable. |
| Cooperative encounters | Confirmed participant XP/personal loot and no reset while occupied/engaged; settle range, contribution, reset delay, shared Vault entry/ramp/late-join/wipe rules and scope of portable first-kill claims. |
| Authority boundary | Client intent vs server results; prediction/acknowledgment; headless real steel; enemy/projectile/collision ownership and interest. |

Lead publishes a short accepted contract before dependent agents edit. Interface changes require notification to dependent owners and a small coordinated integration patch. A new module does not justify a broad rewrite of unrelated modes.

## Task packets

Each packet must produce a focused implementation plus verification evidence when implementation is authorized. Proposed module names are intentionally suggestions; settle exact names at assignment time.

| ID | Owner and scope | Depends on | Exit evidence |
| --- | --- | --- | --- |
| A0 | Tooling agent: materialize/check LFS; establish pinned engine; portable cache/tool discovery and disposable-userdata launcher while preserving Windows wrapper; inspect actual Linux export inputs. | Implementation authorization | Reproducible setup on chosen client hosts and Linux; clean dependency check; no private save touched; no generated binaries in Git. |
| A1 | Verification agent: real World Rise running/swing input reproduction; long-clock sprint transitions; classify the three known uphill failures separately. | A0 | Before captures, reproduction sequence, measurements and focused failing checks. Explicitly distinguish fixture fault from gameplay fault. |
| A2 | Contract agent with lead: settle interfaces above and record accepted product policies. | Source audit; user decisions as applicable | Small reviewed contract and file ownership map; defaults vs accepted decisions distinguished. |
| N0 | Network/combat experiment agent: headless movement and pure real-steel sampler; two peers with delayed input/parry; compare client/server geometry. | A0, draft A2 | Actual Linux headless evidence; equivalence of blade base/tip, basis/width, ground fitting and world transform over timing/aim/terrain; no mesh/camera dependency; recommendation on compensation. |
| V0 | Voice experiment agent: pinned codec extension builds/exports on chosen OSes at Godot 4.5.1; record licenses and dependencies; live mic encode/decode. | A0, target platforms | Tested version/commit, latency/device/export results and fallback choice. Reject engine upgrade as an implicit workaround. |
| M1 | Motion agent: repair reproduced locomotion defects; integrated gait phase is the leading candidate, not a predetermined diagnosis. Adjust amplitudes only where evidence warrants it. | A1 | Before/after real-input clips; early/long-clock tests; idempotent sampling, pause/reset and focus behavior. |
| M2 | Same motion owner: isolate/fix trajectory, camera or IK defects; preserve shared steel and action clocks. | A1, M1 | Smooth ready/draw/light/heavy/combo/parry and sprint-to-attack; grip limits, real contact/occlusion and resource behavior. |
| M3 | Verification owner plus lead: review actual Advanced first-person sequences and focused combat/grip tests. | M1, M2 | Accepted motion evidence; unresolved visual issues explicitly identified before reusing paths. |
| F1 | Integration agent: split local input, simulation context and presentation; explicit offline/online gates and session lifecycle. | A2, N0; merge after M3 | Existing offline behavior and saves retained; authoritative actor runs without local input/UI/rendering; online menu cannot grant immunity. |
| F2 | Weapon foundation agent: new profiles/schemas, pure contact/motion sampler, legacy greatsword adapter and hooks. Shared-file edits routed through integration owner. | A2, N0, M3 | Current greatsword tiers/actions/skills/damage/grips unchanged; profiles select geometry without scattered type branches. |
| F3 | Contract implementation owner: stable IDs/events/damage context, validators and revision rules. | A2, F1/F2 interfaces | Deduplicated action/results; validated content; no per-process instance IDs in persisted/network identities. |
| W0 | Art intake agent: inspect open-license donors, fit/style static weapon options, prepare model-review evidence; record provenance. | A0 for intake; F2 sockets and model approval for fitting | Accepted static models and exact licenses; animation/socket fitting only after both dependencies. |
| W1 | Spear agent: dedicated data/actions/grips/tip contacts and gameplay slice, using approved model. | F2, F3, W0 | Longest melee reach by measured contact envelope; no shaft/wall phantom hits; smooth draw/thrust/recovery/parry. |
| W2 | Rapier agent: short responsive thrust sequences and approved movement/cancel rules. | W1 interface acceptance, F3, W0 | Faster intended feel, continuous one-hand grip, correct stamina/recovery, no new invulnerability. |
| W3 | Bow agent: physical flight, nock/draw/release/cancel, preview, finite vendor arrows and recoverable missed-arrow claims. | F2/F3, W1 interface acceptance, W0; defense/recovery details | Static preview/flight match; moving-target limits; accepted release tick/aim and reconciliation; safe near-wall origin; one ammo spend/recovery; interruption and bounded lifetime/count. |
| W4 | Integration/stat/save owner: consolidate catalog/equipment/UI, effect applicability, true greatsword kill attribution, strict migration and full-body observer motions. Provide minimal production integration to each W1–W3 slice as it lands. | W1–W3 for final regression; accepted tuning table | Old saves load; invalid IDs reject; all four weapons save/travel/replicate correctly; no accidental Greatsword bonuses. |
| C0 | Character art agent: actual source/GLB/morph inspection; compatible face/hair/body options, material design and static review sheets. | A0 | Feasible options and rig budget; exact default preserved; new model review tied to candidate hashes. |
| C1 | Appearance renderer agent: profile/catalog/schema, material instances, named grip/morph channels, first-person arms and preview revision invalidation. | A2, C0; F2 hand socket agreement | Default equality, independent materials, named grip channels coexist with appearance, strict version/ID/bounds validation. |
| C2 | UI agent: editor, Apply/Cancel/Randomize/Reset, access from existing menus, focus and save/network request integration. | C1, F1 gates | No draft leakage; no attack click-through; normal save lifecycle; 960×540 capture and keyboard focus acceptance. |
| C3 | Art/verification owner: approved fitted variants/correctives and combined extrema, all weapon hand poses, remote LOD/performance. | C0 approval, C1/C2, weapon poses | Seams/clipping/grips reviewed; eight-avatar budget; unchanged hand/nock/carry anchors, spear spacing and bow string grip; no collision/reach changes. |
| S0 | Audio agent: event catalog, bus layout, bounded pools/listener/settings, source intake and voice-bus API. | A2; F3 for event wiring | Valid catalog/license records; pool limits and settings; explicit offline pause lifecycle; preview cannot steal listener. |
| S1 | Audio agent: actual footsteps/surfaces, jump/land, greatsword contacts/parry/damage, wolf/slime sound slice. | S0, F3 | Recorded/listened gameplay slice; no duplicate/false hit cues or steps while blocked; menus resume without bursts. |
| S2 | Audio content agent: remaining weapons/enemies/bosses/hazards/UI/economy/travel, zones/music, accessibility and mix. | S1; W1–W3 for weapon cues | Complete coverage checklist, source licenses, listened worst-case mix, bounded CPU/memory and emitter cleanup. |
| N1 | Transport/integration agent: session/identity, encryption or documented VPN transport, join flow, snapshots, prediction/reconciliation, remote actors and early authoritative greatsword damage/parry against a shared enemy. | F1, F2, F3, N0 | Separate Linux server plus two clients move and fight; spoof/replay/rate limits; version mismatch; motion/contact corrections measured. |
| N2 | World/AI agent: concurrent floors/shared Vault, union-of-player interest, target selection, collision/attack routing and encounter lifecycle. | F1, N1; detailed reset and Vault rules | Independent distant fights/floors; correct targets; Vault entry/ramp/late-join/reconnect/wipe; bounded spawn/LOD retained. |
| N3 | Persistence agent: portable profiles/identity, world state, durable reward/loot transactions, checkpoint export/import, reconnect/conflicts and backup format. | A2 accepted policy, N1/N2 interfaces | Partial fights/claims/bonuses settle once per session; disk-error handling and durable-ack contract; A→B→A travel, interrupted export, stale/fork recovery; no false global anti-duplication guarantee. |
| N4 | Combat network agent: four weapon authority, projectile reconciliation, latency/parry policy and mutually opted-in PvP. | N0, N1/N2, W1–W4; PvP policy | Real steel and arrows resolve once; both-player opt-in enforced; no toggle/floor/disconnect exploit; playability at agreed latency. |
| N5 | Presentation integration agent: accepted appearance revisions, semantic audio dedup, spawn/late join and observer poses. | C2/C3, S2, N1/N2, F3 | No historical sounds/rewards replay; no local/remote material bleed; one appearance update per Apply; coherent four-weapon observer poses. |
| V1 | Voice agent: confirmed proximity/group PTT, relay authorization, jitter buffer/playback, device settings and mute/admin hooks. | V0, N1, S0 | Real Windows/macOS devices; 8 speakers; loss/jitter/focus/mute/device-denial/spam tests; gameplay stays within measured limits under constrained uplink. |
| D1 | Hosting/tooling agent: Linux export/image, Compose/config, volume/secrets/logs/admin, readiness, stop/save/restart and restore guide. Join UI coordinated with N1/UI owner. | A0, N1/N3; early image prototype allowed | New machine can host/join; no GPU; clean stop/kill/full-disk/restore/version tests; NAT/CGNAT instructions accurate. |
| Q1 | Integration verification agent: eight clients, Internet-condition matrix, malicious/malformed inputs, long session, floor/boss/economy and existing regressions. | All feature branches | Measured results on named hardware; unresolved known baseline failures separated; no false full-suite pass. |
| Q2 | Lead with verification/art/audio owners: actual native visuals, listening and packaging evidence; user review of concrete results. | Q1, approved assets | Gated release accepted; only current evidence/release retained; source/licenses complete; no private saves or machine paths committed. |

## File ownership and collision prevention

| Owner | Existing shared files requiring coordination | Typical exclusive new files |
| --- | --- | --- |
| Integration | `game/scripts/main.gd`, `actor.gd`, bootstrap/scene wiring, `project.godot` | Session/input/simulation adapters |
| Motion | `first_person_sword.gd`, `first_person_visuals.gd`, `follow_camera.gd`, `unarmed_hands.gd`, motion JSON | Transition diagnostics/fixtures |
| Weapon foundation | `magic_items.gd`, combat/stat interfaces; requests shared actor edits through integration | Weapon profiles/runtime/sampler and schemas |
| Weapon feature owners | Their weapon-specific assets/data/modules only | Spear, rapier, bow, arrow and preview modules |
| Appearance renderer | `beta_hero.gd`, `equipment_preview.gd`; first-person visuals only after motion owner's handoff | Appearance catalog/profile/renderer |
| UI | `inventory.gd`, `pause_menu.gd`, `title_screen.gd`; shared input wiring through integration | Appearance/join/audio/voice settings components |
| World/AI | `world_rise.gd`, `swamp_campaign.gd`, `wolf_packs.gd`, enemy/boss/hazard controllers | Floor runtime and targeting services |
| Persistence | `save_store.gd`, save migration, guild/checkpoint/reward interfaces | Server storage, settlements and recovery fixtures |
| Audio/voice | Separate subsystem directories; event hooks routed through owning agent | Audio director/events/zones, voice codec/relay/client adapter |
| Tooling | `tools/platform_cli.py`, `platform.cmd`, export/build configuration | Portable launchers, container/config/docs, new verification entry points |

The motion and appearance agents must never edit `first_person_visuals.gd` concurrently. Networking and weapon agents must not independently rewrite actor action clocks. After M3, the weapon foundation owner accepts N0's sampler prototype and takes an explicit handoff of the relevant `first_person_sword.gd`/motion definitions from the motion owner; the integration owner wires the actor. Invalidate cached grip frames when weapon profiles or motion definitions change. The UI owner integrates all new menu entry points. A leaf agent may propose a shared-file change but must request an ownership handoff before editing it.

Every W1–W3 handoff includes normal equipment selection/save/travel, sprint-to-equip/attack, held-input cancellation, damage interruption, pause/focus loss, death, low targets and steep pitch. Compare local/observer weapon pose and authority/client contact paths, including parry. N4 extends these checks under latency and PvP; it does not supply the first correctness check.

Use a small number of concurrent agents, normally three or four active implementation owners. Separate worktrees/branches based on this handoff can isolate edits, but do not replace ownership discipline. Keep branches under `codex/`; preserve Alpha/Beta history. Never automatically start optional gameplay changes to keep an agent busy.

## Suggested dispatch waves

| Wave | Work that can overlap | Required join before proceeding |
| --- | --- | --- |
| 0 | A0 setup, A2 policy/contracts, paper asset/license inspection | Usable checkout and chosen target platforms |
| 1 | A1/M reproduction, N0 headless/latency experiment, V0 voice experiment, C0 static review | Motion evidence and feasibility decisions |
| 2 | M1/M2; prototype S0/catalog; W0 static/license intake | M3 acceptance, stable A2/N0 outcomes; fitting waits for F2 |
| 3 | F1/F2/F3 through coordinated owners; C1 nonconflicting data work | Offline greatsword equivalence and shared interfaces |
| 4 | W1, N1, C2, S1 | Playable spear, two-client movement/greatsword combat, default appearance editor and sound slice |
| 5 | W2/W3 in separate modules, N2/N3, C3, S2 as slots/ownership permit | Four weapons, simultaneous floors, accepted appearance and complete audio |
| 6 | N4/N5, V1 and D1 | Integrated release candidate |
| 7 | Q1/Q2 | Accepted tested release and complete handoff |

No asset gate is waived by a scheduling dependency. Work on approved/default assets and independent systems while a new static candidate awaits the existing model review.

## Research anchors for agent context

Line numbers below refer to the planning baseline and will move. Read the whole relevant function and current source before editing.

| Topic | Starting points |
| --- | --- |
| Mandatory reading | `AGENTS.md`, `START-HERE-WORLD-RISE.md`, `docs/WORLD-RISE-HANDOFF.md`, newest `docs/CURRENT-BASELINE.md`; combat owners also read `FIRST-PERSON-SWORD.md` and `COMBAT.md`. |
| Gait phase hypothesis | `unarmed_hands.gd:17–24`; `first_person_sword.gd:29`; `unarmed_checks.gd:14` and `unarmed_capture.gd:15` lack actual transition/long-clock coverage. |
| Swing/camera/arms | `first_person_sword.gd:13,45`; `follow_camera.gd:179`; `first_person_visuals.gd:74,85,143,219,261`; `grip_checks.gd:75`. |
| Actor authority | `actor.gd:642` phases, `:1230` steel pose, `:1283` swept contact, `:1337` physics/clocks/global input. |
| Weapon coupling | `actor.gd:212,522,528,620,762,979,1005,1041`; `schemas/character.schema.json:50`; `main.gd:1400` hit/greatsword credit; `world_rise_stats.gd:4,7`. |
| Single-world lifecycle | `main.gd:53–95,557`; `world_rise.gd:237`; `wolf_packs.gd:59`; `swamp_campaign.gd:97`; `world_rise.gd:306`. |
| UI gates | `main.gd:724,1188,1222,1248,1255`; `actor.gd:1116` rejects damage when disabled; `main.gd:172` handles focus loss. |
| Persistence/economy | `main.gd:1031,1046,1486`; `save_store.gd:17,88`; `magic_items.gd:23,63,65`; `rise_guild.gd:43`. |
| Active heroine | `beta_hero.gd:18,59,121`; `tools/beta_rig.py`; `art/character/beta-heroine-export.json`; `tools/export_personal_heroine_static.py:134`; `tools/export_beta_heroine.py:7`. |
| Appearance hazards | `first_person_visuals.gd:24,29,64–69,120` view-arm extraction/cache/fixed morph indexes; `equipment_preview.gd:6,24`; `equipment_visuals.gd:4` intentionally omits procedural accessories. |
| Audio hooks | `actor.gd:936,944,1066,1086,1587`; `beta_gait.gd:10`; accepted contacts in `main.gd:1400`; actual boss/slime state transitions and guild/checkpoint outcome methods. |
| Tooling limits | `tools/platform_cli.py:18` Windows cache assumption, `:337` existing model gate, `:565` current command list; `tools/bootstrap_runtime.py` Windows-only downloads; `tools/check_checkout.py` read-only materialization check. |

Official research links and license qualifications are consolidated in the roadmap. No new donor binary or live engine compatibility was verified during this planning pass.

## Agent dispatch template

Use this as a complete natural-language task, replacing the brackets before dispatch:

> Work on World Rise task [ID and concrete outcome] from the accepted roadmap. Use GPT-6.1-sol with medium reasoning. This task has implementation authorization from [actual user instruction]; do not infer authorization from the planning files. Read the repository instructions and newest baseline, then the task packet and current code. Own only [files/modules]; [names] own shared integration files. Dependencies accepted: [evidence]. Preserve [specific contracts]. Implement the smallest coherent result, including meaningful focused verification and native visuals/listening where needed. Use disposable userdata, never personal saves. Do not change unrelated gameplay/balance or reset model approvals. Stop dependent work and report the exact missing decision if one is required; continue independent authorized work. Return changed paths, design choices, checks with actual outcomes, evidence paths, unresolved issues and integration needs. Do not claim a global pass from focused tests or create additional agents without an explicit assignment.

For a research-only packet replace implementation language with: “Read-only research. Do not edit files, download assets, import Godot, generate models, run builds or modify saves. Return source evidence, verified primary links, hypotheses, dependencies and acceptance criteria.”

## Review and handoff requirements

Every implementation handoff records the accepted contract version and exact scope, explains behavior changes, lists relevant checks actually run, links current visual/audio evidence and names unresolved issues. Include license/version records for assets and native libraries. Tests proposed but not run must be labeled as such.

Use existing focused commands where they fit: `validate`, `verify-unarmed`, `verify-combat`, `verify-world-rise`, relevant `verify-windows --suite ...`, `inspect-swamp`, and required native/menu captures. New weapon/network/voice/appearance/audio commands do not exist yet; add them through the tooling owner rather than documenting imaginary commands as runnable. Diagnose the known broad uphill failures; never delete failing fixtures to make the report green.

No gameplay implementation, asset generation, dependency installation, tests, package, commit or release was performed for this planning document. Only this guide and its companion roadmap are planning deliverables.
