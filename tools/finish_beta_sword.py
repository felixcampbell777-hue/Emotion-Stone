"""Read-only release/source/evidence audit after successful native checks."""
import json,hashlib
from pathlib import Path
from datetime import datetime,timezone
ROOT=Path(__file__).resolve().parents[1]
def read(p):return json.loads((ROOT/p).read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
release=read('game/content/release.json')['version']
cache=read('output/build-cache.json'); evidence=read('output/verification/current-render-evidence.json')
sources=read('art/character/model-review.json')['static_integration']['frozen_assets']
for name,expected in sources.items(): assert sha(ROOT/name)==expected,name
personal=Path('C:/Users/felix/OneDrive/Documents/heroinedraft1.blend')
assert sha(personal)=='dbfce2db2c8ee3e99d97cd64c0c6801e3052dd29945fda8e32aca133964ee3d8'
assert sorted(p.name for p in (ROOT/'output/windows').iterdir())==['v'+release]
assert not list((ROOT/'art/source').glob('*.blend[0-9]*'))
assert evidence['release']==release and evidence['game_key']==cache['game_key']
required=['beta/war-sword-ground-drag.png','beta/longsword-ground-impact.png','beta/longsword-energy-1.0.png','beta/longsword-restored-steel.png','beta/longsword-back-carry.png','beta/inventory.png','beta/gait-side-walk-sheet.png','beta/gait-side-run-sheet.png','beta/gait-side-burden-walk-sheet.png','beta/gait-side-burden-run-sheet.png','camera-first-person-look-right.png','camera-first-person-look-left.png','camera-first-person-spin-020.png','camera-first-person-spin-036.png','camera-first-person-parry.png','lance-restored-steel.png','sword-burden-walk-25.png']
for name in required:assert name in evidence['files'] and (ROOT/'output/verification/windows-render'/name).is_file(),name
anchor_required=['beta/back-anchor-idle-back.png','beta/back-anchor-idle-side.png','beta/back-anchor-walk-back.png','beta/back-anchor-run-side.png','beta/back-anchor-draw-back.png','beta/back-anchor-sheathe-back.png','beta/back-anchor-detail.png','beta/back-anchor-released.png']
for name in anchor_required:assert name in evidence['files'] and (ROOT/'output/verification/windows-render'/name).is_file(),name
source_checks=read('output/verification/integration-report.json');native=read('output/verification/export-integration-report.json')
assert source_checks['passed'] and native['passed'] and not native['failures']
model=read('art/character/beta-sword-review/customization.json')
assert sha(ROOT/'art/source/beta-greatsword.blend')==model['source_sha256']
assert sha(ROOT/'game/assets/characters/greatsword-beta.glb')==model['runtime_sha256']
intake=read('art/library/source/quandtum-knights-trust/INTAKE.json')
assert sha(ROOT/'art/library/source/quandtum-knights-trust/LongSword_KnightsTrust_Quandtum.blend')==model['donor_sha256']
exe=ROOT/('output/windows/v'+release+'/CoastalFoundation.exe')
assert sha(exe)==cache['executable_hash']
human_motion=read('art/library/source/quaternius-human-motion/INTAKE.json')
assert sha(ROOT/human_motion['runtime_samples'])==human_motion['runtime_samples_sha256']
assert human_motion['archive_scan']['exit_code']==0 and human_motion['selected_scan']['exit_code']==0
for name,expected in human_motion['files'].items():assert sha(ROOT/'art/library/source/quaternius-human-motion'/name)==expected,name
assert abs(model['overall_length_m']-1.8048)<.001 and abs(model['blade_length_m']-1.40)<.001
record={'utc':datetime.now(timezone.utc).isoformat(),'release':release,'game_key':cache['game_key'],'source_checks':source_checks['check_count'],'windows_checks':native['check_count'],'current_rendered_files':len(evidence['files']),'canonical_sources_and_exports_unchanged':True,'personal_source_unchanged':True,'sole_release':str(exe.parent),'editable_source':str(ROOT/'art/source/beta-greatsword.blend'),'donor_source_unchanged':True,'defender_archive':read('art/library/security/beta-sword-archive.json')['exit_code'],'defender_source':read('art/library/security/beta-sword-source.json')['exit_code'],'provenance':intake['source'],'human_motion_intake':human_motion['status'],'sword_dimensions':{key:model[key] for key in ['overall_length_m','blade_length_m','blade_width_m','blade_thickness_m']},'required_reviewed_frames':required}
(ROOT/'art/character/beta-sword-review/installed-validation.json').write_text(json.dumps(record,indent=2)+'\n')
anchor_record={**record,'required_reviewed_frames':anchor_required,'anchor_tuning':read('game/content/beta.json')['back_anchor'],'native_recipe':'game/scripts/beta_back_anchor.gd','existing_editable_blender_sources_preserved':True,'new_downloads':False}
(ROOT/'art/character/back-anchor-review/installed-validation.json').write_text(json.dumps(anchor_record,indent=2)+'\n')
print(json.dumps(record,indent=2))
