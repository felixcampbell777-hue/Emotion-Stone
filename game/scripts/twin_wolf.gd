extends "res://scripts/beta_enemy.gd"
## A fixed island pair: alternating pressure, independent neck tells and delayed bites.
const CENTER=Vector3(-331,0,16)
const ATTACK_STATES=["windup","bite","bite_pause","follow_windup","follow_bite","rush"]
var engaged=false
var attack_kind="bites"
var turns=0
var cooldown=0.0
var rig:Skeleton3D
var neck_a=0.0
var neck_b=0.0
func configure(data:Dictionary,target:Node3D,saved:Dictionary={}) -> void:
	super.configure(data,target,saved)
	mob_category="canine";size_class="medium";state="circle"
	cooldown=.7 if String(data.id).ends_with("0") else 1.6
	var rigs=animal.find_children("*","Skeleton3D",true,false)
	if not rigs.is_empty():rig=rigs[0]
	for mesh in animal.find_children("*","MeshInstance3D",true,false):
		for index in range(mesh.mesh.get_surface_count()):
			var material=mesh.get_active_material(index)
			if material is StandardMaterial3D:
				material=material.duplicate();mesh.set_surface_override_material(index,material);coat_materials.append([material,material.albedo_color])
func peers() -> Array:
	var record=game.worldrise.packs.get(definition.pack,{})
	return record.get("members",[]).filter(func(e):return is_instance_valid(e) and e.health>0 and e!=self)
func bounded(at:Vector3) -> Vector3:
	var flat=CENTER+((at-CENTER)*Vector3(1,0,1)).limit_length(15)
	flat.y=game.current_world.ground_height(flat);return flat
func take_damage(amount:int,away:Vector3) -> void:
	super.take_damage(amount,away)
	engaged=true;cooldown=maxf(cooldown,1.0)
func begin_turn() -> void:
	turns+=1;attack_kind="rush" if turns%3==0 else "bites"
	direction=((player.position-position)*Vector3(1,0,1)).normalized()
	state="windup";state_time=.95 if attack_kind=="rush" else .8;lunge_hit=false
func contact(reach:float) -> void:
	if lunge_hit:return
	var offset=(player.position-position)*Vector3(1,0,1)
	if offset.length()>reach or direction.dot(offset.normalized())<.3:return
	if absf(player.position.y-position.y)>(1.5 if attack_kind=="rush" else 1.2):return
	if game.impact_blocked(position+Vector3.UP*.6,player.position+Vector3.UP*.6):return
	lunge_hit=true
	if player.try_parry(self,player.position-offset.normalized()*.65):return
	player.take_damage(14,offset.normalized())
func rotate_neck(name:String,angle:float) -> void:
	if rig==null:return
	var bone=rig.find_bone(name)
	if bone<0:return
	var basis=rig.global_basis*rig.get_bone_global_pose(bone).basis
	var axis=(basis.inverse()*(visual.global_basis*Vector3.RIGHT)).normalized()
	rig.set_bone_pose_rotation(bone,rig.get_bone_pose_rotation(bone)*Quaternion(axis,angle))
func animate(delta:float) -> void:
	var moving=velocity.length()>.2
	var purpose="run" if velocity.length()>3 else "walk" if moving else "idle"
	# Independent neck articulation carries the bite tells; do not make both heads bite together.
	var clip=animation_names.get(purpose,animation_names.idle)
	if current_animation!=clip:animator.play(clip,.1);current_animation=clip
	if state in ATTACK_STATES and state!="rush":animator.advance(delta);animator.seek(0,true)
	else:animator.advance(delta)
	var first=0.0;var second=0.0
	match state:
		"windup":
			var t=1-state_time/(.95 if attack_kind=="rush" else .8)
			first=-.5*smoothstep(0,.7,t)
			second=first if attack_kind=="rush" else -.08
		"bite":first=lerpf(-.5,.55,smoothstep(0,.16/.3,1-state_time/.3))
		"bite_pause":first=.3;second=-.15
		"follow_windup":first=.1;second=-.55*smoothstep(0,.75,1-state_time/.5)
		"follow_bite":second=lerpf(-.55,.55,smoothstep(0,.12/.3,1-state_time/.3))
		"rush":first=.25;second=.25
	neck_a=lerpf(neck_a,first,minf(1,delta*18));neck_b=lerpf(neck_b,second,minf(1,delta*18))
	rotate_neck("Neck3_A",neck_a);rotate_neck("Head_A",neck_a*.35)
	rotate_neck("Neck3_B",neck_b);rotate_neck("Head_B",neck_b*.35)
	visual.position.y=-.12*smoothstep(0,.7,1-state_time/.95) if state=="windup" and attack_kind=="rush" else 0.0
	for entry in coat_materials:entry[0].albedo_color=entry[1].lerp(Color("#bce8ff"),.5) if parry_flash>0 else entry[1].lerp(Color("#ffe0c0"),.4) if hit_flash>0 else entry[1]
func _physics_process(delta:float) -> void:
	if not simulation_enabled or not ai_enabled or health<=0 or not player.input_enabled:return
	if player.position.distance_squared_to(position)>3600 and not engaged and knockback.length_squared()<.01:return
	phase+=delta;cooldown=maxf(0,cooldown-delta);hit_flash=maxf(0,hit_flash-delta);parry_flash=maxf(0,parry_flash-delta)
	var toward=(player.position-position)*Vector3(1,0,1);var distance=toward.length()
	var in_territory=Vector2(player.position.x-CENTER.x,player.position.z-CENTER.z).length()<22
	if player.health<=0 or not in_territory:engaged=false
	elif (distance<14 and game.worldrise.can_see(self)) or health<max_health or peers().any(func(e):return e.engaged):engaged=true
	pack_engaged=engaged;velocity=Vector3.ZERO
	if not engaged and state in ATTACK_STATES:state="recover";state_time=.6;lunge_hit=true
	match state:
		"circle","idle","patrol":
			if engaged:
				var radial=toward.normalized();var side=1.0 if String(definition.id).ends_with("0") else -1.0
				var goal=player.position-radial*2.2+Vector3(radial.z,0,-radial.x)*side*1.1
				velocity=(bounded(goal)-position).limit_length(2.1)
				if cooldown<=0 and distance<(6 if (turns+1)%3==0 else 3.2) and not peers().any(func(e):return e.state in ATTACK_STATES) and game.worldrise.can_see(self):begin_turn()
			else:velocity=(bounded(home)-position).limit_length(1.3)
			var face=toward if engaged else velocity
			if face.length()>.01:visual.rotation.y=lerp_angle(visual.rotation.y,atan2(face.x,face.z),minf(1,delta*7))
		"windup","follow_windup":
			state_time-=delta
			if state_time>.25:direction=toward.normalized()
			if attack_kind=="bites":velocity=direction*.6
			visual.rotation.y=atan2(direction.x,direction.z)
			if state_time<=0:
				state="rush" if attack_kind=="rush" else "follow_bite" if state=="follow_windup" else "bite"
				state_time=.48 if state=="rush" else .3;lunge_hit=false
		"bite","follow_bite":
			state_time-=delta;velocity=direction*2.6 if state_time>.1 else Vector3.ZERO
			if state_time<.16:contact(1.8)
			if state_time<=0 and state in ["bite","follow_bite"]:
				state="bite_pause" if state=="bite" else "recover";state_time=.32 if state=="bite_pause" else 1.15;cooldown=2.4
		"bite_pause":
			state_time-=delta
			if state_time<=0:state="follow_windup";state_time=.5;lunge_hit=false
		"rush":
			state_time-=delta;velocity=direction*8.4;contact(1.25)
			if state_time<=0 and state=="rush":state="recover";state_time=1.3;cooldown=2.4
		"recover":
			state_time-=delta
			if state_time<=0:state="circle"
	if state=="recover":velocity=Vector3.ZERO
	# Steer AI away from the rim without cancelling physical sword/parry knockback.
	var radial=(position-CENTER)*Vector3(1,0,1)
	if radial.length()>14.5 and velocity.dot(radial)>0:velocity-=radial.normalized()*velocity.dot(radial.normalized())
	velocity+=knockback;knockback=knockback.move_toward(Vector3.ZERO,delta*float(recoil_policy.deceleration))
	game.current_world.move_grounded(self,delta)
	var step=game.worldrise.animation_step(self,delta)
	if step>0:animate(step)
