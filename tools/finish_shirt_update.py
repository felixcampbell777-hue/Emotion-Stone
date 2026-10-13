"""Audit installed garment release and preserve a current validation record."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[1]
def read(name):return json.loads((ROOT/name).read_text(encoding='utf-8'))
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
version=read('game/content/release.json')['version'];evidence=read('output/verification/current-render-evidence.json');build=read('output/build-cache.json')
assert evidence['release']==version and evidence['game_key']==build['game_key']
assert not read('output/verification/integration-report.json')['failures']
assert not read('output/verification/export-integration-report.json')['failures']
export=read('art/character/beta-heroine-export.json');audit=read('art/character/shirt-review/source-checks.json')
assert sha(ROOT/export['editable_source'])==export['editable_source_sha256']==audit['source_sha256']
assert sha(ROOT/export['export'])==export['export_sha256'] and audit['passed']
for name,expected in read('art/character/model-review.json')['static_integration']['frozen_assets'].items():assert sha(ROOT/name)==expected,name
assert sha('C:/Users/felix/OneDrive/Documents/heroinedraft1.blend')==export['source_sha256']
required=['idle_loop','draw_sword','attack_heavy','attack_lance','parry_guard','drag_walk_loop']
for name in required:assert 'beta/shirt-back-'+name+'.png' in evidence['files']
folders=list((ROOT/'output/windows').iterdir());assert len(folders)==1 and folders[0].name=='v'+version
assert not list((ROOT/'art/source').glob('*.blend[0-9]*'))
report={'release':version,'source_checks':read('output/verification/integration-report.json')['check_count'],'windows_checks':read('output/verification/export-integration-report.json')['check_count'],'garment_source_checks':audit,'personal_and_canonical_sources_unchanged':True,'sole_current_release':str(folders[0]),'rendered_coverage_poses':required,'current_rendered_files':len(evidence['files'])}
(ROOT/'art/character/shirt-review/installed-validation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
