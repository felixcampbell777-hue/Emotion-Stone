# Separate heroine anime preset study

2026-10-10. User authorized trying openly licensed face/eye presets after rejecting the enlarged realistic-eye study. Current alternate: `C:\Users\felix\OneDrive\Documents\heroinedraft-anime.blend`. It replaces the rejected alternate only; main `heroinedraft1.blend` stays byte-for-byte unchanged. This is a static comparison awaiting user review, not approved art or a game asset.

Current eye reference: `C:\Users\felix\AppData\Local\Temp\codex-clipboard-ff69ee15-bc53-4267-b1f2-3355d0aeecd1.png`: bold upper lash, clean lower lid, oval reddish-brown iris, dark pupil and small white catchlight. Do not restore the rejected swollen realistic eye rims/heavy lower eyelashes.

## Assets actually tested

- [MakeHuman cartoon01](https://static.makehumancommunity.org/assets/assetpacks/cartoon01.html), CC0 targets by SpamRakuen. Enhanced head-only alone produced narrow eyes and an awkward lower face with current macros. Current recipe blends `spamrakuen_toon_eyes_and_slim_body_head_only` at .65, `spamrakuen_anime_stylized_enhanced_head_only` at .20 and the SR female lip target at .20, plus .30 native nose depth reduction. Face morphs fade only through neck basis Z 1.36-1.40; the original higher mask clipped chin deformation. Body below the neck mask, original macro sliders, rig and clothing/equipment geometry remain unchanged.
- [Manga Eye / mngeye_base.blend by MITSUDA Tetsuo (lab1092)](https://note.com/lab1092/n/ne7cd24b488bb), [CC0 listing](https://blendswap.com/blend/25062). Native procedural iris/pupil graph loads in Blender 5.2.2. Append material only, not downloaded scene objects/scripts. Explicit projected globe UVs, transparent outer shells, burgundy/brown colors and a small custom catchlight fit it to MPFB eyes. Native lower lashes are hidden in the alternate; custom upper ribbons trace visible globe/skin contacts. These ribbons are static, not animation-ready.

Head shading is simplified with restrained freckles. User-selected Wavy Bob is refitted through its original MHCLO, not replaced. Denim, hair and leather receive modest saturation changes in the alternate. Main appearance stays unchanged. Actual inspected front/three-quarter/profile renders show closer graphic eyes, but the nose/mouth and existing hair still do not adequately match the reference. Do not present this preset combination as a finished or approved design.

Recipe: `tools/personal_heroine_anime.py`, `tools/heroine_anime_style.py` and shared face-fitting/audit helpers. Start from main using Blender 5.2.2 with `--disable-autoexec`; never save these newer files using project Blender 4.5. Main SHA256: `20bdf232e6b7cebbbcc8d29a80960fa60ccead6fded5da76981caabb852e3f33`. Current saved/reopened checks and actual model renders: `output/verification/user-heroine-anime-draft/`. Evidence replaces older rejected candidates. Preserve the intentional main/alternate pair; no obsolete variant/backup copies.

## Intake and approval gate

Origins, CC0 evidence, SHA256 hashes, validated archive contents and successful Defender scan are recorded in `art/source/heroine-anime-presets/LICENSE-AND-INTAKE.json`. Downloader: `tools/fetch_heroine_anime_presets.py`. Defender reported no threats; this is a scan result, not an absolute malware guarantee. Downloaded Blender data contains no Text datablocks and is loaded with auto-execution disabled.

User verification precedes animations, retargeting, export or game integration. Blender procedural eyes require baking or an equivalent Godot shader after design approval. No playable game changes/release replacement were made. Only manifest-selected Windows v0.23.2 remains.

Unused researched alternatives: [crute_1046464 CC0 shader](https://blendswap.com/blend/23319); MB-Lab anime bases use [AGPL data licensing](https://mb-lab-docs.readthedocs.io/en/latest/license.html), a larger pipeline/licensing change than CC0 targets.
