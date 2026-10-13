# Quaternius candidates for later RPG development

Authorized by the user on 11 October 2026: "use all the quaternius you want." Four official creator-linked packs add 335 art/license files, 262 glTF scenes and 62 editable creature Blender sources, about 256 MB. This is a collection for later selection; no game scenes, behavior or saves were changed.

## Enemy candidates and verified clips

| Candidate | Suggested area / role | Verified glTF clips and remaining work |
| --- | --- | --- |
| [Wolf](source/quaternius-animals/glTF/Wolf.gltf) / [Blender](source/quaternius-animals/Blends/Wolf.blend) | Forest / mountain predator; strongest immediate addition | Attack, Death, two hit reactions, Gallop, Walk, jump/eat/idles; 12 clips and one skin. Native mesh 1,962 triangles. Completes the animation gap of the separately collected NewDLC wolf; no automatic replacement. |
| [Stag](source/quaternius-animals/glTF/Stag.gltf) | Forest / mountain fauna; defensive animal if requested | Headbutt, kick, death, hit reactions and movement. Prefer ambient use unless combat scope explicitly changes. |
| [Green Blob](source/quaternius-monsters/Blob/glTF/GreenBlob.gltf) / [Blender](source/quaternius-monsters/Blob/Blends/GreenBlob.blend) | Forest / cave shape variant | Bite_Front, Death, HitRecieve, Idle, Jump, Walk and social clips; 9 total. Keep the accepted wet slime shader as material reference. Vendor spelling of HitRecieve is preserved. |
| [Green Spiky Blob](source/quaternius-monsters/Blob/glTF/GreenSpikyBlob.gltf) | Forest / mountain armored variant | Blob rig/animation family; assess silhouette, recoil size and weakspot behavior before use. |
| [Mushroom King](source/quaternius-monsters/Big/glTF/MushroomKing.gltf) | Woodland boss | Big rig family with 14 clips including Punch, Weapon, Death, HitReact, Run and Walk. Weapon clip is a vendor action name, not a guarantee of an appropriate attack. |
| [Yeti, Big](source/quaternius-monsters/Big/glTF/Yeti.gltf) / [Blender](source/quaternius-monsters/Big/Blends/Yeti.blend) | Mountain enemy | 14 clips including Punch, Weapon, Death, HitReact, Run/Walk. Distinct from the small [Blob Yeti](source/quaternius-monsters/Blob/glTF/Yeti.gltf), which has the 9-clip bite family. |
| [Orc, Big](source/quaternius-monsters/Big/glTF/Orc.gltf) | Town / castle / mountain melee enemy | 14-clip Big family. Review grip, weapon geometry and attack contact before assigning existing enemy logic. |
| [Ghost](source/quaternius-monsters/Flying/glTF/Ghost.gltf) / [Blender](source/quaternius-monsters/Flying/Blends/Ghost.blend) | Castle / ruin hovering enemy | Flying_Idle, Fast_Flying, Headbutt, Punch, Death, HitReact, No, Yes; 8 clips. Needs movement/height rules; preserve current save IDs. |
| [Dragon](source/quaternius-monsters/Flying/glTF/Dragon.gltf) / [Blender](source/quaternius-monsters/Flying/Blends/Dragon.blend) | Mountain / coastal flying enemy | Same 8-clip flying family, including headbutt and punch. No verified fire-breath clip; do not assume that attack exists. |
| [Shark](source/quaternius-pirate/glTF/Characters_Shark.gltf) | Beach / water enemy | Swim, Swim_Bite, Swim_Fast; no death/hit clip. Needs water movement and gameplay design. |
| [Animated tentacle](source/quaternius-pirate/glTF/Characters_Tentacle.gltf) | Beach stationary hazard / enemy | Tentacle_Attack, Tentacle_Attack2, Tentacle_Idle, Tentacle_Poke; no death/stagger. Choose this skinned character, not the unanimated `Enemy_Tentacle.gltf` prop. |
| [Sharky](source/quaternius-pirate/glTF/Characters_Sharky.gltf) | Coastal humanoid enemy option | 15 clips including Sword, Punch, Death, HitReact, Run/Walk. Deliberately cartoon-like; compare against the existing visual profile before adoption. |

## Pack contents and environments

- [Ultimate Animated Animals](https://quaternius.com/packs/ultimateanimatedanimals.html): wolf, stag, deer, fox, two horse variants, donkey, cow, bull, alpaca, husky and shiba inu. All 12 glTFs have a skin and 12–13 clips; all have native Blender sources. Animal colors are largely simple material colors; the wolf glTF has no required image texture. Old native Blender reference-image paths can be stale without indicating missing glTF materials.
- [Ultimate Monsters](https://quaternius.com/packs/ultimatemonsters.html): 16 Big, 17 Blob and 17 Flying models. All 50 glTFs have skins and clips. Names repeat between families, so preserve folder paths. Atlas textures are embedded in glTF and supplied separately for Blender relinking. Variants include demons, ghosts, mushrooms, golem-like flyers, dragons, blobs and animal-like monsters.
- [Ultimate Fantasy RTS](https://quaternius.com/packs/ultimatefantasyrts.html): 128 glTF scenes, all static. Reusable town buildings, markets, walls/towers, ports, resources, pine/tree groups and four mountain/group forms. Upgrade/color variants contribute to the scene count. GlTF can be imported and edited in Blender; no duplicate native scenery export was downloaded.
- [Pirate Kit](https://quaternius.com/packs/piratekit.html): 72 glTF scenes, nine skinned characters. Dock segments, three palms, four cliffs, five rocks, rustic houses, ships, barrels, chests and coastal props complement the beach. Keep cannon/pirate-specific props optional to the setting.

Existing fir saplings, photographed ground and the slime's wet skin remain the visual anchors. These clean low-poly assets provide enemy rigs and kitbash geometry; their stock color/atlas look still needs an intentional comparison against our forest and Advanced materials.

## Provenance and checks

The Google Drive plugin read only public creator-linked folders/files; it did not search, modify or share the user's Drive. Metadata was checked before raw-file fetch. Every download matched the listed byte size; original SHA256 hashes and public file IDs/URLs are in `MANIFEST.json`. Returned authenticated transport URLs were temporary and deleted.

Defender scans found no threats. All 62 new `.blend` sources opened in Blender 4.5.3 with script auto-execution disabled and were not saved. No object drivers or apparently executable text were detected. All 262 new glTF structures/dependencies passed checks. These checks establish source readability/integrity, not visual quality, gameplay compatibility or an absolute malware guarantee.

Animals, Monsters and Fantasy RTS retain their supplied legacy CC0 texts; the latter two use a generic "Ultimate Platformer Pack" heading. Pirate has no supplied root license file. Current [QAL v1.0](https://quaternius.com/license.html) permits game use, modification and project collaborators, with a restriction on distributing assets as assets. Keep both declarations; conservatively follow QAL for new use. This expressly authorized exception should not be described as an unambiguously open-licensed pack or uploaded as a public asset mirror.
