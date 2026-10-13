extends MeshInstance3D
## Reusable air ribbons driven by the actor clock, never a sword trail.
var clock=0.0
var ribbons=ImmediateMesh.new()

func _ready() -> void:
	mesh=ribbons
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo=true
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.albedo_color=Color.WHITE
	material_override=material
	visible=false

func update_wind(actor:Node,delta:float) -> void:
	var charging=actor.state=="charge" and actor.thrust_charging
	var travel=actor.state=="thrust"
	visible=charging or travel
	if not visible:
		clock=0
		return
	clock+=delta
	rotation.y=atan2(actor.attack_direction.x,actor.attack_direction.z)
	var power=clampf(actor.state_time/float(actor.combat.thrust_charge.max_seconds),0,1) if charging else 1.0
	var fade=1.0 if charging else 1-smoothstep(0,.28,actor.state_time-actor.thrust_windup_seconds-actor.thrust_launch_seconds)
	visible=fade>0
	ribbons.clear_surfaces()
	if not visible: return
	var started=false
	var first_person=actor.first_person_driver!=null
	var eye=actor.first_person_driver.sample_first_person(0,false) if first_person else Transform3D.IDENTITY
	for streak in range(16):
		var seed=float(streak)/16
		var cycle=fposmod(clock*(.65+power*.45 if charging else 2.4)+seed,1.0)
		var angle=seed*TAU+clock*(1.5 if charging else .3)
		for segment in range(7):
			var a=point(charging,cycle,angle,segment/7.0,power)
			var b=point(charging,cycle,angle,(segment+1)/7.0,power)
			if first_person and minf((global_transform*a-eye.origin).dot(-eye.basis.z),(global_transform*b-eye.origin).dot(-eye.basis.z))<.50: continue
			var width=(.016+.014*power)*sin(PI*(segment+.5)/7)
			if first_person: width*=.5
			var side=Vector3(cos(angle),sin(angle),0)*width
			var opacity=fade*(.42+.28*power)*sin(PI*cycle)
			if first_person: opacity*=.6
			if not started: ribbons.surface_begin(Mesh.PRIMITIVE_TRIANGLES);started=true
			for vertex in [a-side,a+side,b+side,a-side,b+side,b-side]:
				ribbons.surface_set_color(Color(.85,.98,.94,opacity))
				ribbons.surface_add_vertex(vertex)
	if started: ribbons.surface_end()
	else: visible=false

func point(charging:bool,cycle:float,angle:float,along:float,power:float) -> Vector3:
	if charging:
		var z=lerpf(2.3,-.8,cycle)+along*.75
		var radius=.38+(1-cycle)*(.75+.25*power)
		var curl=angle+along*.7
		return Vector3(cos(curl)*radius,.72+sin(curl)*radius*.55,z)
	return Vector3(cos(angle)*(.42+.38*cycle),.70+sin(angle)*.40,lerpf(1.7,-2.4,cycle)+along*1.4)
