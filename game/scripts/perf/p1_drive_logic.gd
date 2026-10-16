extends Node




func _ready() -> void :
	var save: = get_node_or_null("/root/SaveGame")
	if save:
		save.enabled = false
	await get_tree().process_frame
	await P1Prof.drive(get_tree(), P1Prof.room_steps(P1Prof.first_spawn()))
	await get_tree().create_timer(10.0).timeout
	P1Prof.snapshot("settled (all neighbour zones streamed in)")
	P1Prof.mark("drive complete")
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()
