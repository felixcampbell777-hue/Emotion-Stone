extends RefCounted
## Actual broad steel owns reach; low carry and grounded catches follow its tip.
const TIP=-1.40/1.472
const GRIP=.10
const BLADE_BASE=-.025
const POMMEL=.25
const WIDTH=.10
const THICKNESS=.012

static func adapt(pose:Dictionary,key:String,t:float,scale:float,carry_basis:Basis=Basis.IDENTITY) -> Dictionary:
	var result=pose.duplicate()
	var direction:Vector3=(pose.tip-pose.grip).normalized()
	var reach=(GRIP-TIP)*scale
	var carry_weight=0.0
	if key=="drag": carry_weight=1.0
	elif key=="draw": carry_weight=smoothstep(.80,1.0,t)
	elif key=="roll": carry_weight=1-smoothstep(.0,.08,t)
	elif key=="stand": carry_weight=smoothstep(.85,1.0,t)
	else:
		carry_weight=smoothstep(.86,1.0,t)
		if key not in ["light2","light3"]: carry_weight=maxf(carry_weight,1-smoothstep(.0,.14,t))
	# Lower the burdened carry and bring its hand slightly inward. The shoulder's
	# authored lean and personal arm solver still provide the actual body movement.
	var drag_direction=Vector3(-.16,-.93,-1.915).normalized()
	var carry_drop=.03/.92-(.96+drag_direction.y*reach)
	result.grip+=carry_basis*Vector3(.07,carry_drop,0)*carry_weight
	var catch_weight=0.0
	if key=="light2": catch_weight=smoothstep(.42,.62,t)
	elif key=="light3": catch_weight=maxf(1-smoothstep(.0,.20,t),smoothstep(.53,.66,t))
	elif key=="heavy": catch_weight=smoothstep(.53,.66,t)
	var near_ground=1-smoothstep(.10,.40,float(pose.tip.y))
	var correction=minf(0.0,float(pose.tip.y)-(float(result.grip.y)+direction.y*reach))
	result.grip.y+=correction*catch_weight*near_ground
	result.tip=result.grip+direction*reach
	return result
