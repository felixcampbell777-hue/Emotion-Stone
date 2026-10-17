extends "res://scripts/beta_enemy.gd"
const West=preload("res://scripts/west_islands.gd")
var half_called=false
var engaged=false
var circle_clock=0.0
var leap_start=Vector3.ZERO
var leap_target=Vector3.ZERO
var tell:MeshInstance3D
func configure(data:Dictionary,target:Node3D,saved:Dictionary={}) -> void:
	super.configure(data,target,saved)
	definition.display_name="Ashfang";definition.combat_height=2.6;definition.combat_radius=.95;definition.label_height=3.0
	mob_category="canine";size_class="large";max_health=360;health=clampi(int(saved.get("health",max_health)),0,max_health)
	collision.shape=collision.shape.duplicate();collision.shape.radius=.85;collision.shape.height=2.6;collision.position.y=1.3
	visual.scale=Vector3.ONE*1.7
	home=West.GROVE;position=Vector3(-437,0,55);state="circle"
	for mesh in animal.find_children("*","MeshInstance3D",true,false):
		for surface in range(mesh.mesh.get_surface_count()):
			var original=mesh.get_active_material(surface)
			if not original is StandardMaterial3D:continue
			var mat=original.duplicate();var title=String(original.resource_name).to_lower()
			if "eye" in title:mat.albedo_color=Color("#f12e19");mat.emission_enabled=true;mat.emission=Color("#d72c16");mat.emission_energy_multiplier=2
			else:mat.albedo_color*=Color(.72,.64,.60)
			mesh.set_surface_override_material(surface,mat)
	var ring=TorusMesh.new();ring.inner_radius=1.3;ring.outer_radius=1.4;ring.rings=48;ring.ring_segments=6
	tell=Props.mesh_node(self,ring,Vector3(0,.07,0),"#ec9b48");tell.visible=false
func bounded(at:Vector3) -> Vector3:
	var d=(at-West.GROVE)*Vector3(1,0,1)
	var result=West.GROVE+d.limit_length(19);result.y=game.current_world.ground_height(result)
	return result
func start_leap(away:Vector3) -> void:
	state="leap";state_time=.8;leap_start=position
	var target=bounded(position+away*6)
	if Vector2(target.x-position.x,target.z-position.z).length()<2:target=bounded(position+Vector3(away.z,0,-away.x)*6)
	leap_target=target;leap_target.y=game.current_world.ground_height(target)
func _physics_process(delta:float) -> void:
	if not simulation_enabled or health<=0 or not ai_enabled:return
	phase+=delta;hit_flash=maxf(0,hit_flash-delta);parry_flash=maxf(0,parry_flash-delta);velocity=Vector3.ZERO
	var toward=(player.position-position)*Vector3(1,0,1);var distance=toward.length()
	if distance<19 and Vector2(player.position.x-West.GROVE.x,player.position.z-West.GROVE.z).length()<22:engaged=true
	if player.health<=0:engaged=false
	if engaged and health<=max_health*.5 and not half_called:
		half_called=true;state="howl";state_time=2.2
		game.worldrise.spawn_ashfang_wolves(position);game.notify("Ashfang howls. Three wolves emerge from the trees!")
	tell.visible=state=="windup"
	if engaged:
		match state:
			"circle":
				circle_clock+=delta
				var radial=toward.normalized();var tangent=Vector3(radial.z,0,-radial.x)
				var goal=bounded(position+tangent*2.7+radial*clampf(distance-8,-1,1));velocity=(goal-position).limit_length(2.7)
				visual.rotation.y=lerp_angle(visual.rotation.y,atan2(toward.x,toward.z),minf(1,delta*5))
				if distance<4.5:start_leap(-radial)
				elif circle_clock>=2.4 and distance<19:direction=radial;state="windup";state_time=1.35
			"windup":
				state_time-=delta
				if state_time>.4:direction=toward.normalized()
				visual.rotation.y=atan2(direction.x,direction.z);tell.scale=Vector3.ONE*(1+.2*sin(phase*16))
				if state_time<=0:
					state="lunge";state_time=.65;lunge_hit=false;leap_start=position
					leap_target=bounded(position+direction*minf(distance,14));leap_target.y=game.current_world.ground_height(leap_target)
			"lunge":
				state_time=maxf(0,state_time-delta);var t=1-state_time/.65
				var target=leap_start.lerp(leap_target,t);velocity=(target-position)/maxf(delta,.001);velocity.y=0
				visual.position.y=sin(t*PI)*1.7
				if not lunge_hit and distance<1.8 and not game.impact_blocked(position+Vector3.UP,player.position+Vector3.UP):
					lunge_hit=true
					if not player.try_parry(self):player.take_damage(30,direction)
				if state=="lunge" and state_time<=0:state="gnash";state_time=1.0;visual.position.y=0
			"gnash":
				state_time-=delta
				if state_time<=0:start_leap(-toward.normalized())
			"leap":
				state_time=maxf(0,state_time-delta);var t=1-state_time/.8
				var target=leap_start.lerp(leap_target,smoothstep(0,1,t));velocity=(target-position)/maxf(delta,.001);velocity.y=0;visual.position.y=sin(t*PI)*2.5
				if state_time<=0:visual.position.y=0;state="circle";circle_clock=0;game.worldrise.ashfang_impact(position)
			"howl","recover":
				state_time-=delta;visual.position.y=0
				if state_time<=0:state="circle";circle_clock=0
	velocity+=knockback;knockback=knockback.move_toward(Vector3.ZERO,delta*float(recoil_policy.deceleration))
	game.current_world.move_grounded(self,delta)
	var purpose="attack" if state in ["windup","lunge","gnash"] else "run" if velocity.length()>1 else "idle"
	var clip=animation_names.get(purpose,animation_names.get("idle",""))
	if not clip.is_empty():
		if current_animation!=clip:animator.play(clip);current_animation=clip
		if state=="windup":animator.seek((1-state_time/1.35)*.35*animator.get_animation(clip).length,true)
		elif state=="gnash":animator.seek((.45+.18*absf(sin(state_time*PI*4)))*animator.get_animation(clip).length,true)
		else:animator.advance(delta)
	for rig in animal.find_children("*","Skeleton3D",true,false):
		for bone in range(rig.get_bone_count()):
			var title=String(rig.get_bone_name(bone)).to_lower()
			if title=="neck1":rig.set_bone_pose_scale(bone,Vector3(1.35,1.15,1.35))
			elif title=="tail1":rig.set_bone_pose_scale(bone,Vector3(1.25,1.45,1.25))
