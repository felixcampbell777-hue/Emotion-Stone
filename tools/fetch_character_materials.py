import json,sys,shutil
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import fetch_polyhaven as download
root=Path(__file__).resolve().parents[1]
download.SOURCE=root/'art/character/source/polyhaven_cc0'
manifest=[]
for asset in ['fabric_pattern_07','leather_white']:
 meta=json.loads((root/'art/environment'/f'{asset}-files.json').read_text(encoding='utf-8-sig'))
 jobs=[(download.SOURCE/asset/(name+'.jpg'),meta['col_1' if kind=='Diffuse' and 'Diffuse' not in meta else kind]['2k']['jpg']) for kind,name in [('Diffuse','albedo'),('nor_gl','normal'),('Rough','roughness')]]
 with ThreadPoolExecutor(max_workers=3) as pool: records=list(pool.map(download.fetch_file,jobs))
 runtime=root/'game/assets/characters/textures'/asset;runtime.mkdir(parents=True,exist_ok=True)
 for name in ['normal.jpg','roughness.jpg']:shutil.copy2(download.SOURCE/asset/name,runtime/name)
 manifest.append({'asset':asset,'source':'https://polyhaven.com/a/'+asset,'license':'CC0-1.0','files':records})
 print('VERIFIED_CHARACTER_MATERIAL',asset,flush=True)
(root/'art/character/texture-intake.json').write_text(json.dumps(manifest,indent=2))

