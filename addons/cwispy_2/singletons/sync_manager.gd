extends Node



func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return

	var blobs := Blobs.get_blobs()
