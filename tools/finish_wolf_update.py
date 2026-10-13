"""Read-only final release/source/render audit; write a current validation record."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[1]
def read(path):return json.loads((ROOT/path).read_text(encoding='utf-8'))
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
release=read('game/content/release.json')['version'];build=read('output/build-cache.json');evidence=read('output/verification/current-render-evidence.json')
assert evidence['release']==release and evidence['game_key']==build['game_key']
source=read('output/verification/integration-report.json');native=read('output/verification/export-integration-report.json')
assert not source['failures'] and not native['failures']
frozen=read('art/character/model-review.json')['static_integration']['frozen_assets']
for name,expected in frozen.items():assert sha(ROOT/name)==expected,name
assert sha(Path('C:/Users/felix/OneDrive/Documents/heroinedraft1.blend'))=='dbfce2db2c8ee3e99d97cd64c0c6801e3052dd29945fda8e32aca133964ee3d8'
wolf=read('art/library/beta-wolf-customization.json')
for key,name in [('source_sha256',wolf['source']),('runtime_sha256',wolf['runtime']),('donor_sha256',wolf['donor'])]:assert sha(ROOT/name)==wolf[key]
for name,expected in read('art/library/wolf-fur-textures.json')['files'].items():assert sha(ROOT/'game/assets/creatures/wolf-fur'/name)==expected
required=['wolves-patrol.png','wolves-circle.png','wolves-single-windup.png','wolves-single-leap.png','wolves-pair-windup.png','wolves-pair-leap.png','beta_wolf.png','beta_wolf-attack.png']
for name in required:assert 'beta/'+name in evidence['files'] and (ROOT/'output/verification/windows-render/beta'/name).is_file(),name
states=read('output/verification/windows-render/beta/wolves-capture.json')
for snap in states:
    count=sum(m['state'] in ['windup','lunge'] for m in snap['members'])
    assert count==(2 if snap['phase'].startswith('pair') else 1),snap
folders=list((ROOT/'output/windows').iterdir());assert len(folders)==1 and folders[0].name=='v'+release
assert not list((ROOT/'art/source').glob('*.blend[0-9]*'))
report={'release':release,'game_key':build['game_key'],'source_checks':len(source['checks']),'windows_checks':len(native['checks']),'source_and_donor_hashes_match':True,'canonical_and_personal_sources_unchanged':True,'sole_current_release':str(folders[0]),'editable_wolf':wolf['source'],'rendered_pack_phases':[snap['phase'] for snap in states],'current_rendered_files':len(evidence['files']),'no_new_downloads':True}
(ROOT/'art/character/wolf-review/installed-validation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
