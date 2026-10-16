"""Author Dreadmore maps and reusable wall footprints; retain existing campaign IDs."""
import json, math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
C=ROOT/'game/content'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def write(p,j):p.write_text(json.dumps(j,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
plan=read(ROOT/'art/source/environments/dreadmore/layout.json')
def distance(p,a,b):
 dx,dz=b[0]-a[0],b[1]-a[1];t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dz)/max(.001,dx*dx+dz*dz)))
 return math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dz)
def route(p):return any(distance(p,a,b)<4 for line in plan['routes'] for a,b in zip(line,line[1:]))
walls=[]
for z in range(-60,60,4):
 start=None
 for x in range(-36,40,4):
  p=(x+2,z+2);solid=x<36 and not route(p) and not (4<p[0]<32 and -50<p[1]<-22)
  if solid and start is None:start=x
  if not solid and start is not None:
   walls.append([start,z,x-start,4,15+math.sin(z*.2)]);start=None
spec={'walls':walls,'routes':plan['routes'],'arena':[6,-48,24,24],'gate':[0,-50], 'selected_design':'C — Orchid Stalker'}
write(C/'dreadmore.json',spec)
def area(id,name,bounds,spawn):
 return dict(id=id,display_name=name,subtitle='',seed=20261016,bounds=bounds,spawn=spawn,sea=False,biome='jungle',terrain_regions=[dict(kind='grass',rect=[bounds[0],bounds[1],bounds[2]-bounds[0],bounds[3]-bounds[1]])],props=[],npcs=[],interactions=[],exits=[],enemies=[],catalog_enemies=[])
m=area('a2_canyon','Dreadmore Canyon',[-36,-60,36,60],[0,54]);m['subtitle']='Root-hung walls swallow the light. Something scratches far above.'
for z in range(-58,58):
 start=None
 for x in range(-34,35):
  selected=x<34 and route((x+.5,z+.5))
  if selected and start is None:start=x
  if not selected and start is not None:m['terrain_regions'].append(dict(kind='path',rect=[start,z,x-start,1]));start=None
m['enemies']=[dict(id='orchid_stalker',kind='canyon_fiend',at=[18,-35],size='giant')]
for group,at,codes in [('dripping',[-18,34],['9E','1E']),('resin',[6,17],['2E','9E']),('sluice',[-18,-3],['9E','9E','9E','9E'])]:
 for i,code in enumerate(codes):m['catalog_enemies'].append(dict(id=group+'_'+str(i),code=code,at=[at[0]+(i%2)*1.3,at[1]+i*.8],spawn_mode='tree_drop',drop_height=5.5+i*.5,trigger_radius=5,ambush_group='dreadmore_'+group))
for side,z in [('rear',4),('front',-10)]:
 for i,code in enumerate(['2E','1E']):m['catalog_enemies'].append(dict(id='sluice_'+side+'_'+str(i),code=code,at=[-19.3+i*2.6,z],spawn_mode='ground'))
m['interactions']=[dict(id='claw_warning',kind='sign',at=[7,-21],title='Fresh marks in the stone',lines=['Four hooked scores climb the cliff. Petals cling to wet stone. Above the right-hand passage, something moves.'])]
m['exits']=[dict(id='to_road',rect=[-2,55,4,2],target='a2_crossroads',spawn=[0,-26],label='Return to the Pilgrim Road',interact=True),dict(id='to_grove',rect=[-2,-57,4,2],target='a2_grove',spawn=[0,13],label='The woodland grove',interact=True)]
write(C/'maps/a2_canyon.json',m)
g=area('a2_grove','The Stillroot Grove',[-22,-22,22,22],[0,13]);g['biome']='woodland';g['subtitle']='A quiet circle of trees shelters the woodland attunement stone.'
g['terrain_regions'].append(dict(kind='path',rect=[-1.5,-6,3,22]))
g['exits']=[dict(id='to_canyon',rect=[-2,17,4,2],target='a2_canyon',spawn=[0,-54],label='Return to Dreadmore Canyon',interact=True)]
write(C/'maps/a2_grove.json',g)
road=read(C/'maps/a2_crossroads.json')
for e in road['exits']:
 if e['id']=='to_wood':e.update(target='a2_canyon',spawn=[0,54],label='Enter Dreadmore Canyon?')
write(C/'maps/a2_crossroads.json',road)
campaign=read(C/'alpha2.json')
for id in ['a2_canyon','a2_grove']:
 if id not in campaign['maps']:campaign['maps'].append(id)
for a in campaign['actions']:
 if a['id']=='wood_ward':a.update(map='a2_grove',at=[0,-3],title='Attune the woodland stone',requires=['a2_canyon/orchid_stalker'])
for a in [dict(id='canyon_fire',map='a2_canyon',at=[0,51],title='Rest · Dreadmore approach',type='rest'),dict(id='canyon_cache',map='a2_canyon',at=[24,12],title='Open the surveyor’s cache',type='loot',item='spring_elixir',count=2,xp=70),dict(id='canyon_spring',map='a2_canyon',at=[-30,-30],title='Rest · The sheltered spring',type='rest'),dict(id='grove_fire',map='a2_grove',at=[-5,6],title='Rest · Stillroot Grove',type='rest')]:
 if not any(old['id']==a['id'] for old in campaign['actions']):campaign['actions'].append(a)
write(C/'alpha2.json',campaign)
schema=read(ROOT/'schemas/map.schema.json');kinds=schema['properties']['enemies']['items']['properties']['kind']['enum']
if 'canyon_fiend' not in kinds:kinds.append('canyon_fiend')
write(ROOT/'schemas/map.schema.json',schema)
progress=read(C/'progression.json');progress['enemy_xp']['canyon_fiend']=350;write(C/'progression.json',progress)
cores=read(C/'monster_cores.json');template=next(c for c in cores['cores'] if c['id']=='bellkeeper_core').copy();template.update(id='orchid_core',name='Orchid Stalker Core',healing_percent=.65,family='boss',color='#7e9d82')
if not any(c['id']=='orchid_core' for c in cores['cores']):cores['cores'].append(template)
else:
 cores['cores']=[template if c['id']=='orchid_core' else c for c in cores['cores']]
cores['profiles']['canyon_fiend']=dict(drop_rate=1,generic='orchid_core',variant='',variant_chance=0,boss_bonus=700);write(C/'monster_cores.json',cores)
catalog=read(C/'menagery.json')
if not any(f['code']=='1H' for f in catalog['features']):catalog['features'].append(dict(code='1H',name='Inaccessible raised bluff',style='inaccessible_bluff',description='Tall solid rock wall; no walk-up slope. Rotate and scale to enclose paths.'))
write(C/'menagery.json',catalog)
print('AUTHORED DREADMORE:',len(walls),'union footprint runs, 8 concealed drop slimes plus 4 ranged supports, Orchid Stalker and attunement grove; stable woodland ward retained')
