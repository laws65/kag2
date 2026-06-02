extends Blob



func _ready() -> void:
	if has_player():
		$Label.text = get_player().get_id()


func _physics_process(_delta: float) -> void:
	if is_my_blob() and client_controlled:
		var input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		velocity = input * 50
		move_and_slide()


func _on_player_id_changed(_old_player_id: int, new_player_id: int) -> void:
	$Label.text = str(new_player_id)
