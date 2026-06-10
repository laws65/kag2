extends Blob


func _ready() -> void:
	if has_player():
		$Label.text = str(get_player().get_id()) + " " + str(get_player().get_prop("username"))


func _on_tick() -> void:
	if is_my_blob() and client_controlled:
		var input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var delta := NetworkedClock.tick_duration_seconds
		velocity = lerp(velocity, input * 100, delta*2.0)
		var _collision := move_and_collide(velocity * delta)


func _on_player_id_changed(_old_player_id: int, new_player_id: int) -> void:
	$Label.text = str(new_player_id)


func interpolate_snapshot(
	old_snapshot: Dictionary,
	new_snapshot: Dictionary,
	interpolation_delta: float
) -> void:
	super(old_snapshot, new_snapshot, interpolation_delta)
	#$Sprite2D.global_position = lerp(old_snapshot["position"], new_snapshot["position"], interpolation_delta)
