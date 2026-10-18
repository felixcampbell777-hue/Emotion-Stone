"""Apply authored Floor Two encounters using permanent island identities."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def apply(spec):
    registry=json.loads((ROOT/'docs/maps/floor-02-island-codes.json').read_text())
    codes={e['code'].removeprefix('F2-'):e for e in registry['islands']}
    # Kept only as an allowlist for existing saves, never used for spawning.
    spec['legacy_enemy_ids']=sorted(set(spec.get('legacy_enemy_ids',[])+[e['id'] for e in spec['enemies'] if e['style']!='giant_green_slime']))
    spec['enemies']=[]
    for code in ['G9','I8','I9','K6','D10','E6','I3']:
        e=codes[code];index=next(i for i,n in enumerate(spec['nodes']) if n['id']==e['island_id'])
        spec['enemies'].append({'id':'giant_'+code.lower(),'style':'giant_green_slime','at':e['at'],'island':index})
    spec['slime_combat']={'giant_health':128,'giant_damage':18,'jump_range':9.0,'jump_warning':1.0,'jump_seconds':.9,'jump_height':3.2,'impact_radius':2.1,'child_health':45,'child_damage':8,'child_xp':18}
    spec['sites']=[s for s in spec['sites'] if s['id']!='swamp_rest_d11']+[{'id':'swamp_rest_d11','at':codes['D11']['at'],'title':'Fen Refuge','type':'rest'}]
    spec['raft']={'island_id':codes['E11']['island_id'],'anchor':codes['E11']['at'],'deck_offset':[16,0],'deck_size':[8,9],'deck_height':.85}
    spec['version']=3
    return spec
if __name__=='__main__':
    p=ROOT/'game/content/world_rise/floor_02.json';spec=apply(json.loads(p.read_text()));p.write_text(json.dumps(spec,separators=(',',':'))+'\n')
    p=ROOT/'game/content/maps/wr_floor_02.json';area=json.loads(p.read_text());area['enemies']=[]
    for e in spec['enemies']:
        area['enemies'].append({'id':e['id'],'kind':'slime','at':e['at'],'size':'large'})
        for i in range(4):area['enemies'].append({'id':e['id']+'_split_'+str(i),'kind':'slime','at':e['at'],'size':'medium'})
    p.write_text(json.dumps(area,indent=2)+'\n')
