class_name Player
extends Node3D
## The inspector: hi-vis vest, hard hat, clipboard. Walks where you click,
## following a path from the current room's navigation mesh.

const SPEED := 3.4
const TURN_SPEED := 12.0

var _path := PackedVector3Array()
var _index := 0
var _on_arrive := Callable()
var _stride := 0.0
var _body: Node3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []


func _ready() -> void:
	_build()


func is_walking() -> bool:
	return not _path.is_empty()


func stop() -> void:
	_path = PackedVector3Array()
	_on_arrive = Callable()


## Walk to the nearest reachable point to `target`, then call `on_arrive` (if given).
func walk_to(target: Vector3, on_arrive := Callable()) -> void:
	var map := get_world_3d().navigation_map
	_path = NavigationServer3D.map_get_path(map, global_position, target, true)
	_index = 0
	_on_arrive = on_arrive
	if _path.is_empty():
		_finish()


func face(point: Vector3) -> void:
	var to_point := point - global_position
	to_point.y = 0.0
	if to_point.length() > 0.01:
		rotation.y = atan2(to_point.x, to_point.z)


func _process(delta: float) -> void:
	if _path.is_empty():
		_pose(0.0, lerpf(_body.position.y, 0.0, minf(1.0, delta * 12.0)))
		return

	var target := _path[_index]
	target.y = global_position.y
	var to_target := target - global_position
	var step := SPEED * delta

	if to_target.length() <= step:
		global_position = target
		_index += 1
		if _index >= _path.size():
			_finish()
		return

	var direction := to_target.normalized()
	global_position += direction * step
	rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), minf(1.0, TURN_SPEED * delta))
	_stride += delta * 10.0
	_pose(sin(_stride), absf(sin(_stride)) * 0.05)


func _pose(swing: float, lift: float) -> void:
	_body.position.y = lift
	_legs[0].rotation.x = swing * 0.7
	_legs[1].rotation.x = -swing * 0.7
	_arms[0].rotation.x = -swing * 0.5
	_arms[1].rotation.x = swing * 0.35


func _finish() -> void:
	_path = PackedVector3Array()
	var callback := _on_arrive
	_on_arrive = Callable()
	if callback.is_valid():
		callback.call()


func _build() -> void:
	var navy := Color(0.16, 0.2, 0.36)
	var vest := Color(1.0, 0.5, 0.08)
	var skin := Color(0.82, 0.6, 0.45)
	var yellow := Color(1.0, 0.82, 0.12)

	_body = Node3D.new()
	add_child(_body)

	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(0.11 * side, 0.52, 0)
		_body.add_child(leg)
		Kit.cyl(leg, Vector3(0, -0.24, 0), 0.08, 0.48, navy)
		Kit.box(leg, Vector3(0, -0.48, 0.05), Vector3(0.15, 0.09, 0.26), Kit.INK)
		_legs.append(leg)

		var arm := Node3D.new()
		arm.position = Vector3(0.3 * side, 1.1, 0)
		_body.add_child(arm)
		Kit.cyl(arm, Vector3(0, -0.2, 0), 0.065, 0.42, navy)
		Kit.ball(arm, Vector3(0, -0.44, 0), 0.075, skin)
		_arms.append(arm)

		Kit.ball(_body, Vector3(0.08 * side, 1.4, 0.185), 0.036, Kit.INK)

	# Clipboard, in the right hand.
	Kit.box(_arms[1], Vector3(0.02, -0.42, 0.12), Vector3(0.22, 0.3, 0.03), Color(0.5, 0.33, 0.18), Vector3(-20, 0, 0))
	Kit.box(_arms[1], Vector3(0.02, -0.42, 0.14), Vector3(0.18, 0.24, 0.02), Kit.CREAM, Vector3(-20, 0, 0))

	Kit.cyl(_body, Vector3(0, 0.84, 0), 0.25, 0.68, vest, Vector3.ZERO, 0.2)
	Kit.cyl(_body, Vector3(0, 0.74, 0), 0.252, 0.07, Color(0.92, 0.94, 0.86), Vector3.ZERO, 0.243)
	Kit.cyl(_body, Vector3(0, 0.96, 0), 0.228, 0.07, Color(0.92, 0.94, 0.86), Vector3.ZERO, 0.218)

	Kit.ball(_body, Vector3(0, 1.37, 0), 0.21, skin)
	Kit.ball(_body, Vector3(0, 1.33, 0.2), 0.045, skin)
	Kit.ball(_body, Vector3(0, 1.5, 0), 0.228, yellow, Vector3(1, 0.62, 1))
	Kit.cyl(_body, Vector3(0, 1.48, 0.04), 0.275, 0.03, yellow)
