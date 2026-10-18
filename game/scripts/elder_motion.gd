extends RefCounted
## Elder-only skeletal posing; donor meshes, rest transforms and other bosses stay intact.
var art:Node3D
var facing:Node3D
var rig:Skeleton3D
var bones:Dictionary={}
var current:Dictionary={}
var recovery:Dictionary={}
var last_state=""
var recovery_time=0.0
const NEUTRAL={"bend":0.0,"twist":0.0,"drop":0.0,"right":0.0,"left":0.0,"spread":0.0,"elbow":0.0,"knee":0.0,"head":0.0}
func configure(model:Node3D,body:Node3D) -> void:
	art=model;facing=body
	var found=art.model.find_children("*","Skeleton3D",true,false)
	if found.is_empty():return
	rig=found[0]
	for name in ["Spine1","Spine2","Spine3","Head","Arm_R","Arm_L","Forearm_R","Forearm_L","Thigh_R","Thigh_L","Leg_R","Leg_L"]:bones[name]=rig.find_bone(name)
	current=NEUTRAL.duplicate()
func blend(a:Dictionary,b:Dictionary,t:float) -> Dictionary:
	var result=NEUTRAL.duplicate()
	for key in result:result[key]=lerpf(float(a.get(key,0)),float(b.get(key,0)),t)
	return result
func pose(values:Dictionary) -> Dictionary:
	var result=NEUTRAL.duplicate();result.merge(values,true);return result
func windup(kind:String,t:float) -> Dictionary:
	var load=smoothstep(0,.62,t)
	match kind:
		"sweep":return blend(NEUTRAL,pose({"bend":.18,"twist":-.85,"right":-1.4,"left":-.55,"spread":.7,"elbow":.6,"knee":.18}),load)
		"slam":return blend(NEUTRAL,pose({"bend":-.2,"right":-2.65,"left":-2.65,"spread":.2,"elbow":.25,"head":-.2}),load)
		"rush":
			var result=blend(NEUTRAL,pose({"bend":.65,"drop":-.5,"right":-.9,"left":-.9,"spread":.45,"elbow":1.0,"knee":.55,"head":-.25}),load)
			# A single weighty stamp precedes the locked-direction pause.
			result.drop+=sin(clampf((t-.55)/.22,0,1)*PI)*.15
			return result
		"stone":return blend(NEUTRAL,pose({"bend":-.12,"twist":-.4,"right":-2.2,"left":-.65,"spread":.2,"elbow":.8,"head":-.1}),load)
	return NEUTRAL.duplicate()
func strike(kind:String,t:float) -> Dictionary:
	var loaded=windup(kind,1)
	match kind:
		"sweep":
			var cut=pose({"bend":.35,"twist":.9,"right":-1.15,"left":-.7,"spread":-.6,"elbow":.15,"knee":.25})
			if t<.24:return blend(loaded,cut,smoothstep(0,.18,t))
			var back=pose({"bend":.3,"twist":-.7,"right":-.65,"left":-1.25,"spread":.5,"elbow":.2,"knee":.25})
			return blend(cut,back,smoothstep(.48,.72,t))
		"slam":return blend(loaded,pose({"bend":.9,"drop":-.6,"right":-.6,"left":-.6,"spread":.15,"elbow":.1,"knee":.65,"head":-.25}),smoothstep(0,.4,t))
		"rush":return pose({"bend":.72,"drop":-.35,"right":-.8,"left":-.8,"spread":.4,"elbow":.8,"knee":.4,"head":-.3})
		"stone":return blend(loaded,pose({"bend":.5,"twist":.35,"right":-1.1,"left":-.45,"elbow":.15,"knee":.2}),smoothstep(0,.28,t))
	return NEUTRAL.duplicate()
func rotate_bone(name:String,axis:Vector3,angle:float) -> void:
	var index=int(bones.get(name,-1))
	if index<0 or absf(angle)<.00001:return
	# Convert the visible-body axis into the live bone frame, including donor rest axes.
	var world_axis=facing.global_basis*axis
	var bone_basis=rig.global_basis*rig.get_bone_global_pose(index).basis
	var local_axis=(bone_basis.inverse()*world_axis).normalized()
	rig.set_bone_pose_rotation(index,rig.get_bone_pose_rotation(index)*Quaternion(local_axis,angle))
func hand_position() -> Vector3:
	if rig==null:return facing.global_position+Vector3.UP*3
	var hand=rig.find_bone("Hand_R")
	return rig.global_transform*rig.get_bone_global_pose(hand).origin if hand>=0 else facing.global_position+Vector3.UP*3
func update(state:String,kind:String,t:float,delta:float,moving:bool) -> void:
	if rig==null:return
	if state=="windup":current=windup(kind,t)
	elif state=="strike":current=strike(kind,t)
	elif state=="recover":
		if last_state!="recover":recovery=current.duplicate();recovery_time=0
		recovery_time+=delta;current=blend(recovery,NEUTRAL,smoothstep(.15,.85,recovery_time))
	else:current=NEUTRAL.duplicate()
	last_state=state
	art.pose("walk" if moving else "idle",-1 if state=="idle" else 0,delta)
	art.position.y=current.drop
	for name in ["Spine1","Spine2","Spine3"]:
		rotate_bone(name,Vector3.RIGHT,current.bend/3)
		rotate_bone(name,Vector3.UP,current.twist/3)
	rotate_bone("Head",Vector3.RIGHT,current.head)
	rotate_bone("Head",Vector3.UP,-current.twist*.4)
	for side in ["R","L"]:
		rotate_bone("Arm_"+side,Vector3.RIGHT,current.right if side=="R" else current.left)
		rotate_bone("Arm_"+side,Vector3.FORWARD,current.spread*(1 if side=="R" else -1))
		rotate_bone("Forearm_"+side,Vector3.RIGHT,-current.elbow)
		rotate_bone("Thigh_"+side,Vector3.RIGHT,-current.knee*.55)
		rotate_bone("Leg_"+side,Vector3.RIGHT,current.knee)
	if state=="windup" and kind=="rush":
		var stamp=sin(clampf((t-.45)/.30,0,1)*PI)
		rotate_bone("Thigh_R",Vector3.RIGHT,-.55*stamp)
		rotate_bone("Leg_R",Vector3.RIGHT,.8*stamp)
