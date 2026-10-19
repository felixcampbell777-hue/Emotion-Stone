# World Rise progression: tree version 5

World Rise has five attributes: Body, Reflexes, Precision, Endurance and Mastery. Each starts at 3 and can reach 20. New characters receive seven attribute points. Each level after level one grants one attribute point and one perk point. Existing XP, all fifty level thresholds, equipment level requirements and the one-percent health/stamina growth per level remain unchanged.

Attributes grant the following bonuses for each point above 3. Health and stamina additions are applied after the existing level growth; weapon damage additions combine additively with relevant perks and practice.

| Attribute | Bonus per point |
| --- | --- |
| Body | +2 maximum health |
| Reflexes | +0.5% walking and sprinting speed |
| Precision | +1% bow and rapier damage |
| Endurance | +2 maximum stamina |
| Mastery | +1% greatsword and spear damage |

The Level Up page displays both budgets and all twenty-three perks. Perks require attribute tiers 4, 9, 15 or 20, plus the displayed prerequisite. One rank costs one perk point. Most perks cap at three ranks; active abilities and capstones cap at one. All learned passives apply automatically. The authoritative descriptions and rank caps are in `game/content/world_rise/skills.json`.

Dash, Dodge and Charged Thrust keep their existing controls and action geometry. Jump remains available without a perk. There is no Mana branch or roll damage immunity. The actor continues to own action clocks and resources.

Perk refunds are free, one rank at a time. A prerequisite cannot be removed while a learned dependent still needs it. Refunding Dash disables its loadout; refunding Charged Thrust selects Overhead. Each character also has one clearly labelled free attribute reset, with confirmation. This refunds every perk and attribute allocation. Allocating, refunding and resetting preserve current health/stamina, clamping only when a new maximum is lower; they cannot heal or refill resources. Changes wait until the actor has finished committed actions. Online transactions are authoritative and do not pause the world.

## Weapon practice

Greatsword, spear, rapier and bow each track lifetime practice kills. Milestones at 15, 50, 100, 200 and 400 kills grant +2% damage with that weapon, to a maximum +10%. Counters are not consumed by perks or refunds and do not grant extra spendable points.

Each positive, accepted weapon contribution to an eligible enemy is recorded with its weapon identity at contact. When that enemy grants positive XP, each contributing weapon receives one practice kill. Switching weapons later cannot change the recorded contribution. Rejected damage, repeated reward callbacks, PvP and zero-XP split parents grant no practice. Partial-encounter contribution records persist with encounter state and clear with the corresponding rest/death reset. Historical `greatsword_kills` remains preserved and mirrors the greatsword practice counter for new events.

## Existing characters

Tree4 saves are validated against the immutable original catalog and level thresholds in `game/content/progression_legacy_v4.json` before conversion. Migration preserves XP, lifetime greatsword kills, inventory, currency, claims, stable IDs and world progress. Dash, Dodge and Charged Thrust remain learned and paid when previously learned; migration assigns only their minimum required attribute ranks. Other old ranks are refunded into the earned perk budget. An exact bounded original allocation receipt is retained as `migration_v4`.

The migration explanation states that old passive allocations were refunded. Dismissing it stores a local presentation preference keyed by receipt hash and offline slot or portable character ID. It never modifies a signed profile. The acknowledgement list retains at most 128 portable identities and one offline slot. Missing or corrupt preferences may safely show the explanation again.

Portable profiles are authenticated and checked against their original digest/ancestry before migration. Accepted conversion creates an ordinary durable tree5 checkpoint descended from that original profile. Dormant server tree4 records remain unchanged until accepted for use, preserving returning A→B→A lineage. Network migration and compatible content upgrades are handled by the existing dedicated persistence layer; ordinary offline saves remain separate.

## Shared policy and verification

`progression.gd` owns budgets, gates, refunds, practice counters, strict validation and pure migration. `world_rise_stats.gd` supplies numeric policy to both playable weapons and the server stat builder. Progression movement is capped at 1.25 times base speed, action-cost multipliers cannot fall below 0.5, and progression damage reduction is capped at 0.5; all current legal perk allocations stay within these bounds.

Run focused checks with disposable userdata:

```sh
./tools/platform.sh check-script scripts/world_rise_progression_fixture.gd
./tools/platform.sh check-script scripts/network/wr_actor_parity_checks.gd
./tools/platform.sh check-script scripts/network/wr_progression_migration_checks.gd
./tools/platform.sh check-script scripts/world_rise_practice_checks.gd
./tools/platform.sh check-script scripts/world_rise_progression_capture.gd --render
```

The progression fixture checks allocation boundaries, frozen legacy validation, migration refunds, JSON roundtrips, no-heal resets, strict offline saves, local notice acknowledgement and the production menu. Stat parity compares all four actual playable weapon builders and geared combinations with the authority. Network migration and practice fixtures cover durable lineage and accepted-contribution semantics. Native menu captures must be inspected after layout changes.
