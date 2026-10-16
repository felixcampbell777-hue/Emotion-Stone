extends RefCounted
const Props=preload("res://scripts/props.gd")
const Art=preload("res://scripts/environment_art.gd")
static var spec:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://content/dreadmore.json"))
var game:Node
var confirmation:ConfirmationDialog
var gate:Node3D
var gate_open=false

static func blocked(id:String,at:Vector3) -> bool:
	if id=="a2_crossroads" and at.z< -25 and absf(at.x)>4:return true
	if id=="a2_canyon":
		for wall in spec.walls:
			if Rect2(wall[0]-.05,wall[1]-.05,wall[2]+.1,wall[3]+.1).has_point(Vector2(at.x,at.z)):return true
	if id=="a2_grove" and Vector2(at.x,at.z).length()>16 and not (absf(at.x)<2.5 and at.z>12):return true
	return false
static func rock_material() -> StandardMaterial3D:
	var material=StandardMaterial3D.new();material.albedo_texture=load("res://assets/alpha2/rock_face/albedo.jpg")
	material.normal_enabled=true;material.normal_texture=load("res://assets/alpha2/rock_face/normal.jpg");material.roughness=.95
	material.uv1_triplanar=true;material.uv1_world_triplanar=true;material.uv1_scale=Vector3.ONE*.24;material.albedo_color=Color("#a5b69b")
	return material

static func bluff(parent:Node3D,r:Array) -> void:
	var x=float(r[0]);var z=float(r[1]);var w=float(r[2]);var d=float(r[3]);var h=float(r[4])
	var material=rock_material()
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Tessellated rock ribs and eroded shoulders retain solid vertical barriers.
	var corners=[Vector2(x-.10,z-.10),Vector2(x+w+.10,z-.10),Vector2(x+w+.10,z+d+.10),Vector2(x-.10,z+d+.10)]
	for side in range(4):
		var a:Vector2=corners[side];var b:Vector2=corners[(side+1)%4]
		var normal=Vector2((b-a).y,-(b-a).x).normalized()
		var count=maxi(2,ceili(a.distance_to(b)/1.7))
		for col in range(count):
			for row in range(9):
				var points=[]
				for uv in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
					var along=(col+uv.x)/count;var rise=(row+uv.y)/9
					var q=a.lerp(b,along)
					var rib=.18+.22*pow(sin(q.x*1.1+q.y*.9),2)+.16*sin(rise*19+q.x*.8)
					q+=normal*rib
					var top=h+sin(q.x*.4+q.y*.7)*.65
					points.append(Vector3(q.x,lerpf(-.35,top,rise),q.y))
				for index in [0,2,1,1,2,3]:st.add_vertex(points[index])
	var cap=[Vector3(x-.4,h,z-.4),Vector3(x+w+.4,h,z-.4),Vector3(x+w+.4,h,z+d+.4),Vector3(x-.4,h,z+d+.4)]
	for index in [0,2,1,0,3,2]:st.add_vertex(cap[index])

	st.generate_normals();var mesh=MeshInstance3D.new();mesh.name="InaccessibleBluff";mesh.mesh=st.commit();mesh.material_override=material;parent.add_child(mesh)
	Props.collider(parent,Vector3(x+w/2,h/2-.15,z+d/2),Vector3(w+.12,h+.3,d+.12))
func is_open() -> bool:return is_instance_valid(confirmation) and confirmation.visible
func request(route:Dictionary) -> bool:
	if route.target!="a2_canyon" or game.map_id!="a2_crossroads":return false
	if confirmation==null:
		confirmation=ConfirmationDialog.new();game.add_child(confirmation);confirmation.title="Dreadmore Canyon"
		confirmation.dialog_text="Enter Dreadmore Canyon?";confirmation.ok_button_text="Enter";confirmation.cancel_button_text="Stay here"
		confirmation.confirmed.connect(func():confirmation.hide();game._refresh_simulation();game.load_map("a2_canyon",Vector2(0,54)))
		confirmation.canceled.connect(func():game._refresh_simulation())
	confirmation.popup_centered(Vector2i(440,160));game._cancel_mouse_charge();game._refresh_simulation();return true
func tree(world:Node3D,at:Vector3,index:int,scale:float=1.8) -> void:
	var entry={"id":"dread_tree_"+str(index),"kind":"catalog_feature","catalog_code":"4A" if index%3==0 else "3A","at":[at.x,at.z],"scale":scale,"show_label":false}
	var node=Props.create(entry);world.add_child(node);node.position.y=at.y;Art.dress_prop(node,entry)
func plant(world:Node3D,at:Vector3,size:float) -> void:
	var node=Art.model(Art.ROOT+"models/fern_02.glb",Vector3(size,size*.62,size),false);world.add_child(node);node.position=at;node.rotation.y=at.x*1.7+at.z
func atmosphere(world:Node3D) -> void:
	# Forward+ volumes have a transparent-sheet fallback in other renderers.
	# High overlapping layers obscure the bright rim without hiding floor tells.
	for entry in [[1.1,.11],[2.3,.08],[11.5,.42],[14.0,.55],[17.0,.70]]:
		var plane=PlaneMesh.new();plane.size=Vector2(80,132)
		var mesh=MeshInstance3D.new();mesh.name="CanyonMist";mesh.mesh=plane;world.add_child(mesh);mesh.position.y=entry[0]
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material=ShaderMaterial.new();material.shader=load("res://shaders/canyon_mist.gdshader");material.set_shader_parameter("mist_color",Color(.055,.09,.075,entry[1]));mesh.material_override=material
	# Ground wisps are local to the walkable lanes, kept faint at eye level.
	for line in spec.routes:
		for i in range(1,line.size()):
			var a=Vector3(line[i-1][0],0,line[i-1][1]);var b=Vector3(line[i][0],0,line[i][1]);var length=a.distance_to(b)
			var plane=PlaneMesh.new();plane.size=Vector2(7,length+2)
			var wisp=MeshInstance3D.new();wisp.mesh=plane;world.add_child(wisp);wisp.position=(a+b)*.5+Vector3.UP*.18;wisp.rotation.y=atan2((b-a).x,(b-a).z)
			var material=ShaderMaterial.new();material.shader=load("res://shaders/canyon_mist.gdshader");material.set_shader_parameter("mist_color",Color(.29,.40,.34,.22));wisp.material_override=material;wisp.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if RenderingServer.get_current_rendering_method()=="forward_plus":
				var volume=FogVolume.new();volume.size=Vector3(7,1.7,length+1);world.add_child(volume);volume.position=(a+b)*.5+Vector3.UP*.65;volume.rotation.y=wisp.rotation.y
				var fog=FogMaterial.new();fog.density=.045;fog.albedo=Color("#617d70");volume.material=fog
func build() -> void:
	gate=null;gate_open=false
	if game.game_mode!="alpha2":return
	var world=game.current_world;var id=String(game.map_id)
	if id=="a2_crossroads":
		for r in [[-32,-32,28,7,14],[4,-32,28,7,15]]:bluff(world,r)
		# A dark, open cleft behind the confirmation marker; never a false door.
		var shade=Props.box(world,Vector3(0,4,-33),Vector3(7.8,8,.12),"#17231c");shade.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var fog=ShaderMaterial.new();var shader=Shader.new();shader.code="shader_type spatial; render_mode unshaded, cull_disabled, blend_mix; void fragment(){float rim=smoothstep(0.0,0.2,UV.x)*(1.0-smoothstep(0.8,1.0,UV.x)); ALBEDO=vec3(0.025,0.04,0.03); ALPHA=rim*0.88;}";fog.shader=shader;shade.material_override=fog
		var roof=Props.box(world,Vector3(0,9,-30.8),Vector3(8.4,6,3.8),"#63765b");roof.material_override=rock_material()
		Props.collider(world,Vector3(0,9,-30.8),Vector3(8.4,6,3.8))
		return
	if id=="a2_canyon":
		for r in spec.walls:bluff(world,r)
		for i in range(spec.walls.size()):
			var r=spec.walls[i]
			if i%2==0:tree(world,Vector3(r[0]+r[2]/2,r[4],r[1]+r[3]/2),i,2.0)
			if i%2==0:
				for j in range(3):
					var vx=float(r[0])+float(r[2])*(j+.5)/3;var vz=float(r[1])-.35;var length=5.0+fmod(i+j*1.7,5)
					var vine=Props.cone(world,Vector3(vx,r[4]-length/2,vz),.07,length,"#526346",.035);vine.rotation.z=sin(i+j)*.08;vine.material_override=Art.texture_material("pine_bark",1.0,Color("#74916a"))
			for side in [-1,1]:
				var at=Vector3(r[0]+r[2]/2,0,r[1]+(r[3] if side>0 else 0)+side*.6)
				if not blocked(id,at):plant(world,at,1.4)
		for line in spec.routes:
			for segment in range(1,line.size()):
				var a=Vector3(line[segment-1][0],0,line[segment-1][1]);var b=Vector3(line[segment][0],0,line[segment][1])
				var side=(b-a).normalized().cross(Vector3.UP)
				for step in range(ceili(a.distance_to(b)/4)):
					for sign in [-1,1]:
						var at=a.lerp(b,(step+.5)/maxf(1,ceil(a.distance_to(b)/4)))+side*sign*3.15
						if not blocked(id,at):plant(world,at,1.6)
		gate=Node3D.new();gate.name="FiendThornGate";world.add_child(gate);gate.position=Vector3(0,0,-50)
		for i in range(9):
			var thorn=Props.cone(gate,Vector3(-4+i,1.5,0),.21,3.0,"#405638",.04);thorn.rotation.z=sin(i)*.5
		Props.collider(gate,Vector3(0,2,0),Vector3(9,4,1))
		gate_open="a2_canyon/orchid_stalker" in game.defeated_enemies;update_gate()
		game.environment_settings.fog_density=.026;game.environment_settings.fog_light_color=Color("#253e35");game.environment_settings.ambient_light_energy=.42;game.environment_settings.tonemap_exposure=1.02
		game.world_root.get_node("WorldSun").light_energy=.8
		if game.environment_settings.sky!=null and game.environment_settings.sky.sky_material is ProceduralSkyMaterial:game.environment_settings.sky.sky_material.sky_energy_multiplier=.17
		game.environment_settings.volumetric_fog_enabled=RenderingServer.get_current_rendering_method()=="forward_plus";game.environment_settings.volumetric_fog_density=.025;game.environment_settings.volumetric_fog_albedo=Color("#344f42")
		atmosphere(world)
	elif id=="a2_grove":
		# Overlapping visible vegetation and solid root banks form a real ring.
		for i in range(48):
			var angle=i*TAU/48;var at=Vector3(sin(angle)*17,0,cos(angle)*17)
			if at.z>14 and absf(at.x)<3.5:continue
			tree(world,at,i,2.5);plant(world,at*.94,3.7)
			var bank=Props.collider(world,at+Vector3.UP*2,Vector3(3.2,4,3.2));bank.rotation.y=angle
			for j in range(3):plant(world,at+Vector3(sin(j*2+i)*1.1,0,cos(j*2+i)*1.1),2.5)
		game.environment_settings.fog_density=.008;game.environment_settings.ambient_light_energy=.65;game.environment_settings.tonemap_exposure=1.12
func update_gate() -> void:
	if is_instance_valid(gate) and gate_open:
		gate.queue_free();gate=null
func tick() -> void:
	if game.map_id=="a2_canyon" and not gate_open and "a2_canyon/orchid_stalker" in game.defeated_enemies:
		gate_open=true;update_gate();game.notify("The Orchid Stalker falls. The roots withdraw from the grove passage.")
