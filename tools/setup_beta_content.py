"""Small, reproducible meadow/woodland layout and selected runtime art."""
import json,random,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
GAME=ROOT/'game'
def write(path,data):path.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
beta={'start_map':'beta_meadow','animals':{
    'beta_wolf':{'name':'Wolf','model':'res://assets/creatures/beta-wolf.gltf','max_health':80,'damage':12,'notice_range':6.5,'walk_speed':1.65,'lunge_speed':4.4,'windup':.85,'lunge_seconds':.32,'recovery':1.15,'height':.95,'radius':.33,'clips':{'idle':'Idle','walk':'Walk','run':'Gallop','attack':'Attack','hit':'Idle_HitReact1','death':'Death'}},
    'beta_rat':{'name':'Giant rat','model':'res://assets/creatures/beta-rat.glb','max_health':35,'damage':6,'notice_range':5.0,'walk_speed':1.4,'lunge_speed':3.6,'windup':.75,'lunge_seconds':.25,'recovery':1.3,'height':.40,'combat_height':1.0,'radius':.22,'clips':{'idle':'Idle.001','walk':'Walk','run':'Run','attack':'Attack.000','hit':'Hit','death':'Die'}}}}
write(GAME/'content/beta.json',beta)
rng=random.Random(71026)
props=[]
for index in range(28):
    x=rng.uniform(-21,21);z=rng.uniform(2,25)
    if abs(x)<3:x+=5
    props.append({'id':'woodland_tree_'+str(index),'kind':'tree','at':[round(x,2),round(z,2)],'scale':round(rng.uniform(.65,.93),2),'rotation':rng.randrange(360)})
for index,(x,z) in enumerate([(-13,-11),(15,-6),(-18,-2),(19,-15),(-20,16),(15,22)]):
    props.append({'id':'meadow_sapling_'+str(index),'kind':'tree','at':[x,z],'scale':.62,'rotation':rng.randrange(360)})
for index,(x,z) in enumerate([(-8,2),(9,6),(-17,15),(16,17),(-13,-5),(14,-8)]):
    props.append({'id':'moss_rock_'+str(index),'kind':'rock','at':[x,z],'scale':.8})
area={'id':'beta_meadow','display_name':'Beta · Meadow & Woodland','subtitle':'A quiet meadow beside sparse pine woodland','seed':71026,'bounds':[-24,-20,24,28],'spawn':[0,-12],'sea':False,'terrain_regions':[],'props':props,'npcs':[],'interactions':[],'exits':[],
    'enemies':[{'id':'meadow_slime','kind':'slime','at':[-5,3],'size':'medium'},{'id':'woodland_slime','kind':'slime','at':[5,8],'size':'medium'},{'id':'woodland_wolf_1','kind':'beta_wolf','at':[-9,12],'size':'medium'},{'id':'woodland_wolf_2','kind':'beta_wolf','at':[10,20],'size':'medium'},{'id':'woodland_rat_1','kind':'beta_rat','at':[8,3],'size':'small'},{'id':'woodland_rat_2','kind':'beta_rat','at':[-7,20],'size':'small'}],
    'catalog_enemies':[{'id':'woodland_resin_1','code':'2E','at':[-13,7]},{'id':'woodland_resin_2','code':'2E','at':[14,13]}]}
write(GAME/'content/maps/beta_meadow.json',area)
schema=json.loads((ROOT/'schemas/map.schema.json').read_text(encoding='utf-8'))
choices=schema['properties']['enemies']['items']['properties']['kind']['enum']
for kind in beta['animals']:
    if kind not in choices:choices.append(kind)
write(ROOT/'schemas/map.schema.json',schema)
progress=json.loads((GAME/'content/progression.json').read_text(encoding='utf-8'))
progress['enemy_xp'].update(beta_wolf=30,beta_rat=12)
write(GAME/'content/progression.json',progress)
schema=json.loads((ROOT/'schemas/progression.schema.json').read_text(encoding='utf-8'))
for kind in beta['animals']:schema['properties']['enemy_xp']['properties'][kind]={'type':'integer','minimum':1}
write(ROOT/'schemas/progression.schema.json',schema)
cores=json.loads((GAME/'content/monster_cores.json').read_text(encoding='utf-8'))
for kind in beta['animals']:
    if kind not in cores['beasts']:cores['beasts'].append(kind)
write(GAME/'content/monster_cores.json',cores)
main=GAME/'scripts/main.gd'
source=main.read_text(encoding='utf-8')
source=source.replace('return {"environment_revision":1,','return {"game_mode":game_mode,"environment_revision":1,')
main.write_text(source,encoding='utf-8')
dest=GAME/'assets/creatures';dest.mkdir(exist_ok=True)
# Apply the current wolf recipe rather than restoring superseded runtime art.
import runpy
runpy.run_path(str(ROOT/'tools/setup_wolf_packs.py'))
print('Beta meadow: 34 sparse trees, 6 rocks, 14 encounters; Alpha map definitions untouched.')

