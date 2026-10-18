"""Deterministic editable Floor Two graph, continuous heightfield and depth mask."""
from pathlib import Path
import json,random,math
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1];rng=random.Random(102018)
nodes=[];grid={}
for row in range(11):
 for col in range(11):
  x=(col-5)*36;z=(row-5)*36
  if math.hypot(x,z)>209:continue
  at=[round(x+rng.uniform(-6,6),2),round(z+rng.uniform(-6,6),2)]
  if (col,row)==(7,10):at=[72,180]
  grid[col,row]=len(nodes);nodes.append({'id':'island_%03d'%len(nodes),'at':at,'radii':[round(rng.uniform(8.5,13),2),round(rng.uniform(8.5,12),2)],'seed':rng.randrange(10000)})
arrival=grid[7,10];nodes[arrival]['radii']=[17,16]
# Random spanning tree guarantees a route; additional local links create loops/cross-connections.
neighbors={i:[] for i in range(len(nodes))}
for (col,row),i in grid.items():
 for k in [(col+1,row),(col-1,row),(col,row+1),(col,row-1)]:
  if k in grid:neighbors[i].append(grid[k])
visited={arrival};stack=[arrival];pairs=set()
while stack:
 a=stack[-1];choices=[b for b in neighbors[a] if b not in visited]
 if not choices:stack.pop();continue
 b=rng.choice(choices);visited.add(b);stack.append(b);pairs.add(tuple(sorted((a,b))))
for a,others in neighbors.items():
 for b in others:
  if a<b and (a,b) not in pairs and rng.random()<.28:pairs.add((a,b))
edges=[]
for a,b in sorted(pairs):
 x,z=nodes[a]['at'];u,v=nodes[b]['at'];dx=u-x;dz=v-z;length=math.hypot(dx,dz);bend=rng.uniform(-5,5)
 mid=[round((x+u)/2-dz/length*bend,2),round((z+v)/2+dx/length*bend,2)]
 edges.append({'a':a,'b':b,'points':[[x,z],mid,[u,v]],'width':round(rng.uniform(2.7,3.5),2)})
N=241;axis=np.linspace(-240,240,N,dtype=np.float32);X,Z=np.meshgrid(axis,axis);H=np.full((N,N),-3.6,dtype=np.float32)
def smooth(a,b,x):
 t=np.clip((x-a)/(b-a),0,1);return t*t*(3-2*t)
for node in nodes:
 x,z=node['at'];rx,rz=node['radii'];angle=np.arctan2(Z-z,X-x)
 q=np.sqrt(((X-x)/rx)**2+((Z-z)/rz)**2)/(1+.075*np.sin(angle*3+node['seed'])+.04*np.cos(angle*5))
 h=.85-4.35*smooth(.55,1.65,q)
 H=np.maximum(H,h)
for edge in edges:
 for (x,z),(u,v) in zip(edge['points'],edge['points'][1:]):
  dx=u-x;dz=v-z;t=np.clip(((X-x)*dx+(Z-z)*dz)/(dx*dx+dz*dz),0,1);d=np.hypot(X-x-dx*t,Z-z-dz*t)
  H=np.maximum(H,-.65-2.95*smooth(edge['width']*.55,edge['width']*1.6,d))
# The copied arrival plaza remains level and wide enough for its existing rings.
x,z=nodes[arrival]['at'];d=np.hypot(X-x,Z-z);H=np.maximum(H,.85-4.45*smooth(10,22,d))
H+=.035*np.sin(X*.31)*np.cos(Z*.29)*(1-smooth(8,13,d))
H=np.round(H,3)
# Three quiet rest islands punctuate long loops; future encounters remain editable data.
rest_ids=[arrival,min(range(len(nodes)),key=lambda i:math.dist(nodes[i]['at'],[-145,70])),min(range(len(nodes)),key=lambda i:math.dist(nodes[i]['at'],[125,-75])),min(range(len(nodes)),key=lambda i:math.dist(nodes[i]['at'],[-75,-145]))]
sites=[{'id':'arrival' if j==0 else 'swamp_rest_%d'%j,'at':nodes[i]['at'],'title':'Arrival Platform' if j==0 else 'Fen Refuge','type':'rest'} for j,i in enumerate(rest_ids)]
enemies=[]
for i,node in enumerate(nodes):
 if i in rest_ids or math.dist(node['at'],nodes[arrival]['at'])<50:continue
 if i%3==0:continue
 style=['green_slime','green_slime','moss_slime','resin_slime','bramble_slime'][i%5]
 for j in range(2 if i%4==0 else 1):
  angle=rng.random()*math.tau;enemies.append({'id':'fen_%03d_%d'%(i,j),'style':style,'at':[round(node['at'][0]+math.sin(angle)*3,2),round(node['at'][1]+math.cos(angle)*3,2)],'island':i})
spec={'version':1,'radius':240,'cell':2,'arrival':nodes[arrival]['at'],'nodes':nodes,'edges':edges,'sites':sites,'enemies':enemies,'heights':H.reshape(-1).tolist()}
path=ROOT/'game/content/world_rise/floor_02.json';path.write_text(json.dumps(spec,separators=(',',':'))+'\n')
assets=ROOT/'game/assets/environment/swamp';assets.mkdir(parents=True,exist_ok=True)
mask=np.uint8(np.clip((H+4)/6,0,1)*255);Image.fromarray(mask).save(assets/'depth-height.png')
base=json.loads((ROOT/'game/content/maps/wr_floor_01.json').read_text());base.update(id='wr_floor_02',display_name='World Rise · Floor 2 — The Drowned Labyrinth',subtitle='Follow pale shallows between low islands. Dark green water is deadly.',bounds=[-240,-240,240,240],spawn=spec['arrival'],props=[],npcs=[],interactions=[],exits=[],enemies=[{"id":e["id"],"kind":"slime","at":e["at"],"size":"medium"} for e in enemies],catalog_enemies=[],wading=True)
(ROOT/'game/content/maps/wr_floor_02.json').write_text(json.dumps(base,indent=2)+'\n')
print('SWAMP GENERATED',len(nodes),'islands',len(edges),'links',len(edges)-len(nodes)+1,'loops',len(enemies),'slimes')
