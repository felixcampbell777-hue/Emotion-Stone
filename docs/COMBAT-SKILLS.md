# Combat skills — v0.31.8

Learn and upgrade in Inventory > Level Up. Each rank costs one point. Existing saves remain tree version 3; no migration of earned XP or learned IDs is required.

| Skill | Prerequisite / slot | Behaviour and ranks |
| --- | --- | --- |
| Flowing Counter | Form / active counter toggle in Skills | Successful parry arms a 1.25s window. Tap left-click or J to step forward and aside into the existing return-cut trajectory, shortened to .85s. Normal return-cut stamina cost; +15% damage per rank, +.15s window for each extra rank. Three ranks. Counter can link into the existing third strike. No new invulnerability. |
| Measured Recovery | Form / one of three passive slots | A confirmed third-strike hit grants +50% stamina regeneration for 3s. Each extra rank adds 25% of the base bonus (+62.5%, +75%). Ordinary recovery gating/delay still applies. Whiffs, water effects and duplicate contacts cannot trigger it. |
| Breaker | Strength / passive slot | Accepted light hits add 1.25 pressure at rank 1; strong hits add 1.875. Further ranks increase the base buildup bonus by 25%. Small/Medium/Large/Giant thresholds are 3/4/6/8. Pressure starts fading after 4s. Breaking interrupts for 1.1s and exposes the target to +20% sword damage for 1.8s. Giants accumulate pressure only on an open weakspot; rejected armor hits add none. |
| Undertow | Water Slash / Q magic slot | Costs 28 stamina. Uses the existing water-swing body/steel path. A .5s low outward front catches enemies, then pulls inward for .85s. Range 6/6.75/7.5m; strength 1/1.2/1.4. Small/Medium/Large pull speeds 5/3.8/1.8m/s times strength; Giant zero. Stops pulling inside 1.25m. Solid scenery blocks contact/pull; actual movement still uses enemy collisions. No armor-breaching damage or separate mana resource. |

Owners: progression.json definitions and rank effects; combat_skills.gd hit-confirmed pressure/exposure; actor.gd counter/buff/action clocks; undertow.gd moving front/pull. main.gd performs real rendered-steel contacts, input and stat rebuilds. save_store.gd and progression.gd validate the additional Q ID and counter loadout flag. Old absent counter flags default false.

Counters inherit the current backhand path with explicit body/weapon entry blending; existing regular combo clips/trajectories remain untouched. All temporary clocks freeze with overlays and reset on map/new game/load/death; transient effects never save. Current procedural water shader is reused without downloads.

Focused QA: tools/platform.cmd verify-skills, capture-windows --view combat-skills --art-profile darkwood, capture-windows --view menus --art-profile darkwood, verify-windows --suite combat-skills. Preserve the previously verified unchanged animations rather than rerunning every clip. Tests use user://combat_skills_verification.json and remove it; player saves are untouched.
