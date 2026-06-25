extends ColorRect


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		visible = not visible


func _on_unpause_button_up() -> void:
	visible = false


func _on_disconnect_button_up() -> void:
	multiplayer.multiplayer_peer.close()


func _on_quit_button_up() -> void:
	get_tree().quit()
