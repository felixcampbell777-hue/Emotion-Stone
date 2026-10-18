extends "res://scripts/swamp_slime.gd"
var jump_origin=Vector3.ZERO
var jump_target=Vector3.ZERO
var jump_clock=0.0
var warning:Node3D
func setup(owner:Node,entry:Dictionary,at:Vector3) -> void:
	super.setup(owner,entry,at)
	# Mother slime dimensions, without the queen's crown or brood abilities.
	body.mesh=body.mesh.duplicate();body.mesh.radius=1.45;body.mesh.height=2.35;body.position.y=1.05
	for child in visual.get_children():
		if child!=body:child.free()
	for x in [-.42,.42]:
		Props.box(visual,Vector3(x,1.35,1.40),Vector3(.20,.28,.10),"#172f26")
		Props.box(visual,Vector3(x-.04,1.42,1.47),Vector3(.05,.06,.03),"#e8f0e7")
	Props.box(visual,Vector3(0,.91,1.46),Vector3(.40,.07,.08),"#274c30")
	collision.shape.radius=1.25;collision.position.y=1.25
	definition.combat_height=2.2;definition.combat_radius=1.3;definition.label_height=2.9
func clear_warning() -> void:
	if is_instance_valid(warning):warning.queue_free()
func take_damage(amount:int,from_direction:Vector3) -> void:
	# A landed hit interrupts the tell or leap; retain a grounded, hittable body.
	if state in ["giant_warn","giant_jump"]:position.y=game.current_world.ground_height(position);clear_warning()
	super.take_damage(amount,from_direction)
func _exit_tree() -> void:clear_warning()
func _physics_process(delta:float) -> void:
	if not simulation_enabled or health<=0:return
	engaged=player.health>0 and ((player.position-position)*Vector3(1,0,1)).length()<18
	phase+=delta;hit_flash=maxf(0,hit_flash-delta);parry_flash=maxf(0,parry_flash-delta)
	set_body_color(Color("#b8ecdf" if parry_flash>0 else "#dae7a4" if hit_flash>0 else specimen.color))
	var tune=game.worldrise.swamp.Fen.spec.slime_combat
	velocity=Vector3.ZERO
	if ai_enabled and player.health>0:
		var toward=(player.position-position)*Vector3(1,0,1);var distance=toward.length()
		if state=="idle":
			visual.scale=Vector3(1+.04*sin(phase*4),1-.06*sin(phase*4),1+.04*sin(phase*4))
			if distance<18:
				visual.rotation.y=atan2(toward.x,toward.z)
				if distance<=float(tune.jump_range):
					jump_origin=position;jump_target=position+toward.limit_length(float(tune.jump_range));jump_target=game.current_world.safe_landing(jump_target)
					state="giant_warn";state_time=float(tune.jump_warning)
					warning=load("res://scripts/slime_warning.gd").new();game.current_world.add_child(warning);warning.configure(jump_target,float(tune.impact_radius),"")
				else:velocity=toward.normalized()*float(specimen.speed)
		elif state=="giant_warn":
			state_time-=delta;visual.scale=Vector3(1.24,.66,1.24)
			if state_time<=0:state="giant_jump";jump_clock=0;direction=((jump_target-position)*Vector3(1,0,1)).normalized()
		elif state=="giant_jump":
			jump_clock+=delta;var t=clampf(jump_clock/float(tune.jump_seconds),0,1)
			var goal=jump_origin.lerp(jump_target,t)+Vector3.UP*sin(t*PI)*float(tune.jump_height)
			move_and_collide(goal-position);visual.scale=Vector3(.88,1.18,.88)
			if t>=1:
				position.y=game.current_world.ground_height(position);clear_warning();state="recover";state_time=1.45;visual.scale=Vector3(1.3,.6,1.3)
				if ((player.position-position)*Vector3(1,0,1)).length()<float(tune.impact_radius) and absf(player.position.y-position.y)<2:
					var contact=player.position+(position-player.position).normalized()*.65
					if not player.try_parry(self,contact):player.take_damage(int(specimen.damage),direction)
			return
		elif state=="recover":
			state_time-=delta;visual.scale=Vector3.ONE.lerp(Vector3(1.3,.6,1.3),clampf(state_time/1.45,0,1))
			if state_time<=0:state="idle"
	velocity+=knockback;knockback=knockback.move_toward(Vector3.ZERO,delta*float(recoil_policy.deceleration))
	game.current_world.move_grounded(self,delta)
