extends RapierCharacterBody2D


func get_blob() -> Blob:
	return $Blob


var jump_force = 250

@export var move_speed := 25.0
@export var acceleration := 2000.0
@export var deceleration := 2500.0


func _ready() -> void:
	if get_blob().has_player():
		$Label.text = str(
			get_blob().get_player().get_id()) + " " + str(get_blob().get_player().get_prop("username")
		)



func _on_player_id_changed(_old_player_id: int, new_player_id: int) -> void:
	$Label.text = str(new_player_id)

	#freeze = not is_my_blob() or not client_controlled
