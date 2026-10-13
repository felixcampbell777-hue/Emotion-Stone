# Monster cores

Actual monster defeats roll a visible ground core. Approach and press E to loot it; Inventory [I] → Equipment & Items → Carried Items consumes one from its ×N stack. Healing is immediate and uses current maximum HP, so Strength/equipment increases also increase core healing. No overheal or revival. Pending pickups and inventory quantities survive map travel, death and explicit Save/Load. Loading a defeated encounter never rerolls its drop.

Only listed monster profiles drop cores. Boars, piglets, bats, hares/rabbits and squirrels are beasts: ordinary XP remains, no core roll. Human NPCs never drop cores. Puffcaps are fungal monsters; legacy wisps remain supported, with no new wisp encounter. All active slime types, including Queen brood/tree ambushes, goblins and the stone warden are covered. Fresh Menagerie/timed respawn kills can produce new drops; clearing/replacing actors produces neither drops nor XP.

The first roll is whether a core drops. A successful ordinary monster drop makes a second roll for its special variant; otherwise it uses the family core. Resin Slime: 50% core roll × 5% conditional Sticky chance = 2.5% overall Sticky, 47.5% overall generic, 50% no core. Bosses guarantee their named core; bonus XP is added once on defeat through the existing shared XP path, including any equipped XP bonus.

| Monster | Core drop | Special on successful drop | Boss XP bonus |
|---|---|---|---|
| slime | 50% | — | 0 |
| moss_slime | 50% | moss_core: 8% | 0 |
| resin_slime | 50% | sticky_core: 5% | 0 |
| bramble_slime | 50% | bramble_core: 10% | 0 |
| green_slime | 50% | spring_core: 3% | 0 |
| goblin_raider | 40% | raider_core: 8% | 0 |
| goblin_guard | 65% | guard_core: 12% | 0 |
| goblin_slinger | 35% | slinger_core: 10% | 0 |
| puffcap | 45% | bloom_core: 8% | 0 |
| wisp | 55% | thorn_core: 10% | 0 |
| warden | 100% | — | 300 |
| queen_slime | 100% | — | 800 |
| goblin_foreman | 100% | — | 250 |

| Core | Heals maximum HP |
|---|---|
| Slime Core | 10% |
| Moss Slime Core | 12% |
| Sticky Slime Core | 15% |
| Bramble Slime Core | 18% |
| Verdant Slime Core | 12% |
| Goblin Core | 12% |
| Raider Goblin Core | 16% |
| Ironbound Goblin Core | 22% |
| Stone-Slinger Core | 18% |
| Spore Core | 12% |
| Puffcap Bloom Core | 18% |
| Spirit Core | 15% |
| Thorn Spirit Core | 20% |
| Calcified Aether Core | 40% |
| Royal Slime Core | 50% |
| Goblin Foreman Core | 30% |

Boss totals before equipment XP bonuses: Stone Warden 120 + 300 = 420 XP; Queen Slime 400 + 800 = 1,200 XP; Goblin Foreman 100 + 250 = 350 XP. Mother's quest still gives 80 XP and farm turn-in 160 XP separately.

Mother's calcified aether core is the same golem_core inventory item. The story Warden's guaranteed drop stays in its authored remains; E after accepting Mother's quest grants one and marks component_ready. Trying to consume any golem core before her quest is complete opens “This may be useful.” and leaves health/count unchanged. The modal pauses combat and closes with Keep the core, Escape or I. Giving Mother the component removes exactly one from the stack, completes the existing quest once and restores health/stamina. Spare golem cores then heal 40%. Legacy component-ready saves automatically acquire the required missing inventory core without repeating kill XP.

Menagerie [M] → Monster cores lists rates/healing, Add test core and Add 5. These test grants give no XP and still obey the quest lock. Normal item stacks remain unique per type, up to 99,999 cores.

Editable tuning: game/content/monster_cores.json and schemas/monster_cores.schema.json. Runtime owner: monster_cores.gd; UI: core_codex.gd/inventory.gd. Death reward integrations: main.gd, menagery.gd, mob_respawn.gd and queen_slime.gd. Save validation rejects unknown IDs, invalid counts, duplicate pickup identities and invalid map positions. Tests use private save files; never write player saves for verification.

Run tools/platform.cmd verify-cores, verify, capture-windows --view cores/quest/menus, verify-windows. Focused tests cover conditional boundaries and a 10,000-roll grid, guaranteed bosses, beast exclusion, actual E pickup/inventory buttons, percentage scaling, pending pickup persistence, malformed saves, quest lock/migration, real Warden/Queen deaths and deduplication. Inspect native quest-lock, ground loot, stacked inventory and Mother turn-in images. Preserve current assets/caches; purge older release only after successful native checks.
