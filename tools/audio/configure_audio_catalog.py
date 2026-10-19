from pathlib import Path
import json
root=Path(__file__).resolve().parents[2]
events={}
def add(id,clip,bus='SFX',gain=-10,priority=40,distance=40,cooldown=.04,caption=''):
    files=clip if isinstance(clip,list) else [clip]
    events[id]=dict(clips=['res://assets/audio/original/'+f+'.wav' for f in files],bus=bus,gain_db=gain,priority=priority,max_distance=distance,cooldown=cooldown,pitch_min=.96,pitch_max=1.04,caption=caption)
for surface in ['grass','dirt','stone','wood','metal','mud','water']:
    add('player.step.'+surface,['step_'+surface+'_'+str(v) for v in range(4)],gain=-16,priority=20,distance=16,cooldown=.12)
    add('enemy.step.'+surface,['step_'+surface+'_'+str(v) for v in range(4)],gain=-18,priority=15,distance=22,cooldown=.12)
for material in ['flesh','gel','stone','metal','wood']:
    add('combat.hit.'+material,['hit_'+material+'_'+str(v) for v in range(3)],gain=-9,priority=80,distance=45,caption='Weapon impact')
    add('projectile.impact.'+material,['hit_'+material+'_'+str(v) for v in range(3)],gain=-12,priority=65,distance=45)
for id,clip in {'player.jump':'jump','player.land':'land','player.dodge':'dodge','player.dash':'dash','player.hurt':'hurt','player.death':'death','player.stamina_denied':'denied','player.draw':'draw','player.sheathe':'sheathe','combat.swing.light':'swing_light','combat.swing.heavy':'swing_heavy','combat.swing.thrust':'thrust','combat.parry':'parry','combat.slam':'land','combat.thrust_stop':'wind','weapon.spear.thrust':'spear','weapon.spear.swing':'spear','weapon.spear.draw':'draw','weapon.rapier.thrust':'rapier','weapon.rapier.swing':'rapier','weapon.rapier.draw':'draw','weapon.bow.nock':'bow_nock','weapon.bow.draw':'bow_draw','weapon.bow.release':'bow_release','weapon.bow.cancel':'bow_nock','weapon.bow.dry':'denied','weapon.bow.pickup':'arrow_pickup','projectile.arrow.flight':'arrow_flight','ability.water.cast':'water_cast','ability.water.impact':'water_hit','ability.lance.release':'water_cast','ability.thrust.charge':'wind','world.water.enter':'water_enter','world.water.exit':'water_exit','world.water.drown':'drown'}.items():
    add(id,clip,gain=-10,priority=95 if id in ['combat.parry','player.hurt','player.death'] else 65,caption={'combat.parry':'Parry','player.hurt':'You were hit','player.stamina_denied':'Not enough stamina','world.water.drown':'Drowning'}.get(id,''))
for family,actions in {'wolf':{'tell':'wolf_tell','bite':'wolf_bite','pain':'wolf_pain','death':'wolf_death','howl':'wolf_howl'},'boar':{'tell':'boar_tell','charge':'boar_charge','pain':'boar_pain','death':'boar_death'},'twin_wolf':{'tell':'wolf_tell','bite_a':'wolf_bite','bite_b':'wolf_bite','rush':'wolf_tell','death':'wolf_death'},'ashfang':{'tell':'wolf_tell','lunge':'wolf_bite','land':'land','howl':'wolf_howl','death':'wolf_death'},'slime':{'tell':'slime_tell','leap':'slime_leap','land':'slime_land','hit':'hit_gel_0','death':'slime_death'},'giant_slime':{'tell':'slime_tell','leap':'slime_leap','land':'slime_land','split':'slime_split','death':'slime_death'},'resin':{'launch':'resin_launch','impact':'slime_land','sticky':'resin_sticky','release':'slime_leap','death':'slime_death'},'elder':{'form':'elder_form','tell':'elder_tell','sweep':'elder_sweep','slam':'elder_slam','rush':'elder_rush','throw':'stone_throw','stone_hit':'hit_stone_0','reflect':'parry','death':'boss_death'}}.items():
    for action,clip in actions.items():
        add('enemy.'+family+'.'+action,clip,gain=-9,priority=90 if action in ['tell','howl','form'] else 65,distance=65 if family in ['elder','ashfang'] else 40,caption=family.replace('_',' ').capitalize()+' '+action.replace('_',' '))
for id,clip in {'ui.focus':'ui_focus','ui.confirm':'ui_confirm','ui.back':'ui_back','ui.tab':'ui_confirm','ui.error':'denied','ui.open':'ui_open','ui.close':'ui_close','inventory.equip':'draw','inventory.unequip':'sheathe','inventory.drink':'drink','inventory.pickup':'pickup','economy.buy':'coin','economy.sell':'coin','economy.craft':'craft','economy.denied':'denied','quest.accept':'quest','quest.complete':'level','progression.level_up':'level','world.discovery':'discover','world.rest':'rest','world.travel':'travel','world.floor_arrival':'travel'}.items():
    add(id,clip,bus='UI',gain=-16 if id=='ui.focus' else -12,priority=70,cooldown=.08,caption=id.replace('.',' ').capitalize() if not id.startswith('ui.') else '')
for name in ['reach','fen','combat','vault','title']:
    add('music.'+name,'music_'+name,'Music',-22,10,0,0);events['music.'+name]['loop']=True;events['music.'+name]['pitch_min']=1;events['music.'+name]['pitch_max']=1
for name in ['wind','forest','night','fen','cave','water','guild','underwater','fire']:
    add('ambience.'+name,'amb_'+name,'Ambience',-21,5,0,0);events['ambience.'+name]['loop']=True;events['ambience.'+name]['pitch_min']=1;events['ambience.'+name]['pitch_max']=1
for family in ['wolf','twin_wolf','ashfang']:
    events['enemy.'+family+'.tell']['clips']=['res://assets/audio/wolf-monster.wav']
    events['enemy.'+family+'.tell']['pitch_min']=.85 if family=='ashfang' else .95
    events['enemy.'+family+'.tell']['pitch_max']=1.05
def imported(id,names):events[id]['clips']=['res://assets/audio/kenney/'+n+'.ogg' for n in names]
for mat in ['grass','dirt','stone']:
    for who in ['player','enemy']:imported(who+'.step.'+mat,['footstep'+n for n in (['00','01','02'] if mat!='stone' else ['03','04','05'])])
for id in ['player.draw','weapon.spear.draw','weapon.rapier.draw','inventory.equip']:
    imported(id,['drawKnife1','drawKnife2']);events[id]['pitch_min']=.8;events[id]['pitch_max']=.9
imported('combat.swing.light',['knifeSlice','knifeSlice2']);events['combat.swing.light']['pitch_min']=.65;events['combat.swing.light']['pitch_max']=.8
for id in ['economy.buy','economy.sell']:imported(id,['handleCoins','handleCoins2'])
imported('ui.open',['bookOpen']);imported('ui.close',['bookClose']);imported('player.dodge',['cloth1','cloth2'])
captions={'combat.parry':'Parry','player.hurt':'You were hit','player.stamina_denied':'Not enough stamina','world.water.drown':'Drowning','world.discovery':'Rest site discovered','world.rest':'Rested','world.travel':'Travelling','world.floor_arrival':'Arrived','progression.level_up':'Level up','quest.accept':'Contract accepted','quest.complete':'Contract completed','enemy.wolf.tell':'Wolf growls','enemy.boar.tell':'Boar prepares to charge','enemy.ashfang.tell':'Ashfang growls','enemy.ashfang.howl':'Ashfang howls','enemy.twin_wolf.tell':'Two-headed wolf growls','enemy.slime.tell':'Slime readies a leap','enemy.giant_slime.tell':'Giant slime readies a leap','enemy.elder.form':'Stone gathers into the Elder','enemy.elder.tell':'Elder prepares an attack','enemy.elder.sweep':'Elder swings','enemy.elder.slam':'Elder slams the ground','enemy.elder.rush':'Elder charges'}
for id,caption in captions.items():events[id]['caption']=caption
(root/'game/content/world_rise/audio_events.json').write_text(json.dumps({'version':1,'events':events},indent=2)+'\n')
print(len(events),'semantic audio events')
