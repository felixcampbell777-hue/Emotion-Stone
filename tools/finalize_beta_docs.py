from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
note='Beta meadow v0.24.0 (2026-10-11): user explicitly requested a separate playable Beta using the current personal heroine and explicitly authorized animation work, with existing human motion research first. Alpha remains the existing adventure. This authorization applies to the separate Beta export, not regeneration of the frozen canonical Alpha or rejected anime models. Read docs/BETA.md. Personal main remains unchanged at SHA256 dbfce2db2c8ee3e99d97cd64c0c6801e3052dd29945fda8e32aca133964ee3d8. Startup selects Alpha/Beta; separate saves. Beta begins in beta_meadow with normal slimes, original Resin sticky slimes, Quaternius wolves and CC0 CDmir rats. Separate editable art/source/beta-heroine.blend and heroine-beta.glb reuse nineteen current actions; no new motion pack was downloaded. Run verify-beta, full verify-windows, and inspect capture-windows --view beta/title/menus/combat. This explicit new request supersedes older prohibitions on animating/integrating the personal model for this Beta only.\n\n'
for name in ['AGENTS.md','docs/CURRENT-BASELINE.md']:
    p=root/name;s=p.read_text(encoding='utf-8')
    if not s.startswith('Beta meadow v0.24.0'):p.write_text(note+s,encoding='utf-8')
p=root/'game/content/maps/beta_meadow.json';area=json.loads(p.read_text())
for prop in area['props']:
    if prop['kind']=='catalog_feature':
        prop['kind']='tree';prop.pop('catalog_code',None)
        if prop['id'].startswith('meadow_sapling'):prop['scale']=.62
p.write_text(json.dumps(area,indent=2)+'\n',encoding='utf-8')
p=root/'docs/ASSET-CREDITS.md';s=p.read_text(encoding='utf-8')
s+='\n## Beta meadow\n\nThe Beta heroine uses the current non-anime personal MakeHuman/MPFB figure, with CC0 sonntag78 Junglebook hair, existing denim/leather materials and project sword. Saved personal source is untouched; the sixteen deform bones and nineteen motions in its derived export reuse the project’s authored animation library.\n\nWolf: Quaternius Animated Animal Pack, supplied wolf skin and Attack/Walk/Gallop/Hit/Death animations. https://quaternius.com/packs/animatedanimals.html . Legacy pack CC0 notice and current Quaternius Asset License are retained in art/library. Conservatively use in the embedded game only; do not redistribute the source kit as a standalone asset product.\n\nRat: CDmir / TinyWorlds, Evil Giant Rat, CC0-1.0, with supplied existing skin and six motion clips. https://opengameart.org/content/evil-giant-rat . Source hashes and runtime export: art/library/BETA-RUNTIME-ASSETS.json. Existing trusted intake/Defender scans cover both source kits. No new remote asset downloads were required for this Beta.\n'
if '## Beta meadow' not in p.read_text(encoding='utf-8'):p.write_text(s,encoding='utf-8')
p=root/'docs/PLAY.md';s=p.read_text(encoding='utf-8');intro='Choose **Alpha — Existing adventure** or **Beta — Meadow & woodland** on the title screen, then Start New Game or Load Saved Game. Beta begins outdoors with the current personal heroine and only normal/sticky slimes, wolves and rats. Its F5/F9 save file is separate from Alpha. Escape → Alpha / Beta menu returns to the selector; save first to keep your current session.\n\n'
if 'Beta — Meadow' not in s:p.write_text(intro+s,encoding='utf-8')
