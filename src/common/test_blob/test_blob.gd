extends Blob


var jump_force = 250

@export var move_speed := 25.0
@export var acceleration := 2000.0
@export var deceleration := 2500.0


func _ready() -> void:
	if has_player():
		$Label.text = str(
			get_player().get_id()) + " " + str(get_player().get_prop("username")
		)


var jump_pressed: bool = false
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("move_up"):
		jump_pressed = true
	elif event.is_action_released("move_up"):
		jump_pressed = false
func _on_tick() -> void:
	if is_my_blob() and client_controlled:
		var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		
		#apply_central_impulse(Vector2(input.x * move_speed, 0))

		if jump_pressed and is_on_floor():
			#apply_central_impulse(Vector2(0, -jump_force))
			jump_pressed = false

		#apply_central_impulse(-linear_velocity * 0.01)
		
		PhysicsServer2D.body_set_state(
			get_rid(),
			PhysicsServer2D.BODY_STATE_TRANSFORM,
			Transform2D.IDENTITY.translated(position + input*1)
		)


func _on_player_id_changed(_old_player_id: int, new_player_id: int) -> void:
	$Label.text = str(new_player_id)
	
	#freeze = not is_my_blob() or not client_controlled


func is_on_floor() -> bool:
	return true
