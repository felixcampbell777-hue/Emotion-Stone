extends RefCounted
static func area(id:String="meadow",cave:bool=false) -> Dictionary:
 if cave:
  var result=JSON.parse_string(FileAccess.get_file_as_string("res://content/maps/menagery_cave.json")); result.id=id; result.display_name="Cave"; result.interactions=[]; result.exits=[]; result.catalog_enemies=[]
  return result
 return {"id":id,"display_name":id.capitalize(),"subtitle":"Custom area","seed":1508,"bounds":[-20,-20,20,20],"spawn":[0,8],"sea":false,"props":[],"terrain_regions":[],"exits":[],"npcs":[],"interactions":[],"catalog_enemies":[]}
static func example() -> Dictionary:
 var meadow=area(); var cave=area("cave",true)
 meadow.props=[{"id":"hill","kind":"catalog_feature","catalog_code":"1F","at":[-7,-4]},{"id":"tree","kind":"catalog_feature","catalog_code":"2A","at":[5,0]},{"id":"mouth","kind":"catalog_feature","catalog_code":"1G","at":[15,-12]}]
 meadow.exits=[{"id":"cave_door","rect":[13.8,-12.4,2.4,1.2],"target":"cave","spawn":[0,5.5],"label":"Enter cave","interact":true}]
 cave.exits=[{"id":"return_gate","rect":[-1.2,6.2,2.4,1.2],"target":"meadow","spawn":[15,-9.5],"label":"Return to meadow","interact":true}]
 return {"format":"coastal_world","version":1,"id":"my_world","name":"My World","start_map":"meadow","maps":[meadow,cave]}

static func blank() -> Dictionary:
 return {"format":"coastal_world","version":1,"id":"my_world","name":"My World","start_map":"meadow","maps":[area()]}
