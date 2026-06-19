extends Control
class_name DebugBlob


@export var blob: Blob
@export var hover_distance: int = 50


func _ready() -> void:
	assert(is_instance_valid(blob), "Must set blob")


func _process(_delta: float) -> void:
	var mouse_pos := blob.get_global_mouse_position()

	var dist_squared := mouse_pos.distance_squared_to(blob.position)
	visible = dist_squared < pow(hover_distance, 2)
	%Label.text = "ID: %s\n Player ID: %s" % [blob.get_id(), blob.get_player_id()]
