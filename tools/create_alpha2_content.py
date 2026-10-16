"""Author Alpha 2 from explicit routes/landforms/encounters. No legacy spawn spacing or broad scatter."""
import json,math,random
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];CONTENT=ROOT/'game/content'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def write(p,d):p.write_text(json.dumps(d,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
def distance(p,a,b):
 dx,dz=b[0]-a[0],b[1]-a[1];t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dz)/max(.001,dx*dx+dz*dz)))
 return math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dz)
def near(lines,p,width):return any(distance(p,a,b)<width for line in lines for a,b in zip(line,line[1:]))
def point_in(r,p,pad=0):return r[0]-pad<=p[0]<=r[0]+r[2]+pad and r[1]-pad<=p[1]<=r[1]+r[3]+pad
plans=read(CONTENT/'alpha2_regions.json');campaign=read(CONTENT/'alpha2.json');stable=read(ROOT/'tools/alpha2_encounter_ids.json')
for id,plan in plans.items():
 m=read(CONTENT/'maps'/f'{id}.json');bounds=m['bounds'];routes=plan['routes']
 # Every rest, NPC and discovery has a deliberate spur to the nearest route.
 targets=[a['at'] for a in campaign['actions'] if a['map']==id]+[n['at'] for n in m['npcs']]
 for pt in targets:
  if near(routes,pt,1):continue
  candidates=[q for line in routes for q in line]
  closest=min(candidates,key=lambda p:math.dist(p,pt));routes=routes+[[closest,pt]]
 m['sculpted_terrain']=plan['hills'];m['terrain_regions']=[dict(kind='path' if m.get('cave') else 'sand' if m.get('biome')=='beach' else 'grass',rect=[bounds[0],bounds[1],bounds[2]-bounds[0],bounds[3]-bounds[1]])]
 if id=='a2_mill':m['terrain_regions'].append(dict(kind='water',rect=[20,-28,8,56]))
 if id=='a2_quarry':m['terrain_regions'].append(dict(kind='water',rect=[27,-30,3,60]))
 if id=='a2_belfry':m['terrain_regions'].append(dict(kind='water',rect=[19,-22,3,44]))
 if id=='a2_fen':m['terrain_regions'] += [dict(kind='water',rect=[-26,-20,13,30]),dict(kind='water',rect=[6,-14,20,35])]
 if not m.get('cave'):
  for z in range(bounds[1],bounds[3]):
   start=None
   for x in range(bounds[0],bounds[2]+1):
    selected=x<bounds[2] and near(routes,[x+.5,z+.5],1.7)
    if selected and start is None:start=x
    if not selected and start is not None:
     # Coastal paths stay sand; marsh causeway is real dry ground over flooded beds.
     m['terrain_regions'].append(dict(kind='sand' if id=='a2_mill' else 'path',rect=[start,z,x-start,1]));start=None
 # No leftover randomly scattered props or redundant sign forests.
 if not m.get('cave'):m['props']=[]
 m['enemies']=[e for g in plan['groups'] for e in g['members']]
 if id=='a2_belfry':m['enemies']=[dict(id='bellkeeper',kind='bellkeeper',at=[0,-3])]
 assert {e['id']for e in m['enemies']}=={x[0]for x in stable[id]},id
 m['catalog_enemies']=[];rng=random.Random(m['seed'])
 reserved=targets+[e['at'] for e in m['enemies']]
 for bank in plan['tree_banks']:
  for ix in range(math.ceil(bank[2]/2.7)):
   for iz in range(math.ceil(bank[3]/2.7)):
    pt=[round(bank[0]+ix*2.7+rng.uniform(-.35,.35),2),round(bank[1]+iz*2.7+rng.uniform(-.35,.35),2)]
    if not bounds[0]+1<pt[0]<bounds[2]-1 or not bounds[1]+1<pt[1]<bounds[3]-1:continue
    if near(routes,pt,2.9) or any(math.dist(pt,q)<2.4 for q in reserved):continue
    if any(math.dist(pt,g['center'])<3.6 for g in plan['groups']):continue
    if any(point_in(t['rect'],pt) for t in m['terrain_regions'] if t['kind']=='water'):continue
    m['props'].append(dict(id='bank_tree_'+str(len(m['props'])),kind='catalog_feature',at=pt,catalog_code='4A' if id=='a2_fen' else '1A' if (ix+iz)%3 else '3A',scale=round(rng.uniform(1.15,1.5),2),show_label=False))
 # One legible local guide per approach, set into an authored resting pocket.
 m['interactions']=[]
 for i,g in enumerate(plan['groups']):
  # Clues are set back on the approach, never in the trigger itself.
  at=min((p for line in plan['routes'] for p in line),key=lambda p:abs(math.dist(p,g['center'])-(g['trigger_radius']+3)))
  choices=[[at[0]+math.cos(j*math.pi/4)*2.8,at[1]+math.sin(j*math.pi/4)*2.8] for j in range(8)]
  choices=[q for q in choices if not near(routes,q,1.5) and all(math.dist(q,t)>1.8 for t in reserved)]
  if not choices:continue
  at=choices[0]
  if bounds[0]+1<at[0]<bounds[2]-1 and bounds[1]+1<at[1]<bounds[3]-1:
   m['interactions'].append(dict(id='local_clue_'+str(i),kind='sign',at=at,title=g['id'].replace('_',' ').title(),lines=[g['warning']]))
 m['subtitle']=plan['identity']
 if id=='a2_fen':m['wading']=True
 write(CONTENT/'maps'/f'{id}.json',m)
print('AUTHORED:',len(plans),'route networks;',sum(len(p['groups']) for p in plans.values()),'bounded encounter situations; all 46 encounter IDs retained.')
