"""Audit the installed castle-town update after native captures and official cleanup."""
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def read(name): return json.loads((ROOT/name).read_text(encoding='utf-8'))
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
release = read('game/content/release.json')['version']
cache = read('output/build-cache.json')
evidence = read('output/verification/current-render-evidence.json')
assert evidence['release'] == release and evidence['game_key'] == cache['game_key']
assert sorted(p.name for p in (ROOT/'output/windows').iterdir()) == ['v'+release]
assert all((ROOT/'output/verification/windows-render'/name).is_file() for name in evidence['files'])
required = ['beta/castle-town-'+name+'.png' for name in ['overview','gate','market','keep','follow','first-person','street-first-person']]
assert all(name in evidence['files'] for name in required)
source = read('output/verification/integration-report.json')
windows = read('output/verification/export-integration-report.json')
for report in [source, windows]:
    assert report['passed'] and not report['failures']
    assert len([c for c in report['checks'] if c['passed'] and any(word in c['check'] for word in ['Castle road','Castle walls','castle gate','perimeter wall','castle-town street','Town roof'])]) == 6
expected = {'beta-heroine.blend':'851a1c7e51afa505d4e743cbe6a6aade6d014571b4a1a389cb322fa6e67b5b40','beta-greatsword.blend':'bef750bcdf023169a9cb6128604586b798eac75d4d87c727d8808f5d21aae32a','beta-wolf.blend':'b20eab0e6c35456f06dcb4461a1e5b3c059e8e454231b75dd5324bffb1b37e19'}
for name, digest in expected.items(): assert sha(ROOT/'art/source'/name) == digest
exe = ROOT/'output/windows'/('v'+release)/'CoastalFoundation.exe'
assert sha(exe) == cache['executable_hash']
town = read('game/content/maps/beta_meadow.json')
assert town['spawn'] == [0,-12] and len(town['enemies']) + len(town['catalog_enemies']) == 14
assert len([p for p in town['props'] if p['id'].startswith('town_house_')]) == 9
record = {'utc':datetime.now(timezone.utc).isoformat(),'release':release,'game_key':cache['game_key'],'source_checks':source['check_count'],'windows_checks':windows['check_count'],'required_native_views':required,'current_evidence_files':len(evidence['files']),'sources_unchanged':True,'new_downloads':False,'sole_release':str(exe.parent),'houses':9,'castle_interiors':'closed exterior scenery; streets, gate and courtyard playable'}
directory = ROOT/'art/environment/castle-town-review'
directory.mkdir(parents=True, exist_ok=True)
(directory/'installed-validation.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record,indent=2))
