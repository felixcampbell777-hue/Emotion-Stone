extends "res://scripts/beta_enemy.gd"

var boss_game:Node
var phase_clock:=0.0
var half_called:=false
var leap_target:=Vector3.ZERO

func configure(data:Dictionary,target:Node3D,saved:Dictionary={}) -> void:
	super.configure(data,target,saved);boss_game=game
	definition.display_name="Ashfang";mob_category="canine";size_class="large";max_health=360;health=clampi(int(saved.get("health",max_health)),0,max_health)
	collision.shape.radius=.85;collision.shape.height=2.6;collision.position.y=1.3
	visual.scale=Vector3.ONE*1.7
	for mesh in animal.find_children("*","MeshInstance3D",true,false):
		for surface in range(mesh.mesh.get_surface_count()):
			var material=mesh.mesh.surface_get_material(surface)
			if material is StandardMaterial3D:
				var copy=material.duplicate();copy.albedo_color=Color("#6f2922").lerp(copy.albedo_color,.3);mesh.set_surface_override_material(surface,copy)
	# Distinctive silhouette accents: enlarged mane/tail and ember-red eyes.
	for x in [-.28,.28]:
		var eye=Props.mesh_node(visual,SphereMesh.new(),Vector3(x,.92,.62),"#d71919");eye.scale=Vector3(.13,.13,.08)
	var mane=Props.cone(visual,Vector3(0,.78,-.12),.48,1.05,"#35191a",.30);mane.scale=Vector3(1.25,1.25,1.15)
	var tail=Props.cone(visual,Vector3(0,.72,-.95),.28,1.65,"#512020",.08);tail.rotation.x=-.95;tail.scale=Vector3(1.15,1.35,1.15)
	state="circle";tuning=tuning.duplicate(true);tuning.notice=22;tuning.damage=30;tuning.windup=1.35;tuning.lunge_seconds=.55;tuning.attack_speed=10;tuning.recovery=1.0

func _physics_process(delta:float) -> void:
	if not simulation_enabled or health<=0:return
	phase_clock+=delta;hit_flash=maxf(0,hit_flash-delta);parry_flash=maxf(0,parry_flash-delta);velocity=Vector3.ZERO
	if health<=max_health*.5 and not half_called:
		half_called=true;state="howl";state_time=2.2;boss_game.spawn_ashfang_wolves(position);boss_game.notify("Ashfang howls. Wolves emerge from the trees!")
	var toward=(player.position-position)*Vector3(1,0,1);var distance=toward.length()
	if ai_enabled and player.health>0:
		if state=="circle":
			var radial=toward.normalized();var tangent=Vector3(radial.z,0,-radial.x);velocity=(tangent*1.7-radial*.15);visual.rotation.y=lerp_angle(visual.rotation.y,atan2(toward.x,toward.z),delta*4)
			if distance<4.5:leap_target=position-toward.normalized()*4;state="leap";state_time=1.0
			elif distance<13:direction=toward.normalized();state="windup";state_time=1.35
		elif state=="windup":
			state_time-=delta;direction=toward.normalized();visual.rotation.y=lerp_angle(visual.rotation.y,atan2(direction.x,direction.z),delta*7)
			if state_time<=0:state="lunge";state_time=.55;lunge_hit=false
		elif state=="lunge":
			velocity=direction*10;state_time-=delta
			if not lunge_hit and distance<1.5:
				if distance<player.combat.parry.contact_range and player.try_parry(self):lunge_hit=true
				else:player.take_damage(30,direction);lunge_hit=true
			if state_time<=0:state="gnash";state_time=1.0;velocity=Vector3.ZERO
		elif state=="gnash":
			state_time-=delta
			if state_time<=0:state="leap";state_time=1.0;leap_target=position-toward.normalized()*5
		elif state=="leap":
			state_time-=delta;var p=1-clampf(state_time,0,1);position=position.lerp(leap_target,.08);visual.position.y=sin(p*PI)*2.5
			if state_time<=0:visual.position.y=0;state="circle";boss_game.ashfang_impact(position)
		elif state=="howl":
			state_time-=delta
			if state_time<=0:state="circle"
	var purpose="attack" if state in ["windup","lunge","gnash"] else "run" if velocity.length()>1 else "idle"
	if animator!=null:
		var clip=animation_names.get(purpose,animation_names.get("idle",""));if not clip.is_empty():animator.play(clip);animator.advance(delta)
	if game!=null:game.current_world.move_grounded(self,delta)
