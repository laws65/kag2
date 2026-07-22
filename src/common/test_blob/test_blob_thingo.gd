extends Blob


var jump_force = 250

@export var move_speed := 25.0
@export var acceleration := 2000.0
@export var deceleration := 2500.0


var jump_pressed: bool = false
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("move_up"):
		jump_pressed = true
	elif event.is_action_released("move_up"):
		jump_pressed = false


func _on_tick() -> void:
	if (is_my_blob() or multiplayer.is_server()) and client_controlled:
		var inputs: Vector2
		inputs.x = int(input.inputs["move_right"]) - int(input.inputs["move_left"])
		inputs.y = int(input.inputs["move_down"]) - int(input.inputs["move_up"])
		inputs = inputs.normalized()

		#apply_central_impulse(Vector2(input.x * move_speed, 0))

		if jump_pressed and scene.is_on_floor():
			#apply_central_impulse(Vector2(0, -jump_force))
			jump_pressed = false

		#apply_central_impulse(-linear_velocity * 0.01)

		scene.velocity = inputs * 250
		scene.move_and_slide()


func get_snapshot() -> Dictionary:
	return {"position": scene.position}


func set_snapshot(snapshot: Dictionary) -> void:
	scene.position = snapshot["position"]
