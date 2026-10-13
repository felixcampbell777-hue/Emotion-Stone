"""Fetch only the reviewed CC0 data assets; inspect archive paths before extraction."""
import urllib.request,hashlib,json,zipfile,pathlib
root=pathlib.Path(r'C:\Games\CoastalFoundation\art\source\heroine-anime-presets');root.mkdir(parents=True,exist_ok=True)
assets=[('cartoon01_cc0.zip','https://files2.makehumancommunity.org/asset_packs/cartoon01/cartoon01_cc0.zip','https://static.makehumancommunity.org/assets/assetpacks/cartoon01.html'),('mngeye_base.blend','https://note.com/api/v2/attachments/download/7045915cf986f41ad17b0db4426e8e18','https://note.com/lab1092/n/ne7cd24b488bb')]
records=[]
for name,url,origin in assets:
    request=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'})
    with urllib.request.urlopen(request,timeout=60) as response:
        data=response.read();resolved=response.url
    assert len(data)<100_000_000
    path=root/name;path.write_bytes(data)
    if name.endswith('.zip'):
        with zipfile.ZipFile(path) as archive:
            entries=[]
            for item in archive.infolist():
                target=(root/'cartoon01'/item.filename).resolve()
                assert target.is_relative_to((root/'cartoon01').resolve()),item.filename
                assert item.file_size<20_000_000
                assert pathlib.Path(item.filename).suffix.lower() in ('','.target','.thumb','.png','.json','.txt','.mhmat','.mhclo','.obj'),item.filename
                if item.filename.endswith('.thumb'):
                    assert archive.read(item).startswith((b'\x89PNG',b'\xff\xd8')),item.filename
                entries.append(item.filename)
            archive.extractall(root/'cartoon01')
    else:
        assert data.startswith(b'BLENDER') or data.startswith(b'\x1f\x8b') or data.startswith(b'\x28\xb5\x2f\xfd'),'Not a Blender file'
        entries=None
    records.append(dict(filename=name,source=url,resolved_url=resolved,license='CC0',license_evidence=origin,sha256=hashlib.sha256(data).hexdigest(),bytes=len(data),archive_entries=entries))
with open(root/'LICENSE-AND-INTAKE.json','w') as f:json.dump({'assets':records,'auto_execution':'disabled','defender_scan':'pending'},f,indent=2)
for r in records:print(r['filename'],r['bytes'],r['sha256'])
