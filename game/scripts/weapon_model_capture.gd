extends SceneTree
## Focused review of original static weapon meshes; gameplay captures remain a separate check.
const Models=preload("res://scripts/weapon_models.gd")
const Profiles=preload("res://scripts/weapon_profiles.gd")
func _initialize() -> void:call_deferred("capture")
func capture() -> void:
 root.size=Vector2i(1100,850)
 var world=Node3D.new();root.add_child(world)
 var environment=WorldEnvironment.new();var env=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("#252e37");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("#d9e7f1");env.ambient_light_energy=.6;environment.environment=env;world.add_child(environment)
 var light=DirectionalLight3D.new();world.add_child(light);light.rotation_degrees=Vector3(-35,-25,0);light.light_energy=1.5
 var fill=DirectionalLight3D.new();world.add_child(fill);fill.rotation_degrees=Vector3(-30,120,0);fill.light_energy=.65
 var camera=Camera3D.new();world.add_child(camera);camera.position=Vector3(4.0,2.4,6.5);camera.look_at(Vector3(0,1.65,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4.5;camera.current=true
 var index=0
 for id in ["field_spear","hunting_bow","duelist_rapier"]:
  var profile=Profiles.profile(id);var model=Models.create(profile.kind,profile);world.add_child(model)
  model.position=Vector3(-1.2+index*1.2,.7 if index!=1 else 1.65,0)
  if index!=1:model.rotation.z=PI
  else:Models.update_string(model,.8)
  index+=1
 for i in range(6):await process_frame
 await RenderingServer.frame_post_draw
 var directory=ProjectSettings.globalize_path("res://../output/weapon-review")
 DirAccess.make_dir_recursive_absolute(directory)
 var path=directory.path_join("weapon-models.png")
 var saved=root.get_texture().get_image().save_png(path)
 if saved!=OK:push_error("Weapon image save failed: "+str(saved))
 print("WEAPON_MODEL_CAPTURE "+path)
 quit()
