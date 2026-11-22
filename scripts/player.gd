class_name Player
extends Node3D
## Click-to-walk character. Follows a path from the room's navigation mesh.

const SPEED := 3.0
const TURN_SPEED := 12.0

var _path := PackedVector3Array()
var _index := 0
var _on_arrive := Callable()
var _walk_time := 0.0

@onready var body: Node3D = $Body


func is_walking() -> bool:
	return not _path.is_empty()


## Walk to the nearest reachable point to `target`, then call `on_arrive` (if given).
func walk_to(target: Vector3, on_arrive := Callable()) -> void:
	var map := get_world_3d().navigation_map
	_path = NavigationServer3D.map_get_path(map, global_position, target, true)
	_index = 0
	_on_arrive = on_arrive


func face(point: Vector3) -> void:
	var to_point := point - global_position
	to_point.y = 0.0
	if to_point.length() > 0.01:
		rotation.y = atan2(to_point.x, to_point.z)


func _process(delta: float) -> void:
	if _path.is_empty():
		body.position.y = 0.0
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

	_walk_time += delta
	body.position.y = absf(sin(_walk_time * 10.0)) * 0.06


func _finish() -> void:
	_path = PackedVector3Array()
	var callback := _on_arrive
	_on_arrive = Callable()
	if callback.is_valid():
		callback.call()
