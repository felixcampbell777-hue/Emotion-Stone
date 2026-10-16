# Scenery source credits

## Standalone personal heroine (static option)

MPFB/MakeHuman core body, skin and facial assets: CC0, https://static.makehumancommunity.org/about/license.html. User-authored proportions/face/outfit assembly from `heroinedraft1.blend`, exported without a rig or animation.

- Wavy Bob (`elvs_wavy_bob`), Elvaerwyn, CC-BY: https://static.makehumancommunity.org/assets/assetpacks/hair02.html. Refitted and recolored chestnut; baked materials. Attribution licence: https://creativecommons.org/licenses/by/ .
- Cocktaildress (`punkduck_black_cocktail_dress`), punkduck, CC-BY 3.0 per local source header: https://static.makehumancommunity.org/assets/assetpacks/dress03.html and https://creativecommons.org/licenses/by/3.0/ . Recolored/retextured to denim and fitted to the user's model.
- Leather boots (`maciekg_leather_boots`), MaciekG (local source header: MGgames), CC-BY per current publisher pack listing: https://static.makehumancommunity.org/assets/assetpacks/shoes03.html. Brown leather material adaptation; local legacy MHCLO header also records AGPL3. Current publisher listing is retained as licence evidence, alongside source headers.
- Donor shirt collar/yoke (`male_casualsuit01`), MakeHuman core asset, CC0. Fitted geometry/denim recolor.
- Poly Haven Denim Fabric 05 and Brown Leather, CC0: https://polyhaven.com/a/denim_fabric_05 and https://polyhaven.com/a/brown_leather . Base color, normal and roughness baked into game PBR textures. Official hashes and Defender intake: art/source/heroine-draft-materials/LICENSE-AND-INTAKE.json.

Custom high-waisted belt, stitching, buttons, freckles, mounted sword/straps and material adaptations are project/user assets. Export recipe and source hash: art/character/standalone-export.json. No anime preset or Manga Eye material is used in this option.

## Detailed heroine

Blender Human Base Meshes bundle (CC0), complete female anatomical body topology with a locally fitted rig and retargeted project animations: https://www.blender.org/download/demo-files/ and https://developer.blender.org/docs/release_notes/3.6/asset_bundles/
Official mirror download: https://mirror.blender.org/demo/bundles/bundles-3.6/human-base-meshes-bundle-v1.0.0.zip
Archive SHA256: 46a912c0524072ac3b78c35d5d2471df7b8df102394a050ca8cd7184e3393648. Bundle README states all provided assets are CC0. Only mesh data is used; no Rain Rig, donor animations, scripts or addons are imported.

Poly Haven fabric_pattern_07 and leather_white (CC0) provide 2K fabric/leather normal and roughness maps: https://polyhaven.com/a/fabric_pattern_07 and https://polyhaven.com/a/leather_white. Official checksum/URL intake: art/character/texture-intake.json. Custom grayscale surface atlas generated for this project with imagegen; no third-party character textures are copied.

All newly downloaded scenery is free to use commercially under CC0-1.0.

Poly Haven: https://polyhaven.com/license

- fir_tree_01 and fir_sapling: conifer scans and twig imagery.
- rock_moss_set_01: six mossy rock scans and the guardian/cave surfaces.
- fern_02, grass_medium_01, tree_stump_01: woodland detail.
- forest_ground_04, forest_leaves_02, leafy_grass: soil, moss and meadow surfaces.
- rocky_trail, cobblestone_floor_08: trails and the old forest road.
- pine_bark and brown_planks_05: bark/wood surface detail.

Each asset has a public source page at https://polyhaven.com/a/ASSET_ID. Raw source files, official download URLs and hashes are preserved in art/environment/source/polyhaven_cc0 and its intake manifests. Runtime GLBs are optimized derivatives, with the original scans retained separately.

Quaternius Medieval Village MegaKit (Standard edition), CC0:
https://quaternius.com/packs/medievalvillagemegakit.html

Selected tiled roof and uneven-brick wall modules, plaster/brick materials. The supplied License_Standard.txt remains with the source and selected runtime kit. Original game character artwork, editable humanoid/sword and authored animations remain project assets, independently of these scenery kits.

Only mesh, texture, buffer, licence and metadata files were accepted from asset downloads. No asset-pack executable, installer, script or editor add-on was executed. Windows Defender scan records are stored with the local intake. This is a record of checks performed, not an absolute guarantee against all malware.


## Beta meadow

The Beta heroine uses the current non-anime personal MakeHuman/MPFB figure, with CC0 sonntag78 Junglebook hair and existing denim/leather materials. Saved personal source is untouched; the sixteen deform bones and nineteen motions in its derived export reuse the project’s authored animation library.

Beta shirt v0.27.1 adds continuous skinned back/shoulder coverage in the separate editable Beta source. Its seamless panel reuses the already collected/scanned CC0 Poly Haven Denim Fabric 05 maps, matching the existing baked outfit tint. Provenance remains art/source/heroine-draft-materials/LICENSE-AND-INTAKE.json. Current saved-source/export hashes: art/character/beta-heroine-export.json. No additional download was needed.

Wolf: Quaternius Animated Animal Pack, supplied wolf skin and Attack/Walk/Gallop/Hit/Death animations. https://quaternius.com/packs/animatedanimals.html . Legacy pack CC0 notice and current Quaternius Asset License are retained in art/library. Conservatively use in the embedded game only; do not redistribute the source kit as a standalone asset product.

Beta wolf v0.27.0 derives smoother weighted geometry from that already collected donor. Original deterministic fur albedo/normal/roughness maps and tapered skinned tufts by the Coastal Foundation project are CC0-1.0. Editable source: art/source/beta-wolf.blend. Source/export/donor hashes: art/library/beta-wolf-customization.json. Original texture recipe/hashes: art/library/wolf-fur-textures.json. No new remote assets or executable code were downloaded for this update.

Rat: CDmir / TinyWorlds, Evil Giant Rat, CC0-1.0, with supplied existing skin and six motion clips. https://opengameart.org/content/evil-giant-rat . Source hashes and runtime export: art/library/BETA-RUNTIME-ASSETS.json. Existing trusted intake/Defender scans cover both source kits.

Beta longsword: Quandtum, Long Sword – Knights Trust, CC0-1.0. https://opengameart.org/content/long-sword-%E2%80%93-knights-trust . Customized actual donor diamond blade topology in Blender: removed decorative wings/gold sunburst, shortened and narrowed steel, reduced thickness, replaced the hilt with a restrained crossguard, oval leather wrap and small blue wheel-pommel inset. Downloaded only from the creator's official OpenGameArt upload, with TLS and no redirects; Defender scans of archive and extracted data found no threats. Intake/hashes/license: art/library/source/quandtum-knights-trust/INTAKE.json; scanner records: art/library/security/beta-sword-*.json. Downloaded text/addon materials were never executed or exported. Editable derived source: art/source/beta-greatsword.blend; runtime: greatsword-beta.glb; customization/reopen checks and actual Blender renders: art/character/beta-sword-review. New hilt/customization is also CC0. Beta's inventory icon is a transparent Blender render of this actual customized sword, generated by tools/render_beta_sword_icon.py.


Beta v0.28.0 locomotion: Quaternius and Gonzalo Furnier, Universal Animation Library free Standard, creator upload 17958403; supplied CC0 License.txt and user-authorized Quaternius use. Walk_Loop/Jog_Fwd_Loop/Sprint_Loop sampled through native glTF parsing, fitted to the current rig. Provenance/hashes/two successful Defender scans: art/library/source/quaternius-human-motion/INTAKE.json. Creator: https://quaternius.itch.io/universal-animation-library . Raw mannequin/source pack is not shipped. Broad war sword blade is original CC0 geometry; scanned Quandtum-derived hilt retained.


## Alpha 2 regional art (v0.32.1)

Existing collected assets only; no new downloads. Donors are not modified. Blender runs with auto-execution disabled; embedded texts/drivers are removed only from the derived export session. Hash validation is recorded in art/library/ALPHA2-RUNTIME-ASSETS.json. Existing intake/security records remain under art/library.

- **Animated Crab**, CoinCoin: https://opengameart.org/content/animated-crab — **CC-BY-4.0**, https://creativecommons.org/licenses/by/4.0/ . Runtime conversion from supplied FBX; repaired local texture paths, material tuning, renamed animation aliases, gameplay scale and crab/sentinel behaviors. Original wood/metal mining-crab design retained.
- **Spider Animated**, Panther-One: https://opengameart.org/content/spider-animated — **CC-BY-3.0**, https://creativecommons.org/licenses/by/3.0/ . Repaired supplied texture, Principled conversion, subdivision/smooth normals, alias clips and game fitting/skitter behavior. This is not the CC0 TinyWorlds spider.
- **Boar**, Teh_Bucket: https://opengameart.org/content/boar — CC0-1.0. Original texture and clips; subdivision/smooth normals, material conversion and fitting.
- **Forest Monster**, CDmir / TinyWorlds: https://opengameart.org/content/forest-monster — CC0-1.0. Supplied skin/normal/tree maps and rig/clips; material conversion and Bellkeeper behavior/fitting.
- **Pirate Kit**, Kenney: https://kenney.nl/assets/pirate-kit — CC0-1.0. Selected wreck, dock, watchtower and barrel; fitted and retextured with existing licensed wood/brick.
- **Poly Haven**, CC0-1.0: coastal_cliff_01, coast_rocks_01, boulder_01, rock_moss_set_02, nettle_plant, flower_heliophila; coast_sand_01, damp_beach_sand, cliff_side, rock_face, castle_brick_01. Sources: https://polyhaven.com/a/ASSET_ID ; license https://polyhaven.com/license . Runtime mesh budgets/material fitting; photographed textures retained. Existing fir/fern/grass/forest-floor library supplies forest continuity.
- Timber Wolf reuses the current customized Beta wolf and embedded-game license described above. No source kit redistributed as a standalone asset pack.

Alpha 2 Wreck Rats reuse the existing CDmir / TinyWorlds CC0 Evil Giant Rat donor and runtime Beta skin/clips described above. Constellation graphics and thornseed/root effects are original procedural game artwork; no Skyrim assets are distributed.


## Original Dreadmore assets

Orchid Stalker geometry, articulated part hierarchy and chitin image are locally authored original assets, guided by the user-selected concept C. Editable source and hashes: art/source/environments/dreadmore/runtime-assets.json. No third-party scripts or downloads were used. Canyon walls reuse the existing credited CC0 rock-face textures; existing licensed trees and ferns are reused. The AI-generated concept board is a design reference, not an imported gameplay mesh.


## World Rise backdrop

Mountain geometry and vertex colors, repeat/ring scenes and cloud shaders are original locally authored assets. Source/export hashes are recorded in art/source/environments/world-rise/runtime-assets.json. The mountain shader reuses the existing Poly Haven CC0 rock_face albedo credited above. No new downloads or third-party executable scripts.
