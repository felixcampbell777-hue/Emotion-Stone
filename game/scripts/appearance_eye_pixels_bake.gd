extends SceneTree
## Authoring utility: retain CPU-readable source pixels across ASTC/BC exports.
func _initialize() -> void:
	var image=Image.load_from_file("res://assets/characters/heroine-beta_2-color.png")
	if image==null:push_error("Original eye map is unavailable");quit(1);return
	var result=ResourceSaver.save(image,"res://assets/characters/heroine-appearance-eye-pixels.res")
	print("APPEARANCE_EYE_PIXELS ",JSON.stringify({"width":image.get_width(),"height":image.get_height(),"format":image.get_format(),"saved":result==OK}))
	quit(0 if result==OK else 1)
