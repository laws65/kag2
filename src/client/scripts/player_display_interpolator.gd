extends Node
class_name PlayerDisplayInterpolator


@export var blob: Blob
@export var nodes_to_interpolate: Array[Node] = []

var _old_position := Vector2.ZERO
var _new_position := Vector2.ZERO


func _ready() -> void:
	if multiplayer.is_server():
		queue_free()
		return

	assert(blob, "Must let the player display interpolat")

	blob.player_id_changed.connect(
		func(_old_player_id, new_player_id):
			set_process(new_player_id == Client.get_my_id())
	)

	NetworkedClock.posttick.connect(
		func():
			_old_position = _new_position
			_new_position = blob.position
	)


func _process(_delta: float) -> void:
	for node in nodes_to_interpolate:
		var interpolated_position: Vector2 = lerp(
			_old_position, _new_position, NetworkedClock.interpolation_fraction
		)
		node.global_position = interpolated_position
