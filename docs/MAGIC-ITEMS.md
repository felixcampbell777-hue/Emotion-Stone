# Magic item codex and equipment

Menagerie [M] → Magic items lists 28 wearables plus three healing draughts. Filter by category, read the effect, and Claim specimen (or Claim all test specimens). Inventory [I] → Equipment & Items: click a slot, choose an owned item; Remove restores starter clothing/empty slot. Drag the live 3D preview to rotate it. Two rings may be worn, but a unique ring cannot occupy both slots. Save explicitly to retain claims/equipment.

Wearable slots: Ring 1, Ring 2, torso, leggings, boots, headwear and necklace. The existing weapon slot still equips/unequips the greatsword. Each item has a visible bone-following cosmetic, including small ring jewels, necklace pendants, dress/armor palettes, greaves, boots and headgear. Lantern Headband provides a moving light. No new ability is unlocked by equipment alone.

Windstep is a necklace, retaining its goblin shrine discovery and +20% movement. Old charm saves migrate automatically; an explicit replacement or empty necklace stays selected. The codex's test copy can also be equipped without completing the campaign.

| Code | Item | Slot | Effect |
|---|---|---|---|
| R1 | Tidal Signet | ring | Water attacks cost 30% less stamina and deal 20% more damage. |
| R2 | Bloodbloom Ring | ring | Successful sword hits restore 3 HP. Armor-blocked hits give no healing. |
| R3 | Echo Loop | ring | A successful parry refunds 12 stamina; guard timing is widened by 0.04 seconds. |
| R4 | Starfall Band | ring | Sword damage +8%; hammer slam shockwave range +25% and force +45%. |
| T1 | Oakheart Cuirass | torso | Maximum HP +35; incoming damage reduced by 20%. |
| T2 | Stormweave Mantle | torso | Movement +10%; recover 5 additional stamina per second. |
| T3 | Duelist Jacket | torso | Sword damage +20%; parries cost 30% less stamina. |
| T4 | Tideglass Vest | torso | Water damage +35%; Water Lance charges 20% faster, but incoming damage rises 10%. |
| L1 | Reedstrider Leggings | leggings | Sprinting costs 25% less stamina; sticky terrain slow is 55% weaker. |
| L2 | Ironroot Greaves | leggings | Sword knockback +35%; incoming knockback reduced by 35%. |
| L3 | Acrobat Wraps | leggings | Dodges cost 35% less stamina; get up from rolls 25% faster. Dodge still requires its Form unlock. |
| L4 | Hunter's Legguards | leggings | All XP rewards +20%; maximum HP +10. |
| B1 | Gale Boots | boots | All movement speeds +18%, including dragging and sprinting with the sword. |
| B2 | Pilgrim Boots | boots | Recover 4 extra stamina per second; heal 1 HP per second after 4 seconds without a hit. |
| B3 | Quake Treads | boots | Hammer slam shockwave force +50% and range +35%. Stacks with Starfall. |
| B4 | Marshgrip Boots | boots | Sticky puddles cannot slow you; sprinting costs 20% less stamina. |
| H1 | Lantern Headband | headwear | A warm light follows your head and illuminates caves. Maximum HP +15. |
| H2 | Seer Circlet | headwear | Water attack range and Water Lance blast radius +25%. |
| H3 | Fox Mask | headwear | Parry window +0.08 seconds; movement +8%. |
| H4 | Phoenix Diadem | headwear | Survive one lethal hit at 1 HP, then recharge for 60 seconds of active play. Cooldown survives saves. |
| N1 | Windstep Necklace | necklace | All movement speeds +20%. The Windstep Charm from the goblin shrine now occupies this necklace slot. |
| N2 | Rootbound Locket | necklace | Maximum HP +25; heal 1 HP per second after 4 seconds without a hit. |
| N3 | River Pearl Pendant | necklace | Water attacks cost 15% less stamina and deal 15% more damage. |
| N4 | Warding Amulet | necklace | Incoming damage reduced by 12%; successful parries refund 6 stamina. |
| T5 | King's Armor: Cuirass | torso | King's Armor. Reduces incoming damage by 4%. Wear all four pieces for 3 HP/second regeneration after four seconds without damage. |
| L5 | King's Armor: Greaves | leggings | King's Armor. Reduces incoming damage by 4%. Wear all four pieces for 3 HP/second regeneration after four seconds without damage. |
| B5 | King's Armor: Boots | boots | King's Armor. Reduces incoming damage by 4%. Wear all four pieces for 3 HP/second regeneration after four seconds without damage. |
| H5 | King's Armor: Crown | headwear | King's Armor. Reduces incoming damage by 4%. Wear all four pieces for 3 HP/second regeneration after four seconds without damage. |

King's Armor uses silver plates, gold trim and a crown. Its four 4% reductions add to 16%; the complete set grants 3 HP/second after four damage-free seconds, only while alive, active and in a free movement state. Removing any piece disables regeneration immediately. Other item bonuses may combine; total damage reduction is capped at 60%. Incoming damage remains at least one point except the Phoenix lethal-hit rescue. HP regeneration pauses with menus and does not resurrect.

Effects rebuild from progression defaults rather than accumulating each time an item is equipped. Quiet regeneration and Phoenix's 60-second active cooldown freeze with menu simulation. Phoenix cooldown is saved. Bloodbloom heals only on successful sword damage; XP items affect the shared quest/mob reward path. Slots, ownership and cooldowns validate before applying a save. Test/capture paths use private saves and never overwrite player progress.

Editable catalog/set bonuses: game/content/magic_items.json; schema: schemas/magic_items.schema.json. Controller: magic_items.gd; native visual recipes: equipment_visuals.gd; inventory live preview: equipment_preview.gd. Geometry/animations remain cached. For future additions reuse the category/variant/palette and established effects, or extend schema/controller deliberately. Set bonuses reference exact item IDs across distinct categories.

Verification: tools/platform.cmd verify-magic; verify-goblins; verify; capture-windows --view magic and --view menus; verify-windows. Clearance samples five complete loadouts across 1,573 gait/combat/draw/roll poses each, excluding intentional ring/hand proximity; cached authored body/blade audit remains mandatory. Inspect native render evidence, not just headless checks. Only the manifest-selected current release survives successful cleanup.


## Healing draughts (v0.21.1)

Choose Healing draughts in the Menagerie magic codex. Claim bottles (up to 99 of each type), then Inventory → Equipment & Items → Carried Items → Drink. Each bottle is consumed from its inventory stack; the codex Add bottle button remains available to refill. Each dose stacks its healing rate, even repeated doses of the same potion, and retains an independent expiry timer; gear regeneration still applies separately. Timers freeze with menus, survives an explicit save/load, and ends on death/New Game. Potion healing starts immediately in combat and caps at maximum HP; it never revives.

| Code | Draught | Healing |
|---|---|---|
| C1 | Mending Tonic | 2 HP/second for 20 seconds |
| C2 | Renewal Draught | 6 HP/second for 8 seconds |
| C3 | Spring Elixir | 25 HP immediately, then 3 HP/second for 10 seconds |

The low-health screen edge tint uses current maximum HP, beginning below 25%. Resource text and the center remain readable. Stamina failures pulse the empty track as well as the fill, so zero stamina remains visible without action captions.

Healing stack presentation: one inventory button per potion ID with a ×N bottle count. Active healing summary groups matching potion types as ×N while retaining independent dose expirations. Saved quantities validate as integer counts 1–99; legacy single-bottle/timer saves migrate.
