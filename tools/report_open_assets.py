"""License receipts and final source-library integrity check; no runtime edits."""
import concurrent.futures
import html
import json
import re
from pathlib import Path
import collect_open_assets as intake

LIB = intake.LIB
SOURCE = intake.SOURCE
manifest = json.loads((LIB/'MANIFEST.json').read_text(encoding='utf-8'))
blend = json.loads((LIB/'BLENDER-INVENTORY.json').read_text(encoding='utf-8'))
temporary = LIB/'_license_pages'
temporary.mkdir(exist_ok=True)

def receipt(row):
    source = row['source']
    evidence = {'source':source,'author':row.get('author'),'license':row['license'],'checked_on':'2026-10-11','status':'publisher declaration verified; not an independent ownership audit'}
    if row['provider'] in {'OpenGameArt','Kenney'}:
        page = temporary/(row['id']+'.txt')
        evidence['page_download']=intake.download(source,page)
        raw = page.read_text(encoding='utf-8-sig')
        plain = re.sub(r'\s+',' ',html.unescape(re.sub(r'<[^>]+>',' ',raw)))
        marker = 'License(s):' if row['provider']=='OpenGameArt' else 'License '
        index = plain.find(marker)
        excerpt = plain[index:index+100]
        expected = 'CC0' if row['license']=='CC0-1.0' else 'CC-BY 3.0' if row['license']=='CC-BY-3.0' else 'CC-BY 4.0'
        if index < 0 or expected not in excerpt:
            raise ValueError('Publisher license marker mismatch: '+row['id']+' '+excerpt)
        evidence['license_field']=excerpt.split('Collections:')[0].split('Download')[0].strip()
        page.unlink()
    elif row['provider']=='Poly Haven':
        evidence['license_source']='https://polyhaven.com/license'
        evidence['checksum_contract']='Official API size and MD5 validated for every art file; local SHA256 retained.'
    elif row['provider']=='Quaternius':
        evidence.update(license_source=row['license_source'],supplied_license_text=row.get('supplied_license_text'),license_handling=row['license_handling'],official_creator_linked_drive=True)
    else:
        evidence['license_files']=[f['path'] for f in row['files'] if 'license' in Path(f['path']).name.lower()]
    receipt_path=SOURCE/row['id']/'LICENSE-AND-SOURCE.txt'
    license_link = row['license_source'] if row['provider']=='Quaternius' else 'https://creativecommons.org/publicdomain/zero/1.0/' if row['license']=='CC0-1.0' else 'https://creativecommons.org/licenses/by/3.0/' if row['license']=='CC-BY-3.0' else 'https://creativecommons.org/licenses/by/4.0/'
    receipt_path.write_text('Source: '+source+'\nAuthor: '+str(row.get('author','Poly Haven; see official asset/API metadata'))+'\nLicense: '+row['license']+'\nLicense reference: '+license_link+'\nChecked: 2026-10-11\n'+(row['license_handling']+'\n' if row['provider']=='Quaternius' else 'Attribution required; name the author, link the source/license and identify modifications.\n' if 'CC-BY' in row['license'] else 'Attribution optional; retain source provenance.\n')+'Collected for later development; no gameplay integration approved by this intake.\n',encoding='utf-8')
    return evidence

with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
    evidence=list(pool.map(receipt,manifest['assets']))
temporary.rmdir()
intake.write_json(LIB/'LICENSE-EVIDENCE.json',evidence)

# Blender's FBX reader can unpack embedded copies. Remove only exact duplicate
# images inside this one known generated directory, verified against intake hashes.
crab = next(a for a in manifest['assets'] if a['id']=='crab')
accepted_hashes={f['sha256'] for f in crab['files']}
generated=SOURCE/'crab/source/minecrab_FBX_Textures'
removed=[]
if generated.exists():
    if generated.resolve() != generated or not generated.resolve().is_relative_to(SOURCE.resolve()):
        raise ValueError('Unsafe generated-directory cleanup')
    for path in generated.iterdir():
        if path.is_file() and path.suffix.lower()=='.png' and intake.sha(path) in accepted_hashes:
            removed.append(str(path.relative_to(SOURCE)))
            path.unlink()
        else:
            raise ValueError('Unexpected FBX extraction; preserve and inspect '+str(path))
    generated.rmdir()

errors=[]
for row in manifest['assets']:
    for file in row['files']:
        path=SOURCE/file['path']
        if not path.is_file() or intake.sha(path)!=file['sha256']:
            errors.append('Modified/missing intake file: '+str(path))
    for file in row['files']:
        path=SOURCE/file['path']
        if path.suffix in {'.glb','.gltf'}:
            intake.inspect_gltf(path)
for row in blend:
    if row.get('error'):
        errors.append(row['file']+': '+row['error'])
    if any(t['looks_like_python'] for t in row.get('embedded_text_review',[])) or row.get('objects_with_drivers'):
        errors.append('Embedded executable content requires review: '+row['file'])
protected=json.loads((LIB/'PRESERVATION.json').read_text(encoding='utf-8'))
after=intake.preserve()
changed=[name for name,digest in protected['before'].items() if after.get(name)!=digest]
concurrent_path=LIB/'CONCURRENT-WORK.json'
concurrent=json.loads(concurrent_path.read_text(encoding='utf-8')) if concurrent_path.exists() else {'verified_updates':{}}
verified_updates={name:record for name,record in concurrent['verified_updates'].items() if name in changed and after.get(name)==record['observed_sha256'] and Path(name).is_file()}
unexpected=[name for name in changed if name not in verified_updates]
protected.update(status='existing_game_sources_release_unchanged_with_verified_concurrent_review_updates' if verified_updates and not unexpected else 'existing_files_unchanged' if not changed else 'CHANGED',missing_or_changed=changed,unexpected_missing_or_changed=unexpected,verified_concurrent_updates=verified_updates,concurrent_additions=sorted(set(after)-set(protected['before'])))
intake.write_json(LIB/'PRESERVATION.json',protected)
manifest['preservation_unchanged']=not changed
manifest['preservation_no_unexpected_changes']=not unexpected
intake.write_json(LIB/'MANIFEST.json',manifest)
if unexpected:
    errors.append('Protected game/source/evidence changed')
intake.scan(LIB,'final-library')
status_cmd="Get-MpComputerStatus | Select-Object AntivirusEnabled,RealTimeProtectionEnabled,AntivirusSignatureLastUpdated,AntivirusSignatureVersion | ConvertTo-Json"
scanner_status=intake.subprocess.run(['powershell','-NoProfile','-Command',status_cmd],capture_output=True,text=True,check=True).stdout
intake.write_json(LIB/'security/defender-status.json',json.loads(scanner_status))
result={'asset_collections':len(manifest['assets']),'source_bytes':manifest['bytes'],'source_files':sum(len(a['files']) for a in manifest['assets']),'gltf_glb_models':sum(len(a['gltf_checks']) for a in manifest['assets']),'blender_files_checked':len([r for r in blend if r['file'].endswith('.blend')]),'fbx_files_checked':len([r for r in blend if r['file'].endswith('.fbx')]),'original_file_hashes_verified':not errors,'preserved_existing_game_sources_release_evidence':not unexpected,'verified_concurrent_personal_review_updates':list(verified_updates),'sole_release':protected['sole_release'],'removed_duplicate_fbx_texture_extractions':removed,'download_archives_remaining':[str(p) for p in LIB.rglob('*') if p.suffix in {'.zip','.7z'}],'errors':errors,'limits':'Defender detected no threats. No antivirus can guarantee absence of all malware. GLTF structure/dependencies and Blender readability were checked, not gameplay behavior or visual suitability.'}
intake.write_json(LIB/'VALIDATION.json',result)
print(json.dumps(result,indent=2))
if errors:
    raise SystemExit(1)
