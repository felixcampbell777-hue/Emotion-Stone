# Open asset library for future RPG development

Follow-up v0.24.0: the user subsequently authorized a playable Beta and character animation. The current prototype uses selected library wolf/rat assets and the personal heroine with reused project motions; see [BETA.md](BETA.md). The intake-only scope described below records the earlier collection phase.

Collected and checked 11 October 2026. Sources are stored in `C:\Games\CoastalFoundation\art\library\source`. This is a reusable development library, separate from the live Godot project. No creature was spawned, game material replaced, encounter changed, animation retargeted, release rebuilt, or purchase made.

The intake contains **34 collections, 791 original art/license files, approximately 515 MB (491 MiB)**. The original 30 collections contribute 12 individual animal/creature sources, a fox, four skeleton characters in one pack, three modular scenery kits, six photographed nature models, and seven PBR material sets. Following the user's explicit "use all the quaternius you want" instruction, four Quaternius packs add 12 animals, 50 monsters, 128 fantasy scenery models and 72 pirate/coastal models. There are **601 glTF/GLB scene files**, with 73 native Blender files inspected. Scene counts are not counts of unique enemies.

## Strategy from the development community

The research began with community discussions about asset sources, licensing, visual consistency, and the Blender/Godot pipeline. These are discovery leads; the publisher's actual license and downloaded contents determine acceptance.

| Discussion | Useful lesson for this project |
| --- | --- |
| [Community asset list and licensing discussion](https://www.reddit.com/r/gamedev/comments/1m76pm4/the_ultimate_free_game_dev_asset_list_50_sites/) | Maintain an asset-by-asset source/license ledger. A free download can still have attribution, noncommercial, or other restrictions. |
| [License-risk resource discussion](https://www.reddit.com/r/gamedev/comments/1w57t2p/free_game_dev_resources_sorted_by_licence_risk/) | Prefer established CC0 libraries, but verify current licenses. This list still calls Quaternius CC0; its current publisher license illustrates why lists cannot be authoritative. |
| [Developer source recommendations](https://www.reddit.com/r/gamedev/comments/1qhuwg8/where_i_actually_find_free_game_assets_compiled/) | Find assets through known libraries, then obtain the original creator's files. Reuse and material adaptation are more useful than collecting unrelated styles. |
| [Blender-to-Godot pipeline discussion](https://www.reddit.com/r/godot/comments/1co4qij/hot_reloading_for_a_gltf_import_pipeline/) | Keep an explicit interchange workflow, with game behavior outside imported art. Avoid installing an extra pipeline plugin merely to use meshes. |
| [Small-world Blender/Godot workflow](https://www.reddit.com/r/godot/comments/1toda72/building_a_tiny_open_world_in_godot_with_blender/) | Reusable components and controlled tooling help a small project grow; an enormous ready-made world is less useful than compatible source assets. |
| [Style-consistency problem](https://www.reddit.com/r/gamedev/comments/1rixmah/solo_dev_torn_between_learning_blender_vs_buying/) | Mixed free packs need deliberate material, scale, silhouette, and lighting decisions. Their presence in the library is not visual approval. |

My recommendation is to extend the current photographed woodland environment with Poly Haven scans and materials, while selecting enemy art by rig quality, useful clips, and silhouette. Keep Kenney/KayKit as a coherent stylized alternative and modular construction source. Their clean silhouettes suit the Original profile more immediately than the detailed Advanced woodland; final use needs a visual comparison in both camera modes.

| Approach | Decision in the context of this game |
| --- | --- |
| Curated photographed nature + selected rigged creatures | Preferred. Extends the existing fir sapling, ground, fern, and mossy-rock vocabulary while filling enemy gaps. |
| One stylized ecosystem | Useful fallback and kitbash source. User-authorized Quaternius creatures/scenery join Kenney structures and KayKit skeletons; their consistent silhouettes help prototypes, but need adaptation to the current grounded world. |
| Individual community models | Accepted from established, identified creator uploads on OpenGameArt with per-asset licenses, local source inspection, and scans. Older materials may need rebuilding. |
| Build every model from scratch | Reserve for distinctive hero/boss requirements and missing actions. Do not restart the paused heroine or retarget its animations from this research request. |
| Free assets under restricted terms | Quaternius is explicitly authorized as an exception; its current QAL terms are recorded separately. Other unclear/restricted candidates remain excluded. Free/royalty-free is not the same as open-licensed. Paid options are links only. |

Godot [recommends glTF 2.0](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html). Keep editable Blender sources outside `game/`, prepare selected GLBs through existing tools, and attach gameplay through local scenes/controllers. OBJ does not carry rigs or animations. Do not copy vendor demo projects or scripts into the game.

For larger towns and forests, use [automatic mesh LOD](https://docs.godotengine.org/en/4.5/tutorials/3d/mesh_lod.html), deliberate occlusion, and [spatially grouped MultiMeshes](https://docs.godotengine.org/en/4.5/tutorials/performance/using_multimesh.html) for repeated static plants/props. A whole biome in one MultiMesh loses individual culling. These are integration recommendations, not changes performed by this intake.

## Preserve the strengths already in the game

The slime's wet skin is the project's procedural `game/shaders/slime_surface.gdshader`, with ripple, marbling, clearcoat, and a menu-paused creature clock. It does not need a replacement downloaded skin texture. Extend it through controlled biome tint/material variants when requested.

The small pines are the existing Poly Haven `fir_sapling` sources; mature firs, fern, grass, stump, mossy rocks, forest ground, trail, cobbles, and planks are already collected. This intake adds different plants, stone forms, beach surfaces, mountain surfaces, and architecture rather than redownloading those assets. Existing Quaternius architecture/nature source kits remain intact.

Retain the current boar/goblin/Warden behavior, timed parries, recoil sizes, sword contacts, stable map/creature IDs, saves, rewards, and menu gating during later art adoption. Ordinary animals remain outside monster-core profiles; an undead squirrel would be a separate enemy identity. No outside skeleton is assumed compatible with the heroine's rig.

## Animal and enemy sources actually collected

Triangle/action counts below come from read-only inspection of downloaded Blender data, before modifiers. Named actions include pose/helper actions and are not a promise that every action is game-ready. The FBX and GLB inspections verify contents, not visual quality or combat behavior.

| Asset and source | License | Verified contents / practical use |
| --- | --- | --- |
| [Boar — Teh_Bucket](https://opengameart.org/content/boar) | CC0 | Editable Blender, packed color texture, 572 triangles; attack/default/walk. First comparison candidate for the existing boars. Death/stagger still need work. |
| [Evil Giant Rat — CDmir/TinyWorlds](https://opengameart.org/content/evil-giant-rat) | CC0 | Blender, packed textures, 6,190 triangles, 14 actions including attack/run/walk/hit/die. Town cellars, sewers, castle stores. Optimize before large swarms. |
| [Forest Monster — CDmir/TinyWorlds](https://opengameart.org/content/forest-monster) | CC0 | Blender plus maps; 6,648 triangles, 6 actions including attack/walk/dying. Strong woodland boss or mountain creature candidate. Publisher credits Rick Hoppmann for source textures. |
| [Goblin — CDmir/TinyWorlds](https://opengameart.org/content/goblin-1) | CC0 | Blender, packed maps, 3,746 triangles, 12 actions including attacks/run/walk/die. Future campaign art option; not a replacement installed now. |
| [Mudeater — CDmir/TinyWorlds](https://opengameart.org/content/mudeater-animated) | CC0 | Blender, packed maps, 4,274 triangles, 29 actions including unarmed combat and directional movement. Humanoid brawler/NPC candidate; does not automatically fit every creature role. |
| [Undead Squirrel — CDmir](https://opengameart.org/content/undead-squirrel-animated) | CC0 | Blender with external maps, 5,522 triangles, 28 actions including attacks, jumps, pain, run, and death. A forest enemy distinct from ordinary ambient squirrels. |
| [Spider — Panther-One](https://opengameart.org/content/spider-animated) | CC BY 3.0 | Blender, diffuse texture, 448 triangles; only stand/walk. Cheap forest/cave/castle enemy base; attack/death need authoring. Old texture path needs relinking to the supplied `Spider_0.png`. |
| [Animated Crab — CoinCoin](https://opengameart.org/content/animated-crab) | CC BY 4.0 | FBX imports read-only in Blender 4.5.3; 45-bone rig, 10 actions including attack/hit/death/burrow. Contains cart/frame meshes and plank/metal maps: inspect/remove mining props before choosing a natural beach crab. |
| [Wolf — NewDLC](https://opengameart.org/content/3d-wolf) | CC0 | Blender and color/normal/roughness/specular maps; 5,358 triangles, rig present, **zero actions**. Good forest/mountain base, not an animated enemy ready to drop in. |
| [Female Deer — CDmir/TinyWorlds](https://opengameart.org/content/deer-female) | CC0 | Blender, packed textures; 4,786 triangles, 11 actions including run/idle/eat/death. Ambient woodland/mountain fauna first. |
| [Male Deer — CDmir/TinyWorlds](https://opengameart.org/content/old-deer-male) | CC0 | Blender, packed maps; 4,926 triangles, 10 actions including run/idle/eat/death. Ambient stag. |
| [Rabbit — CDmir/TinyWorlds](https://opengameart.org/content/rabbit-0) | CC0 | Blender, packed maps; 2,642 triangles, 10 actions including jump/run/sit/death. Ambient fauna. |
| [Fox — Khronos sample asset](https://github.com/KhronosGroup/glTF-Sample-Assets/tree/edc7c9e67c639d230715049ee31f9a96a6babbbe/Models/Fox) | CC0 mesh; CC BY 4.0 animation | GLB with Survey/Walk/Run. Ambient fox and interoperability reference; no attack/death. Credit PixelMannen, tomkranis, AsoboStudio, and scurest with their stated roles. |
| [KayKit Skeletons — Kay Lousberg](https://kaylousberg.itch.io/kaykit-skeletons) | CC0 | Four verified skinned GLBs: Mage, Minion, Rogue, Warrior, **95 clips each**, plus 13 equipment scenes. Strongest broad enemy pack for ruins/castles/mines. Obtained from the creator's linked GitHub at a pinned commit; no plugin installed. Free tier has no native `.blend`; GLBs can be edited in Blender. |

Priority for later review: **Quaternius animated wolf, rat, forest monster, goblin, skeletons, boar**, then crab, Quaternius blob/yeti/ghost/dragon, shark and tentacle. They supply useful combat clips. The original NewDLC wolf and spider require missing actions; Quaternius now supplies a separate wolf with attack/death/hit reactions. Deer/rabbit/fox improve wildlife without expanding combat scope. See [the Quaternius priorities](../art/library/QUATERNIUS-PRIORITIES.md) for exact file choices and clip limitations.

## Coverage for the four planned environments

| Area | Collected additions | Existing assets to reuse / remaining gaps |
| --- | --- | --- |
| Forest | [Nettle](https://polyhaven.com/a/nettle_plant), [Heliophila flowers](https://polyhaven.com/a/flower_heliophila), [second moss-rock set](https://polyhaven.com/a/rock_moss_set_02); deer, rabbit, fox, boar, animated Quaternius wolf, forest monster, spider, undead squirrel, blob/mushroom creatures | Keep the accepted small pines, fir canopies, fern/grass/stump, forest ground and slime wet shader. Quaternius pines are stylized options; its blobs are shape/rig alternatives, while the accepted slime surface remains the material reference. |
| Large town / castle | [Kenney Fantasy Town Kit](https://kenney.nl/assets/fantasy-town-kit), [Castle Kit](https://kenney.nl/assets/castle-kit), [Castle Brick 01](https://polyhaven.com/a/castle_brick_01), [Plaster Stone Wall 01](https://polyhaven.com/a/plaster_stone_wall_01), [Quaternius Fantasy RTS](https://quaternius.com/packs/ultimatefantasyrts.html); rats, goblin, skeleton, orc and ghost variants | RTS contributes 128 scenery scenes including house/building upgrades, walls/towers, markets and ports. Reuse existing timber/cobble/roof sources. Street layout, interiors, navigation and collision remain project work. |
| Beach | [Kenney Pirate Kit](https://kenney.nl/assets/pirate-kit), [Quaternius Pirate Kit](https://quaternius.com/packs/piratekit.html), [Coast Rocks 01](https://polyhaven.com/a/coast_rocks_01), [Coastal Cliff 01](https://polyhaven.com/a/coastal_cliff_01), [Coast Sand 01](https://polyhaven.com/a/coast_sand_01), [Damp Beach Sand](https://polyhaven.com/a/damp_beach_sand); crab, animated shark and tentacle | Quaternius contributes 72 scenes including dock segments, palms, cliffs, rocks, houses, ships and characters. Shark has swim/bite, tentacle has two attacks; death/stagger gaps are recorded. Crab has attached mining props. Waves, shoreline transitions and gameplay water remain project work. |
| Mountain | [Boulder 01](https://polyhaven.com/a/boulder_01), coastal cliff as a reusable landform, [Rock Face](https://polyhaven.com/a/rock_face), [Cliff Side](https://polyhaven.com/a/cliff_side), [Snow 02](https://polyhaven.com/a/snow_02), Quaternius mountain groups; animated wolf, yeti, flying dragon, forest creature, skeletons/mines | Use the current terrain/builder workflow for traversable mountain shapes. Scans and stylized mountain meshes need geometry budgets/LOD and intentional collisions. Wolf now has combat clips; flying monsters still need flight/navigation behavior and attack review. |

Poly Haven [licenses its assets CC0](https://polyhaven.com/license). New model sources include 1K glTF materials and all referenced mesh buffers/textures. New tiled materials include 2K albedo, OpenGL normal, and roughness. Publisher MD5/size and local SHA256 checks passed. Higher resolutions and native Blender variants can be fetched later from the retained official metadata if necessary; they were not redundantly downloaded now.

## Licensing exclusions and paid links saved for later

**Quaternius is now collected under the user's explicit authorization (11 October 2026).** [Animals](https://quaternius.com/packs/ultimateanimatedanimals.html), [Monsters](https://quaternius.com/packs/ultimatemonsters.html), [Fantasy RTS](https://quaternius.com/packs/ultimatefantasyrts.html) and [Pirate](https://quaternius.com/packs/piratekit.html) were obtained from their official creator-linked Google Drive folders through authenticated raw-file fetches. Animal/monster Blender sources and glTF are retained; scenery glTF can be edited in Blender. Duplicate FBX/OBJ exports and combined showcase scenes were omitted.

Animals, Monsters and Fantasy RTS supply CC0 license text; the Monsters/RTS generic text is titled "Ultimate Platformer Pack," which is retained verbatim rather than silently corrected. Pirate supplies no root license file. The publisher's [current QAL v1.0](https://quaternius.com/license.html), updated 28 August 2026, allows use/modification in commercial games and collaboration, but restricts standalone asset redistribution. Old pack pages still show CC0 badges. Both declarations are retained. Conservatively treat new use as subject to QAL and keep the raw Quaternius library private to this game's collaborators; no blanket claim that these new downloads are unambiguously open-licensed. Current license-page evidence is in `art/library/QUATERNIUS-LICENSE-PAGE.txt`.

Other marketplace, aggregator, anonymous-mirror, installer, and unclear-license candidates were not collected. OpenGameArt was treated as a host for identified creator submissions, not as a blanket license or guarantee of ownership. CC BY assets need author credit, a license/source link, and an indication of modifications; their receipts remain beside the source. None of this collection is CC BY-NC. Quaternius's current restricted terms are the expressly authorized exception.

| Paid bookmark | Observed price / reason to keep the link |
| --- | --- |
| [Kenney Game Assets All-in-1](https://kenney.itch.io/kenney-game-assets) | **$19.95 USD**, 60,000+ assets, CC0, future updates. A convenience download of otherwise free packs. Strong value for coherent props/UI/audio; not a solution for realistic animated predators. Optional launcher is unnecessary for asset use. |
| [Complete KayKit](https://kaylousberg.itch.io/kaykit-complete) | **$150 USD**, publisher lists $248 individual source-tier value, current and future packs, native Blender sources, extra characters/animation content, CC0. Broader editable stylized collection; a worthwhile comparison if this style is selected. |
| [Skeletons source tier](https://kaylousberg.itch.io/kaykit-skeletons) | **$11.95 USD** for `.blend` sources plus extra characters; $7.95 extra tier adds golem/necromancer. Targeted option if four free skeletons prove useful. |

Prices were checked 11 October 2026 and can change. Nothing was purchased or subscribed to. These bookmarks stay available for a later decision; no scheduled buying/monitoring was created.

## Intake evidence and handoff

- `art/library/MANIFEST.json`: collection records, exact download URLs, pinned GitHub revisions, hashes, excluded files, glTF rig/clip inventories.
- `art/library/LICENSE-EVIDENCE.json` and per-collection `LICENSE-AND-SOURCE.txt`: publisher license fields and credit requirements. Original supplied license files and embedded Blender license notes remain intact.
- `art/library/BLENDER-INVENTORY.json`: 73 Blender files opened with auto-execution disabled, plus the read-only crab FBX import. Blender sources were not saved. No object drivers or apparently executable embedded text were found in the inspected Blender files. Legacy Blender files may contain stale image/reference paths; the new glTF materials and dependencies were validated separately.
- `art/library/security/`: Defender archive/source/final-library scan receipts and antivirus status. Final scan exited 0 and detected no threats. **No antivirus can guarantee absolute virus freedom.** Only identified sources over HTTPS were used; unexpected redirects were refused. No downloaded executable, installer, add-on, script, or Godot project was run.
- `art/library/VALIDATION.json`: source hashes, 601 glTF/GLB structures/dependencies, Blender readability, license checks, zero retained transport archives, and preserved current release/source/evidence checks.
- `art/library/PRESERVATION.json`: game sources, editable assets, release and indexed game-render evidence remain intact. Two personal hair review images and three current-image aliases were updated by the concurrent authorized work in "Plan 3D pixel game platform"; those updates and their hashes are recorded in `CONCURRENT-WORK.json`, preserved, and distinguished from unexpected changes. Concurrent additions are retained. Only `output/windows/v0.23.3` remains.

Recipes are `tools/collect_open_assets.py`, `tools/collect_quaternius_assets.py`, `tools/inspect_library_blends.py`, and `tools/report_open_assets.py`. `QUATERNIUS-DOWNLOAD-PLAN.json` retains public Drive file metadata and creator-folder provenance; ephemeral authenticated transfer URLs were consumed then deleted. Intake validation is not a gameplay test or visual sign-off. The source library is current reusable material, not superseded exports. No replacement-release cleanup was needed. During later selection, rebuild old materials where required, relink the spider diffuse map, inspect combat clips/scale/grounding in Godot, and use the project's existing capture and verification gates before publishing an integration.
