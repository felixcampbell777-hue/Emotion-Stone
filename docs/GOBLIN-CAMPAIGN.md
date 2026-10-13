# Northern goblin campaign

From Village Green take the north exit to Lark Farm. Rowan offers **The Larks' Harvest** independently of Mother's quest. Tessa gives combat and shrine hints; Mira describes her stolen copper swallow. The family shares the existing animated humanoid and friendly villager conversation artwork over the blurred game view.

Route: Village Green → Lark Farm → Goblin Palisade → Smuggler Gallery → Foreman Vault. The winch opens a physical palisade gate. Silencing the bell delays the two-goblin road ambush. The gallery barricade needs two sword contacts, or can be dismantled with E after clearing its guards. Another hidden raider activates deeper inside. A sheltered fire restores health/stamina when nearby enemies are defeated. After the foreman dies, loot the supplies with E and unlock the supply tunnel, which provides travel in both directions between farm and vault. Return the supplies to Rowan for 160 XP.

Optional discoveries: Mira's small box in the gallery's western nook; loose stones in the vault's western alcove hide the Windstep shrine. Each gives 25 XP once. Windstep auto-equips and multiplies ordinary, drawn and sprint movement by 1.20. Inventory [I] → Equipment & Items → Necklace changes or removes it. Skill stat rebuilds start from original tuning, so repeated equipment/skill changes cannot stack the bonus. The charm and secrets survive death, map travel and saves.

Four goblin roles share native procedural geometry and animation. Raiders rush after a short tell; slingers throw parryable rocks; shieldguards reduce frontal damage while idle but expose themselves during their long recovery. Grub, the foreman, chains a rush into a ground-marked close cleave, which can be interrupted by parry/recoil. The foreman is Large for size-scaled knockback; other goblins are Medium. Damage, health, tells and recovery live in `game/content/goblin_campaign.json`. Fixed kill XP lives in `progression.json`: raider 30, guard 45, slinger 35, foreman 100. Ten enemies give 415 XP, plus the 160 XP turn-in and 50 XP optional discoveries: 625 XP total. They remain defeated. No infinite rewards or automatic respawn are introduced.

Balance targets a longer, harder route than Mother's opening errand, below the jungle/650-HP Queen Slime branch. Goblin individual damage is 8–15, foreman HP 145, with separated groups and rest/retreat routes. This is an initial tuning target; player feedback can adjust the data without changing art or animations.

Ownership: `goblin_campaign.gd` owns quest stages, interaction flags, ambush activation, props and legacy charm migration; magic_items.gd owns necklace effects. `goblin_enemy.gd` owns creature AI and visuals, extending shared damage/parry/recoil interfaces. The four map JSON files own placements and travel. Existing cave kit supplies physical walls and camera-only ceilings. Main only connects lifecycle, hit, dialogue, save and inventory hooks. Custom world maps do not gain campaign geometry or interactions.

Save field `goblin_campaign` contains `stage`, unique stable `flags`, and `charm_equipped`. Missing fields migrate to a fresh campaign. Unknown flags, duplicate flags, unearthed charm without an opened shrine, unowned equipped charm, and completion without foreman defeat are rejected. Never rename map, encounter or saved flag IDs without migration. The player's save is never written by verification/capture.

Checks: `tools/platform.cmd validate`, `verify-goblins`, `verify`, `verify-windows`, `capture-windows --view goblins`, and `capture-windows --view menus`. Inspect farm dialogue, closed gate, ambush, gallery fortification, vault, shrine, follow camera, necklace inventory and journal. No Blender rebuild is necessary. Preserve geometry/audit caches and purge superseded releases after successful native verification.


As of v0.21.0, Windstep occupies the necklace slot (N1 Windstep Necklace) in the shared magic-item catalog. Finding the shrine owns and equips it; old saves migrate the discovered charm into that slot. Replacing or removing the necklace preserves discovery. The old charm_equipped save field remains compatibility data; speed comes only from canonical necklace equipment. See MAGIC-ITEMS.md.


Monster cores v0.22.0: see [drop/healing/quest rules](MONSTER-CORES.md). Warden, Queen Slime and Goblin Foreman add 300, 800 and 250 XP boss bonuses respectively; prior base rewards remain. Mother now removes one canonical golem core from inventory; consumption is quest locked until completion.
