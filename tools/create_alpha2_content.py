"""Authored Hollow Bell campaign layout. Re-run only to deliberately reset these maps."""
import json, random
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
CONTENT=ROOT/'game/content'
def write(path,data): path.write_text(json.dumps(data,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
def area(id,name,subtitle,size=28,cave=False):
    return dict(id='a2_'+id,display_name=name,subtitle=subtitle,seed=820+len(id),bounds=[-8,-9,8,8] if cave else [-size,-size,size,size],spawn=[0,5] if cave else [0,size-6],sea=False,terrain_regions=[dict(kind='path' if cave else 'grass',rect=[-size,-size,size*2,size*2]),dict(kind='cobble',rect=[-2,-size,4,size*2]),dict(kind='cobble',rect=[-size,-2,size*2,4])],props=[],npcs=[],interactions=[],exits=[],enemies=[],catalog_enemies=[],**({'cave':True} if cave else {}))
maps={}
for args in [('haven','Hearthmere','An old compass promises a route to the royal vault',24),('crossroads','The Pilgrim Roads','West: mill and fen | East: quarry | North: old wood',32),('mill','The Drowned Mill','Resin on the millstones; the first of three ward-stones',28),('fen','Lantern Fen','Lost lanterns, a missing courier, and an older road',28),('quarry','Ashen Quarry','The stonecutters heard something singing underground',30),('wood','The Witness Wood','Three broken wards; one living witness',32),('watch','The Buried Watch','A forgotten refuge beneath the quarry',8,True),('sanctum','Chapel of the Unheard','The keepers wrote down the price of silence',8,True),('belfry','The Rootbound Belfry','The last bell is not made of bronze',22)]:
    m=area(*args); maps[m['id']]=m
def prop(m,kind,x,z,**kw):
    p=dict(id=kind+'_'+str(len(m['props'])),kind=kind,at=[x,z],**kw);m['props'].append(p);return p
def npc(m,id,char,x,z): m['npcs'].append(dict(id=id,character=char,role='a2_'+id,at=[x,z],dialogue=['The Hollow Bell']))
def sign(m,title,x,z,text): m['interactions'].append(dict(id='sign_'+str(len(m['interactions'])),kind='sign',at=[x,z],title=title,lines=[text]))
def link(a,b,point,spawn,label):
    maps['a2_'+a]['exits'].append(dict(id='to_'+b,rect=[point[0]-1.8,point[1]-1.1,3.6,2.2],target='a2_'+b,spawn=spawn,label=label,interact=True))
def pair(a,b,pa,pb):
    link(a,b,pa,[pb[0],pb[1]+(3 if pb[1]<0 else -3)],maps['a2_'+b]['display_name'])
    link(b,a,pb,[pa[0],pa[1]+(3 if pa[1]<0 else -3)],maps['a2_'+a]['display_name'])
pair('haven','crossroads',[0,-21],[0,29])
pair('crossroads','mill',[-29,0],[25,0])
pair('crossroads','quarry',[29,0],[-27,0])
pair('crossroads','wood',[0,-29],[0,29])
pair('mill','fen',[0,-25],[0,25])
pair('fen','wood',[25,0],[-29,0])
pair('quarry','wood',[0,-27],[29,0])
pair('quarry','watch',[23,17],[0,5.5])
pair('wood','sanctum',[0,-29],[0,5.5])
pair('sanctum','belfry',[0,-6.5],[0,19])
link('belfry','haven',[0,19],[0,-17],'Pilgrim road to Hearthmere')
def mob(m,kind,x,z,id=None): m['enemies'].append(dict(id=id or 'foe_'+str(len(m['enemies'])),kind=kind,at=[x,z]))
def slime(m,code,x,z): m['catalog_enemies'].append(dict(id='slime_'+str(len(m['catalog_enemies'])),code=code,at=[x,z]))
h=maps['a2_haven'];h['spawn']=[0,9]
for x,z in [(-9,8),(10,8),(-10,-8),(10,-8)]: prop(h,'house',x,z,rotation=0 if z<0 else 180)
prop(h,'well',5,0);prop(h,'bench',-5,3);prop(h,'market_stall',-9,0);prop(h,'market_stall',9,0)
npc(h,'mother','mother',-3,7);npc(h,'mara','farm_tessa',-5,-4);npc(h,'oren','farm_rowan',5,5);npc(h,'ada','keeper',5,-11)
sign(h,'North · Pilgrim Roads',2,-18,'Three roads leave the crossroads. Return here to speak with your companions, use the hearth, or save with F5. Quest journal: I → Quests. Draw sword: R. Parry: right mouse. Hold left mouse: heavy attack.')
for id in ['crossroads','mill','fen','quarry','wood']:
    m=maps['a2_'+id];s=m['bounds'][2]
    # Hand-authored clear axes connect every entrance; scenic scatter stays off them.
    rng=random.Random(m['seed'])
    for n in range(85 if id=='wood' else 12 if id=='quarry' else 46 if id=='fen' else 38):
        x=rng.uniform(-s+3,s-3);z=rng.uniform(-s+3,s-3)
        if abs(x)<5 or abs(z)<5: continue
        prop(m,'catalog_feature',round(x,2),round(z,2),catalog_code=rng.choice(['1A','2A','3A','4A'] if id=='fen' else ['1A','2A','3A']),scale=rng.uniform(.85,1.3),show_label=False)
    for x,z in [(-8,6),(9,-7),(-12,-14),(15,13)]: prop(m,'catalog_feature',x,z,catalog_code='3B',show_label=False)
    for x,z in [(-6,-18),(16,7),(-17,16)]: prop(m,'catalog_feature',x,z,catalog_code='3C',show_label=False)
    for ex in m['exits']:
        x=ex['rect'][0]+1.8;z=ex['rect'][1]+1.1
        sign(m,ex['label'],x+2.2,z,ex['label']+' · approach the trail marker and press E.')
    # Raised ground beside the road supplies readable silhouettes without breaking travel.
    prop(m,'catalog_feature',s-10,-s+10,catalog_code='1F',scale=1.35,show_label=False)
m=maps['a2_crossroads'];prop(m,'well',-8,0);prop(m,'bench',-6,3)
sign(m,'The three wards',2,5,'West: Drowned Mill, then Lantern Fen. East: Ashen Quarry. North: Witness Wood and the chapel. The routes reconnect; you may explore them in any order.')
for kind,x,z in [('slime',-12,1),('slime',-17,3),('goblin_raider',14,1),('goblin_slinger',19,-3),('slime',-2,-14),('goblin_raider',3,-21)]: mob(m,kind,x,z)
m=maps['a2_mill'];prop(m,'house',-12,-7);prop(m,'well',-7,-8);prop(m,'catalog_feature',-13,-12,catalog_code='2G',scale=1.5,show_label=False)
for x,z in [(12,2),(5,-4),(-4,-10),(-2,-17)]: slime(m,'2E',x,z)
for x,z in [(10,-11),(14,-16),(-7,13)]: slime(m,'1E',x,z)
mob(m,'goblin_slinger',-5,9);mob(m,'goblin_guard',-10,11)
sign(m,'The miller’s tally',-8,-4,'The roots sealed the millrace when the royal compass woke. The ward-stone is glowing behind the old wheel. I have hidden the treasure ledger beneath the old watch. — Oren')
m=maps['a2_fen'];npc(m,'jun','farm_mira',-9,-15)
for code,x,z in [('2E',0,13),('3E',4,8),('1E',-5,3),('2E',6,-6),('3E',0,-13),('1E',17,-1)]: slime(m,code,x,z)
mob(m,'goblin_raider',-10,-9);mob(m,'goblin_slinger',-14,-12)
for x,z in [(-14,7),(13,-13),(-16,-19)]: prop(m,'catalog_feature',x,z,catalog_code='4G',show_label=False)
sign(m,'Jun’s lantern marks',-5,-3,'The courier followed the western edge of the fen. A warm light shines beside the old willow north-west of here.')
m=maps['a2_quarry']
for x,z in [(-12,-9),(13,9),(-15,14),(17,-14)]: prop(m,'catalog_feature',x,z,catalog_code='4B',scale=1.6,show_label=False)
prop(m,'catalog_feature',23,17,catalog_code='1G',show_label=False)
for kind,x,z in [('goblin_raider',-16,2),('goblin_slinger',-11,-4),('goblin_guard',-3,8),('goblin_raider',3,12),('goblin_slinger',9,6),('goblin_guard',6,-11),('goblin_foreman',0,-18),('goblin_raider',14,-15),('goblin_slinger',17,14)]: mob(m,kind,x,z,'quarry_captain' if kind=='goblin_foreman' else None)
sign(m,'A warning scratched in slate',3,1,'The guards brace their shields until they attack. Parry their rush, then punish the recovery. The buried watch is south-east. The northern path leads to the Witness Wood.')
m=maps['a2_wood'];npc(m,'sable','keeper',-9,-20)
for kind,x,z in [('goblin_raider',-4,17),('goblin_slinger',5,12),('boar',-14,1),('boar',-17,4),('goblin_guard',13,0),('goblin_slinger',19,-4),('warden',0,-13)]: mob(m,kind,x,z,'ward_guardian' if kind=='warden' else None)
for code,x,z in [('3E',-1,5),('2E',-10,-7),('1E',8,-18)]: slime(m,code,x,z)
sign(m,'The guardian’s rule',2,-6,'A thrown stone can open living stone. Face the guardian and right-click just before its rock arrives, then attack the glowing cracks. Water Lance can breach the shell too.')
for id in ['watch','sanctum']:
    m=maps['a2_'+id]
    for x,z in [(-5,-4),(5,3),(-5,5)]: prop(m,'catalog_feature',x,z,catalog_code='4G',show_label=False)
m=maps['a2_watch'];mob(m,'goblin_guard',-4,0);mob(m,'goblin_slinger',3,-4);mob(m,'goblin_raider',-3,-5)
sign(m,'Names in the dark',-5,-6,'The royal treasure routes were hidden here. Sable’s notes show a key at each ward-stone. The oldest map points beyond this valley, toward the king’s islands.')
m=maps['a2_sanctum'];npc(m,'sable_chapel','keeper',-4,-5)
sign(m,'The keeper’s oath',5,-5,'The king left his compass-heart in the care of a living guardian. Attune the three wards, pass its test, and claim the lost roads.')
m=maps['a2_belfry'];m['spawn']=[0,16];mob(m,'bellkeeper',0,-3,'bellkeeper')
for i in range(8):
    import math
    a=i*math.tau/8;prop(m,'catalog_feature',round(math.sin(a)*15,2),round(math.cos(a)*15,2),catalog_code='2G',scale=1.4,rotation=-i*45,show_label=False)
for x,z in [(-18,-15),(18,-15),(-18,15),(18,15)]: prop(m,'catalog_feature',x,z,catalog_code='1A',scale=1.7,show_label=False)
maps['a2_mill']['terrain_regions'].append(dict(kind='water',rect=[-19,-16,4,8]))
maps['a2_fen']['terrain_regions'] += [dict(kind='water',rect=[-20,-6,10,10]),dict(kind='water',rect=[10,7,10,9])]
maps['a2_quarry']['terrain_regions'].insert(1,dict(kind='sand',rect=[-30,-30,60,60]))
# Actions have stable IDs; all rewards and progression derive from these records.
actions=[]
def action(id,map,at,title,type,**kw): actions.append(dict(id=id,map='a2_'+map,at=at,title=title,type=type,**kw))
for id,ma,at in [('hearth','haven',[0,5]),('pilgrim_fire','crossroads',[-6,0]),('mill_fire','mill',[17,17]),('fen_fire','fen',[-17,19]),('quarry_fire','quarry',[-21,19]),('wood_fire','wood',[4,24]),('chapel_fire','sanctum',[4,4])]: action(id,ma,at,'Rest · '+maps['a2_'+ma]['display_name'],'rest')
action('mill_ward','mill',[0,-21],'Quiet the drowned ward-stone','ward',requires=['a2_mill/slime_0','a2_mill/slime_1','a2_mill/slime_2','a2_mill/slime_3'],xp=180)
action('quarry_ward','quarry',[0,-23],'Quiet the ashen ward-stone','ward',requires=['a2_quarry/quarry_captain'],xp=220)
action('wood_ward','wood',[0,-19],'Quiet the witness ward-stone','ward',requires=['a2_wood/ward_guardian'],xp=250)
action('medicine','mill',[-14,13],'Search the abandoned medicine chest','quest',xp=80)
action('ledger','watch',[0,-5.5],'Recover the keeper’s ledger','quest',xp=140)
action('bellheart','belfry',[0,-3],'Take the Bellkeeper’s heart','heart',requires=['a2_belfry/bellkeeper'],xp=300)
for id,ma,at,item in [('mill_cache','mill',[-18,-19],'lanternglass'),('fen_cache','fen',[17,-19],'tidal_signet'),('quarry_cache','quarry',[20,-20],'starfall_band'),('watch_cache','watch',[-5,-5],'oakheart'),('wood_cache','wood',[-23,-23],'bloodbloom'),('pilgrim_cache','crossroads',[20,19],'wayfinder_boots')]: action(id,ma,at,'Open forgotten reliquary','loot',item=item,xp=75)
for id,ma,at in [('mill_supplies','mill',[14,12]),('quarry_supplies','quarry',[15,20]),('fen_supplies','fen',[-18,15]),('wood_supplies','wood',[20,20])]: action(id,ma,at,'Gather surviving remedies','loot',item='spring_elixir',count=2,xp=20)
action('root_memory','wood',[-22,-17],'Listen to the names in the roots','lore',xp=100,text='The roots repeat a cheerful message: Eli found a sea route to the old king’s islands. He asks Oren to bring a boat, two fishing rods, and absolutely no more turnip sandwiches.')
campaign=dict(id='hollow_bell',title='The Hollow Bell',maps=list(maps),start='a2_haven',boss='a2_belfry/bellkeeper',target_minutes=[45,75],actions=actions,quest_rewards=dict(medicine=240,courier=250,ledger=280,memory=220,ending=650),boss_tuning=dict(health=740,damage=18,ring_damage=16,windup=1.25,recovery=2.0,phase_threshold=.5))
for m in maps.values(): write(CONTENT/'maps'/f'{m["id"]}.json',m)
write(CONTENT/'alpha2.json',campaign)
print(f'Authored {len(maps)} linked areas, {sum(len(m["enemies"])+len(m["catalog_enemies"]) for m in maps.values())} enemies and {len(actions)} interactions')
