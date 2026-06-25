extends Node2D
class_name Map


func _ready() -> void:
	NetworkedClock.tick.connect(_on_tick_internal)


func _on_tick_internal() -> void:
	if not is_queued_for_deletion():
		_on_tick()


func _on_tick() -> void:
	pass


func get_spawn_data() -> Dictionary:
	return {}


func set_spawn_data(_spawn_data: Dictionary) -> void:
	pass


func cleanup() -> void:
	pass
