World Rise v0.36.1: select World Rise — Floor 1 on the title, then Start New Game for a fresh character. The arrival platform is at the center of a 480m floating floor with large hills, grazing boar herds and a northwest wolf forest. Rest crystals heal and set respawn; ordinary packs return after rest/death while XP and treasure remain. Follow the cobbled southeast road to the Adventurers’ Guild. Copper is earned automatically on kills; E collects item/material sacks and talks to vendors. The clerk buys hides/trophies and offers two one-time hunts (10 boars: 75cp +107XP; 10 wolves: 125cp +133XP). Accept before hunting. The back armorer crafts hide torso armor and the +2% damage Cruel Charm; the sword merchant’s stock comes later. Inventory → Ingredients holds counted material stacks; Apparel equips crafted items. No hidden magic-item caches remain in World Rise. The metallic rim is walkable, but falling off it is fatal. World Rise has a separate save (F5/F9); no character import. The northern ascent gate is reserved for a later floor.

Alpha 2 v0.32.1: the west road reaches Saltwind Strand (wreck salvage), east reaches Skyglass Bluffs (burrow sentinel), north reaches Heartwood (listening bells). Wading slows movement; turn back at the deep-water warning before shoulder-depth immersion kills you. Inventory → Level Up opens Strength/Form/Mana constellations; later skills appear after prerequisites are learned. F5 saves.

Alpha 2 — The Hollow Bell: choose it on the title, choose Alpha/Beta as your import source, then Start New Game. Load Saved Game resumes its separate expedition. Speak to Mother in Hearthmere, then explore the three roads. I → Quests has the route guide. F5 saves; rest fires set respawn only. See ALPHA2.md.

v0.30.0 (2026-10-12): gameplay is FIRST PERSON ONLY. C and the pause camera selector are removed; real old saves restore first person. Legacy overhead/follow implementations remain solely for isolated physics fixtures; do not update or capture their graphics. Camera/progression/menu capture recipes now use first person. Existing half-amplitude gait and 20% parry camera motion remain. Skill catalog has Active / Passive / Capacities filters, three passive slots, existing heavy/magic slots and separate Dash/Jump slots. Passive bonuses require equipment and accept three ranks; extra ranks add 25% of the first-rank bonus. Optional per-attack upgrades add 15% damage/rank (three ranks). Thrust Control adds 15% charge-rate/rank and reduces windup, extension hold and recovery by 15%/rank; Lance Control reduces charge by 15%/rank. Stamina Capacity adds 10 maximum/rank (five ranks). Dash: learn Form then Dash, hold T up to 1.5s/release for 2.5-7m and 12-24 stamina. Shift sprint/tap Dodge and Ctrl remain unchanged. Jump: learn Form then Jump, Space, 12 stamina, actual capsule/gravity/ceiling collision; no immunity. E/Enter interact. tree_version 3 saves retain v2 XP/ranks and equip its learned passives; strict loadout validation. No Blender/model/export changes. Run focused/full source/Windows checks, first-person camera/progression/menus captures, and purge superseded release after verification.

Choose **Alpha — Existing adventure** or **Beta — Meadow & woodland** on the title screen, then Start New Game or Load Saved Game. Beta begins outdoors with the current personal heroine and only normal/sticky slimes, wolves and rats. Its F5/F9 save file is separate from Alpha. Escape → Alpha / Beta menu returns to the selector; save first to keep your current session.

# v0.36.3: Jump is a baseline movement action. Space works from a fresh game and every mode without a Form unlock or inventory equip slot. Dash remains the Form-gated T ability; jump stamina, gravity, collision and damage behavior are unchanged.

# Coastal Foundation

A 3D woodland exploration and sword-combat prototype for Windows, built from the earlier coastal character artwork. Advanced graphics now reskin the whole world with scanned vegetation, rocks and detailed surfaces. Original graphics remain available in Pause > World art.

Advanced Alpha equips the Blue-gem War Sword used in Beta, with its fitted leather back pad and steel clips. It uses the animated personal Blender heroine: chestnut shoulder-length layers, tan skin and freckles, a denim outfit, high-waisted belt and leather boots. Select Esc > Graphics & View > World art > Advanced to enable it and first person. Gameplay now uses first person only. Full resolution displays the textures without pixelation; Original restores the retained character.

Double-click **CoastalFoundation.exe**. The executable includes the game data; no engine or asset editor is needed to play. If using the ZIP, extract it before starting the game.

For the user-authored non-anime Blender model, choose **Esc > Graphics & View > Character > Standalone (static)**. This is a fixed-pose, fixed-outfit scale review at 1.67m: it moves and turns with the player, but its body and back-mounted sword have no animation. **Animated heroine** restores the active animated character. The choice is saved and applies to the inventory portrait; World art remains independent.

**Install Desktop Shortcut.cmd** creates a desktop launcher with the coastal sword-and-gem icon. Keep the extracted game folder in its final location before installing the shortcut. Run the installer again after moving that folder.

## Map Builder

Open **MapBuilder.exe** or the **Coastal Map Builder** desktop shortcut. Drag existing scenery, hills, paths, creatures and transitions into custom areas; Save, Validate, then Install or Play. **Play Custom World** on the title screen loads installed maps. Custom worlds keep separate saves. See MAP-BUILDER.md for the full workflow.

## Controls

| Control | Action |
| --- | --- |
| M (in Menagery) | Open creature spawn controls and scenery-code catalog |
| magicnow (Beta gameplay) | Add the bottomless XP potion; find it in Inventory > Potions |
| I | Open/close inventory: Equipment & Items, Skills, Level Up, Quests |
| Esc | Pause/resume; close an open inventory or conversation first |
| P | Open Level Up directly inside inventory |
| Middle mouse drag | Orbit the follow camera |
| Mouse wheel | Zoom the follow camera |
| V | Recenter behind the heroine |
| T (hold / release) | Charge and launch Dash; Dash Reach increases its distance |
| Left-click / J while holding T, sword drawn | Queue an opening swing at the dash exit; release T to dash into it |
| Mana → Flowing Splash learned | Dash swings automatically release a mana slash on follow-through, using Water Slash stamina; equip the passive for its discount |
| Mouse movement (first person) | Look around; Esc / I releases the pointer for menus |
| WASD or arrow keys | Walk freely, including diagonals |
| Hold Shift while moving | Sprint; sword drawn reaches normal walking pace |
| Ctrl / tap Shift (after Dodge unlock) | Prone dodge roll followed by stand-up |
| Space | Jump after learning and equipping it |
| E or Enter | Talk, read signs, continue dialogue |
| R | Draw or sheathe the oversized sword |
| Tap left mouse click on the world, or J | Light combo on release |
| Hold left mouse click for 0.42 seconds, or K | Heavy attack |
| Right mouse click on the world, or F | Timed parry |
| Q with the sword drawn | Equipped special: Water Slash, Water Lance or Mana Sea Dragon |
| Mouse during Sea Dragon | Steer its first-person flight for up to 10 seconds; your body remains vulnerable |
| Click a conversation choice, or Tab then Enter | Choose a response to Mother |
| F5 / Save button | Save your place |
| F9 / Load button | Load your saved place |
| Pause > Graphics & View | Select Full, Detailed, Fine or Chunky; camera mode and fullscreen |
| H / Help button | Open help |

Advanced + Full is the default. Original restores the retained faceted scenery and character. For an older GPU, start `CoastalFoundation.exe --rendering-method gl_compatibility`; this uses the same assets with ordinary fog. See ASSET-CREDITS.md for the free CC0 scenery sources. Saves and custom worlds remain outside the release folder.
| F11 | Toggle fullscreen |

Follow the path north from Coastal Path to Village Green, or south across the causeway into **Slime Forest**. Mother waits downstairs inside the west cottage on the coast. Press E at its front door to enter. Speak to her and choose **Could you take off the arm wrap?** to reveal her crude left prosthetic and cracked orange palm gem.

The drawn sword slows your walk and scrapes along the ground behind you. Attacks have a committed wind-up, blade release, and slow recovery. The release pulls the girl forward; direction stays locked until the swing ends. Face the slime before attacking. Heavy attacks are slower, stronger, and carry you farther. Shift with the sword drawn increases movement from 1.25 to 2.4, at 34 stamina per second (ordinary sheathed sprint uses 22). Rush forward for at least 0.18 seconds, then swing: light wind-up drops by 35%, heavy wind-up by 58%. Keep Shift and forward movement held while clicking: the girl immediately anticipates the swing while running. A tap releases a light cut; a hold commits a heavy cut and credits the anticipation time toward its wind-up. Walls and water still stop movement; gameplay stays on a horizontal plane.

The blue stamina bar drains when sprinting. The three light combo swings cost 20, 20, and 28 stamina; heavy swings cost 36, parries 10, and water sweeps 24. Stamina recovers after a short rest; an exhausted sprint needs 20 stamina before it resumes. Tap again after the first swing has started to queue a return cut, then tap again to queue a momentum spin. Linked strikes carry the blade and forward motion into each other, with no idle reset. Each strike spends stamina only when it starts. You can also tap within 0.65 seconds after recovery to continue the combo. Holding an attack button commits only one swing. Releasing before the heavy threshold gives a light swing; releasing outside the game or losing window focus cancels a pending charge. Committed swings cannot be cancelled.

Choose **Water Slash** or **Water Lance** from Inventory after unlocking the relevant Mana skills; the selection is saved with your equipment. Q uses the equipped special while the sword is drawn. Water Slash turns the torso and steps through a sword sweep, sending a widening fan up to 8 units; damage and opacity fade with distance, and walls block it. Water Lance costs 52 stamina and locks you in a three second charge, gathering a bright blue aura at the pommel while you brace the sword forward in both hands. It then fires a fast, narrow beam that bursts on the first enemy or wall. A direct hit deals 120 damage, with a smaller nearby blast; it opens the stone warden's armor and bypasses its normal block. Face the target and make space to charge.

Face the slime and right-click just before its lunge lands. A successful parry flashes blue, prevents damage, knocks the slime back, and staggers it for one second. The brief guard window runs from 0.20 to 0.48 seconds after starting the parry. Mistimed parries leave you vulnerable during recovery.

Talk to Mother downstairs in the west cottage to enter an illustrated conversation with dialogue choices and character cutouts over the blurred current game. Other villagers use the same mode with a friendly villager portrait. Accept her alchemical-core errand, defeat the slime, and take the southern forest trail to Warden's Hollow. Fight two briar boars that charge together, then a stone warden among dense pines and natural openings. Face the warden's thrown rock and right-click just before impact to send it back: its armor opens for five seconds, allowing sword and water damage. After the warden falls, press E beside its collapsed remains to loot a calcified aether core. Return it to Mother. Follow the old moss-covered cobbled road through both forest areas.

Defeated enemies stay defeated. Your health and stamina are shown in the screen interface; enemies have floating health bars. At zero health, the death screen waits for you to choose **Wake in the village square**. You return with full health/stamina and keep recovered components, quest progress and defeated enemies. Conversation, inventory, skills, help and death pause combat. I opens the inventory: the weapon slot unequips the sword into your bag; select the bag sword to equip it again. An unequipped sword is absent from the model and cannot be drawn or used for melee, water or parry.

Saves are local to this Windows account, in `%APPDATA%\Godot\app_userdata\Coastal Foundation\save-v1.json`. Save explicitly before closing the window. Saves include XP, learned skills, health, stamina, equipped/drawn sword state, selected special attack, Mother's arm-wrap reveal, quest progress and permanent enemy defeats. Older six-skill saves retain XP and refund their allocations into this tree. Saving/loading is unavailable during a weapon action or defeat recovery. Verification uses a separate temporary save file.

This is a reusable exploration/combat foundation with four sample areas, shared animation, modular characters, dialogue choices, and saving. The faceted heroine has layered hair and an animated pleated dress. The camera stays over each map; coast foam moves along the eastern beach. Doors are taller than the characters. The earlier girl and mother illustrations are represented by reusable rigged models.

Powered by [Godot Engine](https://godotengine.org/) 4.5.1. The engine is MIT licensed. See GODOT-LICENSE.txt and GODOT-COPYRIGHT.txt for the engine and bundled third-party notices. Art and gameplay content are project assets.

P opens the starter skill tree. First defeats and returning the core awards XP; each new level grants a point. Invest one point in a root to unlock its split. Strength and Form roots each accept five ranks; both split options can be learned for one point each. The current quest gives 355 XP, level 3 and two points. XP and unlocks survive death. Older saves receive credit for existing defeats and completed quests when loaded. See [progression details](PROGRESSION.md).

The permanent bottom controls strip is removed; use H or Help for controls. Select **Full resolution** by clicking **Detailed** once. This renders the existing Blender-exported geometry at the available window resolution with 8x MSAA and no camera pixel snapping, preserving its modeled faceted style. F11 expands the game to your display resolution; resizing updates the render size automatically. F5 saves the selected mode. The sheathed sword now rests diagonally against the back, with its hilt above one shoulder and the blade clear of the ground.

A damaging hit during Water Lance charge interrupts the spell and staggers you for .8 seconds. The beam does not fire; spent stamina remains spent. Blocked, invulnerable and zero-damage hits do not interrupt.

Unlock Driving Thrust in Form and equip it as the heavy attack in Inventory. It charges straight forward and ends in a sliding recovery. The other Form path unlocks Dodge; tap Shift within .30 seconds, or hold it longer to sprint. The roll costs 18 stamina and restores the previous sword stance after standing up.

Everfull Experience Potion: talk to the male keeper beside the Village Green well, ask for his wishing coin, then interact with the well and choose to throw it in. Open inventory [I] and drink the reusable potion for +1,000 XP per use. Spend skill points with P; F5 saves ownership and XP. Current level and XP limits still apply.

Dodge controls: Ctrl triggers immediately; Shift taps up to 0.30 seconds dodge, longer holds sprint. Learn Form then choose Dodge (compatible with Driving Thrust). Costs 18 stamina; locked/low-stamina attempts display feedback. The saved skill ID belly_roll and animation clips remain stable for compatibility.

Startup opens the title screen with Start New Game / Load Saved Game. A fresh game resets the session without deleting or overwriting the existing save; F5 is still the explicit save action. Load validates the saved file and restores map, position, equipment, health/stamina, XP/skills, story and well gift. Unusable saves disable Load; a failed load stays on the title. Title blocks gameplay input and enemy simulation. Verification/capture launch paths bypass startup; title_checks.gd and capture-windows --view title exercise the menu using separate fixture saves.

Home v0.15.0: Start New Game wakes beside the second-floor bed. Dismiss the morning message with E, walk onto the stair landing, talk to Mother downstairs and choose the morning farewell before using E at the front door to leave. Press E at the west cottage doorstep to enter again. Existing saves retain their journey and default to a completed farewell. Capture home checks both camera modes, bedroom, fireplace, farewell and door; home_checks uses a private save.

Sword hits push lighter mobs farther. Slimes and hogs recoil as Medium; the Giant Warden only recoils from a heavy attack or Driving Thrust while its armor is exposed.

## Menagery

Walk west from Village Green or Coastal Path to the signed gate. Press M to spawn any of eight practice creatures, clear them, or restore your health/stamina. Three are slime variants, including Resin slime with slowing sap patches. Thorn seeds and acorns can be parried. The practice area does not award quest progress or XP. Scenery and creatures carry stable codes; see [the shared sketch legend](MENAGERY.md).

The northern Menagery now has rolling hills (F), walk-up bluffs and a cave (G). Press E at 1G to enter; E at the southern cave doorway returns. The southern ramps are the routes onto bluffs; stone faces and cliff drops block movement.



