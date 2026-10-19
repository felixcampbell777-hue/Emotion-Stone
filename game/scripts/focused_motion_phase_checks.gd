extends SceneTree
var failures:Array[String]=[]
var check_count=0
func _initialize() -> void:call_deferred("run")
func check(condition:bool,message:String) -> void:
	check_count+=1
	if not condition:failures.append(message);push_error(message)
func run() -> void:
	check(load("res://scripts/first_person_visuals.gd")!=null,"View-arm integration parses under pinned Godot")
	check(load("res://scripts/motion_contact_checks.gd")!=null,"Skinned steel clearance fixture parses under pinned Godot")
	check(load("res://scripts/capture_motion_repair.gd")!=null,"World Rise real-input capture parses under pinned Godot")
	load("res://scripts/locomotion_phase_checks.gd").new().run(self)
	load("res://scripts/swing_sampler_checks.gd").new().run(self)
	print("MOTION_PHASE ",check_count," checks; failures=",failures)
	quit(0 if failures.is_empty() else 1)
