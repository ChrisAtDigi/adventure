extends Node
## Lines the inspector up in every key pose, for checking the character's look.
## Run:  godot --path . res://tests/character_preview.tscn
## With SMOKE_OUT set to a folder, saves two screenshots there and quits.

const POSES := [
	# [label, walk weight, walk phase, gesture, gesture progress, reach height]
	["idle", 0.0, 0.0, "", 0.0, 0.0],
	["walk: left foot forward", 1.0, PI * 0.5, "", 0.0, 0.0],
	["walk: passing", 1.0, 0.0, "", 0.0, 0.0],
	["walk: right foot forward", 1.0, PI * 1.5, "", 0.0, 0.0],
	["reach: high", 0.0, 0.0, "reach", 0.45, 1.0],
	["reach: middle", 0.0, 0.0, "reach", 0.45, 0.0],
	["reach: low", 0.0, 0.0, "reach", 0.45, -1.0],
	["shrug", 0.0, 0.0, "shrug", 0.45, 0.0],
	["think", 0.0, 0.0, "think", 0.45, 0.0],
	["startle", 0.0, 0.0, "startle", 0.45, 0.0],
]
const SPACING := 1.5


func _ready() -> void:
	var stage := Room.new()
	add_child(stage)
	stage.mood(Color(0.6, 0.66, 0.85), 0.6, Color(1.0, 0.93, 0.8), 0.8)
	stage.floor_slab(POSES.size() * SPACING + 2.0, 5.0, Color(0.2, 0.33, 0.36))
	Kit.box(stage, Vector3(0, 1.6, -2.6), Vector3(POSES.size() * SPACING + 2.0, 3.2, 0.2), Color(0.87, 0.81, 0.68))

	var start := -(POSES.size() - 1) * SPACING / 2.0
	for i in POSES.size():
		var pose: Array = POSES[i]
		var figure := Player.new()
		figure.position = Vector3(start + i * SPACING, 0, 0)
		figure.rotation.y = 0.55
		stage.add_child(figure)
		figure.preview(pose[1], pose[2], pose[3], pose[4], pose[5])
		Kit.text(stage, Vector3(start + i * SPACING, 2.35, -2.45), pose[0], 26, Kit.INK)

	var folder := OS.get_environment("SMOKE_OUT")
	for half in 2:
		var centre := start + (1.5 + half * 5.0) * SPACING + SPACING * 0.5
		stage.shot(Vector3(centre + 1.2, 1.7, 6.6), Vector3(centre, 1.05, 0), 40.0)
		for i in 4:
			await get_tree().process_frame
		if folder != "":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(folder.path_join("character_%d.png" % (half + 1)))
	if folder != "":
		get_tree().quit()
