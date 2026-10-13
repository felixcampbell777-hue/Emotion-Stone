"""Curated art intake only. Never installs code, launches assets, or changes the game."""
import concurrent.futures
import hashlib
import html
import json
import re
import stat
import struct
import subprocess
import urllib.parse
import zipfile
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / 'art/library'
SOURCE = LIB / 'source'
INCOMING = LIB / '_incoming'
ALLOWED = {'.blend', '.glb', '.gltf', '.bin', '.obj', '.mtl', '.fbx', '.png', '.jpg', '.jpeg', '.tga', '.txt', '.md'}
HOSTS = {'opengameart.org', 'kenney.nl', 'api.polyhaven.com', 'dl.polyhaven.org', 'polyhaven.com', 'api.github.com', 'raw.githubusercontent.com', 'codeload.github.com', 'creativecommons.org', 'quaternius.com'}
MAX_FILE = 128 * 1024 * 1024
KAY_COMMIT = '15b62b9bad122f72926c10fb14d622c73819fa54'
FOX_COMMIT = 'edc7c9e67c639d230715049ee31f9a96a6babbbe'

def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')

def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def safe_path(base, name):
    if '\\' in name or ':' in name or '\x00' in name:
        raise ValueError('Unsafe asset path: ' + name)
    rel = PurePosixPath(name)
    if rel.is_absolute() or '..' in rel.parts:
        raise ValueError('Unsafe asset path: ' + name)
    target = base.joinpath(*rel.parts).resolve()
    if not target.is_relative_to(base.resolve()):
        raise ValueError('Path escaped intake')
    return target

def download(url, path, expected=None):
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != 'https' or parsed.hostname not in HOSTS or parsed.username or parsed.port:
        raise ValueError('Unapproved download URL: ' + url)
    if parsed.hostname == 'dl.polyhaven.org' and not parsed.path.startswith('/file/ph-assets/'):
        raise ValueError('Unexpected Poly Haven data path')
    if "'" in url or "'" in str(path):
        raise ValueError('Unsafe shell quoting')
    path.parent.mkdir(parents=True, exist_ok=True)
    # Windows TLS validation; redirects are refused, even to another trusted host.
    command = "Invoke-WebRequest -Uri '" + url + "' -OutFile '" + str(path) + "' -MaximumRedirection 0 -TimeoutSec 180"
    result = subprocess.run(['powershell', '-NoProfile', '-Command', "$ErrorActionPreference='Stop'; " + command], capture_output=True, text=True, timeout=200)
    if result.returncode:
        path.unlink(missing_ok=True)
        raise RuntimeError(result.stderr[-1500:])
    if path.stat().st_size > MAX_FILE:
        path.unlink()
        raise ValueError('Asset exceeds intake size limit')
    if expected:
        if path.stat().st_size != expected['size'] or hashlib.md5(path.read_bytes()).hexdigest() != expected['md5']:
            path.unlink()
            raise ValueError('Publisher size/MD5 mismatch')
    return {'url': url, 'bytes': path.stat().st_size, 'sha256': sha(path), 'publisher_md5': (expected or {}).get('md5')}

def fetch_json(url, path):
    download(url, path)
    return json.loads(path.read_text(encoding='utf-8-sig'))

def scan(path, label):
    versions = sorted(Path('C:/ProgramData/Microsoft/Windows Defender/Platform').glob('*/MpCmdRun.exe'), key=lambda p: p.parent.name)
    if not versions:
        raise RuntimeError('Defender unavailable; intake stays pending')
    result = subprocess.run([str(versions[-1]), '-Scan', '-ScanType', '3', '-File', str(path), '-DisableRemediation'], capture_output=True, text=True, timeout=240)
    output = result.stdout + result.stderr
    record = {'utc': datetime.now(timezone.utc).isoformat(), 'scanner': str(versions[-1]), 'path': str(path), 'exit_code': result.returncode, 'output': output}
    write_json(LIB / 'security' / (label + '.json'), record)
    if result.returncode != 0 or 'found no threats' not in output.lower():
        raise RuntimeError('Defender did not confirm a clean scan: ' + output[-800:])
    return record

def unpack(archive, dest, only=None):
    accepted, skipped = [], []
    if archive.suffix == '.zip':
        with zipfile.ZipFile(archive) as pack:
            entries = [i for i in pack.infolist() if not i.is_dir()]
            if sum(i.file_size for i in entries) > 512 * 1024 * 1024:
                raise ValueError('Archive expansion limit')
            for item in entries:
                target = safe_path(dest, item.filename)
                if stat.S_ISLNK(item.external_attr >> 16) or item.flag_bits & 1:
                    raise ValueError('Archive contains link or encryption')
                if target.suffix.lower() not in ALLOWED or (only and not only(item.filename)):
                    skipped.append(item.filename)
                    continue
                if item.file_size > MAX_FILE:
                    raise ValueError('Archive member exceeds size limit')
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(pack.read(item))
                accepted.append(target)
    else:
        tar = 'C:/Windows/System32/tar.exe'
        listing = subprocess.run([tar, '-tf', str(archive)], capture_output=True, text=True, check=True).stdout.splitlines()
        for name in listing:
            target = safe_path(dest, name)
            if name.endswith('/'):
                continue
            if target.suffix.lower() not in ALLOWED or (only and not only(name)):
                skipped.append(name)
                continue
            # Read a single member to stdout. Never ask tar to create paths or links.
            data = subprocess.run([tar, '-xOf', str(archive), '--', name], capture_output=True, check=True, timeout=60).stdout
            if len(data) > MAX_FILE:
                raise ValueError('Archive member exceeds size limit')
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            accepted.append(target)
    return accepted, skipped

def inspect_gltf(path):
    if path.suffix == '.glb':
        data = path.read_bytes()
        magic, version, size = struct.unpack_from('<4sII', data)
        if magic != b'glTF' or version != 2 or size != len(data):
            raise ValueError('Malformed GLB')
        length, kind = struct.unpack_from('<II', data, 12)
        if kind != 0x4e4f534a:
            raise ValueError('Missing GLB JSON chunk')
        scene = json.loads(data[20:20+length].rstrip(b' \x00'))
    else:
        scene = json.loads(path.read_text(encoding='utf-8-sig'))
    for obj in scene.get('buffers', []) + scene.get('images', []):
        uri = obj.get('uri', '')
        if uri and not uri.startswith('data:'):
            if urllib.parse.urlparse(uri).scheme:
                raise ValueError('Remote glTF dependency')
            dependency = safe_path(path.parent, urllib.parse.unquote(uri))
            if not dependency.is_file():
                raise ValueError('Missing glTF dependency: ' + str(dependency))
            if 'byteLength' in obj and dependency.stat().st_size != obj['byteLength']:
                raise ValueError('glTF buffer size mismatch')
    return {'file': str(path.relative_to(SOURCE)), 'meshes': len(scene.get('meshes', [])), 'skins': len(scene.get('skins', [])), 'animations': [a.get('name', '(unnamed)') for a in scene.get('animations', [])]}

def catalog():
    rows = []
    animals = [
        ('wolf', '3d-wolf', 'NewDLC', 'CC0-1.0', ['forest','mountain'], 'Rigged wolf; attack/run/death clips need authoring or verification.', ['3dwolf_blend.zip']),
        ('boar', 'boar', 'Teh_Bucket', 'CC0-1.0', ['forest'], 'Walk and attack; future art option for existing boar logic.', ['boar_0.blend']),
        ('giant-rat', 'evil-giant-rat', 'CDmir / TinyWorlds', 'CC0-1.0', ['town','castle'], 'Rigged animated sewer/cellar enemy; optimize before swarms.', ['rat_2.blend']),
        ('deer-female', 'deer-female', 'CDmir / TinyWorlds', 'CC0-1.0', ['forest','mountain'], 'Ambient fauna first; packed textures.', ['doe.blend']),
        ('deer-male', 'old-deer-male', 'CDmir / TinyWorlds', 'CC0-1.0', ['forest','mountain'], 'Ambient stag; rigged and animated with packed maps.', ['deer1.blend']),
        ('rabbit', 'rabbit-0', 'CDmir / TinyWorlds', 'CC0-1.0', ['forest','mountain'], 'Ambient fauna; keep distinct from monster-core profiles.', ['rabbit.blend']),
        ('mudeater', 'mudeater-animated', 'CDmir / TinyWorlds', 'CC0-1.0', ['forest','beach'], 'Distinct creature for mud/swamp encounters; rigged and animated.', ['mudeater.blend']),
        ('undead-squirrel', 'undead-squirrel-animated', 'CDmir', 'CC0-1.0', ['forest'], 'Undead enemy alternative; ordinary squirrel remains fauna.', ['undeadsquirrell.zip']),
        ('goblin', 'goblin-1', 'CDmir / TinyWorlds', 'CC0-1.0', ['forest','castle','mountain'], 'Future goblin visual candidate; retain campaign AI and save IDs.', ['goblin-FINAL.blend']),
        ('forest-monster', 'forest-monster', 'CDmir / TinyWorlds', 'CC0-1.0', ['forest','mountain'], 'Large forest creature/boss; textured and animated.', ['forest-monster_0.7z']),
        ('spider', 'spider-animated', 'Panther-One', 'CC-BY-3.0', ['forest','castle','mountain'], '448-triangle spider; walk/idle only, attack/death still needed.', ['Spider.blend','Spider_0.png']),
        ('crab', 'animated-crab', 'CoinCoin', 'CC-BY-4.0', ['beach'], 'Animated crab; appropriate beach enemy after clip review.', ['crab.zip']),
    ]
    for ident, slug, author, license_id, biomes, note, files in animals:
        rows.append(dict(id=ident, type='creature', provider='OpenGameArt', author=author, license=license_id, biomes=biomes, note=note, source='https://opengameart.org/content/'+slug, downloads=['https://opengameart.org/sites/default/files/'+name for name in files]))
    for slug, count, biomes in [('castle-kit',75,['castle']),('fantasy-town-kit',160,['town','castle']),('pirate-kit',70,['beach'])]:
        rows.append(dict(id='kenney-'+slug, type='modular-kit', provider='Kenney', author='Kenney', license='CC0-1.0', biomes=biomes, source='https://kenney.nl/assets/'+slug, note=f'Publisher advertises {count} assets; simple stylized shapes, useful kitbash base.', kenney=True))
    rows.append(dict(id='kaykit-skeletons',type='creature-kit',provider='KayKit',author='Kay Lousberg',license='CC0-1.0',biomes=['castle','town','mountain'],source='https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0',note='Four skeleton variants with equipment; GLTF only, excludes Godot plugin and scene code.',downloads=[f'https://codeload.github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0/zip/{KAY_COMMIT}'],commit=KAY_COMMIT,selector='kay'))
    rows.append(dict(id='fox',type='creature',provider='Khronos glTF Sample Assets',author='PixelMannen; tomkranis; AsoboStudio; scurest',license='CC0-1.0 mesh + CC-BY-4.0 animation',biomes=['forest'],source='https://github.com/KhronosGroup/glTF-Sample-Assets/tree/'+FOX_COMMIT+'/Models/Fox',note='Survey/Walk/Run sample; ambient fox, no combat clips. Preserve mixed-license credits.',downloads=[f'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/{FOX_COMMIT}/Models/Fox/{name}' for name in ['glTF-Binary/Fox.glb','LICENSE.md','README.md']],commit=FOX_COMMIT))
    for ident, biomes in [('coastal_cliff_01',['beach','mountain']),('coast_rocks_01',['beach']),('boulder_01',['mountain','forest']),('rock_moss_set_02',['forest','mountain']),('flower_heliophila',['forest','beach']),('nettle_plant',['forest'])]:
        rows.append(dict(id='ph-'+ident,asset_id=ident,type='scanned-model',provider='Poly Haven',license='CC0-1.0',biomes=biomes,source='https://polyhaven.com/a/'+ident,note='1K glTF source scan and dependencies; optimize geometry/LOD before runtime.',polyhaven=True))
    for ident, biomes in [('coast_sand_01',['beach']),('damp_beach_sand',['beach']),('snow_02',['mountain']),('rock_face',['mountain']),('cliff_side',['mountain','beach']),('castle_brick_01',['castle','town']),('plaster_stone_wall_01',['town','castle'])]:
        rows.append(dict(id='ph-'+ident,asset_id=ident,type='pbr-texture',provider='Poly Haven',license='CC0-1.0',biomes=biomes,source='https://polyhaven.com/a/'+ident,note='2K albedo, OpenGL normal and roughness; no redundant 8K/16K maps.',polyhaven=True))
    extra = LIB/'QUATERNIUS-CATALOG.json'
    if extra.exists():
        rows.extend(json.loads(extra.read_text(encoding='utf-8')))
    return rows

def collect(row):
    ident = row['id']
    dest = SOURCE / ident
    existing = dest / 'INTAKE.json'
    if existing.exists():
        current = json.loads(existing.read_text(encoding='utf-8'))
        complete = row.get('selector') != 'kay' or len([c for c in current.get('gltf_checks',[]) if c['skins'] > 0]) == 4
        if complete:
            return current
    if row['provider']=='Quaternius':
        raise ValueError('Use creator-linked Drive intake recipe; missing Quaternius files are not automatically fetched')
    work = INCOMING / ident
    work.mkdir(parents=True, exist_ok=True)
    dest.mkdir(parents=True, exist_ok=True)
    accepted, skipped, downloads, checks = [], [], [], []
    if row.get('polyhaven'):
        meta = fetch_json('https://api.polyhaven.com/files/'+row['asset_id'], dest/'publisher-files.json')
        if row['type'] == 'scanned-model':
            info = meta['gltf']['1k']['gltf']
            jobs = [(urllib.parse.urlparse(info['url']).path.rsplit('/',1)[-1], info)] + list(info['include'].items())
        else:
            jobs = [(name+'.jpg',meta[kind]['2k']['jpg']) for kind,name in [('Diffuse','albedo'),('nor_gl','normal'),('Rough','roughness')]]
        for name, info in jobs:
            target = safe_path(dest, name)
            if target.suffix not in ALLOWED:
                raise ValueError('Non-data Poly Haven dependency')
            downloads.append(download(info['url'], target, info))
            accepted.append(target)
    else:
        if row.get('kenney'):
            page = work/'publisher-page.txt'
            download(row['source'], page)
            page_html = page.read_text(encoding='utf-8-sig')
            match = re.search(r'https://kenney\.nl/media/[^\s\"\'<>]+\.zip',page_html)
            if not match or 'creativecommons.org/publicdomain/zero' not in page_html:
                raise ValueError('Missing official CC0 download')
            urls = [html.unescape(match.group())]
        else:
            urls = row['downloads']
        for index, url in enumerate(urls):
            name = urllib.parse.unquote(urllib.parse.urlparse(url).path.rsplit('/',1)[-1])
            if row.get('commit') and 'codeload' in url:
                name += '.zip'
            target = work / name
            record = download(url,target)
            downloads.append(record)
            if target.suffix in {'.zip','.7z'}:
                scan(target, ident+'-archive')
                selector = None
                if row.get('selector') == 'kay':
                    selector = lambda name: '/Assets/gltf/' in name or '/Characters/gltf/' in name or name.endswith(('/LICENSE.txt','/README.md'))
                elif row.get('kenney'):
                    selector = lambda name: Path(name).suffix.lower() in {'.glb','.txt','.md'} or '/Textures/' in name or '/textures/' in name
                files, excluded = unpack(target,dest,selector)
                accepted.extend(files)
                skipped.extend(excluded)
            else:
                if target.suffix.lower() not in ALLOWED:
                    raise ValueError('Non-data download')
                final = safe_path(dest,name)
                target.replace(final)
                accepted.append(final)
    for path in accepted:
        if path.suffix in {'.glb','.gltf'}:
            checks.append(inspect_gltf(path))
        elif path.suffix == '.blend' and path.read_bytes()[:7] != b'BLENDER':
            raise ValueError('Invalid Blender header: '+str(path))
    if not any(p.suffix in {'.blend','.glb','.gltf','.fbx','.obj','.jpg'} for p in accepted):
        raise ValueError('No reusable art data collected')
    if row.get('selector') == 'kay' and len([check for check in checks if check['skins'] > 0]) != 4:
        raise ValueError('Expected four rigged skeleton models')
    result = {**row,'status':'collected_pending_final_scan','utc':datetime.now(timezone.utc).isoformat(),'downloads':downloads,'excluded_files':skipped,'gltf_checks':checks,'files':[{'path':str(p.relative_to(SOURCE)), 'bytes':p.stat().st_size,'sha256':sha(p)} for p in accepted]}
    write_json(existing,result)
    # Archives are transport only. Retain original unpacked sources and intake hashes.
    for path in work.iterdir():
        if path.is_file():
            path.unlink()
    work.rmdir()
    print('COLLECTED',ident,len(accepted),sum(p.stat().st_size for p in accepted),flush=True)
    return result

def preserve():
    release = json.loads((ROOT/'game/content/release.json').read_text(encoding='utf-8-sig'))['version']
    folders = [ROOT/'game',ROOT/'art/source',ROOT/'output/windows'/('v'+release)]
    files = [p for base in folders for p in base.rglob('*') if p.is_file() and '.godot' not in p.parts]
    evidence = ROOT/'output/verification/current-render-evidence.json'
    index = json.loads(evidence.read_text(encoding='utf-8-sig'))
    files += [evidence] + [ROOT/'output/verification/windows-render'/name for name in index['files']]
    for base in [ROOT/'output/verification/user-heroine-draft',ROOT/'output/verification/user-heroine-anime-draft']:
        files += [p for p in base.rglob('*') if p.is_file()]
    return {str(p):sha(p) for p in sorted(set(files))}

def main():
    LIB.mkdir(parents=True,exist_ok=True)
    before = preserve()
    write_json(LIB/'PRESERVATION.json',{'before':before,'status':'in_progress'})
    rows = catalog()
    write_json(LIB/'catalog.json',rows)
    results, errors = [], []
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        futures = {pool.submit(collect,row):row for row in rows}
        for future in concurrent.futures.as_completed(futures):
            try:
                results.append(future.result())
            except Exception as exc:
                errors.append({'id':futures[future]['id'],'error':str(exc)})
                print('PENDING',futures[future]['id'],str(exc)[-250:],flush=True)
    scan_result = scan(SOURCE,'complete-library')
    for row in results:
        row['status']='collected_defender_no_threats_detected'
        write_json(SOURCE/row['id']/'INTAKE.json',row)
    after = preserve()
    releases = [p.name for p in (ROOT/'output/windows').iterdir()]
    changed = [name for name,digest in before.items() if after.get(name)!=digest]
    write_json(LIB/'PRESERVATION.json',{'before':before,'status':'existing_files_unchanged' if not changed else 'CHANGED','sole_release':releases,'missing_or_changed':changed,'concurrent_additions':sorted(set(after)-set(before))})
    write_json(LIB/'MANIFEST.json',{'utc':datetime.now(timezone.utc).isoformat(),'scope':'Future-development source library; not integrated or runtime-tested','scan_record':'security/complete-library.json','assets':sorted(results,key=lambda r:r['id']),'pending':errors,'bytes':sum(f['bytes'] for r in results for f in r['files']),'preservation_unchanged':not changed})
    for base in [SOURCE,INCOMING]:
        if base.exists():
            for child in base.iterdir():
                if child.is_dir() and not any(child.iterdir()):
                    child.rmdir()
    if INCOMING.exists() and not any(INCOMING.iterdir()):
        INCOMING.rmdir()
    print('INTAKE_SUMMARY',json.dumps({'collected':len(results),'pending':len(errors),'preserved':not changed,'releases':releases}),flush=True)

if __name__ == '__main__':
    main()
