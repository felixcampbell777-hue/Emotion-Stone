"""Apply the scoped wolf update without resetting other Beta/Alpha content."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def read(path):return json.loads((ROOT/path).read_text(encoding='utf-8'))
def write(path,data):(ROOT/path).write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
beta=read('game/content/beta.json')
beta['animals']['beta_wolf'].update(model='res://assets/creatures/beta-wolf.glb',lunge_speed=7.8,lunge_seconds=.50,recovery=1.5)
beta['wolf_packs']={'patrol_speed':1.2,'circle_speed':2.2,'circle_radius':3.1,'circle_angular_speed':.32,'attack_distance':4.2,'first_attack_delay':1.65,'wave_interval':3.3,'leash_radius':12.0,'lost_sight_seconds':4.5,'territories':{'west_woodland':{'center':[-9,12],'radius':5.5},'east_woodland':{'center':[10,20],'radius':5.5}}}
write('game/content/beta.json',beta)
area=read('game/content/maps/beta_meadow.json')
for index,(name,center) in enumerate([('west_woodland',[-9,12]),('east_woodland',[10,20])],1):
    leader=next(e for e in area['enemies'] if e['id']==f'woodland_wolf_{index}')
    leader['pack']=name
    for member,(dx,dz) in enumerate([(-1.1,-1.2),(1.1,-1.2),(0,-2.2)],2):
        entry={'id':f'{name}_wolf_{member}','kind':'beta_wolf','at':[center[0]+dx,center[1]+dz],'size':'medium','pack':name}
        existing=next((e for e in area['enemies'] if e['id']==entry['id']),None)
        if existing:existing.update(entry)
        else:area['enemies'].append(entry)
write('game/content/maps/beta_meadow.json',area)
schema=read('schemas/map.schema.json');schema['properties']['enemies']['items']['properties']['pack']={'$ref':'#/$defs/id'};write('schemas/map.schema.json',schema)
write('game/content/release.json',{'version':'0.27.0','baseline':'Beta fur-textured wolves patrol in woodland packs, surround detected players and alternate single/paired lunges with a global two-attacker limit'})
print('WOLF_PACKS: two packs of four; 14 Beta encounters; original encounter IDs retained')
