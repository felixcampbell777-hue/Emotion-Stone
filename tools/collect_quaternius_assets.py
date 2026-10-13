"""Official creator-linked Drive files only; no projects, plugins, or code."""
import concurrent.futures
import json
import sys
import urllib.request
import urllib.parse
from datetime import datetime, timezone
from pathlib import Path
import collect_open_assets as intake

LIB = intake.LIB
PLAN = LIB/'QUATERNIUS-DOWNLOAD-PLAN.json'

def transfer(item):
    plan = json.loads(PLAN.read_text(encoding='utf-8'))
    expected = next(f for f in plan['files'] if f['id']==item['id'] and f['pack']==item['pack'] and f['path']==item['path'])
    base = intake.SOURCE/item['pack']
    base.mkdir(parents=True,exist_ok=True)
    target = intake.safe_path(base, item['path'])
    if target.suffix.lower() not in intake.ALLOWED:
        raise ValueError('Non-art file refused')
    if target.is_file() and target.stat().st_size==int(expected['size']):
        return str(target.relative_to(intake.SOURCE))
    url = item['download_url']
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme!='https' or not parsed.hostname.endswith('.oaiusercontent.com') or parsed.username or parsed.port:
        raise ValueError('Unexpected authenticated connector download endpoint')
    size = int(expected['size'])
    if size!=int(item['file_size_bytes']) or size>intake.MAX_FILE:
        raise ValueError('Provider size disagreement')
    target.parent.mkdir(parents=True,exist_ok=True)
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, *args, **kwargs):
            raise ValueError('Unexpected download redirect')
    try:
        with urllib.request.build_opener(NoRedirect).open(url,timeout=120) as stream, target.open('wb') as dest:
            received=0
            while chunk:=stream.read(1024*1024):
                received+=len(chunk)
                if received>size:
                    raise ValueError('Download exceeded expected size')
                dest.write(chunk)
        if target.stat().st_size!=size:
            raise ValueError('Truncated download')
    except Exception:
        target.unlink(missing_ok=True)
        raise
    return str(target.relative_to(intake.SOURCE))

def finalize():
    plan = json.loads(PLAN.read_text(encoding='utf-8'))
    biomes={'quaternius-animals':['forest','mountain','town'],'quaternius-monsters':['forest','mountain','castle','beach'],'quaternius-fantasy-rts':['town','castle','forest','mountain','beach'],'quaternius-pirate':['beach','town']}
    rows=[]
    for root in plan['roots']:
        ident=root['id']
        files=[]
        checks=[]
        for spec in [f for f in plan['files'] if f['pack']==ident]:
            path=intake.safe_path(intake.SOURCE/ident,spec['path'])
            if not path.is_file() or path.stat().st_size!=int(spec['size']):
                raise ValueError('Missing/incomplete source: '+spec['path'])
            if path.suffix=='.blend' and path.read_bytes()[:7]!=b'BLENDER':
                raise ValueError('Invalid Blender header')
            if path.suffix in {'.glb','.gltf'}:
                checks.append(intake.inspect_gltf(path))
            files.append({'path':str(path.relative_to(intake.SOURCE)),'bytes':path.stat().st_size,'sha256':intake.sha(path),'official_drive_id':spec['id'],'official_drive_url':spec['url']})
        supplied=(intake.SOURCE/ident/'License.txt')
        license_text=supplied.read_text(encoding='utf-8-sig') if supplied.exists() else None
        legacy_cc0=bool(license_text and ('creativecommons.org/publicdomain/zero' in license_text or 'CC0' in license_text))
        row={'id':ident,'type':'creature-kit' if ident in {'quaternius-animals','quaternius-monsters'} else 'modular-kit','provider':'Quaternius','author':'Quaternius','source':root['source'],'license':'CC0-1.0 (supplied legacy license; current QAL conflict recorded)' if legacy_cc0 else 'Quaternius Asset License 1.0','license_source':'https://quaternius.com/license.html','supplied_license_text':license_text,'license_handling':'User explicitly authorized Quaternius on 2026-10-11. Retain legacy declarations; conservatively comply with current QAL restrictions for new use; do not redistribute raw assets. This exception is separate from the open-license collection.','biomes':biomes[ident],'note':'Original art sources only; no installers, addon, Godot code, demos, or duplicate FBX/OBJ exports. No game integration.','utc':datetime.now(timezone.utc).isoformat(),'downloads':[{'official_creator_page':root['source'],'official_drive_root':'https://drive.google.com/drive/folders/'+root['root'],'transfer':'Authenticated Google Drive connector raw-file response; returned scoped download URL consumed ephemerally, not retained.'}],'status':'collected_pending_final_scan','gltf_checks':checks,'files':files,'excluded_files':['FBX/OBJ duplicate exports','native Blender scenery duplicate exports','Scene_AllModels combined scene']}
        intake.write_json(intake.SOURCE/ident/'INTAKE.json',row)
        rows.append(row)
    intake.scan(intake.SOURCE,'complete-library')
    for row in rows:
        row['status']='collected_defender_no_threats_detected'
        intake.write_json(intake.SOURCE/row['id']/'INTAKE.json',row)
    manifest=json.loads((LIB/'MANIFEST.json').read_text(encoding='utf-8'))
    manifest['assets']=[r for r in manifest['assets'] if r['provider']!='Quaternius']+rows
    manifest['assets'].sort(key=lambda r:r['id'])
    manifest.update(utc=datetime.now(timezone.utc).isoformat(),bytes=sum(f['bytes'] for r in manifest['assets'] for f in r['files']))
    intake.write_json(LIB/'MANIFEST.json',manifest)
    intake.write_json(LIB/'QUATERNIUS-CATALOG.json',[{k:v for k,v in r.items() if k not in {'files','gltf_checks','downloads','status','utc','supplied_license_text'}} for r in rows])
    intake.write_json(LIB/'catalog.json',intake.catalog())
    print(json.dumps({'packs':len(rows),'files':sum(len(r['files']) for r in rows),'gltf_models':sum(len(r['gltf_checks']) for r in rows),'bytes':sum(f['bytes'] for r in rows for f in r['files'])}))

if __name__=='__main__':
    if sys.argv[1]=='--begin':
        intake.write_json(LIB/'PRESERVATION.json',{'before':intake.preserve(),'status':'in_progress','sole_release':[p.name for p in (intake.ROOT/'output/windows').iterdir()]})
    elif sys.argv[1]=='--transfer':
        queue=Path(sys.argv[2]).resolve()
        if not queue.is_relative_to((LIB/'_incoming').resolve()):
            raise ValueError('Transfer queue must be within intake directory')
        try:
            items=json.loads(queue.read_text(encoding='utf-8'))
            with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
                completed=list(pool.map(transfer,items))
            print('Transferred',len(completed),'creator-verified art files')
        finally:
            queue.unlink(missing_ok=True)
            if not any(queue.parent.iterdir()):
                queue.parent.rmdir()
    elif sys.argv[1]=='--finalize':
        finalize()
    else:
        raise ValueError('Unknown operation')
