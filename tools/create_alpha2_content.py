"""Current authored biome layouts. Stable encounter IDs are a save compatibility contract."""
import json, math, random
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];CONTENT=ROOT/'game/content'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def write(p,d):p.write_text(json.dumps(d,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
ids=read(ROOT/'tools/alpha2_encounter_ids.json')
paths={
'a2_crossroads':[[[0,28],[5,19],[-3,9],[0,0]],[[0,0],[-12,-3],[-20,3],[-28,0]],[[0,0],[12,5],[22,-3],[28,0]],[[0,0],[-5,-12],[3,-22],[0,-28]]],
'a2_mill':[[[15,23],[7,13],[3,2],[8,-8],[0,-17],[-5,-25]],[[7,13],[-3,13],[-13,9],[-14,13]],[[3,2],[-11,-2],[-16,-9]],[[0,-17],[0,-21]]],
'a2_fen':[[[0,25],[5,16],[-5,8],[0,-1],[12,-4],[24,0]],[[0,-1],[-5,-10],[-9,-15]],[[-5,8],[-17,19]]],
'a2_quarry':[[[-27,0],[-15,-5],[-9,4],[0,8],[6,2],[0,-5],[-5,-15],[0,-23],[0,-27]],[[0,8],[12,12],[23,17]],[[-15,-5],[-21,19]]],
'a2_wood':[[[0,29],[-4,20],[6,12],[-2,4],[-8,-6],[3,-13],[0,-19],[0,-29]],[[-29,0],[-20,5],[-2,4]],[[29,0],[20,-5],[3,-13]],[[-8,-6],[-18,-8],[-22,-17]]],
'a2_sanctum':[[[0,7],[3,2],[0,-7]]], 'a2_belfry':[[[0,19],[4,12],[0,2],[0,-10]]],
}
def distance(point,a,b):
 dx,dz=b[0]-a[0],b[1]-a[1];t=max(0,min(1,((point[0]-a[0])*dx+(point[1]-a[1])*dz)/max(.0001,dx*dx+dz*dz)))
 return math.hypot(point[0]-a[0]-t*dx,point[1]-a[1]-t*dz)
def near_path(id,point,width=2):return any(distance(point,a,b)<width for line in paths.get(id,[]) for a,b in zip(line,line[1:]))
def base(id,name,subtitle,n=28,biome='woodland',sea=False):return dict(id=id,display_name=name,subtitle=subtitle,seed=1952+len(id),bounds=[-n,-n,n,n],spawn=[0,n-6],sea=sea,biome=biome,terrain_regions=[dict(kind='sand' if biome=='beach' else 'grass',rect=[-n,-n,n*2,n*2])],props=[],npcs=[],interactions=[],exits=[],enemies=[],catalog_enemies=[])
settings={'a2_crossroads':('The Forked Pilgrim Road','Saltwind Strand west · Skyglass Bluffs east · Heartwood north',32,'woodland',False),'a2_mill':('Saltwind Strand','Shipwreck salvage, tidal pools and the shore chime',28,'beach',True),'a2_fen':('Reedwater Marsh','A lantern trail among reed islands',28,'woodland',False),'a2_quarry':('Skyglass Bluffs','Climb the old watch road to the burrowing sentinel',30,'highlands',True),'a2_wood':('Heartwood','Follow the winding roots; listen before ringing',32,'woodland',False),'a2_sanctum':('The Open-Sky Chapel','The bell road crosses a roofless royal sanctuary',14,'highlands',False),'a2_belfry':('The Living Bell Court','Ancient roots overlook the sea',22,'highlands',True)}
maps={k:base(k,*v) for k,v in settings.items()}
for id in ['a2_haven','a2_watch']:maps[id]=read(CONTENT/'maps'/f'{id}.json')
maps['a2_sanctum']['bounds']=[-14,-20,14,20];maps['a2_sanctum']['spawn']=[0,5]
maps['a2_mill']['spawn']=[12,20]
# Paths are rasterized into short row runs, giving actual curved trails instead of repeated crosses.
for id,m in maps.items():
 if id not in paths:continue
 n=m['bounds'];kind='sand' if m['biome']=='beach' else 'path'
 for z in range(n[1],n[3]):
  runs=[];start=None
  for x in range(n[0],n[2]+1):
   selected=x<n[2] and near_path(id,(x+.5,z+.5),1.65)
   if selected and start is None:start=x
   if not selected and start is not None:runs.append(dict(kind=kind,rect=[start,z,x-start,1]));start=None
  m['terrain_regions']+=runs
 if id=='a2_mill':m['terrain_regions'].append(dict(kind='water',rect=[20,-28,8,56]))
 if id=='a2_quarry':m['terrain_regions'].append(dict(kind='water',rect=[27,-30,3,60]))
 if id=='a2_belfry':m['terrain_regions'].append(dict(kind='water',rect=[19,-22,3,44]))
 if id=='a2_fen':m['terrain_regions'] += [dict(kind='water',rect=[-22,-6,10,9]),dict(kind='water',rect=[9,8,12,9])]
 def add_prop(kind,at,**kw):m['props'].append(dict(id='biome_'+str(len(m['props'])),kind=kind,at=at,**kw))
 rng=random.Random(m['seed'])
 if id in ['a2_crossroads','a2_wood','a2_fen']:
  count=145 if id=='a2_wood' else 65 if id=='a2_fen' else 45
  for i in range(count):
   pt=[round(rng.uniform(n[0]+3,n[2]-3),2),round(rng.uniform(n[1]+3,n[3]-3),2)]
   if any(math.dist(pt,a['at'])<2.2 for a in read(CONTENT/'alpha2.json')['actions'] if a['map']==id) or near_path(id,pt,2.4) or any(math.dist(pt,at)<1.8 for _,at in ids.get(id,[])):continue
   if id=='a2_fen' and ((-22<pt[0]<-12 and -6<pt[1]<3) or (9<pt[0]<21 and 8<pt[1]<17)):continue
   add_prop('catalog_feature',pt,catalog_code='4A' if id=='a2_fen' else '1A' if i%3 else '3A',scale=rng.uniform(1.2,1.8) if id=='a2_wood' else rng.uniform(.9,1.35),show_label=False)
 m['sculpted_terrain']=[]
 def hill(id,at,h,r,profile='smooth',**kw):m['sculpted_terrain'].append(dict(id=id,at=at,height=h,radius=r,profile=profile,**kw))
 if id=='a2_mill':
  for i,pt in enumerate([[-5,18],[12,-17],[-10,-17]]):hill('dune_'+str(i),pt,.65,6)
 if id=='a2_quarry':
  hill('ascent',[0,-7],2.2,8,'bluff',plateau_width=14,plateau_depth=8);hill('north_descent',[0,-15],2.2,8)
  hill('west_shoulder',[-17,-13],1.5,7)
 if id=='a2_wood':
  for i,pt in enumerate([[12,20],[-16,15],[14,-14],[-15,-20]]):hill('forest_hill_'+str(i),pt,1.1,7)
 if id=='a2_belfry':hill('court',[0,-10],1.0,8)
# Every original encounter ID survives, but all Alpha 2 monsters now use collected skinned art.
for id,m in maps.items():
 if id=='a2_haven':continue
 m['enemies']=[];m['catalog_enemies']=[]
 for i,(enemy_id,at) in enumerate(ids.get(id,[])):
  if id=='a2_belfry':kind='bellkeeper'
  elif id=='a2_mill':kind='library_rat' if i in [1,3,5] else 'library_crab'
  elif id=='a2_quarry':kind='library_sentinel' if enemy_id=='quarry_captain' else 'library_crab' if i%2==0 else 'library_boar'
  elif id in ['a2_watch','a2_fen']:kind='library_spider' if i%2==0 else 'library_crab'
  else:kind='library_wolf' if i%3==0 else 'library_boar' if i%3==1 else 'library_spider'
  if kind=='library_rat':at={1:[-10,8],3:[-17,4],5:[-10,-3]}[i]
  if id=='a2_mill' and at[0]>17:at=[16,at[1]]
  m['enemies'].append(dict(id=enemy_id,kind=kind,at=at))
# Explicit bidirectional connections, reserved clear of scenery.
for m in maps.values():m['exits']=[]
def pair(a,b,pa,pb,sa=None,sb=None):
 for first,second,point,spawn in [(a,b,pa,sb or [pb[0],pb[1]+(3 if pb[1]<0 else -3)]),(b,a,pb,sa or [pa[0],pa[1]+(3 if pa[1]<0 else -3)])]:
  maps['a2_'+first]['exits'].append(dict(id='to_'+second,rect=[point[0]-1.6,point[1]-1,3.2,2],target='a2_'+second,spawn=spawn,label=maps['a2_'+second]['display_name'],interact=True))
pair('haven','crossroads',[0,-21],[0,29]);pair('crossroads','mill',[-29,0],[15,23],sb=[12,20]);pair('crossroads','quarry',[29,0],[-27,0]);pair('crossroads','wood',[0,-29],[0,29]);pair('mill','fen',[-5,-25],[0,25]);pair('fen','wood',[25,0],[-29,0]);pair('quarry','wood',[0,-27],[29,0]);pair('quarry','watch',[23,17],[0,5.5]);pair('wood','sanctum',[0,-29],[0,8],sb=[0,5]);pair('sanctum','belfry',[0,-6.5],[0,19])
maps['a2_belfry']['exits'].append(dict(id='to_haven',rect=[-1.6,18,3.2,2],target='a2_haven',spawn=[0,-17],label='Return to Hearthmere',interact=True))
def npc(id,name,char,at):maps[id]['npcs'].append(dict(id=name,character=char,role='a2_'+name,at=at,dialogue=['The Hollow Bell']))
npc('a2_fen','jun','farm_mira',[-9,-15]);npc('a2_wood','sable','keeper',[-9,-20]);npc('a2_sanctum','sable_chapel','keeper',[-4,-5])
# Replace old combat instructions and sign posts with biome-specific leads.
for id,m in maps.items():
 if id=='a2_haven':continue
 m['interactions']=[]
 for i,route in enumerate(m['exits']):
  at=[route['rect'][0]+3.7,route['rect'][1]+1]
  at=[max(m['bounds'][0]+1,min(m['bounds'][2]-1,at[0])),max(m['bounds'][1]+1,min(m['bounds'][3]-1,at[1]))]
  m['interactions'].append(dict(id='route_'+str(i),kind='sign',at=at,title=route['label'],lines=[route['label']+' · follow the trail marker and press E.']))
extra={
 'a2_mill':('The stranded bell',[1,15],'A bronze chime went down with the survey ship. Work the salvage winch near the wreck, then recover its net. Ring the shore ward after finding it.'),
 'a2_quarry':('The watch-road trial',[-9,3],'Follow the switchback up the bluffs. The burrowing sentinel guards the sky chime. Parry its thrown shell-stone or punish it after it emerges.'),
 'a2_wood':('The three forest voices',[3,14],'The listening roots remember the bells: deep earth, high bird, middle river. Ring those three notes at the Heartwood ward. Oren’s message lies beyond the western roots.'),
 'a2_watch':('The royal treasure ledger',[-5,-6],'The old surveyors charted the coast before the roads were lost. Their ledger waits in the back chamber.'),
}
for id,(title,at,line) in extra.items():maps[id]['interactions'].append(dict(id='biome_story',kind='sign',at=at,title=title,lines=[line]))
c=read(CONTENT/'alpha2.json')
for action in c['actions']:
 if action['id']=='mill_ward':action['title']='Ring the shore chime';action['requires']=[];action['requires_flags']=['tide_chime']
 if action['id']=='quarry_ward':action['title']='Claim the sky chime'
 if action['id']=='wood_ward':action['title']='Tune the Heartwood bells';action['requires']=[]
 if action['id']=='root_memory':action['text']=action['text'].split(' The trees answer in three tones:')[0]+' The trees answer in three tones: LOW, HIGH, MIDDLE.'
 if action['id']=='medicine':action['title']='Recover Mara’s medicine from the stranded cargo'
 if action['id']=='mill_cache':action['at']=[-18,-19]
 if action['type']=='rest':action['title']='Rest · '+maps[action['map']]['display_name']
c['actions']=[a for a in c['actions'] if a['id'] not in ['wreck_winch','tide_chime']]
c['actions'] += [dict(id='wreck_winch',map='a2_mill',at=[-13,9],title='Work the salvage winch',type='mechanism',xp=50),dict(id='tide_chime',map='a2_mill',at=[-16,-9],title='Recover the bronze chime from the salvage net',type='quest',requires_flags=['wreck_winch'],xp=120)]
for id,m in maps.items():
 if m['sea'] or id=='a2_fen':m['wading']=True
 write(CONTENT/'maps'/f'{id}.json',m)
write(CONTENT/'alpha2.json',c)
print('Authored distinct coast, forest, marsh and bluff routes; preserved all saved encounter IDs.')
