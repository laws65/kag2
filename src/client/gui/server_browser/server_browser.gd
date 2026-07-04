extends Control


var current_request_id: int


func _ready() -> void:
	Steamworks._initialise_on_client()
	Steamworks.server_browser.query_response.connect(_on_query_response)
	Steamworks.server_browser.query_finished.connect(_on_query_finished)


func _on_refresh_server_list_button_up() -> void:
	var filters = [
		{"key":"or", "value":"2"},
		{"key":"map", "value":"kag2_test"},
		{"key":"gametagsand", "value":"ctf"}
	]
	Steamworks.server_browser.request_server_list(filters)
	$LoadingLabel.show()


func _on_query_response(_server_details: Dictionary) -> void:
	pass


func _on_query_finished(_response: int) -> void:
	$LoadingLabel.hide()
