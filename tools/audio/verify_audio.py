#!/usr/bin/env python3
"""Static audio catalog, provenance, and non-silence checks without Godot imports."""
from pathlib import Path
import array,hashlib,json,math,sys,wave
root=Path(__file__).resolve().parents[2]
failures=[];checks=0

def check(ok,label):
    global checks
    checks+=1
    if not ok:failures.append(label)
manifest=json.loads((root/'art/library/audio/original-audio-manifest.json').read_text())
licensed={}
for item in manifest['files']:
    p=root/item['file'];licensed[item['file']]=item['license']
    check(p.exists(),item['file']+' exists')
    check(hashlib.sha256(p.read_bytes()).hexdigest()==item['sha256'],item['file']+' hash')
    with wave.open(str(p)) as w:
        samples=array.array('h',w.readframes(w.getnframes()))
        peak=max(abs(n) for n in samples)
        check(100<peak<32767,item['file']+' non-silent unclipped PCM')
intake=json.loads((root/'art/library/audio/kenney-rpg/intake.json').read_text())
for item in intake['selected']:
    licensed[item['file']]=item['license']
    check(hashlib.sha256((root/item['file']).read_bytes()).hexdigest()==item['sha256'],item['file']+' hash')
wolf=json.loads((root/'art/library/audio/wolf-monster-intake.json').read_text())
licensed['game/assets/audio/wolf-monster.wav']=wolf['license']
check(hashlib.sha256((root/'art/library/audio/wolf-monster.mp3').read_bytes()).hexdigest()==wolf['sha256'],'wolf source hash')
check(hashlib.sha256((root/wolf['runtime']['file']).read_bytes()).hexdigest()==wolf['runtime']['sha256'],'wolf runtime hash')
events=json.loads((root/'game/content/world_rise/audio_events.json').read_text())['events']
for id,item in events.items():
    check(item['bus'] in ['UI','Music','Ambience','SFX'],'event bus '+id)
    check(-60<=item['gain_db']<=0,'event headroom '+id)
    check(item['pitch_min']>0 and item['pitch_max']>=item['pitch_min'],'pitch bounds '+id)
    for clip in item['clips']:
        local='game/'+clip.removeprefix('res://')
        check((root/local).is_file(),'clip exists '+local)
        check(licensed.get(local)=='CC0-1.0','exact license '+local)
result=dict(checks=checks,failures=failures,events=len(events),licensed_runtime_assets=len(licensed),runtime_bytes=sum(p.stat().st_size for p in (root/'game/assets/audio').rglob('*') if p.suffix in ['.wav','.ogg']))
print(json.dumps(result,indent=2))
sys.exit(bool(failures))
