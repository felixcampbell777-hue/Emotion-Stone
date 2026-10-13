extends "res://scripts/slime.gd"
## Supplied animal clips with the established contact/parry/recoil rules.
var game:Node
var animal:Node3D
var animator:AnimationPlayer
var animation_names:Dictionary={}
var current_animation=""
var pack_target=Vector3.ZERO
var pack_speed=1.2
var pack_engaged=false
var coat_materials:Array=[]

func configure(data:Dictionary,target:Node3D,saved:Dictionary={}) -> void:
	super.configure(data,target,saved)
	var entry=JSON.parse_string(FileAccess.get_file_as_string("res://content/beta.json")).animals[data.kind]
	tuning=tuning.duplicate(true)
	for key in entry:
		if key in tuning: tuning[key]=entry[key]
	max_health=int(entry.max_health); health=clampi(int(saved.get("health",max_health)),0,max_health)
	# Small ground animals need a forgiving melee target above their visual back.
	# Movement collision and displayed model size still use the physical height.
	definition["display_name"]=entry.name; definition["combat_height"]=entry.get("combat_height",entry.height); definition["combat_radius"]=entry.radius
	definition["label_height"]=entry.height+.4
	for child in visual.get_children(): child.free()
	animal=load(entry.model).instantiate(); visual.add_child(animal)
	var bounds=load("res://scripts/standalone_hero.gd").bounds(animal)
	var factor=float(entry.height)/bounds.size.y
	animal.scale=Vector3.ONE*factor; animal.position.y=-bounds.position.y*factor
	animator=animal.find_children("*","AnimationPlayer",true,false)[0]
	animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for purpose in entry.clips:
		for clip in animator.get_animation_list():
			var expected=String(entry.clips[purpose]).replace(".","_")
			if String(clip)==expected or String(clip).ends_with("/"+expected):
				animation_names[purpose]=clip
				if purpose in ["idle","walk","run"]: animator.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
	body=MeshInstance3D.new(); body.mesh=SphereMesh.new(); body.visible=false; visual.add_child(body)
	var shape=CapsuleShape3D.new(); shape.radius=entry.radius; shape.height=maxf(entry.height,entry.radius*2)
	collision.shape=shape; collision.position.y=shape.height*.5
	visible=health>0; collision.disabled=health<=0; collision_layer=4 if health>0 else 0
	if has_node("Shadow"): get_node("Shadow").visible=false
	pack_target=home
	if data.kind=="beta_wolf":
		state="patrol"
		# Each animal has its own coat tint/flash, without changing the shared mesh.
		var variation=float(abs(String(data.id).hash())%5)*.025
		for mesh in animal.find_children("*","MeshInstance3D",true,false):
			for surface in range(mesh.mesh.get_surface_count()):
				var material=mesh.mesh.surface_get_material(surface)
				if material is StandardMaterial3D:
					material=material.duplicate()
					if material.resource_name.begins_with("Main") or material.resource_name.begins_with("Fur"):
						var tint=Color(1.0-variation,1.0-variation*.8,1.0-variation*.6)
						material.albedo_color*=tint
						coat_materials.append([material,material.albedo_color])
						if material.resource_name.begins_with("Fur"):
							material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
							material.alpha_scissor_threshold=.22
							material.cull_mode=BaseMaterial3D.CULL_DISABLED
					mesh.set_surface_override_material(surface,material)

func take_damage(amount:int,from_direction:Vector3) -> void:
	var before=health
	super.take_damage(amount,from_direction)
	if health<before and definition.kind=="beta_wolf" and is_instance_valid(game) and game.wolf_packs!=null:
		game.wolf_packs.alert(self)

func _physics_process(delta:float) -> void:
	if not simulation_enabled or health<=0: return
	if definition.kind=="beta_wolf": _wolf_tick(delta)
	else: super._physics_process(delta)
	visual.scale=Vector3.ONE
	var purpose="attack" if state in ["windup","lunge"] else "hit" if hit_flash>0 else "run" if velocity.length()>2.5 else "walk" if velocity.length()>.2 else "idle"
	var clip=animation_names.get(purpose,animation_names.get("idle",""))
	if clip.is_empty(): return
	if clip!=current_animation: animator.play(clip); current_animation=clip
	if purpose=="attack":
		var t=(1-state_time/float(tuning.windup))*.5 if state=="windup" else .5+(1-state_time/float(tuning.lunge_seconds))*.5
		animator.seek(clampf(t,0,1)*animator.get_animation(clip).length,true)
	else:
		var playback=1.0
		if definition.kind=="beta_wolf" and purpose in ["walk","run"]:
			playback=clampf(velocity.length()/(1.3 if purpose=="walk" else 3.8),.6,1.8)
		animator.advance(delta*playback)
	for entry in coat_materials:
		entry[0].albedo_color=entry[1].lerp(Color("#d1eef2"),.5) if parry_flash>0 else entry[1].lerp(Color("#efcfb8"),.5) if hit_flash>0 else entry[1]

func _wolf_tick(delta:float) -> void:
	phase+=delta; hit_flash=maxf(0,hit_flash-delta); parry_flash=maxf(0,parry_flash-delta)
	velocity=Vector3.ZERO
	visual.position.y=0
	if ai_enabled and is_instance_valid(player) and player.health>0:
		var toward=(player.position-position)*Vector3(1,0,1)
		var distance=toward.length()
		if state in ["patrol","circle","idle"]:
			var travel=(pack_target-position)*Vector3(1,0,1)
			if travel.length()>.18: velocity=travel.normalized()*minf(pack_speed,travel.length()*3)
			# Avoid stacking in a ring or crushing together around scenery.
			if is_instance_valid(game):
				for other in game.enemies:
					if other==self or other.health<=0 or other.definition.kind!="beta_wolf": continue
					var away=(position-other.position)*Vector3(1,0,1)
					if away.length()<1.0 and away.length()>.01: velocity+=away.normalized()*(1-away.length())*2.5
			velocity=velocity.limit_length(pack_speed)
			var facing=velocity if velocity.length()>.3 else toward if pack_engaged else velocity
			if facing.length()>.01: visual.rotation.y=lerp_angle(visual.rotation.y,atan2(facing.x,facing.z),minf(1,delta*7))
		elif state=="windup":
			state_time-=delta
			# Turn early, then commit the last 0.35s so a dodge can evade the leap.
			if state_time>.35: direction=toward.normalized()
			visual.rotation.y=lerp_angle(visual.rotation.y,atan2(direction.x,direction.z),minf(1,delta*9))
			if state_time<=0:
				state="lunge"; state_time=float(tuning.lunge_seconds); lunge_hit=false
		elif state=="lunge":
			velocity=direction*float(tuning.lunge_speed); state_time-=delta
			var progress=clampf(1-state_time/float(tuning.lunge_seconds),0,1)
			visual.position.y=sin(progress*PI)*.32
			if not lunge_hit and (not is_instance_valid(game) or not game.impact_blocked(position,player.position)):
				if distance<=float(player.combat.parry.contact_range) and player.try_parry(self): lunge_hit=true
				elif distance<.9:
					player.take_damage(int(tuning.damage),direction); lunge_hit=true
			if state_time<=0: state="recover"; state_time=float(tuning.recovery)
		elif state=="recover":
			state_time-=delta
			if state_time<=0: state="circle" if pack_engaged else "patrol"
	velocity+=knockback
	knockback=knockback.move_toward(Vector3.ZERO,delta*float(recoil_policy.deceleration))
	if is_instance_valid(player) and is_instance_valid(player.ground_world): player.ground_world.move_grounded(self,delta)
	else:
		move_and_slide(); position.y=0
