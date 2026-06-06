extends Blob


func _ready() -> void:
	if has_player():
		$Label.text = str(get_player().get_id()) + " " + str(get_player().get_prop("username"))


func _physics_process(delta: float) -> void:
	if is_my_blob() and client_controlled:
		var input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		velocity = lerp(velocity, input * 100, delta*2.0)
		var collision := move_and_collide(velocity * delta)
		#if collision:
		#	_resolve_collision(collision)
	elif not multiplayer.is_server():

		#print("%s %s" % [position, get_player_id()])
		var collision := KinematicCollision2D.new()
		if test_move(transform, velocity * delta, collision):
			_resolve_collision(collision)


func _on_player_id_changed(_old_player_id: int, new_player_id: int) -> void:
	$Label.text = str(new_player_id)


func interpolate_snapshot(
	old_snapshot: Dictionary,
	new_snapshot: Dictionary,
	interpolation_delta: float
) -> void:
	super(old_snapshot, new_snapshot, interpolation_delta)
	#$Sprite2D.global_position = lerp(old_snapshot["position"], new_snapshot["position"], interpolation_delta)
