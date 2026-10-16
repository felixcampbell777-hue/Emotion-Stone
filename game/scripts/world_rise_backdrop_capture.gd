extends RefCounted
func run(g:Node,directory:String) -> void:
	g.set_resolution(0);g.set_process(false);g.player.set_physics_process(false)
	for child in g.world_root.get_children():
		if child is Node3D:child.visible=false;child.set_physics_process(false)
		if child is WorldEnvironment:child.environment=null
	var preview=preload("res://assets/environment/world_rise_backdrop/preview.tscn").instantiate();g.world_root.add_child(preview)
	for view in [[0,"north"],[1,"join"],[3,"west"]]:
		preview.set_view(view[0]);await g.get_tree().create_timer(.25).timeout;await RenderingServer.frame_post_draw;g.world_view.get_texture().get_image().save_png(directory+"/world-rise-backdrop-"+view[1]+".png")
	preview.camera.position=Vector3(0,4200,5800);preview.camera.look_at(Vector3(0,100,0));preview.camera.fov=70
	await g.get_tree().create_timer(.2).timeout;await RenderingServer.frame_post_draw;g.world_view.get_texture().get_image().save_png(directory+"/world-rise-backdrop-ring.png")
	var meshes=preview.find_children("*","MeshInstance3D",true,false)
	var triangles=0
	for mesh in meshes:
		if mesh.material_override is ShaderMaterial and mesh.name!="SunnyCloudSea":triangles+=mesh.mesh.get_faces().size()/3
	var report={"triangles":triangles,"unit_count":preview.get_node("WorldRiseBackdropRing").get_child_count()-1,"mountain_meshes":meshes.filter(func(n):return n.material_override is ShaderMaterial and n.name!="SunnyCloudSea").size(),"collision_shapes":preview.find_children("*","CollisionShape3D",true,false).size()}
	assert(report.triangles==73728 and report.unit_count==8 and report.mountain_meshes==24 and report.collision_shapes==0)
	var file=FileAccess.open(directory+"/world-rise-backdrop-report.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
