extends RefCounted
## Presentation-only boom. Combat always samples FollowCamera's canonical head frame.
const RADIUS=.22
const DISTANCE=3.8
const CLOSE_DISTANCE=.65
var query:PhysicsShapeQueryParameters3D
var actual_distance=0.0
var close_view=false

func _init() -> void:
	query=PhysicsShapeQueryParameters3D.new()
	var sphere=SphereShape3D.new();sphere.radius=RADIUS
	query.shape=sphere;query.collision_mask=1|8

func reset() -> void:
	actual_distance=0.0

func sample(actor:Node3D,head:Transform3D,yaw:float,pitch:float,bounds:Rect2,delta:float) -> Transform3D:
	# The boom uses mouse look rather than attack head rotation. The visible
	# reticle independently projects the canonical aim, including animated recoil.
	var basis=Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,-pitch)
	# Bow rests in the left hand; that shoulder keeps the real nock and
	# ballistic preview clear of the local head without redirecting the shot.
	var shoulder=-.70 if actor.get("weapon_type")=="bow" else .60
	var desired=head.origin+basis*Vector3(shoulder,.25,DISTANCE)
	desired.x=clampf(desired.x,bounds.position.x+RADIUS,bounds.end.x-RADIUS)
	desired.z=clampf(desired.z,bounds.position.y+RADIUS,bounds.end.y-RADIUS)
	var travel=desired-head.origin
	query.exclude=[actor.get_rid()]
	query.transform=Transform3D(Basis.IDENTITY,head.origin)
	query.motion=travel
	var space=actor.get_world_3d().direct_space_state
	var fractions=space.cast_motion(query)
	var safe=maxf(0,travel.length()*fractions[0]-.04) if fractions[0]<1 else travel.length()
	# Starting overlaps must not permit a boom to tunnel through a nearby wall.
	query.motion=Vector3.ZERO
	if not space.intersect_shape(query,1).is_empty():safe=0.0
	actual_distance=minf(actual_distance,safe) if safe<actual_distance else lerpf(actual_distance,safe,1-exp(-maxf(delta,0)*8))
	# A mode switch/teleport has no stale previous camera position to sweep from.
	if delta<=0:actual_distance=safe
	close_view=actual_distance<CLOSE_DISTANCE
	return head if close_view else Transform3D(basis,head.origin+travel.normalized()*actual_distance)

func aim_point(actor:Node3D,head:Transform3D) -> Vector3:
	var target=head.origin-head.basis.z*40
	var ray=PhysicsRayQueryParameters3D.create(head.origin,target,1|8,[actor.get_rid()])
	var hit=actor.get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.position if not hit.is_empty() else target
