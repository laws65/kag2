extends Node
class_name PlayerDisplayInterpolator


@export var active: bool = true
@export var blob: Blob
@export var nodes_to_interpolate: Array[Node] = []

var _old_position := Vector2.ZERO
var _new_position := Vector2.ZERO


func _ready() -> void:
	if multiplayer.is_server():
		queue_free()
		set_process(false)
		return

	set_process(active)

	assert(is_instance_valid(blob), "Must set the blob to interpolate")

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
