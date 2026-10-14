extends Node3D
## Remote camera owner; the real actor stays input-enabled so hits and AI remain live.
var game:Control
var tuning:Dictionary
var active=true
var elapsed=0.0
var impact_time=0.0
var birth_origin=Vector3.ZERO
var birth_view=Transform3D.IDENTITY
var desired_yaw=0.0
var desired_pitch=0.0
var flight_yaw=0.0
var flight_pitch=0.0
var direction=Vector3.FORWARD
var trail:Array=[]
var dragon=preload("res://scripts/mana_dragon_visual.gd").new()
var counter:Label
var collision=PhysicsShapeQueryParameters3D.new()
var impact_count=0
var reason=""

func configure(owner_game:Control,origin:Vector3,view:Transform3D,settings:Dictionary) -> void:
	game=owner_game;tuning=settings.duplicate(true);global_position=origin;birth_origin=origin;birth_view=view
	direction=-view.basis.z;flight_yaw=atan2(direction.x,-direction.z);flight_pitch=asin(clampf(direction.y,-1,1));desired_yaw=flight_yaw;desired_pitch=flight_pitch
	add_child(dragon);dragon.build()
	var shape=SphereShape3D.new();shape.radius=float(tuning.radius);collision.shape=shape;collision.collision_mask=1|4;collision.exclude=[game.player.get_rid()]
	counter=game.label("",18,Color("#9edee9"));counter.mouse_filter=Control.MOUSE_FILTER_IGNORE;game.add_child(counter)
	for i in range(28): trail.append(origin-direction*.04*i)
	_update_visual()
func steer(relative:Vector2) -> void:
	if not active or not game.player.input_enabled: return
	desired_yaw=wrapf(desired_yaw+relative.x,-PI,PI);desired_pitch=clampf(desired_pitch-relative.y,-1.15,1.15)
func view_transform() -> Transform3D:
	var forward_basis=Basis(Vector3.UP,-flight_yaw)*Basis(Vector3.RIGHT,flight_pitch)
	var view=Transform3D(forward_basis,global_position+forward_basis*Vector3(0,.42,-.56))
	return birth_view.interpolate_with(view,smoothstep(0,float(tuning.formation_seconds),elapsed))
func _physics_process(delta:float) -> void:
	if not is_instance_valid(game): queue_free();return
	if active and (game.player.health<=0 or game.recovering or game.player.state!="dragon_channel"):
		finish(false,true);return
	if is_instance_valid(counter): counter.visible=game.player.input_enabled
	if not game.player.input_enabled: return
	advance(delta)
func advance(delta:float) -> void:
	if not active:
		impact_time+=delta;dragon.show_impact(clampf(impact_time/float(tuning.impact_seconds),0,1),float(tuning.blast_radius))
		if impact_time>=float(tuning.impact_seconds): queue_free()
		return
	if game.player.health<=0 or game.player.state!="dragon_channel": finish(false,true);return
	var remaining=maxf(0,float(tuning.seconds)-elapsed);delta=minf(delta,remaining);elapsed+=delta
	flight_yaw=rotate_toward(flight_yaw,desired_yaw,float(tuning.turn_speed)*delta)
	flight_pitch=move_toward(flight_pitch,desired_pitch,float(tuning.turn_speed)*delta)
	var frame=Basis(Vector3.UP,-flight_yaw)*Basis(Vector3.RIGHT,flight_pitch);direction=-frame.z
	var birth=smoothstep(0,float(tuning.formation_seconds),elapsed)
	var movement=direction*float(tuning.speed)*delta*lerpf(.22,1,birth)
	collision.transform=Transform3D(Basis.IDENTITY,global_position);collision.motion=movement
	var space=get_world_3d().direct_space_state
	var overlaps=space.intersect_shape(collision,1)
	if not overlaps.is_empty(): finish(true,false,overlaps[0].collider);return
	var fractions=space.cast_motion(collision)
	if fractions[0]<1.0:
		global_position+=movement*fractions[0]
		collision.transform.origin=global_position+movement.normalized()*.015;collision.motion=Vector3.ZERO
		var contact=space.get_rest_info(collision)
		finish(true,false,instance_from_id(int(contact.collider_id)) if contact.has("collider_id") else null);return
	global_position+=movement
	var flat=Vector2(global_position.x,global_position.z)
	if not game.current_world.bounds.has_point(flat): reason="boundary";finish(false);return
	if global_position.y<game.current_world.ground_height(global_position)+.12: finish(true);return
	if trail[0].distance_to(global_position)>.025: trail.push_front(global_position)
	while trail.size()>300: trail.pop_back()
	_update_visual()
	if elapsed>=float(tuning.seconds): reason="timeout";finish(false)
func _update_visual() -> void:
	var birth=smoothstep(0,float(tuning.formation_seconds),elapsed)
	var frame=Basis(Vector3.UP,-flight_yaw)*Basis(Vector3.RIGHT,flight_pitch)
	dragon.global_transform=Transform3D(frame,global_position)
	var centers=[];var length=5.6*maxf(.08,birth);var previous=trail[0];var index=1;var walked=0.0
	for segment in range(28):
		var distance=length*segment/27;var point=previous
		while index<trail.size() and walked+previous.distance_to(trail[index])<distance:
			walked+=previous.distance_to(trail[index]);previous=trail[index];index+=1
		if index<trail.size():
			point=previous.lerp(trail[index],clampf((distance-walked)/maxf(.001,previous.distance_to(trail[index])),0,1))
		else: point=previous-direction*(distance-walked)
		var wave=sin(elapsed*6-segment*.42)*.12*birth*smoothstep(0,5,segment)
		point+=frame.x*wave;centers.append(point)
	dragon.update_shape(centers,elapsed,birth)
	counter.text="SEA DRAGON · %.1f s · Body vulnerable"%maxf(0,float(tuning.seconds)-elapsed)
	counter.position=game.world_rect.position+Vector2(game.world_rect.size.x*.5-190,92)
	# Only the gem glows during emergence; steel never remains blue after release.
	if elapsed>=float(tuning.formation_seconds): game.player.set_sword_glow(false)
func finish(explode:bool,immediate:bool=false,collider:Object=null) -> void:
	if not active: return
	active=false
	if is_instance_valid(counter): counter.queue_free()
	if game.sea_dragon==self: game.sea_dragon=null
	var alive=game.player.health>0 and not game.recovering
	game.player.set_sword_glow(false)
	if game.player.state=="dragon_channel" and alive:
		if immediate: game.player.set_sword_drawn(game.player.sword_drawn)
		else:
			game.player.state="dragon_recover";game.player.state_time=0;game.player.state_duration=.65
	game.camera_driver.end_remote_view(immediate)
	if explode and alive:
		impact_count+=1;reason="impact"
		for enemy in game.enemies:
			if not is_instance_valid(enemy) or enemy.health<=0: continue
			var target=enemy.global_position+Vector3(0,.55,0);var range=target.distance_to(global_position)
			var direct=enemy==collider
			if not direct and range>float(tuning.blast_radius): continue
			if not direct:
				var ray=PhysicsRayQueryParameters3D.create(global_position,target,1,[game.player.get_rid()])
				if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
			var away=(target-global_position).normalized()
			enemy.take_lance_damage(int(tuning.damage if direct else tuning.splash_damage),away)
		dragon.show_impact(0,float(tuning.blast_radius))
	else:
		if reason.is_empty(): reason="cancelled"
		queue_free()
