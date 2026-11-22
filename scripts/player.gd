class_name Player
extends Node3D
## The inspector: a lanky cartoon figure with a jointed body, built from shapes
## and animated in code. Walks where you click along the room's navigation mesh,
## turns their head to look at things, and acts out what they are doing.
##
## Faces +Z. "l" joints are on the +X side, "r" on the -X side.

const WALK_SPEED := 2.9
const TURN_SPEED := 9.0
## Metres covered by one full walk cycle (two steps).
const STRIDE := 2.0
## Gesture name -> length in seconds.
const GESTURES := {"reach": 0.75, "shrug": 1.1, "think": 1.4, "startle": 0.9}
## How far through a gesture its action happens (the hand arrives).
const CONTACT := 0.35

## A point for the head to turn towards, or null. Set by Main from the mouse.
var look_target: Variant = null

var _path := PackedVector3Array()
var _index := 0
var _on_arrive := Callable()
var _yaw_target := 0.0

var _clock := 0.0
var _walk := 0.0
var _phase := 0.0
var _gesture := ""
var _queued := ""
var _gesture_time := 0.0
var _gesture_height := 0.0
var _gesture_contact := Callable()
var _preview := false

var _rig: Node3D
var _head: Node3D
var _joints := {}
var _applied := {}
var _eyes: Array[Node3D] = []
var _brows: Array[Node3D] = []
var _head_yaw := 0.0
var _head_pitch := 0.0
var _glance := 0.0
var _glance_timer := 2.0
var _blink_timer := 3.0


func _ready() -> void:
	_build()
	_yaw_target = rotation.y
	_apply(_idle_pose(), 1.0)


func is_walking() -> bool:
	return not _path.is_empty()


func stop() -> void:
	_path = PackedVector3Array()
	_on_arrive = Callable()
	_cancel_gesture()
	_yaw_target = rotation.y


## Walk to the nearest reachable point to `target`, then call `on_arrive` (if given).
func walk_to(target: Vector3, on_arrive := Callable()) -> void:
	_cancel_gesture()
	var map := get_world_3d().navigation_map
	_path = NavigationServer3D.map_get_path(map, global_position, target, true)
	_index = 0
	_on_arrive = on_arrive
	if _path.is_empty():
		_finish()


## Turn to face a point.
func face(point: Vector3) -> void:
	var to_point := point - global_position
	to_point.y = 0.0
	if to_point.length() > 0.01:
		_yaw_target = atan2(to_point.x, to_point.z)
		if Game.test_mode:
			rotation.y = _yaw_target


## Act something out. `height` is -1 (floor) to 1 (overhead) for "reach".
## `on_contact` runs at the moment the hand arrives.
func gesture(kind: String, height := 0.0, on_contact := Callable()) -> void:
	if Game.test_mode or is_walking() or not GESTURES.has(kind):
		if on_contact.is_valid():
			on_contact.call()
		return
	if _gesture == "reach" and kind != "reach":
		# A reaction to what the hand just did: let the reach finish first.
		_queued = kind
		return
	_gesture = kind
	_queued = ""
	_gesture_time = 0.0
	_gesture_height = height
	_gesture_contact = on_contact


## Freeze the figure in a given pose, for the character preview.
func preview(walk: float, phase: float, kind := "", progress := 0.0, height := 0.0) -> void:
	_preview = true
	var pose := _idle_pose()
	_blend(pose, _walk_pose(phase), walk)
	if kind != "":
		_blend(pose, _gesture_pose(kind, height), _envelope(progress))
		_set_surprise(_envelope(progress) if kind == "startle" else 0.0)
	_apply(pose, 1.0)


func _process(delta: float) -> void:
	if _preview:
		return
	_clock += delta
	_move(delta)
	_animate(delta)
	_look(delta)
	_blink(delta)


# --- Movement ----------------------------------------------------------------

func _move(delta: float) -> void:
	if _path.is_empty():
		_walk = move_toward(_walk, 0.0, delta * 5.0)
	else:
		_walk = move_toward(_walk, 1.0, delta * 6.0)
		var target := _path[_index]
		target.y = global_position.y
		var to_target := target - global_position
		var step := WALK_SPEED * delta
		_phase += step * TAU / STRIDE
		if to_target.length() <= step:
			global_position = target
			_index += 1
			if _index >= _path.size():
				_finish()
		else:
			var direction := to_target.normalized()
			global_position += direction * step
			_yaw_target = atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, _yaw_target, minf(1.0, TURN_SPEED * delta))


func _finish() -> void:
	_path = PackedVector3Array()
	var callback := _on_arrive
	_on_arrive = Callable()
	if callback.is_valid():
		callback.call()


func _cancel_gesture() -> void:
	_gesture = ""
	_queued = ""
	_gesture_contact = Callable()


# --- Animation ---------------------------------------------------------------
# A pose is a dictionary of joint name -> rotation (radians), plus "root" for the
# whole body's offset. Each frame the idle, walk and gesture poses are blended,
# then the joints ease towards the result so nothing ever snaps.

func _animate(delta: float) -> void:
	var pose := _idle_pose()
	if _walk > 0.0:
		_blend(pose, _walk_pose(_phase), smoothstep(0.0, 1.0, _walk))

	var surprise := 0.0
	if _gesture != "":
		_gesture_time += delta
		var progress: float = _gesture_time / GESTURES[_gesture]
		if progress >= CONTACT and _gesture_contact.is_valid():
			var contact := _gesture_contact
			_gesture_contact = Callable()
			contact.call()
		if _gesture != "" and progress >= 1.0:
			_gesture = _queued
			_queued = ""
			_gesture_time = 0.0
		elif _gesture != "":
			_blend(pose, _gesture_pose(_gesture, _gesture_height), _envelope(progress))
			if _gesture == "startle":
				surprise = _envelope(progress)

	_set_surprise(surprise)
	_apply(pose, 1.0 - exp(-20.0 * delta))


func _idle_pose() -> Dictionary:
	var breath := sin(_clock * 1.8)
	var sway := sin(_clock * 0.6)
	return {
		"root": Vector3(0, breath * 0.008, 0),
		"hips": Vector3(0, 0, sway * 0.03),
		"spine": Vector3(0.03 + breath * 0.015, 0, -sway * 0.03),
		"neck": Vector3.ZERO,
		# Right arm hangs loose; left arm holds the clipboard up.
		"shoulder_r": Vector3(0.03, 0, -0.08 - breath * 0.01),
		"elbow_r": Vector3(-0.2, 0, 0),
		"shoulder_l": Vector3(-0.2, -0.45, 0.1),
		"elbow_l": Vector3(-1.45, 0, 0),
		"thigh_l": Vector3(0, 0.22, 0.03),
		"knee_l": Vector3.ZERO,
		"foot_l": Vector3.ZERO,
		"thigh_r": Vector3(0, -0.22, -0.03),
		"knee_r": Vector3.ZERO,
		"foot_r": Vector3.ZERO,
	}


func _walk_pose(phase: float) -> Dictionary:
	var left := sin(phase)
	var right := sin(phase + PI)
	return {
		"root": Vector3(0, 0.03 * cos(2.0 * phase) - 0.03, 0),
		"hips": Vector3(0, -0.14 * left, 0.04 * left),
		"spine": Vector3(0.1, 0.22 * left, -0.03 * left),
		"neck": Vector3(-0.05, -0.08 * left, 0),
		"shoulder_r": Vector3(-0.55 * left, 0, -0.1),
		"elbow_r": Vector3(-0.3 - 0.3 * maxf(0.0, left), 0, 0),
		"shoulder_l": Vector3(-0.2 + 0.1 * right, -0.45, 0.1),
		"elbow_l": Vector3(-1.4, 0, 0),
		"thigh_l": Vector3(-0.62 * left, 0.1, 0),
		"knee_l": Vector3(1.15 * maxf(0.0, cos(phase)), 0, 0),
		"foot_l": Vector3(-0.3 * left, 0, 0),
		"thigh_r": Vector3(-0.62 * right, -0.1, 0),
		"knee_r": Vector3(1.15 * maxf(0.0, cos(phase + PI)), 0, 0),
		"foot_r": Vector3(-0.3 * right, 0, 0),
	}


func _gesture_pose(kind: String, height: float) -> Dictionary:
	match kind:
		"reach":
			var pose := {
				"shoulder_r": Vector3(-1.35 - 0.55 * height, 0, 0.1),
				"elbow_r": Vector3(-0.15, 0, 0),
				"spine": Vector3(0.16 - 0.12 * height, 0.25, 0),
				"neck": Vector3(-0.2 * height, 0, 0),
			}
			if height < -0.3:
				# Low down: bend the knees and get in there.
				var crouch := clampf((-height - 0.3) / 0.7, 0.0, 1.0)
				pose["root"] = Vector3(0, -0.2 * crouch, 0.02)
				pose["thigh_l"] = Vector3(-0.85 * crouch, 0.22, 0.03)
				pose["thigh_r"] = Vector3(-0.85 * crouch, -0.22, -0.03)
				pose["knee_l"] = Vector3(1.5 * crouch, 0, 0)
				pose["knee_r"] = Vector3(1.5 * crouch, 0, 0)
				pose["foot_l"] = Vector3(-0.6 * crouch, 0, 0)
				pose["foot_r"] = Vector3(-0.6 * crouch, 0, 0)
				pose["spine"] = Vector3(0.2 + 0.35 * crouch, 0.25, 0)
			return pose
		"shrug":
			return {
				"root": Vector3(0, 0.03, 0),
				"shoulder_r": Vector3(-0.35, 0, -0.55),
				"elbow_r": Vector3(-1.5, 0, 0),
				"shoulder_l": Vector3(-0.35, 0, 0.55),
				"elbow_l": Vector3(-1.5, 0, 0),
				"neck": Vector3(0, 0, 0.2),
			}
		"think":
			return {
				"spine": Vector3(0.1, 0, 0.04),
				"shoulder_r": Vector3(-0.8, 0.35, 0.1),
				"elbow_r": Vector3(-2.15, 0, 0),
				"neck": Vector3(0.14, 0, -0.14),
			}
		"startle":
			return {
				"root": Vector3(0, 0.1, -0.12),
				"spine": Vector3(-0.28, 0, 0),
				"neck": Vector3(-0.12, 0, 0),
				"shoulder_r": Vector3(-0.9, 0, -1.2),
				"elbow_r": Vector3(-1.2, 0, 0),
				"shoulder_l": Vector3(-0.9, 0, 1.2),
				"elbow_l": Vector3(-1.2, 0, 0),
				"thigh_l": Vector3(-0.4, 0.3, 0.2),
				"knee_l": Vector3(0.8, 0, 0),
				"thigh_r": Vector3(-0.4, -0.3, -0.2),
				"knee_r": Vector3(0.8, 0, 0),
			}
	return {}


## Ease in, hold, ease out.
func _envelope(progress: float) -> float:
	return smoothstep(0.0, 0.25, progress) * (1.0 - smoothstep(0.7, 1.0, progress))


func _blend(pose: Dictionary, other: Dictionary, weight: float) -> void:
	for joint: String in other:
		var from: Vector3 = pose.get(joint, Vector3.ZERO)
		pose[joint] = from.lerp(other[joint], weight)


func _apply(pose: Dictionary, amount: float) -> void:
	for joint: String in pose:
		var target: Vector3 = pose[joint]
		var current: Vector3 = _applied.get(joint, target)
		current = current.lerp(target, amount)
		_applied[joint] = current
		if joint == "root":
			_rig.position = current
		else:
			(_joints[joint] as Node3D).rotation = current


func _look(delta: float) -> void:
	var yaw := 0.0
	var pitch := 0.0
	if look_target is Vector3:
		var point: Vector3 = look_target
		var local := to_local(point) - Vector3(0, 1.5, 0)
		var raw := atan2(local.x, local.z)
		if absf(raw) < 1.9:
			yaw = clampf(raw, -1.1, 1.1)
			pitch = clampf(-atan2(local.y, Vector2(local.x, local.z).length()), -0.5, 0.6)
	elif _walk < 0.1 and _gesture == "":
		# Nothing to look at: glance about now and then.
		_glance_timer -= delta
		if _glance_timer <= 0.0:
			_glance_timer = randf_range(2.0, 5.0)
			_glance = 0.0 if randf() < 0.5 else randf_range(-0.7, 0.7)
		yaw = _glance
	var amount := 1.0 - exp(-7.0 * delta)
	_head_yaw = lerpf(_head_yaw, yaw, amount)
	_head_pitch = lerpf(_head_pitch, pitch, amount)
	_head.rotation = Vector3(_head_pitch, _head_yaw, 0)


func _blink(delta: float) -> void:
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink_timer = randf_range(2.2, 5.0)
	var closed := _blink_timer < 0.11
	for eye in _eyes:
		eye.scale.y = 0.12 if closed else eye.scale.x


func _set_surprise(amount: float) -> void:
	for eye in _eyes:
		eye.scale = Vector3.ONE * (1.0 + 0.35 * amount)
	for brow in _brows:
		brow.position.y = 0.3 + 0.05 * amount


# --- Construction ------------------------------------------------------------

func _joint(parent: Node3D, joint_name: String, pos: Vector3) -> Node3D:
	var joint := Node3D.new()
	joint.position = pos
	parent.add_child(joint)
	_joints[joint_name] = joint
	return joint


func _build() -> void:
	var trousers := Color(0.17, 0.2, 0.36)
	var shirt := Color(0.86, 0.88, 0.92)
	var vest := Color(1.0, 0.5, 0.08)
	var stripe := Color(0.93, 0.95, 0.85)
	var skin := Color(0.82, 0.6, 0.45)
	var hair := Color(0.28, 0.17, 0.1)
	var yellow := Color(1.0, 0.82, 0.12)
	var boot := Color(0.2, 0.14, 0.1)

	_rig = Node3D.new()
	_rig.scale = Vector3.ONE * 0.9
	add_child(_rig)

	var hips := _joint(_rig, "hips", Vector3(0, 0.95, 0))
	Kit.ball(hips, Vector3.ZERO, 0.17, trousers, Vector3(1.1, 0.8, 0.9))

	var spine := _joint(hips, "spine", Vector3(0, 0.06, 0))
	Kit.ball(spine, Vector3(0, 0.1, 0.03), 0.2, shirt, Vector3(1, 0.9, 0.95))
	Kit.cyl(spine, Vector3(0, 0.27, 0), 0.21, 0.4, vest, Vector3.ZERO, 0.17)
	Kit.cyl(spine, Vector3(0, 0.19, 0), 0.208, 0.05, stripe, Vector3.ZERO, 0.202)
	Kit.cyl(spine, Vector3(0, 0.36, 0), 0.186, 0.05, stripe, Vector3.ZERO, 0.18)
	Kit.ball(spine, Vector3(0, 0.45, 0), 0.17, vest, Vector3(1.4, 0.45, 0.9))

	var neck := _joint(spine, "neck", Vector3(0, 0.5, 0))
	Kit.cyl(neck, Vector3(0, 0.04, 0), 0.05, 0.12, skin)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.08, 0)
	_head.scale = Vector3.ONE * 1.12
	neck.add_child(_head)
	_build_head(skin, hair, yellow)

	for side in [1.0, -1.0]:
		var tag := "l" if side > 0.0 else "r"

		var thigh := _joint(hips, "thigh_" + tag, Vector3(0.1 * side, -0.04, 0))
		Kit.cyl(thigh, Vector3(0, -0.21, 0), 0.065, 0.42, trousers, Vector3.ZERO, 0.08)
		var knee := _joint(thigh, "knee_" + tag, Vector3(0, -0.42, 0))
		Kit.ball(knee, Vector3.ZERO, 0.066, trousers)
		Kit.cyl(knee, Vector3(0, -0.2, 0), 0.05, 0.4, trousers, Vector3.ZERO, 0.064)
		var foot := _joint(knee, "foot_" + tag, Vector3(0, -0.4, 0))
		Kit.box(foot, Vector3(0, -0.04, 0.06), Vector3(0.13, 0.1, 0.28), boot)
		Kit.ball(foot, Vector3(0, -0.03, 0.2), 0.08, boot, Vector3(1, 0.8, 1.15))

		var shoulder := _joint(spine, "shoulder_" + tag, Vector3(0.23 * side, 0.44, 0))
		Kit.ball(shoulder, Vector3.ZERO, 0.07, shirt)
		Kit.cyl(shoulder, Vector3(0, -0.15, 0), 0.048, 0.3, shirt, Vector3.ZERO, 0.06)
		var elbow := _joint(shoulder, "elbow_" + tag, Vector3(0, -0.3, 0))
		Kit.ball(elbow, Vector3.ZERO, 0.052, skin)
		Kit.cyl(elbow, Vector3(0, -0.14, 0), 0.04, 0.28, skin, Vector3.ZERO, 0.05)
		Kit.ball(elbow, Vector3(0, -0.32, 0), 0.08, skin, Vector3(0.8, 1.15, 1.0))

		if side > 0.0:
			var clipboard := Node3D.new()
			clipboard.position = Vector3(-0.05, -0.3, 0.07)
			clipboard.rotation_degrees = Vector3(-35, 0, 0)
			elbow.add_child(clipboard)
			Kit.box(clipboard, Vector3.ZERO, Vector3(0.24, 0.32, 0.025), Color(0.5, 0.33, 0.18))
			Kit.box(clipboard, Vector3(0, -0.01, 0.016), Vector3(0.2, 0.27, 0.01), Kit.CREAM)
			Kit.box(clipboard, Vector3(0, 0.14, 0.02), Vector3(0.1, 0.03, 0.02), Color(0.6, 0.62, 0.66))


func _build_head(skin: Color, hair: Color, yellow: Color) -> void:
	Kit.ball(_head, Vector3(0, 0.17, 0), 0.19, skin, Vector3(0.95, 1.15, 1.0))
	Kit.ball(_head, Vector3(0, 0.2, -0.05), 0.185, hair, Vector3(1.0, 1.05, 0.95))
	Kit.cyl(_head, Vector3(0, 0.13, 0.24), 0.05, 0.17, skin, Vector3(90, 0, 0), 0.02)
	Kit.box(_head, Vector3(0, 0.04, 0.165), Vector3(0.1, 0.018, 0.03), Color(0.4, 0.2, 0.18))
	for side in [1.0, -1.0]:
		Kit.ball(_head, Vector3(0.185 * side, 0.16, 0), 0.05, skin, Vector3(0.6, 1, 1))

		var eye := Node3D.new()
		eye.position = Vector3(0.075 * side, 0.22, 0.15)
		_head.add_child(eye)
		Kit.ball(eye, Vector3.ZERO, 0.055, Color.WHITE, Vector3(1, 1.2, 0.6))
		Kit.ball(eye, Vector3(-0.008 * side, -0.005, 0.028), 0.025, Kit.INK)
		_eyes.append(eye)

		var brow := Kit.box(_head, Vector3(0.075 * side, 0.3, 0.17), Vector3(0.09, 0.024, 0.03), hair, Vector3(0, 0, -10 * side))
		_brows.append(brow)

	# A hard hat a size too big, pushed back.
	var hat := Node3D.new()
	hat.position = Vector3(0, 0.31, -0.01)
	hat.rotation_degrees = Vector3(-9, 0, 0)
	_head.add_child(hat)
	Kit.ball(hat, Vector3(0, 0.03, 0), 0.22, yellow, Vector3(1, 0.72, 1.06))
	Kit.cyl(hat, Vector3(0, 0, 0.05), 0.275, 0.028, yellow)
	Kit.box(hat, Vector3(0, 0.17, 0), Vector3(0.05, 0.05, 0.36), yellow)
