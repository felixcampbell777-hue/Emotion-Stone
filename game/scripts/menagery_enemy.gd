extends "res://scripts/slime.gd"
const Hazard=preload("res://scripts/menagery_hazard.gd")
const Shot=preload("res://scripts/menagery_projectile.gd")
var game:Node
var specimen:Dictionary
var style=""
var bounce_count=0
var regen_clock=0.0
var parts:Array=[]
var wings:Array=[]
var resin_dash_active=false
var dash_line:MeshInstance3D
var dash_target=Vector3.ZERO
var drop_height=3.8
var trigger_radius=6.0
var drop_origin=Vector3.ZERO
var drop_target=Vector3.ZERO
var drop_clock=0.0
var drop_warning:Node3D
var ambush_group=""
var canyon_support=false
func setup(owner:Node,entry:Dictionary,at:Vector3) -> void:
	game=owner; specimen=entry; style=entry.style
	configure({"id":"practice_"+entry.code.to_lower(),"kind":"practice","at":[at.x,at.z],"size":entry.size,"display_name":entry.code+" "+entry.name},game.player)
	position.y=game.current_world.ground_height(position)
	definition["combat_height"]=1.4 if style=="bat" else 1.0
	definition["label_height"]=1.6 if style=="bat" else 1.35
	max_health=int(entry.health); health=max_health
	for child in visual.get_children(): child.free()
	collision.shape=SphereShape3D.new()
	collision.shape.radius=.28 if entry.size=="small" else .46
	collision.position.y=.35
	if style.ends_with("slime"):
		var sphere=SphereMesh.new(); sphere.radius=.55; sphere.height=.95; sphere.radial_segments=10; sphere.rings=5
		body=Props.mesh_node(visual,sphere,Vector3(0,.48,0),entry.color)
		if style=="moss_slime":
			for i in range(6): Props.box(visual,Vector3(sin(i*2.4)*.35,.8,cos(i*2.4)*.3),Vector3(.19,.06,.19),"#a0bd69")
		elif style=="resin_slime":
			for i in range(4): Props.cone(visual,Vector3(sin(i*2.4)*.25,.9,cos(i*2.4)*.22),.08,.23,"#ecd386",.015)
		elif style=="bramble_slime":
			for i in range(7): Props.cone(visual,Vector3(sin(i*2.4)*.39,.72,cos(i*2.4)*.36),.09,.33,"#b5c5a0",0).rotation.z=sin(i)*.5
	elif style=="piglet":
		body=Props.box(visual,Vector3(0,.46,0),Vector3(.66,.52,.94),entry.color)
		Props.box(visual,Vector3(0,.43,.56),Vector3(.4,.26,.25),"#c09273")
		for x in [-.22,.22]:
			Props.cone(visual,Vector3(x,.49,.65),.045,.20,"#e5d6b3",0).rotation.x=-.4
			for z in [-.3,.3]: Props.box(visual,Vector3(x,.18,z),Vector3(.13,.36,.16),"#4e4035")
	elif style=="bat":
		body=Props.box(visual,Vector3(0,1.05,0),Vector3(.28,.35,.25),entry.color)
		for sign in [-1,1]:
			var wing=Props.box(visual,Vector3(sign*.4,1.05,0),Vector3(.65,.06,.36),"#ad899e")
			wings.append(wing)
			Props.cone(visual,Vector3(sign*.11,1.32,0),.07,.23,"#746687",0)
	elif style in ["hare","squirrel"]:
		body=Props.box(visual,Vector3(0,.36,0),Vector3(.37,.46,.55),entry.color)
		Props.box(visual,Vector3(0,.61,.25),Vector3(.30,.30,.29),entry.color)
		for x in [-.11,.11]:
			Props.cone(visual,Vector3(x,.93,.2),.075,.55 if style=="hare" else .20,entry.color,.045)
			Props.box(visual,Vector3(x,.10,-.05),Vector3(.15,.16,.32),"#d2ba96")
		var tail=Props.box(visual,Vector3(0,.58,-.45),Vector3(.3,.7,.25) if style=="squirrel" else Vector3(.18,.18,.18),"#c09361" if style=="squirrel" else "#e1d5b9")
		tail.rotation.x=-.5
	else:
		body=Props.cone(visual,Vector3(0,.42,0),.22,.8,"#d2c3a6",.16)
		Props.cone(visual,Vector3(0,.9,0),.72,.42,entry.color,.18)
		for x in [-.24,0,.24]: Props.box(visual,Vector3(x,1.12,.22),Vector3(.09,.03,.10),"#e4cfab")
	for x in [-.14,.14]: Props.box(visual,Vector3(x,.67 if style!="bat" else 1.15,.4 if style!="bat" else .15),Vector3(.065,.085,.05),"#283631")

func configure_placement(data:Dictionary) -> void:
	canyon_support=game.map_id=="a2_canyon" and String(data.get("id","")).begins_with("sluice_") and data.get("spawn_mode","ground")=="ground"
	if canyon_support:
		ambush_group="dreadmore_sluice";state="canyon_wait";visual.visible=false;get_node("Shadow").visible=false;collision.set_deferred("disabled",true)
	if data.get("spawn_mode","ground")!="tree_drop" or style not in ["green_slime","moss_slime","resin_slime","bramble_slime"]: return
	drop_height=float(data.get("drop_height",3.8)); trigger_radius=float(data.get("trigger_radius",6))
	ambush_group=data.get("ambush_group","")
	state="tree_wait"; position.y=game.current_world.ground_height(position)+drop_height
	drop_origin=position; collision.set_deferred("disabled",true)
	if game.map_id=="a2_canyon":visual.visible=false;get_node("Shadow").visible=false

func begin_tree_drop(offset:Vector3=Vector3.ZERO,caption:String="SLIME DROP") -> void:
	if state!="tree_wait" or health<=0: return
	if ambush_group=="dreadmore_sluice":
		var slot=clampi(String(definition.id).get_slice("_",1).to_int(),0,3)
		offset=[Vector3(-1.25,0,-1),Vector3(1.25,0,-1),Vector3(-1.25,0,1),Vector3(1.25,0,1)][slot]
	drop_target=game.current_world.safe_landing(player.position+offset)
	drop_warning=load("res://scripts/slime_warning.gd").new(); game.current_world.add_child(drop_warning); drop_warning.configure(drop_target,1.15,caption)
	state="tree_warn"; drop_clock=0

func _drop_tick(delta:float) -> bool:
	if state not in ["tree_wait","tree_warn","tree_fall"]: return false
	if not ai_enabled or player.health<=0: return true
	get_node("Shadow").position.y=game.current_world.ground_height(position)-position.y+.008
	visual.scale=Vector3(1.12,.8,1.12)
	if state=="tree_wait":
		if ((player.position-position)*Vector3(1,0,1)).length()<trigger_radius:
			begin_tree_drop()
			if not ambush_group.is_empty():
				var index=0
				for ally in game.enemies:
					if ally==self or not ally.has_method("begin_tree_drop") or ally.ambush_group!=ambush_group: continue
					if ally.canyon_support:
						ally.state="idle";ally.visual.visible=true;ally.get_node("Shadow").visible=true;ally.collision.set_deferred("disabled",false);continue
					var angle=index*TAU/3; ally.begin_tree_drop(Vector3(sin(angle),0,cos(angle))*.65,""); index+=1
	elif state=="tree_warn":
		drop_clock+=delta
		visual.position.y=sin(drop_clock*25)*.06
		if drop_clock>=.65: state="tree_fall"; drop_clock=0; visual.position.y=0;visual.visible=true;get_node("Shadow").visible=true
	else:
		drop_clock+=delta; var t=clampf(drop_clock/.85,0,1)
		position=drop_origin.lerp(drop_target,t)+Vector3.UP*(sin(t*PI)*.65)
		visual.scale=Vector3(.8,1.3,.8)
		if t>=1:
			position=drop_target; home=drop_target; collision.set_deferred("disabled",false)
			get_node("Shadow").position.y=.008
			if is_instance_valid(drop_warning): drop_warning.queue_free()
			if ((player.position-position)*Vector3(1,0,1)).length()<1.15:
				if not player.try_parry(self): player.take_damage(int(specimen.damage)+4,(player.position-position).normalized())
			state="recover"; state_time=.9; visual.scale=Vector3(1.4,.5,1.4)
	return true

func take_damage(amount:int,from_direction:Vector3) -> void:
	if state in ["tree_wait","tree_warn","tree_fall"]:
		visual.visible=true;get_node("Shadow").visible=true
		position.y=game.current_world.ground_height(position); collision.set_deferred("disabled",false); visual.position.y=0
		get_node("Shadow").position.y=.008
		if is_instance_valid(drop_warning): drop_warning.queue_free()
	regen_clock=0
	resin_dash_active=false
	if dash_line!=null: dash_line.visible=false
	super.take_damage(amount,from_direction)

func _release_ability() -> void:
	if style=="resin_slime":
		var gloop=load("res://scripts/resin_gloop.gd").new(); game.current_world.add_child(gloop)
		gloop.configure(game,self,player.position+player.velocity*.15); game.projectiles.append(gloop)
		state="recover"; state_time=float(specimen.recover); return
	elif style in ["bramble_slime","squirrel"] or (canyon_support and style=="moss_slime"):
		game.projectiles=game.projectiles.filter(func(item): return is_instance_valid(item))
		for angle in [-.25,0,.25] if style=="bramble_slime" else [0.0]:
			var shot=Shot.new(); game.current_world.add_child(shot)
			shot.configure(game,self,direction.rotated(Vector3.UP,angle),style=="bramble_slime" or style=="moss_slime")
			game.projectiles.append(shot)
		state="recover"; state_time=float(specimen.recover); return
	elif style=="puffcap":
		var patch=Hazard.new(); game.current_world.add_child(patch); patch.configure(game,position,false)
		state="recover"; state_time=float(specimen.recover); return
	state="lunge"; state_time=.45 if style=="piglet" else .32; lunge_hit=false

func notice_trapped_target() -> bool:
	if style!="resin_slime" or health<=0 or not ai_enabled or not simulation_enabled or state not in ["idle","recover","windup"] or knockback.length_squared()>.01 or hit_flash>0 or parry_flash>0: return false
	state="resin_charge"; state_time=float(game.menagery.catalog.resin_attack.charge_seconds)
	dash_target=player.position; direction=((dash_target-position)*Vector3(1,0,1)).normalized(); knockback=Vector3.ZERO
	if dash_line==null:
		dash_line=Props.box(self,Vector3.ZERO,Vector3(.20,.025,1),"#d77b2b")
	return true

func _physics_process(delta:float) -> void:
	if not simulation_enabled or health<=0: return
	if state=="canyon_wait":return
	if _drop_tick(delta): return
	phase+=delta
	hit_flash=maxf(0,hit_flash-delta); parry_flash=maxf(0,parry_flash-delta)
	set_body_color(Color("#b8ecdf" if parry_flash>0 else "#f3e5ae" if hit_flash>0 or state in ["windup","resin_charge"] else specimen.color))
	for i in range(wings.size()): wings[i].rotation.z=(1 if i==0 else -1)*sin(phase*16)*.45
	visual.scale=Vector3.ONE
	if style.ends_with("slime"): visual.scale=Vector3(1+.05*sin(phase*5),1-.08*sin(phase*5),1+.05*sin(phase*5))
	velocity=Vector3.ZERO
	if dash_line!=null: dash_line.visible=state=="resin_charge"
	if ai_enabled and is_instance_valid(player) and player.health>0:
		var toward=(player.position-position)*Vector3(1,0,1)
		var distance=toward.length()
		if state=="idle":
			if distance<(16 if canyon_support else 12):
				visual.rotation.y=atan2(toward.x,toward.z)
				var range=12.0 if canyon_support else 6.0 if style in ["bramble_slime","resin_slime","squirrel"] else 3.5 if style=="bat" else 2.4
				if style=="squirrel" and distance<2.8: velocity=-toward.normalized()*float(specimen.speed)
				elif distance<range and (not canyon_support or not game.impact_blocked(position,player.position)):
					state="windup"; state_time=float(specimen.windup); direction=toward.normalized(); bounce_count=0
				else:
					velocity=toward.normalized()*float(specimen.speed) if not canyon_support else Vector3.ZERO
					if style=="bat": velocity+=toward.normalized().rotated(Vector3.UP,PI/2)*.7
			else: velocity=(home-position).normalized()*float(specimen.speed) if position.distance_to(home)>.3 else Vector3.ZERO
			if style=="moss_slime" and distance>4:
				regen_clock+=delta
				if regen_clock>=3: health=mini(max_health,health+3); regen_clock=0
		elif state=="windup":
			state_time-=delta
			if style=="hare": velocity=direction.rotated(Vector3.UP,PI/2)*.9
			if style.ends_with("slime"): visual.scale=Vector3(1.18,.72,1.18)
			if state_time<=0: _release_ability()
		elif state=="resin_charge":
			var tuning=game.menagery.catalog.resin_attack
			state_time-=delta
			if state_time>float(tuning.aim_lock_remaining): dash_target=player.position+player.velocity*.12; direction=((dash_target-position)*Vector3(1,0,1)).normalized()
			visual.rotation.y=atan2(direction.x,direction.z); visual.scale=Vector3(1.25,.62,1.25)
			var length=clampf(((dash_target-position)*Vector3(1,0,1)).length()+.8,2.2,float(tuning.max_dash_distance))
			dash_line.scale.z=length; dash_line.position=direction*length*.5+Vector3.UP*.035; dash_line.rotation.y=atan2(direction.x,direction.z)
			if state_time<=0:
				state="lunge"; state_time=length/float(tuning.dash_speed); resin_dash_active=true; lunge_hit=false; dash_line.visible=false
		elif state=="lunge":
			velocity=direction*(float(game.menagery.catalog.resin_attack.dash_speed) if resin_dash_active else float(specimen.attack_speed))
			if resin_dash_active: visual.scale=Vector3(.82,.68,1.4)
			state_time-=delta
			if not lunge_hit:
				if distance<=float(player.combat.parry.contact_range) and player.try_parry(self): lunge_hit=true
				elif distance<.85: player.take_damage(int(specimen.damage),direction); lunge_hit=true
			if state_time<=0 and state=="lunge":
				if style in ["moss_slime","hare"] and bounce_count==0:
					bounce_count=1; state="windup"; state_time=.28; direction=toward.normalized().rotated(Vector3.UP,.24 if style=="hare" else -.12)
				else: state="recover"; state_time=float(game.menagery.catalog.resin_attack.recover_seconds) if resin_dash_active else float(specimen.recover); resin_dash_active=false
		elif state=="recover":
			state_time-=delta
			if state_time<=0: state="idle"
	velocity+=knockback
	knockback=knockback.move_toward(Vector3.ZERO,delta*float(recoil_policy.deceleration))
	game.current_world.move_grounded(self,delta)
